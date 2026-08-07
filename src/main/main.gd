extends Control
## 부트 씬 겸 진입점. 던전을 만들어 화면들에 나눠 주고, 생성·개발 모드를 조작한다.
##
## 아웃게임(주둔지)이 생기면 이 씬은 "어떤 씬을 띄울지 결정"만 하고 물러난다.
## 플레이 로직은 여기에 쌓지 않는다.

## 첫 판의 시드. 이후에는 생성 버튼이 새 시드를 뽑는다.
const FIRST_SEED := 1

const _BACKDROP_SHADER := preload("res://src/ui/style/shaders/facility_backdrop.gdshader")

var _seed := FIRST_SEED
var _debug_visible := false
var _backdrop: ShaderMaterial

@onready var _background: ColorRect = %Background
@onready var _board: DungeonBoard = %DungeonBoard
@onready var _overlay: DebugOverlay = %DebugOverlay
@onready var _debug_button: Button = %DebugButton
@onready var _generate_button: Button = %GenerateButton
@onready var _size_slider: HSlider = %SizeSlider
@onready var _size_label: Label = %SizeLabel
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	# Theme 은 루트에 한 번만 물린다. 자식에게 그대로 흘러내린다.
	# 여기서 물리지 않으면 화면마다 색을 손으로 칠하게 되고, 그러면 규칙이 흩어진다.
	theme = UiTheme.get_theme()
	_build_backdrop()

	_size_slider.min_value = SampleDungeons.SIZE_MIN
	_size_slider.max_value = SampleDungeons.SIZE_MAX
	_size_slider.value = 3

	_generate_button.pressed.connect(_generate_new)
	_debug_button.pressed.connect(_toggle_debug)
	_size_slider.value_changed.connect(func(_value: float) -> void: _update_size_label())

	_update_size_label()
	_build_run()
	_apply_debug_state()


## 시설 바닥을 깐다. 판의 이동·배율을 그대로 받아 격자가 지도와 함께 흐른다.
##
## 배경을 단색으로 두면 판을 끌어도 화면이 가만히 있어서 "지도를 움직인다"는 감각이 없다.
## 이건 장식이 아니라 공간 표현이다 — 판은 그림이 아니라 장소여야 한다.
func _build_backdrop() -> void:
	_backdrop = ShaderMaterial.new()
	_backdrop.shader = _BACKDROP_SHADER
	_backdrop.set_shader_parameter("floor_color", UiTokens.FLOOR)
	_backdrop.set_shader_parameter("seam_color", UiTokens.SEAM)
	_backdrop.set_shader_parameter("glow_color", UiTokens.SIGNAL)
	_backdrop.set_shader_parameter("sweep_period", UiTokens.TIME_DRIFT)
	_background.material = _backdrop
	_board.view_changed.connect(_on_view_changed)


func _on_view_changed(pan: Vector2, zoom: float) -> void:
	_backdrop.set_shader_parameter("view_pan", pan)
	_backdrop.set_shader_parameter("view_zoom", zoom)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_toggle_debug()
		get_viewport().set_input_as_handled()


## 새 시드로 판을 다시 만든다.
##
## 시드를 무작위로 뽑되 화면에 표시한다. 이상한 판이 나왔을 때
## 시드가 없으면 다시 볼 수 없다 (docs/design/17-dungeon-generation.md §17.7).
func _generate_new() -> void:
	_seed = randi() % 1000000
	_build_run()


func _build_run() -> void:
	# 판은 여기서 만들어 화면 둘에 나눠 준다. 화면끼리 서로의 내부를 들여다보지 않는다.
	var run := SampleDungeons.create_run(_seed, int(_size_slider.value))
	_board.setup(run, _seed)
	_overlay.bind(run, _seed)
	if not _board.player_acted.is_connected(_overlay.refresh):
		_board.player_acted.connect(_overlay.refresh)
	_status_label.text = _build_status_text()
	_board.redraw()
	_overlay.refresh()


func _update_size_label() -> void:
	var size := int(_size_slider.value)
	_size_label.text = "맵 크기 %d   (방 %d개 안팎)" % [size, SampleDungeons.room_estimate(size)]


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
		"%s v%s   •   Godot %s   •   %s   •   seed %d"
		% [
			GameConfig.title,
			GameConfig.version,
			Engine.get_version_info().string,
			"web" if GameConfig.is_web else OS.get_name(),
			_seed,
		]
	)
