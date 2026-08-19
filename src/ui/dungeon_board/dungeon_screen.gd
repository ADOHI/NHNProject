class_name DungeonScreen
extends Control
## 던전 화면. 판을 만들어 화면들에 나눠 주고, 생성•개발 모드를 조작한다.
##
## **예전에는 이것이 `main.tscn` 이었다.** 진입점에 플레이 로직을 쌓지 않기로 한
## docs/architecture.md 의 약속대로 제 씬으로 내려왔다 —
## 이제 `main` 은 어떤 화면을 띄울지 고르고 물러난다
## (docs/design/34-systems.md §34.5).
##
## **옮긴 것이지 고친 것이 아니다.** 아래 로직은 이름만 바뀌었다.
##
## 혼자 띄워도 그대로 돈다.
##
##     godot --path . res://src/ui/dungeon_board/dungeon_screen.tscn

## 주둔지에서 넘어올 때 받는 값의 열쇠 (docs/design/34-systems.md §34.3.4).
##
## **받는 쪽이 계약을 든다.** 보내는 화면이 저마다 문자열을 적으면 오타 하나가
## 조용히 기본 판을 띄우고, 그것은 화면만 봐서는 구분되지 않는다.
const ENTRY_SEED := "dungeon_seed"
const ENTRY_SIZE := "dungeon_size"
const ENTRY_CHARACTER := "dungeon_character"
const ENTRY_GATE_NAME := "gate_name"

## 진짜 원정을 업고 왔는가는 `SettlementScreen.ENTRY_EXPEDITION` 하나로 안다.
##
## **나머지 값은 읽지 않는다. 들고 있다가 정산 화면에 그대로 넘긴다**
## (docs/design/36-settlement.md §36.5.1) — 씨앗 · 저장 자리는 이 화면의 관심사가 아니다.

## 첫 판의 시드. 이후에는 생성 버튼이 새 시드를 뽑는다.
const FIRST_SEED := 1

const _SHEET_SHADER := preload("res://src/ui/style/shaders/press_sheet.gdshader")

## 조작 막대가 아래에서 차지하는 높이. 피드가 그 위를 덮으면 버튼을 못 누른다.
const _CONTROL_BAR_HEIGHT := 132.0

var _seed := FIRST_SEED

## 어느 게이트로 들어왔나. 넘어온 값이 없으면 빈 문자열이고, 그러면 지면에 안 찍힌다.
var _gate_name := ""

## 지금 보고 있는 던전 성격 (DungeonCatalog 의 색인).
##
## 아웃게임에 성격을 고르는 화면이 아직 없다. 그래서 개발 화면에서는 **새 판을 찍을 때마다
## 차례로 돈다** — 다섯을 다 보려면 생성 버튼을 다섯 번 누르면 된다.
var _character := 0

## 지금 판의 설계도. 등급을 띄우려고 들고 있는다.
var _plan: DungeonBlueprint = null

## 지금 판. 화면들에 나눠 준 것과 같은 것을 여기서도 들고 있는다 —
## 사건을 피드에 넘기려면 로그를 읽을 수 있어야 한다.
var _run: DungeonRun = null

## 이 판의 렉카 피드. **판마다 새로 만든다** — 접두어와 닉네임 고리가 다시 섞여야 한다.
var _feed: RekkaFeed = null

## 지금 업고 있는 원정. 없으면 이 화면은 예전처럼 **판을 구경하는 화면**이다.
##
## 업고 있으면 두 가지가 달라진다 — 판을 새로 못 찍고(원정이 든 판과 갈린다),
## 나가는 문이 **중도 회수**가 된다 (§36.5.3).
var _expedition: Expedition = null

## 정산 화면에 그대로 넘길 값. 받은 그대로 두고 기사만 얹는다.
var _entry: Dictionary = {}
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
@onready var _feed_view: RekkaFeedView = %Feed
@onready var _overlay: DebugOverlay = %DebugOverlay
@onready var _back_button: Button = %BackButton
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

	_take_entry()
	_generate_button.pressed.connect(_generate_new)
	_back_button.pressed.connect(_go_back)
	_debug_button.pressed.connect(_toggle_debug)
	_routes_button.pressed.connect(_toggle_routes)
	# 한 턴이 넘어갈 때마다 새 판을 찍는다. 전환 자체가 이 게임의 볼거리다.
	_board.player_acted.connect(_print_edition)
	_board.struck.connect(_plate.strike_at)
	_board.struck.connect(_sound_on_strike)
	# 행동이 끝나면 그 턴이 기사가 된다. 계획 페이즈에 읽으라고 만든 장치다 (08 8.1).
	_board.player_acted.connect(_publish_turn)
	# **탈출은 즉시가 아니다** (05 5.9). 탈출구에서 버티는 것은 판이 세고, 다 버티면
	# `DungeonRun.finished` 가 선다. 정산은 그 신호를 듣는 것이지 스스로 판정하지 않는다.
	_board.player_acted.connect(_check_finish)
	# **판과 피드는 서로의 내부를 들여다보지 않는다.** 여기서 한 줄로 잇는다 (32 32.5.3).
	_feed_view.room_selected.connect(_board.highlight_room)
	resized.connect(_layout_feed)
	for button in [_generate_button, _routes_button, _debug_button, _back_button]:
		(button as Button).pressed.connect(_strike_from.bind(button))
		(button as Button).pressed.connect(_sound_on_press)
	_size_slider.value_changed.connect(func(_value: float) -> void: _update_size_label())

	_build_run()
	_layout_feed()
	# **판을 만든 뒤에 라벨을 쓴다.** 등급은 만들어진 판을 재서 나오므로(DungeonGrade),
	# 순서를 뒤집으면 **첫 판만 등급이 빈칸**이 된다 — 새 판을 한 번 찍어야 나타났다.
	_update_size_label()
	_apply_debug_state()
	_apply_routes_state()
	_apply_expedition_state()
	# 혼자 띄웠으면 돌아갈 곳이 없다. **눌러도 아무 일이 없는 버튼을 두지 않는다.**
	# 원정을 업고 있으면 돌아갈 곳과 무관하게 나가는 문이 있어야 한다 — 그것이 회수다.
	_back_button.visible = _expedition != null or Router.can_go_back()
	# 화면이 뜨는 것 자체가 **첫 판을 찍는 것**이다. 켜자마자 인쇄기가 한 번 지나간다.
	# 첫 프레임에 완성된 지면이 그냥 놓여 있으면, 이 화면이 인쇄물이라는 전제가
	# 글로만 남고 몸짓으로는 한 번도 나타나지 않는다.
	_print_edition.call_deferred(true)


## 주둔지에서 넘어온 게이트를 판으로 옮긴다.
##
## **넘어온 값이 없으면 아무것도 안 바꾼다** — 이 씬을 혼자 띄웠을 때
## 지금까지와 똑같이 도는 것이 이 함수의 유일한 조건이다.
func _take_entry() -> void:
	_entry = Router.take_payload()
	if _entry.is_empty():
		return
	_seed = int(_entry.get(ENTRY_SEED, _seed))
	_character = DungeonCatalog.wrapped(int(_entry.get(ENTRY_CHARACTER, _character)))
	_gate_name = String(_entry.get(ENTRY_GATE_NAME, ""))
	if _entry.has(ENTRY_SIZE):
		_size_slider.value = clampi(
			int(_entry[ENTRY_SIZE]), SampleDungeons.SIZE_MIN, SampleDungeons.SIZE_MAX
		)
	_expedition = _entry.get(SettlementScreen.ENTRY_EXPEDITION) as Expedition


## 나가는 문. **원정을 업고 있으면 그냥 못 돌아간다** (docs/design/36-settlement.md §36.5.3).
##
## 익스트랙션에서 한 판을 무를 수 있으면 손실 규칙이 통째로 무너진다.
## 그래서 원정이 걸려 있을 때 이 단추는 **중도 회수**이고, 정산을 거쳐 나간다.
## 업은 것이 없으면 예전 그대로 — 라우터가 지나온 길을 안다.
func _go_back() -> void:
	if _expedition != null:
		_finish_expedition(ExpeditionReport.Outcome.RECALLED)
		return
	Router.back()


## 원정을 끝내고 정산 화면으로 넘긴다. **결말이 이 화면으로 들어오는 유일한 문이다.**
##
## 전투 판정이 붙으면(docs/design/05-rules.md §5.5 — 미정) 여기를
## `DOWNED` 로 부르면 된다. 정산 쪽에는 분기가 없다 — 보고서가 성패를 알고
## `GuildBalance` 가 값을 정한다 (§36.5.4).
func _finish_expedition(outcome: ExpeditionReport.Outcome) -> void:
	if _expedition == null:
		return
	var going := _expedition
	# **먼저 비운다.** 정산으로 넘어가는 사이에 이 화면이 한 번 더 이 함수를 부르면
	# 같은 원정이 두 번 결말을 낸다 — 전환은 프레임 끝에 일어나므로 그 틈이 실제로 있다.
	_expedition = null
	going.finish(outcome)
	var payload := _entry.duplicate()
	payload[SettlementScreen.ENTRY_FEED] = _feed
	Router.go_to(SceneRoutes.Screen.SETTLEMENT, payload)


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
	# **원정 중에는 판을 못 바꾼다.** 바꾸면 원정이 든 판과 화면의 판이 갈리고,
	# 그때 나온 턴 수가 전리품이 된다 — 조용히 틀린 값이 정산에 들어간다.
	if _expedition != null:
		return
	_seed = randi() % 1000000
	# 성격도 함께 돈다. 다섯을 다 보려면 다섯 번 누른다 (_character 주석 참고).
	_character = DungeonCatalog.wrapped(_character + 1)
	_build_run()
	# 등급은 판을 만든 뒤에야 잴 수 있다. 순서를 바꾸면 직전 판의 등급이 뜬다.
	_update_size_label()
	# 판을 통째로 새로 짠 것이므로 종이를 찢고 다시 찍는다.
	_print_edition(true)


func _build_run() -> void:
	# 판은 여기서 만들어 화면 셋에 나눠 준다. 화면끼리 서로의 내부를 들여다보지 않는다.
	#
	# **원정을 업고 왔으면 그 판을 물려받는다.** 같은 생성기 · 같은 씨앗이라 그림은
	# 똑같지만(Gate.create_run), 판을 하나 더 만들면 화면이 세는 턴과 정산이 읽는 턴이
	# 갈린다 — 그 턴 수가 전리품이 되므로(GuildBalance.loot_for) 조용히 틀린 값이 된다.
	var run := _expedition.run if _expedition != null else null
	if run == null:
		run = SampleDungeons.create_run(_seed, int(_size_slider.value), _character)
	_plan = run.blueprint
	_run = run
	# 소금으로 시드를 준다. 판이 바뀌면 접두어와 닉네임 배열도 바뀌어야 한다
	# (docs/design/19-rekka-voice.md 19.B.9 2차).
	_feed = RekkaFeed.new(_seed)
	_feed_view.bind(_feed)
	# **판이 시작하자마자 한 편이 걸린다.** 사건이 없는 턴에도 기사는 나가고
	# (32 32.1), 빈 목록은 이 장치가 무엇인지 설명하지 못한다.
	_feed.record_turn(run, [] as Array[GameEvent])
	_board.setup(run, _seed)
	_overlay.bind(run, _seed)
	if not _board.player_acted.is_connected(_overlay.refresh):
		_board.player_acted.connect(_overlay.refresh)
	_status_label.text = _build_status_text()
	_board.redraw()
	_overlay.refresh()
	_page.set_edition("제 %d 판" % _board.turn_number())
	_page.set_folio(_build_folio_text())


## 방금 끝난 턴을 기사로 낸다.
##
## **직전 턴의 사건을 읽는다.** `DungeonRun.move_player()` 는 사건을 기록한 뒤에
## 턴을 올리므로, 지금 `turn` 은 이미 다음 턴을 가리킨다. 그대로 읽으면 빈 턴이 나간다.
func _publish_turn() -> void:
	if _run == null or _feed == null:
		return
	_feed.record_turn(_run, _run.event_log.events_in_turn(_run.turn - 1))


## 피드를 화면 어디에 둘 것인가.
##
## 08-ui-ux.md 8.2 — **판 · 피드 · 상태를 한 화면에서 본다. 탭으로 나누지 않는다.**
## 매 턴 판단이 이 셋의 대조에서 나오기 때문이다.
## 세로 화면(모바일)에서는 옆에 세울 자리가 없으므로 **판 위에 피드를 쌓는다.**
func _layout_feed() -> void:
	if _feed_view == null:
		return
	var margin := float(UiTokens.SPACE_GAP)
	if size.x >= size.y:
		var width := clampf(size.x * 0.30, 300.0, 460.0)
		_feed_view.position = Vector2(size.x - width - margin, margin)
		_feed_view.size = Vector2(width, size.y - margin * 2.0 - _CONTROL_BAR_HEIGHT)
		return
	var height := size.y * 0.42
	_feed_view.position = Vector2(margin, size.y - height - margin)
	_feed_view.size = Vector2(size.x - margin * 2.0, height - _CONTROL_BAR_HEIGHT)


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


## 원정을 업고 있을 때 달라지는 것들.
##
## 판을 새로 못 찍는 이유는 `_generate_new()` 에 적었다. **잠근 단추를 그냥 두지 않고
## 끈다** — 눌리는데 아무 일도 안 일어나는 것이 가장 나쁘다.
func _apply_expedition_state() -> void:
	if _expedition == null:
		return
	_back_button.text = "원정을 접는다"
	_generate_button.disabled = true
	_size_slider.editable = false


## 판이 끝났는가. 끝났으면 정산으로 넘어간다.
##
## **끝나는 길이 둘이다.** 탈출해서 나가거나(§5.9), 조우에서 제압당하거나
## (docs/design/35-encounter.md §35.2.3). 둘 다 `DungeonRun.finished` 를 세우므로
## 여기서 갈라야 한다 — 안 가르면 **털리고 나온 판이 탈출 성공으로 정산된다.**
##
## 이 자리는 정산 레인이 비워 두고 간 것이다 —
## *"전투 판정이 붙으면 여기를 `DOWNED` 로 부르면 된다"* (§36).
func _check_finish() -> void:
	if _expedition == null or _run == null or not _run.finished:
		return
	_finish_expedition(ExpeditionReport.outcome_for(_run.defeated))


## 지면 아래쪽 여백에 찍히는 한 줄. 신문의 쪽수 자리다.
func _build_folio_text() -> String:
	var gate := "" if _gate_name.is_empty() else "%s • " % _gate_name
	return "지하 실황 • 연출부 유출본 • %s조판 %d • 이 지면은 송출되지 않는다" % [gate, _seed]


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


## 판이 울릴 때 소리를 낸다.
##
## **소리 층을 부르는 것은 화면이지 로직이 아니다.** `DungeonBoard` 도 `DungeonRun` 도
## `Sfx` 를 모른다 — 순수 로직이 오토로드에 의존하면 헤드리스 테스트가 깨진다
## (docs/conventions.md §3.1). 신호를 듣는 쪽에서 한 줄로 잇는다.
##
## 붙이는 자리 목록은 docs/design/29-sound.md §29.3.11 에 있다.
func _sound_on_strike(_at: Vector2) -> void:
	Sfx.play(SfxEvent.Kind.BOARD_STRUCK)


func _sound_on_press() -> void:
	Sfx.play(SfxEvent.Kind.UI_PRESS)
