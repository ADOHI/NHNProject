#!/usr/bin/env python3
"""`gdlint` · `gdformat --check` 를 **파일 하나씩** 돌리고, 폭사한 것만 다시 돌린다.

    python tools/run_lint_retry.py            # 둘 다
    python tools/run_lint_retry.py --only lint
    python tools/run_lint_retry.py --only format

## 왜 이 도구가 있나

이 개발 기계는 무작위로 프로세스를 죽인다(`docs/test-stability.md`).
원인은 하드웨어이고 우리 코드가 아니다.

**중요한 성질 하나:** 폭사율이 **그 프로세스가 한 일의 양에 비례한다.**

| 부하 | 폭사율 |
| --- | --- |
| `python -c "print(...)"` | 0 / 20 |
| `gdlint --version` | 0 / 10 |
| `gdlint <파일 하나>` | 1 / 10 |
| `gdlint src test tools` (약 250 파일) | **12 / 12** |

한 프로세스가 250 파일을 파싱하는 동안 한 번이라도 오염을 맞으면 통째로 죽는다.
그래서 **긴 실행 하나를 짧은 실행 여럿으로 쪼갠다.** 파일 하나가 죽으면
그 파일만 다시 돌리면 되고, 나머지 249 개의 결과는 안 버린다.

## 무엇을 숨기지 않는가

- **진짜 문제는 그대로 빨갛게 낸다.** 재시도는 **폭사한 파일에만** 한다
- 폭사와 진짜 지적은 **출력으로 갈린다** — `gdlint` 가 판정을 내면
  `: Error: ` 줄이나 `Success` 가 나온다. 그것이 없으면 판정을 못 낸 것이다
- 재시도로도 판정을 못 얻은 파일은 **따로 모아 보고하고 종료 코드 2** 로 끝난다.
  조용히 넘어가면 검사 안 한 파일이 생긴다
"""

import argparse
import os
import pathlib
import shutil
import subprocess
import sys

for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

DEFAULT_ROOTS = ["src", "test", "tools"]

# **판정은 종료 코드로 읽는다. 출력 문자열로 읽지 않는다.**
#
# 처음에는 출력에서 `Success` · `Failure: ` 같은 표시를 찾았는데 **구멍이 있었다** —
# `gdlint` 는 **파싱조차 못 한 파일에도** `Failure: 1 problem found` 를 낸다.
# 그것을 「판정 났다」로 읽고, 문제 줄은 `: Error: ` 로만 뽑으니 **0건으로 삼켰다.**
# 파싱이 안 되는 파일이 조용히 통과했고, **CI 가 잡을 때까지 몰랐다** (2026-08-21).
#
# 종료 코드는 그 함정이 없다.
#
# | 코드 | 뜻 |
# | --- | --- |
# | 0 | 깨끗하다 |
# | 1 | **지적이 있다** (파싱 실패 포함) |
# | 그 밖 | 폭사 — 재시도한다 |
EXIT_CLEAN = 0
EXIT_PROBLEMS = 1

# **도구가 스스로 터진 것은 지적이 아니다.**
#
# `gdlint`·`gdformat` 은 내부에서 파이썬 예외가 나도 종료 코드 1 로 끝난다.
# 종료 코드만 믿으면 그것이 「지적」으로 세어져 **없는 문제로 빨개진다** —
# 이 기계는 도구를 무작위로 죽이므로(§5) 그 오검출이 실제로 났다.
#
# 가르는 법: 파이썬 역추적이 있고 **판정 줄이 하나도 없으면** 도구가 터진 것이다.
# 파싱 실패(`No terminal matches ...`)는 역추적이 없으므로 **계속 지적으로 남는다** —
# §7.8 이 잡은 그 구멍을 다시 열지 않는다.
CRASH_MARK = "Traceback (most recent call last)"


def resolve(name):
    found = shutil.which(name)
    return found if found else name


def run_once(command):
    try:
        proc = subprocess.run(
            command, capture_output=True, timeout=180, encoding="utf-8", errors="replace"
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return None, "실행 자체가 실패: %s" % exc
    return proc, (proc.stdout or "") + (proc.stderr or "")


def first_meaningful(text, path):
    """지적 줄을 못 뽑았을 때 **무슨 일이 났는지** 한 줄로 보여 준다."""
    skip = str(path)
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.rstrip(":") == skip:
            continue
        return stripped
    return "출력이 비었다"


def check_file(tool, flags, path, attempts):
    """한 파일을 판정한다. (문제줄들, 폭사횟수, 판정했나)"""
    crashes = 0
    for _ in range(attempts):
        proc, text = run_once([tool] + flags + [str(path)])
        if proc is None:
            crashes += 1
            continue
        if proc.returncode == EXIT_CLEAN:
            return [], crashes, True
        if proc.returncode == EXIT_PROBLEMS:
            problems = [
                ln.strip()
                for ln in text.splitlines()
                if ": Error: " in ln or ln.startswith("would reformat")
            ]
            if not problems and CRASH_MARK in text:
                # 도구가 스스로 터졌다. 판정을 못 받은 것이므로 다시 돌린다.
                crashes += 1
                continue
            # **줄을 못 뽑았어도 지적은 지적이다.** 여기서 빈 목록을 돌려주면
            # 파싱 실패가 조용히 통과한다 — 실제로 그렇게 통과했었다 (§7.8).
            if not problems:
                problems = ["%s: %s" % (path, first_meaningful(text, path))]
            return problems, crashes, True
        crashes += 1
    return [], crashes, False


def collect(roots):
    files = []
    for root in roots:
        base = pathlib.Path(root)
        if base.is_dir():
            files.extend(sorted(base.rglob("*.gd")))
        elif base.suffix == ".gd" and base.is_file():
            files.append(base)
    return files


def sweep(label, tool, flags, files, attempts):
    print("=" * 70)
    print("%s — 파일 %d개, 파일당 최대 %d회" % (label, len(files), attempts))
    print("=" * 70, flush=True)

    problems, crashes, undecided = [], 0, []
    for index, path in enumerate(files, 1):
        found, hit, decided = check_file(tool, flags, path, attempts)
        crashes += hit
        if not decided:
            undecided.append(path)
            print("  [판정못함] %s (%d회 전부 폭사)" % (path, attempts), flush=True)
            continue
        if found:
            problems.extend(found)
            for line in found:
                print("  %s" % line, flush=True)
        if index % 50 == 0:
            print("  ... %d/%d" % (index, len(files)), flush=True)

    print("-" * 70)
    print("%s: 지적 %d건 · 폭사 후 재시도 %d회 · 판정 못한 파일 %d개"
          % (label, len(problems), crashes, len(undecided)))
    return problems, undecided


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("roots", nargs="*", default=DEFAULT_ROOTS)
    parser.add_argument("--attempts", type=int, default=5)
    parser.add_argument("--only", choices=["lint", "format"], default=None)
    args = parser.parse_args()

    files = collect(args.roots or DEFAULT_ROOTS)
    if not files:
        print("검사할 .gd 파일이 없다.")
        return 1

    all_problems, all_undecided = [], []
    if args.only in (None, "lint"):
        found, undecided = sweep("gdlint", resolve("gdlint"), [], files, args.attempts)
        all_problems += found
        all_undecided += undecided
    if args.only in (None, "format"):
        tool = resolve("gdformat")
        print()
        found, undecided = sweep("gdformat --check", tool, ["--check"], files, args.attempts)
        all_problems += found
        all_undecided += undecided

    print()
    print("=" * 70)
    if all_undecided:
        print("판정을 못 낸 파일이 %d개다. 검사 안 한 것을 통과로 치지 않는다." % len(all_undecided))
        print("=" * 70)
        return 2
    if all_problems:
        print("지적 %d건. 고쳐야 한다." % len(all_problems))
        print("=" * 70)
        return 1
    print("전부 통과.")
    print("=" * 70)
    return 0


if __name__ == "__main__":
    sys.exit(main())
