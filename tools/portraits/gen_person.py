#!/usr/bin/env python
"""인물 하나의 초상을 뽑는다 — 로컬 ComfyUI :8000, Klein 4B Pro.

    python tools/portraits/gen_person.py .captures/portraits/cast2/324_prompt.txt --plates 2

`gen_portraits.py` 는 **격자**를 돈다 (계열 × 인상). 격자는 폐기됐고(§27.2)
지금 파이프라인은 **인물 단위**라 뽑을 것이 격자 칸이 아니라 `gen_character.py` 가
낸 프롬프트 파일 하나다. 그래서 도구를 나눈다 — 같은 `comfy.run` 을 쓰고
같은 로그 형식으로 적는다.

# 시드는 인물 번호에서 나온다 (§27.13)

    seed = BASE + 인물번호 × 1_000_003 + 판번호 × 101

**같은 인물의 같은 판 번호는 같은 그림이다.** 프롬프트를 고치면 그림이 바뀌는데
시드가 같으므로 **바뀐 것이 문장뿐임이 로그로 증명된다** (§21.13.12 의 규율).

# 판마다 프롬프트 전문을 적는다

시드만 적으면 프롬프트를 고친 뒤에 재현이 안 된다.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import comfy  # noqa: E402
import console  # noqa: E402
import prompts  # noqa: E402

console.utf8()

#: `grid.py` 와 같은 기준값이라 인물 초상이 격자 판과 시드를 나눠 갖지 않는다.
BASE_SEED = 20260808

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
LOG = os.path.join(ROOT, ".captures", "portraits", "log.jsonl")


def seed_of(person: int, plate: int, reroll: int) -> int:
    """전부 소수 배수라 다른 인물, 다른 판이 같은 시드를 갖지 않는다 (§27.13)."""
    return BASE_SEED + person * 1_000_003 + plate * 101 + reroll * 7_919


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("prompt_file", help="gen_character.py 가 낸 <인물>_prompt.txt")
    ap.add_argument("--plates", type=int, default=2, help="몇 장 뽑나. **한 번에 몇 장만** — GPU 는 하나다")
    ap.add_argument("--reroll", type=int, default=0,
                    help="시드만 바꿔 다시 굴린다. **번호가 파일 이름에 남는다** (§27.12)")
    ap.add_argument("--steps", type=int, default=24, help="타이틀 레인과 같은 값이 기본")
    ap.add_argument("--out", default="", help="기본: 프롬프트와 같은 폴더")
    args = ap.parse_args()

    with open(args.prompt_file, encoding="utf-8") as f:
        prompt = f.read().strip()

    stem = os.path.basename(args.prompt_file).replace("_prompt.txt", "")
    person = int(re.sub(r"\D", "", stem) or 0)
    out_dir = args.out or os.path.dirname(os.path.abspath(args.prompt_file))
    os.makedirs(out_dir, exist_ok=True)

    # **넣기 전에 다시 검사한다.** 사람이 파일을 손으로 고쳤을 수 있다 (§27.9.1 ②).
    hits = prompts.suspects_in(prompt)
    print(f"=== 초상 — 인물 {stem}, {args.plates}장, {args.steps} 스텝 ===")
    print(f"  함정 검사: 용의자 {len(hits)}개")
    for h in hits:
        print(f"    [x] {h}")
    if hits:
        print("  [x] 걸린 것이 있다. **Klein 에 넣지 않는다** — 낱말을 지우고 다시 와라",
              file=sys.stderr)
        return 2

    running, pending = comfy.queue_depth()
    if running or pending:
        print(f"  [!] 시작 전인데 큐가 비어 있지 않다 — 돌는 중 {running}, 대기 {pending}")

    done = 0
    for plate in range(args.plates):
        tag = f"v{plate + 1}" if not args.reroll else f"v{plate + 1}r{args.reroll}"
        name = f"{stem}_{tag}.png"
        dest = os.path.join(out_dir, name)
        seed = seed_of(person, plate, args.reroll)
        started = time.time()
        try:
            elapsed = comfy.run(dest, prompt, prompts.SIZE, prompts.SIZE, seed, steps=args.steps)
        except Exception as exc:  # 판 하나가 실패해도 나머지를 세우지 않는다
            print(f"  {name:<24} [x] {exc}")
            continue
        done += 1
        print(f"  {name:<24} {elapsed:5.1f}s   시드 {seed}")
        os.makedirs(os.path.dirname(LOG), exist_ok=True)
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(json.dumps({
                "file": name, "person": person, "plate": plate, "reroll": args.reroll,
                "seed": seed, "steps": args.steps, "w": prompts.SIZE, "h": prompts.SIZE,
                "model": comfy.UNET, "prompt": prompt,
                "elapsed_s": round(elapsed, 1),
                "utc": datetime.now(timezone.utc).isoformat(),
            }, ensure_ascii=False) + "\n")
        del started

    print(f"\n  뽑은 판 {done}장\n  결과: {out_dir}\n  로그: {LOG}\n")
    return 0 if done else 1


if __name__ == "__main__":
    raise SystemExit(main())
