"""컨셉 다섯을 **같은 순간**에 나란히 놓은 비교 GIF 를 만든다.

    python tools/make_compare_gif.py .renders .renders/compare.gif

키로 넘기며 보는 것과 별개로 필요하다. 넷 이상을 기억으로 견주면 마지막에 본 것이
이기기 때문이다. 다섯이 **같은 대본 시각**을 각자 어떻게 다루는지 한 화면에 세우면
차이가 가장 압축된다 — 커서가 닿는 순간, 누르는 순간이 다섯 줄에서 동시에 일어난다.

각 줄은 대본을 받는 판과 그 아래 idle 판 하나를 함께 자른다. 「가만히 있을 때도
죽었는지」가 비교에서도 보여야 하기 때문이다.
"""

import glob
import os
import sys

from PIL import Image, ImageDraw, ImageFont

FPS = 25

## 대본을 받는 판과 아래 idle 판 하나가 들어오는 창.
CROP = (250, 170, 720, 330)

LABEL_HEIGHT = 26
FONT_PATH = "assets/fonts/song_myung/SongMyung-Regular.ttf"

## 이름과 한 줄 요약. 그림만으로는 무엇이 축인지 안 보인다.
CONCEPTS = [
    ("slam", "SLAM", "들이받는다 - 오버슛 - 색 반전"),
    ("shear", "SHEAR", "공간이 끊긴다 - 조각이 어긋난다"),
    ("hold", "HOLD", "시간이 끊긴다 - 눌림은 완전 정지"),
    ("squash", "SQUASH", "부피가 보존된다 - 모양만 바뀐다"),
    ("afterimage", "AFTERIMAGE", "잔상이 상태다 - 늘 갈라져 있다"),
]


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: make_compare_gif.py <프레임 폴더> <내보낼 gif> [프레임 간격]")
        return 2
    folder, out = sys.argv[1], sys.argv[2]
    stride = int(sys.argv[3]) if len(sys.argv) > 3 else 2

    try:
        font = ImageFont.truetype(FONT_PATH, 15)
    except OSError:
        font = ImageFont.load_default()

    tracks = []
    for key, name, blurb in CONCEPTS:
        names = sorted(glob.glob(os.path.join(folder, f"{key}_f*.png")))
        if not names:
            print(f"건너뜀 - 프레임이 없다: {key}")
            continue
        tracks.append((name, blurb, names))
    if not tracks:
        print("쓸 프레임이 하나도 없다")
        return 1

    count = min(len(names) for _, _, names in tracks)
    width = CROP[2] - CROP[0]
    height = CROP[3] - CROP[1]
    row = height + LABEL_HEIGHT

    frames = []
    for index in range(0, count, stride):
        sheet = Image.new("RGB", (width, row * len(tracks)), (12, 12, 14))
        draw = ImageDraw.Draw(sheet)
        for i, (name, blurb, names) in enumerate(tracks):
            top = i * row
            draw.text((14, top + 5), name, font=font, fill=(242, 242, 236))
            draw.text(
                (14 + max(96, len(name) * 9), top + 6), blurb, font=font, fill=(122, 122, 130)
            )
            sheet.paste(Image.open(names[index]).convert("RGB").crop(CROP), (0, top + LABEL_HEIGHT))
            # 줄을 가르는 선. 없으면 다섯 화면이 한 덩어리로 뭉쳐 보인다.
            draw.line([(0, top), (width, top)], fill=(38, 38, 44))
        frames.append(sheet.convert("P", palette=Image.ADAPTIVE, colors=160))

    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    frames[0].save(
        out,
        save_all=True,
        append_images=frames[1:],
        duration=round(1000 / FPS * stride),
        loop=0,
        optimize=True,
        disposal=2,
    )
    print(f"{out}  {len(frames)}프레임  {os.path.getsize(out)/1024:.0f} KB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
