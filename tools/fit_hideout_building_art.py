"""생성기가 뽑은 큰 정사각 그림을 **아지트 건물 캔버스에 맞춰 자른다.**

    python tools/fit_hideout_building_art.py <원본.png> --facility workshop --storeys 2
    python tools/fit_hideout_building_art.py .in/*.png --all        # 이름으로 알아서 고른다

규격의 출처는 `docs/design/hideout-building-art.json` 이고, 그것은
`tools/dump_hideout_art_spec.gd` 가 코어에서 뽑은 것이다. **여기서 숫자를 다시 적지 않는다.**

## 자르는 기준 — 받는 쪽이 정한다 (docs/design/30-hideout.md §30.10.7)

1. **세로: 알파의 맨 아래를 기준점(바닥 마름모 아래꼭짓점)에 맞춘다.**
   경계상자의 위쪽은 안 본다 — 굴뚝 · 깃발 · 간판이 위로 자라도 접지가 안 움직여야 한다.
   기준점을 밑변으로 잡은 이유와 같다 (§30.10.2).
2. **가로: 알파 경계상자의 가운데를 캔버스 가운데에 맞춘다.**
   바닥 마름모의 **중심은 발자국이 무엇이든 캔버스 한가운데**다 — 기준점과 달리
   2x3 과 3x2 에서도 가운데다. 그래서 가로만은 가운데 맞춤이 옳다.
3. **배율: 알파 경계상자의 가로가 바닥 마름모 가로와 같아지게.**
   세로로 맞추지 않는 이유는 **세로가 못 믿을 값**이기 때문이다(첨탑 하나에 통째로 흔들린다).
   가로로 삐져나오면 **옆 칸을 침범한다** — 그것이 실제로 곤란한 실패다.

높이가 상한을 넘으면 **자동으로 줄이지 않고 실패로 알린다.** 조용히 맞춰 두면
2층 상한(§30.10.3)이 그림에서만 깨진 채로 굴러간다.

## 손보정

`docs/design/samples/hideout_art/fit_overrides.json` 에 파일별로 적으면 그만큼 더 민다.

    { "workshop_2l.png": { "dx": 0, "dy": -3, "scale": 1.02 } }

자동 규칙이 어떤 그림에서도 맞을 리 없다. **틀린 것을 규칙으로 감추지 말고 여기 적는다.**
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

try:
    import numpy as np
    from PIL import Image
except ImportError:  # pragma: no cover
    sys.exit("Pillow 와 numpy 가 필요하다:  pip install pillow numpy")

# 콘솔이 cp949 인 기계가 있다. 한글 로그가 터지면 도구가 통째로 죽는다.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPEC = ROOT / "docs" / "design" / "hideout-building-art.json"
OUT_DIR = ROOT / "docs" / "design" / "samples" / "hideout_art"
FITTED_DIR = OUT_DIR / "fitted"
OVERRIDES = OUT_DIR / "fit_overrides.json"

# 배경으로 볼 색과의 거리. 생성기 배경은 평평해서 넉넉히 잡아도 건물을 안 먹는다.
KEY_TOLERANCE = 26

# 가장자리에 잉크가 남아 있으면 배경 키잉이 실패한 것이다.
EDGE_INK_LIMIT = 0.02


def load_spec() -> dict:
    if not SPEC.exists():
        sys.exit(
            f"{SPEC} 가 없다. 먼저 돌려라:\n"
            "  godot --headless --path . -s res://tools/dump_hideout_art_spec.gd"
        )
    return json.loads(SPEC.read_text(encoding="utf-8"))


def keyed_alpha(image: Image.Image) -> Image.Image:
    """배경을 지운다. 이미 알파가 있으면 그대로 믿는다."""
    image = image.convert("RGBA")
    alpha = image.getchannel("A")
    if alpha.getextrema()[0] < 255:
        return image

    data = np.asarray(image).astype(int)
    height, width, _ = data.shape
    corners = np.stack(
        [data[0, 0, :3], data[0, width - 1, :3], data[height - 1, 0, :3], data[height - 1, width - 1, :3]]
    )
    key = corners.mean(axis=0)
    distance = np.abs(data[:, :, :3] - key).sum(axis=2)
    data[:, :, 3] = np.where(distance <= KEY_TOLERANCE * 3, 0, data[:, :, 3])
    return Image.fromarray(data.astype(np.uint8), "RGBA")


def edge_ink_ratio(image: Image.Image) -> float:
    """캔버스 가장자리에 남은 잉크 비율. 0 이 아니면 잘려 나간 것이 있다."""
    alpha = np.asarray(image.getchannel("A"))
    border = np.concatenate([alpha[0, :], alpha[-1, :], alpha[:, 0], alpha[:, -1]])
    return float((border > 8).mean())


def fit(source: pathlib.Path, entry: dict, nudge: dict) -> tuple[Image.Image, dict]:
    canvas_w, canvas_h = entry["canvas"]
    pivot_x, pivot_y = entry["pivot"]
    ground_w = entry["ground_size"][0]
    content_h = canvas_h - 2 * _margin(entry)

    art = keyed_alpha(Image.open(source))
    box = art.getchannel("A").getbbox()
    if box is None:
        raise ValueError("알파가 비어 있다 — 배경 키잉이 그림까지 먹었다")
    art = art.crop(box)

    scale = ground_w / art.width * float(nudge.get("scale", 1.0))
    sized = art.resize(
        (max(1, round(art.width * scale)), max(1, round(art.height * scale))),
        Image.LANCZOS,
    )

    left = round(canvas_w / 2 - sized.width / 2) + int(nudge.get("dx", 0))
    top = pivot_y - sized.height + int(nudge.get("dy", 0))

    # 넘치면 **넘친 자리에서** 잘라야 한다. 0 으로 당겨 붙이면 접지가 조용히 어긋나고,
    # 그러면 «맞지 않는다» 가 «조금 이상하다» 로 바뀌어 아무도 안 고친다.
    pad = max(0, -left, -top, left + sized.width - canvas_w, top + sized.height - canvas_h)
    roomy = Image.new("RGBA", (canvas_w + pad * 2, canvas_h + pad * 2), (0, 0, 0, 0))
    roomy.alpha_composite(sized, (left + pad, top + pad))
    canvas = roomy.crop((pad, pad, pad + canvas_w, pad + canvas_h))

    report = {
        "source": source.name,
        "source_size": list(Image.open(source).size),
        "ink_bbox_in_source": list(box),
        "scale": round(scale, 4),
        "placed_at": [left, top],
        "fitted_height_px": sized.height,
        "content_height_px": content_h,
        "over_height_cap": sized.height > content_h,
        "edge_ink_ratio": round(edge_ink_ratio(canvas), 4),
    }
    return canvas, report


def _margin(entry: dict) -> int:
    return (entry["canvas"][0] - entry["ground_size"][0]) // 2


def pick_entry(spec: dict, facility: str, storeys: int) -> dict:
    for entry in spec["buildings"]:
        if entry["file"] == f"{facility}_{storeys}l.png":
            return entry
    names = sorted({e["file"].rsplit("_", 1)[0] for e in spec["buildings"]})
    sys.exit(f"모르는 건물이다: {facility} {storeys}층. 있는 것: {', '.join(names)}")


def main() -> int:
    parser = argparse.ArgumentParser(description="생성 그림을 아지트 건물 캔버스에 맞춘다")
    parser.add_argument("sources", nargs="+", type=pathlib.Path)
    parser.add_argument("--facility", default=None, help="workshop · intel_room · contact_point")
    parser.add_argument("--storeys", type=int, default=1)
    args = parser.parse_args()

    spec = load_spec()
    overrides = json.loads(OVERRIDES.read_text(encoding="utf-8")) if OVERRIDES.exists() else {}
    FITTED_DIR.mkdir(parents=True, exist_ok=True)

    failures = 0
    for source in args.sources:
        facility = args.facility or source.stem.rsplit("_", 1)[0]
        entry = pick_entry(spec, facility, args.storeys)
        canvas, report = fit(source, entry, overrides.get(entry["file"], {}))
        out = FITTED_DIR / entry["file"]
        canvas.save(out)

        notes = []
        if report["over_height_cap"]:
            notes.append(
                "캔버스를 넘는다 %d > %d — 몸통을 낮추거나 굴뚝을 빼라"
                % (report["fitted_height_px"], report["content_height_px"])
            )
            failures += 1
        elif report["edge_ink_ratio"] > EDGE_INK_LIMIT:
            notes.append("가장자리에 잉크 %.1f%%" % (report["edge_ink_ratio"] * 100))
            failures += 1
        state = "  ".join(notes) if notes else "맞음"
        print(f"[fit] {out.relative_to(ROOT)}  x{report['scale']}  {state}")
        (FITTED_DIR / (out.stem + ".json")).write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )

    if failures:
        print("[fit] %d 건이 규격을 벗어났다. 손보정하거나 다시 뽑아라" % failures)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
