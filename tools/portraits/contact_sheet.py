#!/usr/bin/env python
"""나란히 놓고 본다 — **화풍이 타이틀과 맞는지는 사람이 눈으로 판정한다.**

    python tools/portraits/contact_sheet.py .captures/portraits/sian

숫자로 판정할 수 없는 것이 하나 있다. `check_portraits.py` 는 「배경이 장면이 됐나」와
「증명사진이 됐나」를 재지만, **「타이틀의 그 사람들과 같은 세계의 사람인가」는 못 잰다.**
그건 심사자가 두 그림을 나란히 놓고 보는 수밖에 없다 (`21-title.md` §21.11 이 여섯 판
내내 그렇게 했다).

그래서 이 도구가 만드는 판은 위가 **타이틀의 확정 화풍**이고 아래가 **이번 초상**이다.

    1행  타이틀의 인간 넷 — 판 전체
    2행  같은 넷의 머리·어깨 크롭 — 초상과 같은 구도로 놓아야 비교가 성립한다
    나머지 계열마다 한 행

**타이틀 워크트리는 읽기만 한다.** 그 레인의 판을 고치지 않는다.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import console  # noqa: E402
from prompts import DISCIPLINES, IMPRESSIONS  # noqa: E402

console.utf8()

#: 타이틀 레인의 워크트리. **읽기만 한다.**
TITLE_ART = Path(r"C:\Users\adohi\NHNProject\.claude\worktrees"
                 r"\agent-ac4676e84365826bf\src\ui\title\art")
HUNTERS = ["hunter_left", "hunter_front", "hunter_right", "hunter_back"]

TILE = 256
PAD = 8
LABEL_H = 18
#: 컷아웃의 투명한 자리를 이 색으로 깐다. 초상 배경과 비슷한 어두운 청록이라
#: 두 행의 밝기가 비슷해져서 **화풍 차이만 눈에 남는다.**
BACKING = (26, 38, 44)
SHEET_BG = (18, 20, 24)


def _font(size: int) -> ImageFont.ImageFont:
    for path in (r"C:\Windows\Fonts\malgun.ttf", r"C:\Windows\Fonts\arial.ttf"):
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                pass
    return ImageFont.load_default()


def _flatten(im: Image.Image) -> Image.Image:
    """알파를 배경색 위에 깐다. 컷아웃 겹은 투명 배경이라 그냥 두면 검게 나온다."""
    im = im.convert("RGBA")
    out = Image.new("RGB", im.size, BACKING)
    out.paste(im, (0, 0), im)
    return out


def _head_crop(path: Path) -> Image.Image:
    """컷아웃 판에서 **머리·어깨 정사각**을 뽑는다.

    초상과 같은 구도로 놓아야 비교가 성립한다 — 전신과 흉상을 나란히 놓으면
    사람이 「화풍이 다르다」가 아니라 「크기가 다르다」를 본다.

    자리를 잡는 법: 알파 경계 상자를 구하고, **위쪽 4분의 1 행의 불투명 화소
    무게중심**을 머리의 가로 위치로 쓴다. 팔을 뻗은 겹에서도 머리는 위쪽에 있으므로
    이 방법이 자세와 무관하게 맞는다.
    """
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im)[:, :, 3] > 24
    ys, xs = np.nonzero(a)
    if not len(ys):
        return _flatten(im).resize((TILE, TILE), Image.LANCZOS)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    top = a[y0:y0 + max(1, (y1 - y0) // 4)]
    tys, txs = np.nonzero(top)
    cx = int(x0 + txs.mean()) if len(txs) else (x0 + x1) // 2

    side = int(min(x1 - x0, y1 - y0) * 0.52)
    left = max(0, min(im.width - side, cx - side // 2))
    top_y = max(0, y0 - side // 12)
    box = (left, top_y, left + side, min(im.height, top_y + side))
    return _flatten(im.crop(box)).resize((TILE, TILE), Image.LANCZOS)


def _tile(path: Path) -> Image.Image:
    return _flatten(Image.open(path)).resize((TILE, TILE), Image.LANCZOS)


def _row_of(folder: Path, discipline: str) -> list[Path]:
    """그 계열의 판을 인상 순서로 늘어놓는다. 순서가 곧 격자의 읽기 순서다."""
    order = {name: i for i, (name, *_r) in enumerate(IMPRESSIONS)}
    plates = [p for p in folder.glob(f"{discipline}_*.png")]

    def key(p: Path) -> tuple[int, str]:
        parts = p.stem.split("_")
        return (order.get(parts[1], 99), p.stem)

    return sorted(plates, key=key)


def build(folder: str, out: str) -> int:
    d = Path(folder)
    rows: list[tuple[str, list[Image.Image], list[str]]] = []

    if TITLE_ART.is_dir():
        full, crop, labels = [], [], []
        for h in HUNTERS:
            p = TITLE_ART / (h + ".png")
            if p.exists():
                full.append(_tile(p))
                crop.append(_head_crop(p))
                labels.append(h.replace("hunter_", ""))
        if full:
            rows.append(("타이틀 — 확정 화풍 (판 전체)", full, labels))
            rows.append(("타이틀 — 머리·어깨 크롭 (초상과 같은 구도)", crop, labels))
    else:
        print(f"  [!] 타이틀 판을 못 찾았다: {TITLE_ART}", file=sys.stderr)

    for name, ko, _p in DISCIPLINES:
        plates = _row_of(d, name)
        if plates:
            rows.append((f"{ko} ({name})", [_tile(p) for p in plates],
                         [p.stem.split("_", 1)[1] for p in plates]))

    if not rows:
        print(f"  [x] 놓을 판이 없다: {d}", file=sys.stderr)
        return 1

    cols = max(len(r[1]) for r in rows)
    head = 26
    w = PAD + cols * (TILE + PAD)
    h = PAD + sum(head + TILE + LABEL_H + PAD for _r in rows)
    sheet = Image.new("RGB", (w, h), SHEET_BG)
    draw = ImageDraw.Draw(sheet)
    f_head, f_lab = _font(15), _font(11)

    y = PAD
    for title, tiles, labels in rows:
        draw.text((PAD, y + 5), title, font=f_head, fill=(232, 226, 214))
        y += head
        for i, (tile, lab) in enumerate(zip(tiles, labels)):
            x = PAD + i * (TILE + PAD)
            sheet.paste(tile, (x, y))
            draw.text((x + 2, y + TILE + 3), lab, font=f_lab, fill=(160, 170, 178))
        y += TILE + LABEL_H + PAD

    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    sheet.save(out)
    print(f"  {w}×{h} · 행 {len(rows)}개 · {out}")
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="contact_sheet", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("folder", help="판이 있는 폴더")
    ap.add_argument("--out", default="", help="기본: <폴더>/_sheet.png")
    args = ap.parse_args(argv)
    out = args.out or str(Path(args.folder) / "_sheet.png")
    return build(args.folder, out)


if __name__ == "__main__":
    raise SystemExit(main())
