"""서로 무관한 작업 부하를 같은 횟수로 돌려 「누가 죽는가」를 가른다.

배경과 결론은 docs/test-stability.md 에 있다. 빌드에 들어가지 않는 조사 도구다.

가르려는 것: 무작위 `0xC0000005` 가 **우리 코드/Godot 의 문제인가, 이 기계의 문제인가.**

세 부하를 같은 조건에서 돌린다.

    gut      Godot 헤드리스 + GUT 전체 스위트 (우리 코드 · 네이티브 C++)
    gdformat gdtoolkit 포맷 검사 (우리 파일을 읽지만 런타임은 Python)
    control  저장소와 무관한 순수 계산/할당 루프 (Python, 파일 입출력 없음)

`control` 까지 같은 비율로 죽으면 **부하 내용과 무관** — 기계가 확정된다.
`control` 만 멀쩡하면 부하 성격에 따라 갈린다는 뜻이라 그 또한 값진 정보다.

`control` 은 크래시뿐 아니라 **조용한 값 오염**도 잡는다. 매 회차 같은 체크섬이
나와야 하므로, 죽지 않고 값만 틀리면 그것도 기록된다.

사용:
    python tools/crash_matrix.py -n 20
    python tools/crash_matrix.py -n 20 --only control
"""

from __future__ import annotations

import argparse
import collections
import os
import pathlib
import subprocess
import sys
import tempfile
import time

DEFAULT_GODOT = "C:/Users/adohi/Godot/Godot_v4.7.1-stable_win64_console.exe"
GUT_SCRIPT = "res://addons/gut/gut_cmdln.gd"

# Windows 가 접근 위반으로 프로세스를 죽일 때의 종료 코드. 셸에서는 신호 11 로 보인다.
ACCESS_VIOLATION = 0xC0000005
STACK_OVERFLOW = 0xC00000FD
HEAP_CORRUPTION = 0xC0000374

FATAL_CODES = {
    ACCESS_VIOLATION: "ACCESS_VIOLATION",
    STACK_OVERFLOW: "STACK_OVERFLOW",
    HEAP_CORRUPTION: "HEAP_CORRUPTION",
    0xC000001D: "ILLEGAL_INSTRUCTION",
    0xC0000094: "INT_DIVIDE_BY_ZERO",
    0xC00000FE: "UNHANDLED_EXCEPTION",
    139: "SIGSEGV",
    134: "SIGABRT",
}


def is_fatal(code):
    """단정 실패(1)와 프로세스 폭사를 가른다. 이 구분이 이 조사의 전부다."""
    if code in (0, 1):
        return False
    return True


def fatal_name(code):
    if code in FATAL_CODES:
        return FATAL_CODES[code]
    unsigned = code & 0xFFFFFFFF
    if unsigned in FATAL_CODES:
        return FATAL_CODES[unsigned]
    return "exit=0x%08X" % unsigned


# ------------------------------------------------------------------ 대조군

CONTROL_SECONDS = 20.0
CONTROL_EXPECT = None  # 첫 회차 값을 기준으로 삼는다.


def control_worker(seconds):
    """저장소와 무관한 순수 계산 · 할당 루프.

    Godot 스위트와 비슷한 시간 동안 정수 연산과 힙 할당을 섞어 돌린다.
    파일도 네트워크도 건드리지 않으므로, 여기서 죽으면 남는 설명은 기계뿐이다.
    매 라운드 같은 체크섬이 나와야 한다 — 값이 틀려도 기록된다.
    """
    deadline = time.time() + seconds
    rounds = 0
    reference = None
    while time.time() < deadline:
        # 할당 처닝: 딕셔너리 · 리스트 · 문자열을 만들고 버린다.
        table = {}
        for index in range(20000):
            key = "k%d" % (index * 2654435761 % 65521)
            table.setdefault(key, []).append(index * index % 1000003)
        # 결정적 체크섬: 같은 입력이면 언제나 같은 값이어야 한다.
        digest = 0
        for key in sorted(table):
            for value in table[key]:
                digest = (digest * 1000003 + value) & 0xFFFFFFFFFFFF
        if reference is None:
            reference = digest
        elif digest != reference:
            # 폭사가 아니라 「자기 검사 실패」다. 폭사율 숫자를 흐리지 않도록 1 로 낸다.
            print("CONTROL_MISMATCH round=%d got=%d want=%d" % (rounds, digest, reference))
            return 1
        rounds += 1
    print("CONTROL_OK rounds=%d digest=%d" % (rounds, reference))
    return 0


# ------------------------------------------------------------------ 실행

def build_command(name, args):
    if name == "gut":
        return [args.godot, "--headless", "--path", args.project, "-s", GUT_SCRIPT]
    if name == "gdformat":
        return ["gdformat", "--check", "src", "test", "tools"]
    if name == "control":
        return [sys.executable, os.path.abspath(__file__), "--control-worker", str(args.control_seconds)]
    raise SystemExit("모르는 부하: %s" % name)


def run_once(name, args, log_path):
    command = build_command(name, args)
    started = time.time()
    with log_path.open("wb") as sink:
        proc = subprocess.Popen(
            command, stdout=sink, stderr=subprocess.STDOUT, cwd=args.project
        )
        proc.wait()
    return proc.returncode, time.time() - started


def measure(name, args, out_dir):
    results = []
    print("")
    print("### 부하 [%s] × %d회" % (name, args.runs))
    for index in range(1, args.runs + 1):
        log_path = out_dir / ("%s_%02d.log" % (name, index))
        code, seconds = run_once(name, args, log_path)
        fatal = is_fatal(code)
        mark = fatal_name(code) if fatal else ("ok" if code == 0 else "fail(단정)")
        results.append((code, seconds, fatal, log_path))
        print("  [%2d/%2d] %-22s %5.1fs" % (index, args.runs, mark, seconds), flush=True)
        # 대조군이 죽지 않고 값만 틀린 경우도 잡는다.
        if name == "control" and not fatal:
            text = log_path.read_text(encoding="utf-8", errors="replace")
            if "CONTROL_MISMATCH" in text:
                print("        !! 조용한 값 오염: %s" % text.strip().splitlines()[-1])
    return results


def report(table):
    print("")
    print("=" * 78)
    print("%-12s %-8s %-10s %-10s %s" % ("부하", "횟수", "폭사", "비율", "관측된 종료 코드"))
    print("-" * 78)
    for name, results in table.items():
        fatal = [item for item in results if item[2]]
        codes = collections.Counter(fatal_name(item[0]) for item in fatal)
        rate = 100.0 * len(fatal) / max(1, len(results))
        summary = ", ".join("%s×%d" % (key, value) for key, value in codes.most_common())
        print(
            "%-12s %-8d %-10d %-10s %s"
            % (name, len(results), len(fatal), "%.0f%%" % rate, summary or "-")
        )
    print("=" * 78)


def main():
    parser = argparse.ArgumentParser(description="작업 부하별 폭사율 비교")
    parser.add_argument("--control-worker", type=float, default=None, help=argparse.SUPPRESS)
    parser.add_argument("-n", "--runs", type=int, default=20)
    parser.add_argument("--godot", default=os.environ.get("GODOT", DEFAULT_GODOT))
    parser.add_argument("--project", default=".")
    parser.add_argument("--out", default=None)
    parser.add_argument("--control-seconds", type=float, default=CONTROL_SECONDS)
    parser.add_argument(
        "--only", action="append", default=None, help="부하 이름 (gut/gdformat/control)"
    )
    args = parser.parse_args()

    if args.control_worker is not None:
        return control_worker(args.control_worker)

    args.project = os.path.abspath(args.project)
    if args.out:
        out_dir = pathlib.Path(args.out)
    else:
        out_dir = pathlib.Path(tempfile.mkdtemp(prefix="crash_matrix_"))
    out_dir.mkdir(parents=True, exist_ok=True)

    names = args.only if args.only else ["gut", "gdformat", "control"]
    table = collections.OrderedDict()
    for name in names:
        table[name] = measure(name, args, out_dir)
    report(table)
    print("로그: %s" % out_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
