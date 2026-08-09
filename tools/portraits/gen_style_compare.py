#!/usr/bin/env python
"""화풍 셋을 한 사람으로 나란히 뽑는다. **글로 물으면 못 고른다. 봐야 고른다.**

    python tools/portraits/gen_style_compare.py .captures/portraits/cast5 3

`docs/design/27-portraits.md` §27.22.3 이 남긴 물음이다 —
**초상은 타이틀 키아트, 전신과 SD 는 수채라 같은 사람이 두 화풍으로 존재한다.**

| 갈래 | 무엇 |
| --- | --- |
| **ⓐ** | 흉상 + 타이틀 키아트 (지금 초상) |
| **ⓑ** | 흉상 + 수채 (초상을 전신 쪽에 맞춘다) |
| **ⓒ** | 전신 + 타이틀 키아트 (전신을 초상 쪽에 맞춘다) |

**같은 인물, 같은 착장, 화풍만 바꾼다.** 착장이 바뀌면 무엇 때문에 달라 보이는지
알 수 없게 된다 — §21.13.12 의 규율이다(바뀐 것이 문장 하나임을 남긴다).
그래서 셋 다 같은 `_look_raw.txt` 를 쓰고 **시드도 같이 간다.**

구도가 다른 ⓐⓑ 와 ⓒ 는 규격이 다르므로 시드가 같아도 같은 그림이 아니다.
그래도 고정하는 이유는 **다시 뽑았을 때 같은 것이 나오게** 하기 위해서다.
"""

from __future__ import annotations

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import comfy  # noqa: E402
import console  # noqa: E402
import illust  # noqa: E402
import prompts  # noqa: E402
from gen_character import compose  # noqa: E402
from gen_person import seed_of  # noqa: E402

console.utf8()


def bust_watercolour(look: str, age: int) -> str:
    """ⓑ — 흉상 그대로에 **화풍과 배경만** 수채로 바꾼다.

    `FRAME`, `GEOMETRY`, `WEATHER` 는 그대로 둔다. 그것들은 화풍이 아니라 구도이고,
    바꾸면 무엇 때문에 달라 보이는지 알 수 없게 된다.
    """
    return " ".join(p.strip() for p in [
        illust.ILLUST_STYLE,
        prompts.FRAME,
        look,
        prompts.weather(age),
        prompts.GEOMETRY,
        illust.ILLUST_BACKGROUND,
    ] if p.strip())


def full_keyart(look: str) -> str:
    """ⓒ — 전신 그대로에 **화풍과 배경만** 타이틀 키아트로 바꾼다."""
    return " ".join(p.strip() for p in [
        prompts.STYLE + ".",
        illust.ILLUST_FRAME,
        look,
        prompts.BACKGROUND,
        prompts.SHADY + ".",
    ] if p.strip())


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("folder")
    ap.add_argument("person", help="인물 번호 (예: 3)")
    ap.add_argument("--steps", type=int, default=24)
    args = ap.parse_args()

    stem = args.person
    look_path = os.path.join(args.folder, f"{stem}_look_raw.txt")
    with open(look_path, encoding="utf-8") as f:
        look = f.read().strip()
    with open(os.path.join(args.folder, f"brief_{stem}.txt"), encoding="utf-8") as f:
        brief = f.read()
    age = int([ln.split(":")[1].strip().rstrip("세")
               for ln in brief.splitlines() if ln.startswith("- 나이:")][0])

    seed = seed_of(int(stem), 0, 0)
    plans = [
        ("a_bust_keyart", compose(look, age), prompts.SIZE, prompts.SIZE, args.steps),
        ("b_bust_water", bust_watercolour(look, age), prompts.SIZE, prompts.SIZE, args.steps),
        ("c_full_keyart", full_keyart(look), illust.ILLUST_W, illust.ILLUST_H, 12),
    ]

    print(f"=== 화풍 비교 — 인물 {stem}, {age}세, 시드 {seed} ===")
    for tag, prompt, w, h, steps in plans:
        hits = prompts.suspects_in(prompt)
        if hits:
            print(f"  {tag:<16} [x] 용의자 {len(hits)}개 — {hits[:3]}")
            continue
        dest = os.path.join(args.folder, f"{stem}_style_{tag}.png")
        try:
            spent = comfy.run(dest, prompt, w, h, seed, steps=steps)
        except Exception as exc:
            print(f"  {tag:<16} [x] {exc}")
            continue
        print(f"  {tag:<16} {spent:5.1f}s  {w}x{h} {steps}스텝  {len(prompt)}자")

    print(f"\n  결과: {args.folder}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
