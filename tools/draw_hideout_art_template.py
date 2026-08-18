"""건물 그림의 밑그림(템플릿)을 그린다.

    python tools/draw_hideout_art_template.py

`docs/design/hideout-building-art.json` 을 읽어 건물 종류마다 PNG 한 장을 낸다.
그 JSON 은 `tools/dump_hideout_art_spec.gd` 가 코어에서 뽑은 것이다 —
**숫자를 여기서 다시 적지 않는다.** 적으면 갈리고, 갈린 것은 그림이 도착한 날에야 드러난다.

나오는 것은 `docs/design/samples/hideout_art/` 안의 한 장씩과, 전부 모은 한 장이다.
그림 그리는 사람은 이 위에 건물을 얹으면 된다.

- **회색 마름모** — 땅에 닿는 자리. 여기를 벗어나면 옆 칸을 침범한다
- **십자** — 기준점. 바닥 마름모의 아래꼭짓점이고 가운데가 아니다
- **가로 점선** — 층 눈금. 맨 위 선이 높이 상한이다
- **왼쪽 아래 면** — 문이 붙는 벽. 한 방향뿐이다
"""

from __future__ import annotations

import json
import pathlib
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:  # pragma: no cover - 실행 환경 안내
    sys.exit("Pillow 가 필요하다:  pip install pillow")

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPEC = ROOT / "docs" / "design" / "hideout-building-art.json"
OUT_DIR = ROOT / "docs" / "design" / "samples" / "hideout_art"

# 기본 폰트에는 한글이 없다. 상자만 찍히면 발주서를 못 읽는다.
FONT_PATH = ROOT / "assets" / "fonts" / "song_myung" / "SongMyung-Regular.ttf"


def load_font(size: int) -> ImageFont.ImageFont:
    if FONT_PATH.exists():
        return ImageFont.truetype(str(FONT_PATH), size)
    return ImageFont.load_default()

CHECKER_A = (46, 50, 60, 255)
CHECKER_B = (38, 42, 51, 255)
GROUND_FILL = (86, 94, 112, 190)
GROUND_EDGE = (196, 208, 232, 255)
STOREY_LINE = (120, 132, 158, 255)
CAP_LINE = (232, 132, 120, 255)
PIVOT = (255, 214, 92, 255)
DOOR_FACE = (108, 176, 226, 90)
TEXT = (226, 232, 244, 255)


def checkerboard(size: tuple[int, int], step: int = 8) -> Image.Image:
    """투명한 곳이 어디인지 보이게 하는 바둑판. 여백을 눈으로 재려는 것이다."""
    image = Image.new("RGBA", size, CHECKER_A)
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], step):
        for x in range(0, size[0], step):
            if (x // step + y // step) % 2:
                draw.rectangle([x, y, x + step - 1, y + step - 1], fill=CHECKER_B)
    return image


def draw_template(entry: dict, rules: dict) -> Image.Image:
    width, height = entry["canvas"]
    pivot_x, pivot_y = entry["pivot"]
    polygon = [tuple(p) for p in entry["ground_polygon_north_east_south_west"]]
    north, east, south, west = polygon

    image = checkerboard((width, height))
    draw = ImageDraw.Draw(image, "RGBA")

    # 문이 붙는 벽 — 서쪽에서 남쪽으로 가는 면. 한 방향뿐이다.
    storey_px = int(rules["storey_height_px"])
    lift = storey_px * entry["storeys"]
    draw.polygon(
        [west, south, (south[0], south[1] - lift), (west[0], west[1] - lift)],
        fill=DOOR_FACE,
    )

    # 층 눈금. 맨 위가 상한이다.
    for storey in range(1, entry["storeys"] + 1):
        top = pivot_y - storey * storey_px
        is_cap = storey == entry["storeys"]
        colour = CAP_LINE if is_cap else STOREY_LINE
        for x in range(0, width, 6):
            draw.line([(x, top), (x + 3, top)], fill=colour, width=1)
        draw.text((3, top + 2), f"{storey}F", fill=colour, font=load_font(11))

    # 땅에 닿는 자리.
    draw.polygon(polygon, fill=GROUND_FILL, outline=GROUND_EDGE)

    # 기준점 십자.
    draw.line([(pivot_x - 9, pivot_y), (pivot_x + 9, pivot_y)], fill=PIVOT, width=2)
    draw.line([(pivot_x, pivot_y - 9), (pivot_x, pivot_y + 9)], fill=PIVOT, width=2)

    draw.rectangle([0, 0, width - 1, height - 1], outline=(150, 160, 180, 255))
    return image


def contact_sheet(cards: list[tuple[str, Image.Image]]) -> Image.Image:
    pad, label_h = 14, 18
    cell_w = max(image.width for _, image in cards) + pad * 2
    cell_h = max(image.height for _, image in cards) + pad * 2 + label_h
    sheet = Image.new("RGBA", (cell_w * len(cards), cell_h), (24, 26, 32, 255))
    draw = ImageDraw.Draw(sheet)
    font = load_font(13)
    for index, (name, image) in enumerate(cards):
        x = index * cell_w + pad
        sheet.alpha_composite(image, (x, pad + label_h))
        draw.text((x, 3), name, fill=TEXT, font=font)
    return sheet


def main() -> int:
    if not SPEC.exists():
        sys.exit(
            f"{SPEC} 가 없다. 먼저 돌려라:\n"
            "  godot --headless --path . -s res://tools/dump_hideout_art_spec.gd"
        )
    spec = json.loads(SPEC.read_text(encoding="utf-8"))
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    cards: list[tuple[str, Image.Image]] = []
    for entry in spec["buildings"]:
        image = draw_template(entry, spec["rules"])
        path = OUT_DIR / entry["file"]
        image.save(path)
        name = f"{entry['label']} {entry['storeys']}F  {entry['canvas'][0]}x{entry['canvas'][1]}"
        cards.append((name, image))
        print(f"[template] {path.relative_to(ROOT)}  {image.width}x{image.height}")

    sheet_path = OUT_DIR / "_all.png"
    contact_sheet(cards).save(sheet_path)
    print(f"[template] {sheet_path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
