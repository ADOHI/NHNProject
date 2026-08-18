#!/usr/bin/env python
"""초상 생성 — 로컬 ComfyUI :8000, Klein 4B Pro.

    python tools/portraits/gen_portraits.py --stage sian
    python tools/portraits/gen_portraits.py --stage grid          # 승인 뒤
    python tools/portraits/gen_portraits.py --only combat --reroll 1

근거는 전부 `docs/design/27-portraits.md` 다. 규격은 §24.20.4 가 정했다 — **512×512 정사각.**

# 생성 로그를 반드시 남긴다 (§27.13)

판마다 `.captures/portraits/log.jsonl` 에 한 줄이 붙고 **프롬프트 전문이 들어간다.**
시드만 적으면 프롬프트를 고친 뒤에 재현이 안 된다. 100장이라 사람이 못 적으므로 도구가 적는다.

# GPU 는 하나뿐이다

인스턴스를 새로 띄우지 않고 체크포인트도 갈아 끼우지 않는다 —
예전에 둘 띄웠다가 블루스크린이 났다. 시작 전과 **배치 중간에** 큐를 확인해서
다른 레인이 끼어들면 화면에 찍는다 (`--queue-every`).
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import comfy  # noqa: E402
import console  # noqa: E402
import grid  # noqa: E402
from prompts import DISCIPLINES, IMPRESSIONS, SIZE, audit  # noqa: E402

console.utf8()

#: 결과는 워크트리의 `.captures/` 아래다. **`.gitignore` 가 그 폴더를 통째로 뺀다** —
#: 캡처 PNG 는 저장소에 들어가지 않는다.
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, ".captures", "portraits")
LOG = os.path.join(OUT, "log.jsonl")


def _record(entry: dict) -> None:
    os.makedirs(OUT, exist_ok=True)
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")


def generate(cells: list[grid.Cell], steps: int, queue_every: int,
             out_dir: str, skip_existing: bool) -> int:
    os.makedirs(out_dir, exist_ok=True)
    started = time.time()
    done = failed = 0
    for i, cell in enumerate(cells):
        dest = os.path.join(out_dir, cell.name + ".png")
        if skip_existing and os.path.exists(dest):
            print(f"  {i + 1:3d}/{len(cells)}  {cell.name:<28} 이미 있다 — 건너뛴다", flush=True)
            continue

        # **다른 레인이 끼어들었는지 본다.** GPU 는 인스턴스 하나뿐이라
        # 끼어들면 느려지는 것이 아니라 VRAM 이 물린다.
        if queue_every and i and i % queue_every == 0:
            running, pending = comfy.queue_depth()
            if running > 1 or pending:
                print(f"  [!] 큐에 남이 있다 — 돌는 중 {running} · 대기 {pending}."
                      f" 다른 레인이 끼어들었을 수 있다", flush=True)

        try:
            elapsed = comfy.run(dest, cell.prompt, SIZE, SIZE, cell.seed, steps=steps)
        except Exception as exc:  # 판 하나가 실패해도 배치를 세우지 않는다
            failed += 1
            print(f"  {i + 1:3d}/{len(cells)}  {cell.name:<28} [x] {exc}", flush=True)
            _record({"file": cell.name + ".png", "error": str(exc), "seed": cell.seed,
                     "utc": datetime.now(timezone.utc).isoformat()})
            continue

        done += 1
        _record({
            "file": cell.name + ".png",
            "discipline": cell.discipline_name,
            "impression": cell.impression_name,
            "variant": cell.variant,
            "reroll": cell.reroll,
            "seed": cell.seed,
            "steps": steps,
            "w": SIZE, "h": SIZE,
            "model": comfy.UNET,
            "prompt": cell.prompt,
            "elapsed_s": round(elapsed, 1),
            "utc": datetime.now(timezone.utc).isoformat(),
        })
        avg = (time.time() - started) / max(done, 1)
        left = (len(cells) - i - 1) * avg
        print(f"  {i + 1:3d}/{len(cells)}  {cell.name:<28} {elapsed:5.1f}s"
              f"   시드 {cell.seed}   남은 예상 {left / 60:.0f}분", flush=True)

    print(f"\n  뽑은 판 {done}장 · 실패 {failed}장 · {(time.time() - started) / 60:.1f}분")
    print(f"  결과: {out_dir}\n  로그: {LOG}\n")
    return 1 if failed else 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--stage", choices=["sian", "grid"], default="sian",
                    help="sian = 계열 5종 무색 3장 + 인상 4종 (19장) · grid = 격자 전체")
    ap.add_argument("--per", type=int, default=1,
                    help="grid 의 변형 수 배수. 격자를 다시 설계하지 않고 늘린다 (§27.5)")
    ap.add_argument("--only", default="",
                    help="쉼표로 구분한 계열 또는 인상 이름만 (예: combat,vain)")
    ap.add_argument("--reroll", type=int, default=0,
                    help="시드만 바꿔 다시 굴린다. **번호가 파일 이름에 남는다** (§27.12)")
    ap.add_argument("--steps", type=int, default=24, help="타이틀 레인과 같은 값이 기본")
    ap.add_argument("--out", default="", help="결과 폴더 (기본: .captures/portraits/<stage>)")
    ap.add_argument("--queue-every", type=int, default=10,
                    help="몇 장마다 GPU 큐를 확인하나. 0 이면 안 한다")
    ap.add_argument("--redo", action="store_true", help="이미 있는 판도 다시 뽑는다")
    ap.add_argument("--dry-run", action="store_true", help="뽑지 않고 무엇을 뽑을지만 찍는다")
    args = ap.parse_args()

    # **자기 점검을 먼저 돌린다** (§21.13.13). 자기가 쓴 규칙은 자기 프롬프트부터
    # 검사해야 걸린다 — 타이틀 레인이 6차에 와서야 `DEMON_CORE` 의 부정문 넷을 찾았다.
    if audit():
        print("  [x] 프롬프트 점검에 걸렸다. 뽑기 전에 손봐라.", file=sys.stderr)
        return 2

    cells = grid.sian() if args.stage == "sian" else grid.full_grid(args.per)
    if args.reroll:
        cells = [grid.Cell(c.discipline, c.impression, c.variant, args.reroll) for c in cells]
    if args.only:
        want = {w.strip() for w in args.only.split(",") if w.strip()}
        cells = [c for c in cells
                 if c.discipline_name in want or c.impression_name in want]
    if not cells:
        print("  [x] 고른 판이 없다. --only 를 확인해라", file=sys.stderr)
        return 2

    out_dir = args.out or os.path.join(OUT, args.stage)
    print(f"=== 초상 생성 — {args.stage} ===")
    print(f"  {grid.describe(cells)} · {args.steps} 스텝")
    print(f"  계열: {' '.join(d[1] for d in DISCIPLINES)}")
    print(f"  인상: {' '.join(i[1] for i in IMPRESSIONS)}")
    print(f"  나가는 곳: {out_dir}\n")

    if args.dry_run:
        for c in cells:
            print(f"  {c.name:<28} 시드 {c.seed}")
        return 0

    running, pending = comfy.queue_depth()
    if running or pending:
        print(f"  [!] 시작 전인데 큐가 비어 있지 않다 — 돌는 중 {running} · 대기 {pending}",
              flush=True)

    return generate(cells, args.steps, args.queue_every, out_dir, not args.redo)


if __name__ == "__main__":
    raise SystemExit(main())
