"""UI 키트 에셋 생성 — 로컬 ComfyUI :8000, Klein 4B Pro. 컨셉 「현시(顯示)」.

    python tools/gen_kit_assets.py            # 다섯 장 전부
    python tools/gen_kit_assets.py ray gold   # 골라서

배관은 `gen_scene.py` 의 것을 그대로 쓴다 — 같은 서버 · 같은 모델 · 같은 그래프다.
**인스턴스를 새로 띄우지 않고 체크포인트도 갈아 끼우지 않는다** (전례: 둘 띄웠다 블루스크린).

--- 프롬프트 규격 ------------------------------------------------------------

**모델은 문장의 논리가 아니라 낱말을 읽는다.** 부정도 비유도 방향 지시도 안 통한다.
그래서 이 파일의 프롬프트는 **명사 목록에 가깝게** 적혀 있고, 아래 점검을 통과했다:

    문법을 다 지우고 명사만 남겨 읽는다. 그 목록이 화면에 나올 것들이다.

앞 레인들이 값비싸게 얻은 사고 예: `NOT screaming` → 비명이 나온다 /
`like a pillow` 의 `skull` → 소품 두개골이 나온다 / `recycled paper` → 종이 부스러기.
그래서 여기에는 비유가 하나도 없다.

--- 검은 바탕과 알파 --------------------------------------------------------

컷아웃이 필요한 겹은 **검은 바탕**으로 생성하고 `kit_alpha.py` 가 휘도를 알파로
옮긴다. 마젠타 크로마(`cut_layers.py`)를 쓰지 않는 이유는 이 겹들이 **금**이라
경계가 반투명해야 하기 때문이다 — 금박의 끝은 딱 끊기지 않는다. 크로마 키는
경계를 이진으로 잘라서 금 광선의 끝이 톱니가 된다.

**검은 바탕 생성물을 그냥 얹으면 회색 사각형이 찍힌다** (4판 실측).
그래서 `kit_alpha.py` 를 반드시 거친다.
"""

from __future__ import annotations

import os
import sys

from gen_scene import run  # noqa: F401  (같은 배관을 쓴다)

HERE = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------------------
# 공통 문장 — 컨셉이 아니라 **촬영 조건**이다
# ---------------------------------------------------------------------------

#: 금세공을 물건으로 찍는다. 일러스트로 그리면 「그린 금」이 되어 화면 안의
#: 다른 층(코드로 그린 도형·글자)과 같은 재질이 되고, 그러면 층이 갈리지 않는다.
SHOT = (
    "macro photograph, museum object photography, single object centred, "
    "raking light from the upper left, deep shadow, extremely sharp fine detail, "
    "high dynamic range, no text, no letters, no numerals"
)

#: 컷아웃 겹의 바탕. 순검정이라야 휘도가 곧 알파다.
VOID = "pure black background, black void, nothing else in frame"

#: 금의 성질. 노란 페인트가 아니라 **금속**이라야 방사 구조가 빛을 받는다.
GOLD = (
    "solid high-karat gold metal, hammered gold leaf surface, goldsmith repoussé, "
    "chased punchwork, rows of punched dots, engraved parallel lines, "
    "warm deep gold, bright specular highlights, dark umber recesses"
)

# ---------------------------------------------------------------------------
# 다섯 장
# ---------------------------------------------------------------------------
#
# | 이름 | 무엇 | 알파 | 화면에서 |
# | --- | --- | --- | --- |
# | `ray` | 금 광선 한 개 | O | N 개를 회전 배치해 방사를 만든다. 광선마다 위상이 다르다 |
# | `gild` | 금박 판 | | 판을 채운다. 금이 면적을 갖는 유일한 자리 |
# | `fissure` | 갈라진 도금 | O | 금 위에 얹는다. **금 간 금**이 게임의 제목이다 |
# | `silk` | 주홍 금실 직물 | O | 격자를 사선으로 가로지르는 띠 한 줄 |
# | `stones` | 물린 보석 | O | 방사의 중심과 눌림 지점. 가장 작고 가장 정밀한 것 |

PROMPTS: dict[str, tuple[str, int, int, bool]] = {
    "ray": (
        "one single narrow tapering gold ray, a long thin wedge of gold "
        "widening from bottom to top, " + GOLD + ", "
        "a raised central rib along its length, a beaded gold rim on both long edges, "
        "the wedge fills the frame from bottom edge to top edge, " + VOID + ", " + SHOT,
        320,
        1024,
        True,
    ),
    "gild": (
        "a flat sheet of gold leaf, " + GOLD + ", "
        "overlapping square leaf edges, crumpled foil wrinkles, "
        "the gold sheet fills the entire frame edge to edge, "
        "flat frontal view, macro photograph, extremely sharp fine detail, "
        "no text, no letters, no numerals",
        1024,
        1024,
        False,
    ),
    "fissure": (
        "cracked gilding, a broken skin of gold leaf, a web of thin fissures, "
        "curling flakes of gold with lifted edges, black voids between the flakes, "
        + GOLD
        + ", "
        + VOID
        + ", "
        + SHOT,
        1024,
        1024,
        True,
    ),
    "silk": (
        "one horizontal band of vermilion silk brocade, gold thread embroidery, "
        "woven cinnabar red cloth, dense gold weft pattern, frayed cut ends, "
        "soft folds and creases, the band spans the frame left edge to right edge, "
        + VOID
        + ", "
        + SHOT,
        1024,
        256,
        True,
    ),
    "stones": (
        "a cluster of polished cabochon stones in gold bezel mounts: "
        "deep blue lapis lazuli, dark red garnet, "
        "each stone held by gold claws, " + GOLD + ", " + VOID + ", " + SHOT,
        640,
        640,
        True,
    ),
}

#: 씨앗은 고정한다. 다시 돌렸을 때 다른 그림이 나오면 화면이 조용히 달라진다.
SEEDS = {"ray": 71041, "gild": 71042, "fissure": 71043, "silk": 71044, "stones": 71045}


def main(argv: list[str]) -> int:
    want = argv or list(PROMPTS)
    unknown = [n for n in want if n not in PROMPTS]
    if unknown:
        print("모르는 이름: %s (있는 것: %s)" % (", ".join(unknown), ", ".join(PROMPTS)))
        return 2
    for name in want:
        prompt, w, h, _alpha = PROMPTS[name]
        run("kit_" + name, prompt, w, h, SEEDS[name], steps=28)
    print("생성 끝. 다음: python tools/kit_alpha.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
