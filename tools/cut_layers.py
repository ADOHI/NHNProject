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

import numpy as np
from PIL import Image
from scipy import ndimage

ROOM_STUDIO = r"C:\Users\adohi\2dAnim\room-studio\src"
if ROOM_STUDIO not in sys.path:
    sys.path.insert(0, ROOM_STUDIO)

from room_studio import compose  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "scene")

#: 컷아웃은 곧바로 기능 폴더 안으로 들어간다.
#:
#: 최상위 `assets/` 가 아닌 이유는 컨벤션이 기준을 명시하기 때문이다 —
#: *사용처가 둘 이상이면 `assets/`, 하나면 기능 폴더 안* (docs/conventions.md §1).
#: 이 열 장은 소비처가 타이틀 하나뿐이다.
DST = os.path.join(HERE, os.pardir, "src", "ui", "title", "art")

#: 물건 하나만 남길 겹. 모델이 크로마 위에 부스러기를 흩뿌리는 일이 있어서,
#: 가장 큰 덩어리만 남긴다. 배경·전경은 원래 여러 덩어리라 제외한다.
SINGLE = {
    "hoard", "hunter_back", "hunter_front", "hunter_left", "hunter_right",
    "demon_a", "demon_b", "demon_c",
}

#: 크로마를 빼지 않는 겹. 배경은 화면을 꽉 채우는 그림이다.
OPAQUE = {"backdrop"}

#: **잘라내지 않는 겹.** `trim_alpha` 는 알파 경계로 캔버스를 줄이는데,
#: 화면을 꽉 채우는 겹(`span` 0)은 그러면 남은 조각이 화면 전체로 늘어난다.
#: 전경이 세로로 1.9배 늘어나 있던 원인이 이것이었다
#: (docs/design/21-title.md §21.13.11). **전경은 자리가 곧 의미다.**
NO_TRIM = {"foreground"}

#: 가장자리를 물릴 겹과 그 폭(물체 짧은 변에 대한 비율).
#:
#: 컷아웃 경계가 칼로 자른 것처럼 서 있으면 오려 붙인 스티커로 보인다.
#: **원경이 근경만큼 또렷하면 깊이가 죽는다** (§21.13.10).
#: 이건 계단 없애기가 아니라 **공기 원근**이라 2~3px 이 아니라 수십 px 짜리 띠다.
FEATHER = {"demon_a": 0.06, "demon_b": 0.06, "demon_c": 0.06}

#: 가장자리에 남기는 알파. **0 이 아니다.**
#:
#: 처음에 0 까지 떨어뜨렸더니 팔다리와 뿔이 통째로 지워졌다 — 굵기가 띠의 두 배가
#: 안 되는 부위는 한가운데까지 경사에 먹힌다. 화면에서 악마가 벽에 번진 얼룩으로
#: 보이고 **시선의 사슬이 끊겼다.** 요구는 "반투명"이지 "없앰"이 아니다.
FEATHER_EDGE_ALPHA = 0.35


def feather_edge(img: Image.Image, band: float) -> Image.Image:
    """실루엣 **안쪽으로** 들어가는 알파 경사를 넣는다.

    흐리기(blur)를 쓰지 않는다. 흐리기는 경계 바깥으로도 번져서 실루엣이 커지고,
    그러면 물체가 부풀어 보인다. 거리 변환은 원래 실루엣 안쪽만 깎는다.

    가장자리에서 `FEATHER_EDGE_ALPHA` 이고 `band` 만큼 안으로 들어가면 1 이 된다.
    사이는 smoothstep — 선형이면 띠가 끝나는 자리에 눈에 보이는 선이 남는다.
    """
    a = np.asarray(img.split()[-1], dtype=np.float32) / 255.0
    if a.max() <= 0.0:
        return img
    width = max(1.0, band * min(img.width, img.height))
    # 거리 변환은 0/1 을 받는다. 반투명 가장자리는 이미 물체 안쪽으로 친다.
    inside = (a > 0.5).astype(np.uint8)
    # 캔버스 테두리에 닿은 물체가 그 변에서 깎이지 않게 한 겹 덧대고 잰다.
    padded = np.pad(inside, 1)
    dist = ndimage.distance_transform_edt(padded)[1:-1, 1:-1]
    t = np.clip(dist / width, 0.0, 1.0)
    smooth = t * t * (3.0 - 2.0 * t)
    ramp = FEATHER_EDGE_ALPHA + (1.0 - FEATHER_EDGE_ALPHA) * smooth
    out = img.copy()
    out.putalpha(Image.fromarray(np.uint8(np.clip(a * ramp, 0.0, 1.0) * 255.0 + 0.5)))
    return out


def cut(name: str) -> str | None:
    src = os.path.join(SRC, name + ".png")
    if not os.path.exists(src):
        print("  (없음) " + src)
        return None
    if name in OPAQUE:
        out = Image.open(src).convert("RGBA")
    else:
        # chroma_key 는 이미지가 아니라 **경로**를 받는다. 안에서 직접 연다.
        out = compose.chroma_key(src)
        if name in SINGLE:
            out = compose.keep_main_object(out)
        if name not in NO_TRIM:
            out = compose.trim_alpha(out)
        if name in FEATHER:
            out = feather_edge(out, FEATHER[name])
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
