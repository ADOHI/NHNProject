"""배경을 뗀다. **`minimal-char-studio` 의 필터를 부르는 얇은 겉껍질이다.**

새로 안 짠다 — 그쪽 `mcs/segment/alpha.py` 가 실물이고, 주석에 왜 그렇게 짰는지까지
적혀 있다: *"순수 색상 임계로 지우면 캐릭터 안쪽의 흰자위·밝은 옷이 같이 뚫린다.
그래서 **바깥과 이어진 배경만** 지운다."*

# 왜 이 단계가 생겼나 (§27.28, §27.29)

화풍이 드러나는 자리가 배경이라 **규격을 열었다.** 그러면 배경이 흰색이 아니게 된다 —
회색 종이, 캔버스 올, 검정 판. **SD 변환에 넘기기 전에 떼야 한다.**

사용자가 발밑 그림자를 후처리로 지우기로 이미 정했고, **같은 단계가 배경도 뗀다.**

# 관용값을 올렸다 — **그러데이션 때문이다**

그쪽 기본값이 `tol=22` 인데 우리 판에는 안 맞는 것이 있다.
그쪽은 흰 배경만 상대했고 **우리는 화풍이 칠한 배경을 상대한다.**

실측 (§27.30) — `남은 배경% / 인물 넓이%`:

    p_digital #2b   tol22  100.0/100.0   tol60  0.0/32.2   ← 그러데이션. 올리면 떨어진다
    p_oil     #3    tol22   56.1/ 72.4   tol60  1.2/29.1   ← 같다
    m_lino    #2b   tol22   75.0/ 86.9   tol80 74.7/86.5   ← **안 떨어진다**
    p_water   #2b   tol22   44.3/ 75.2   tol80 43.2/67.4   ← **안 떨어진다**

**앞의 둘과 뒤의 둘은 다른 병이다:**

> **바탕에 「색을 깔면」 떨어지고 「그림을 그리면」 안 떨어진다.**
>
> `m_lino` 는 검정 판 둘레에 **흰 테두리를 그렸다** — 액자다. 바깥 모서리가 종이색이라
> 검정 판이 「바깥과 이어진」 영역이 아니게 된다.
> `p_water` 는 배경에 **수채 얼룩을 그렸다.** 그건 배경색이 아니라 그림이라 안 지워진다.
>
> **§27.25.8 ㉡ 과 같은 규칙의 세 번째 얼굴이다** — 화풍이 배경에 무엇을 그리면
> 그것이 남는다. 전에는 「규격을 이긴다」였고 이제는 **「후처리로도 못 뗀다」**다.
> **그리고 이건 탈락 사유다. 화풍이 예뻐도 못 쓴다.**
"""

from __future__ import annotations

import os
import sys

#: 그쪽 저장소를 import 경로에 넣는다. **베끼지 않고 부른다** (§27.24.4 와 같은 규율).
_STUDIO = os.path.join(os.path.expanduser("~"), "2dAnim", "minimal-char-studio")
if _STUDIO not in sys.path:
    sys.path.insert(0, _STUDIO)

#: 우리 기본값. 그쪽은 22 다 — 위 주석이 이유다.
DEFAULT_TOL = 60
#: 뗀 뒤 바깥 띠에 이만큼 넘게 남으면 **안 떨어진 것**이다.
LEFTOVER_BREAK = 5.0


def cut(src: str, dest: str = "", tol: int = DEFAULT_TOL,
        flatten: str = "white") -> tuple[str, float, float]:
    """배경을 떼고 저장한다. `(경로, 남은 배경 %, 인물 넓이 %)`.

    `flatten` 이 색이면 그 색 위에 얹어 RGB 로 낸다. **Klein 에 넘기려면 필요하다** —
    SD 변환은 알파를 안 받고, 투명을 검정으로 읽으면 실루엣이 망가진다.
    `""` 면 RGBA 그대로 둔다 (스프라이트로 쓸 때).
    """
    import numpy as np
    from PIL import Image
    from mcs.segment.alpha import remove_background

    im = Image.open(src)
    rgba = remove_background(im, tol=tol)
    a = np.array(rgba)[..., 3] > 16
    h, w = a.shape
    band = np.concatenate([a[:, :int(w * 0.15)], a[:, int(w * 0.85):]], axis=1)
    left, area = float(band.mean() * 100.0), float(a.mean() * 100.0)

    out = rgba
    if flatten:
        bg = Image.new("RGBA", rgba.size, flatten)
        out = Image.alpha_composite(bg, rgba).convert("RGB")
    dest = dest or src.replace(".png", "_cut.png")
    os.makedirs(os.path.dirname(os.path.abspath(dest)), exist_ok=True)
    out.save(dest)
    return dest, left, area


def verdict(left: float) -> str:
    return "떨어짐" if left < 1.0 else ("남음" if left < LEFTOVER_BREAK else "**안 떨어짐**")
