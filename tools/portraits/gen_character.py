#!/usr/bin/env python
"""브리프 하나를 GPT 에 넣어 **설정 시트**와 **겉모습 서술**을 받는다.

    python tools/portraits/gen_character.py .captures/portraits/cast/brief_13.txt

`docs/design/27-portraits.md` §27.3 의 파이프라인 두 번째 칸이다.

    dump_person_briefs.gd --> [이 도구] --> 함정 검사 --> Klein 4B Pro

# 무엇을 GPT 에게 맡기고 무엇을 안 맡기나 (§27.9.1)

| 코드가 고정한다 | GPT 가 쓴다 |
| --- | --- |
| 화풍 (`STYLE` · `SHADY`) | 그 인물의 얼굴 · 나이 · 표정 |
| **구도와 사분의 삼** (`FRAME` · `GEOMETRY`) | 그 인물의 옷과 장비 |
| 조명 · 배경 (`LIGHT` · `BACKGROUND`) | 흉터 · 머리 · 눈 |

**GPT 에게 화풍과 구도를 맡기면 인물마다 화풍이 달라진다.** 그리고 초상 프롬프트를
쓰라고 하면 거의 반드시 정면을 쓴다 — 초상의 관용구이기 때문이다. 그래서
**`GEOMETRY` 는 GPT 산출과 무관하게 코드가 뒤에 붙인다.** 문장 하나를 맡기지 않는다.

# 산출을 그대로 믿지 않는다

`prompts.suspects_in()` 을 걸어 부정문 · 비유 · 정면 지시 · 램프 명사를 잡는다.
걸리면 **화면에 찍고 파일에 남긴다.** 사람이 보고 고칠 수 있어야 하므로 조용히
지우지 않는다 — 무엇이 걸렸는지가 다음 판의 시스템 프롬프트를 고치는 근거다.
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
#: 렉카가 쓴 값과 같다 (§19.B.7).
MAX_TOKENS = 1600

#: **렉카의 시스템 프롬프트보다 길다.** §19.A 가 *"짧다는 것이 이 프롬프트의 미덕이다.
#: 줄을 더할 때마다 나빠진다"* 고 했는데 여기는 줄이 많다.
#:
#: 이유는 렉카와 맡긴 일이 다르기 때문이다 — 렉카는 **말투**를 시켰고 여기는
#: **금지 규격**을 시킨다. 말투는 예시로 잡히지만 금지는 적어야 한다.
#: **그래도 이것이 첫 번째 용의자다.** 산출이 나빠지면 여기부터 줄여라.
SYSTEM = """너는 던전 익스트랙션 게임의 인물 설정을 쓴다.

세계: 다른 차원의 존재들이 유희로 게이트를 연다. 인간은 거기서 건져 올 것이 있어
제 발로 들어간다. 가장 큰 위협은 몬스터가 아니라 같은 목적으로 들어온 다른 탐험대다.
협상하고 배신하며 살아 나온다. 양쪽 다 자발적이라 피해자가 없다.

받은 수치가 진실이다. 수치에 맞는 사람을 써라. 수치와 어긋나는 것을 지어내지 마라.
「아직 없음」이라고 적힌 칸은 그대로 둬라. 채우지 마라.

둘을 낸다. 각각 아래 머리말을 그대로 달아라.

## 설정 시트
한국어. 대여섯 줄. 그 사람이 누구인지 쓴다.
성향 여섯 축을 전부 재료로 써도 된다. 수치를 나열하지 말고 사람으로 써라.

## 겉모습
영어 한 문단. 이미지 생성 모델에 그대로 들어간다. 아래를 지켜라.

- 그 사람의 얼굴, 나이, 체격, 머리, 표정, 옷, 장비만 써라.
- **가슴 위만 그린다.** 화면에 어깨와 머리밖에 없다.
  허리, 손, 무릎, 발, 허리에 찬 것, 등에 멘 것은 화면 밖이니 쓰지 마라.
  숨겨져 있다고 적은 것도 쓰지 마라 — 안 보이는 것은 그릴 수 없다.
- 화풍, 카메라, 각도, 구도, 조명, 배경, 피부의 닳음은 쓰지 마라. 그건 코드가 따로 붙인다.
- 성향 중 얼굴에 그려도 되는 것은 「무모/신중」과 「과시/은둔」 둘뿐이다.
  「선/악」, 「의리/실리」, 「위계/자유」, 「정직/기만」은 얼굴에 그리지 마라.
  그 넷은 설정 시트에만 쓴다.
- 부정문을 쓰지 마라. no, not, without, nothing 을 쓰지 마라.
  있어야 할 것만 써라. "not cruel" 이라고 쓰면 잔인한 그림이 나온다.
- 비유를 쓰지 마라. like a, as if, as though 를 쓰지 마라.
  "eyes like a hawk" 는 매를 그린다.
- 정면을 시키지 마라. facing the camera, toward us, looking at the viewer 를 쓰지 마라.
- 등불, 횃불, 촛불, 램프 같은 광원을 쓰지 마라.

이름은 홑화살괄호 안에 있다. 괄호는 입력 표시이니 산출에 쓰지 마라."""


def call(brief: str) -> str:
    payload = {
        "model": MODEL,
        "max_completion_tokens": MAX_TOKENS,
        "messages": [
            {"role": "system", "content": SYSTEM},
            {"role": "user", "content": brief},
        ],
    }
    req = urllib.request.Request(
        ENDPOINT, data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json",
                 "Authorization": "Bearer " + os.environ["OPENAI_API_KEY"]})
    with urllib.request.urlopen(req, timeout=300) as r:
        return json.load(r)["choices"][0]["message"]["content"]


def split(text: str) -> tuple[str, str]:
    """산출을 시트와 겉모습으로 가른다.

    머리말을 못 찾으면 **조용히 반쪽을 내지 않고 터뜨린다** — 반쪽짜리 프롬프트로
    그림을 뽑으면 왜 이상한지 알 수 없게 된다.
    """
    parts = re.split(r"^#+\s*(설정 시트|겉모습)\s*$", text, flags=re.MULTILINE)
    found = {}
    for i in range(1, len(parts) - 1, 2):
        found[parts[i].strip()] = parts[i + 1].strip()
    if "설정 시트" not in found or "겉모습" not in found:
        raise RuntimeError("머리말을 못 찾았다. 받은 것:\n" + text[:800])
    return found["설정 시트"], found["겉모습"]


def compose(look: str) -> str:
    """GPT 가 쓴 겉모습을 코드의 고정 문장 사이에 끼운다 (§27.9.1).

    순서는 `prompts.compose()` 와 같다 — **`FRAME` 이 인물보다 먼저다.**
    모델이 구도를 정하기 전에 흉상이라는 것을 알아야 한다.
    """
    return " ".join(p.strip() for p in [
        prompts.STYLE + ".",
        prompts.FRAME,
        look,
        # **`WEATHER` 는 코드가 붙인다. 1차 실호출이 여기서도 졌다** (§27.15.4).
        #
        # 얼굴을 GPT 에게 맡겼더니 *"a sharp angular face"* 라고만 쓰고 닳음을 안 썼다.
        # 나온 얼굴이 어리고 말끔했다 — §27.15.1 ② 에서 고쳤던 결함이 그대로 재발했다.
        #
        # **닳음은 인물의 개성이 아니라 이 세계의 성질이다.** 이 게임의 인간은 전부
        # 땅속에서 일해 닳아 있다(§27.6.1). 그러니 인물마다 달라질 것이 아니라
        # 화풍처럼 고정돼야 한다 — §27.9.1 의 「코드가 고정한다」 칸으로 옮긴다.
        prompts.WEATHER,
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
    args = ap.parse_args()

    with open(args.brief, encoding="utf-8") as f:
        # 고도 배너가 섞여 들어오므로 「인물」부터 자른다.
        raw = f.read()
    brief = raw[raw.index("인물"):] if "인물" in raw else raw

    stem = os.path.splitext(os.path.basename(args.brief))[0].replace("brief_", "")
    out_dir = args.out or os.path.dirname(os.path.abspath(args.brief))
    os.makedirs(out_dir, exist_ok=True)

    print(f"=== {MODEL} 호출 — 인물 {stem} ===\n")
    text = call(brief)
    sheet, look = split(text)

    # ---- 함정 검사. **걸린 것을 숨기지 않는다** ----------------------------
    hits = prompts.suspects_in(look)
    print("--- GPT 가 쓴 겉모습 (검사 전) ---")
    print(look + "\n")
    print(f"--- 함정 검사: 용의자 {len(hits)}개 ---")
    for h in hits:
        print(f"  [x] {h}")
    if not hits:
        print("  (없다)")
    print()

    final = compose(look)
    final_hits = prompts.suspects_in(final)

    for name, body in (("sheet", sheet), ("look_raw", look), ("prompt", final)):
        with open(os.path.join(out_dir, f"{stem}_{name}.txt"), "w", encoding="utf-8") as f:
            f.write(body + "\n")

    with open(os.path.join(out_dir, "llm_log.jsonl"), "a", encoding="utf-8") as f:
        f.write(json.dumps({
            "person": stem, "model": MODEL, "brief": brief,
            "system": SYSTEM, "raw": text, "sheet": sheet, "look": look,
            "look_suspects": hits, "final_prompt": final,
            "final_suspects": final_hits,
            "utc": datetime.now(timezone.utc).isoformat(),
        }, ensure_ascii=False) + "\n")

    print("--- 설정 시트 ---")
    print(sheet + "\n")
    print(f"--- 최종 프롬프트 (코드 고정 문장 + GPT 겉모습) · 용의자 {len(final_hits)}개 ---")
    print(final + "\n")
    print(f"  파일: {out_dir}")
    # **걸려도 1 을 돌려주되 파일은 남긴다.** 사람이 보고 고쳐야 하므로.
    return 1 if hits else 0


if __name__ == "__main__":
    raise SystemExit(main())
