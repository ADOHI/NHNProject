#!/usr/bin/env python
"""브리프 하나를 GPT 에 넣어 **열전**과 **착장**을 받는다.

    python tools/portraits/gen_character.py .captures/portraits/cast2/brief_13.txt

`docs/design/27-portraits.md` §27.19 의 사슬이다. **한 번 부르지 않고 세 번 부른다.**

    dump_person_briefs.gd
      → ① 열전   그 성향이 왜 생겼는지, 어린 시절부터
        → ② 착장   그 삶에서 유추한 옷과 장비
          → 코드가 프레임을 붙인다 → Klein 4B Pro
      → ③ 성향 맞추기   **열전만 주고 성향을 맞추게 한다** (합격 기준)

# 왜 한 번이 아니라 세 번인가

**성향은 결과다. 열전은 원인을 대야 한다.**

1차 실호출의 시트는 **수치를 말로 바꾼 것**이었다 —
`신중 90` 이 *"무모하게 뛰어들기보다 재며 확실한 순간에만 움직인다"* 가 됐다.
문장은 멀쩡한데 **아무것도 설명하지 않는다.** 왜 그런 사람이 됐는지가 없다.

착장도 같은 병이었다. 「전투 계열이니 갑옷」은 그 사람의 옷이 아니라 계열의 옷이다.
**원인이 서면 착장이 저절로 나온다** — *"아버지가 광부였다"* 가 있으면
*"아버지 곡괭이를 아직 쓴다"* 가 나온다.

그래서 열전을 먼저 받고, **그 열전을 읽혀서** 착장을 받는다.
한 번에 시키면 모델이 수치에서 곧장 옷으로 건너뛴다.

# ③ 이 이 도구의 합격 기준이다 (§27.19.2)

> **열전만 읽고 성향을 맞출 수 있어야 한다. 다만 열전에 성향 이름이 나오면 안 된다.**

「신중하다」고 쓰면 실패다. 읽고 나서 **「이 사람은 신중하겠구나」가 되면** 성공이다.
**이것은 정규식으로 못 잡는다** — 1차 실호출의 부호 오류와 같은 부류로,
문장이 완벽한데 하는 일이 틀린 종류다. 그래서 **모델에게 되물어서 잰다.**

# 무엇을 GPT 에게 맡기고 무엇을 안 맡기나 (§27.9.1)

| 코드가 고정한다 | GPT 가 쓴다 |
| --- | --- |
| 화풍 (`STYLE` · `SHADY`) | 그 인물의 삶 · 얼굴 · 표정 |
| **구도와 사분의 삼** (`FRAME` · `GEOMETRY`) | 그 인물의 옷과 장비 |
| 조명 · 배경 (`LIGHT` · `BACKGROUND`) | 흉터 · 머리 · 눈 |
| **닳음과 나이** (`WEATHER`) | |

**나이는 코드 쪽이다** (§27.18.1). 레코드가 들고 있으므로 `WEATHER` 가 직접 읽는다 —
코드가 아는 것을 모델에게 다시 알아내라고 시키지 않는다.

# 산출을 그대로 믿지 않는다

`prompts.suspects_in()` 을 걸어 부정문 · 비유 · 정면 지시 · 램프 명사 · **정면을 부르는
어깨**를 잡는다. 걸리면 **화면에 찍고 파일에 남긴다.** 조용히 지우지 않는다 —
무엇이 걸렸는지가 다음 판의 시스템 프롬프트를 고치는 근거다.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.request
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import console  # noqa: E402
import prompts  # noqa: E402

console.utf8()

MODEL = "gpt-5.6-luna"
ENDPOINT = "https://api.openai.com/v1/chat/completions"
#: 렉카가 쓴 값과 같다 (§19.B.7). 열전이 길어져서 한 번 올렸다.
MAX_TOKENS = 2400

#: 세계 설명. 세 부름이 다 같은 세계에 있어야 하므로 한 곳에 둔다.
WORLD = """세계: 다른 차원의 존재들이 유희로 게이트를 연다. 인간은 거기서 건져 올 것이 있어
제 발로 들어간다. 가장 큰 위협은 몬스터가 아니라 같은 목적으로 들어온 다른 탐험대다.
협상하고 배신하며 살아 나온다. 양쪽 다 자발적이라 피해자가 없다."""

#: ① 열전. **이 프롬프트가 이 레인에서 가장 무거운 자리다** (§27.19.2).
#:
#: 「수치를 말로 바꾸지 마라」가 전부다. 나머지 줄은 그것을 지키게 하는 장치다.
SYSTEM_CHRONICLE = (
    WORLD
    + """

너는 이 세계의 인물 열전을 쓴다. 인물 상세 화면에 들어가고 사람이 읽는다.

# 가장 중요한 것

**성향은 결과다. 너는 원인을 써야 한다.**

받은 성향 수치를 문장으로 번역하지 마라. **그 수치가 왜 그렇게 됐는지를 지어내라.**

- 나쁜 예: "무모하게 뛰어들기보다 끝까지 재며 확실한 순간에만 움직인다"
  — 이것은 「신중 90」을 풀어 쓴 것이다. 아무것도 설명하지 않는다.
- 좋은 예: "열여섯에 처음 들어간 게이트에서 넷이 죽고 혼자 나왔다.
  그 뒤로 문턱을 넘기 전에 출구부터 센다"
  — 원인이 있고 결과가 따라 나온다.

**성향의 이름을 쓰지 마라.** 무모, 신중, 선, 악, 의리, 실리, 위계, 자유,
정직, 기만, 과시, 은둔 — 이 낱말들을 열전에 쓰지 마라.
읽은 사람이 스스로 "이 사람은 그렇겠구나" 하게 만들어라.

# 원인의 재료는 받은 것 안에 있다. 허공에서 짓지 마라

- 나이 — 이 일을 몇 년 했나. 스물이면 최근이고 쉰이면 반평생이다
- 가족 — 있는 것도 없는 것도 원인이다. 형이 있으면 따라 들어왔을 수 있고,
  아버지가 있으면 가업일 수 있고, 아무도 없으면 혼자 자란 것이다
- 스승과 제자 — 누가 가르쳤나, 누구를 가르치나
- 소속 — 큰 길드인지 작은 데인지 무소속인지
- 계열 — 왜 이 일을 골랐나
- 유명세 — 이름이 알려졌다면 알려진 이유가 있어야 한다

# 어느 축을 쓰고 어느 축을 버리나 — **이걸 틀리면 없는 사람이 된다**

- **「(극)」이라고 적힌 축은 반드시 원인을 대라.** 그 축이 그 사람의 가장 큰 특징이고,
  읽은 사람이 그 축을 못 맞추면 열전이 실패한 것이다.
  **극인 축과 반대로 읽히는 일화를 앞세우지 마라.**
- 「약간」이라고 적힌 축은 약하게만 쓴다. 한 줄을 넘기지 마라.
- **쪽이 안 적힌 축은 이야기에 아예 넣지 마라.** 그 사람은 그 축에서 가운데다.
  넣으면 레코드에 없는 성향이 생긴다.

**받은 것과 어긋나면 안 된다.** 가족이 없다고 적혀 있는데 형 이야기를 쓰면 실패다.
받은 관계에 있는 사람은 이름으로 부르고, 없는 사람은 만들지 마라.
이 세계의 가족 자료에는 부계 혈연과 사제만 있다.
어머니, 아내, 남편, 혼인을 지어내지 마라.

# 문체

한국어. 여덟에서 열두 줄. **과장하지 마라.** 이 세계에는 과장하는 글이 따로 있고
열전은 사실 쪽이다. 영웅으로 만들지 말고 그냥 살아온 대로 적어라.

**지금은 사건 기록이 없으므로 태생부만 쓴다** — 어디서 나서 어떻게 자랐고
어떻게 이 일을 갖게 됐으며 지금 무엇을 하고 있나까지. 최근의 사건은 쓰지 마라.

받은 글의 괄호 안내는 너에게 주는 지시다. 산출에 옮겨 적지 마라.
「없다」, 「자료에 없다」 같은 말도 옮겨 적지 마라.
이름은 홑화살괄호 안에 있다. 괄호는 입력 표시이니 산출에 쓰지 마라."""
)

#: ② 착장. **열전을 읽고 옷을 유추한다.** 수치는 안 준다.
SYSTEM_LOOK = (
    WORLD
    + """

너는 인물 열전을 읽고 **그 사람이 지금 입고 있는 것**을 쓴다.
산출은 이미지 생성 모델에 그대로 들어간다.

# 옷은 그 사람의 삶에서 나온다

열전에 아버지가 광부였다고 적혀 있으면 아버지가 입던 외투를 물려 입었을 수 있다.
팀이 전멸했다고 적혀 있으면 그때 얻은 흉터나 남의 장비를 물려 입은 자국이 있다.
**직업만 보고 옷을 고르지 마라.** 같은 직업이라도 살아온 것이 다르면 다르게 입는다.

# 거름망 둘. 이것을 어기면 그림이 깨진다

**하나 — 가슴 위만 그린다. 화면에는 머리와 어깨와 가슴 윗부분밖에 없다.**

허리, 손, 팔, 무릎, 발, 허리에 찬 것, 등에 멘 것, 주머니 속의 것은 **화면 밖이다.**
숨겨져 있다고 적은 것도 쓰지 마라 — 안 보이는 것은 그릴 수 없다.

**둘 — 도구와 무기는 아예 적지 마라. 가슴 위라도 안 된다.**

이 그림은 나중에 캐릭터 스프라이트의 바탕이 되고, **무기와 도구는 손에 따로 붙는다.**
그림에 이미 도구가 있으면 도구가 둘이 된다.

곡괭이, 망치, 검, 칼, 도끼, 활, 창, 방패, 연장, 밧줄, 가방, 배낭, 주머니 —
열전에 나와도 쓰지 마라. **어깨에 메거나 등 뒤로 솟은 것도 안 된다.**

**남는 것은 옷 · 방어구 · 흉터 · 머리 · 장신구다.** 몸에 붙어 있고 손에 안 든 것.
그러니 그 사람의 삶을 **몸에 남은 것**으로 적어라 —
흉터, 물려 입은 외투, 길드 표식, 지운 문신, 덴 자국, 기운 자리.

**머리와 몸이 서로를 크게 가리는 자세는 적지 마라.** 나중에 파츠로 나눌 때 걸린다.

# 어떻게 쓰나

영어 한 문단. 아래를 지켜라.

- 얼굴, 체격, 머리, 눈, 눈썹, 입, 표정, 목과 어깨와 가슴 위의 옷과 장비를 쓴다.
- **눈에 보이는 것만 써라. 색과 모양과 재질을 적어라.**
  presence, attire, details, equipment, features 같이 뭉뚱그린 말은
  그릴 수 있는 것이 아니라 화면에 아무것도 안 나온다.
- **성격을 형용사로 적지 마라. 얼굴의 모양으로 적어라.**
  cautious 라고 적지 말고 "윗눈꺼풀이 눈을 반쯤 덮고, 턱을 목 쪽으로 당기고,
  입이 다물린 평평한 선" 처럼 적어라. 그림은 형용사를 못 그린다.
- **나이를 문장으로 쓰지 마라.** 코드가 레코드의 나이를 따로 붙인다.
  **다만 머리와 얼굴이 받은 나이와 어긋나면 안 된다** — 쉰이 넘은 사람에게
  검은 머리만 적으면 코드가 붙인 나이와 싸워서 그림이 젊게 나온다.
  나이가 있으면 머리의 세기와 살의 늘어짐을 그 나이에 맞춰 적어라.
- 이름을 쓰지 마라. 그림에 이름은 안 나온다.
- 화풍, 카메라, 각도, 구도, 조명, 배경, 피부의 닳음은 쓰지 마라. 코드가 따로 붙인다.
- 부정문을 쓰지 마라. no, not, without, nothing 을 쓰지 마라.
  있어야 할 것만 써라. "not cruel" 이라고 쓰면 잔인한 그림이 나온다.
- 비유를 쓰지 마라. like a, as if, as though 를 쓰지 마라.
  "eyes like a hawk" 는 매를 그린다.
- 정면을 시키지 마라. facing the camera, toward us, looking at the viewer 를 쓰지 마라.
- 어깨를 나란히 놓지 마라. both shoulders, squared shoulders, shoulders back 을 쓰지 마라.
  어깨 둘이 나란하면 어깨 둘이 다 보이는 각도, 곧 정면이 된다.
  어깨는 한쪽만 앞으로 나온다.
- 등불, 횃불, 촛불, 램프 같은 광원을 쓰지 마라."""
)

#: ③ 성향 맞추기. **열전이 원인을 댔는지를 재는 자다** (§27.19.2).
#:
#: 열전만 준다. 수치도 브리프도 안 준다 — 주면 시험이 무의미해진다.
SYSTEM_GUESS = """너는 인물 열전을 읽고 그 사람의 성향을 맞춘다.

여섯 축이 있다. 각 축마다 어느 쪽인지 하나만 고른다.
읽어서 판단이 안 서는 축은 「가운데」라고 답한다. 억지로 고르지 마라.

무모/신중 · 선/악 · 의리/실리 · 위계/자유 · 정직/기만 · 과시/은둔

아래 형식으로 여섯 줄만 낸다. 설명을 붙이지 마라.

무모/신중: <무모 또는 신중 또는 가운데>
선/악: <선 또는 악 또는 가운데>
의리/실리: <의리 또는 실리 또는 가운데>
위계/자유: <위계 또는 자유 또는 가운데>
정직/기만: <정직 또는 기만 또는 가운데>
과시/은둔: <과시 또는 은둔 또는 가운데>"""

#: 열전에 나오면 안 되는 낱말 — **성향의 이름이다** (§27.19.2).
#: 잡는 것이 아니라 **찍는다.** 「선」과 「악」은 보통 한국어에도 흔해서
#: 관문으로 세우면 거짓 경보가 난다 (§27.12 의 규율).
_TRAIT_WORDS = ["무모", "신중", "의리", "실리", "위계", "기만", "과시", "은둔"]

#: 브리프에서 값을 꺼내는 자리들. **`PersonDossier` 의 형식을 읽는다.**
_AGE_LINE = re.compile(r"^-\s*나이:\s*(\d+)\s*세\s*$", re.MULTILINE)
_GENDER_LINE = re.compile(r"^-\s*성별:\s*(\S+)\s*$", re.MULTILINE)
#: 계열 줄은 **뜻풀이까지 통째로 가져간다** (§27.19.3). 이름 두 글자만 넘기면
#: 모델이 `기공` 을 氣功 으로 읽는다.
_DISCIPLINE_LINE = re.compile(r"^-\s*계열:\s*(.+?)\s*$", re.MULTILINE)
_AXIS_LINE = re.compile(r"^-\s*(\S+?)\s*축:\s*(.+)$", re.MULTILINE)


def call(system: str, user: str) -> str:
    payload = {
        "model": MODEL,
        "max_completion_tokens": MAX_TOKENS,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
    }
    req = urllib.request.Request(
        ENDPOINT, data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json",
                 "Authorization": "Bearer " + os.environ["OPENAI_API_KEY"]})
    with urllib.request.urlopen(req, timeout=300) as r:
        return json.load(r)["choices"][0]["message"]["content"].strip()


def _one(pattern: re.Pattern[str], brief: str, what: str) -> str:
    """브리프에서 한 값. **못 찾으면 터뜨린다.**

    조용히 넘어가면 그 칸이 빠진 채로 그림이 나오고, 어긋난 것을 나중에 눈으로
    찾을 수 없다 — 1차 실호출의 부호 오류가 정확히 그런 종류였다 (§27.18).
    """
    found = pattern.search(brief)
    if not found:
        raise RuntimeError(f"브리프에 {what} 줄이 없다. dump_person_briefs.gd 를 다시 돌려라")
    return found.group(1)


def truth_of(brief: str) -> dict[str, str]:
    """브리프의 성향 여섯 축을 **쪽 이름으로** 읽는다. ③ 의 정답지다.

    브리프가 이미 쪽을 말로 적고 있으므로 (`정직/기만 축: 정직 쪽으로 52`)
    부호를 푸는 일이 없다. **그것이 §27.18 의 요점이다** — 형식이 해석을 요구하지
    않으면 읽는 쪽도 틀릴 수 없다. 사람도 모델도 코드도 마찬가지다.
    """
    truth: dict[str, str] = {}
    for axis, words in _AXIS_LINE.findall(brief):
        if words.startswith("어느 쪽도"):
            truth[axis] = "가운데"
            continue
        # `약간 정직 쪽으로 52` · `정직 쪽으로 52  (극)` 둘 다 두 번째에서 첫 낱말을 뺀다.
        parts = words.replace("약간 ", "").split()
        truth[axis] = parts[0] if parts else "가운데"
    return truth


def guessed_of(text: str) -> dict[str, str]:
    """모델이 낸 여섯 줄을 읽는다."""
    out: dict[str, str] = {}
    for line in text.splitlines():
        if ":" not in line:
            continue
        axis, _, side = line.partition(":")
        out[axis.strip().lstrip("-").strip()] = side.strip().strip("<>").split()[0] if side.strip() else ""
    return out


def score(truth: dict[str, str], guess: dict[str, str]) -> tuple[int, int, list[str]]:
    """맞은 축 수 · 잰 축 수 · 줄별 결과.

    **가운데인 축도 센다.** 「가운데를 가운데로 봤다」도 열전이 제대로 섰다는 증거다 —
    1차 실호출이 진 자리가 정확히 거기였다 (`위계 5` 를 「자유를 중시한다」로 썼다).
    """
    lines: list[str] = []
    hit = 0
    for axis, want in truth.items():
        got = guess.get(axis, "(없음)")
        ok = got == want
        hit += int(ok)
        lines.append(f"  {'[o]' if ok else '[x]'} {axis:<8} 레코드 {want:<5} 맞춘 것 {got}")
    return hit, len(truth), lines


def compose(look: str, age: int) -> str:
    """GPT 가 쓴 착장을 코드의 고정 문장 사이에 끼운다 (§27.9.1).

    순서에 뜻이 있다 — **`FRAME` 이 인물보다 먼저다.** 모델이 구도를 정하기 전에
    흉상이라는 것을 알아야 한다.
    """
    return " ".join(p.strip() for p in [
        prompts.STYLE + ".",
        prompts.FRAME,
        look,
        # **`WEATHER` 는 코드가 붙인다** (§27.15.4 ②). 얼굴을 GPT 에게 맡겼더니
        # *"a sharp angular face"* 라고만 쓰고 닳음을 안 썼다. **닳음은 인물의
        # 개성이 아니라 이 세계의 성질이다** — 인물마다 달라질 것이 아니라
        # 화풍처럼 고정돼야 한다. **나이도 여기로 왔다** (§27.18.1).
        prompts.weather(age),
        prompts.GEOMETRY,
        prompts.LIGHT,
        prompts.BACKGROUND,
        prompts.SHADY + ".",
    ] if p.strip())


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("brief", help="dump_person_briefs.gd 가 낸 파일")
    ap.add_argument("--out", default="", help="기본: 브리프와 같은 폴더")
    ap.add_argument("--skip-guess", action="store_true",
                    help="성향 맞추기 시험을 건너뛴다. **평소에는 켜 둬라 — 합격 기준이다**")
    args = ap.parse_args()

    with open(args.brief, encoding="utf-8") as f:
        raw = f.read()
    # 고도 배너가 섞여 들어오므로 첫 칸부터 자른다.
    brief = raw[raw.index("[인물]"):] if "[인물]" in raw else raw

    age = int(_one(_AGE_LINE, brief, "나이"))
    gender = _one(_GENDER_LINE, brief, "성별")
    discipline = _one(_DISCIPLINE_LINE, brief, "계열")

    stem = os.path.splitext(os.path.basename(args.brief))[0].replace("brief_", "")
    out_dir = args.out or os.path.dirname(os.path.abspath(args.brief))
    os.makedirs(out_dir, exist_ok=True)

    print(f"=== {MODEL} — 인물 {stem} · {gender} · {age}세 · {discipline} ===\n")

    # ---- ① 열전 -----------------------------------------------------------
    chronicle = call(SYSTEM_CHRONICLE, brief)
    print("--- ① 열전 ---")
    print(chronicle + "\n")

    leaked = [w for w in _TRAIT_WORDS if w in chronicle]
    print(f"--- 성향 이름이 샜나: {'  '.join(leaked) if leaked else '(없다)'} ---\n")

    # ---- ② 착장 -----------------------------------------------------------
    # **열전만으로는 부족한 둘을 코드가 얹는다.** 성별은 레코드 값이고(§27.19.1)
    # 계열은 착장의 뼈대다 — 열전이 그 둘을 안 적을 수도 있는데, 코드가 아는 것을
    # 모델이 열전에서 다시 읽어 내게 하지 않는다 (§27.18).
    look_input = f"성별: {gender}\n나이: {age}세\n계열: {discipline}\n\n[열전]\n{chronicle}"
    look = call(SYSTEM_LOOK, look_input)
    hits = prompts.suspects_in(look)
    print("--- ② 착장 (검사 전) ---")
    print(look + "\n")
    print(f"--- 함정 검사: 용의자 {len(hits)}개 ---")
    for h in hits:
        print(f"  [x] {h}")
    if not hits:
        print("  (없다)")
    print()

    # ---- ③ 성향 맞추기 — **합격 기준이다** --------------------------------
    truth = truth_of(brief)
    guess_raw = ""
    hit = total = 0
    guess: dict[str, str] = {}
    if not args.skip_guess:
        guess_raw = call(SYSTEM_GUESS, chronicle)
        guess = guessed_of(guess_raw)
        hit, total, lines = score(truth, guess)
        print(f"--- ③ 열전만 읽고 성향 맞추기 — {hit}/{total} ---")
        for line in lines:
            print(line)
        print("  (맞으면 원인이 서 있는 것이고, 못 맞으면 열전이 아직 수치의 번역이다)\n")

    final = compose(look, age)
    final_hits = prompts.suspects_in(final)

    for name, body in (("chronicle", chronicle), ("look_raw", look),
                       ("prompt", final), ("guess", guess_raw)):
        with open(os.path.join(out_dir, f"{stem}_{name}.txt"), "w", encoding="utf-8") as f:
            f.write(body + "\n")

    with open(os.path.join(out_dir, "llm_log.jsonl"), "a", encoding="utf-8") as f:
        f.write(json.dumps({
            "person": stem, "model": MODEL, "brief": brief,
            "age": age, "gender": gender, "discipline": discipline,
            "system_chronicle": SYSTEM_CHRONICLE, "system_look": SYSTEM_LOOK,
            "chronicle": chronicle, "trait_words_leaked": leaked,
            "look": look, "look_suspects": hits,
            "guess_raw": guess_raw, "truth": truth, "guess": guess,
            "guess_hit": hit, "guess_total": total,
            "final_prompt": final, "final_suspects": final_hits,
            "utc": datetime.now(timezone.utc).isoformat(),
        }, ensure_ascii=False) + "\n")

    print(f"--- 최종 프롬프트 (코드 고정 + GPT 착장) · 용의자 {len(final_hits)}개 ---")
    print(final + "\n")
    print(f"  파일: {out_dir}")
    # **걸려도 파일은 남긴다.** 사람이 보고 고쳐야 하므로 (§27.9.1 ③).
    return 1 if hits or leaked else 0


if __name__ == "__main__":
    raise SystemExit(main())
