"""SD 변환 결과가 **레이맨화될 수 있는 그림인가**를 검산한다.

    python tools/check_sprite_parts.py <그림.png> [--json]

`docs/design/25-character-animation.md` §25.38 이 명세이고, 여기 박힌 요구값은
전부 **지금 리그(`char_rig.gd`)에서 나온 것**이다 — 손으로 정한 값이 하나도 없다.

## 왜 그림 한 장을 재나

그림이 두 단계로 온다 — 전신 일러스트 → **SD 변환** → 레이맨화(파츠 분리).
**이 검산은 가운데 단계의 결과에 건다.** 파츠로 이미 갈라진 뒤에 재면 늦다:
그때는 「갈릴 수 있었나」가 이미 끝난 물음이다.

## 무엇을 재나 — 알파 경계상자와 **줄 구조**뿐이다

**배경을 가장자리에서 흘려 채워(flood fill) 잡는다.** 「줄의 왼쪽 끝과 다른 색이면
캐릭터」로 먼저 해 봤다가 **틀렸다** — 청바지가 배경과 색이 비슷해서 몸통이 조각조각
끊겼고, 「팔이 떨어진 틈 0.2 %」 같은 답이 나왔다.

**흘려 채우면 그 문제가 통째로 사라진다.** 팔과 몸통 사이의 틈은 **바깥 배경과
이어져 있어서** 채워지고, 옷 안쪽의 그늘은 아무리 배경색과 비슷해도 **안 이어져서**
안 채워진다. 이웃 화소와 견주므로 배경이 그라데이션이어도 된다.

채우고 나면 줄마다 **연속 구간(run)** 을 세는 것으로 팔이 떨어졌는지가 바로 나온다.

    구간 3 개  =  팔 | 몸통 | 팔      ← 떨어져 있다. 오려 낼 수 있다
    구간 1 개  =  팔이 몸에 붙었다     ← 지운 자리가 몸통을 파먹는다

**목은 이 방법으로 못 찾는다.** 6.3 등신 원본에서 폭의 극소점으로 목을 찾았더니
「등신 12.6」이 나왔다 — 머리카락이 넓으면 목이 안 보인다(§25.37.1). SD 는 머리가
더 커서 더 안 나온다. **그래서 목은 재는 대신 「받아야 한다」고 보고한다.**

## 판정을 못 하는 것도 결과다

**「못 잼」과 「틀림」을 갈라서 낸다.** 둘을 뭉치면 재는 쪽이 조용히 거짓말한다 —
이 저장소에서 대리 지표로 여덟 번 틀린 것과 같은 모양이다(§25.13.7).
"""

import argparse
import json
import pathlib
import sys

from PIL import Image

# **콘솔 인코딩에 도구가 죽지 않게 한다.**
#
# 윈도우 콘솔이 cp949 면 대시 하나(`—`)에 `UnicodeEncodeError` 로 통째로 죽는다 --
# 실제로 그렇게 죽었다. 판정을 다 내놓고 마지막 출력에서 죽으면 **아무것도 안 한 것과 같다.**
# 이 저장소가 웹 폰트에서 겪은 두부(글리프) 함정의 명령줄 판이다 (`conventions.md` §5.1).
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

# 배경을 흘려 채울 때 **이웃 화소와의** 색 차이 한계. 그라데이션은 한 걸음이 1~2 라
# 타고 넘어가고, 잉크선은 수십이라 거기서 멈춘다.
NEIGHBOUR_STEP = 14

# 구간으로 세지 않을 잔부스러기 폭(px).
MIN_RUN = 6

# 바닥 그림자를 잘라 내는 세로 띠. 캐릭터가 가운데 있다고 보고 양옆을 버린다.
CORRIDOR_MARGIN = 0.18

# 요구값 — 전부 `char_rig.gd` 에서 나온 것이고 **키에 대한 비율**이다 (§25.38.1).
#
# 비율로 두는 것이 요점이다. 변환 결과의 해상도를 우리가 못 정하므로,
# px 로 적으면 그림이 커질 때마다 자를 다시 써야 한다.
REQUIRED = {
    "hand_gap": (0.024, "앞손과 몸 사이가 떠 있어야 한다 (레이맨의 표시)"),
    "hand_overlap": (0.031, "뒷손은 몸에 겹쳐야 한다 (깊이를 만드는 유일한 수단)"),
    "neck": (0.035, "몸 윗면과 머리 사이 (지연 0.13 s 와 갸웃이 여기서 나온다)"),
    "foot_gap": (0.149, "두 발의 앞뒤 간격 (나란히 서면 정면 자세가 된다)"),
}


def background_mask(image: Image.Image) -> bytearray:
    """가장자리에서 흘려 채운 **배경**. `1` 이면 배경, `0` 이면 캐릭터.

    **이웃과 견준다.** 배경이 그라데이션이라 절대색으로는 못 자르고, 이웃과의 차이로
    보면 잉크선에서만 크게 튄다. 그래서 그라데이션은 타고 넘어가고 실루엣에서 멈춘다.
    """
    width, height = image.size
    px = image.load()
    seen = bytearray(width * height)
    stack = []
    for x in range(width):
        stack.append((x, 0))
        stack.append((x, height - 1))
    for y in range(height):
        stack.append((0, y))
        stack.append((width - 1, y))
    while stack:
        x, y = stack.pop()
        index = y * width + x
        if seen[index]:
            continue
        seen[index] = 1
        here = px[x, y][:3]
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if nx < 0 or ny < 0 or nx >= width or ny >= height:
                continue
            if seen[ny * width + nx]:
                continue
            there = px[nx, ny][:3]
            step = (
                abs(there[0] - here[0]) + abs(there[1] - here[1]) + abs(there[2] - here[2])
            )
            if step <= NEIGHBOUR_STEP:
                stack.append((nx, ny))
    return seen


def mask_runs(image: Image.Image) -> list[list[tuple[int, int]]]:
    """줄마다 캐릭터가 차지한 연속 구간들."""
    width, height = image.size
    back = background_mask(image)
    rows = []
    for y in range(height):
        runs = []
        start = None
        base = y * width
        for x in range(width):
            on = not back[base + x]
            if on and start is None:
                start = x
            elif not on and start is not None:
                if x - start >= MIN_RUN:
                    runs.append((start, x - 1))
                start = None
        if start is not None and width - start >= MIN_RUN:
            runs.append((start, width - 1))
        rows.append(runs)
    return rows


def body_extent(rows: list[list[tuple[int, int]]], width: int) -> tuple[int, int]:
    """캐릭터의 위아래 끝. **바닥 그림자를 통로 밖으로 잘라 낸다.**

    그림자를 안 자르면 「발바닥」이 그림자 끝으로 잡혀 키가 통째로 늘어난다.
    """
    left = int(width * CORRIDOR_MARGIN)
    right = int(width * (1.0 - CORRIDOR_MARGIN))
    top = None
    bottom = None
    for y, runs in enumerate(rows):
        inside = [r for r in runs if r[0] >= left and r[1] <= right]
        if inside:
            if top is None:
                top = y
            bottom = y
    return top, bottom


def arm_window(rows, top: int, bottom: int) -> tuple[int, int, int]:
    """팔이 몸에서 떨어져 있는 구간과 **가장 좁은 틈**.

    구간이 3 개인 줄이 「팔 | 몸통 | 팔」이다. 그런 줄이 하나도 없으면
    팔이 몸에 붙어 있다는 뜻이고, 그러면 레이맨화에서 오려 낼 수가 없다.
    """
    first = None
    last = None
    tightest = None
    for y in range(top, bottom + 1):
        runs = rows[y]
        if len(runs) < 3:
            continue
        gaps = [runs[i + 1][0] - runs[i][1] for i in range(len(runs) - 1)]
        if first is None:
            first = y
        last = y
        near = min(gaps)
        tightest = near if tightest is None else min(tightest, near)
    return first, last, tightest


def split_window(rows, top: int, bottom: int, width: int):
    """아래쪽에서 **두 다리로 갈라지는** 첫 줄과 그때의 틈."""
    left = int(width * CORRIDOR_MARGIN)
    right = int(width * (1.0 - CORRIDOR_MARGIN))
    height = bottom - top
    for y in range(top + int(height * 0.45), bottom):
        runs = [r for r in rows[y] if r[0] >= left and r[1] <= right]
        if len(runs) == 2 and runs[1][0] - runs[0][1] > MIN_RUN:
            return y, runs[1][0] - runs[0][1]
    return None, None


def measure(path: pathlib.Path) -> dict:
    image = Image.open(path).convert("RGB")
    width, _ = image.size
    rows = mask_runs(image)
    top, bottom = body_extent(rows, width)
    if top is None:
        sys.exit("캐릭터를 못 찾았다: %s" % path)
    height = bottom - top
    crotch, foot_gap = split_window(rows, top, bottom, width)
    # **팔은 가랑이 위에서만 찾는다.** 아래로 내려가면 두 다리가 만드는 구간이
    # 「팔이 떨어졌다」로 세어져 자가 엉뚱한 데를 잰다.
    arm_from, arm_to, arm_gap = arm_window(rows, top, crotch if crotch else bottom)
    return {
        "path": str(path),
        "height_px": height,
        "arm_free_from": None if arm_from is None else (arm_from - top) / height,
        "arm_free_to": None if arm_to is None else (arm_to - top) / height,
        "arm_gap": None if arm_gap is None else arm_gap / height,
        "crotch": None if crotch is None else (crotch - top) / height,
        "foot_gap": None if foot_gap is None else foot_gap / height,
    }


def report(found: dict) -> int:
    """사람이 읽는 판정. **못 잰 것은 통과로 세지 않는다.**"""
    height = found["height_px"]
    lines = []
    bad = 0

    def say(mark: str, text: str) -> None:
        # **표시를 ASCII 로 둔다.** 콘솔이 cp949 면 기호 하나에 도구가 통째로 죽는다 --
        # 이 저장소가 웹 폰트에서 겪은 두부(글리프) 함정의 명령줄 판이다.
        lines.append("  %s %s" % (mark, text))

    lines.append("%s  (키 %d px)" % (found["path"], height))

    # ① 팔이 몸에서 떨어졌나 — 이것이 레이맨화가 되느냐를 정한다 (§25.38.3).
    if found["arm_gap"] is None:
        say("[X] ", "팔이 몸에 붙어 있다 — 지운 자리가 몸통 실루엣을 파먹는다")
        bad += 1
    else:
        need = REQUIRED["hand_gap"][0]
        got = found["arm_gap"]
        mark = "[OK]" if got >= need else "[X] "
        bad += 0 if got >= need else 1
        say(
            mark,
            "팔이 몸에서 떨어진 틈 %.1f%% (필요 %.1f%%) · 떨어진 구간 %.0f%%…%.0f%%"
            % (got * 100, need * 100, found["arm_free_from"] * 100, found["arm_free_to"] * 100),
        )

    # ② 두 다리가 갈라지나. 안 갈리면 두 발을 못 가른다.
    if found["foot_gap"] is None:
        say("[X] ", "두 다리가 안 갈린다 — 앞발과 뒷발을 못 가른다")
        bad += 1
    else:
        say(
            "[OK]",
            "다리가 %.0f%% 에서 갈라진다 · 발 사이 %.1f%%"
            % (found["crotch"] * 100, found["foot_gap"] * 100),
        )
        # 다리 몫은 「원본의 긴 다리가 남았나」다 (§25.38.4). 리그는 24 % 다.
        legs = 1.0 - found["crotch"]
        mark = "[OK]" if legs >= 0.24 else "[!] "
        say(mark, "다리 몫 %.0f%% (지금 리그 24 %%, 원본 55 %%)" % (legs * 100))

    # ③ 목은 못 잰다. **그 사실을 결과로 낸다** (§25.38.2).
    say("[?] ", "목 높이는 이 그림에서 못 잰다 - 값으로 받아야 한다 (필요 3.5 %)")
    say("[?] ", "뒷손 겹침은 파츠로 갈린 뒤에만 잰다 (필요 3.1 %)")

    sys.stdout.write("\n".join(lines) + "\n")
    return bad


def main() -> None:
    parser = argparse.ArgumentParser(description="SD 변환 결과가 레이맨화될 수 있는지 검산한다")
    parser.add_argument("images", nargs="+", help="검산할 PNG")
    parser.add_argument("--json", action="store_true", help="측정값을 JSON 으로")
    args = parser.parse_args()

    failed = 0
    found_all = []
    for name in args.images:
        found = measure(pathlib.Path(name))
        found_all.append(found)
        if not args.json:
            failed += report(found)
    if args.json:
        sys.stdout.write(json.dumps(found_all, ensure_ascii=False, indent=2) + "\n")
        return
    sys.stdout.write(
        "\n%d 장 중 %d 개 항목이 요구를 못 맞췄다.\n" % (len(args.images), failed)
        if failed
        else "\n요구를 다 맞췄다 (못 잰 둘은 따로 받아야 한다).\n"
    )
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
