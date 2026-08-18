"""브리프 하나에서 **열전**과 **③ 외형 칸**을 받는다 — GPT 대신 하위 에이전트로.

`docs/design/27-portraits.md` §27.26 (통합자 지시) · §27.27 (관문) 다음 자리.
**이 파일은 혼자 못 돈다.** `Agent` 도구(Claude Code)는 파이썬에서 못 부른다 —
이 모듈은 **부를 문장을 짓고 돌아온 문자열을 검사·저장하는 자리**이고,
실제 호출은 오케스트레이터(지금 이 레인을 도는 Claude)가 한다.

    prompt = agent_character.chronicle_prompt(brief)
    # → Agent 도구 호출 (model="sonnet", run_in_background=False), 문자열을 받는다
    chronicle = "..."  # 받은 문자열
    hits = agent_character.check_chronicle(chronicle)   # 성향 이름이 샜나

    prompt2 = agent_character.slot_prompt(chronicle, gender, age, discipline, work)
    # → Agent 도구 호출
    slot = "..."
    hits2 = agent_character.check_slot(slot)            # prompts.slot_suspects_in

    agent_character.save(out_dir, stem, chronicle=chronicle, slot=slot, ...)

# 왜 GPT 시스템 프롬프트를 그대로 안 베꼈나

**딱 하나 다르다** — 하위 에이전트는 저장소를 **직접 읽을 수 있다.** GPT 는
붙여 넣은 것만 본다. §27.26.1 이 그 이득을 실측했다 — 브리프에 §27.5 를
안 적었는데도 하위 에이전트가 스스로 *"악↔선은 §27.5 가 외형에 얹는 것을
금지했다"* 를 찾아 지켰다. 그래서 두 파일을 **직접 읽으라고 지시한다**
(사용자 지시) — `docs/design/24-npc-relations.md` (이 세계의 관계·이름·나이 관례),
`src/core/npc/person_seed.gd` (인물이 결정론적으로 태어나는 규칙).

**나머지 규칙(축 사용법, 부정문 금지, 도구 금지 …)은 그대로 옮겼다.** 이것들은
「찾아 읽으면 나오는 세계관」이 아니라 **이 파이프라인 고유의 형식 규칙**이라
문서 어디를 읽어도 안 나온다 — 명시하지 않으면 못 지킨다.

# 관문은 그대로 걸어야 한다 (사용자 지시) — **모델이 세는 것을 믿지 마라**

§27.26.2 의 실증 — 같은 산출물이 §27.5 는 스스로 지켰는데 **명시로 금지한 `soot`
는 어겼다.** §27.27.1 의 실증 — 하위 에이전트가 `WORDS: 22` 라 자기 신고했는데
실제로 24 였다. **읽는 것은 맡기고 지키는 것은 코드로 문다.** 그래서 `check_slot`
은 `prompts.slot_suspects_in` 을 그대로 부른다 — **낱말 수도 여기서 다시 센다,
모델의 자기 신고를 쓰지 않는다.**

# 하위 에이전트에게 파일을 쓰게 하지 않는다 (사용자 지시)

문자열만 받는다. `save()` 가 **오케스트레이터 쪽에서** 디스크에 적는다 —
인물을 여럿 병렬로 돌리면 하위 에이전트 열다섯이 같은 파일을 동시에 건드릴 수 있다.
"""

from __future__ import annotations

import json
import os
import re
import sys
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import prompts  # noqa: E402

MODEL_TAG = "sonnet-subagent"

#: 세계 설명 — `gen_character.py` 의 `WORLD` 와 같다. 세계 자체는 안 바뀌었다.
WORLD = """세계: 다른 차원의 존재들이 유희로 게이트를 연다. 인간은 거기서 건져 올 것이 있어
제 발로 들어간다. 가장 큰 위협은 몬스터가 아니라 같은 목적으로 들어온 다른 탐험대다.
협상하고 배신하며 살아 나온다. 양쪽 다 자발적이라 피해자가 없다."""

#: **하위 에이전트가 직접 읽을 자리.** 브리프에 없는 질감(이름 관례, 나이·가족
#: 분포, 인물이 어떻게 결정론적으로 태어나는가)은 여기서 얻는다 — GPT 에게처럼
#: 내가 요약해서 떠먹이지 않는다. 그게 §27.26.1 이 실측한 이득이다.
READ_FIRST = """# 먼저 읽어라

너는 이 저장소 안에서 도는 하위 에이전트다 — 파일을 읽을 수 있다. 쓰지는 마라.

- `docs/design/24-npc-relations.md` — 이 세계의 인물 관계 규칙, 이름 관례,
  나이·가족 분포의 실측. 브리프에 없는 질감은 여기서 얻어라.
- `src/core/npc/person_seed.gd` — 인물이 어떻게 결정론적으로 태어나는지
  (계열·성별·성향이 어느 흐름에서 나오는가).

**브리프에 있는 값과 어긋나면 브리프가 이긴다** — 저 문서들은 세계의 질감이고
브리프는 이 사람 하나의 확정된 사실이다."""


def chronicle_prompt(brief: str) -> str:
    """① 열전 부름. **성향은 결과다. 원인을 대야 한다** (§27.19.2).

    `gen_character.py` 의 `SYSTEM_CHRONICLE` 과 규칙은 같다. 다른 것은
    `READ_FIRST` 하나 — GPT 에게는 없던, 저장소를 직접 읽으라는 지시.
    """
    return f"""{WORLD}

{READ_FIRST}

# 너는 이 세계의 인물 열전을 쓴다

인물 상세 화면에 들어가고 사람이 읽는다. **마지막 메시지에 열전 본문만 담아라** —
머리말도 설명도 따옴표도 붙이지 마라. 그게 그대로 파일에 저장된다.

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
- 가족 — 있는 것도 없는 것도 원인이다
- 소속 — 큰 길드인지 작은 데인지 무소속인지
- 계열 — 왜 이 일을 골랐나
- 유명세 — 이름이 알려졌다면 알려진 이유가 있어야 한다

# 어느 축을 쓰고 어느 축을 버리나 — **이걸 틀리면 없는 사람이 된다**

- **「(극)」이라고 적힌 축은 반드시 원인을 대라.** 그 축이 그 사람의 가장 큰 특징이고,
  읽은 사람이 그 축을 못 맞추면 열전이 실패한 것이다.
  **극인 축과 반대로 읽히는 일화를 앞세우지 마라.**
- 「약간」이라고 적힌 축은 약하게만 쓴다. 한 줄을 넘기지 마라.
- **쪽이 안 적힌 축은 이야기에 아예 넣지 마라.** 그 사람은 그 축에서 가운데다.

**받은 것과 어긋나면 안 된다.** 가족이 없다고 적혀 있는데 형 이야기를 쓰면 실패다.
받은 관계에 있는 사람은 이름으로 부르고, 없는 사람은 만들지 마라.
이 세계의 가족 자료에는 부계 혈연과 사제만 있다.
어머니, 아내, 남편, 혼인을 지어내지 마라.

# 문체

한국어. 여덟에서 열두 줄. **과장하지 마라.** 영웅으로 만들지 말고 그냥 살아온
대로 적어라. **지금은 사건 기록이 없으므로 태생부만 쓴다** — 어디서 나서
어떻게 자랐고 어떻게 이 일을 갖게 됐으며 지금 무엇을 하고 있나까지.
최근의 사건은 쓰지 마라.

받은 글의 괄호 안내는 너에게 주는 지시다. 산출에 옮겨 적지 마라.
이름은 홑화살괄호 안에 있다. 괄호는 입력 표시이니 산출에 쓰지 마라.

# 브리프

{brief}"""


def slot_prompt(chronicle: str, gender: str, age: int, discipline: str, work: str) -> str:
    """③ 외형 칸 부름. **명사구 하나, 12~22 낱말** (§27.24.2).

    옷 이름을 안 준다 — `work`(그 일이 몸에 요구하는 것)만 준다.
    카탈로그를 주면 모델이 고르기만 하고 지어내지 않는다(§27.21.4).
    """
    return f"""{WORLD}

# 너는 인물 열전을 읽고 그 사람의 전신 겉모습을 **명사구 하나**로 쓴다

이미지 생성 프롬프트의 한 칸에 그대로 끼워진다. **마지막 메시지에 그 명사구
하나만 담아라** — 머리말, 설명, 따옴표, 마침표를 붙이지 마라.

# 규격 — 어기면 뒤 문장이 흘러 나간다

- **영어 명사구 하나. 12~22 낱말.** 문장으로 쓰지 마라. 마침표를 찍지 마라.
  **낱말 수는 네가 세지 마라 — 코드가 다시 센다. 스스로 못 미더우면 짧게 써라.**
- **사람으로 시작해라** — A woman, A man, A boy, A girl, 또는 직업으로.
- 손과 신발은 비어 있어야 한다. **무기, 도구, 가방을 쓰지 마라** — 손에 따로 붙는다.
- **장소·환경 명사를 쓰지 마라** (tunnel, cave, mine, smoke, dust, soot, ruins …).
  일은 **옷의 생김새**로만 드러낸다 — `tunnel surveyor` 가 아니라
  `a woman in a reinforced heat-resistant coat` 다.
- **화풍, 구도, 카메라, 자세, 배경, 그림자, 조명을 말하지 마라.** 다른 칸이 맡는다.
- 실제 색 이름을 써라. colourful, vibrant 는 그림에 아무것도 안 만든다.
- 부정문(no, not, without)과 비유(like a, as if)를 쓰지 마라.
- **일이 몸에 요구하는 것**이 아래에 적혀 있다. 그것을 만족시키는 옷을 지어내라.
  옷 이름은 안 준다 — **일에서 유추해라.**

# 받은 것

성별: {gender}
나이: {age}세
계열: {discipline}
하는 일: {work}

[열전]
{chronicle}

명사구만 답해라."""


#: 열전에 나오면 안 되는 낱말 — 성향의 이름이다 (§27.19.2). `gen_character.py` 와 같다.
_TRAIT_WORDS = ["무모", "신중", "의리", "실리", "위계", "기만", "과시", "은둔"]


def check_chronicle(text: str) -> list[str]:
    """열전에 성향 이름이 샜나. **관문이 아니라 찍는다** — 「선」・「악」은 흔한 말이라
    관문으로 세우면 거짓 경보가 난다(§27.12)."""
    return [w for w in _TRAIT_WORDS if w in text]


def check_slot(text: str) -> list[str]:
    """③ 외형 칸의 관문. **`prompts.slot_suspects_in` 을 그대로 부른다** — 사용자 지시
    ("관문은 그대로 걸어라"). 낱말 수도 거기서 다시 센다."""
    return prompts.slot_suspects_in(text.strip())


def save(out_dir: str, stem: str, *, brief: str, chronicle: str, chronicle_hits: list[str],
         slot: str, slot_hits: list[str], guess_raw: str = "", truth: dict | None = None,
         guess: dict | None = None, guess_hit: int = 0, guess_total: int = 0) -> None:
    """받은 문자열을 저장한다. **하위 에이전트가 아니라 여기(오케스트레이터)가 쓴다**
    (사용자 지시). `gen_character.py` 와 같은 파일 이름을 쓴다 — 도구를 갈아 끼워도
    `contact_sheet.py` 같은 다음 단계가 안 흔들린다."""
    os.makedirs(out_dir, exist_ok=True)
    for name, body in (("chronicle", chronicle), ("slot", slot), ("guess", guess_raw)):
        with open(os.path.join(out_dir, f"{stem}_{name}.txt"), "w", encoding="utf-8") as f:
            f.write(body.strip() + "\n")
    with open(os.path.join(out_dir, "llm_log.jsonl"), "a", encoding="utf-8") as f:
        f.write(json.dumps({
            "person": stem, "model": MODEL_TAG, "brief": brief,
            "chronicle": chronicle, "trait_words_leaked": chronicle_hits,
            "slot": slot, "slot_words": len(slot.split()), "slot_suspects": slot_hits,
            "guess_raw": guess_raw, "truth": truth or {}, "guess": guess or {},
            "guess_hit": guess_hit, "guess_total": guess_total,
            "utc": datetime.now(timezone.utc).isoformat(),
        }, ensure_ascii=False) + "\n")


# ---------------------------------------------------------------------------
# ③ 성향 맞추기 — 합격 기준 (§27.19.2). `gen_character.py` 의 것을 그대로 쓴다.
# ---------------------------------------------------------------------------

_AXIS_LINE = re.compile(r"^-\s*(\S+?)\s*축:\s*(.+)$", re.MULTILINE)


def guess_prompt(chronicle: str) -> str:
    """열전만 주고 성향을 되묻는다. **수치도 브리프도 안 준다** — 주면 시험이
    무의미해진다. 이 부름은 **반드시 딴 사람(새 컨텍스트)에게** 시켜야 한다 —
    브리프를 이미 본 오케스트레이터가 스스로 맞히면 답을 안다."""
    return """너는 인물 열전을 읽고 그 사람의 성향을 맞춘다.

여섯 축이 있다. 각 축마다 어느 쪽인지 하나만 고른다.
읽어서 판단이 안 서는 축은 「가운데」라고 답한다. 억지로 고르지 마라.

무모/신중, 선/악, 의리/실리, 위계/자유, 정직/기만, 과시/은둔

아래 형식으로 여섯 줄만 낸다. 설명을 붙이지 마라.

무모/신중: <무모 또는 신중 또는 가운데>
선/악: <선 또는 악 또는 가운데>
의리/실리: <의리 또는 실리 또는 가운데>
위계/자유: <위계 또는 자유 또는 가운데>
정직/기만: <정직 또는 기만 또는 가운데>
과시/은둔: <과시 또는 은둔 또는 가운데>

[열전]
""" + chronicle


def truth_of(brief: str) -> dict[str, str]:
    truth: dict[str, str] = {}
    for axis, words in _AXIS_LINE.findall(brief):
        if words.startswith("어느 쪽도"):
            truth[axis] = "가운데"
            continue
        parts = words.replace("약간 ", "").split()
        truth[axis] = parts[0] if parts else "가운데"
    return truth


def guessed_of(text: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in text.splitlines():
        if ":" not in line:
            continue
        axis, _, side = line.partition(":")
        out[axis.strip().lstrip("-").strip()] = (
            side.strip().strip("<>").split()[0] if side.strip() else "")
    return out


def score(truth: dict[str, str], guess: dict[str, str]) -> tuple[int, int, list[str]]:
    lines: list[str] = []
    hit = 0
    for axis, want in truth.items():
        got = guess.get(axis, "(없음)")
        ok = got == want
        hit += int(ok)
        lines.append(f"  {'[o]' if ok else '[x]'} {axis:<8} 레코드 {want:<5} 맞춘 것 {got}")
    return hit, len(truth), lines
