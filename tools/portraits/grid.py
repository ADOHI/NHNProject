"""격자 — 어느 판을 어느 시드로 뽑나 (`docs/design/27-portraits.md` §27.2 · §27.13).

**인물 단위가 아니라 격자다.** 3000명 각각을 뽑으면 시드가 바뀔 때 통째로 버린다 —
그 인물이 더 이상 없으니까 (§24.20.2). 대신 칸을 채우고 코드가 골라 붙인다.

    계열 5종 × 인상 5종 × 변형 N장
"""

from __future__ import annotations

from dataclasses import dataclass

from prompts import DISCIPLINES, IMPRESSIONS, SIZE, compose

#: 시드의 밑값. **바꾸면 지금까지 뽑은 판을 재현할 수 없다.**
BASE_SEED = 270808

#: 칸과 변형에서 시드를 결정론적으로 만드는 소수들.
#: 전부 소수 배수라 **다른 칸이 같은 시드를 갖지 않는다** — 우연히 같은 얼굴이
#: 두 칸에 나오면 격자가 칸을 나눈 뜻이 없어진다.
_D_STRIDE = 1_000_003
_I_STRIDE = 10_007
_V_STRIDE = 101
#: 재굴림. **프롬프트가 옳은데 판이 못 쓰게 나올 때 시드만 바꿔 다시 굴린다.**
#: 번호가 파일 이름과 로그에 남는다 — 안 적으면 그 그림을 다시 못 뽑는다 (§27.12).
_R_STRIDE = 7_919


@dataclass(frozen=True)
class Cell:
    """판 한 장. 이름 · 시드 · 프롬프트가 전부 여기서 나온다."""

    discipline: int
    impression: int
    variant: int
    reroll: int = 0

    @property
    def discipline_name(self) -> str:
        return DISCIPLINES[self.discipline][0]

    @property
    def impression_name(self) -> str:
        return IMPRESSIONS[self.impression][0]

    @property
    def seed(self) -> int:
        return (BASE_SEED
                + self.discipline * _D_STRIDE
                + self.impression * _I_STRIDE
                + self.variant * _V_STRIDE
                + self.reroll * _R_STRIDE)

    @property
    def name(self) -> str:
        """`combat_plain_00` · 재굴림이면 `combat_plain_00_r1`.

        **재굴림 판이 원판을 덮어쓰지 않는다.** 덮어쓰면 「무엇을 왜 다시 굴렸나」가
        디스크에서 사라지고, 그러면 심사자가 둘을 나란히 못 본다.
        """
        base = f"{self.discipline_name}_{self.impression_name}_{self.variant:02d}"
        return base if not self.reroll else f"{base}_r{self.reroll}"

    @property
    def prompt(self) -> str:
        return compose(self.discipline, self.impression)


def full_grid(per_multiplier: int = 1) -> list[Cell]:
    """격자 전체. 변형 수는 §27.5 — **인상 비율에 맞춘다.**

    칸마다 같은 장수를 두면 무색 인물의 얼굴이 훨씬 자주 겹친다
    (무색 34% · 은둔 12.2% 인데 둘이 같은 장수를 나눠 쓰므로).

    `per_multiplier` 로 전체를 배수로 늘린다 — **격자를 다시 설계하지 않고
    칸 비율을 유지한 채 늘어난다** (§27.5).
    """
    out: list[Cell] = []
    for di in range(len(DISCIPLINES)):
        for ii, (*_rest, count) in enumerate(IMPRESSIONS):
            for v in range(count * per_multiplier):
                out.append(Cell(di, ii, v))
    return out


def sian() -> list[Cell]:
    """시안 — **얼굴을 먼저 성립시키고 나서 기분을 잰다** (§21.13.15).

    두 덩어리이고 **순서에 뜻이 있다.**

    1. **계열 5종 × 무색 × 3장 = 15장.** 화풍이 타이틀과 맞는지, 512 정사각에
       흉상이 앉는지, 계열이 어깨에서 읽히는지. **인상을 변수에서 뺐다** —
       얼굴이 깨진 채로 기분을 재면 매번 *"얼굴 때문에 그렇게 읽었다"* 가
       답으로 돌아오고, 조형을 고쳤는지 결함을 고쳤는지 구분할 수 없다.
    2. **전투 × 인상 4종 × 1장 = 4장.** 인상 축이 실제로 갈리는지.
       1번이 통과했을 때만 이 넷을 믿는다.

    **15장은 버리는 판이 아니다.** 무색이 인구의 34% 라(§27.4) 그대로
    격자의 첫 칸들이 된다 — 통과하면 대량에서 다시 뽑지 않는다.
    """
    out = [Cell(di, 0, v) for di in range(len(DISCIPLINES)) for v in range(3)]
    out += [Cell(0, ii, 0) for ii in range(1, len(IMPRESSIONS))]
    return out


def describe(cells: list[Cell]) -> str:
    n_d = len({c.discipline for c in cells})
    n_i = len({c.impression for c in cells})
    return f"{len(cells)}장 · 계열 {n_d}종 · 인상 {n_i}종 · {SIZE}×{SIZE}"
