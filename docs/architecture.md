# 구조

이 문서는 **"지금 무엇이 있는가"**를 기록한다.
코드를 어떻게 써야 하는지는 [conventions.md](conventions.md),
무엇을 만드는지는 [game-design.md](game-design.md) 참고.

**판이 화면에 그려지고 클릭으로 이동한다.** 턴 페이즈와 NPC 는 아직 없다.

---

## 현재 구성

```
src/
├── autoload/
│   └── game_config.gd          # 전역 설정 · 실행 환경 판별
├── core/                       # 노드 비의존 순수 로직
│   ├── dungeon/
│   │   ├── actor.gd            # 던전 안의 행동 주체 (몬스터 · NPC · 스쿼드)
│   │   ├── room.gd             # 방 하나. 점유자와 위험도
│   │   ├── dungeon_graph.gd    # 방 연결 그래프 + 인접 위험도 조회
│   │   ├── dungeon_blueprint.gd  # 던전 설계도 (방 · 연결 · 화면 배치)
│   │   ├── dungeon_run.gd      # 진행 중인 잠입 한 판
│   │   └── sample_dungeons.gd  # 개발용 표본 던전
│   └── event/
│       ├── game_event.gd       # 사건 하나 (누가 · 어디서 · 무엇을 · 얼마나)
│       └── event_log.gd        # 사건의 시간순 기록
├── ui/
│   └── dungeon_board/
│       ├── dungeon_board.tscn  # 판 화면 (방 배치 · 연결선 · HUD)
│       ├── dungeon_board.gd
│       ├── room_node.tscn      # 방 하나의 위젯
│       └── room_node.gd
└── main/
    ├── main.tscn               # 부트 씬 (project.godot 의 main_scene)
    └── main.gd

assets/fonts/ui_font.tres       # 한글 표시용 SystemFont ⚠ 웹에서 동작 안 함
test/unit/                      # GUT 단위 테스트 6종
tools/capture_scene.gd          # 화면 캡처 검증 도구 (빌드에 포함되지 않음)
addons/gut/                     # GUT 9.7.1 (벤더링). 빌드에서 제외된다
web/shell.html                  # 웹 빌드용 커스텀 HTML 셸
```

### `src/core/dungeon/` — 판

기획의 [던전 · 공간 · 위험도](design/07-level-design.md)를 코드로 옮긴 것이다.

| 클래스 | 책임 |
| --- | --- |
| `Actor` | 전투력을 가진 행동 주체. 몬스터 · NPC 탐험가 · 플레이어 스쿼드 **공통** |
| `Room` | 방 하나. 누가 있는지와 그 합만 안다. 연결은 모른다 |
| `DungeonGraph` | 방 연결과 이동. **`adjacent_threat()` 가 이 게임의 심장** |

**`Actor` 를 종류별로 나누지 않은 것이 핵심 결정이다.**
방의 위험도는 몬스터든 탐험가든 플레이어든 같은 단위의 전투력 합이다
([07 §7.2.0](design/07-level-design.md)). 종류별로 클래스를 나누면 합산 로직이
갈라지고, 그 순간 판이 하나의 판이 아니게 된다.
`kind` 는 합산이 아니라 **행동 방식**(몬스터는 고정, 탐험가는 이동)만 가른다.

연결 정보를 `Room` 이 아니라 `DungeonGraph` 가 갖는 이유는, 방에 두면
양쪽 방을 동시에 고쳐야 해서 한쪽만 갱신되는 사고가 나기 때문이다.

### `src/core/event/` — 사건

**소비자가 둘이라서 착수 시점에 먼저 세웠다**
([16 §16.2](design/16-build-order.md)).

```
행동 페이즈 → EventLog ─┬→ 렉카 기사 생성 (인게임 피드 · 아웃게임 뉴스)
                        └→ 세계 갱신 (NPC 상태 반영)
```

나중에 만들면 턴 처리 코드를 다시 짜야 한다.

**로그에 담기는 값은 언제나 진실이다.** 기사의 과장은 생성 단계에서 일어나고,
그것도 `magnitude` 에만 적용된다 ([13 §13.3](design/13-information-design.md)).
로그에 과장을 섞으면 세계 갱신까지 오염되어 판 자체가 어긋난다.

### `src/ui/dungeon_board/` — 화면

**화면은 상태를 갖지 않는다.** `DungeonRun` 을 읽어 그리고, 클릭을 `DungeonRun` 에
넘기고, 다시 읽어 그린다. 게임 규칙은 전부 `src/core/` 에 있다 (conventions.md §3.1).

`DungeonBoard` 가 내리는 유일한 판단은 **무엇을 보여 줄지**다.
플레이어가 선 방에만 인접 위험도 합을 띄우고 나머지는 `?` 로 둔다.
이 판단이 위젯으로 흩어지면 "무엇이 보이는가"라는 규칙이 화면 곳곳에 퍼진다 —
이 게임에서 그 규칙은 재미 그 자체다.

좌표는 `DungeonGraph` 가 아니라 `DungeonBlueprint` 에 있다.
같은 판을 다르게 그릴 수는 있어도, 같은 판이 다르게 이어질 수는 없다.

### 한글 폰트 ⚠

`assets/fonts/ui_font.tres` 는 `SystemFont` 으로 시스템 한글 폰트를 빌려 쓴다.
**데스크톱 전용 임시 조치이며 웹 빌드에서는 동작하지 않는다.**
제출 전에 재배포 가능한 폰트를 임베드해야 한다
([09 §9.3.1](design/09-art-sound.md), [12](design/12-open-questions.md) Q35).

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
| `src/entities/` | 플레이어, 적 등 게임 오브젝트 |
| `src/systems/` | 씬 전환, 저장, 오디오 |
| `src/ui/` | HUD, 메뉴 |
| `assets/` | 여러 기능이 공유하는 원본 에셋 |

`src/core/` 에 아직 없는 것 (구현 순서는 [16](design/16-build-order.md)):
턴 진행(계획/행동 페이즈), 조우 절차, 렉카 기사 생성기, 스쿼드, 세계 갱신.

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
| 2026-08-07 | `src/core/dungeon/` · `src/core/event/` 신설 | 구현 0단계. 위험도 합산은 순수 함수라 씬 없이 검증되고, 이벤트 로그는 기사·세계갱신의 공통 입력이라 먼저 세워야 재작업이 없다 ([16 §16.2](design/16-build-order.md)) |
| 2026-08-07 | `src/ui/dungeon_board/` 신설, `main.tscn` 을 Node2D → Control 로 교체 | 구현 1단계. 이 게임의 화면은 판과 텍스트라 Control 트리가 맞다. 웹 검증용 상태 표시줄은 하단에 남겼다 |
| 2026-08-07 | 좌표를 `Room` 이 아니라 `DungeonBlueprint` 에 둠 | 좌표는 판의 규칙이 아니라 표현이다. 같은 판을 다르게 그릴 수는 있어도 같은 판이 다르게 이어질 수는 없다 |
