# 구조

이 문서는 **"지금 무엇이 있는가"**를 기록한다.
코드를 어떻게 써야 하는지는 [conventions.md](conventions.md),
무엇을 만드는지는 [game-design.md](game-design.md) 참고.

현재는 부트 씬 하나뿐인 골격 상태다.

---

## 현재 구성

```
src/
├── autoload/
│   └── game_config.gd      # 전역 설정 · 실행 환경 판별
└── main/
    ├── main.tscn           # 부트 씬 (project.godot 의 main_scene)
    └── main.gd

test/unit/
└── test_game_config.gd     # GameConfig 단위 테스트

addons/gut/                 # GUT 9.7.1 (벤더링). 빌드에서 제외된다
web/shell.html              # 웹 빌드용 커스텀 HTML 셸
```

### `GameConfig` (오토로드)

`project.godot` 에 등록된 유일한 싱글톤이다. 노출하는 것은 세 가지뿐이다.

| 멤버 | 내용 |
| --- | --- |
| `title` | `application/config/name` |
| `version` | `application/config/version` |
| `is_web` | `OS.has_feature("web")` — 웹 전용 분기에 사용 |

**게임 상태(점수, 진행도 등)는 여기 넣지 않는다.**
여기 두는 것은 빌드 전체에서 변하지 않는 값과 실행 환경 판별뿐이다.
상태가 필요해지면 별도 오토로드나 씬 소유 상태로 분리한다.

### `main.tscn` / `main.gd`

지금은 **빌드가 실제로 구동되는지 확인하는 화면**이다.
브라우저에서 제목·버전·렌더러·플랫폼이 보이면 웹 빌드가 정상이라는 뜻이다.
배포 검증에 실제로 쓰이고 있다 ([web-build.md](web-build.md) 참고).

콘텐츠가 생기면 이 씬은 **진입점 역할만** 남긴다.
(어떤 씬을 띄울지 결정 → 해당 씬으로 전환) 플레이 로직을 여기에 쌓지 않는다.

---

## 아직 없는 것

`conventions.md` §1 에 정의된 아래 폴더는 **필요해질 때 만든다.**

| 폴더 | 들어갈 것 |
| --- | --- |
| `src/core/` | 노드에 의존하지 않는 순수 로직 (재사용 단위) |
| `src/entities/` | 플레이어, 적 등 게임 오브젝트 |
| `src/systems/` | 씬 전환, 저장, 오디오 |
| `src/ui/` | HUD, 메뉴 |
| `assets/` | 여러 기능이 공유하는 원본 에셋 |

---

## 렌더러

`gl_compatibility` (OpenGL ES 3.0 / WebGL 2) 로 고정돼 있다.

Forward+ / Mobile 렌더러는 Vulkan 기반이라 브라우저에서 동작하지 않는다.
웹 제출이 목표인 이상 이 설정은 바꾸지 않는다. 바꾸면 웹 빌드가 검은 화면이 된다.

---

## 구조 변경 이력

| 날짜 | 변경 | 사유 |
| --- | --- | --- |
| 2026-08-07 | `scenes/` + `scripts/` → `src/` 기능 단위 구조 | 타입별 분리는 기능 하나를 고칠 때 여러 폴더를 오가게 만든다. 근거는 [conventions.md](conventions.md) §1 |
| 2026-08-07 | GUT · gdtoolkit · 커스텀 웹 셸 · Release 워크플로 도입 | 콘텐츠가 붙기 전에 품질 게이트와 제출 파이프라인을 먼저 세웠다. 코드가 늘어난 뒤에는 도입 비용이 커진다 |
