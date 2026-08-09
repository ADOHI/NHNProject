"""전신 일러스트의 바탕을 잘라 낸다.

모델이 낸 그림은 배경이 있는 사각형이다. 그대로 얹으면 홀로그램 위에 종이가 붙은
것으로 보인다. 테두리에서 이어지는 균일한 색만 지운다 — 인물 안쪽의 같은 색은
테두리와 안 이어져 있으므로 남는다.
"""

import glob
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

SRC = r"C:\Users\adohi\NHNProject\.claude\worktrees\portraits\.captures\portraits"
OUT = sys.argv[1]
SIZE = (312, 456)
TOL = 34


def main() -> int:
    picks = []
    for folder in ("cast4", "cast5", "cast6"):
        picks += sorted(glob.glob(os.path.join(SRC, folder, "*_illust.png")))
    picks = picks[:6]
    os.makedirs(OUT, exist_ok=True)
    for i, path in enumerate(picks):
        image = Image.open(path).convert("RGB").resize(SIZE, Image.LANCZOS)
        pixels = np.asarray(image).astype(np.int16)
        corners = np.stack(
            [pixels[0, 0], pixels[0, -1], pixels[-1, 0], pixels[-1, -1]]
        ).mean(axis=0)
        flat = np.abs(pixels - corners).max(axis=2) <= TOL
        parts, _ = ndimage.label(flat)
        edge = set(parts[0, :]) | set(parts[-1, :]) | set(parts[:, 0]) | set(parts[:, -1])
        edge.discard(0)
        background = np.isin(parts, list(edge))
        alpha = np.where(background, 0, 255).astype(np.uint8)
        alpha = ndimage.grey_erosion(alpha, size=(2, 2))
        rgba = np.dstack([np.asarray(image), alpha])
        out = os.path.join(OUT, "figure_%d.webp" % i)
        Image.fromarray(rgba, "RGBA").save(out, "WEBP", quality=88, method=6)
        print(out, os.path.getsize(out) // 1024, "KB   지운 바탕", int(background.mean() * 100), "%")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
