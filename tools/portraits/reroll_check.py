#!/usr/bin/env python
"""판정 하나가 **시드 하나에서 나온 것인지** 재확인한다 (`docs/design/27-portraits.md`
§27.33, 통합자 지시: *"실패를 보면 고치기 전에 재현되는지 먼저 확인해라."*).

    python tools/portraits/reroll_check.py cast6 2b m_lino,p_water --rerolls 2

# 왜 이 도구가 있나 — **§27.30 이 한 번 여기서 틀렸다**

방 시각화 레인이 소품 판에서 겪은 것과 같다 — 배경을 「그림」으로 칠하고 나온 판을
시드만 바꿔 다시 뽑으니 멀쩡했다. **확률이었다.** `m_lino`·`p_water` 를 §27.30.2 가
「탈락」으로 적었는데, 그 판정은 인물 하나·시드 하나였다. 재보니 3시드 중 1개만
나빴다 — **탈락 사유가 아니라 재굴림으로 피하는 것.**

**결론이 실측 하나에서 나올 때마다 이 도구를 돌려라.** 특히 배경 오염(`cutout.py`)
처럼 씬 구성 자체가 확률적인 자리 — 같은 프롬프트라도 모델이 「배경에 무엇을
그릴지」를 매번 다시 굴린다.

# 하는 일 — **프롬프트는 고정, 시드만 흔든다**

인물 슬롯(`{stem}_slot.txt`)과 화풍은 그대로 두고 `gen_person.seed_of` 의
재굴림 칸만 올려 다시 뽑는다. 뽑은 뒤 `cutout.py` 로 배경을 떼고
`measure.background_dirt` 로 남은 배경을 잰다 — §27.30.1 과 같은 자다.
"""

from __future__ import annotations

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import comfy  # noqa: E402
import console  # noqa: E402
import cutout  # noqa: E402
import illust  # noqa: E402
import measure  # noqa: E402
from gen_person import seed_of  # noqa: E402

console.utf8()

CAST_ROOT = os.path.normpath(os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..", ".captures", "portraits"))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cast", help="예: cast6")
    ap.add_argument("person", help="`{person}_slot.txt` 를 읽는다 (예: 2b)")
    ap.add_argument("styles", help="쉼표로 구분한 후보 목록 (예: m_lino,p_water)")
    ap.add_argument("--rerolls", type=int, default=2, help="원 시드 말고 몇 번 더 뽑나")
    ap.add_argument("--tol", type=int, default=cutout.DEFAULT_TOL)
    args = ap.parse_args()

    folder = os.path.join(CAST_ROOT, args.cast)
    with open(os.path.join(folder, f"{args.person}_slot.txt"), encoding="utf-8") as f:
        slot = f.read().strip()
    hits = __import__("prompts").slot_suspects_in(slot)
    if hits:
        print(f"[x] {args.person} 의 슬롯에 용의자 {len(hits)}개 — 그대로는 못 쓴다", file=sys.stderr)
        return 2

    styles = [s.strip() for s in args.styles.split(",") if s.strip()]
    out = os.path.join(folder, "reroll_test")
    os.makedirs(out, exist_ok=True)
    frame_open = illust.frame_of("open")

    running, pending = comfy.queue_depth()
    print(f"큐 상태: 도는 중 {running}, 대기 {pending}")
    person_digits = int("".join(c for c in args.person if c.isdigit()) or 0)

    results = []
    for style in styles:
        _axis, style_text = illust.STYLE_CANDIDATES[style]
        prompt = illust.compose_illust(slot, style_text, anchor="anime", frame=frame_open)
        for rr in range(1, args.rerolls + 1):
            seed = seed_of(person_digits, 0, rr)
            dest = os.path.join(out, f"{args.person}_{style}_open_r{rr}.png")
            spent = comfy.submit(
                illust.zitani_graph(prompt, seed, illust.ILLUST_W, illust.ILLUST_H,
                                    steps=illust.ZITANI_STEPS,
                                    prefix=f"reroll/{args.person}_{style}_r{rr}"),
                dest)
            cut_dest = os.path.join(out, f"{args.person}_{style}_open_r{rr}_cut.png")
            _, left, area = cutout.cut(dest, cut_dest, tol=args.tol, flatten="white")
            print(f"  {style:<12} r{rr}  seed={seed}  {spent:5.1f}s  "
                  f"남은배경={left:5.2f}%  인물넓이={area:5.1f}%")
            results.append({"style": style, "reroll": rr, "seed": seed,
                            "left_pct": round(left, 2), "area_pct": round(area, 1),
                            "elapsed_s": round(spent, 1)})

    comfy.free()
    with open(os.path.join(out, "reroll_results.jsonl"), "a", encoding="utf-8") as f:
        for r in results:
            f.write(json.dumps({**r, "person": args.person}, ensure_ascii=False) + "\n")

    print(f"\n판정: 재굴림에서도 계속 나쁘면(대부분 시드에서 안 떨어지면) 진짜 탈락이다.")
    print(f"      1~2 개만 나쁘면 확률이다 — 재굴림으로 피한다 (§27.33).")
    print(f"결과: {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
