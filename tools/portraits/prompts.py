"""초상 프롬프트 — 근거는 전부 `docs/design/27-portraits.md` 에 있다.

# 이 파일을 고치기 전에 읽을 것

**모델은 문장의 논리가 아니라 낱말을 읽는다** (`21-title.md` §21.13.13).
부정도 비유도 방향 지시도 안 통한다 — `NOT screaming` 은 비명 지르는 그림을,
`like a pillow` 의 `skull` 은 소품 두개골을, `toward us` 는 좌우 대칭을 만들었다.

> **점검법: 문법을 다 지우고 명사만 남겨 읽어라. 그 목록이 화면에 나올 것들이다.**

`python tools/portraits/prompts.py` 로 그 점검을 돌릴 수 있다 —
부정어 · 비유어 · 정면 지시어를 긁어서 찍는다. **문자열을 고쳤으면 돌려라.**

# 지금 이 파일이 지키고 있는 것

| 규칙 | 상태 |
| --- | --- |
| 부정문 (`no` · `not` · `without`) | **하나도 없다** (§27.9) |
| 비유 (`like a` · `as if`) | **하나도 없다** |
| 정면 지시 (`toward us` · `facing the camera`) | **하나도 없다.** 사분의 삼을 **도형**으로 서술한다 (§27.8) |
| 크로마 · 램프 명사 | **하나도 없다.** 컷아웃을 안 하므로 필요가 없다 |

`STYLE` 과 `SHADY` 는 타이틀 레인의 `tools/gen_layers.py` 에서 **한 글자도 안 고치고**
가져왔다. 그 문자열이 심사를 통과한 인물 넷을 만들었다 (§27.6).
**베끼는 것이지 고쳐 쓰는 것이 아니다** — 같은 낱말이 같은 그림을 부른다.
"""

from __future__ import annotations

import re
import sys

# ---------------------------------------------------------------------------
# 화풍 — 타이틀에서 그대로 가져온 둘. **고치지 마라** (§27.6)
# ---------------------------------------------------------------------------

STYLE = (
    "dramatic video game key art, rich saturated colour, painterly digital illustration "
    "with crisp animation-background rendering, strong chiaroscuro, "
    "warm gold key light against deep cold teal shadow"
)

SHADY = (
    "grubby and slightly seedy, worn and greasy surfaces, "
    "the faint sense that this whole arrangement is crooked"
)

# ---------------------------------------------------------------------------
# 규격 — §24.20.4 가 정했다. 이 레인은 바꾸지 않는다
# ---------------------------------------------------------------------------

SIZE = 512

#: 흉상. **어깨가 규격의 일부다** — 어깨가 보여야 옷과 장비로 계열이 읽힌다
#: (§24.20.4 근거 3). 얼굴만 크게 잡으면 계열이 화면에서 사라진다.
#:
#: **`both shoulders` 를 뺐다 — 1차 탐침의 범인이다** (§27.15.1).
#: 「어깨 둘」은 어깨 둘이 다 보이는 각도, 즉 정면을 부르는 낱말이었다.
#: `GEOMETRY` 가 사분의 삼을 시키는 동안 이 문장이 반대로 당기고 있었다.
FRAME = (
    "A head-and-shoulders portrait of one single person. "
    "The head and shoulders fill the picture and the crop ends at the chest."
)

#: 얼굴이 타이틀의 인간 넷과 같은 사람들이어야 한다 (§27.15.1).
#: 1차 탐침의 얼굴은 **어리고 말끔했다** — `SHADY` 가 옷에만 앉고 얼굴에는 안 앉았다.
#: 그래서 얼굴에 직접 건다. 살빛이 따뜻해지면서 **차가운 배경과의 대비도 같이 오른다** —
#: `STYLE` 이 말하는 `warm gold key light against deep cold teal shadow` 가 그제야 선다.
WEATHER = (
    "This is a grown adult who works underground for a living: the skin is ruddy and "
    "weathered, marked with grime, old sweat and small healed nicks, "
    "the face lined and lived-in."
)

#: **사분의 삼을 방향이 아니라 도형으로 시킨다** (§27.8).
#:
#: `toward us` 가 좌우 대칭을 만든 것이 §21.13.16 ⑥ 의 기록이고, 그 대칭이
#: `demon_b` 의 외눈 규칙을 두 판 연속 이겼다 (§21.13.14). 초상은 얼굴 하나가
#: 판을 다 쓰는 그림이라 이 함정에 가장 깊이 걸린다 — 대칭인 얼굴은 개성이 죽고,
#: 개성이 죽으면 변형 100장이 서로 구분되지 않아 **격자 전체가 헛일이 된다.**
#:
#: **1차 탐침에서 도형 서술만으로는 졌다** (§27.15.1). 세 장 다 정면 대칭이었다.
#: 그래서 §21.13.13 을 다시 읽고 **내가 그 절을 넓게 잘못 읽었다는 것**을 찾았다 —
#: 그 절이 확인한 것은 *"`toward us` 가 정면 대칭을 만든다"* 이고, 그것은
#: **정면 지시가 실제로 잘 먹혔다**는 뜻이다. 안 통한 것은 방향 지시 일반이 아니라
#: **부정으로 방향을 미는 것**이었다.
#:
#: 그리고 반증이 판에 남아 있다 — `hunter_left` 의
#: `Seen in THREE-QUARTER view from their front-left` 는 **제대로 사분의 삼을 냈다.**
#: 같은 모델 · 같은 화풍 · 같은 레인의 실측이다.
#:
#: **그래서 그 문구를 그대로 앞에 세우고, 도형 서술은 뒤에 받침으로 남긴다.**
GEOMETRY = (
    "Seen in THREE-QUARTER view, the head turned well round onto one side: the far cheek "
    "is narrow and cut short by the line of the nose, the far ear stays hidden behind the "
    "cheek, and the near cheek is broad and open. The near shoulder comes forward while "
    "the far shoulder is set back behind the jaw."
)

#: **빛은 방향만 말하고 출처를 말하지 않는다** (§27.9).
#: room-studio 의 결함이 `lamp` · `flame` · `fire` 가 소품마다 등불을 그려 넣은 것이었다.
#: `key light` 는 지시어라 안전하다 — `STYLE` 이 이미 들고 있는데 `hunter_*` 넷에
#: 등불이 하나도 안 그려져 있다 (§21.13.16 ⑦ 의 「먹여도 되는 낱말」).
LIGHT = (
    "A warm gold key light rakes across one side of the face and the near shoulder; "
    "the other side of the face and the far shoulder fall away into deep cold teal shadow."
)

#: **테두리를 재는 관문이 이 문장을 검사한다** (§27.12).
#: room-studio 가 얻은 것 — 프롬프트가 요구하는 것이 *"배경이 프레임의 모든 변과
#: 모서리까지 이어진다"* 이면, **테두리를 재면 그 요구를 그대로 검사하게 된다.**
#: 그래서 요구를 테두리의 말로 적는다.
BACKGROUND = (
    "Behind the shoulders there is only plain dark cold teal, evenly dark and smooth "
    "all the way out to every edge and corner of the picture."
)

# ---------------------------------------------------------------------------
# 계열 — `src/core/guild/member_discipline.gd` 의 `Kind` 순서다 (§27.10)
# ---------------------------------------------------------------------------

#: 순서가 `MemberDiscipline.Kind` 와 같아야 한다. 색인이 곧 계열 번호다.
DISCIPLINES: list[tuple[str, str, str]] = [
    (
        "combat", "전투",
        # `hunter_*` 넷이 이미 입고 있는 것이다. **한쪽 어깨에만** 두면 §27.8 의
        # 비대칭이 공짜로 생긴다 — 조형으로 지키는 것이 낱말로 지키는 것보다 세다.
        "a hardened human treasure hunter. One heavy scavenged steel pauldron is strapped "
        "over the near shoulder while the other shoulder carries only cloth. A thick "
        "leather gorget wraps the throat with its chin strap running up past the jaw. "
        "The hair is cropped close and an old scar crosses the face.",
    ),
    (
        "scout", "정찰",
        # 민첩이 가장 높은 계열 (`_AGILITIES` 4). **금속을 빼는 것**이 전투와 가장
        # 크게 갈리는 지점이다. 두건은 **젖혀 놓는다** — 올린 두건은 은둔의 것이다.
        "a lean human treasure hunter. A deep cloth hood is pushed back off the head and "
        "bunched behind the neck, and a long wound scarf covers the throat. The hair is "
        "tied back tight. Everything worn here is cloth and soft worn leather.",
    ),
    (
        "engineer", "기공",
        # *"고도 차이와 통로 상태를 읽는다"* (`_EYES`). 감식의 외눈렌즈와 갈리도록
        # **두 알 + 검댕 + 앞치마** 셋으로 묶는다 — 한 축으로 가르면 판 하나가
        # 애매하게 나올 때 계열이 안 읽힌다 (§27.10).
        #
        # **어깨에 감은 줄을 두려다 뺐다.** `cable` · `wiring` 은 §21.13.4 가 폐기한
        # 방송 스튜디오 설정의 낱말이고, 줄 감은 기술자는 그 설정으로 읽힌다.
        "a soot-marked human treasure hunter. A thick canvas apron bib is buckled over "
        "both shoulders and a pair of heavy two-lens goggles is pushed up onto the "
        "forehead. Soot streaks the face, and the wooden haft of a hammer rises past "
        "one shoulder.",
    ),
    (
        "broker", "교섭",
        # *"상대의 성향 단서를 얻는다"*. **폐허에서 유일하게 차려입은 사람**이라는 읽기.
        # 귀고리 한쪽이 비대칭을 공짜로 만든다.
        "a well-turned-out human treasure hunter. A good coat with a heavy fur-trimmed "
        "collar sits over a worn shirt, and a thick chain hangs at the throat. The hair "
        "is oiled and combed back, and one ear carries a fat metal ring.",
    ),
    (
        "appraiser", "감식",
        # *"고가치 방의 위치를 좁힌다"*. **보는 도구**가 그 말의 조형이다.
        #
        # **1차·2차 탐침에서 기공의 고글이 여기로 샜다** (§27.15.2). 범인은 낱말이 아니라
        # **자리**였다 — 둘 다 `pushed up onto the forehead` 였고, 이마 한가운데는
        # 알이 둘 앉는 자리다. `single` 이라고 세 번 말해도 조형이 이긴다
        # (§21.13.14 — 좌우 대칭은 낱말을 이긴다. 이마 정중앙은 대칭 자리다).
        #
        # 그래서 **낱말이 아니라 자리를 옮겼다.** 관자놀이 한쪽 위는 알이 하나만 앉는
        # 자리라 고글이 될 수 없고, 덤으로 §27.8 의 비대칭이 공짜로 생긴다.
        "a neat and careful human treasure hunter. A single round brass jeweller's loupe "
        "on a slim band rides high above one temple, off to one side of the head. A high "
        "collar is buttoned right up under the chin and a slim strap crosses the throat. "
        "The hair is combed flat.",
    ),
]

# ---------------------------------------------------------------------------
# 인상 — 성향 6축 중 흉상이 나를 수 있는 둘 + 무색 (§27.3 · §27.11)
# ---------------------------------------------------------------------------

#: 조형은 §21.13.8 의 표를 옮겨 온 것이다. 그 표의 축이
#: **힘이 들어간 얼굴 ↔ 힘이 빠진 얼굴**이고, **무모 ↔ 신중이 정확히 그 축이다.**
#: 새로 발명하지 않는다.
#:
#: (이름, 한글, 문장, 계열당 변형 수)
#: 변형 수는 §27.5 — 인상 비율에 맞춘다. 무색이 34% 라 가장 많다.
IMPRESSIONS: list[tuple[str, str, str, int]] = [
    (
        "plain", "무색",
        # **가장 큰 칸이므로 가장 평범해야 한다.** §24.16.3 을 뒤집으면 —
        # 평범이 다수여야 극단이 눈에 띈다.
        "This is an ordinary working face: the head is level, the closed mouth sits easy, "
        "and the eyes rest steady and level. Tired, plain and unremarkable.",
        6,
    ),
    (
        "reckless", "무모",
        # **광기로 보내면 안 된다.** §21.13.8 이 *"눈이 완전히 동그랗게 열려 있다"* 를
        # 광기의 첫 줄로 꼽았고, 활짝 열린 눈은 무슨 표정을 붙여도 광기로 간다.
        # 그래서 무모는 **눈썹 한쪽 · 이 한쪽**의 비대칭으로 만든다.
        # 대칭으로 활짝 열면 미친 사람이 되고, 그러면 §21.13.15 대로 심사가 흔들린다.
        "The chin is lifted high and one eyebrow is hauled up far higher than the other. "
        "The eyes are lit up and eager, and the open grin bares the teeth on one side only. "
        "The cords of the neck stand out and the near shoulder is thrown forward.",
        4,
    ),
    (
        "cautious", "신중",
        # §21.13.8 의 「여유」 칸 그대로 — 늘어진 윗눈꺼풀 · 다문 평평한 입.
        # **머리는 더 돌아가 있는데 눈만 이쪽에 남는다** 가 「재고 있다」의 조형이고,
        # 덤으로 §27.8 의 사분의 삼을 한 번 더 밀어 준다.
        "The upper eyelids hang halfway down across the eyes and the chin is tucked in "
        "toward the throat. The mouth is one flat closed line. The head is turned well "
        "round while the eyes stay level and steady, weighing up what is in front of them.",
        4,
    ),
    (
        "vain", "과시",
        # **어깨를 각 잡고 펴는 것이 가장 쉬운 과시 표현인데 그것이 §27.8 을 어긴다.**
        # §21.13.14 의 *"진 쪽 요구의 근거를 갈아 끼워라"* 를 그대로 쓴 자리 —
        # 과시의 근거를 **턱과 치장**에서 가져온다.
        "The chin is raised to show off the better side of the face, and one corner of the "
        "closed mouth is pulled up into a pleased little smile. The hair is freshly "
        "arranged, the metal is polished bright, and an extra trinket or two is worked "
        "into the gear.",
        3,
    ),
    (
        "reclusive", "은둔",
        # **정찰과 겹친다** — 정찰의 두건은 젖힌 것이고 은둔의 두건은 올린 것이다.
        # `정찰 × 은둔` 칸에서는 두 배로 두건이 강조된다. **받아들인다** (§27.11) —
        # 계열이 안 읽히는 것보다 낫고 그 칸은 전체의 2.4% 다.
        "The head is lowered so the brow shades most of the face, and the gaze slides off "
        "to one side. The shoulders are drawn up toward the ears and the collar is pulled "
        "high against the jaw.",
        3,
    ),
]


# ---------------------------------------------------------------------------
# 조립
# ---------------------------------------------------------------------------

def _join(*parts: str) -> str:
    return " ".join(p.strip() for p in parts if p.strip())


def compose(discipline: int, impression: int) -> str:
    """칸 하나의 프롬프트.

    순서에 뜻이 있다 — **`FRAME` 이 계열보다 먼저다.** 모델이 구도를 정하기 전에
    흉상이라는 것을 알아야 한다. 계열을 먼저 두면 전신 인물화가 나오고
    그 뒤에 오는 프레임 지시가 크롭으로만 작동한다.
    """
    return _join(
        STYLE + ".",
        FRAME,
        "The subject is " + DISCIPLINES[discipline][2],
        WEATHER,
        IMPRESSIONS[impression][2],
        GEOMETRY,
        LIGHT,
        BACKGROUND,
        SHADY + ".",
    )


# ---------------------------------------------------------------------------
# 자기 점검 — §21.13.13 의 점검법을 코드로
# ---------------------------------------------------------------------------

#: 그 낱말을 모델에 먹이는 구조들. **`21-title.md` §21.13.16 이 손으로 한 것을 자동화한다.**
_SUSPECTS: list[tuple[str, str]] = [
    ("부정문", r"\b(?:no|not|never|without|nothing|none|neither|nor)\b\s+\w+"),
    ("비유", r"\b(?:like a|like an|as if|as though|resembling)\b\s+\w+"),
    ("정면 지시", r"\b(?:toward us|towards us|facing the camera|at the camera|"
                  r"facing the viewer|head-?on|full frontal|symmetrical)\b"),
    ("램프 명사", r"\b(?:lamp|lantern|torch|candle|brazier|sconce|flame|fire|wick|bulb)\b"),
    ("크로마", r"\b(?:magenta|chroma|gradient|vignette)\b"),
    ("폐기 설정", r"\b(?:truss|trusses|spotlight|loudspeaker|cable|wiring|scaffold|"
                  r"audience|signage)\b"),
]


def suspects_in(text: str) -> list[str]:
    """한 문자열에서 용의자를 긁는다. **GPT 산출을 검사하는 자리가 여기다.**

    파이프라인이 바뀌면서 이 함수의 무게가 달라졌다 (§27.9.1). 전에는 내가 쓴
    문자열 25개를 검사했는데, 이제는 **GPT 가 인물마다 새로 쓴 문장**을 검사한다.

    **GPT 는 부정문과 비유를 아주 잘 쓴다.** 사람이 읽기에 좋은 글의 습관이 여기서는
    전부 함정이다 — `a face that is not cruel` 은 모델에 `cruel` 을 먹이고
    `eyes like a hawk's` 는 매를 그린다.

    **걸리면 Klein 에 넣지 마라.** 문장을 고칠 게 아니라 낱말을 지워야 한다
    (`21-title.md` §21.13.13).
    """
    hits: list[str] = []
    for label, pattern in _SUSPECTS:
        for m in re.finditer(pattern, text, re.IGNORECASE):
            hits.append(f"{label}: {m.group(0)!r}")
    return hits


def nouns_in(text: str) -> list[str]:
    """문법을 지우고 남은 낱말. **§21.13.13 의 점검법을 그대로 돌린 것이다.**

    *"프롬프트를 다 쓰고 나서 문법을 전부 지우고 명사만 남겨 읽어 봐라.
    그 목록이 곧 화면에 나올 것들이다."*

    **정규식이 못 잡는 것을 사람이 여기서 잡는다.** §27.15.1 의 `both shoulders` 가
    그 예다 — `shoulders` 는 화면에 나와야 하는 명사라 목록에서 무해해 보이는데,
    「어깨 둘」이 정면을 부르고 있었다. **셈이 방향을 뜻하는 자리는 목록으로 안 걸린다.**
    """
    return sorted({w.lower() for w in re.findall(r"[A-Za-z][A-Za-z-]{3,}", text)})


def audit() -> int:
    """모든 칸의 프롬프트를 긁어 용의자를 찍는다. 걸린 개수를 돌려준다.

    **격자는 폐기됐지만(§27.2) 이 함수는 산다** — `DISCIPLINES` 와 `IMPRESSIONS` 는
    이제 칸이 아니라 **GPT 에게 줄 조형 어휘**이고, 그 어휘 자체도 함정이 없어야 한다.
    """
    bad = 0
    print("=== 프롬프트 자기 점검 (§21.13.13 의 점검법) ===\n")
    for di, (dname, dko, _) in enumerate(DISCIPLINES):
        for ii, (iname, iko, _, _n) in enumerate(IMPRESSIONS):
            hits = suspects_in(compose(di, ii))
            if hits:
                bad += len(hits)
                print(f"  [x] {dname}/{iname} ({dko}/{iko})")
                for h in hits:
                    print(f"        {h}")
    cells = len(DISCIPLINES) * len(IMPRESSIONS)
    plates = len(DISCIPLINES) * sum(n for *_r, n in IMPRESSIONS)
    print(f"  칸 {cells}개 · 판 {plates}장 · 용의자 {bad}개"
          f" → {'통과' if not bad else '**손봐야 한다**'}\n")

    # 명사만 남겨 읽은 목록도 같이 낸다 — 사람이 눈으로 보는 것이 최종 판정이다.
    print("  전투/무색 한 칸의 낱말 (중복 제외, 알파벳순):")
    _print_words(nouns_in(compose(0, 0)))
    return bad


def _print_words(words: list[str]) -> None:
    for i in range(0, len(words), 8):
        print("    " + " ".join(words[i:i + 8]))
    print()


def audit_file(path: str) -> int:
    """파일 하나에 든 프롬프트를 검사한다. **GPT 산출을 여기에 물린다** (§27.9.1).

        python tools/portraits/prompts.py --check gpt_output.txt
    """
    with open(path, encoding="utf-8") as f:
        text = f.read()
    hits = suspects_in(text)
    print(f"=== {path} — 함정 검사 ===\n")
    for h in hits:
        print(f"  [x] {h}")
    print(f"\n  용의자 {len(hits)}개 → "
          f"{'통과' if not hits else '**Klein 에 넣지 마라. 낱말을 지워라**'}\n")
    print("  명사만 남겨 읽은 목록 (**여기 있으면 안 될 것이 보이면 그 낱말을 지워라**):")
    _print_words(nouns_in(text))
    return len(hits)


if __name__ == "__main__":
    sys.path.insert(0, __file__.rsplit("prompts.py", 1)[0])
    import console

    console.utf8()
    if len(sys.argv) > 2 and sys.argv[1] == "--check":
        raise SystemExit(1 if audit_file(sys.argv[2]) else 0)
    raise SystemExit(1 if audit() else 0)
