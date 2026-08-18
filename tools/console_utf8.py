"""윈도우 콘솔은 기본이 **cp949** 다. 한국어 도구가 이걸 안 다스리면 언젠가
`UnicodeEncodeError` 로 죽는다 — 실제로 `make_plate_normal.py --help` 가 줄표
(`—`, U+2014) 한 글자 때문에 죽었다 (`docs/design/26-2d-lighting.md` §26.14).

**글자를 하나씩 피하는 것은 손잡이가 안 된다.** `—` 를 고쳐도 다음 사람이 `…` 나
`""` 를 쓰면 또 죽는다. 진짜 원인은 특정 글자가 아니라 **콘솔 인코딩이 cp949 라는
것** 자체다. 그래서 글자를 피하지 않고 **인코딩을 UTF-8 로 못 박는다.**

이 저장소의 `tools/` 는 전부 한국어를 콘솔에 찍는다. 그러므로 이 함수는
**한 곳**에 두고, 도구마다 `main()` 첫 줄에서 부른다 — 그래야 첫 `print` 나
`argparse` 의 `--help` 보다 먼저 인코딩이 바뀐다. 도구를 새로 만들 때도
이 한 줄만 넣으면 되므로, 다음 사람이 이 함정을 다시 밟을 여지가 준다.
"""

from __future__ import annotations

import sys


def fix_console_encoding() -> None:
    """`stdout` · `stderr` 를 UTF-8 로 바꾼다. **`main()` 의 첫 줄에서, 다른 어떤
    출력보다도 먼저 불러야 한다.**

    `hasattr` 로 감싸는 이유는 스트림이 파이프로 리다이렉트되거나 이미 다른 무언가로
    교체된 경우 `reconfigure` 가 없는 객체일 수 있어서다. 그런 환경은 애초에
    파이썬이 골라 준 인코딩을 쓰므로 이 함수가 손댈 필요도 없다.
    """
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
