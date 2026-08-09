"""방 판(구워진 파노라마)의 **노멀맵을 만든다.** 로컬 ComfyUI 의 DSINE 을 부른다.

    python tools/make_plate_normal.py <방 폴더> [--out .renders-lighting/plate_normal] [--api http://127.0.0.1:8000]

# 왜 DSINE 인가 — **BAE 는 구운 빛을 요철로 읽는다**

같은 판에 둘을 돌려 재 봤다. 램프가 구워 놓은 밝은 바닥과 어두운 바닥
(밝기 차 54/255) 에서 두 추정기가 답한 법선의 차이:

    BAE     |dN| = 0.697   <- 구운 빛을 지형으로 읽었다
    DSINE   |dN| = 0.055   <- 무시했다

방 판은 **빛이 이미 구워져 있다.** 그러므로 shape-from-shading 에 약한 추정기는
여기서 못 쓴다. `docs/design/26-2d-lighting.md` §26.4.5 에 표가 있다.

# 왜 바닥을 따로 고치나 — **DSINE 이 맞아서 문제다**

DSINE 이 답한 평균 법선:

    벽    [0.01, -0.03, 0.99]   <- 화면을 본다. 2D 라이팅이 원하는 그대로다
    바닥  [0.02,  0.92, 0.10]   <- **위를 본다.** 기하로는 정답이다

Godot 의 2D 노멀맵은 **화면 전체가 한 평면**이라고 보고 셰이딩한다. 그런데 사선
사이드뷰 판에는 벽과 바닥이 같이 들어 있고, 바닥은 진짜로 위를 본다. 그래서 DSINE 이
정확할수록 바닥이 빛에 반응하지 않는다 (`z` 가 0.10 이면 `N·L` 이 거의 0 이다).
판의 **27%** 가 바닥이다.

그래서 **바닥처럼 생긴 화소만 화면 쪽으로 세운다.** 가로선을 긋지 않는 이유는
소품이 바닥에 서 있어서 선으로 자르면 소품이 잘리기 때문이다 — 내용으로 고른다.

# 언제 다시 굽나 — **「판이 바뀌면」이 아니라 「기하가 바뀌면」이다**

`.renders-lighting/` 는 `.gitignore` 에 있다. 노멀은 판의 파생물이지만, **판이
바뀌었다고 항상 낡는 것은 아니다.** 재 봤다 (`26-2d-lighting.md` §26.4.13):
판이 두 세대 낡은 노멀로 찍은 화면과 다시 구운 화면의 차이가 **화면의 0.76%,
평균 0.057/255** 였다.

이유는 DSINE 을 고른 이유와 같다 — **이 추정기는 구운 밝기를 안 읽는다.**
재생성이 바꾸는 것은 대개 표면 결과 조명이고, 그건 원래 안 보는 것이다.

| 판이 이렇게 바뀌면 | 다시 굽나 |
| --- | --- |
| 표면 결 · 색 · 조명만 (배치 그대로) | **안 굽어도 된다** |
| **카메라 · 소품 배치 · 방 길이** | **굽는다** |

확인하는 법: 옛 판과 새 판의 **위상 상관으로 전역 이동**을 재라. 0px 이면
배치가 그대로다. (판 한 장에 4~6 초니, 애매하면 그냥 굽는 게 싸다.)
"""

from __future__ import annotations

import argparse
import io
import json
import pathlib
import time
import urllib.parse
import urllib.request
import uuid

import numpy as np
from PIL import Image

from console_utf8 import fix_console_encoding

## 바닥으로 볼 `N.y` 의 문턱과 그 위로 부드럽게 섞을 폭. 딱 자르면 경계에 금이 보인다.
_FLOOR_FROM = 0.55
_FLOOR_SPAN = 0.30


def _upload(api: str, path: pathlib.Path) -> str:
    """ComfyUI 입력 폴더로 그림을 올리고 그쪽이 부르는 이름을 돌려준다."""
    boundary = "----x" + uuid.uuid4().hex
    body = io.BytesIO()

    def write(chunk: str | bytes) -> None:
        body.write(chunk if isinstance(chunk, bytes) else chunk.encode())

    write(
        f'--{boundary}\r\nContent-Disposition: form-data; '
        f'name="image"; filename="{path.name}"\r\n'
    )
    write("Content-Type: application/octet-stream\r\n\r\n")
    write(path.read_bytes())
    write("\r\n")
    write(f'--{boundary}\r\nContent-Disposition: form-data; name="overwrite"\r\n\r\ntrue\r\n')
    write(f"--{boundary}--\r\n")
    request = urllib.request.Request(
        api + "/upload/image",
        data=body.getvalue(),
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
    )
    with urllib.request.urlopen(request, timeout=180) as response:
        return json.load(response)["name"]


def _run_dsine(api: str, name: str, resolution: int) -> bytes:
    """DSINE 을 한 번 돌리고 나온 PNG 바이트를 돌려준다."""
    workflow = {
        "1": {"class_type": "LoadImage", "inputs": {"image": name, "upload": "image"}},
        "2": {
            "class_type": "DSINE-NormalMapPreprocessor",
            "inputs": {"image": ["1", 0], "fov": 60.0, "iterations": 5, "resolution": resolution},
        },
        "3": {
            "class_type": "SaveImage",
            "inputs": {"images": ["2", 0], "filename_prefix": "plate_normal"},
        },
    }
    request = urllib.request.Request(
        api + "/prompt",
        data=json.dumps({"prompt": workflow, "client_id": uuid.uuid4().hex}).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=180) as response:
        prompt_id = json.load(response)["prompt_id"]

    started = time.time()
    while time.time() - started < 900:
        with urllib.request.urlopen(f"{api}/history/{prompt_id}", timeout=60) as response:
            history = json.load(response)
        entry = history.get(prompt_id)
        if entry and entry.get("status", {}).get("completed"):
            for output in entry["outputs"].values():
                for image in output.get("images", []):
                    query = urllib.parse.urlencode(
                        {
                            "filename": image["filename"],
                            "subfolder": image.get("subfolder", ""),
                            "type": image["type"],
                        }
                    )
                    with urllib.request.urlopen(f"{api}/view?{query}", timeout=180) as view:
                        return view.read()
        if entry and entry.get("status", {}).get("status_str") == "error":
            raise RuntimeError(json.dumps(entry["status"], ensure_ascii=False)[:2000])
        time.sleep(2)
    raise TimeoutError("DSINE 이 15 분 안에 안 끝났다")


def _stand_floor_up(normal: np.ndarray) -> np.ndarray:
    """**바닥처럼 생긴 화소를 화면 쪽으로 세운다.** 위 주석의 이유가 여기 들어 있다."""
    floorness = np.clip((normal[..., 1] - _FLOOR_FROM) / _FLOOR_SPAN, 0.0, 1.0)[..., None]
    flat = np.zeros_like(normal)
    flat[..., 2] = 1.0
    mixed = normal * (1.0 - floorness) + flat * floorness
    return mixed / (np.linalg.norm(mixed, axis=2, keepdims=True) + 1e-8)


def main() -> int:
    # **한국어 윈도우 콘솔은 cp949 다.** 줄표(U+2014)가 cp949 에 없어서 이 설명문을
    # 그냥 찍으면 `--help` 가 `UnicodeEncodeError` 로 죽는다 — 실제로 죽었다.
    # 같은 위험이 도구 다섯 군데에 더 있어서 `tools/console_utf8.py` 로 뽑아냈다.
    fix_console_encoding()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("room_dir", help="방 폴더 (…/out/<던전>/<방>)")
    parser.add_argument("--out", default=".renders-lighting/plate_normal")
    parser.add_argument("--api", default="http://127.0.0.1:8000")
    parser.add_argument("--resolution", type=int, default=1088, help="DSINE 짧은 변 (64 의 배수)")
    args = parser.parse_args()

    room = pathlib.Path(args.room_dir)
    plate = room / f"{room.name}.panorama.jpg"
    if not plate.exists():
        print(f"판이 없다: {plate}")
        return 1
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    size = Image.open(plate).size
    print(f"판: {plate.name} {size[0]}x{size[1]}")
    started = time.time()
    raw = _run_dsine(args.api, _upload(args.api, plate), args.resolution)
    print(f"DSINE {time.time() - started:.1f}초")

    estimated = Image.open(io.BytesIO(raw)).convert("RGB").resize(size, Image.LANCZOS)
    normal = np.asarray(estimated).astype(np.float64) / 255.0 * 2.0 - 1.0
    normal /= np.linalg.norm(normal, axis=2, keepdims=True) + 1e-8

    def save(image: np.ndarray, suffix: str) -> None:
        path = out / f"{room.name}{suffix}.png"
        Image.fromarray(((image + 1.0) / 2.0 * 255.0).clip(0, 255).astype(np.uint8)).save(path)
        print(f"적었다: {path}")

    save(normal, ".normal")
    fixed = _stand_floor_up(normal)
    save(fixed, ".normal_fixed")

    floor_share = 100.0 * (normal[..., 1] > _FLOOR_FROM).mean()
    print(f"  바닥으로 본 화소 {floor_share:.1f}%")
    print(f"  바닥 평균 N  {normal[800:, :].reshape(-1, 3).mean(axis=0).round(2)}"
          f"  ->  {fixed[800:, :].reshape(-1, 3).mean(axis=0).round(2)}")
    print("실험대에서 `7` 로 돌려 보면 된다.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
