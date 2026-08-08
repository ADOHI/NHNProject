"""마젠타 크로마를 빼고 알파 PNG 로 만든다.

**직접 구현하지 않는다.** room-studio 레인이 같은 문제를 이미 풀었고, 실측으로
얻은 상수와 함정 회피가 그 모듈 안에 들어 있다. 여기서 다시 짜면 그 실측이 버려진다.

그쪽이 알아낸 것 중 여기서도 그대로 걸리는 것 둘:

  1. **고정 임계는 반드시 깨진다.** 모델이 칠하는 분홍이 그림마다 다르다
     (클라우드 (166,74,133) vs 로컬 (221,101,137)). `estimate_background()` 가
     그림에서 배경 색도를 스스로 찾는다.
  2. **크로마가 있는지 없는지를 색으로 판정하면 틀린다.** 색의 여유는 그림마다
     2.5배 흔들려서 셋을 못 가른다. **면적**으로는 20배 차이로 갈린다 —
     크로마 배경은 화면의 30~45%, 우연한 분홍기는 2% 미만.
     그래서 배경 없는 겹(backdrop)에 이 스크립트를 그냥 돌려도 안전하다.
     크로마가 없다고 판정되면 키를 아예 빼지 않는다.
"""

from __future__ import annotations

import argparse
import os
import sys

from PIL import Image

ROOM_STUDIO = r"C:\Users\adohi\2dAnim\room-studio\src"
if ROOM_STUDIO not in sys.path:
    sys.path.insert(0, ROOM_STUDIO)

from room_studio import compose  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "scene")
DST = os.path.join(HERE, "cutout")

#: 물건 하나만 남길 겹. 모델이 크로마 위에 부스러기를 흩뿌리는 일이 있어서,
#: 가장 큰 덩어리만 남긴다. 배경·전경은 원래 여러 덩어리라 제외한다.
SINGLE = {
    "hoard", "hunter_back", "hunter_front", "hunter_left", "hunter_right",
    "demon_a", "demon_b", "demon_c",
}

#: 크로마를 빼지 않는 겹. 배경은 화면을 꽉 채우는 그림이다.
OPAQUE = {"backdrop"}


def cut(name: str) -> str | None:
    src = os.path.join(SRC, name + ".png")
    if not os.path.exists(src):
        print("  (없음) " + src)
        return None
    img = Image.open(src).convert("RGB")
    if name in OPAQUE:
        out = img.convert("RGBA")
    else:
        out = compose.chroma_key(img)
        if name in SINGLE:
            out = compose.keep_main_object(out)
        out = compose.trim_alpha(out)
    os.makedirs(DST, exist_ok=True)
    dest = os.path.join(DST, name + ".png")
    out.save(dest)
    alpha = out.split()[-1]
    covered = sum(alpha.histogram()[8:]) / float(out.width * out.height)
    print("%-14s %4dx%-4d  불투명 %5.1f%%  %s"
          % (name, out.width, out.height, covered * 100.0, dest))
    return dest


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    wanted = [n.strip() for n in args.only.split(",") if n.strip()]
    if not wanted:
        wanted = sorted(
            f[:-4] for f in os.listdir(SRC)
            if f.endswith(".png") and not f.startswith("full_")
        ) if os.path.isdir(SRC) else []
    for name in wanted:
        cut(name)


if __name__ == "__main__":
    main()
