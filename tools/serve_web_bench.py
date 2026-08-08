"""웹 빌드를 HTTP 로 서빙하면서 **측정 결과를 받아 적는다.**

웹 빌드는 `file://` 로 열면 CORS 로 `.wasm`/`.pck` 가 막힌다(`docs/web-build.md`).
그래서 어차피 서버가 필요하다. 이 서버는 거기에 하나를 더한다 —
장면이 `/bench?line=...` 로 보내는 결과 줄을 **파일과 화면에 그대로 남긴다.**

왜 콘솔을 안 읽고 이렇게 하나:

- 브라우저 창이 화면에 보이지 않으면 `requestAnimationFrame` 이 멈춘다.
  그러면 측정이 **한 줄도 진행되지 않는다** (실제로 그렇게 막혔다).
- 창을 띄우면 이번에는 그 창의 콘솔을 밖에서 붙잡을 수단이 없었다.
- 결과를 서버로 되돌려 보내면 둘 다 필요 없다. 창은 사람이 보든 안 보든 뜨면 되고,
  결과는 파일에 남는다.

쓰는 법:

    python tools/serve_web_bench.py --dir build/web --port 8071 --out .renders-lighting/web.txt
    "C:/Program Files/Google/Chrome/Application/chrome.exe" --new-window http://localhost:8071/index.html

`--out` 이 없으면 표준출력으로만 낸다. `.renders-*/` 는 `.gitignore` 에 있다.
"""

from __future__ import annotations

import argparse
import http.server
import pathlib
import urllib.parse

_ARGS: argparse.Namespace | None = None


class BenchHandler(http.server.SimpleHTTPRequestHandler):
    """`/bench?line=...` 만 가로채고 나머지는 평범한 정적 서버로 동작한다."""

    def do_GET(self) -> None:  # noqa: N802  (표준 라이브러리가 정한 이름이다)
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/bench":
            query = urllib.parse.parse_qs(parsed.query)
            for line in query.get("line", []):
                _record(line)
            self.send_response(204)
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            return
        super().do_GET()

    def log_message(self, fmt: str, *args: object) -> None:
        """정적 파일 요청 기록은 결과를 덮으므로 지운다."""


def _record(line: str) -> None:
    print(line, flush=True)
    if _ARGS is not None and _ARGS.out:
        out = pathlib.Path(_ARGS.out)
        out.parent.mkdir(parents=True, exist_ok=True)
        with out.open("a", encoding="utf-8") as handle:
            handle.write(line + "\n")


def main() -> None:
    global _ARGS
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dir", default="build/web")
    parser.add_argument("--port", type=int, default=8071)
    parser.add_argument("--out", default="")
    _ARGS = parser.parse_args()

    handler = lambda *a, **kw: BenchHandler(*a, directory=_ARGS.dir, **kw)  # noqa: E731
    server = http.server.ThreadingHTTPServer(("127.0.0.1", _ARGS.port), handler)
    print("서빙: http://localhost:%d/index.html  (dir=%s)" % (_ARGS.port, _ARGS.dir), flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
