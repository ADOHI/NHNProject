"""윈도 콘솔이 cp949 라서 한글과 `—` 가 터진다. 도구마다 한 줄로 고친다.

`docs/conventions.md` 가 아니라 여기 있는 이유 — 이건 저장소 규약이 아니라
**이 도구들이 도는 환경의 문제**다. Godot 쪽 코드는 이 문제를 겪지 않는다.
"""

from __future__ import annotations

import sys


def utf8() -> None:
    """표준 출력을 UTF-8 로 돌린다. 못 돌리면 조용히 넘어간다."""
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[union-attr]
        except (AttributeError, OSError):
            pass
