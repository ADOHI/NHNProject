"""생성된 PDF 에 한글 폰트가 실제로 임베드됐는지 검사한다.

사용법:
    python tools/verify_pdf.py <파일.pdf>

왜 필요한가:
    한글 폰트가 없는 환경에서도 PDF 생성 자체는 성공한다. 다만 모든 한글이
    두부(□)로 렌더링된다. 텍스트 추출도 정상적으로 되기 때문에
    "생성 성공"이나 "텍스트 추출 성공"으로는 이 실패를 잡을 수 없다.
    임베드된 폰트 목록을 직접 확인해야 한다.

    Linux CI 에서는 fonts-noto-cjk 를, Windows 로컬에서는 맑은 고딕을 쓴다.

구현 메모:
    폰트 딕셔너리의 위치는 PDF 생성기마다 다르다. 페이지 리소스에 직접 있기도 하고,
    Form XObject 안에 중첩되거나 부모 페이지 트리에서 상속되기도 한다.
    그래서 특정 경로를 가정하지 않고 객체 그래프 전체를 훑는다.
"""

from __future__ import annotations

import sys
from pathlib import Path

from console_utf8 import fix_console_encoding

try:
    import pypdf
    from pypdf.generic import IndirectObject
except ImportError:
    sys.exit("pypdf 패키지가 필요합니다:  python -m pip install pypdf")


# 한글 글리프를 가진 폰트로 인정할 이름 조각. 대소문자를 구분하지 않고 부분 일치시킨다.
KOREAN_FONT_MARKERS = (
    "cjk",       # Noto Sans CJK KR 등 (Linux)
    "malgun",    # 맑은 고딕 (Windows)
    "nanum",     # 나눔 계열
    "gulim",     # 굴림 (코드블록 폴백)
    "batang",    # 바탕
    "dotum",     # 돋움
    "applesdgothic",
    "notosanskr",
    "notoserifkr",
    "pretendard",
)


def collect_fonts(pdf_path: Path) -> set[str]:
    """PDF 객체 그래프 전체를 훑어 폰트 이름을 모은다."""
    reader = pypdf.PdfReader(str(pdf_path))
    found: set[str] = set()
    visited: set[int] = set()

    def walk(node: object) -> None:
        if isinstance(node, IndirectObject):
            # 순환 참조(/Parent 등)를 막기 위해 객체 번호로 방문 여부를 판단한다.
            if node.idnum in visited:
                return
            visited.add(node.idnum)
            walk(node.get_object())
            return

        if isinstance(node, dict):
            for key in ("/BaseFont", "/FontName"):
                value = node.get(key)
                if value is not None:
                    found.add(str(value))
            for value in node.values():
                walk(value)
            return

        if isinstance(node, (list, tuple)):
            for value in node:
                walk(value)

    for page in reader.pages:
        walk(page)

    return found


def has_korean_font(fonts: set[str]) -> bool:
    normalized = [f.lower().replace("-", "").replace("_", "").replace(" ", "") for f in fonts]
    return any(marker in name for name in normalized for marker in KOREAN_FONT_MARKERS)


def main(argv: list[str]) -> None:
    # 지금은 줄표(U+2014) 가 없어 cp949 콘솔에서 안 죽지만, 이 도구도 한국어를
    # 그대로 콘솔에 찍는다. `tools/console_utf8.py` 를 똑같이 걸어 둔다 (§26.14).
    fix_console_encoding()
    if len(argv) != 1:
        sys.exit("사용법: python tools/verify_pdf.py <파일.pdf>")

    pdf_path = Path(argv[0])
    if not pdf_path.exists():
        sys.exit(f"파일을 찾을 수 없습니다: {pdf_path}")

    reader = pypdf.PdfReader(str(pdf_path))
    fonts = collect_fonts(pdf_path)

    print(f"파일   : {pdf_path}  ({pdf_path.stat().st_size / 1024:.0f} KB)")
    print(f"쪽 수  : {len(reader.pages)}")
    print(f"폰트   : {sorted(fonts) if fonts else '(없음)'}")

    if not fonts:
        sys.exit("실패: PDF 에서 폰트를 하나도 찾지 못했습니다. 문서가 비어 있을 수 있습니다.")

    if not has_korean_font(fonts):
        sys.exit(
            "실패: 한글 폰트가 임베드되지 않았습니다. "
            "이 PDF 의 한글은 두부(□)로 보입니다.\n"
            "Linux 라면 fonts-noto-cjk 설치 여부를 확인하세요."
        )

    print("통과: 한글 폰트가 임베드돼 있습니다.")


if __name__ == "__main__":
    main(sys.argv[1:])
