"""ComfyUI 배관 — 로컬 인스턴스 하나(:8000), Klein 4B Pro.

**타이틀 레인의 `tools/gen_scene.py` 에서 그래프와 상수를 그대로 가져왔다.**
그쪽이 여섯 판을 돌려 확인한 노드 구성이라 바꿀 이유가 없다.
복사한 이유는 하나다 — `gen_scene.py` 는 다른 레인의 워크트리에 있고
**읽기만 허용**되어 있어서 import 할 수 없다. 두 레인이 통합될 때 합친다.

**체크포인트를 갈아 끼우지 않는다.** 인스턴스도 새로 띄우지 않는다 —
예전에 둘 띄웠다가 블루스크린이 났고 VRAM 이 물린 채 앱들이 줄줄이 죽었다.

`ReferenceLatent` 배관은 남겨 뒀다. 초상은 레퍼런스를 안 물지만
(`docs/design/27-portraits.md` §27.7) **뒤집는 조건이 그 절에 적혀 있어서**
뒤집을 때 배관을 다시 짜지 않으려고 둔다.
"""

from __future__ import annotations

import io
import json
import os
import time
import urllib.parse
import urllib.request
import uuid

HOST = "http://127.0.0.1:8000"

#: gen_scene.py 와 같은 값. 갈아 끼우지 않는다
UNET = "fluxKlein4BPro_v10.safetensors"
CLIP = "qwen_3_4b_fp4_flux2.safetensors"
CLIP_TYPE = "flux2"
VAE = "flux2-vae.safetensors"
SAMPLER = "euler"


def _r16(v: int) -> int:
    return max(16, int(round(v / 16.0)) * 16)


def build(prompt: str, w: int, h: int, seed: int, steps: int = 24,
          prefix: str = "portrait", refs: list[str] | None = None) -> dict:
    """API 형식 워크플로 하나. `refs` 는 화풍 레퍼런스 파일 이름들."""
    w, h = _r16(w), _r16(h)
    refs = refs or []
    g: dict = {
        "1": {"class_type": "UNETLoader",
              "inputs": {"unet_name": UNET, "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader",
              "inputs": {"clip_name": CLIP, "type": CLIP_TYPE, "device": "default"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": VAE}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 0], "text": prompt}},
        "6": {"class_type": "EmptyFlux2LatentImage",
              "inputs": {"width": w, "height": h, "batch_size": 1}},
        "7": {"class_type": "Flux2Scheduler", "inputs": {"steps": steps, "width": w, "height": h}},
        "8": {"class_type": "KSamplerSelect", "inputs": {"sampler_name": SAMPLER}},
        "9": {"class_type": "RandomNoise", "inputs": {"noise_seed": int(seed)}},
        "11": {"class_type": "SamplerCustomAdvanced",
               "inputs": {"noise": ["9", 0], "guider": ["10", 0], "sampler": ["8", 0],
                          "sigmas": ["7", 0], "latent_image": ["6", 0]}},
        "12": {"class_type": "VAEDecode", "inputs": {"samples": ["11", 0], "vae": ["3", 0]}},
        "13": {"class_type": "SaveImage",
               "inputs": {"images": ["12", 0], "filename_prefix": prefix}},
    }
    cond = ["4", 0]
    for i, name in enumerate(refs):
        lid, eid, rid = f"20{i}", f"21{i}", f"22{i}"
        g[lid] = {"class_type": "LoadImage", "inputs": {"image": name}}
        g[eid] = {"class_type": "VAEEncode", "inputs": {"pixels": [lid, 0], "vae": ["3", 0]}}
        g[rid] = {"class_type": "ReferenceLatent",
                  "inputs": {"conditioning": cond, "latent": [eid, 0]}}
        cond = [rid, 0]
    g["10"] = {"class_type": "BasicGuider", "inputs": {"model": ["1", 0], "conditioning": cond}}
    return g


def post(path: str, payload: dict) -> dict:
    data = json.dumps(payload).encode()
    req = urllib.request.Request(HOST + path, data=data,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=300) as r:
        return json.loads(r.read().decode())


def get(path: str) -> dict:
    with urllib.request.urlopen(HOST + path, timeout=300) as r:
        return json.loads(r.read().decode())


def queue_depth() -> tuple[int, int]:
    """(돌고 있는 것, 기다리는 것). **다른 레인이 끼어들었는지 보는 자다.**

    대량 배치 중간에 주기적으로 부른다 — GPU 는 인스턴스 하나뿐이라
    누가 끼어들면 우리 판이 느려지는 것이 아니라 **VRAM 이 물린다.**
    """
    q = get("/queue")
    return len(q.get("queue_running", [])), len(q.get("queue_pending", []))


def run(dest: str, prompt: str, w: int, h: int, seed: int, steps: int = 24,
        refs: list[str] | None = None) -> float:
    """판 하나를 뽑아 `dest` 에 쓴다. 걸린 초를 돌려준다."""
    cid = str(uuid.uuid4())
    name = os.path.splitext(os.path.basename(dest))[0]
    g = build(prompt, w, h, seed, steps=steps, prefix="portrait/" + name, refs=refs)
    started = time.time()
    pid = post("/prompt", {"prompt": g, "client_id": cid})["prompt_id"]
    while True:
        time.sleep(1.5)
        hist = get("/history/" + pid)
        if pid in hist:
            break
    files: list[dict] = []
    for node in hist[pid]["outputs"].values():
        files.extend(node.get("images", []))
    if not files:
        raise RuntimeError("판이 안 나왔다: " + name)
    im = files[-1]
    q = urllib.parse.urlencode({"filename": im["filename"],
                                "subfolder": im.get("subfolder", ""),
                                "type": im.get("type", "output")})
    with urllib.request.urlopen(HOST + "/view?" + q, timeout=300) as r:
        blob = r.read()
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with open(dest, "wb") as f:
        f.write(blob)
    return time.time() - started


def upload(path: str) -> str:
    """입력 폴더에 그림을 올린다. 레퍼런스를 물릴 때만 쓴다 (§27.7)."""
    boundary = "----portrait" + uuid.uuid4().hex
    body = io.BytesIO()
    body.write(("--%s\r\n" % boundary).encode())
    body.write(('Content-Disposition: form-data; name="image"; filename="%s"\r\n'
                % os.path.basename(path)).encode())
    body.write(b"Content-Type: image/png\r\n\r\n")
    with open(path, "rb") as f:
        body.write(f.read())
    body.write(("\r\n--%s\r\n" % boundary).encode())
    body.write(b'Content-Disposition: form-data; name="overwrite"\r\n\r\ntrue\r\n')
    body.write(("--%s--\r\n" % boundary).encode())
    req = urllib.request.Request(
        HOST + "/upload/image", data=body.getvalue(),
        headers={"Content-Type": "multipart/form-data; boundary=" + boundary})
    with urllib.request.urlopen(req, timeout=300) as r:
        info = json.loads(r.read().decode())
    sub = info.get("subfolder", "")
    return (sub + "/" + info["name"]) if sub else info["name"]
