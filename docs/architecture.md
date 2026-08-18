# 구조

이 문서는 **"지금 무엇이 있는가"**를 기록한다.
코드를 어떻게 써야 하는지는 [conventions.md](conventions.md),
무엇을 만드는지는 [game-design.md](game-design.md) 참고.

**판이 화면에 그려지고 클릭으로 이동한다. 아지트에서 게이트를 골라 원정을 돌리고 정산까지 온다.**
그 위에 **세계 3000명**(인구·가족·사건·유명세), **레이맨 절차 애니메이션**,
**전투 시험대**(백팩 격자·체이닝·대련), **효과음**, **아지트 아이소 격자**,
**UI 킷**이 각각 서 있다.

> **아직 안 이어진 자리가 이 문서에서 가장 중요하다.**
> **턴 페이즈 해결기가 없다** — `TurnIntent`·`TurnPhase` 라는 어휘만 서 있다.
> 위 여섯은 각자 돌아가지만 **한 판 안에서 서로를 부르지 않는다.**
> 그것이 [16](design/16-build-order.md) §16.4 의 2단계이고, 남은 것 중 가장 위험하다.

### 2026-08-18 통합 — 레인 열을 접었다

`char-anim` · `dungeon-gen` · `npc-relations` · `sound` · `hideout` · `lighting-2d` ·
`portraits` · `combat` · `ui-kit-2` · `test-stability`. 테스트 **623 → 1717**.

**git 이 깨끗하다고 답한 자리에서 의미 충돌이 둘 나왔다** — 두 레인이 같은 함수의
같은 자리에 서로 다른 인자를 밀어 넣었는데 diff 가 안 겹쳤다. 경위는
[`integration-2026-08-18.md`](integration-2026-08-18.md).

> **이 기계는 무작위로 프로세스를 죽인다** (하드웨어 결함 — [`test-stability.md`](test-stability.md)).
> 검증은 `tools/run_gut_retry.py` · `tools/run_lint_retry.py` 로 돌린다.

---

## 현재 구성

```
src/
├── autoload/game_config.gd     # 전역 설정 · 실행 환경 판별 (유일한 싱글톤)
├── core/                       # 노드 비의존 순수 로직. 전부 RefCounted
│   ├── dungeon/                # 판 — 방 · 위험도 · 고도 · 절차 생성
│   │   └── generation/         # 생성 파이프라인 (샘플링 → 삼각분할 → 간선 → 지형 → 구역 → 종류)
│   ├── event/                  # 사건 하나와 그 기록. **소비자가 둘이라 먼저 세웠다**
│   ├── turn/                   # ⚠ 어휘만 있다 — `TurnIntent` · `TurnPhase`. 해결기가 없다
│   ├── gate/                   # 게이트 = 열린 문. 아웃게임 대상
│   ├── guild/                  # 길드 아지트 — 대원 · 스쿼드 · 시설 · 원정 · 정산 · 수치표
│   ├── npc/                    # **세계 3000명** — 인구 생성 · 가족 · 관계 · 사건 · 유명세 · 인물 상세
│   ├── combat/                 # 전투 시험대 — 백팩 격자 · 체이닝 · 브레이크 · 대련
│   ├── char_anim/              # **레이맨 절차 애니메이션** — 파츠 여섯, 클립 아홉
│   ├── hideout/                # 아지트 아이소 격자 — 건물 · 배치 · 배회
│   ├── nav/                    # 흐름장 · 격자. 이동 프로토에서 끌어올렸다
│   ├── sfx/                    # 효과음 — 사건 → 층 쌓기 → 합성
│   ├── rekka/                  # 렉카 게시글 — 사건을 언어 모델 입력으로
│   ├── ui/                     # **UI 를 그리는 규칙**(픽셀 아님) — 배치 · 조형 · 팔레트
│   │   └── motion/             # 동작 곡선 다섯 (잔상 · 정지 · 전단 · 내리침 · 눌림)
│   └── text/korean_josa.gd     # 조사 처리
├── entities/character/         # 리그를 노드로 세우는 층. 자리표시자 도형 ↔ 진짜 그림
├── systems/audio/              # 소리를 실제로 내는 층 (`core/sfx/` 는 무엇을 낼지만 정한다)
├── ui/
│   ├── dungeon_board/          # 판 화면
│   ├── base/                   # 길드 아지트 화면
│   ├── hideout/                # 아지트 아이소 화면
│   ├── backpack/               # 백팩 격자 화면
│   ├── npc_sheet/              # 인물 상세 열람기 (개발용 — 전부 보인다)
│   ├── kit/                    # UI 킷 — 조형 실험과 견본 화면들
│   ├── style/                  # 「호외」 시각 언어 (보류 — kit 이 대체)
│   ├── title/                  # 타이틀
│   └── debug_overlay/          # 개발 정보 패널 (F1)
├── proto/                      # **본 게임과 독립된 씬.** 조작감·기법을 재는 자리
│   ├── unit_move/              # 이동 조작감
│   ├── char_anim/              # 애니메이션 조절판
│   ├── lighting/               # 2D 조명 조사
│   └── sfx/                    # 효과음 데모
└── main/                       # 부트 씬 (진입점)

assets/fonts/song_myung/        # SongMyung Regular (SIL OFL) — 한글 글리프
assets/audio/sfx/               # CC0 녹음물 65개 + CREDITS.md
test/unit/                      # GUT 단위 테스트 (현재 149 스크립트 / 1717 통과)
test/support/                   # 생성기를 안 믿고 따로 검사하는 자들
tools/                          # 전부 빌드에 포함되지 않는다
  capture_*.gd                  # 화면 캡처 (창을 한 번 띄워 여러 장을 몰아 뽑는다)
  check_glyphs*.gd              # 폰트에 없는 글자를 잡는다 — 없으면 두부(□)가 된다
  run_gut_retry.py              # ⚠ 이 기계 전용 — 폭사에만 재시도하는 테스트 러너
  run_lint_retry.py             # ⚠ 이 기계 전용 — 파일 하나씩 린트하고 폭사만 재시도
  build_docs.py · verify_pdf.py # 제출용 PDF
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

> `conventions.md` §1 이 「필요해질 때 만든다」고 적어 둔 폴더 넷은 **전부 생겼다** —
> `src/entities/` · `src/systems/` · `src/ui/` · `assets/`. 그 표는 이제 지웠다.

### 🔴 이어 붙는 자리가 없다 — 지금 가장 큰 구멍

부품은 많은데 **한 판이 안 돈다.** [16](design/16-build-order.md) §16.4 의 2단계다.

| 없는 것 | 없으면 | 어디에 |
| --- | --- | --- |
| **턴 페이즈 해결기** | 계획/행동이 안 갈리고 동시 해결이 없다. **이 게임이 아니게 된다**(M2) | `src/core/turn/` 에 어휘만 |
| **NPC 탐험가의 판 위 행동** | 위험도가 안 변한다 → 추리할 것이 없다(M4) | 세계는 있는데 판에 안 들어온다 |
| **조우 절차** (전투/협상/도주 분기) | NPC 가 장애물로 전락한다(M5) | `core/combat/` 은 시험대뿐 |
| **렉카 피드 화면** | 개성이 사라지고 정보원을 하나 잃는다(M6) | 입력층만 있고 화면이 없다 |

**넷 다 §16.8 의 「절대 자르지 않는 여섯」에 든다.**

### 서로 안 부르는 부품들

각자는 도는데 아직 한 판 안에서 안 만난다.

| 부품 | 지금 도는 곳 | 안 이어진 자리 |
| --- | --- | --- |
| `core/char_anim/` | `proto/char_anim/` 조절판 | 판·전투 화면에 안 선다 |
| `core/combat/` | 대련 시험대 | 조우 절차가 없어 판에서 안 불린다 |
| `core/sfx/` | `proto/sfx/` 데모 · 호출부 2개 | 사건 대부분이 소리를 안 낸다 |
| `core/npc/` | 인물 상세 열람기(개발용) | 던전 판에 NPC 로 안 들어간다 |
| `core/hideout/` | 아지트 화면 | 길드 진행과 안 묶였다 |

### 그 밖에 아직 없는 것

세계 갱신(던전 1회 = 세계 1틱은 `NpcWorld.tick()` 이 있으나 호출부가 없다),
영입, 스쿼드 편성 화면, 저장.

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
| 2026-08-18 | **레인 열을 접었다** — `char-anim`·`dungeon-gen`·`npc-relations`·`sound`·`hideout`·`lighting-2d`·`portraits`·`combat`·`ui-kit-2`·`test-stability` | 병렬로 갈라 둔 것이 main 에 없으면 서로를 못 부른다. 테스트 623 → 1717. 경위는 [integration-2026-08-18.md](integration-2026-08-18.md) |
| 2026-08-18 | `src/core/nav/` 신설 (이동 프로토에서 끌어올림) | 흐름장·격자를 아지트가 같이 쓴다. 프로토 안에 두면 본 게임이 프로토에 의존한다 |
| 2026-08-18 | `src/core/ui/` 신설 — **UI 를 그리는 규칙을 픽셀에서 떼어냈다** | 배치·조형·팔레트가 순수 함수라 씬 없이 검증된다. 노드가 들고 있으면 화면을 띄워야만 검사가 된다 |
| 2026-08-18 | `docs/HANDOFF.md` → `docs/handoff/<레인>.md` | 레인 여덟이 같은 파일명을 써서 병합 때마다 충돌했고, 이긴 하나 말고는 전부 사라졌다 |
| 2026-08-18 | `tools/run_gut_retry.py` · `tools/run_lint_retry.py` 도입 | **이 개발 기계가 무작위로 프로세스를 죽인다**(하드웨어 — [test-stability.md](test-stability.md)). 긴 실행 하나를 짧은 실행 여럿으로 쪼갠다. CI 는 멀쩡한 러너라 날것 그대로 둔다 |
