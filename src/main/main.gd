extends Control
## 부트 씬 겸 진입점. 던전 한 판을 만들어 판 화면에 넘기고, 개발 모드를 토글한다.
##
## 아웃게임(주둔지)이 생기면 이 씬은 "어떤 씬을 띄울지 결정"만 하고 물러난다.
## 플레이 로직은 여기에 쌓지 않는다.

## 판을 고정하는 시드. 다른 판을 보려면 이 값을 바꾼다
## (docs/design/17-dungeon-generation.md §17.7).
const DUNGEON_SEED := 1

var _debug_visible := false

@onready var _board: DungeonBoard = %DungeonBoard
@onready var _overlay: DebugOverlay = %DebugOverlay
@onready var _debug_button: Button = %DebugButton
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	_status_label.text = _build_status_text()
	# 판은 여기서 만들어 화면 둘에 나눠 준다. 화면끼리 서로의 내부를 들여다보지 않는다.
	var run := SampleDungeons.create_run(DUNGEON_SEED)
	_board.setup(run)
	_overlay.bind(run, DUNGEON_SEED)
	_board.player_acted.connect(_overlay.refresh)
	_debug_button.pressed.connect(_toggle_debug)
	_apply_debug_state()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_toggle_debug()
		get_viewport().set_input_as_handled()


## 개발 모드를 켜고 끈다.
##
## 켜면 판의 숨김이 전부 걷히고 오른쪽에 정보 패널이 열린다.
## 플레이 화면만으로는 "생성기가 의도대로 모호함을 만들었는지" 알 수 없다.
func _toggle_debug() -> void:
	_debug_visible = not _debug_visible
	_apply_debug_state()


func _apply_debug_state() -> void:
	_overlay.visible = _debug_visible
	_board.reveal_everything = _debug_visible
	_board.redraw()
	_overlay.refresh()
	_debug_button.text = "개발 정보 닫기 (F1)" if _debug_visible else "개발 정보 (F1)"


## 화면 구석에 띄울 런타임 상태 문자열.
## 웹 빌드에서 "브라우저에서 실제로 뭐가 돌고 있는지"를 눈으로 확인하는 용도다.
func _build_status_text() -> String:
	return (
		"%s v%s   ·   Godot %s   ·   %s   ·   seed %d"
		% [
			GameConfig.title,
			GameConfig.version,
			Engine.get_version_info().string,
			"web" if GameConfig.is_web else OS.get_name(),
			DUNGEON_SEED,
		]
	)
