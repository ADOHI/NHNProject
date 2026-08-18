#!/usr/bin/env python
"""**전신 → 배경 제거 → SD 변환**, 셋을 이어서 돌린다 (§27.31).

    python tools/portraits/gen_chain.py .captures/portraits/cast6 2b 3 --only p_oil,p_gouache

# 왜 셋을 이어서 돌려야 하나

**이것이 「이 화풍으로 갈 수 있나」의 진짜 관문이다.** 전신 한 장이 예쁜 것은
답이 아니다 — 배경을 열었으니 (§27.28) **입력의 성격이 바뀌었고**, SD 변환이
그 입력에서도 서는지는 안 재 봤다.

앞 판이 확인한 경계가 *"출력 구도가 입력과 같은 범주면 성공"* 이었는데,
**그때 입력은 전부 흰 배경이었다.**

# 모델을 번갈아 올린다 — **인스턴스가 하나다**

zitani(전신)와 Klein(SD)을 16GB 에 같이 올리면 경합한다. 그래서 **단계마다 갈고
사이에 `comfy.free()`** 를 부른다. 이 도구는 zitani 를 안 쓴다 —
전신은 `gen_style_compare.py` 가 이미 뽑아 뒀고 **여기서는 SD 만 올린다.**

# 배경 제거가 관문 노릇을 한다

`cutout.py` 가 남은 배경을 재고, **안 떨어지면 SD 에 안 넘긴다.**
못 떼는 배경을 넘기면 Klein 이 그 배경까지 치비로 다시 그린다 —
**뒤 단계에서 터지느니 여기서 세운다.**
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import comfy  # noqa: E402
import console  # noqa: E402
import cutout  # noqa: E402
import illust  # noqa: E402
from gen_person import seed_of  # noqa: E402

console.utf8()

#: 전신과 SD 가 같은 시드를 안 갖게 띄운다 (`gen_batch.py` 와 같은 값).
SD_SEED_OFFSET = 555_557


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("folder")
    ap.add_argument("people", nargs="+")
    ap.add_argument("--only", default="", help="후보를 쉼표로")
    ap.add_argument("--frame", default="open", choices=list(illust.FRAMES),
                    help="어느 규격으로 뽑은 전신을 쓸 것인가. 파일 이름의 접미사가 된다")
    ap.add_argument("--tol", type=int, default=cutout.DEFAULT_TOL)
    ap.add_argument("--force", action="store_true",
                    help="배경이 안 떨어져도 SD 에 넘긴다. **무엇이 나오는지 보려는 자리다**")
    args = ap.parse_args()

    tags = [t.strip() for t in args.only.split(",") if t.strip()] or list(illust.STYLE_CANDIDATES)
    suffix = "" if args.frame == "closed" else f"_{args.frame}"
    log = os.path.join(args.folder, "chain.jsonl")

    print(f"=== 사슬 — 규격 `{args.frame}`, 후보 {len(tags)}, 인물 {len(args.people)} ===")
    plan: list[tuple[str, str, str]] = []   # (tag, stem, cut 경로)

    # ── ① 배경 제거. **관문이다** ───────────────────────────────────────────
    print("\n  ① 배경 제거 (남은 배경% / 인물 넓이%)")
    for tag in tags:
        for stem in args.people:
            src = os.path.join(args.folder, f"{stem}_style_{tag}{suffix}.png")
            if not os.path.exists(src):
                continue
            dest = os.path.join(args.folder, "cut", f"{stem}_{tag}{suffix}_cut.png")
            try:
                dest, left, area = cutout.cut(src, dest, tol=args.tol)
            except Exception as exc:
                print(f"    {tag:<12} #{stem}  [x] {exc}")
                continue
            mark = cutout.verdict(left)
            print(f"    {tag:<12} #{stem}  {left:6.2f}% / {area:5.1f}%  {mark}")
            if left >= cutout.LEFTOVER_BREAK and not args.force:
                continue
            plan.append((tag, stem, dest))

    if not plan:
        print("\n  [x] SD 에 넘길 것이 없다 — 전부 배경이 안 떨어졌다\n")
        return 1

    # ── ② SD 변환. **여기서 Klein 을 올린다** ───────────────────────────────
    print(f"\n  ② SD 변환 — Klein 4B Pro edit {illust.KLEIN_EDIT_STEPS}스텝, "
          f"{illust.SD_SIZE}² ({len(plan)}장)")
    comfy.free()   # zitani 를 내리고 자리를 비운다
    done = 0
    for tag, stem, cut_path in plan:
        name = comfy.upload(cut_path)
        seed = seed_of(int("".join(c for c in stem if c.isdigit()) or 0), 0, 0) + SD_SEED_OFFSET
        dest = os.path.join(args.folder, f"{stem}_sd_{tag}{suffix}.png")
        try:
            spent = comfy.submit(
                illust.klein_edit_graph(illust.SD_CONVERT, name, seed,
                                        prefix=f"sd/{stem}_{tag}"), dest)
        except Exception as exc:
            print(f"    {tag:<12} #{stem}  [x] {exc}", flush=True)
            continue
        done += 1
        print(f"    {tag:<12} #{stem}  {spent:5.1f}s  시드 {seed}", flush=True)
        with open(log, "a", encoding="utf-8") as f:
            f.write(json.dumps({
                "file": os.path.basename(dest), "person": stem, "style": tag,
                "frame": args.frame, "source": os.path.basename(cut_path),
                "tol": args.tol, "seed": seed, "model": illust.KLEIN_UNET,
                "prompt": illust.SD_CONVERT, "elapsed_s": round(spent, 1),
                "utc": datetime.now(timezone.utc).isoformat(),
            }, ensure_ascii=False) + "\n")

    comfy.free()
    print(f"\n  SD {done}장\n  결과: {args.folder}\n  로그: {log}\n")
    return 0 if done else 1


if __name__ == "__main__":
    raise SystemExit(main())
