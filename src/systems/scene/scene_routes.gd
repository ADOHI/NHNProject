class_name SceneRoutes
extends RefCounted
## 화면 이름과 씬 경로의 장부. **`res://…tscn` 문자열이 사는 유일한 곳이다.**
##
## 화면이 경로를 직접 들고 있으면 씬을 옮길 때마다 부르는 쪽을 전부 고쳐야 하고,
## **안 고친 곳은 조용히 깨진다** — `change_scene_to_file` 은 없는 경로에 오류 한 줄만
## 찍고 넘어가므로 화면이 안 바뀔 뿐이다 (docs/design/34-systems.md §34.3.1).
##
## 노드를 모른다. 그래서 경로가 실제로 살아 있는지를 시험이 헤드리스로 확인할 수 있다.

## 갈 수 있는 화면. **순서가 곧 아래 표의 색인이다.**
enum Screen {
	TITLE,  ## 타이틀 — 부팅이 닿는 첫 화면
	BASE,  ## 주둔지 — 아웃게임 한 바퀴가 도는 곳
	DUNGEON,  ## 던전 — 판 · 피드 · 상태를 한 화면에서 본다
	SETTLEMENT,  ## 정산 — 한 판이 여기서 닫힌다. 자동 저장이 걸리는 자리
	HIDEOUT,  ## 아지트 조감 — 아이소 격자 위의 시설
	NPC_SHEET,  ## 인물 열람기 — 개발용
	BACKPACK,  ## 소지품 — 개발용
}

const _PATHS: Array[String] = [
	"res://src/ui/title/title_screen.tscn",
	"res://src/ui/base/base_screen.tscn",
	"res://src/ui/dungeon_board/dungeon_screen.tscn",
	"res://src/ui/settlement/settlement_screen.tscn",
	"res://src/ui/hideout/hideout_screen.tscn",
	"res://src/ui/npc_sheet/npc_sheet_screen.tscn",
	"res://src/ui/backpack/backpack_screen.tscn",
]

## 화면 이름. 개발 패널과 기록에 그대로 나간다 (docs/conventions.md §8).
const _LABELS: Array[String] = [
	"타이틀",
	"주둔지",
	"던전",
	"정산",
	"아지트",
	"인물 열람기",
	"소지품",
]


static func count() -> int:
	return _PATHS.size()


## 정의된 화면인가. **enum 밖의 정수를 받을 수 있으므로 먼저 묻는다** —
## 라우터는 신호와 저장된 값에서도 화면 번호를 받는다.
static func is_known(screen: int) -> bool:
	return screen >= 0 and screen < _PATHS.size()


## 이 화면의 씬 경로. 모르는 화면이면 빈 문자열이다.
static func path_of(screen: int) -> String:
	return _PATHS[screen] if is_known(screen) else ""


static func label(screen: int) -> String:
	return _LABELS[screen] if is_known(screen) else "모르는 화면"


## 이 경로가 가리키는 화면. 장부에 없으면 -1 이다.
##
## 부팅 직후처럼 **라우터를 거치지 않고 떠 있는 씬**이 어느 화면인지 되묻는 자리가 있다.
static func screen_at(path: String) -> int:
	return _PATHS.find(path)


## 정의된 모든 화면. 시험과 개발 패널이 순서대로 훑는다.
static func all() -> Array[int]:
	var screens: Array[int] = []
	for index in _PATHS.size():
		screens.append(index)
	return screens
