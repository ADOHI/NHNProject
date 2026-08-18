"""검은 바탕 생성물을 알파 겹으로 바꾼다. 컨셉 「현시」의 금 겹들.

    python tools/kit_alpha.py

`tools/scene/kit_*.png` → `assets/ui/kit/*.webp`.

--- 왜 크로마 키가 아닌가 ----------------------------------------------------

`cut_layers.py` 는 마젠타 크로마를 뺀다. 그쪽이 맞는 경우는 **경계가 딱 끊기는 물체**다.
여기 겹들은 **금박**이라 끝이 얇아지며 사라진다. 크로마 키는 경계를 이진으로 잘라서
금 광선의 끝을 톱니로 만든다. 휘도 알파는 그 반투명을 그대로 살린다.

--- 휘도만으로는 안 됐다 (실측) ----------------------------------------------

`kit_silk` 의 바탕은 순검정이 아니라 **어두운 회색 천**이었고(모델이 "black
background" 를 천으로 읽었다), 진사(辰砂) 비단의 휘도가 0.22 로 그 바탕과 거의
같았다. **휘도만 쓰면 비단이 사라지고 바탕이 남는다.**

그래서 **휘도와 채도 중 큰 쪽**을 쓴다. 금과 비단은 채도가 높고, 회색 바탕과
갈라진 도금의 검은 틈은 둘 다 낮다. 두 신호가 서로의 실패를 메운다.

--- 그래도 안 됐다 — 속이 뚫렸다 (실측) --------------------------------------

채도를 넣어도 **진사 비단의 어두운 주름과 청금석의 짙은 부분이 반투명**으로 남았다.
`.renders/alpha_check.png` 에서 초록 바탕이 비단 안쪽으로 비쳤고 보석이 초록빛을 띠었다.
문턱을 아무리 내려도 회색 바탕과 어두운 주름의 휘도가 겹쳐 있어서 **문턱 하나로는
못 가른다.**

그래서 **문턱이 아니라 형태로 판정한다.** 실루엣을 잡아 **속을 메운다**
(`binary_fill_holes`). 그러면 안쪽은 무조건 불투명해지고 문턱은 경계에서만 일한다.

**`fissure` 만 이것을 하지 않는다** — 조각 사이의 검은 틈이 뚫려 있는 것이
그 겹이 하는 일이다. 속을 메우면 겹의 목적이 사라진다.

--- 함정 둘 (4판 실측) -------------------------------------------------------

1. **검은 바탕 생성물을 그냥 얹으면 회색 사각형이 찍힌다.** 이 파일이 그것을 막는다.
2. **알파만 만들고 RGB 를 그대로 두면 경계에 검은 테가 생긴다.** 검은 바탕이 색에도
   섞여 있기 때문이다. 그래서 알파로 **역곱(unpremultiply)** 한다 — `rgb / alpha`.
   빼먹으면 금이 어두운 갈색으로 보인다.
"""

from __future__ import annotations

import os

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "scene")
DEST = os.path.join(os.path.dirname(HERE), "assets", "ui", "kit")


class Cut:
    """겹 하나를 어떻게 자를지. 값은 그림을 보고 정했다."""

    def __init__(
        self,
        alpha: bool,
        low: float = 0.055,
        high: float = 0.62,
        solid: bool = True,
        crop: tuple[int, int, int, int] | None = None,
    ) -> None:
        self.alpha = alpha
        self.low = low
        self.high = high
        #: 속을 메울지. 성한 물건이면 참, 뚫려 있어야 하는 겹이면 거짓.
        self.solid = solid
        self.crop = crop


CUTS: dict[str, Cut] = {
    # 순검정 바탕. 광선 끝이 얇아지므로 문턱을 낮게 둔다.
    "ray": Cut(True, low=0.045, high=0.50),
    # 판을 꽉 채우는 질감이라 바탕이 없다. 알파를 만들면 안 된다.
    "gild": Cut(False),
    # 조각 사이의 **검은 틈이 투명해야** 아래가 보인다. 그게 이 겹의 일이다.
    "fissure": Cut(True, low=0.10, high=0.42, solid=False),
    # 바탕이 어두운 회색 천이었다. 어두운 주름은 문턱이 아니라 속 메우기가 지킨다.
    "silk": Cut(True, low=0.16, high=0.46),
    # 아래쪽에 반사상이 함께 찍혔다. 잘라 낸다 — 안 자르면 보석이 두 벌이 된다.
    "stones": Cut(True, low=0.06, high=0.45, crop=(52, 12, 588, 528)),
}


def coverage(rgb: np.ndarray, cut: Cut) -> np.ndarray:
    """휘도와 채도 중 큰 쪽을 알파로. 둘이 서로의 실패를 메운다."""
    lum = rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114
    chroma = rgb.max(axis=-1) - rgb.min(axis=-1)
    raw = np.maximum(lum, chroma * 1.35)
    a = np.clip((raw - cut.low) / (cut.high - cut.low), 0.0, 1.0)
    # smoothstep. 선형으로 두면 바닥 근처의 옅은 회색이 넓게 남아 사각형이 보인다.
    a = a * a * (3.0 - 2.0 * a)
    if not cut.solid:
        return a
    return np.maximum(a, fill_inside(a))


def fill_inside(a: np.ndarray) -> np.ndarray:
    """실루엣의 속을 메운다. 어두운 주름이 반투명으로 남는 것을 이것이 막는다."""
    mask = ndimage.binary_fill_holes(a > 0.28)
    if mask is None:
        return np.zeros_like(a)
    # 안쪽으로 한 칸 물러선 뒤 흐린다. 안 하면 문턱 자리에 딱 끊긴 테가 생긴다.
    inner = ndimage.binary_erosion(mask, iterations=2)
    return np.clip(ndimage.gaussian_filter(inner.astype(np.float32), 1.6), 0.0, 1.0)


def unpremultiply(rgb: np.ndarray, a: np.ndarray) -> np.ndarray:
    """검은 바탕이 섞여 어두워진 색을 되돌린다. 안 하면 금이 갈색이 된다."""
    return np.clip(rgb / np.maximum(a, 0.12)[..., None], 0.0, 1.0)


def main() -> int:
    os.makedirs(DEST, exist_ok=True)
    made = 0
    for name, cut in CUTS.items():
        src = os.path.join(SRC, "kit_" + name + ".png")
        if not os.path.exists(src):
            print("없다 (건너뜀): " + src)
            continue
        opened = Image.open(src).convert("RGB")
        if cut.crop is not None:
            opened = opened.crop(cut.crop)
        rgb = np.asarray(opened, dtype=np.float32) / 255.0
        dest = os.path.join(DEST, "kit_" + name + ".webp")
        if cut.alpha:
            a = coverage(rgb, cut)
            out = np.concatenate([unpremultiply(rgb, a), a[..., None]], axis=-1)
            img = Image.fromarray((out * 255.0 + 0.5).astype(np.uint8), mode="RGBA")
            cover = float(a.mean())
        else:
            img = Image.fromarray((rgb * 255.0 + 0.5).astype(np.uint8), mode="RGB")
            cover = 1.0
        img.save(dest, "WEBP", quality=92, method=5)
        made += 1
        print(
            "%-10s %4dx%-4d  덮는 비율 %4.1f%%  %6.0f KB"
            % (name, img.width, img.height, cover * 100.0, os.path.getsize(dest) / 1024.0)
        )
    if made == 0:
        print("만든 것이 없다. 먼저 python tools/gen_kit_assets.py")
        return 1
    print("다음: godot --path . --import")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
