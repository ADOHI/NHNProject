"""생성기가 뽑은 그림을 **아지트 격자 바닥 마름모에 맞춰** 넣는다.

    python tools/fit_hideout_building_art.py <원본.png> --facility workshop --storeys 1
    python tools/fit_hideout_building_art.py <원본.png> --facility workshop --storeys 1 --mode bbox

## 기본 모드: quad (꼭짓점 → 호모그래피)

1. 알파에서 **바닥 면 네 꼭짓점**(북·동·남·서)을 찾는다.
2. 코어 발주서의 `ground_polygon`(격자 마름모)으로 **투시 변환**한다.
3. 건물 전체가 같은 변환을 받아 바닥이 칸에 앉고 비율이 격자에 맞춰진다.

## 폴백 모드: bbox (옛 방식)

가로 스케일 + 접지만. 각도가 틀린 장에서는 바닥이 안 맞는다. 디버그용.

규격: `docs/design/hideout-building-art.json` (dump_hideout_art_spec.gd).
손보정: `fit_overrides.json` — quad 모드에서는 dx/dy/scale 을 변환 뒤 미세 이동에 쓴다.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

try:
    import numpy as np
    from PIL import Image, ImageDraw
except ImportError:  # pragma: no cover
    sys.exit("Pillow 와 numpy 가 필요하다:  pip install pillow numpy")

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPEC = ROOT / "docs" / "design" / "hideout-building-art.json"
OUT_DIR = ROOT / "docs" / "design" / "samples" / "hideout_art"
FITTED_DIR = OUT_DIR / "fitted"
OVERRIDES = OUT_DIR / "fit_overrides.json"

KEY_TOLERANCE = 26
EDGE_INK_LIMIT = 0.02
# 실루엣 아래쪽 이 비율만 바닥 후보로 본다 (지붕·벽 상단 제외).
BASE_BAND = 0.42


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
        [
            data[0, 0, :3],
            data[0, width - 1, :3],
            data[height - 1, 0, :3],
            data[height - 1, width - 1, :3],
        ]
    )
    key = corners.mean(axis=0)
    distance = np.abs(data[:, :, :3] - key).sum(axis=2)
    data[:, :, 3] = np.where(distance <= KEY_TOLERANCE * 3, 0, data[:, :, 3])
    return Image.fromarray(data.astype(np.uint8), "RGBA")


def edge_ink_ratio(image: Image.Image) -> float:
    alpha = np.asarray(image.getchannel("A"))
    border = np.concatenate([alpha[0, :], alpha[-1, :], alpha[:, 0], alpha[:, -1]])
    return float((border > 8).mean())


def _opaque_mask(image: Image.Image) -> np.ndarray:
    return np.asarray(image.getchannel("A")) > 8


def detect_base_quad(image: Image.Image) -> list[tuple[float, float]]:
    """알파 실루엣에서 바닥 마름모 네 점. 순서: 북·동·남·서.

    아이소 박스 건물 실루엣은 남단에서 대각으로 벌어지다가(바닥 앞 빗변)
    어느 높이에서 **세로 벽**으로 꺾인다. 그 꺾임이 동·서 꼭짓점이다.
    북은 동·서 중점에서 남과 대칭(마름모)으로 둔다.
    """
    mask = _opaque_mask(image)
    height, _width = mask.shape
    left_x = np.full(height, -1, dtype=np.int32)
    right_x = np.full(height, -1, dtype=np.int32)
    for y in range(height):
        xs = np.where(mask[y])[0]
        if xs.size == 0:
            continue
        left_x[y] = int(xs[0])
        right_x[y] = int(xs[-1])

    ys = np.where(left_x >= 0)[0]
    if ys.size < 8:
        raise ValueError("잉크가 너무 적다 — 바닥 꼭짓점을 못 찾는다")
    y_top, y_bot = int(ys[0]), int(ys[-1])
    span = max(1, y_bot - y_top)

    south = (
        (left_x[y_bot] + right_x[y_bot]) * 0.5,
        float(y_bot),
    )

    # 남에서 위로 올라가며 좌·우 윤곽이 '빗변 → 수직'으로 바뀌는 지점.
    west = _silhouette_corner(left_x, y_bot, y_top, side="left")
    east = _silhouette_corner(right_x, y_bot, y_top, side="right")
    # 동·서 높이가 어긋나면 평균 높이에 맞춤(같은 적도).
    y_eq = int(round(0.5 * (west[1] + east[1])))
    y_eq = int(np.clip(y_eq, y_top + 1, y_bot - 1))
    if left_x[y_eq] >= 0 and right_x[y_eq] >= 0:
        west = (float(left_x[y_eq]), float(y_eq))
        east = (float(right_x[y_eq]), float(y_eq))

    # 북: 적도 기준 남 대칭.
    y_n = int(round(y_eq - (y_bot - y_eq)))
    y_n = int(np.clip(y_n, y_top, y_eq - 1))
    if left_x[y_n] >= 0 and right_x[y_n] >= 0:
        x_n = 0.5 * (left_x[y_n] + right_x[y_n])
    else:
        x_n = 0.5 * (west[0] + east[0])
    north = (float(x_n), float(y_n))

    if south[1] <= north[1] + 2:
        raise ValueError("바닥 북·남이 구별되지 않는다")
    if east[0] <= west[0] + 2:
        raise ValueError("바닥 동·서가 구별되지 않는다")

    return [north, east, south, west]


def _silhouette_corner(
    edge_x: np.ndarray, y_bot: int, y_top: int, side: str
) -> tuple[float, float]:
    """남단에서 위로 가며 빗변이 수직으로 꺾이는 칸."""
    # 이동 평균으로 가로 변화량 보기.
    ys = list(range(y_bot, y_top, -1))
    xs = [int(edge_x[y]) for y in ys if edge_x[y] >= 0]
    ys = [y for y in ys if edge_x[y] >= 0]
    if len(ys) < 6:
        y = ys[len(ys) // 2]
        return float(edge_x[y]), float(y)

    # 연속 행 간 |dx|. 빗변은 큼(>=2), 수직 벽은 0~1.
    best_y = ys[len(ys) // 3]
    run_vertical = 0
    for i in range(1, len(ys)):
        dx = abs(xs[i] - xs[i - 1])
        if dx <= 1:
            run_vertical += 1
            # 빗변 구간을 지난 뒤 수직이 3행 이어지면 코너.
            if run_vertical >= 3 and i > 4:
                best_y = ys[i - 3]
                break
        else:
            run_vertical = 0
    return float(edge_x[best_y]), float(best_y)


def perspective_coeffs(
    src: list[tuple[float, float]], dst: list[tuple[float, float]]
) -> list[float]:
    """출력 좌표(dst) → 입력 좌표(src) 8계수. PIL PERSPECTIVE 용.

    출력의 dst[i] 픽셀이 입력의 src[i] 에서 샘플되게 한다.
    """
    matrix: list[list[float]] = []
    for (dx, dy), (sx, sy) in zip(dst, src):
        matrix.append([dx, dy, 1, 0, 0, 0, -sx * dx, -sx * dy])
        matrix.append([0, 0, 0, dx, dy, 1, -sy * dx, -sy * dy])
    a = np.asarray(matrix, dtype=np.float64)
    b = np.asarray(src, dtype=np.float64).reshape(8)
    # 정사각이 아닐 수 있어 최소자승.
    coeffs, *_ = np.linalg.lstsq(a, b, rcond=None)
    return coeffs.tolist()


def fit_quad(
    source: pathlib.Path, entry: dict, nudge: dict
) -> tuple[Image.Image, dict]:
    canvas_w, canvas_h = entry["canvas"]
    content_h = canvas_h - 2 * _margin(entry)
    ground = entry["ground_polygon_north_east_south_west"]
    dst = [(float(p[0]), float(p[1])) for p in ground]

    art = keyed_alpha(Image.open(source))
    box = art.getchannel("A").getbbox()
    if box is None:
        raise ValueError("알파가 비어 있다 — 배경 키잉이 그림까지 먹었다")
    full = art
    src_quad = detect_base_quad(full)
    # 크롭 + 꼭짓점 보정.
    left, top, right, bottom = box
    pad = 8
    left = max(0, left - pad)
    top = max(0, top - pad)
    right = min(full.width, right + pad)
    bottom = min(full.height, bottom + pad)
    cropped = full.crop((left, top, right, bottom))
    src_in_crop = [(x - left, y - top) for x, y in src_quad]

    # 손보정: 목표 마름모를 살짝 밀거나 키운다.
    scale = float(nudge.get("scale", 1.0))
    dx = float(nudge.get("dx", 0))
    dy = float(nudge.get("dy", 0))
    if scale != 1.0 or dx or dy:
        cx = sum(p[0] for p in dst) / 4.0
        cy = sum(p[1] for p in dst) / 4.0
        dst = [
            (cx + (x - cx) * scale + dx, cy + (y - cy) * scale + dy) for x, y in dst
        ]

    coeffs = perspective_coeffs(src_in_crop, dst)
    canvas = cropped.transform(
        (canvas_w, canvas_h),
        Image.Transform.PERSPECTIVE,
        coeffs,
        resample=Image.Resampling.BICUBIC,
        fillcolor=(0, 0, 0, 0),
    )
    if canvas.mode != "RGBA":
        canvas = canvas.convert("RGBA")

    # 변환 보간으로 가장자리에 번진 잉크를 한 번 닦는다.
    canvas = _clear_edge_bleed(canvas)

    ink = canvas.getchannel("A").getbbox()
    fitted_h = (ink[3] - ink[1]) if ink else 0

    report = {
        "mode": "quad",
        "source": source.name,
        "source_size": list(Image.open(source).size),
        "ink_bbox_in_source": list(box),
        "src_quad_nesw": [[round(float(x), 1), round(float(y), 1)] for x, y in src_quad],
        "dst_quad_nesw": [[round(float(x), 1), round(float(y), 1)] for x, y in dst],
        "fitted_height_px": fitted_h,
        "content_height_px": content_h,
        "over_height_cap": fitted_h > content_h,
        "edge_ink_ratio": round(edge_ink_ratio(canvas), 4),
    }
    return canvas, report


def _clear_edge_bleed(image: Image.Image, border: int = 1) -> Image.Image:
    """호모그래피 보간이 캔버스 테두리에 남긴 반투명 점을 지운다."""
    data = np.asarray(image).copy()
    data[:border, :, 3] = 0
    data[-border:, :, 3] = 0
    data[:, :border, 3] = 0
    data[:, -border:, 3] = 0
    return Image.fromarray(data, "RGBA")


def fit_bbox(
    source: pathlib.Path, entry: dict, nudge: dict
) -> tuple[Image.Image, dict]:
    """옛 방식: 가로 스케일 + 접지. 각도는 안 고친다."""
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
        Image.Resampling.LANCZOS,
    )

    left = round(canvas_w / 2 - sized.width / 2) + int(nudge.get("dx", 0))
    top = pivot_y - sized.height + int(nudge.get("dy", 0))

    pad = max(0, -left, -top, left + sized.width - canvas_w, top + sized.height - canvas_h)
    roomy = Image.new("RGBA", (canvas_w + pad * 2, canvas_h + pad * 2), (0, 0, 0, 0))
    roomy.alpha_composite(sized, (left + pad, top + pad))
    canvas = roomy.crop((pad, pad, pad + canvas_w, pad + canvas_h))

    report = {
        "mode": "bbox",
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


def fit(
    source: pathlib.Path, entry: dict, nudge: dict, mode: str
) -> tuple[Image.Image, dict]:
    if mode == "bbox":
        return fit_bbox(source, entry, nudge)
    return fit_quad(source, entry, nudge)


def save_debug_overlay(canvas: Image.Image, entry: dict, out: pathlib.Path) -> None:
    """맞춘 결과 위에 목표 마름모를 노란 선으로 그린다."""
    overlay = canvas.copy()
    draw = ImageDraw.Draw(overlay)
    poly = [tuple(p) for p in entry["ground_polygon_north_east_south_west"]]
    draw.line(poly + [poly[0]], fill=(255, 220, 0, 255), width=2)
    px, py = entry["pivot"]
    draw.ellipse((px - 3, py - 3, px + 3, py + 3), outline=(255, 64, 64, 255), width=2)
    overlay.save(out)


def _margin(entry: dict) -> int:
    return (entry["canvas"][0] - entry["ground_size"][0]) // 2


def pick_entry(spec: dict, facility: str, storeys: int) -> dict:
    for entry in spec["buildings"]:
        if entry["file"] == f"{facility}_{storeys}l.png":
            return entry
    names = sorted({e["file"].rsplit("_", 1)[0] for e in spec["buildings"]})
    sys.exit(f"모르는 건물이다: {facility} {storeys}층. 있는 것: {', '.join(names)}")


def main() -> int:
    parser = argparse.ArgumentParser(description="생성 그림을 아지트 격자 마름모에 맞춘다")
    parser.add_argument("sources", nargs="+", type=pathlib.Path)
    parser.add_argument("--facility", default=None, help="workshop · intel_room · contact_point")
    parser.add_argument("--storeys", type=int, default=1)
    parser.add_argument(
        "--mode",
        choices=("quad", "bbox"),
        default="quad",
        help="quad=꼭짓점 호모그래피(기본), bbox=옛 가로 스케일",
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="맞춘 결과 + 목표 마름모 오버레이 PNG 도 남긴다",
    )
    args = parser.parse_args()

    spec = load_spec()
    overrides = json.loads(OVERRIDES.read_text(encoding="utf-8")) if OVERRIDES.exists() else {}
    FITTED_DIR.mkdir(parents=True, exist_ok=True)

    failures = 0
    for source in args.sources:
        facility = args.facility or source.stem.rsplit("_", 1)[0]
        entry = pick_entry(spec, facility, args.storeys)
        try:
            canvas, report = fit(source, entry, overrides.get(entry["file"], {}), args.mode)
        except Exception as exc:  # noqa: BLE001 — CLI 도구, 원인 그대로 보여 준다
            print(f"[fit] FAIL {source.name}: {exc}")
            failures += 1
            continue

        out = FITTED_DIR / entry["file"]
        canvas.save(out)
        if args.debug:
            save_debug_overlay(canvas, entry, FITTED_DIR / f"{out.stem}_debug.png")

        notes = []
        if report["over_height_cap"]:
            notes.append(
                "캔버스를 넘는다 %d > %d"
                % (report["fitted_height_px"], report["content_height_px"])
            )
            failures += 1
        elif report["edge_ink_ratio"] > EDGE_INK_LIMIT:
            notes.append("가장자리에 잉크 %.1f%%" % (report["edge_ink_ratio"] * 100))
            failures += 1
        state = "  ".join(notes) if notes else "맞음"
        mode = report.get("mode", args.mode)
        print(f"[fit] {out.relative_to(ROOT)}  mode={mode}  {state}")
        if "src_quad_nesw" in report:
            print(f"       src {report['src_quad_nesw']}")
            print(f"       dst {report['dst_quad_nesw']}")
        (FITTED_DIR / (out.stem + ".json")).write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )

    if failures:
        print("[fit] %d 건이 규격을 벗어나거나 실패했다" % failures)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
