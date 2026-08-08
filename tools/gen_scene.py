"""Title-screen SCENE generation for the game — local ComfyUI :8000, Klein 4B Pro.

The scene (client's own words):
    던전 중앙에 금이 상자에 담겨 있어. 근데 이건 금 간 금이야.
    그리고 사방에서 캐릭터들이 달라들어.
    그거랑 별개로 원경에서 악마들이 스트리밍 하면서 웃고있는거야.

No title typography here — the logo is stamped on separately later.

Setting detail that matters (docs/design/02-overview.md 2.6.1): beings from another
dimension open the gate FOR AMUSEMENT. Humans walk in on their own because there is
something worth taking. Both sides are there voluntarily, so nobody is a victim and
there is no tragedy — only a deal, watched. Humans look covetous, demons look amused.

**There is no studio.** They open the gate; they do not build a set. No trusses,
no spotlights, no speakers, no cables, no audience seating. They watch in person.
An earlier draft of this file described a purpose-built television set — that setting
was discarded, and the picture it produced went on to poison every layer that used it
as a style reference (docs/design/21-title.md 21.13.7). It stays corrected here.

Stage 1 (`full`) is the 시안 — one shot only. **It is not the style reference.**
Per-layer generation references `scene/backdrop.png` instead, because a backdrop has
no creatures in it and therefore nothing that can leak into a cut-out layer.
"""

from __future__ import annotations

import argparse
import io
import json
import os
import time
import urllib.parse
import urllib.request
import uuid

HOST = "http://127.0.0.1:8000"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "scene")

UNET = "fluxKlein4BPro_v10.safetensors"
CLIP = "qwen_3_4b_fp4_flux2.safetensors"
CLIP_TYPE = "flux2"
VAE = "flux2-vae.safetensors"
SAMPLER = "euler"


def _r16(v: int) -> int:
    return max(16, int(round(v / 16.0)) * 16)


def build(prompt: str, w: int, h: int, seed: int, steps: int = 24,
          prefix: str = "scene", refs: list[str] | None = None) -> dict:
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
    with urllib.request.urlopen(req, timeout=180) as r:
        return json.loads(r.read().decode())


def get(path: str) -> dict:
    with urllib.request.urlopen(HOST + path, timeout=180) as r:
        return json.loads(r.read().decode())


def run(name: str, prompt: str, w: int, h: int, seed: int, steps: int = 24,
        refs: list[str] | None = None) -> str:
    cid = str(uuid.uuid4())
    g = build(prompt, w, h, seed, steps=steps, prefix="scene/" + name, refs=refs)
    started = time.time()
    pid = post("/prompt", {"prompt": g, "client_id": cid})["prompt_id"]
    while True:
        time.sleep(2.0)
        hist = get("/history/" + pid)
        if pid in hist:
            break
    files = []
    for node in hist[pid]["outputs"].values():
        files.extend(node.get("images", []))
    if not files:
        raise RuntimeError("no image for " + name)
    im = files[-1]
    q = urllib.parse.urlencode({"filename": im["filename"],
                                "subfolder": im.get("subfolder", ""),
                                "type": im.get("type", "output")})
    with urllib.request.urlopen(HOST + "/view?" + q, timeout=180) as r:
        blob = r.read()
    os.makedirs(OUT, exist_ok=True)
    dest = os.path.join(OUT, name + ".png")
    with open(dest, "wb") as f:
        f.write(blob)
    print("%-12s %6.1fs  %s" % (name, time.time() - started, dest), flush=True)
    return dest


def upload(path: str) -> str:
    boundary = "----scene" + uuid.uuid4().hex
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
    with urllib.request.urlopen(req, timeout=180) as r:
        info = json.loads(r.read().decode())
    sub = info.get("subfolder", "")
    return (sub + "/" + info["name"]) if sub else info["name"]


# ---------------------------------------------------------------------------
# prompts
# ---------------------------------------------------------------------------

STYLE = (
    "dramatic video game key art, rich saturated colour, painterly digital illustration "
    "with crisp animation-background rendering, cinematic wide establishing shot, "
    "strong chiaroscuro, volumetric haze, warm gold key light against deep cold teal shadow"
)

# A hand-hewn stone chamber. NOT a studio — see the module docstring.
ARENA = (
    "a vast ancient underground chamber of raw hand-carved stone: rough rock walls, "
    "crumbling arches and pillars, a broken flagstone floor, dark tunnel mouths "
    "receding into blackness on every side, cold teal gloom and drifting dust haze. "
    "There is absolutely no man-made equipment anywhere: no lighting rigs, no trusses, "
    "no spotlights, no lamps, no loudspeakers, no cameras, no cables, no scaffolding, "
    "no railings, no audience seating, no signage, no machinery"
)

PRIZE = (
    "dead centre, raised on a low stone pedestal, an open iron-bound wooden chest heaped "
    "with gold. The gold has fused into a single solid glowing mass and one jagged black "
    "FISSURE splits it clean through the middle — cracked gold, broken treasure. "
    "It burns warm amber and is the brightest thing in the room, lighting everything from below"
)

HUNTERS = (
    "converging from all four sides, four human treasure hunters in mismatched adventuring "
    "gear and armour, caught mid-lunge, arms outstretched and grabbing toward the chest, "
    "racing each other, faces uplit by the gold with naked greed and exhilaration — "
    "hungry and eager, absolutely not frightened, nobody fleeing"
)

# Calm, not manic. The eyelid does the work — see docs/design/21-title.md 21.13.8.
DEMONS = (
    "high above in the darkness, three grotesque floating demons, each with ONE enormous "
    "single eye, the upper lid drooping halfway across it in a heavy-lidded lazy gaze "
    "angled down at THE HUMANS rather than at the gold. Their lips stay closed and only "
    "one corner of each mouth curls up in a small private smirk. Their bodies hang slack "
    "and unhurried, at ease, settled in to watch, mildly entertained by something they "
    "have seen many times before"
)

FULL = "%s. %s. %s. %s. %s. No text, no letters, no logo, no watermark, no user interface." % (
    STYLE, ARENA, PRIZE, HUNTERS, DEMONS
)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("stage", choices=["full"])
    ap.add_argument("--seed", type=int, default=30507)
    ap.add_argument("--count", type=int, default=1)
    args = ap.parse_args()
    if args.stage == "full":
        for i in range(args.count):
            run("full_%d" % i, FULL, 1536, 864, args.seed + i * 977, steps=24)


if __name__ == "__main__":
    main()
