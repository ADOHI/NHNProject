# 개발 컨벤션

이 문서는 **"어떻게 쓰는가"**를 정한다.
지금 무엇이 있는지는 [architecture.md](architecture.md),
무엇을 만드는지는 [game-design.md](game-design.md) (기획 문서 지도) 참고.

---

## 1. 폴더 구조

```
NHNProject/
├── project.godot
├── export_presets.cfg
├── icon.svg
├── CLAUDE.md
├── README.md
├── addons/                 # 서드파티 플러그인 (Godot 이 요구하는 고정 이름)
├── assets/                 # 여러 기능이 공유하는 원본 에셋
│   ├── fonts/
│   ├── audio/
│   └── textures/
├── src/                    # 게임 코드와 씬
│   ├── autoload/           # 싱글톤 (project.godot 에 등록된 것만)
│   ├── core/               # 노드에 의존하지 않는 순수 로직 — 재사용의 핵심
│   ├── entities/           # 플레이어, 적, 발사체 등 게임 오브젝트
│   ├── systems/            # 씬 전환, 저장, 오디오 등 게임 전반 시스템
│   ├── ui/                 # HUD, 메뉴
│   └── main/               # 진입점
├── test/                   # 단위 테스트 (GUT). 빌드에 포함되지 않는다
│   └── unit/
├── web/                    # 웹 빌드용 커스텀 HTML 셸
├── docs/
│   └── design/             # 기획 본문 (항목별 분할). 지도는 docs/game-design.md
├── tools/                  # 개발 보조 스크립트 (게임에 포함되지 않음)
└── .github/
    ├── actions/            # 워크플로가 공유하는 합성 액션
    └── workflows/
```

> 위 폴더는 **필요할 때 만든다.** 빈 폴더를 미리 만들어 두지 않는다
> (Git 은 빈 폴더를 추적하지 않고, 안 쓰는 폴더는 구조를 읽기 어렵게 만든다).

### 왜 `scenes/` + `scripts/` 가 아니라 `src/` 인가

타입별로 나누는 `scenes/` + `scripts/` 구조는 파일이 늘어날수록
**하나의 기능을 고치려고 두 폴더를 오가야 한다.** `player.tscn` 은 `scenes/` 에,
`player.gd` 는 `scripts/` 에 있고, 전용 텍스처는 `assets/` 에 있는 식이다.

Godot 공식 문서도 타입이 아니라 **맥락(context) 단위로 묶을 것**을 권한다.
그래서 한 기능에 속한 씬·스크립트·전용 에셋은 같은 폴더에 둔다.

```
src/entities/player/
├── player.tscn
├── player.gd
├── player_stats.gd
└── player_sprite.png       # 이 기능에서만 쓰는 에셋
```

여러 기능이 공유하는 에셋만 최상위 `assets/` 로 올린다.
**판단 기준: 사용처가 둘 이상이면 `assets/`, 하나면 기능 폴더 안.**

---

## 2. 네이밍

| 대상 | 규칙 | 예 |
| --- | --- | --- |
| 폴더 · 파일 | `snake_case` | `src/entities/player/player_state.gd` |
| 씬 파일 | 루트 노드와 같은 이름의 `snake_case` | `main.tscn` (루트 노드 `Main`) |
| 노드 | `PascalCase` | `TitleLabel`, `AnimationPlayer` |
| 클래스 (`class_name`) | `PascalCase` | `class_name PlayerStats` |
| 변수 · 함수 | `snake_case` | `move_speed`, `apply_damage()` |
| 비공개 멤버 | `_` 접두사 | `_title_label`, `_build_status_text()` |
| 상수 · enum 값 | `SCREAMING_SNAKE_CASE` | `const MAX_HEALTH = 100` |
| 시그널 | 과거형 `snake_case` | `signal health_changed(value)` |
| 부울 | 상태를 읽히게 | `is_alive`, `has_key` (`flag` 금지) |

씬 파일과 그 스크립트는 **같은 이름**을 쓴다 (`player.tscn` ↔ `player.gd`).
어떤 스크립트가 어떤 씬을 움직이는지 찾을 필요가 없어진다.

---

## 3. 코드 작성 규칙

### 3.1 재사용 단위 분리

**노드 트리에 의존하지 않는 로직은 노드에 두지 않는다.**
`RefCounted` / `Resource` 를 상속한 순수 클래스로 만들어 `src/core/` 에 둔다.

```gdscript
# src/core/health.gd  — 노드가 아니다. 테스트도 쉽고 어디서든 쓸 수 있다.
class_name Health
extends RefCounted

signal depleted

var _current: int
var _max: int

func _init(max_value: int) -> void:
    _max = max_value
    _current = max_value

func apply_damage(amount: int) -> void:
    _current = maxi(0, _current - amount)
    if _current == 0:
        depleted.emit()
```

노드 스크립트는 **입력을 받아 순수 클래스에 넘기고, 결과를 노드에 반영하는 역할**만 한다.
이 경계를 지키면 같은 로직을 플레이어·적·파괴 가능한 오브젝트에 그대로 재사용할 수 있다.

### 3.2 데이터는 `Resource` 로

스탯·밸런싱 수치를 코드에 상수로 박지 않는다. `Resource` 로 정의하면
에디터에서 편집 가능한 `.tres` 파일이 되고, 같은 스크립트로 여러 변형을 만들 수 있다.

### 3.3 결합도

- 부모는 자식을 직접 참조해도 된다. **자식이 부모를 직접 참조하지 않는다.**
  자식은 시그널로 알리고, 부모가 판단한다. (Godot 의 "Call down, signal up")
- 다른 씬의 노드를 `get_node("../../Foo")` 로 찾지 않는다. 경로가 바뀌면 조용히 깨진다.
- 오토로드는 **늘리기 쉽고 줄이기 어렵다.** 추가 전에 순수 클래스로 될 일인지 먼저 본다.
  게임 전체에서 하나뿐이어야 하고 씬 전환에도 살아남아야 하는 것만 오토로드로 만든다.

### 3.4 정적 타입

모든 변수·인자·반환값에 타입을 명시한다. GDScript 는 정적 타입일 때 더 빠르고,
오타를 실행 전에 잡는다.

```gdscript
func apply_damage(amount: int) -> void:   # O
func apply_damage(amount):                # X
```

### 3.5 노드 참조

`@onready` + 고유 이름(`%Name`)을 쓴다. 노드를 옮겨도 경로가 깨지지 않는다.

```gdscript
@onready var _title_label: Label = %TitleLabel     # O
@onready var _title_label = $UI/Root/Layout/Title  # X — 구조 바꾸면 깨진다
```

### 3.6 스크립트 내부 순서

`class_name` → `extends` → 문서 주석 → 시그널 → enum → 상수 → `@export` →
공개 변수 → 비공개 변수 → `@onready` → `_init` → `_ready` → 그 외 `_` 콜백 →
공개 메서드 → 비공개 메서드.

---

## 4. 테스트

[GUT](https://github.com/bitwes/Gut) 9.7.1 을 `addons/gut/` 에 벤더링해 쓴다.
테스트는 `test/unit/` 에 두고 파일명은 `test_<대상>.gd` 로 한다.

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd
```

설정은 `.gutconfig.json` 에 있다. 테스트 위치를 옮기면 여기도 고친다.

### 무엇을 테스트하는가

**`src/core/` 의 순수 로직이 1순위다.** 노드 트리에 의존하지 않으므로
씬을 띄우지 않고 검증할 수 있고, 재사용 단위이기 때문에 회귀 비용도 가장 크다.

노드 스크립트는 테스트하기 어렵다. 어렵다면 그건 **로직이 노드에 붙어 있다는 신호**다
(§3.1). 테스트를 억지로 짜기 전에 로직을 `src/core/` 로 빼는 쪽을 먼저 검토한다.

오토로드에 의존하는 테스트는 쓰지 않는다. 스크립트를 직접 인스턴스화해서
클래스 자체를 검증한다 (`test/unit/test_game_config.gd` 참고).

### 리팩토링과 테스트

**구조를 바꾸기 전에 그 동작을 덮는 테스트가 있는지 먼저 본다.**
없으면 테스트를 먼저 쓰고, 그다음에 옮긴다. 이것이 "과감한 리팩토링"을
"기능 유지"와 양립시키는 유일한 방법이다.

---

## 5. 코드 품질 검사

[gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) 을 쓴다.
CI 가 매 푸시마다 검사하므로, 커밋 전에 로컬에서 돌려 두면 왕복이 줄어든다.

```bash
python -m pip install "gdtoolkit==4.*"

gdlint src test tools            # 네이밍·구조 규칙 위반 검사
gdformat src test tools          # 포맷 자동 정리
gdformat --check src test tools  # 고치지 않고 확인만 (CI 와 동일)
```

> 실행 파일이 잡히지 않으면 pip 의 스크립트 경로가 PATH 에 없는 것이다.
> 그 경로를 PATH 에 넣거나, 무관하게 동작하는 `python -m gdtoolkit.linter` /
> `python -m gdtoolkit.formatter` 형태를 쓴다.

> **로컬(Windows · Python 3.10)에서 `gdlint` 가 간헐적으로 크래시한다.**
> `TypeError: decoding to str` / `SystemError: bad argument to internal function` 등
> 파서 내부 오류로, 코드 문제가 아니다. **다시 실행하면 통과한다.**
> CI(Ubuntu · Python 3.12)에서는 재현되지 않는다.

`addons/` 는 서드파티이므로 검사 대상에서 제외한다 (`.gdlintrc`).
`tools/` 는 빌드에 포함되지 않지만 **우리가 쓰는 코드이므로 같은 기준으로 검사한다.**

설정은 `.gdlintrc` 에 있고, 명시하지 않은 항목은 gdtoolkit 기본값을 따른다.
기본값이 이미 §2 의 네이밍 규칙과 일치하므로 중복해서 적지 않는다.

---

## 6. 문서화 규칙

### 6.1 코드 주석

- 스크립트 상단에 `##` 문서 주석으로 **이 파일의 책임**을 적는다.
  에디터 도움말에 그대로 노출된다.
- 주석은 **"무엇을"이 아니라 "왜"**를 적는다.
  코드를 읽으면 아는 내용은 쓰지 않는다.

```gdscript
# X — 코드를 그대로 옮긴 주석
speed = 300  # 속도를 300으로 설정

# O — 판단 근거
speed = 300  # 웹 빌드 기준 60fps 에서 한 화면을 4초에 가로지르는 값
```

### 6.2 문서 갱신 시점

| 변경 | 갱신할 문서 |
| --- | --- |
| 게임 규칙·콘텐츠 결정 | `docs/design/` 의 해당 항목 문서 + `design/11-decisions.md` |
| 폴더 구조·컨벤션 변경 | `conventions.md` |
| 새 시스템·모듈 추가 | `architecture.md` + **개발 패널에 상태 노출** (§8) |
| 빌드·배포 설정 변경 | `web-build.md` |
| 모든 작업 세션 | `ai-usage.md` (§4 로그, §5 프롬프트) |

**코드와 문서는 같은 커밋에 넣는다.** 나눠서 올리면 문서는 반드시 뒤처진다.

---

## 7. 커밋

```
<타입>: <한 줄 요약>

<왜 이렇게 했는지. 무엇을 바꿨는지는 diff 가 말해 준다>
```

타입: `feat` `fix` `refactor` `docs` `ci` `chore`

리팩토링 커밋에는 **기능 유지를 어떻게 확인했는지** 적는다.

---

## 8. 개발 모드

**개발 빌드는 판의 상태를 최대한 드러낸다.**

이 게임은 정보를 숨기는 것이 곧 재미다(`design/13-information-design.md`).
그래서 플레이 화면만 보고는 **의도한 모호함인지 버그인지 구분할 수 없다.**
인접 합이 6 으로 보일 때, 그게 생성기가 잘 만든 판인지 배치가 깨진 판인지
플레이 화면에는 나타나지 않는다.

개발 모드는 그 구분을 위해 존재한다.

### 여는 법

| 방법 | |
| --- | --- |
| 키보드 | `F1` (InputMap 액션 `toggle_debug`) |
| 마우스 · 터치 | 우측 상단 **개발 정보** 버튼 |

버튼을 함께 둔 이유는 조작을 포인터 단독으로 가정하기 때문이다
(`design/04-controls.md` §4.1). 키만 두면 모바일 브라우저에서 열 수 없다.

### 보여 주는 것

| 구역 | 내용 |
| --- | --- |
| 판 위 | 모든 방의 **실제 위험도와 개체 수** (`숨김 해제`) |
| 요약 | 시드 · 턴 · 스쿼드 능력 · 현재 방 · 인접 합/개체/최댓값 |
| 판의 진실 | 방마다 고도 · 종류 · 실제 위험도 · 개체 수 · 필요 민첩 |
| 사건 기록 | 이벤트 로그 최근 항목 |

**시드를 항상 표시한다.** 이상한 판이 나왔을 때 시드가 없으면 다시 볼 수 없다
(`design/17-dungeon-generation.md` §17.7).

### 규칙

- **새 시스템을 만들면 그 상태를 개발 패널에 노출한다.**
  화면에 드러나지 않는 상태는 디버깅할 수 없고, 디버깅할 수 없는 상태는 반드시 틀린다.
- **사건은 로그로 남긴다.** 이벤트 로그는 개발 확인 수단이면서
  동시에 렉카 기사의 재료다(`design/08-ui-ux.md` §8.3). 둘은 같은 자료를 본다.
- 개발 패널이 열리면 **판이 가려지지 않도록** 배치 영역을 좁힌다.
  가리면 확인하려던 것을 못 본다.
- 개발 모드는 **플레이 로직에 영향을 주지 않는다.** 표시만 바꾼다.

### 제출 빌드에서의 처리

현재는 제출 빌드에도 포함된다. 배포본에서 직접 확인할 수단이 필요하기 때문이다.
제출 직전에 감출지는 그때 판단한다 (`design/12-open-questions.md`).
