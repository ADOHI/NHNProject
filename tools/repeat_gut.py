"""GUT 를 여러 번 돌려 비결정적 크래시의 재현률과 죽는 자리를 잰다.

빌드에 들어가지 않는 조사 도구다. 배경은 docs/test-stability.md 에 있다.

사용:
    python tools/repeat_gut.py -n 10
    python tools/repeat_gut.py -n 10 --rss          # 프로세스 RSS 를 함께 잰다
    python tools/repeat_gut.py -n 5 -- -gdir=res://test/unit/foo

출력: 회차별 종료 코드 · 통과 수 · 크래시 위치 표와 분포 요약.
로그는 --out 디렉터리에 run_NN.log 로 남는다 (기본값은 임시 디렉터리).
"""

from __future__ import annotations

import argparse
import collections
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import threading
import time

DEFAULT_GODOT = "C:/Users/adohi/Godot/Godot_v4.7.1-stable_win64_console.exe"
GUT_SCRIPT = "res://addons/gut/gut_cmdln.gd"

ANSI = re.compile(r"\x1b\[[0-9;]*m")
RE_SIGNAL = re.compile(r"crashed with signal (\d+)")
RE_CPP_FRAME = re.compile(r"^\[(\d+)\] [0-9a-f]+ \((.+?)\)")
RE_GD_FRAME = re.compile(r"^\s*\[(\d+)\] (\S+) \((res://.+?):(\d+)\)")
RE_SCRIPT = re.compile(r"^res://test/.+\.gd$")
RE_TEST = re.compile(r"^\* (\w+)")
RE_PASSED = re.compile(r"^(\d+)/(\d+) passed\.")
RE_TOTALS = re.compile(r"(\d+) of (\d+) passed")
RE_ORPHAN = re.compile(r"^\s*(\d+) Orphans")


class RunResult:
    """한 회차의 관측값."""

    def __init__(self, index, log_path):
        self.index = index
        self.log_path = log_path
        self.exit_code = 0
        self.seconds = 0.0
        self.signal = None
        self.cpp_frames = []
        self.gd_frames = []
        self.last_script = None
        self.last_test = None
        self.asserts_passed = 0
        self.asserts_total = 0
        self.scripts_run = 0
        self.orphans = 0
        self.peak_rss_mb = 0.0
        self.has_dump = False

    @property
    def crashed(self):
        return self.signal is not None or self.exit_code not in (0, 1)

    @property
    def crash_site(self):
        if not self.crashed:
            return "-"
        if self.gd_frames:
            return self.gd_frames[0]
        # 크래시 덤프조차 못 찍고 죽은 경우가 대부분이다. 그때는 마지막으로
        # 돌던 스크립트가 유일한 단서다.
        return "덤프 없음 · 마지막 스크립트 %s" % self.last_script

    @property
    def faulting_cpp(self):
        # [1] 은 크래시 핸들러 자신, 그 뒤 ntdll 은 예외 디스패치 경로다.
        # 엔진 주소가 다시 나오는 첫 프레임이 실제로 터진 자리다.
        for frame in self.cpp_frames[1:]:
            if not frame.startswith("ntdll") and not frame.startswith("KERNEL"):
                return frame
        return "?"


def parse_log(result):
    """로그에서 크래시 위치 · 통과 수 · 마지막으로 돌던 테스트를 뽑는다."""
    text = ANSI.sub("", result.log_path.read_text(encoding="utf-8", errors="replace"))
    in_cpp = False
    in_gd = False
    for raw in text.splitlines():
        line = raw.rstrip()
        stripped = line.strip()

        found = RE_SIGNAL.search(line)
        if found:
            result.signal = int(found.group(1))
            result.has_dump = True
            in_cpp = True
            continue
        if stripped.startswith("-- END OF C++"):
            in_cpp = False
            continue
        # 크래시 덤프의 백트레이스는 1열에서 시작한다.
        # push_error 가 찍는 백트레이스는 들여쓰여 있고 종료 표시가 없다 —
        # 둘을 안 가르면 정상 실행 로그가 통째로 백트레이스로 먹힌다.
        if line.startswith("GDScript backtrace"):
            in_gd = True
            continue
        if stripped.startswith("-- END OF GDSCRIPT"):
            in_gd = False
            continue

        if in_cpp:
            found = RE_CPP_FRAME.match(stripped)
            if found:
                result.cpp_frames.append(found.group(2).split(" - ")[0])
            continue
        if in_gd:
            found = RE_GD_FRAME.match(line)
            if found:
                func, path, num = found.group(2), found.group(3), found.group(4)
                result.gd_frames.append("%s (%s:%s)" % (func, path, num))
            continue

        if RE_SCRIPT.match(stripped):
            result.last_script = stripped
            result.scripts_run += 1
            continue
        found = RE_TEST.match(stripped)
        if found:
            result.last_test = found.group(1)
            continue
        found = RE_PASSED.match(stripped)
        if found:
            result.asserts_passed += int(found.group(1))
            result.asserts_total += int(found.group(2))
            continue
        found = RE_ORPHAN.match(line)
        if found:
            result.orphans += int(found.group(1))
            continue
        found = RE_TOTALS.search(stripped)
        if found:
            result.asserts_passed = int(found.group(1))
            result.asserts_total = int(found.group(2))


def watch_rss(proc, result, stop):
    """프로세스 RSS 최고치를 잰다 — 가설 「누적 메모리」를 가르는 데 쓴다."""
    try:
        import psutil
    except ImportError:
        return
    try:
        handle = psutil.Process(proc.pid)
    except Exception:
        return
    while not stop.is_set():
        try:
            mbytes = handle.memory_info().rss / (1024 * 1024)
        except Exception:
            return
        result.peak_rss_mb = max(result.peak_rss_mb, mbytes)
        stop.wait(0.05)


def run_once(index, args, out_dir):
    log_path = out_dir / ("run_%02d.log" % index)
    result = RunResult(index, log_path)
    command = [args.godot, "--headless", "--path", args.project, "-s", GUT_SCRIPT]
    command.extend(args.gut_args)
    started = time.time()
    with log_path.open("wb") as sink:
        proc = subprocess.Popen(command, stdout=sink, stderr=subprocess.STDOUT)
        stop = threading.Event()
        watcher = None
        if args.rss:
            watcher = threading.Thread(target=watch_rss, args=(proc, result, stop))
            watcher.daemon = True
            watcher.start()
        proc.wait()
        stop.set()
        if watcher:
            watcher.join(timeout=1.0)
    result.seconds = time.time() - started
    result.exit_code = proc.returncode
    parse_log(result)
    return result


def report(results, out_dir):
    print("")
    print("=" * 100)
    print(
        "%-4s %-7s %-7s %-8s %-9s %-8s %s"
        % ("회차", "종료", "초", "스크립트", "단정", "RSS(MB)", "죽은 자리")
    )
    print("-" * 100)
    for item in results:
        print(
            "%-4d %-7s %-7.1f %-8d %-9s %-8.0f %s"
            % (
                item.index,
                item.exit_code if not item.signal else "sig%d" % item.signal,
                item.seconds,
                item.scripts_run,
                "%d/%d" % (item.asserts_passed, item.asserts_total),
                item.peak_rss_mb,
                item.crash_site,
            )
        )
    crashed = [item for item in results if item.crashed]
    print("-" * 100)
    rate = 100.0 * len(crashed) / max(1, len(results))
    print("재현률: %d/%d (%.0f%%)" % (len(crashed), len(results), rate))

    if crashed:
        print("")
        print("죽은 GDScript 자리 분포:")
        counter = collections.Counter(i.crash_site for i in crashed)
        for site, count in counter.most_common():
            print("  %2d회  %s" % (count, site))
        print("")
        print("터진 C++ 프레임 분포 (엔진 주소):")
        counter = collections.Counter(i.faulting_cpp for i in crashed)
        for frame, count in counter.most_common():
            print("  %2d회  %s" % (count, frame))
        print("")
        print("죽기 직전 스크립트 분포:")
        counter = collections.Counter(str(i.last_script) for i in crashed)
        for script, count in counter.most_common():
            print("  %2d회  %s" % (count, script))
        depths = [i.scripts_run for i in crashed]
        print("")
        print("크래시 시점 스크립트 진행도: 최소 %d · 최대 %d" % (min(depths), max(depths)))
    clean = [item for item in results if not item.crashed]
    if clean:
        totals = collections.Counter(
            "%d/%d" % (i.asserts_passed, i.asserts_total) for i in clean
        )
        print("")
        print("완주한 회차의 단정 합계: %s" % dict(totals))
    print("")
    print("로그: %s" % out_dir)
    print("=" * 100)


def main():
    parser = argparse.ArgumentParser(description="GUT 반복 실행 · 크래시 통계")
    parser.add_argument("-n", "--runs", type=int, default=10, help="반복 횟수")
    parser.add_argument("--godot", default=os.environ.get("GODOT", DEFAULT_GODOT))
    parser.add_argument("--project", default=".", help="프로젝트 경로")
    parser.add_argument("--out", default=None, help="로그 디렉터리")
    parser.add_argument("--rss", action="store_true", help="RSS 최고치를 잰다")
    parser.add_argument("gut_args", nargs="*", help="-- 뒤의 인자는 GUT 로 넘어간다")
    args = parser.parse_args()

    if args.out:
        out_dir = pathlib.Path(args.out)
    else:
        out_dir = pathlib.Path(tempfile.mkdtemp(prefix="gut_repeat_"))
    out_dir.mkdir(parents=True, exist_ok=True)

    results = []
    for index in range(1, args.runs + 1):
        item = run_once(index, args, out_dir)
        results.append(item)
        mark = "CRASH sig%s" % item.signal if item.crashed else "ok"
        print(
            "[%2d/%2d] %-12s %5.1fs  %s"
            % (
                index,
                args.runs,
                mark,
                item.seconds,
                item.crash_site if item.crashed else "",
            ),
            flush=True,
        )
    report(results, out_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
