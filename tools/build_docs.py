"""제출용 문서를 마크다운에서 PDF로 변환한다.

사용법:
    python tools/build_docs.py             # docs/ai-usage.md -> docs/build/AI활용기술문서.pdf
    python tools/build_docs.py <입력.md> <출력.pdf>

변환 경로는 마크다운 -> HTML -> (Chrome 헤들리스 인쇄) -> PDF 다.
Chrome 을 쓰는 이유는 한글 때문이다. 시스템에 설치된 맑은 고딕을 그대로 사용하므로
CJK 폰트를 따로 등록할 필요가 없다. Chrome 이 없으면 Edge 로 대체한다.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

try:
    import markdown
except ImportError:
    sys.exit("markdown 패키지가 필요합니다:  python -m pip install markdown")


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SOURCE = ROOT / "docs" / "ai-usage.md"
DEFAULT_OUTPUT = ROOT / "docs" / "build" / "AI활용기술문서.pdf"

# Chrome 계열 브라우저 후보. 앞에 있는 것부터 찾는다.
BROWSER_CANDIDATES = (
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
)

# A4 인쇄용 스타일. 화면용이 아니라 종이 기준이므로 pt 단위를 쓴다.
PRINT_CSS = """
@page { size: A4; margin: 18mm 16mm; }

html { -webkit-print-color-adjust: exact; print-color-adjust: exact; }

body {
  font-family: "Malgun Gothic", "맑은 고딕", "Noto Sans KR", sans-serif;
  font-size: 10.5pt;
  line-height: 1.65;
  color: #1b1d21;
  margin: 0;
}

h1 {
  font-size: 21pt;
  margin: 0 0 4pt;
  padding-bottom: 10pt;
  border-bottom: 2.5pt solid #1b1d21;
  letter-spacing: -0.3pt;
}

/* 각 대단원은 새 쪽에서 시작한다. 단, 문서 첫 제목 뒤의 첫 단원은 제외. */
h2 {
  font-size: 14pt;
  margin: 22pt 0 8pt;
  padding-bottom: 4pt;
  border-bottom: 0.8pt solid #c8ccd4;
  break-before: page;
  break-after: avoid;
}
h1 + h2, h1 ~ hr + h2:first-of-type { break-before: auto; }

h3 { font-size: 12pt; margin: 16pt 0 6pt; break-after: avoid; }
h4 {
  font-size: 10.5pt;
  margin: 12pt 0 4pt;
  color: #495061;
  break-after: avoid;
}

p, li { orphans: 2; widows: 2; }
ul, ol { padding-left: 18pt; }
li { margin: 2pt 0; }

/* 표는 쪽 경계에서 잘리지 않게 한다. 근거 표가 두 쪽에 걸치면 읽기 어렵다. */
table {
  width: 100%;
  border-collapse: collapse;
  margin: 8pt 0 12pt;
  font-size: 9.5pt;
  break-inside: avoid;
}
th, td {
  border: 0.6pt solid #c8ccd4;
  padding: 5pt 7pt;
  text-align: left;
  vertical-align: top;
}
th { background: #eef0f4; font-weight: 600; }

code {
  font-family: Consolas, "D2Coding", monospace;
  font-size: 9pt;
  background: #eef0f4;
  padding: 1pt 3pt;
  border-radius: 2pt;
}

pre {
  background: #f6f7f9;
  border: 0.6pt solid #d8dce4;
  border-left: 2.5pt solid #4a5568;
  border-radius: 3pt;
  padding: 8pt 10pt;
  margin: 8pt 0 12pt;
  font-size: 8.8pt;
  line-height: 1.5;
  white-space: pre-wrap;   /* 긴 줄이 종이 밖으로 나가지 않도록 */
  word-break: break-all;
  break-inside: avoid;
}
pre code { background: none; padding: 0; font-size: inherit; }

blockquote {
  margin: 8pt 0;
  padding: 2pt 0 2pt 12pt;
  border-left: 2.5pt solid #c8ccd4;
  color: #495061;
}

hr { border: none; border-top: 0.6pt solid #d8dce4; margin: 16pt 0; }
a { color: #1b1d21; text-decoration: none; border-bottom: 0.5pt dotted #8a92a3; }
strong { font-weight: 600; }
"""

HTML_TEMPLATE = """<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<title>{title}</title>
<style>{css}</style>
</head>
<body>
{body}
</body>
</html>
"""


def find_browser() -> str:
    """PDF 인쇄에 쓸 Chrome 계열 브라우저 경로를 찾는다."""
    for path in BROWSER_CANDIDATES:
        if Path(path).exists():
            return path
    found = shutil.which("chrome") or shutil.which("msedge")
    if found:
        return found
    sys.exit("Chrome 또는 Edge 를 찾지 못했습니다. PDF 생성에는 둘 중 하나가 필요합니다.")


def render_html(source: Path) -> str:
    """마크다운 파일을 인쇄용 HTML 문자열로 변환한다."""
    text = source.read_text(encoding="utf-8")
    body = markdown.markdown(
        text,
        extensions=["tables", "fenced_code", "sane_lists", "attr_list"],
        output_format="html5",
    )
    # 문서 제목은 첫 번째 H1 을 쓴다. 없으면 파일명으로 대체한다.
    title = source.stem
    for line in text.splitlines():
        if line.startswith("# "):
            title = line[2:].strip()
            break
    return HTML_TEMPLATE.format(title=title, css=PRINT_CSS, body=body)


def print_to_pdf(browser: str, html_path: Path, pdf_path: Path) -> None:
    """헤들리스 브라우저로 HTML 을 PDF 로 인쇄한다.

    Chrome 의 --print-to-pdf 에 비ASCII 경로를 넘기면 인코딩 문제가 생길 수 있으므로
    임시 ASCII 경로로 출력한 뒤 최종 위치로 옮긴다. (출력 파일명이 한글이다)
    """
    with tempfile.TemporaryDirectory() as tmp:
        tmp_dir = Path(tmp)
        staged_pdf = tmp_dir / "out.pdf"
        cmd = [
            browser,
            "--headless=new",
            "--disable-gpu",
            # 이미 떠 있는 브라우저 프로필에 붙지 않도록 격리한다.
            f"--user-data-dir={tmp_dir / 'profile'}",
            "--run-all-compositor-stages-before-draw",
            "--virtual-time-budget=10000",
            # 기본 머리글/바닥글에는 file:// 로컬 경로가 찍힌다. 제출물에 남기지 않는다.
            "--no-pdf-header-footer",
            f"--print-to-pdf={staged_pdf}",
            html_path.as_uri(),
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if not staged_pdf.exists():
            sys.exit(
                "PDF 생성 실패 (exit={code})\n{err}".format(
                    code=result.returncode, err=result.stderr.strip()[:2000]
                )
            )
        pdf_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(staged_pdf), str(pdf_path))


def main(argv: list[str]) -> None:
    source = Path(argv[0]).resolve() if len(argv) >= 1 else DEFAULT_SOURCE
    output = Path(argv[1]).resolve() if len(argv) >= 2 else DEFAULT_OUTPUT

    if not source.exists():
        sys.exit(f"원본 문서를 찾을 수 없습니다: {source}")

    output.parent.mkdir(parents=True, exist_ok=True)
    html_path = output.parent / (source.stem + ".html")
    html_path.write_text(render_html(source), encoding="utf-8")

    print_to_pdf(find_browser(), html_path, output)

    size_kb = output.stat().st_size / 1024
    print(f"생성 완료: {output}  ({size_kb:.0f} KB)")
    print(f"중간 HTML: {html_path}")


if __name__ == "__main__":
    main(sys.argv[1:])
