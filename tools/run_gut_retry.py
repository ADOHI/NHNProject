"""GUT 스위트를 돌리되, **프로세스가 폭사한 경우에만** 다시 시도한다.

배경은 docs/test-stability.md 에 있다. 이 기계에서 Godot · Python 을 가리지 않고
무작위 `0xC0000005` 가 나는 것이 확인됐고, 그 탓에 테스트 스위트가 무작위로
죽어 CI 가 빨개진다. 이 러너는 **그 폭사만** 걸러 낸다.

## 절대 어기지 않는 선

- **단정 실패는 재시도하지 않는다.** GUT 가 정상 종료하며 실패를 보고하면(종료 코드 1)
  그대로 실패다. 진짜 실패를 재시도로 지우면 지금보다 나쁘다
- **시도 횟수와 매 시도의 결과를 반드시 찍는다.** 몇 번 만에 통과했는지가 로그에 남는다
- **최대 시도를 넘기면 빨갛게 실패한다.** 폭사를 초록으로 바꾸지 않는다
- **덜 돌고 통과한 것도 실패로 본다.** `--expect-tests` 로 기대 테스트 수를 박으면
  그보다 적게 돌고 끝난 실행은 통과로 치지 않는다.
  (이 저장소는 `-gtest=` 인자가 조용히 무시되는 것을 이미 겪었다)

## 사용

    python tools/run_gut_retry.py --max-attempts 3 --expect-tests 811

## 종료 코드

    0  스위트 통과
    1  테스트 실패 — 재시도하지 않았다
    2  매 시도가 폭사했다 — 기계 문제로 보이지만 초록으로 만들지 않는다
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import time

DEFAULT_GODOT = os.environ.get("GODOT", "godot")
GUT_SCRIPT = "res://addons/gut/gut_cmdln.gd"

ANSI = re.compile(r"\x1b\[[0-9;]*m")
RE_TESTS = re.compile(r"^Tests\s+(\d+)$")
RE_PASSING = re.compile(r"^Passing Tests\s+(\d+)$")
RE_SCRIPTS = re.compile(r"^Scripts\s+(\d+)$")

FATAL_NAMES = {
    0xC0000005: "ACCESS_VIOLATION",
    0xC00000FD: "STACK_OVERFLOW",
    0xC0000374: "HEAP_CORRUPTION",
    0xC000001D: "ILLEGAL_INSTRUCTION",
    0xC00000FE: "UNHANDLED_EXCEPTION",
    139: "SIGSEGV",
    134: "SIGABRT",
    11: "SIGSEGV",
}


def fatal_name(code):
    """폭사 종료 코드를 사람이 읽는 이름으로."""
    for candidate in (code, code & 0xFFFFFFFF, -code):
        if candidate in FATAL_NAMES:
            return FATAL_NAMES[candidate]
    return "exit=0x%08X" % (code & 0xFFFFFFFF)


class Attempt:
    """한 번의 시도 결과."""

    def __init__(self, index):
        self.index = index
        self.exit_code = 0
        self.seconds = 0.0
        self.scripts = 0
        self.tests = 0
        self.passing = 0

    @property
    def crashed(self):
        # 0 = 전부 통과, 1 = GUT 가 실패를 보고하고 정상 종료.
        # 그 밖의 모든 종료 코드는 프로세스가 죽은 것이다.
        return self.exit_code not in (0, 1)

    @property
    def verdict(self):
        if self.crashed:
            return "폭사 (%s)" % fatal_name(self.exit_code)
        if self.exit_code == 1:
            return "테스트 실패 (%d/%d 통과)" % (self.passing, self.tests)
        return "통과 (%d/%d, 스크립트 %d)" % (self.passing, self.tests, self.scripts)


def parse_summary(attempt, text):
    """GUT 실행 요약에서 스크립트 · 테스트 · 통과 수를 읽는다."""
    for raw in ANSI.sub("", text).splitlines():
        line = raw.strip()
        found = RE_SCRIPTS.match(line)
        if found:
            attempt.scripts = int(found.group(1))
            continue
        found = RE_TESTS.match(line)
        if found:
            attempt.tests = int(found.group(1))
            continue
        found = RE_PASSING.match(line)
        if found:
            attempt.passing = int(found.group(1))


def run_attempt(index, args):
    attempt = Attempt(index)
    command = [args.godot, "--headless", "--path", args.project, "-s", GUT_SCRIPT]
    started = time.time()
    proc = subprocess.Popen(
        command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, cwd=args.project
    )
    chunks = []
    for line in proc.stdout:
        chunks.append(line)
        if not args.quiet:
            sys.stdout.buffer.write(line)
            sys.stdout.flush()
    proc.wait()
    attempt.seconds = time.time() - started
    attempt.exit_code = proc.returncode
    parse_summary(attempt, b"".join(chunks).decode("utf-8", errors="replace"))
    return attempt


def main():
    parser = argparse.ArgumentParser(description="폭사에만 재시도하는 GUT 러너")
    parser.add_argument("--max-attempts", type=int, default=3)
    parser.add_argument("--godot", default=DEFAULT_GODOT)
    parser.add_argument("--project", default=".")
    parser.add_argument(
        "--expect-tests",
        type=int,
        default=0,
        help="기대 테스트 수. 이보다 적게 돌고 끝나면 통과로 치지 않는다",
    )
    parser.add_argument("--quiet", action="store_true", help="GUT 출력을 중계하지 않는다")
    args = parser.parse_args()
    args.project = os.path.abspath(args.project)

    attempts = []
    for index in range(1, args.max_attempts + 1):
        print("")
        print("=== GUT 시도 %d/%d ===" % (index, args.max_attempts), flush=True)
        attempt = run_attempt(index, args)
        attempts.append(attempt)
        print("--- 시도 %d: %s (%.1fs)" % (index, attempt.verdict, attempt.seconds), flush=True)

        if attempt.crashed:
            if index < args.max_attempts:
                print("--- 프로세스가 죽었다. 단정 실패가 아니므로 다시 시도한다.", flush=True)
            continue

        # 여기부터는 GUT 가 정상 종료한 경우다. 재시도하지 않는다.
        if attempt.exit_code == 1:
            report(attempts, "테스트가 실패했다. 재시도하지 않는다 — 진짜 실패다.")
            return 1
        if args.expect_tests and attempt.tests < args.expect_tests:
            report(
                attempts,
                "통과했지만 %d개만 돌았다 (기대 %d개). 덜 돈 실행은 통과로 치지 않는다."
                % (attempt.tests, args.expect_tests),
            )
            return 1
        report(attempts, "통과.")
        return 0

    report(attempts, "%d회 전부 프로세스가 죽었다. 초록으로 만들지 않는다." % args.max_attempts)
    return 2


def report(attempts, verdict):
    print("")
    print("=" * 70)
    print("시도 요약 — 총 %d회" % len(attempts))
    for attempt in attempts:
        print("  %d) %-46s %5.1fs" % (attempt.index, attempt.verdict, attempt.seconds))
    print("-" * 70)
    print(verdict)
    print("=" * 70, flush=True)


if __name__ == "__main__":
    sys.exit(main())
