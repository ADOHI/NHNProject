#!/usr/bin/env python
"""화풍 후보를 인물 고정으로 나란히 뽑는다. **글로 물으면 못 고른다. 봐야 고른다.**

    python tools/portraits/gen_style_compare.py .captures/portraits/cast6 2 3
    python tools/portraits/gen_style_compare.py .captures/portraits/cast6 2 3 --only hairline,heavy

# 이 도구가 지키는 것 하나 — **변수는 화풍 하나뿐이다**

인물, 착장, 시드, 스텝, 규격이 전부 고정이다. 바뀌는 것은 프롬프트의 **둘째 칸**
문자열 하나다. 그래야 결과 차이를 화풍 탓으로 돌릴 수 있다 (§21.13.12 의 규율 —
*바뀐 것이 문장 하나임을 남긴다*).

시드는 `gen_batch.py` 의 전신 단계와 같은 `seed_of(인물, 0, 0)` 이다.
그래서 `{인물}_illust.png` 와 `{인물}_style_*.png` 가 **같은 난수에서 나온 형제**고,
후보를 다시 뽑아도 같은 그림이 나온다.

# 함정 검사를 **우리가 갈아 끼우는 칸에만** 건다 (§27.24.2)

원본의 고정 문자열(`No ground, no floor, no cast shadow ...`)은 §27.9 의
「부정문 금지」에 걸린다. 그 규칙은 **Klein 흉상 경로**에서 얻은 것이고 저 문자열은
**zitani 전신 경로에서 212건으로 검증된 것**이다.
**남의 검증된 문자열을 내 규칙으로 심판하지 않는다.** 그래서 검사는 `_slot.txt` 에만 건다.

# 모델이 하나만 올라간다

zitani 와 Klein 을 16GB 에 같이 올리면 경합한다. 이 도구는 zitani 만 쓰고,
끝나면 `comfy.free()` 로 내린다 — 다음 사람이 Klein 을 올릴 수 있게.
`/free` 는 **즉시 안 내려간다** (실측: 직후 5.2GB, 잠시 뒤 15.0GB). 기다렸다가
안 오르면 경고만 남기고 넘어간다.
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
import illust  # noqa: E402
import measure  # noqa: E402
import prompts  # noqa: E402
from gen_person import seed_of  # noqa: E402

console.utf8()

#: 내려갈 때까지 이만큼 기다린다. 안 오르면 경고를 남기고 넘어간다 (모듈 머리말).
FREE_WAIT_S = 20.0
FREE_WANT_GB = 10.0


def vram_free_gb() -> float:
    try:
        d = comfy.get("/system_stats")
        return max(dev.get("vram_free", 0) for dev in d.get("devices", [])) / 1e9
    except Exception:
        return -1.0


def unload(tag: str = "") -> None:
    """VRAM 을 내리고 **실제로 내려갔는지 본다.** 곧바로 재고 판단하면 거짓말한다."""
    try:
        comfy.free()
    except Exception as exc:
        print(f"  [!] /free 실패 — {exc}")
        return
    deadline = time.time() + FREE_WAIT_S
    got = vram_free_gb()
    while time.time() < deadline and 0 <= got < FREE_WANT_GB:
        time.sleep(2.0)
        got = vram_free_gb()
    if 0 <= got < FREE_WANT_GB:
        print(f"  [!] {tag} VRAM 이 {got:.1f}GB 밖에 안 비었다 — 다음 모델이 경합할 수 있다")
    else:
        print(f"  VRAM {got:.1f}GB 비었다{(' — ' + tag) if tag else ''}")


def load_slot(folder: str, stem: str) -> str:
    """`gen_character.py` 가 낸 인물 칸(명사구 12~22낱말)을 읽는다."""
    path = os.path.join(folder, f"{stem}_slot.txt")
    with open(path, encoding="utf-8") as f:
        return f.read().strip()


def build_sheet(folder: str, people, tags, suffix: str = "") -> str:
    """후보 × 인물 격자 한 장. **사람이 고르는 것은 눈이라 나란히 놓아야 한다.**"""
    from PIL import Image, ImageDraw

    # 후보가 적으면 칸을 키운다 — **좁혀 놓고 볼 때가 진짜 판정이다**
    cell_w, pad, head = (220 if len(tags) > 8 else 420), 6, 26
    cells = [(t, illust.STYLE_CANDIDATES[t][0]) for t in tags]
    cell_h = int(cell_w * illust.ILLUST_H / illust.ILLUST_W)
    cols, rows = len(cells), len(people)
    sheet = Image.new("RGB", (cols * (cell_w + pad) + pad,
                              rows * (cell_h + pad) + head + pad), "white")
    dr = ImageDraw.Draw(sheet)
    for c, (tag, _axis) in enumerate(cells):
        x = pad + c * (cell_w + pad)
        dr.text((x + 2, 6), tag, fill="black")
        for r, stem in enumerate(people):
            src = os.path.join(folder, f"{stem}_style_{tag}{suffix}.png")
            y = head + pad + r * (cell_h + pad)
            if not os.path.exists(src):
                continue
            sheet.paste(Image.open(src).convert("RGB").resize((cell_w, cell_h)), (x, y))
            dirt, _ = measure.background_dirt(src)
            mark = measure.background_verdict(dirt)
            if mark != "성함":
                dr.rectangle([x, y, x + cell_w - 1, y + cell_h - 1],
                             outline=(220, 0, 0), width=3)
    dest = os.path.join(folder, f"style_sheet{suffix}.png")
    sheet.save(dest)
    return dest


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("folder")
    ap.add_argument("people", nargs="+",
                    help="인물 번호들 (예: 2 3). **고정이어야 비교가 된다**. "
                         "`2b` 처럼 글자를 붙이면 **시드는 2 그대로 두고 슬롯만 갈아 끼운다** "
                         "— ③ 칸을 한 낱말 고쳤을 때 그림이 어떻게 바뀌는지 재는 자리다")
    ap.add_argument("--only", default="",
                    help="후보를 쉼표로 골라 돈다. 기본은 아직 안 뽑은 것 전부")
    ap.add_argument("--redo", action="store_true", help="이미 있는 판도 다시 뽑는다")
    ap.add_argument("--steps", type=int, default=illust.ZITANI_STEPS)
    ap.add_argument("--anchor", default="anime", choices=list(illust.ANCHORS),
                    help="맨 앞 조립. **셋 다 원본에 실물이 있다** — `anime`(기록 19건), "
                         "`drawn`(기록 189건, 다수), `none`(noanchor 실험)")
    ap.add_argument("--open-frame", action="store_true",
                    help="**탐침.** 배경 지시를 뺀 규격으로 뽑는다 (§27.28). "
                         "화풍이 배경에서 드러나는지 재는 자리다 — 파이프라인은 안 바꾼다")
    ap.add_argument("--jitter", type=int, default=0,
                    help="**잡음 바닥을 재는 자리.** 화풍은 그대로 두고 시드만 N 번 흔든다. "
                         "화풍을 바꾼 벌어짐이 이걸 못 넘으면 화풍이 안 갈린 것이다")
    ap.add_argument("--sheet-only", action="store_true",
                    help="안 뽑고 이미 있는 판으로 대조표와 배경 자만 다시 낸다")
    args = ap.parse_args()

    tags = ([t.strip() for t in args.only.split(",") if t.strip()]
            or list(illust.STYLE_CANDIDATES))
    bad = [t for t in tags if t not in illust.STYLE_CANDIDATES]
    if bad:
        print(f"[x] 모르는 후보: {bad}\n    있는 것: {list(illust.STYLE_CANDIDATES)}",
              file=sys.stderr)
        return 2

    slots = {}
    for stem in args.people:
        slot = load_slot(args.folder, stem)
        hits = prompts.suspects_in(slot)  # **우리 칸에만 건다** (모듈 머리말)
        if hits:
            print(f"[x] 인물 {stem} 의 슬롯에 용의자 {len(hits)}개 — {hits[:3]}", file=sys.stderr)
            return 2
        slots[stem] = slot

    log = os.path.join(args.folder, "style_sweep.jsonl")
    suffix = "" if args.anchor == "anime" else f"_{args.anchor}"
    if args.open_frame:
        suffix += "_open"
    frame = illust.FRAME_OPEN if args.open_frame else ""
    todo = [(t, s) for t in tags for s in args.people]
    print(f"=== 화풍 비교 — 후보 {len(tags)}, 인물 {len(args.people)}, "
          f"판 {len(todo)}장, zitani {args.steps}스텝 {illust.ILLUST_W}x{illust.ILLUST_H} ===")

    running, pending = comfy.queue_depth()
    if running or pending:
        print(f"  [!] 시작 전인데 큐가 안 비었다 — 도는 중 {running}, 대기 {pending}")

    done = skipped = 0
    for tag, stem in todo:
        axis, style = illust.STYLE_CANDIDATES[tag]
        dest = os.path.join(args.folder, f"{stem}_style_{tag}{suffix}.png")
        if args.sheet_only or (os.path.exists(dest) and not args.redo):
            skipped += 1
            continue
        prompt = illust.compose_illust(slots[stem], style, anchor=args.anchor, frame=frame)
        # 숫자만 뽑는다 — `2b` 는 **인물 2 의 시드**를 쓴다. 난수가 같아야 슬롯 한 낱말의
        # 차이를 슬롯 탓으로 돌릴 수 있다 (`gen_person.py` 와 같은 방식).
        seed = seed_of(int("".join(c for c in stem if c.isdigit()) or 0), 0, 0)
        try:
            spent = comfy.submit(
                illust.zitani_graph(prompt, seed, illust.ILLUST_W, illust.ILLUST_H,
                                    steps=args.steps, prefix=f"style/{stem}_{tag}"), dest)
        except Exception as exc:  # 판 하나가 죽어도 나머지를 세우지 않는다
            print(f"  {tag:<10} #{stem}  [x] {exc}", flush=True)
            continue
        done += 1
        print(f"  {tag:<10} #{stem}  {spent:5.1f}s  시드 {seed}   ({axis})", flush=True)
        with open(log, "a", encoding="utf-8") as f:
            f.write(json.dumps({
                "file": os.path.basename(dest), "person": stem, "style": tag, "axis": axis,
                "anchor": args.anchor,
                "style_text": style, "prompt": prompt, "seed": seed, "steps": args.steps,
                "w": illust.ILLUST_W, "h": illust.ILLUST_H, "model": illust.ZITANI_CKPT,
                "elapsed_s": round(spent, 1),
                "utc": datetime.now(timezone.utc).isoformat(),
            }, ensure_ascii=False) + "\n")

    if not args.sheet_only:
        unload("일러스트 끝")

    # ── 배경 자 — **`soft` 를 눈으로 잡았지만 눈은 옅은 것을 놓친다** ────────
    print(f"\n  배경 (좌우 바깥 띠, {measure.WHITE_CUT} 미만을 얼룩으로 본다)")
    for tag in tags:
        marks = []
        for stem in args.people:
            src = os.path.join(args.folder, f"{stem}_style_{tag}{suffix}.png")
            if not os.path.exists(src):
                continue
            dirt, worst = measure.background_dirt(src)
            marks.append(f"#{stem} {dirt:6.2f}% {measure.background_verdict(dirt)}")
        axis = illust.STYLE_CANDIDATES[tag][0]
        print(f"    {tag:<10} {'  '.join(marks):<40} {axis}")

    # ── 화풍이 옷 색을 이기나 (§27.25.6 을 자로 만든 것) ────────────────────
    #
    # 인물 순서가 곧 뜻이다 — **첫째가 무채색이어야 할 사람, 둘째가 진홍이어야 할 사람.**
    if len(args.people) >= 2:
        neutral, vivid = args.people[0], args.people[1]
        print(f"\n  옷 색 (#{neutral} 숯빛은 낮아야 맞고 #{vivid} 진홍은 높아야 맞다)")
        for tag in tags:
            a = os.path.join(args.folder, f"{neutral}_style_{tag}{suffix}.png")
            b = os.path.join(args.folder, f"{vivid}_style_{tag}{suffix}.png")
            if not (os.path.exists(a) and os.path.exists(b)):
                continue
            _, c_neutral = measure.garment_colour(a)
            _, c_vivid = measure.garment_colour(b)
            painted = c_neutral > measure.CHROMA_TINTED
            killed = 0 <= c_vivid < measure.CHROMA_KILLED
            mark = ("지배" if (painted and killed) else
                    "물듦" if (painted or killed) else "지킴")
            print(f"    {tag:<12} 숯빛 C* {c_neutral:5.1f}  진홍 C* {c_vivid:5.1f}   {mark}")

    # ── 화풍끼리 갈리나 — **잡음 바닥과 견준다** ────────────────────────────
    for stem in args.people:
        got = [os.path.join(args.folder, f"{stem}_style_{t}{suffix}.png") for t in tags]
        got = [g for g in got if os.path.exists(g)]
        if len(got) < 2:
            continue
        sp = measure.spread(got)
        base = [os.path.join(args.folder, f"{stem}_style_{tags[0]}{suffix}.png")]
        base += [os.path.join(args.folder, f"{stem}_style_{tags[0]}{suffix}_j{k}.png")
                 for k in range(1, args.jitter + 1)]
        base = [b for b in base if os.path.exists(b)]
        floor = measure.spread(base)
        note = ""
        if floor > 0:
            note = (f"  (잡음 바닥 {floor:.2f})" +
                    ("  **갈렸다**" if sp > floor * 1.5
                     else "  [!] 잡음 바닥과 비슷하다 — 화풍이 안 갈렸다"))
        print(f"\n  #{stem} 후보 {len(got)}개의 벌어짐 {sp:.2f}{note}")

    try:
        print(f"\n  대조표: {build_sheet(args.folder, args.people, tags, suffix)}")
    except ImportError:
        print("\n  [!] PIL 이 없어 대조표를 못 만든다")
    print(f"  뽑은 판 {done}장, 건너뛴 판 {skipped}장\n  결과: {args.folder}\n  로그: {log}\n")
    return 0 if done or skipped else 1


if __name__ == "__main__":
    raise SystemExit(main())
