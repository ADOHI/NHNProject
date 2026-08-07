# NHNProject 작업 지침

Godot 4.7.1 기반 2D 게임. **웹(HTML5) 빌드로 제출**한다.

## 개발 원칙

1. **기획/개발 문서화를 코드와 함께 한다.**
   기능을 추가하면 같은 커밋에서 관련 문서를 갱신한다. 코드만 올리고 문서는 나중에, 는 없다.
2. **재사용성을 최대한 고려한다.**
   노드 트리에 의존하지 않는 로직은 `src/core/` 의 순수 클래스로 분리한다.
   특정 씬에서만 쓰이는 코드라도, 두 번째 사용처가 생길 여지가 보이면 미리 분리한다.
3. **폴더·파일 구조는 보편적 컨벤션을 따른다.** → `docs/conventions.md`
4. **리팩토링은 과감하게 하되, 기능 유지를 반드시 검증한다.**
   구조가 잘못됐다고 판단되면 미루지 말고 고친다.
   단 리팩토링 커밋은 반드시 실행 검증(아래)을 거친다. "고쳤는데 안 돌아간다"는 허용되지 않는다.
5. **개선안은 제안하고 허가받은 뒤 착수한다.**
   최신 기법, 미래에 필요할 구조, 완성도를 높일 요소는 **적극적으로 제안한다.**
   제안하지 않고 넘어가는 것도 위반이고, 승인 없이 임의로 넣는 것도 위반이다.

## 검증 규칙

코드 변경 후 아래를 통과해야 커밋한다. 코드 리뷰만으로 채택하지 않는다.

```bash
godot --headless --path . --import                          # 임포트 오류 없음
godot --headless --path . --quit-after 60                   # 런타임 오류 없음
godot --headless --path . -s res://addons/gut/gut_cmdln.gd  # 테스트 통과
gdlint src test && gdformat --check src test                # 컨벤션 통과
```

마지막 두 줄은 CI 가 `quality.yml` 에서 똑같이 검사한다. 로컬에서 먼저 돌리면 왕복이 준다.

구조를 옮기는 변경(파일 이동/이름 변경)은 `.godot/` 캐시를 지우고 검증한다.
캐시가 깨진 경로를 가려 준다.

웹 빌드에 영향이 갈 수 있는 변경은 푸시 후 GitHub Actions 결과와 배포본까지 확인한다.

## 절대 바꾸지 말 것

웹 제출 조건에서 나온 설정이다. 바꾸면 빌드는 성공하지만 브라우저에서 실행되지 않는다.
근거는 `docs/web-build.md` 에 있다.

| 설정 | 값 |
| --- | --- |
| `rendering/renderer/rendering_method` | `gl_compatibility` (브라우저에 Vulkan 없음) |
| `variant/thread_support` (Web 프리셋) | `false` (GitHub Pages 는 COOP/COEP 헤더 불가) |

## AI 활용 기록

`docs/ai-usage.md` 는 제출물이다. 작업 세션이 끝날 때마다
§4 작업 로그와 §5 프롬프트 전문을 갱신한다. 프롬프트는 원문 그대로 남긴다.

PDF 변환:

```bash
python tools/build_docs.py
```

## 문서 지도

| 문서 | 내용 |
| --- | --- |
| `docs/game-design.md` | 기획 문서 지도 — 어떤 내용이 어느 파일에 있는가 |
| `docs/design/*.md` | 기획 본문 — 무엇을 만드는가 (항목별 분할) |
| `docs/conventions.md` | 개발 컨벤션 — 어떻게 쓰는가 |
| `docs/architecture.md` | 구조 — 지금 무엇이 있는가 |
| `docs/web-build.md` | 웹 빌드·배포 |
| `docs/ai-usage.md` | AI 활용 기술 문서 (제출물) |
