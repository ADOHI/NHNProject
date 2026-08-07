# NHNProject

Godot 4.7.1 기반 2D 게임 프로젝트. **웹(HTML5) 빌드로 제출**하는 것을 전제로 구성돼 있다.

`main` 브랜치에 푸시하면 GitHub Actions 가 웹 빌드를 만들어 GitHub Pages 로 배포한다.

## 요구 사항

- [Godot 4.7.1](https://godotengine.org/download) (표준 빌드, C# 아님)
- 로컬에서 웹 빌드를 직접 뽑으려면 익스포트 템플릿 필요
  (에디터 → `Editor` → `Manage Export Templates...` → `Download and Install`)
  단순히 게임을 실행/개발만 한다면 템플릿은 없어도 된다.

## 실행

에디터로 열기:

```bash
godot --path . --editor
```

에디터 없이 바로 실행:

```bash
godot --path .
```

## 테스트 · 품질 검사

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd
```

```bash
pip install "gdtoolkit==4.*" && gdlint src test && gdformat --check src test
```

둘 다 `main` 푸시 시 CI(`quality.yml`)가 동일하게 검사한다.

## 웹 빌드

로컬에서 뽑기 (익스포트 템플릿 설치 후):

```bash
godot --headless --path . --export-release "Web" build/web/index.html
```

`build/` 는 `.gitignore` 대상이다. 배포본은 커밋하지 않고 CI 가 만든다.

빌드 결과는 `file://` 로 열면 동작하지 않는다. 반드시 HTTP 로 서빙해야 한다:

```bash
python -m http.server 8060 --directory build/web
```

자세한 내용과 제약은 [docs/web-build.md](docs/web-build.md) 참고.

## 구조

| 경로 | 역할 |
| --- | --- |
| `src/` | 게임 코드와 씬. 기능 단위로 묶는다 |
| `src/autoload/` | 자동 로드 싱글톤 |
| `src/main/` | 진입점 씬 |
| `assets/` | 여러 기능이 공유하는 원본 에셋 |
| `test/` | 단위 테스트 (GUT). 빌드에 포함되지 않는다 |
| `addons/` | 서드파티 애드온 (GUT) |
| `web/` | 웹 빌드용 커스텀 HTML 셸 |
| `docs/` | 기획·설계·운영 문서 |
| `tools/` | 개발 보조 스크립트 (문서 PDF 빌드 등) |
| `.github/workflows/` | 웹 배포 · 품질 검사 · 제출물 패키징 |

씬·스크립트·전용 에셋은 같은 기능 폴더에 함께 둔다.
자세한 규칙은 [docs/conventions.md](docs/conventions.md) 참고.

## 문서

| 문서 | 내용 |
| --- | --- |
| [docs/game-design.md](docs/game-design.md) | 기획 문서 지도 — 어떤 내용이 어느 파일에 있는가 |
| [docs/design/](docs/design/) | 기획 본문 — 무엇을 만드는가 (항목별 분할) |
| [docs/conventions.md](docs/conventions.md) | 개발 컨벤션 — 폴더 구조, 네이밍, 코드 규칙 |
| [docs/architecture.md](docs/architecture.md) | 구조 — 지금 무엇이 있는가 |
| [docs/web-build.md](docs/web-build.md) | 웹 빌드 설정 근거와 배포 절차 |
| [docs/ai-usage.md](docs/ai-usage.md) | **AI 활용 기술 문서** (제출물). 개발과 함께 갱신한다 |

AI 활용 기술 문서는 제출 시 PDF로 변환한다.

```bash
python tools/build_docs.py
```

결과물은 `docs/build/AI활용기술문서.pdf` 에 생성된다 (Git 추적 대상 아님).

## 서드파티 에셋

| 에셋 | 출처 | 라이선스 |
| --- | --- | --- |
| SongMyung Regular | [Google Fonts](https://fonts.google.com/specimen/Song+Myung) | SIL Open Font License 1.1 — `assets/fonts/song_myung/OFL.txt` |
| GUT 9.7.1 | [bitwes/Gut](https://github.com/bitwes/Gut) | MIT — `addons/gut/` (테스트 전용, 빌드에서 제외) |
