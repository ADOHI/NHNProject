#!/usr/bin/env python
"""초상 판정 — **모델이 시키지 않은 것을 그렸는가, 그리고 증명사진이 되었는가.**

    python tools/portraits/check_portraits.py .captures/portraits/sian

# 왜 이 둘인가

room-studio 레인이 컷아웃에서 얻은 규율 둘을 그대로 받는다
(`C:/Users/adohi/2dAnim/room-studio/tools/check_props.py` 머리말).

> **테두리를 재라.** 판 전체 비율로 관문을 세우면 떠 있는 조각을 놓친다.
> **거짓 경보를 내는 관문은 사람이 관문을 무시하게 만들어 없는 것보다 나쁘다.**

초상에는 컷아웃이 없다 — 340×340 액자가 불투명한 칸이라(§24.17.3) 알파가 필요 없다.
그래서 마젠타도 로즈 얼룩도 잴 것이 없다. **대신 이 판이 실제로 지는 두 가지를 잰다.**

## 검사 1 — 테두리 (**판정에 쓴다**)

프롬프트가 요구하는 것이 *"배경이 판의 모든 변과 모서리까지 이어진다"* 이다
(`prompts.BACKGROUND`). **테두리를 재면 그 요구를 그대로 검사하게 된다.**
배경이 돌방이나 다른 사람이 되면 테두리가 밝아지고 얼룩덜룩해진다.

room-studio 가 이 자리에서 한 번 놓쳤다 — 판 **전체** 배경 비율로 관문을 세웠더니
모델이 방 안에 마젠타 패널을 세워 놓은 판이 통과했다. **테두리는 안 속는다.**

## 참고 — 좌우 대칭 (**판정에 안 쓴다. 아래를 읽어라**)

`docs/design/27-portraits.md` §27.8 이 막으려는 것이다. 정면 대칭 얼굴은 증명사진이 되고
**개성이 죽으면 변형 100장이 서로 구분되지 않아 격자 전체가 헛일이 된다.**
**관문으로 쓰려고 만들었다** — 뒤집은 판과의 차이가 정면에서 작게 나올 것이라 봤다.

**갈리지 않았다. 그리고 거꾸로 나왔다.**

1차 탐침이 **정면으로 나온 판 셋**을 남겨 줘서 라벨 붙은 대조군이 있었다
(`.captures/portraits/probe`, §27.15.1). 시안 19장(전부 사분의 삼)과 나란히 쟀다.

| 판별식 | 정면 셋 | 사분의 삼 열아홉 | 갈리나 |
| --- | --- | --- | --- |
| 밝기 좌우차 | 32.9 ~ 46.3 | 21.2 ~ 44.0 | **아니오 — 거꾸로다** (정면이 오히려 크다) |
| 잔결 좌우차 | 1.26 ~ 1.36 | 1.10 ~ 1.36 | 아니오 (완전히 겹친다) |
| 잔결 좌우 상관 | 0.088 ~ 0.186 | 0.040 ~ 0.245 | 아니오 (완전히 겹친다) |

**이유가 분명하다.** 셋 다 **한쪽에서 오는 키 조명**이 지배한다
(`prompts.LIGHT` — 얼굴 한쪽만 금빛을 받는다). 정면이든 사분의 삼이든 빛이 비대칭이라
화소가 비대칭이고, **자세의 차이는 그 아래 묻힌다.**

> **그래서 관문에서 내렸다.** room-studio 가 램프 검출에서 똑같은 길을 갔고 똑같이
> 내렸다 — *"거짓 경보를 내는 관문은 사람이 관문을 무시하게 만들어 없는 것보다 나쁘다."*
> 임계를 억지로 끼우면 **성한 판 다섯이 걸린다** (실측).

**증명사진을 잡는 권위 있는 방법은 `contact_sheet.py` 다.** 한 명령에 그림 한 장이고
사람이 1초에 판정한다. 픽셀로 재려던 것을 눈이 공짜로 한다 — `check_props.py` 가
「불이 있어야 하는 소품」의 출처를 픽셀에서 컨셉 텍스트로 되돌린 것과 같은 판단이다.

## 참고 — 머리 자리 (**판정에 안 쓴다**)

전신이 나왔거나 얼굴이 잘렸는지. 흉상은 얼굴이 늘 위쪽에 있어서 성한 판과 못 쓰는 판이
같은 값을 낼 공산이 크다. **그래서 처음부터 참고로 둔다.**
실측이 갈리는 것을 보여주면 그때 관문으로 올린다 — 그 반대 순서는 거짓 경보를 만든다.

# 임계

**시안을 재고 나서 정했다. 지어내지 않았다.** 값의 근거는 각 상수 옆 주석에 있다.
`--calibrate` 로 임계 없이 숫자만 뽑을 수 있다 — 새 판을 재서 임계를 다시 볼 때 쓴다.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import console  # noqa: E402

console.utf8()

#: 테두리 띠의 두께. 판 짧은 변의 이 비율.
BORDER_BAND = 0.06

#: 테두리 밝기의 표준편차 상한. **배경에 물건이 들어오면 여기가 뛴다.**
#:
#: **아직 실측으로 갈린 적이 없다** — 시안 22장 전부 배경이 성했다(18.7~43.0).
#: 그래서 이것은 「좋은가」를 재는 자가 아니라 **상한만 막는 안전선**이다.
#: 관측 최댓값의 1.4배에 둔다. 배경이 돌방이 되면 훨씬 위로 뛰므로 그때 걸린다.
#: **갈린 실측이 생기면 그 사이로 내려라.**
BORDER_STD_MAX = 62.0

#: 테두리 평균 밝기 상한 (0~255). 배경은 `dark cold teal` 이라 어두워야 한다.
#: 시안 실측 28.8~46.0 → 관측 최댓값의 1.7배. 위와 같은 성격의 안전선이다.
BORDER_MEAN_MAX = 78.0

#: 대칭을 재는 세로 범위 — 얼굴이 있는 위쪽만.
FACE_TOP, FACE_BOTTOM = 0.05, 0.65


def _luma(path: Path) -> np.ndarray:
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    return 0.299 * a[:, :, 0] + 0.587 * a[:, :, 1] + 0.114 * a[:, :, 2]


def border_stats(path: Path) -> tuple[float, float]:
    """(테두리 밝기 표준편차, 테두리 평균 밝기).

    **전체가 아니라 테두리다.** 큰 머리가 판 가운데를 정당하게 밝게 채우므로
    전체 밝기로 관문을 세우면 거짓 경보가 난다 — 그리고 배경에 세워진 벽 조각은
    가운데 통계에 묻힌다. 프롬프트가 요구한 것이 「모든 변과 모서리」이므로
    그 요구를 그대로 잰다.
    """
    y = _luma(path)
    h, w = y.shape
    b = max(3, int(min(h, w) * BORDER_BAND))
    ring = np.zeros(y.shape, dtype=bool)
    ring[:b] = ring[-b:] = True
    ring[:, :b] = ring[:, -b:] = True
    band = y[ring]
    return float(band.std()), float(band.mean())


def symmetry(path: Path) -> float:
    """뒤집은 판과의 평균 절대차. **참고다. 판정에 안 쓴다** (모듈 머리말의 표).

    작으면 좌우 대칭 = 증명사진일 것이라 봤는데 **실측이 거꾸로 나왔다.**
    한쪽에서 오는 키 조명이 이 값을 지배해서 자세의 차이가 묻힌다.
    남겨 두는 이유는 하나 — **조명 문장을 고치면 이 자가 되살아날 수 있다.**
    그때 다시 재 보라고 계산만 해 둔다.
    """
    y = _luma(path)
    h = y.shape[0]
    face = y[int(h * FACE_TOP):int(h * FACE_BOTTOM)]
    return float(np.abs(face - face[:, ::-1]).mean())


def head_weight(path: Path) -> float:
    """**참고.** 판의 명암 대비가 위쪽에 얼마나 쏠려 있나 (0~1).

    흉상이면 얼굴의 잔결(눈·코·입)이 위쪽에 몰려 0.5 를 넘는다.
    전신이 나오면 아래로 퍼진다. **판정에 안 쓴다** — 아래 `report` 의 표에
    실측이 갈리는지 같이 찍히므로, 갈리면 그때 관문으로 올려라.
    """
    y = _luma(path)
    gy, gx = np.gradient(y)
    energy = np.hypot(gx, gy)
    half = energy.shape[0] // 2
    total = energy.sum()
    return float(energy[:half].sum() / total) if total else 0.0


def report(folder: str, calibrate: bool) -> int:
    d = Path(folder)
    # `_` 로 시작하는 것은 도구가 만든 것이다 (`_sheet.png`). 판이 아니므로 안 잰다.
    plates = sorted(p for p in d.glob("*.png") if not p.name.startswith("_"))
    if not plates:
        print(f"  [x] 판이 없다: {d}", file=sys.stderr)
        return 1

    print(f"\n=== {d.name} — 초상 판정 ({len(plates)}장) ===")
    if calibrate:
        print("  **임계 없이 숫자만 낸다** (--calibrate)")
    print(f"\n  {'판':<30}{'테두리σ':>9}{'테두리평균':>11}{'대칭차':>9}"
          f"{'위쪽무게':>10}   판정")

    rows = []
    n_border = n_sym = 0
    for p in plates:
        std, mean = border_stats(p)
        sym = symmetry(p)
        head = head_weight(p)
        rows.append((p.stem, std, mean, sym, head))

        flags = []
        if not calibrate:
            if std > BORDER_STD_MAX or mean > BORDER_MEAN_MAX:
                flags.append("[x] 배경이 장면이 됐다")
                n_border += 1
        print(f"  {p.stem:<30}{std:9.1f}{mean:11.1f}{sym:9.1f}{head:10.2f}"
              f"   {' '.join(flags) or ('-' if calibrate else '[o]')}")

    arr = np.array([[r[1], r[2], r[3], r[4]] for r in rows])
    names = ["테두리σ", "테두리평균", "대칭차", "위쪽무게"]
    print(f"\n  {'':<30}{'최소':>9}{'중위':>11}{'최대':>9}")
    for i, nm in enumerate(names):
        print(f"  {nm:<30}{arr[:, i].min():9.1f}{np.median(arr[:, i]):11.1f}"
              f"{arr[:, i].max():9.1f}")

    if calibrate:
        print("\n  **임계는 이 표가 갈리는 자리에 둔다.** 갈리지 않으면 그 검사는")
        print("  관문이 아니라 참고다 — 거짓 경보를 내는 관문은 없느니만 못하다.\n")
        return 0

    print(f"\n  배경 미달 {n_border}/{len(plates)}장  ← **관문은 이것 하나다**")
    print("  (대칭차 · 위쪽무게는 참고다. 갈리지 않는다 — 모듈 머리말의 표를 봐라.")
    print("   증명사진은 `contact_sheet.py` 로 사람이 판정한다)")
    print(f"  → {'통과' if not n_border else '미달 — `--reroll N` 로 다시 굴려라'}"
          f" (합격은 사람이 정한다)\n")
    return 1 if n_border else 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="check_portraits", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("folder", nargs="+", help="판이 있는 폴더 (여러 개 가능)")
    ap.add_argument("--calibrate", action="store_true",
                    help="임계 없이 숫자만 낸다. 새 판으로 임계를 다시 볼 때")
    args = ap.parse_args(argv)
    return max(report(f, args.calibrate) for f in args.folder)


if __name__ == "__main__":
    raise SystemExit(main())
