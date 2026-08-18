"""노멀맵 여러 장을 **결과(같은 빛을 먹여 렌더한 그림)로** 견준다.

    python tools/measure_normal_plausibility.py <바탕.png> \\
        --normal BAE=bae.png --normal DSINE=dsine.png \\
        --want-flat 1000,780,2560,1040 --want-relief 320,550,922,832 \\
        --out .renders-lighting/plausibility

# 왜 이 도구가 있나 — **노멀 차이 자체를 재면 두 가지를 못 가른다**

`docs/design/26-2d-lighting.md` §26.4.6~26.4.7 은 "경계에서 법선이 얼마나
급하게 바뀌는가"를 자로 썼다. §26.4.8 에서 이 자가 **틀렸다는 것이 드러났다** —
BAE 가 셀 경계에서 낮은 값을 낸 것은 **정확해서가 아니라 아무것도 못 읽어서**였다.
「적게 흔든다」는 「정확히 조용하다」와 「그냥 죽어 있다」 둘 다를 가리킬 수 있고,
**한 자로 두 원인을 가르지 못하면 그 자로는 아무 것도 못 닫는다.**

그래서 이 도구는 노멀 자체를 안 재고 **노멀로 빛을 켠 결과**를 잰다 — 그게
실제로 게임이 쓰는 것이다(`docs/design/26-2d-lighting.md` §26.4.8). 같은 빛,
같은 렌더 방식이면 후보가 몇 장이든 같은 단위(0~255 화소값)로 놓인다.

# 무엇을 보증하고 무엇을 못 보는가 — **반드시 읽어라**

이 도구가 답하는 것:

- 지정한 두 종류의 구역 — **평평해야 할 곳**(`--want-flat`, 재질은 하나인데
  구운 밝기가 다른 자리 같은 「가짜 신호」) 과 **굴곡이 있어야 할 곳**
  (`--want-relief`, 실제 소품 실루엣 같은 「진짜 신호」) — 에서 렌더가
  얼마나 울퉁불퉁한가
- 후보 노멀들의 **경계/그밖 비율**을 정렬해서 보여준다. **비율이 1 에 가깝거나
  1 보다 작으면 위험 신호다** — 가짜 신호와 진짜 신호를 못 가른다는 뜻이다

이 도구가 **못** 답하는 것:

- **구역을 대신 골라 주지 않는다.** `--want-flat`/`--want-relief` 좌표는
  사람이 바탕 그림을 보고 정해야 한다 — §26.4.5 의 원래 시험도 사람이 두 자리를
  짚었다. 셀 그림처럼 손으로 짚기 번거로우면 `--auto-cel` 로 "색상은 같고
  밝기만 다른 자리"를 자동으로 찾지만, 이것도 §26.4.6 이 이미 적어 둔 한계
  (옷 주름과 셀 경계를 완전히 못 가른다) 를 그대로 물려받는다
- **방향이 맞는지는 안 잰다.** 반응의 크기(거칠기)만 잰다 — 밝은 쪽이 정말
  빛 쪽으로 기울었는지는 렌더 이미지를 **사람이 봐야** 안다. 이 도구는 항상
  렌더를 파일로 남긴다(`--out`) — 숫자만 보고 판단하지 않는다는 것이
  §26.4.8 에서 얻은 교훈이다
- **이 도구의 합성 빛은 실제 게임 빛과 다르다.** 고정된 한 방향의 단순
  `N·L` 이고, `PointLight2D` 의 거리 감쇠·색·`height`는 없다. **여기서 이겼다고
  게임 화면에서도 이긴다는 보장은 아니다** — 어둠·대원 빛까지 같이 켠 실제
  화면 확인은 `room_light_lab.gd` 실험대가 한다(§26.9)
- **거칠기(라플라시안)는 해상도에 민감하다.** 후보 노멀들이 서로 다른
  해상도면 억지로 비교하지 않는다 — 크기가 안 맞으면 이 도구는 그냥 에러를
  낸다(조용히 계속 진행하지 않는다. §26.9 의 "조용히 검은 화면이 되면 원인을
  찾는 데 한나절이 든다"와 같은 이유)

# 다시 재는 법 (§26.4.8 · 이번 판의 표를 그대로 재현한다)

    # 셀 재질 — 화풍 산출물 한 장, 자동 경계 검출
    python tools/measure_normal_plausibility.py <화풍 산출물.png> \\
        --normal BAE=<BAE 노멀.png> --normal DSINE=<DSINE 노멀.png> \\
        --auto-cel --out .renders-lighting/plausibility/cel

    # 사실적 텍스처 — 방 판, 손으로 짚은 두 구역
    python tools/measure_normal_plausibility.py <방 판 crop.png> \\
        --normal BAE=<BAE 노멀.png> --normal DSINE=<DSINE 노멀.png> \\
        --want-flat <바닥 사각형> --want-relief <소품 사각형> \\
        --out .renders-lighting/plausibility/room

**판이 다시 그려지거나 화풍이 바뀌면 다시 돌려라.** 이 표는 한 번 뽑고
버리는 것이 아니라 **재질이 바뀔 때마다 다시 대야 하는 자다** — 그래서
스크래치패드가 아니라 여기(`tools/`)에 있다.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

from console_utf8 import fix_console_encoding

_LIGHT_DEFAULT = (-0.5, -0.35, 0.8)

## 셀 경계 자동 검출의 문턱값. §26.4.6 이 쓴 값 그대로 - 색상은 그대로인데
## 밝기만 크게 뛰는 화소를 셀 경계로 본다.
_LUM_GRAD_MIN = 18.0
_HUE_STD_MAX = 6.0
_SAT_MIN = 40


def _parse_box(text: str) -> tuple[int, int, int, int]:
    parts = [int(v.strip()) for v in text.split(",")]
    if len(parts) != 4:
        raise argparse.ArgumentTypeError("x0,y0,x1,y1 네 값이어야 한다: %r" % text)
    return parts[0], parts[1], parts[2], parts[3]


def _parse_normal_arg(text: str) -> tuple[str, Path]:
    if "=" not in text:
        raise argparse.ArgumentTypeError("LABEL=경로.png 형태여야 한다: %r" % text)
    label, path = text.split("=", 1)
    return label, Path(path)


def _region_mask(shape: tuple[int, int], box: tuple[int, int, int, int]) -> np.ndarray:
    x0, y0, x1, y1 = box
    mask = np.zeros(shape, dtype=bool)
    mask[y0:y1, x0:x1] = True
    return mask


def _light_render(normal_img: np.ndarray, light: np.ndarray) -> np.ndarray:
    n = normal_img.astype(np.float32) / 255.0 * 2.0 - 1.0
    n /= np.clip(np.linalg.norm(n, axis=2, keepdims=True), 1e-6, None)
    ndotl = np.clip((n * light).sum(axis=2), 0.0, 1.0)
    shade = 0.15 + 0.85 * ndotl
    return (shade * 255.0).clip(0, 255).astype(np.uint8)


def _roughness(lit_gray: np.ndarray, mask: np.ndarray) -> float:
    lap = ndimage.laplace(lit_gray.astype(np.float32))
    vals = np.abs(lap)[mask]
    return float(vals.mean()) if vals.size else float("nan")


def _auto_cel_masks(source_rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """§26.4.6·26.4.8 의 자동 셀 경계 검출을 그대로 옮긴 것.

    HSV 로 바꿔 밝기(V) 기울기와 색상(H) 국소 변동을 같이 본다 - 밝기만
    뛰고 색상은 그대로인 자리가 셀 경계다. 반환값은 (want_relief, want_flat)."""
    from PIL import ImageFilter  # noqa: PLC0415  (여기서만 쓴다)

    img = Image.fromarray(source_rgb).convert("HSV")
    h_ch, s_ch, v_ch = (np.asarray(c, dtype=np.float32) for c in img.split())

    gx = ndimage.sobel(v_ch, axis=1)
    gy = ndimage.sobel(v_ch, axis=0)
    lum_grad = np.sqrt(gx**2 + gy**2)

    h_rad = h_ch * (np.pi / 128.0)
    cos_h = ndimage.uniform_filter(np.cos(h_rad), size=5)
    sin_h = ndimage.uniform_filter(np.sin(h_rad), size=5)
    hue_consistency = np.sqrt(cos_h**2 + sin_h**2)
    hue_std_proxy = (1.0 - hue_consistency) * 90.0

    fg = s_ch > _SAT_MIN
    border = np.zeros_like(fg)
    m = int(0.06 * min(fg.shape))
    border[m:-m, m:-m] = True

    relief = (lum_grad > _LUM_GRAD_MIN) & (hue_std_proxy < _HUE_STD_MAX) & fg & border
    flat = fg & border & ~ndimage.binary_dilation(relief, iterations=3)
    return relief, flat


def main() -> int:
    fix_console_encoding()
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source", type=Path, help="바탕 그림 (진단용, 자동 검출에도 쓴다)")
    parser.add_argument(
        "--normal", action="append", default=[], type=_parse_normal_arg, metavar="LABEL=경로.png", required=True
    )
    parser.add_argument("--want-flat", action="append", default=[], type=_parse_box, metavar="x0,y0,x1,y1")
    parser.add_argument("--want-relief", action="append", default=[], type=_parse_box, metavar="x0,y0,x1,y1")
    parser.add_argument("--auto-cel", action="store_true", help="손으로 안 짚고 셀 경계를 자동으로 찾는다")
    parser.add_argument("--light", default=",".join(str(v) for v in _LIGHT_DEFAULT), help="dx,dy,dz")
    parser.add_argument("--out", type=Path, default=None, help="렌더 결과를 저장할 폴더")
    args = parser.parse_args()

    if not args.auto_cel and not (args.want_flat and args.want_relief):
        parser.error("--want-flat 과 --want-relief 를 하나씩 이상 주거나 --auto-cel 을 켜라")

    light = np.array([float(v) for v in args.light.split(",")], dtype=np.float32)
    light /= np.linalg.norm(light)

    source = np.array(Image.open(args.source).convert("RGB"))

    if args.auto_cel:
        relief_mask, flat_mask = _auto_cel_masks(source)
        if relief_mask.sum() < 200:
            print("셀 경계가 200 화소 미만이다 - 이 재질엔 --auto-cel 이 안 맞을 수 있다.")
            return 1
    else:
        flat_mask = np.zeros(source.shape[:2], dtype=bool)
        for box in args.want_flat:
            flat_mask |= _region_mask(source.shape[:2], box)
        relief_mask = np.zeros(source.shape[:2], dtype=bool)
        for box in args.want_relief:
            relief_mask |= _region_mask(source.shape[:2], box)

    if args.out:
        args.out.mkdir(parents=True, exist_ok=True)

    rows: list[tuple[str, float, float]] = []
    for label, path in args.normal:
        normal_img = np.array(Image.open(path).convert("RGB"))
        if normal_img.shape[:2] != source.shape[:2]:
            print(
                f"크기가 안 맞는다: {label} 는 {normal_img.shape[1]}x{normal_img.shape[0]}, "
                f"바탕은 {source.shape[1]}x{source.shape[0]}. 억지로 비교하지 않는다."
            )
            return 1
        lit = _light_render(normal_img, light)
        if args.out:
            Image.fromarray(lit).save(args.out / f"lit_{label}.png")
        flat_r = _roughness(lit, flat_mask)
        relief_r = _roughness(lit, relief_mask)
        rows.append((label, flat_r, relief_r))

    print(f"{'label':<12}{'flat (want LOW)':>18}{'relief (want HIGH)':>20}{'relief/flat':>14}")
    for label, flat_r, relief_r in rows:
        ratio = relief_r / (flat_r + 1e-6)
        flag = "  <- 1 이하, 위험 신호" if ratio <= 1.0 else ""
        print(f"{label:<12}{flat_r:>18.3f}{relief_r:>20.3f}{ratio:>14.2f}{flag}")

    if args.out:
        print(f"\n렌더 저장: {args.out}/lit_<label>.png - 반드시 눈으로도 확인해라.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
