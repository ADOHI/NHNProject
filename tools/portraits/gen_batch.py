#!/usr/bin/env python
"""밤샘 배치 — 전신 일러스트(zitani) → SD 변환(Klein edit). **모델을 갈 때마다 VRAM 을 내린다.**

    python tools/portraits/gen_batch.py .captures/portraits/cast4 --stage illust
    python tools/portraits/gen_batch.py .captures/portraits/cast4 --stage sd
    python tools/portraits/gen_batch.py .captures/portraits/cast4          # 둘 다

`docs/design/27-portraits.md` §27.22.

# 왜 단계로 나누고 한 단계를 몰아서 도나

**모델을 한 장마다 갈아 끼우면 적재 시간이 장수만큼 붙는다.** zitani 콜드 18초 ·
Klein 콜드 21초다. 그래서 **일러스트를 전부 뽑고 → VRAM 을 내리고 → SD 를 전부 뽑는다.**
적재가 배치당 한 번으로 준다.

    일러스트 N장 → comfy.free() → VRAM 확인 → SD N장 → comfy.free()

# 죽어도 앞부분이 남는다

판마다 `.captures/portraits/log.jsonl` 에 한 줄이 붙는다. 중간에 끊겨도
**이미 뽑은 것은 파일과 로그에 남아 있고**, 다시 돌리면 있는 것은 건너뛴다.
밤새 도는 배치라 이것이 없으면 아침에 처음부터다.
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import sys
import time
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import comfy  # noqa: E402
import console  # noqa: E402
import illust  # noqa: E402
import prompts  # noqa: E402
from gen_person import seed_of  # noqa: E402

console.utf8()

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
LOG = os.path.join(ROOT, ".captures", "portraits", "log.jsonl")

#: 일러스트와 SD 의 시드를 갈라 두는 값. 둘이 같은 시드를 쓰면 로그에서 못 가른다.
SD_SEED_OFFSET = 500_009


def _record(entry: dict) -> None:
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    with open(LOG, "a", encoding="utf-8") as f:
        entry["utc"] = datetime.now(timezone.utc).isoformat()
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")


def _people(folder: str) -> list[tuple[str, str]]:
    """(인물 번호, 착장 원문). `gen_character.py` 가 낸 `<번호>_look_raw.txt` 를 읽는다."""
    out = []
    for path in sorted(glob.glob(os.path.join(folder, "*_look_raw.txt"))):
        stem = os.path.basename(path).replace("_look_raw.txt", "")
        with open(path, encoding="utf-8") as f:
            out.append((stem, f.read().strip()))
    return out


def _vram() -> tuple[float, float]:
    """(비어 있는 GB, 전체 GB). **모델을 내린 뒤 실제로 내려갔는지 본다.**"""
    d = comfy.get("/system_stats")["devices"][0]
    return d["vram_free"] / 1e9, d["vram_total"] / 1e9


#: VRAM 이 이 비율 위로 올라와야 "내려갔다"고 본다. 모델 하나가 7~9GB 라
#: 절반이 안 비면 아직 물려 있는 것이다.
FREE_RATIO = 0.6

#: `/free` 뒤에 비는 데 걸리는 시간. **곧바로 재면 아직 안 내려가 있다** (실측 §27.22.1).
FREE_TRIES, FREE_WAIT = 12, 2.0


def _cool(label: str) -> None:
    """모델을 내리고 **실제로 내려갔는지 확인한다.**

    `/free` 는 즉시 돌아오지만 VRAM 은 바로 안 빈다 — 배치 직후에 쟀더니
    17.2GB 중 5.2GB 만 비어 있었고, 잠시 뒤 다시 재니 15.0GB 였다 (§27.22.1).
    **곧바로 재고 「안 내려갔다」고 판단하면 다음 모델을 안 올리게 된다.**
    그래서 오를 때까지 기다린다. 안 오르면 찍고 넘어가되 **경고를 남긴다** —
    다음 모델을 그 위에 올리면 경합하고, 최악에는 기계가 죽는다.
    """
    comfy.free()
    total = 0.0
    for _try in range(FREE_TRIES):
        free, total = _vram()
        if free / max(total, 1e-9) >= FREE_RATIO:
            print(f"  [VRAM] {label} 뒤 — 비어 있음 {free:.1f}/{total:.1f} GB", flush=True)
            return
        time.sleep(FREE_WAIT)
    free, total = _vram()
    print(f"  [!] [VRAM] {label} 뒤에도 안 내려갔다 — 비어 있음 {free:.1f}/{total:.1f} GB."
          f" **다음 모델을 올리면 경합한다**", flush=True)


def stage_illust(folder: str, people, steps: int, redo: bool) -> int:
    print(f"\n=== ① 전신 일러스트 — zitani {steps}스텝 · {illust.ILLUST_W}x{illust.ILLUST_H} ===")
    done = 0
    for stem, look in people:
        dest = os.path.join(folder, f"{stem}_illust.png")
        if os.path.exists(dest) and not redo:
            print(f"  {stem:>6}  이미 있다 — 건너뛴다", flush=True)
            continue
        prompt = illust.compose_illust(look)
        hits = prompts.suspects_in(prompt)
        if hits:
            # **도구 · 무기가 여기서도 걸린다** (§27.20). 전신이라 오히려 더 잘 샌다.
            print(f"  {stem:>6}  [x] 용의자 {len(hits)}개 — {hits[:3]}", flush=True)
            _record({"file": os.path.basename(dest), "person": stem,
                     "stage": "illust", "suspects": hits, "skipped": True})
            continue
        seed = seed_of(int("".join(c for c in stem if c.isdigit()) or 0), 0, 0)
        try:
            spent = comfy.submit(
                illust.zitani_graph(prompt, seed, illust.ILLUST_W, illust.ILLUST_H,
                                    steps=steps, prefix="illust/" + stem), dest)
        except Exception as exc:  # 한 장이 실패해도 배치를 세우지 않는다
            print(f"  {stem:>6}  [x] {exc}", flush=True)
            _record({"file": os.path.basename(dest), "person": stem,
                     "stage": "illust", "error": str(exc), "seed": seed})
            continue
        done += 1
        print(f"  {stem:>6}  {spent:5.1f}s  시드 {seed}", flush=True)
        _record({"file": os.path.basename(dest), "person": stem, "stage": "illust",
                 "model": illust.ZITANI_CKPT, "seed": seed, "steps": steps,
                 "w": illust.ILLUST_W, "h": illust.ILLUST_H,
                 "prompt": prompt, "elapsed_s": round(spent, 1)})
    return done


def stage_sd(folder: str, people, redo: bool) -> int:
    print(f"\n=== ② SD 변환 — Klein 4B Pro edit {illust.KLEIN_EDIT_STEPS}스텝 · "
          f"{illust.SD_SIZE}² ===")
    done = 0
    for stem, _look in people:
        src = os.path.join(folder, f"{stem}_illust.png")
        dest = os.path.join(folder, f"{stem}_sd.png")
        if not os.path.exists(src):
            print(f"  {stem:>6}  일러스트가 없다 — 건너뛴다", flush=True)
            continue
        if os.path.exists(dest) and not redo:
            print(f"  {stem:>6}  이미 있다 — 건너뛴다", flush=True)
            continue
        # **레퍼런스는 서버의 input 폴더에 있어야 한다** — LoadImage 가 로컬 경로를 모른다.
        name = comfy.upload(src)
        seed = seed_of(int("".join(c for c in stem if c.isdigit()) or 0), 0, 0) + SD_SEED_OFFSET
        try:
            spent = comfy.submit(
                illust.klein_edit_graph(illust.SD_CONVERT, name, seed,
                                        prefix="sd/" + stem), dest)
        except Exception as exc:
            print(f"  {stem:>6}  [x] {exc}", flush=True)
            _record({"file": os.path.basename(dest), "person": stem,
                     "stage": "sd", "error": str(exc), "seed": seed})
            continue
        done += 1
        print(f"  {stem:>6}  {spent:5.1f}s  시드 {seed}", flush=True)
        _record({"file": os.path.basename(dest), "person": stem, "stage": "sd",
                 "model": illust.KLEIN_UNET, "reference": name, "seed": seed,
                 "steps": illust.KLEIN_EDIT_STEPS, "w": illust.SD_SIZE, "h": illust.SD_SIZE,
                 "prompt": illust.SD_CONVERT, "elapsed_s": round(spent, 1)})
    return done


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("folder", help="gen_character.py 산출이 있는 폴더")
    ap.add_argument("--stage", choices=["illust", "sd", "both"], default="both")
    ap.add_argument("--steps", type=int, default=illust.ZITANI_STEPS,
                    help="일러스트 스텝. **기본값이 제작자 권장이다** — 근거 없이 올리지 마라")
    ap.add_argument("--redo", action="store_true", help="이미 있는 판도 다시 뽑는다")
    args = ap.parse_args()

    people = _people(args.folder)
    if not people:
        print(f"  [x] 착장 파일이 없다: {args.folder}/*_look_raw.txt", file=sys.stderr)
        return 2

    running, pending = comfy.queue_depth()
    free, total = _vram()
    print(f"=== 배치 — 인물 {len(people)}명 · {args.folder} ===")
    print(f"  큐 {running}/{pending} · VRAM {free:.1f}/{total:.1f} GB")
    if running or pending:
        print("  [!] 큐가 비어 있지 않다 — 다른 레인이 쓰는 중일 수 있다")

    made = 0
    if args.stage in ("illust", "both"):
        made += stage_illust(args.folder, people, args.steps, args.redo)
        _cool("일러스트")
    if args.stage in ("sd", "both"):
        made += stage_sd(args.folder, people, args.redo)
        _cool("SD 변환")

    print(f"\n  뽑은 판 {made}장\n  결과: {args.folder}\n  로그: {LOG}\n")
    return 0 if made else 1


if __name__ == "__main__":
    raise SystemExit(main())
