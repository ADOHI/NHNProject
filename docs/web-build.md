# 웹 빌드 & 배포

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

### `html/canvas_resize_policy = 2`

캔버스를 브라우저 창 크기에 맞춘다. 채점자가 어떤 화면에서 열든
잘리지 않도록 하기 위한 설정이며, `project.godot` 의
`window/stretch/mode = canvas_items` 와 짝을 이룬다.

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
