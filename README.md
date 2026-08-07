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
| `scenes/` | 씬(`.tscn`) |
| `scripts/` | GDScript. 씬과 1:1로 대응하는 스크립트 |
| `scripts/autoload/` | 자동 로드 싱글톤 |
| `docs/` | 설계·운영 문서 |
| `tools/` | 개발 보조 스크립트 (문서 PDF 빌드 등) |
| `.github/workflows/` | 웹 빌드 & Pages 배포 |

코드 배치 규칙은 [docs/architecture.md](docs/architecture.md) 참고.

## 문서

| 문서 | 내용 |
| --- | --- |
| [docs/architecture.md](docs/architecture.md) | 씬·스크립트·오토로드 배치 규칙 |
| [docs/web-build.md](docs/web-build.md) | 웹 빌드 설정 근거와 배포 절차 |
| [docs/ai-usage.md](docs/ai-usage.md) | **AI 활용 기술 문서** (제출물). 개발과 함께 갱신한다 |

AI 활용 기술 문서는 제출 시 PDF로 변환한다.

```bash
python tools/build_docs.py
```

결과물은 `docs/build/AI활용기술문서.pdf` 에 생성된다 (Git 추적 대상 아님).
