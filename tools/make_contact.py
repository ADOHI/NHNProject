"""팔레트별 정지 컷을 **한 장**으로 붙인다.

    python tools/make_contact.py .renders/54-vats .renders/54-vats.png 3

색을 여러 벌 견주는 판에서는 **한 번에 보이는 것**이 판정의 전부다.
파일 여섯 장을 차례로 여는 동안 앞의 것이 눈에서 사라지고, 그러면 비교가 아니라
여섯 번의 첫인상이 된다. 붙여 놓으면 **옆칸이 기준**이 되어 세기 차이가 바로 보인다.

`capture_pop.gd` 가 `<앞머리>_<슬러그>.png` 로 저장하므로 그 규칙만 안다.
슬러그 순서는 `HoloPalette._SLUGS` 순서이므로 여기 적어 두지 않고 **파일 이름 순서**가
아니라 인자로 받은 순서를 쓴다 — 이름 순으로 정렬하면 팔레트 차례가 뒤섞인다.
"""

import os
import sys

from PIL import Image

# `HoloPalette._SLUGS` 와 같은 차례여야 한다. 화면의 차례가 곧 판정의 차례다.
SLUGS = ["dancheong", "hemlock", "gore", "bazaar", "voltearth", "hothouse"]

# 칸 사이 여백(px). 바탕이 벌마다 다르므로 **어두운 띠로 갈라 놓아야**
# 옆칸의 바탕이 자기 칸의 일부로 안 읽힌다.
MARGIN = 10
BACKING = (16, 16, 18)


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: make_contact.py <앞머리> <내보낼 png> [칸 수] [꼬리표,쉼표]")
        return 2
    prefix, out = sys.argv[1], sys.argv[2]
    cols = int(sys.argv[3]) if len(sys.argv) > 3 else 3
    # 네 번째 인자로 꼬리표를 직접 줄 수 있다 — 팔레트가 아니라 **단 수**를 견주는
    # 판에서는 붙일 것이 `_t1.._t5` 라서 슬러그 목록이 안 맞는다.
    tags = sys.argv[4].split(",") if len(sys.argv) > 4 else SLUGS

    tiles = []
    for slug in tags:
        name = f"{prefix}_{slug}.png"
        if not os.path.exists(name):
            print(f"없다: {name}")
            return 1
        tiles.append(Image.open(name).convert("RGB"))

    wide, tall = tiles[0].size
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new(
        "RGB",
        (cols * wide + (cols + 1) * MARGIN, rows * tall + (rows + 1) * MARGIN),
        BACKING,
    )
    for i, tile in enumerate(tiles):
        x = MARGIN + (i % cols) * (wide + MARGIN)
        y = MARGIN + (i // cols) * (tall + MARGIN)
        sheet.paste(tile, (x, y))

    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    sheet.save(out)
    print(f"{out}  {sheet.width}x{sheet.height}  {os.path.getsize(out)/1024:.0f} KB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
