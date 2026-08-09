"""판을 **재는 자들.** 눈이 놓치는 것을 숫자로 잡는다.

여기 있는 것은 전부 **같은 방식으로 태어났다** — 사람이 눈으로 한 번 잡고,
그다음에 「눈은 옅은 것을 놓친다」는 걸 깨닫고 자로 만들었다.

| 자 | 무엇을 놓쳤나 |
| --- | --- |
| `background_dirt` | `soft` 의 얼룩은 보였는데 `wash` 의 0.31% 는 안 보였다 (§27.25.3) |
| `garment_colour` | 「코트가 주황이 됐다」는 보였는데 **얼마나** 인지는 못 셌다 (§27.27) |

**둘 다 판정을 대신하지 않는다.** 무엇을 버릴지는 사람이 보고 고른다.
자는 **볼 것을 줄여 줄 뿐이고, 조용히 깨진 것을 놓치지 않게 할 뿐이다.**
"""

from __future__ import annotations

# ── 배경이 깨졌나 ────────────────────────────────────────────────────────────
#
# 재는 곳은 **인물이 절대 안 닿는 좌우 바깥 띠**다. 세로 규격(832x1216)에 전신을
# 세우면 인물이 가운데 3분의 1을 안 넘는다 — 28장에서 확인했다.

#: 이보다 어두우면 흰 배경이 아니다.
WHITE_CUT = 246
#: 바깥 띠에서 이 비율을 넘게 더러우면 **깨진 것** (실측: `soft` #2 가 5.86%).
DIRTY_BREAK = 1.0
DIRTY_WARN = 0.3


def background_dirt(path: str) -> tuple[float, int]:
    """`(바깥 띠의 얼룩 비율 %, 최대 편차)`. PIL 이 없으면 `(-1, -1)`."""
    try:
        from PIL import Image
    except ImportError:
        return -1.0, -1
    im = Image.open(path).convert("L")
    w, h = im.size
    px = im.load()
    xs = list(range(0, int(w * 0.18), 3)) + list(range(int(w * 0.82), w, 3))
    band = [px[x, y] for y in range(0, h, 3) for x in xs]
    if not band:
        return -1.0, -1
    return sum(1 for v in band if v < WHITE_CUT) / len(band) * 100.0, 255 - min(band)


def background_verdict(dirt: float) -> str:
    if dirt < 0:
        return "?"
    if dirt > DIRTY_BREAK:
        return "깨짐"
    return "의심" if dirt > DIRTY_WARN else "성함"


# ── 화풍이 ③ 의 옷 색을 이기나 ───────────────────────────────────────────────
#
# **§27.25.6 을 자로 만든 것이다.** 눈으로는 「코트가 주황이 됐다」까지만 보이고
# 「조금 달라졌다」와 「완전히 덮였다」의 중간이 아주 많다.
#
# # 왜 이것이 취향이 아니라 **구조적 탈락 사유**인가
#
# ② 는 ③ 보다 **앞**이라 화풍의 색 목록이 인물의 옷 색을 이긴다.
# **3000명이 각자 다른 옷을 입어야 하는데 화풍이 색을 정하면 전부 같은 옷이 된다.**
# 화풍의 색 칸은 「무엇을 칠하라」가 아니라 **「채도와 온도를 어디에 두라」**여야 한다.
#
# # 재는 법 — **옷 색이 정반대인 인물 둘을 같은 화풍으로 뽑는다**
#
# 우리 표본 둘이 이 시험에 딱 맞는다. ③ 이 시키는 색이 정반대다:
#
#     #2 / #2b  `charcoal ... ash-gray ...`     → 무채색. **채도가 낮아야 맞다**
#     #3        `crimson vital-covering plates` → 진홍.  **채도가 높아야 맞다**
#
# **그래서 신호가 둘이고, 지배가 양쪽으로 일어난다:**
#
#     ㉮ 숯빛이 색을 입었나  — 채도를 올리는 화풍이 **없는 색을 칠한다**
#     ㉯ 진홍이 죽었나       — 채도를 내리는 화풍이 **있는 색을 지운다**
#
# **둘 다 「화풍이 ③ 을 이긴 것」이다.** 방향만 반대다. 하나만 재면 절반을 놓친다 —
# 실측: `neon` 은 숯빛을 칠했고(C* 25.9) `varied` 는 진홍을 죽였다(C* 17.9).
#
# # 상자를 왜 좁게 두나
#
# 넓히면 소매와 다리와 살빛이 섞여 **평균이 회색으로 수렴한다.** 실측으로
# 상자를 넓혔더니 성한 `ink` 와 지배하는 `cel` 이 같이 뭉개졌다.
# **③ 이 색을 지정하는 자리가 정확히 가슴이다** (`charcoal coat`, `crimson plates`).
# 좁은 상자가 그 자리를 정확히 본다. 얼굴(머리색)과 신발은 피한다.

#: 가슴. (x0, y0, x1, y1) 비율. **넓히지 마라** — 위 주석이 이유다.
TORSO_BOX = (0.40, 0.30, 0.60, 0.52)
#: 배경(흰색)과 선(검정)을 몸통 표본에서 뺀다. 색을 재는 것이지 명암을 재는 게 아니다.
_INK_CUT, _PAPER_CUT = 40, 232


def _torso_lab(path: str):
    """몸통에서 배경과 선을 뺀 화소의 평균 Lab. 표본이 없으면 `None`."""
    import numpy as np
    from PIL import Image

    im = Image.open(path).convert("RGB")
    w, h = im.size
    x0, y0, x1, y1 = TORSO_BOX
    crop = np.asarray(im.crop((int(w * x0), int(h * y0), int(w * x1), int(h * y1))),
                      dtype=np.float64) / 255.0
    flat = crop.reshape(-1, 3)
    lum = flat.mean(axis=1) * 255.0
    keep = flat[(lum > _INK_CUT) & (lum < _PAPER_CUT)]
    if len(keep) < 50:
        return None

    # sRGB → 선형 → XYZ(D65) → Lab. 자잘한 의존을 안 늘리려고 직접 편다.
    lin = np.where(keep <= 0.04045, keep / 12.92, ((keep + 0.055) / 1.055) ** 2.4)
    m = np.array([[0.4124, 0.3576, 0.1805],
                  [0.2126, 0.7152, 0.0722],
                  [0.0193, 0.1192, 0.9505]])
    xyz = lin @ m.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16.0 / 116.0)
    lab = np.stack([116.0 * f[:, 1] - 16.0,
                    500.0 * (f[:, 0] - f[:, 1]),
                    200.0 * (f[:, 1] - f[:, 2])], axis=1)
    return lab.mean(axis=0)


def garment_colour(path: str) -> tuple[float, float]:
    """`(몸통 밝기 L*, 몸통 채도 C*)`. 못 재면 `(-1, -1)`.

    `C*` 가 채도다. 숯빛 코트는 낮아야 맞고, **높으면 화풍이 칠한 것이다.**
    """
    try:
        lab = _torso_lab(path)
    except ImportError:
        return -1.0, -1.0
    if lab is None:
        return -1.0, -1.0
    return float(lab[0]), float((lab[1] ** 2 + lab[2] ** 2) ** 0.5)


def colour_distance(path_a: str, path_b: str) -> float:
    """두 판의 몸통 색 거리(ΔE). **다른 옷이 아직 다른가.** 못 재면 `-1`."""
    try:
        a, b = _torso_lab(path_a), _torso_lab(path_b)
    except ImportError:
        return -1.0
    if a is None or b is None:
        return -1.0
    return float(((a - b) ** 2).sum() ** 0.5)


#: 임계값은 **눈으로 이미 판정이 끝난 판들에 맞춰 잡았다** (§27.27.1) —
#: `ink`/`varied`/`sepia` 가 숯빛을 지켰고 `gradient`/`cel`/`hairline` 이 칠했다.
#: 숫자를 먼저 정하고 판을 거기 맞추지 않는다. **판이 먼저고 자가 나중이다.**
#: 숯빛 코트가 이보다 진하면 **화풍이 없는 색을 칠한 것**이다.
#: 실측: `ink` 4.0 · `wash` 4.3 · `hatch` 1.4 (지킴) 대 `neon` 25.9 · `cel` 15.6 (칠함).
CHROMA_TINTED = 11.0
#: 진홍 갑옷이 이보다 옅으면 **화풍이 있는 색을 지운 것**이다.
#: 실측: `heavy` 38.9 · `gradient` 42.5 (지킴) 대 `hairline` 13.3 · `cel` 14.4 (지움).
CHROMA_KILLED = 20.0
DELTA_MERGED = 28.0     # 둘의 옷 색이 이보다 가까우면 같은 옷으로 수렴한 것이다
CHROMA_PAINTED = 22.0   # (옛 이름 — 아래 `colour_verdict` 가 쓴다)


def colour_verdict(chroma_neutral: float, delta: float) -> str:
    """`(무채색이어야 할 인물의 채도, 둘 사이 거리)` 로 판정한다."""
    if chroma_neutral < 0:
        return "?"
    if chroma_neutral > CHROMA_PAINTED or 0 <= delta < DELTA_MERGED:
        return "지배"
    if chroma_neutral > CHROMA_TINTED:
        return "물듦"
    return "지킴"


# ── 화풍끼리 실제로 갈리나 ───────────────────────────────────────────────────
#
# **사용자 평이 「화풍이 너무 안 드러난다」였다.** 열넷을 뽑았는데 다 비슷했다.
# 그러면 **후보끼리의 거리를 재는 자**가 있어야 「이번엔 갈렸다」를 말할 수 있다.
#
# `outputs/minimal-char/stylebench/bench.json` 에 그 흔적이 있다:
#
#     noise 27.8   OLD spread 41.97   NEW spread 29.91
#
# **잡음 바닥이 27.8 인데 새 형식의 벌어짐이 29.9 다.** 화풍을 여섯 개 바꾼 것이
# **시드 하나 바꾼 것과 거의 같았다.** 그 판이 우리 판과 같은 병을 앓았다.
#
# **그쪽 계산 코드는 안 남아 있다.** 그래서 절대값을 그쪽과 비교하지 않는다 —
# **우리 잡음 바닥을 우리가 재고 우리 벌어짐과 비교한다.**
#
#     잡음 바닥 = 같은 화풍, 시드만 다른 판들 사이의 평균 거리
#     벌어짐   = 다른 화풍, 시드는 같은 판들 사이의 평균 거리
#
# **벌어짐이 잡음 바닥을 못 넘으면 그 후보 묶음은 화풍이 안 갈린 것이다.**

#: 재기 전에 이 크기로 줄인다. 화풍은 큰 덩어리의 색과 명암이라 세부가 필요 없고,
#: 줄이면 **붓질 하나하나가 아니라 화면 전체의 인상**을 비교하게 된다.
BENCH_SIZE = 64


def _bench_lab(path: str):
    """판 하나를 `BENCH_SIZE²` Lab 판으로. 화풍 거리를 재는 표본이다."""
    import numpy as np
    from PIL import Image

    im = Image.open(path).convert("RGB").resize((BENCH_SIZE, BENCH_SIZE), Image.BILINEAR)
    rgb = np.asarray(im, dtype=np.float64) / 255.0
    lin = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    m = np.array([[0.4124, 0.3576, 0.1805],
                  [0.2126, 0.7152, 0.0722],
                  [0.0193, 0.1192, 0.9505]])
    xyz = lin @ m.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16.0 / 116.0)
    return np.stack([116.0 * f[..., 1] - 16.0,
                     500.0 * (f[..., 0] - f[..., 1]),
                     200.0 * (f[..., 1] - f[..., 2])], axis=-1)


def image_distance(path_a: str, path_b: str) -> float:
    """두 판의 평균 화소 ΔE. 크면 다르게 보이는 것이다."""
    import numpy as np
    a, b = _bench_lab(path_a), _bench_lab(path_b)
    return float(np.sqrt(((a - b) ** 2).sum(axis=-1)).mean())


def spread(paths: list[str]) -> float:
    """판 묶음의 **평균 쌍거리.** 둘 미만이면 `-1`."""
    if len(paths) < 2:
        return -1.0
    ds = [image_distance(paths[i], paths[j])
          for i in range(len(paths)) for j in range(i + 1, len(paths))]
    return sum(ds) / len(ds)


# ── 발밑에 그림자가 지나 ─────────────────────────────────────────────────────
#
# **배경이 열리면 「어둡다」로는 못 잰다.** 흰 배경일 때는 어두운 화소를 세면 됐는데
# 종이색·회색 캔버스·검정 배경에서는 배경 자체가 어둡다.
#
# 그래서 **같은 높이의 배경과 견준다.** 접지 그림자는 발밑 **가운데**에만 생기는
# 국소적인 얼룩이고, 배경은 좌우로 이어진다. 가운데가 옆구리보다 어두우면 그림자다.

#: 발밑으로 보는 띠 (아래에서부터). 접지 그림자가 앉는 자리다.
FOOT_BAND = (0.88, 1.00)
#: 같은 높이에서 이만큼 어두우면 그림자로 센다 (L* 차이).
FOOT_DARK = 8.0
FOOT_BREAK = 6.0   # 이 비율(%)을 넘으면 **그림자가 있다**


def foot_shadow(path: str) -> float:
    """발밑 띠에서 **옆구리 배경보다 어두운** 화소의 비율 %. 못 재면 `-1`.

    배경 색이 무엇이든 상관없다 — **가로로 견주기 때문이다.**
    """
    try:
        import numpy as np
        from PIL import Image
    except ImportError:
        return -1.0
    im = Image.open(path).convert("L")
    w, h = im.size
    a = np.asarray(im, dtype=np.float64)[int(h * FOOT_BAND[0]):int(h * FOOT_BAND[1]), :]
    if a.size == 0:
        return -1.0
    side = np.concatenate([a[:, :int(w * 0.12)], a[:, int(w * 0.88):]], axis=1)
    ref = np.median(side, axis=1, keepdims=True)      # 줄마다 배경 밝기
    # **발 자체를 세면 안 된다.** 신발은 배경보다 늘 어둡다 — 첫 판이 23~50% 를 냈고
    # 그게 전부 신발이었다. 그림자만 **옆으로 번지므로** 발 옆을 본다.
    near = np.concatenate([a[:, int(w * 0.18):int(w * 0.38)],
                           a[:, int(w * 0.62):int(w * 0.82)]], axis=1)
    return float((near < ref - FOOT_DARK).mean() * 100.0)
