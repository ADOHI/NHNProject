# 웹 빌드 & 배포

> ## ★ 2026-08-19 — **웹은 이제 부판이다**
>
> 본판은 **PC 스탠드얼론(Windows x86_64)** 이다. 웹은 **데모 배포·디버깅용으로 유지한다**
> ([`design/01-constraints.md`](design/01-constraints.md) §1.1).
>
> **그래서 이 문서의 설정은 전부 그대로 지킨다.** 웹을 안 깨뜨리는 것이 여전히 규칙이다 —
> 바뀐 것은 **웹이 더 이상 상한을 정하지 않는다**는 것뿐이다.
> 용량 때문에 에셋을 줄이는 판단은 이제 하지 않는다.
>
> ### PC 빌드
>
> ```bash
> godot --headless --path . --export-release "Windows Desktop" build/windows/Geum.exe
> ```
>
> 프리셋은 `export_presets.cfg` 의 `[preset.1]`. 산출물은 `Geum.exe` + `Geum.pck`
> (`embed_pck=false` — 갱신할 때 `.pck` 만 갈아 끼울 수 있다).
> **내보내기 경로의 폴더는 미리 만들어야 한다** — 없으면
> *"주어진 내보내기 경로는 존재하지 않습니다"* 로 실패한다.
>
> 실측(2026-08-19): `Geum.exe` 109 MB · `Geum.pck` 31.6 MB.
> 구동 확인 — `OpenGL API 3.3.0 Compatibility`, 오류 0, 종료 코드 0.

## 배포 흐름

`main` 푸시 → GitHub Actions(`.github/workflows/deploy-web.yml`) →
Godot 헤드리스 익스포트 → GitHub Pages.

워크플로는 도커 이미지가 아니라 **공식 릴리스를 직접 내려받는다.**
엔진을 올릴 때는 워크플로의 `env.GODOT_VERSION` 한 줄만 바꾸면 된다
(로컬 에디터 버전과 반드시 맞출 것 — 버전이 어긋나면 `.tscn` 포맷 경고가 난다).

## 왜 이렇게 설정했나

웹 빌드는 설정 하나만 틀려도 "빌드는 되는데 브라우저에서 안 돌아가는" 상태가 된다.
아래 항목은 임의로 바꾸지 말 것.

### `rendering_method = gl_compatibility`

브라우저에는 Vulkan 이 없다. Forward+ / Mobile 렌더러를 고르면
웹 빌드가 검은 화면으로 뜬다. WebGL 2 를 쓰는 호환성 렌더러만 동작한다.

### `variant/thread_support = false`

스레드를 켠 웹 빌드는 `SharedArrayBuffer` 를 요구하고, 그러려면 서버가
`Cross-Origin-Opener-Policy` / `Cross-Origin-Embedder-Policy` 헤더를 보내야 한다.

**GitHub Pages 는 이 헤더를 설정할 수 없다.** 정적 호스팅이라 응답 헤더를 못 건드린다.
그래서 스레드 없는 단일 스레드 빌드(`web_nothreads_*` 템플릿)를 쓴다.

익스포트 시 `web_nothreads_release.zip` 을 찾는다면 설정이 제대로 먹은 것이다.

### `html/custom_html_shell = res://web/shell.html`

Godot 기본 셸은 회색 배경에 진행 막대 하나가 전부다. 웹 제출에서는
**로딩 화면이 채점자가 처음 보는 화면**이므로 커스텀 셸로 교체했다.

기본 셸과 달라진 것은 표현뿐이다. 엔진 초기화 로직
(`Engine.getMissingFeatures` 검사, 서비스워커 재시도 경로, `engine.startGame`)은
공식 셸(`misc/dist/html/full-size.html`)과 동일하게 유지한다.
**이 부분은 손대지 말 것** — 브라우저 호환성 처리가 들어 있다.

셸이 제공하는 것:

- 프로젝트 제목과 진행률(%), 다운로드 용량(MB)
- 전체 용량을 모를 때(서버가 `Content-Length` 미제공)의 무한 진행 표시
- 지원되지 않는 브라우저일 때 한국어 안내
- 로딩 완료 시 페이드아웃

셸에는 `$GODOT_CONFIG`, `$GODOT_THREADS_ENABLED`, `$GODOT_URL`,
`$GODOT_PROJECT_NAME`, `$GODOT_HEAD_INCLUDE` 플레이스홀더가 반드시 있어야 한다.
익스포트 시 Godot 이 이 문자열을 치환한다. 하나라도 빠지면 빌드는 되지만 실행되지 않는다.

### `exclude_filter`

`export_filter="all_resources"` 라 **빼겠다고 적지 않은 것은 전부 실린다.**
웹 빌드는 다운로드 용량이 곧 이탈률이므로 게임에 쓰이지 않는 파일은 담지 않는다.

| 빼는 것 | 왜 |
| --- | --- |
| `test/*` · `addons/gut/*` | 테스트 코드와 GUT(약 3MB). 게임이 안 쓴다 |
| `assets/audio/sfx/*` | CC0 원본 녹음은 **굽는 재료**다. 게임이 싣는 것은 `assets/audio/sfx_baked/` (`docs/design/29-sound.md`) |
| `src/proto/*` | **버리려고 만든 프로토타입** — 이동 · 애니 조절판 · 조명 · 효과음 데모 |

`src/proto/*` 는 2026-08-19 에 더했다 (`docs/refactoring-2026-08-19.md` §5.2).
**파일을 지운 것이 아니라 내보내기에서만 뺀 것**이라 에디터와 헤드리스에서는 그대로
돌아야 한다 — `tools/capture_unit_move.gd` 같은 도구가 그 씬을 연다.

두 프리셋(Web · Windows Desktop)의 목록은 **같게 유지한다.** 한쪽에만 더하면
웹에서만 나거나 PC 에서만 나는 차이가 생기고, 그것이 제일 늦게 발견된다.

### `html/canvas_resize_policy = 2`

캔버스를 브라우저 창 크기에 맞춘다. 채점자가 어떤 화면에서 열든
잘리지 않도록 하기 위한 설정이며, `project.godot` 의
`window/stretch/mode = canvas_items` 와 짝을 이룬다.

## 제출물 만들기

`v` 로 시작하는 태그를 푸시하면 웹 빌드 zip 과 AI 활용 기술 문서 PDF 가
GitHub Release 에 자동 첨부된다.

```bash
git tag v0.1.0
git push origin v0.1.0
```

릴리스를 공개하지 않고 산출물만 확인하려면 Actions 탭에서 `Release` 워크플로를
수동 실행한다. 이 경우 Release 를 만들지 않고 워크플로 아티팩트로만 올라간다.

## 워크플로 구성

| 워크플로 | 언제 | 하는 일 |
| --- | --- | --- |
| `deploy-web.yml` | `main` 푸시 (문서·도구 변경 제외) | 웹 빌드 → GitHub Pages 배포 |
| `quality.yml` | `src/` `test/` 등 변경 | gdlint · gdformat · GUT 테스트 |
| `release.yml` | `v*` 태그 푸시 / 수동 | 웹 zip + 문서 PDF 패키징 |

엔진 설치는 세 워크플로가 `.github/actions/setup-godot` 합성 액션을 공유한다.
Godot 버전을 올릴 때는 각 워크플로의 `env.GODOT_VERSION` 을 맞춘다.

## 최초 1회 설정 (저장소 소유자)

Pages 소스를 **GitHub Actions** 로 지정해야 워크플로의 배포 단계가 통과한다.

`Settings` → `Pages` → `Build and deployment` → `Source: GitHub Actions`

CLI 로도 가능하다:

```bash
gh api -X POST repos/:owner/:repo/pages -f build_type=workflow
```

## 로컬에서 확인하기

익스포트 템플릿이 필요하다 (에디터 → `Editor` → `Manage Export Templates...`).
설치 후:

```bash
godot --headless --path . --export-release "Web" build/web/index.html
```

`file://` 로 열면 안 된다. 브라우저가 `.wasm`/`.pck` 를 CORS 로 막는다.
HTTP 로 서빙할 것:

```bash
python -m http.server 8060 --directory build/web
```

## 문제가 생기면

| 증상 | 원인 |
| --- | --- |
| 검은 화면, 콘솔에 WebGL 오류 | 렌더러가 `gl_compatibility` 가 아님 |
| `SharedArrayBuffer is not defined` | `thread_support` 가 켜져 있음 |
| 로딩 바에서 멈춤 | `.pck` 404 — 산출물 전체가 배포됐는지 확인 |
| CI 에서 `No export template found` | `GODOT_VERSION` 과 템플릿 버전 불일치 |
| 소리가 안 남 | 브라우저 정책상 첫 사용자 입력 전에는 오디오가 막힌다 (버그 아님) |
