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
│   │   ├── dungeon_graph.gd    # 방 연결 · 고도 통과 판정 · 인접 위험도 조회
│   │   ├── dungeon_blueprint.gd  # 던전 설계도 (방 · 고도 · 종류 · 연결 · 배치 산출)
│   │   ├── dungeon_generator.gd  # 절차 생성 (아래 generation/ 을 엮는다)
│   │   ├── generation/         # 생성 파이프라인 단계별
│   │   │   ├── poisson_disk_sampler.gd   # 자리 뿌리기 (블루 노이즈)
│   │   │   ├── delaunay_triangulation.gd # 평면 후보 간선 (Bowyer-Watson)
│   │   │   ├── proximity_graphs.gd       # RNG · 가브리엘 · MST 부분그래프
│   │   │   ├── dungeon_terrain.gd        # 고도를 지형으로 (거리 + 저주파 노이즈)
│   │   │   ├── dungeon_edge_selector.gd  # 간선 선택 (고도차 · 깊이 가중)
│   │   │   └── room_kind_planner.gd      # 방 종류 배정
│   │   ├── squad_stats.gd      # 대원 능력치를 스쿼드 하나로 접는 규칙
│   │   ├── dungeon_run.gd      # 진행 중인 잠입 한 판
│   │   └── sample_dungeons.gd  # 생성된 판에 존재를 배치해 조립
│   ├── event/
│   │   ├── game_event.gd       # 사건 하나 (누가 · 어디서 · 무엇을 · 얼마나)
│   │   └── event_log.gd        # 사건의 시간순 기록
│   ├── turn/
│   │   ├── turn_intent.gd      # 한 주체가 이번 턴에 하려는 일 (2단계 공유 어휘)
│   │   └── turn_phase.gd       # 계획 / 행동 두 국면
│   ├── rekka/                  # 렉카 게시글 - 사건을 언어 모델 입력으로
│   │   ├── rekka_prompt.gd     # 직렬화. 등급 변환. 중의어 배제
│   │   ├── rekka_context.gd    # **판 문맥 수집** - 방 상태 · 인접 · 이력 · 위상
│   │   └── rekka_post.gd       # 후처리 (허용 문자 · 괄호 · 숫자 · 반복 제거)
│   ├── gate/                   # 게이트 = 열린 문. 아웃게임 대상
│   │   ├── gate.gd             # 게이트 하나. 씨앗을 물고 던전을 만든다
│   │   ├── gate_rank.gd        # 등급 -> 크기 · 보상
│   │   ├── gate_disclosure.gd  # 정보 공개 수준 (소문 / 정찰 / 해부)
│   │   └── gate_board.gd       # 목록 생성. 원정 1회 = 목록 1회 갈림
│   └── guild/                  # 길드 아지트. `gate/` 를 알지만 `gate/` 는 여기를 모른다
│       ├── guild.gd            # 등급 · 자금 · 대원 · 아지트 진척
│       ├── guild_member.gd     # 대원. **`Actor` 가 아니다**
│       ├── squad.gd            # 대원 N -> `Actor` 하나 (14 §14.2)
│       ├── facility.gd         # 시설 셋 (공방 · 정보실 · 접선처)
│       ├── facility_assignment.gd  # 배치. **출전자는 안 센다**
│       ├── expedition.gd       # 편성 -> 진입 -> 결과 -> 정산
│       ├── guild_settlement.gd # 정산. 두 번 적용되지 않는다
│       └── guild_balance.gd    # **수치와 계산식이 전부 여기** 한 파일
├── proto/
│   └── unit_move/              # 이동 조작감 프로토타입 (본 게임과 독립 씬)
│       ├── unit_move_proto.tscn / .gd   # 진입점 · 입력 해석
│       ├── terrain_view.gd · field_view.gd · debug_draw.gd · tuning_panel.gd
│       └── core/               # 흐름장 · 대형 · 선택 · 부대. 노드 비의존
├── ui/
│   ├── kit/                    # **UI 원자 단위 실험.** 버튼과 팝업만. 방향 미정
│   │   ├── kit_showcase.tscn   # 견본 화면. 1/2/3 으로 조형 방향 전환
│   │   ├── kit_field.gd        # 세 방향을 갈아 끼우는 자리
│   │   ├── kit_terrain/facet/grain.gdshader   # 등고선 / 파편 / 알갱이
│   │   └── kit_button.gd · kit_popup.gd · kit_tokens.gd
│   ├── base/                   # 길드 아지트 화면. **도형만.** 조형은 kit 이 정한다
│   │   └── base_screen.tscn    # 기둥 셋 - 길드·시설 / 대원·편성 / 게이트·원정
│   ├── style/                  # 「호외」 시각 언어. **보류** - 반려되어 kit 으로 넘어감
│   ├── dungeon_board/
│   │   ├── dungeon_board.tscn  # 판 화면 (방 배치 · 연결선 · HUD)
│   │   ├── dungeon_board.gd
│   │   ├── room_node.tscn      # 방 하나의 위젯
│   │   └── room_node.gd
│   └── debug_overlay/
│       ├── debug_overlay.tscn  # 개발 정보 패널 (F1)
│       └── debug_overlay.gd
└── main/
    ├── main.tscn               # 부트 씬 (project.godot 의 main_scene)
    └── main.gd

assets/fonts/song_myung/        # SongMyung Regular (SIL OFL) + OFL.txt
test/unit/                      # GUT 단위 테스트 72개 파일 (현재 409개 통과)
test/support/segment_crossing.gd  # 선분 교차 판정. 생성기를 안 믿고 따로 검사한다
tools/capture_scene.gd          # 화면 캡처 검증 도구 (빌드에 포함되지 않음)
tools/capture_dungeon_maps.gd   # 여러 시드의 판을 한꺼번에 캡처
tools/capture_unit_move.gd      # 이동 프로토 캡처 + 성능 측정
tools/bench_dungeon_generation.gd  # 생성 소요 시간 실측
tools/check_glyphs.gd           # src/ 문자열이 폰트에 있는지 검사
tools/check_glyphs_text.gd      # 표본 .txt 도 같은 검사 (화면에 나갈 텍스트)
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

### 고도

방마다 정수 고도가 있고, **내려가기는 자유 · 올라가기는 상승폭 ≤ 민첩**이다
([07 §7.2.6](design/07-level-design.md)). 이 값 하나가 세 가지를 맡는다.

| 쓰임 | 위치 |
| --- | --- |
| 이동 가능 판정 | `DungeonGraph.can_traverse()` |
| 방 등급 (필요 민첩) | `DungeonGraph.required_agility_from()` — bottleneck path |

**고도는 화면 배치에 쓰지 않는다.** 탑뷰라 높이는 평면 위치와 무관하다.
숫자로만 보여 주고, 시각화는 나중에 측면뷰가 맡는다
([11 번복 기록](design/11-decisions.md)).

민첩 검사를 `move_actor()` 안에 둔 이유는, 호출자에게 맡기면
빠뜨린 경로가 하나만 생겨도 판의 규칙이 깨지기 때문이다.

### 배치

`DungeonBlueprint.layout()` 이 **연결 관계만으로** 좌표를 만든다 —
흩뿌리고, 밀고 당기기를 반복하고, 겹친 것을 떼어 낸다
([17 §17.6](design/17-dungeon-generation.md)).

좌표를 저장하지 않고 매번 만들어 내는 이유는 그것이 판의 규칙이 아니라 표현이기 때문이다.
같은 시드는 같은 배치를 만든다.

판은 화면보다 커도 된다. `DungeonBoard` 가 이동(끌기)과 확대(휠)를 맡고,
**배율이 낮아지면 읽히지 않을 글자를 지운다** ([07 §7.8](design/07-level-design.md)).

### 생성기

`DungeonGenerator` 는 **척추를 먼저 보장하고 살을 붙인다**
([17 §17.3](design/17-dungeon-generation.md)). 무작위로 잇고 나서 도달성을 검사하면
대부분 실패해 재시도가 폭증한다.

검증은 규칙마다 함수로 나눠 두었다. 실패한 규칙을 특정할 수 있어야 하고,
규칙이 늘어날 때 한 함수가 계속 길어지지 않아야 한다.

**생성은 시드를 받는다.** 전역 난수를 쓰면 재현성이 깨지므로
`RandomNumberGenerator` 인스턴스를 들고 다닌다.

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

### `src/ui/debug_overlay/` — 개발 정보

**숨김을 전부 걷어낸 화면.** 이 게임은 정보를 숨기는 것이 곧 재미라
(design/13), 플레이 화면만으로는 **의도한 모호함인지 버그인지 구분할 수 없다.**

`F1` 또는 우측 상단 버튼으로 연다. 규칙과 갱신 의무는
[conventions.md §8](conventions.md) 에 있다 —
**새 시스템을 만들면 그 상태를 이 패널에 노출한다.**

판과 패널은 서로의 내부를 들여다보지 않는다.
`main.gd` 가 `DungeonRun` 을 만들어 둘에게 나눠 주고,
판은 `player_acted` 시그널로 알린다.

### 한글 폰트

`assets/fonts/song_myung/SongMyung-Regular.ttf` (SIL OFL, 2.03 MB)를
`project.godot` 의 `gui/theme/custom_font` 로 지정했다.
Godot 기본 폰트에는 한글 글리프가 없어 그대로 두면 UI 가 전부 두부(□)가 된다.

**임베드 폰트라 웹에서도 동작한다.** `OFL.txt` 는 재배포 조건이라 함께 둔다.
서브셋 여부는 UI 문구가 확정된 뒤 판단한다 ([09 §9.3.2](design/09-art-sound.md)).

첫 임포트에서 `Error loading custom project font` 가 출력되지만
**1회차에만** 발생한다(폰트 데이터 생성 전에 테마가 로드된다). 2회차 0건, exit code 0.
배포 워크플로는 export 전에 별도 import 패스를 돌리므로 영향이 없다.

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
