extends Control
## 부트 씬 겸 진입점. 던전을 만들어 화면들에 나눠 주고, 생성•개발 모드를 조작한다.
##
## 아웃게임(주둔지)이 생기면 이 씬은 "어떤 씬을 띄울지 결정"만 하고 물러난다.
## 플레이 로직은 여기에 쌓지 않는다.

## 첫 판의 시드. 이후에는 생성 버튼이 새 시드를 뽑는다.
const FIRST_SEED := 1

const _SHEET_SHADER := preload("res://src/ui/style/shaders/press_sheet.gdshader")

var _seed := FIRST_SEED

## 지금 보고 있는 던전 성격 (DungeonCatalog 의 색인).
##
## 아웃게임에 성격을 고르는 화면이 아직 없다. 그래서 개발 화면에서는 **새 판을 찍을 때마다
## 차례로 돈다** — 다섯을 다 보려면 생성 버튼을 다섯 번 누르면 된다.
var _character := 0

## 지금 판의 설계도. 등급을 띄우려고 들고 있는다.
var _plan: DungeonBlueprint = null
var _debug_visible := false

## 보스까지의 두 길을 그리고 있는가.
##
## **새 판을 찍어도 꺼지지 않는다.** 두 길이 갈리는지는 여러 판을 연달아 봐야
## 판정되는데, 판마다 다시 켜야 하면 그 자체가 번거로움이 된다
## (docs/design/17-dungeon-generation.md §17.27.4).
var _routes_visible := false

var _sheet: ShaderMaterial

@onready var _background: ColorRect = %Background
@onready var _board: DungeonBoard = %DungeonBoard
@onready var _page: PressPage = %Page
@onready var _plate: PressPlate = %PressPlate
@onready var _overlay: DebugOverlay = %DebugOverlay
@onready var _debug_button: Button = %DebugButton
@onready var _routes_button: Button = %RoutesButton
@onready var _generate_button: Button = %GenerateButton
@onready var _size_slider: HSlider = %SizeSlider
@onready var _size_label: Label = %SizeLabel
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	# Theme 은 루트에 한 번만 물린다. 자식에게 그대로 흘러내린다.
	# 여기서 물리지 않으면 화면마다 색을 손으로 칠하게 되고, 그러면 규칙이 흩어진다.
	theme = UiTheme.get_theme()
	_build_sheet()

	_size_slider.min_value = SampleDungeons.SIZE_MIN
	_size_slider.max_value = SampleDungeons.SIZE_MAX
	_size_slider.value = 3

	_generate_button.pressed.connect(_generate_new)
	_debug_button.pressed.connect(_toggle_debug)
	_routes_button.pressed.connect(_toggle_routes)
	# 한 턴이 넘어갈 때마다 새 판을 찍는다. 전환 자체가 이 게임의 볼거리다.
	_board.player_acted.connect(_print_edition)
	_board.struck.connect(_plate.strike_at)
	for button in [_generate_button, _routes_button, _debug_button]:
		(button as Button).pressed.connect(_strike_from.bind(button))
	_size_slider.value_changed.connect(func(_value: float) -> void: _update_size_label())

	_build_run()
	# **판을 만든 뒤에 라벨을 쓴다.** 등급은 만들어진 판을 재서 나오므로(DungeonGrade),
	# 순서를 뒤집으면 **첫 판만 등급이 빈칸**이 된다 — 새 판을 한 번 찍어야 나타났다.
	_update_size_label()
	_apply_debug_state()
	_apply_routes_state()
	# 화면이 뜨는 것 자체가 **첫 판을 찍는 것**이다. 켜자마자 인쇄기가 한 번 지나간다.
	# 첫 프레임에 완성된 지면이 그냥 놓여 있으면, 이 화면이 인쇄물이라는 전제가
	# 글로만 남고 몸짓으로는 한 번도 나타나지 않는다.
	_print_edition.call_deferred(true)


## 지면을 깐다. 판의 이동•배율을 그대로 받아 잉크 얼룩이 지도와 함께 흐른다.
##
## 배경을 단색으로 두면 판을 끌어도 화면이 가만히 있어서 "지도를 움직인다"는 감각이 없다.
## 이건 장식이 아니라 공간 표현이다 — 판은 그림이 아니라 **책상 위의 큰 신문지**여야 한다.
func _build_sheet() -> void:
	_sheet = ShaderMaterial.new()
	_sheet.shader = _SHEET_SHADER
	_sheet.set_shader_parameter("paper_color", UiTokens.PAPER)
	_sheet.set_shader_parameter("shade_color", UiTokens.PAPER_SHADE)
	_background.material = _sheet
	_board.view_changed.connect(_on_view_changed)


func _on_view_changed(pan: Vector2, zoom: float) -> void:
	_sheet.set_shader_parameter("view_pan", pan)
	_sheet.set_shader_parameter("view_zoom", zoom)
	# 지면이 접힌 자리도 함께 흐른다. 접힘은 화면의 무늬가 아니라 종이의 성질이다.
	_plate.follow_view(pan, zoom)


## 누른 자리에서 파문이 퍼진다. 조작이 지면에 자국을 남긴다.
func _strike_from(button: Control) -> void:
	_plate.strike_at(button.global_position + button.size * 0.5)


## 새 판을 찍는다.
##
## 지면이 굵은 점 덩어리에서 왼쪽부터 자리를 잡고, 그 앞머리가 지나가는 순서대로
## 방 칸들이 하나씩 다시 찍힌다. 판을 새로 짠 것이면 종이를 한 번 찢고 시작한다.
func _print_edition(rip: bool = false) -> void:
	_plate.print_edition(rip)
	_board.reprint()
	_page.set_edition("제 %d 판" % _board.turn_number())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_toggle_debug()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_boss_routes"):
		_toggle_routes()
		get_viewport().set_input_as_handled()


## 새 시드로 판을 다시 만든다.
##
## 시드를 무작위로 뽑되 화면에 표시한다. 이상한 판이 나왔을 때
## 시드가 없으면 다시 볼 수 없다 (docs/design/17-dungeon-generation.md §17.7).
func _generate_new() -> void:
	_seed = randi() % 1000000
	# 성격도 함께 돈다. 다섯을 다 보려면 다섯 번 누른다 (_character 주석 참고).
	_character = DungeonCatalog.wrapped(_character + 1)
	_build_run()
	# 등급은 판을 만든 뒤에야 잴 수 있다. 순서를 바꾸면 직전 판의 등급이 뜬다.
	_update_size_label()
	# 판을 통째로 새로 짠 것이므로 종이를 찢고 다시 찍는다.
	_print_edition(true)


func _build_run() -> void:
	# 판은 여기서 만들어 화면 둘에 나눠 준다. 화면끼리 서로의 내부를 들여다보지 않는다.
	var run := SampleDungeons.create_run(_seed, int(_size_slider.value), _character)
	_plan = run.blueprint
	_board.setup(run, _seed)
	_overlay.bind(run, _seed)
	if not _board.player_acted.is_connected(_overlay.refresh):
		_board.player_acted.connect(_overlay.refresh)
	_status_label.text = _build_status_text()
	_board.redraw()
	_overlay.refresh()
	_page.set_edition("제 %d 판" % _board.turn_number())
	_page.set_folio(_build_folio_text())


func _update_size_label() -> void:
	var size := int(_size_slider.value)
	# 판을 걸어 보면서 등급이 맞는지 눈으로 확인할 수 있어야 한다 (§17.20).
	_size_label.text = (
		"%s   크기 %d (칸 %d개 안팎)%s"
		% [
			DungeonCatalog.name_of(_character),
			size,
			SampleDungeons.room_estimate(size),
			_grade_text(),
		]
	)


## 지금 판의 등급. 걸어 보면서 「복잡 3」이 정말 복잡한지 확인하라고 띄운다.
##
## 설계도를 여기서 들고 있는 이유는 화면의 내부를 들여다보지 않기 위해서다 —
## 판은 main 이 만들어 화면들에 나눠 주는 것이므로 여기가 원본이다.
func _grade_text() -> String:
	if _plan == null:
		return ""
	var grade := DungeonGrade.of(_plan)
	return (
		# 슬라이더는 **다음** 판의 크기를 정하고 등급은 **지금** 판의 것이다.
		# 둘이 섞이지 않게 「지금 판」이라고 못 박는다.
		"      지금 판 — 규모 %d/%d • 복잡 %d/%d • 험난 %d/%d"
		% [
			grade["scale"],
			DungeonGrade.SCALE_MAX,
			grade["complexity"],
			DungeonGrade.COMPLEXITY_MAX,
			grade["hardship"],
			DungeonGrade.HARDSHIP_MAX,
		]
	)


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
	_debug_button.text = "교정쇄 닫기 (F1)" if _debug_visible else "교정쇄 (F1)"


## 보스까지의 두 길을 켜고 끈다.
##
## 교정쇄와 따로 두는 이유는 **재는 것이 다르기** 때문이다. 교정쇄는 방 안의 값을 보고,
## 두 길은 판의 모양을 본다. 험난 등급이 화면에서 판정되는 자리가 여기다
## (docs/design/17-dungeon-generation.md §17.27).
func _toggle_routes() -> void:
	_routes_visible = not _routes_visible
	_apply_routes_state()


func _apply_routes_state() -> void:
	_board.show_boss_routes = _routes_visible
	_board.redraw()
	_routes_button.text = "두 길 닫기 (F2)" if _routes_visible else "두 길 (F2)"


## 지면 아래쪽 여백에 찍히는 한 줄. 신문의 쪽수 자리다.
func _build_folio_text() -> String:
	return "지하 실황 • 연출부 유출본 • 조판 %d • 이 지면은 송출되지 않는다" % _seed


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
