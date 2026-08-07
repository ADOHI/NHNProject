extends Control
## 시각 언어를 한 지면에 늘어놓은 **견본쇄**.
##
## 스타일 가이드는 문서로만 두면 반드시 코드와 어긋난다.
## 이 화면은 **가이드의 실행본**이다 — 토큰을 고치면 여기가 먼저 달라지고,
## 달라지지 않으면 그 토큰은 아무 데도 쓰이지 않는다는 뜻이다.
##
## 이후 작업자는 새 위젯을 만들기 전에 이 화면을 먼저 본다.
## 여기 있는 형태를 조합하면 대개 새로 그릴 것이 없다.
##
##     godot --path . -s res://tools/capture_scene.gd -- showcase.png showcase

const RoomNodeScene := preload("res://src/ui/dungeon_board/room_node.tscn")
const _SHEET_SHADER := preload("res://src/ui/style/shaders/press_sheet.gdshader")

## 판 견본. **역할이 아니라 어느 판으로 찍히는가**로 묶는다.
## 이 화면에서 색은 장식이 아니라 "이 정보를 믿어도 되는가"의 표시다.
const _SWATCH_GROUPS := [
	["먹판 — 사실", [["먹", UiTokens.INK], ["중간", UiTokens.INK_MUTED], ["희미", UiTokens.INK_FAINT]]],
	["별색판 — 과장", [["별색", UiTokens.SPOT], ["짙게", UiTokens.SPOT_DEEP]]],
	["겹쳐찍기 — 물리적 금지", [["사선", UiTokens.MARK], ["짙게", UiTokens.MARK_DEEP]]],
	["종이", [["지면", UiTokens.PAPER_HIGH], ["바탕", UiTokens.PAPER], ["그늘", UiTokens.PAPER_SHADE]]],
]

const _TYPE_SAMPLES := [
	[UiTheme.DECK, "54  제호"],
	[UiTheme.HEAD, "34  기사 제목"],
	[UiTheme.SUB, "22  지금 어디인가"],
	["Label", "16  본문"],
	[UiTheme.CAPTION, "13  사진 설명"],
	[UiTheme.MICRO, "11  안 읽어도 되는 말"],
]

## 서명 시연 — 어긋난 크기가 곧 부풀린 크기다.
const _SLIP_SAMPLES := [
	[UiTokens.SLIP_TRUE, "18", "잰 값"],
	[UiTokens.SLIP_STORY, "18", "옮긴 말"],
	[UiTokens.SLIP_SHOUT, "18", "제목"],
]

const _SWATCH := Vector2(64.0, 30.0)
const _SWATCH_TOP := 168.0
const _SHAPE_TOP := 262.0

var _font: Font
var _tiles: Array[RoomNode] = []
var _slips: Array[PlateLabel] = []
var _random := RandomNumberGenerator.new()

@onready var _background: ColorRect = %Background
@onready var _page: PressPage = %Page
@onready var _gallery: Control = %Gallery
@onready var _tile_row: HBoxContainer = %Tiles
@onready var _panel_row: HBoxContainer = %Panels
@onready var _type_column: VBoxContainer = %TypeColumn
@onready var _slip_row: HBoxContainer = %SlipRow
@onready var _reroll_button: Button = %RerollButton
@onready var _plate: PressPlate = %PressPlate


func _ready() -> void:
	theme = UiTheme.get_theme()
	_font = UiTheme.project_font()
	_random.seed = 7
	_build_sheet()
	_page.set_edition("견 본")
	_page.set_folio("이 지면이 규칙의 실행본이다 — docs/design/18-visual-identity.md")
	_build_tiles()
	_build_panels()
	_build_type_column()
	_build_slip_row()
	_gallery.draw.connect(_draw_gallery)
	_reroll_button.pressed.connect(_reroll)


func _build_sheet() -> void:
	var material := ShaderMaterial.new()
	material.shader = _SHEET_SHADER
	material.set_shader_parameter("paper_color", UiTokens.PAPER)
	material.set_shader_parameter("shade_color", UiTokens.PAPER_SHADE)
	_background.material = material


## 방 타일 네 상태를 나란히 둔다. **이 화면의 핵심**이다 —
## "지금 있는 곳 / 갈 수 있는 곳 / 보이지만 못 가는 곳 / 먼 곳"이
## 한눈에 구분되지 않으면 판은 읽히지 않는다.
func _build_tiles() -> void:
	var rows := [
		["r_current", "관제실", "9", RoomNode.State.CURRENT, ""],
		["r_reach", "화물 리프트", "?", RoomNode.State.REACHABLE, "내림 1"],
		["r_block", "봉인된 금고", "?", RoomNode.State.BLOCKED, "오름 4"],
		["r_far", "제단", "?", RoomNode.State.DISTANT, "고도 7"],
	]
	for row in rows:
		var tile: RoomNode = RoomNodeScene.instantiate()
		_tile_row.add_child(tile)
		_tiles.append(tile)
		tile.display(row[0], row[1], row[2], row[3], row[4], RoomNode.Detail.FULL)


## 판 세 종류. 어느 판으로 찍힌 것인지가 **읽기 전에** 보여야 한다.
func _build_panels() -> void:
	_panel_row.add_child(
		_make_panel(
			PressPanel.Plate.FACT, "먹판", "시설이 잰 값이다. 괘선에 갇혀 축에 반듯하고,\n귀퉁이에 판 맞춤표가 있다. 두 판이 정확히 겹친다."
		)
	)
	_panel_row.add_child(
		_make_panel(
			PressPanel.Plate.STORY,
			"별색판",
			"렉카가 오려 붙인 조각이다. 가장자리가 찢겨 있고\n지면에서 기울어 있다. 장소와 종류는 사실이지만 규모는 부풀려져 있다."
		)
	)
	_panel_row.add_child(
		_make_panel(
			PressPanel.Plate.PROOF,
			"교정쇄",
			"아직 인쇄기에 안 걸린 지면이다. 별색이 하나도 없다.\n여백의 눈금 말고는 아무 표시도 두지 않는다."
		)
	)


func _make_panel(plate: PressPanel.Plate, title: String, body: String) -> PressPanel:
	var panel := PressPanel.new()
	panel.plate = plate
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", UiTokens.SPACE_SNUG)
	margin.add_child(rows)
	var heading := Label.new()
	heading.theme_type_variation = (
		UiTheme.SPOT_HEAD if plate == PressPanel.Plate.STORY else UiTheme.SUB
	)
	heading.text = title
	rows.add_child(heading)
	var text := Label.new()
	text.theme_type_variation = UiTheme.CAPTION
	text.text = body
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(text)
	return panel


func _build_type_column() -> void:
	var caption := Label.new()
	caption.theme_type_variation = UiTheme.MICRO
	caption.text = "글자 위계 — 명조 하나뿐이라 크기를 크게 벌린다"
	_type_column.add_child(caption)
	for sample in _TYPE_SAMPLES:
		var label := Label.new()
		label.theme_type_variation = sample[0]
		label.text = sample[1]
		_type_column.add_child(label)


## **서명 시연.** 같은 숫자를 어긋난 정도만 바꿔 세 번 찍는다.
##
## 여기서 규칙이 한눈에 보여야 한다 — 두 판이 겹쳐 있으면 잰 값이고,
## 벌어져 있으면 누가 옮긴 말이며, 크게 벌어져 있으면 제목이다.
func _build_slip_row() -> void:
	for sample in _SLIP_SAMPLES:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", UiTokens.SPACE_TIGHT)
		var plate := PlateLabel.new()
		plate.variation = UiTheme.DECK
		plate.slip_amount = sample[0]
		plate.text = sample[1]
		column.add_child(plate)
		var caption := Label.new()
		caption.theme_type_variation = UiTheme.MICRO
		caption.text = "%s   어긋남 %.1f" % [sample[2], sample[0]]
		column.add_child(caption)
		_slip_row.add_child(column)
		_slips.append(plate)


## 숫자를 흔들어 **서명이 움직이는 것**을 눈으로 확인한다.
## 인쇄 띠가 한 번 지나가고, 그 아래에서 별색판이 튀었다가 되튀어 앉는다.
func _reroll() -> void:
	_plate.print_edition(true)
	for index in _tiles.size():
		var tile := _tiles[index]
		var value := str(_random.randi_range(0, 24))
		var state: RoomNode.State = [
			RoomNode.State.CURRENT,
			RoomNode.State.REACHABLE,
			RoomNode.State.BLOCKED,
			RoomNode.State.DISTANT,
		][index]
		tile.display(tile.room_id, tile.name, value, state, "평지", RoomNode.Detail.FULL)
	for plate in _slips:
		plate.set_text(str(_random.randi_range(3, 40)))


# ---------------------------------------------------------------------------
# 절차적 형태 갤러리 — 이미지 파일은 하나도 없다
# ---------------------------------------------------------------------------


func _draw_gallery() -> void:
	_draw_swatches()
	_draw_shapes()


func _draw_swatches() -> void:
	var cursor := Vector2(40.0, _SWATCH_TOP)
	for group in _SWATCH_GROUPS:
		_label(Vector2(cursor.x, cursor.y - 9.0), group[0], UiTokens.INK_MUTED)
		for entry in group[1]:
			var rect := Rect2(cursor, _SWATCH)
			_gallery.draw_rect(rect, entry[1])
			_gallery.draw_rect(rect, UiTokens.fade(UiTokens.INK, 0.4), false, UiTokens.RULE_HAIR)
			_label(cursor + Vector2(0.0, _SWATCH.y + 13.0), entry[0], UiTokens.INK_MUTED)
			cursor.x += _SWATCH.x + UiTokens.SPACE_TIGHT
		# 역할이 바뀌는 자리에서만 크게 벌린다. 이 간격이 곧 분류다.
		cursor.x += UiTokens.SPACE_RIFT


func _draw_shapes() -> void:
	var y := _SHAPE_TOP
	_label(Vector2(40.0, y - 12.0), "형태 — 전부 코드가 만든다", UiTokens.INK_MUTED)
	_draw_rule_sample(Vector2(40.0, y))
	_draw_register_sample(Vector2(232.0, y))
	_draw_tear_sample(Vector2(330.0, y))
	_draw_pennant_sample(Vector2(494.0, y))
	_draw_overprint_sample(Vector2(646.0, y))
	_draw_link_sample(Vector2(806.0, y))
	_draw_gauge_sample(Vector2(1080.0, y))


func _draw_rule_sample(origin: Vector2) -> void:
	for band in UiShape.rule_stack(
		origin,
		160.0,
		PackedFloat32Array(
			[UiTokens.RULE_BANNER, UiTokens.RULE_HEAVY, UiTokens.RULE_TEXT, UiTokens.RULE_HAIR]
		),
		9.0
	):
		_gallery.draw_rect(band, UiTokens.INK)
	_label(origin + Vector2(0.0, 76.0), "괘선 네 굵기", UiTokens.INK_MUTED)


func _draw_register_sample(origin: Vector2) -> void:
	var center := origin + Vector2(30.0, 28.0)
	for stroke in UiShape.register_mark(center, UiTokens.REGISTER_ARM, UiTokens.REGISTER_GAP):
		_gallery.draw_polyline(stroke, UiTokens.INK_MUTED, UiTokens.RULE_HAIR)
	_gallery.draw_polyline(
		UiShape.register_ring(center, UiTokens.REGISTER_ARM * 0.5),
		UiTokens.INK_MUTED,
		UiTokens.RULE_HAIR
	)
	var slipped := center + UiTokens.slip(UiTokens.SLIP_SHOUT)
	for stroke in UiShape.register_mark(
		slipped, UiTokens.REGISTER_ARM * 0.8, UiTokens.REGISTER_GAP
	):
		_gallery.draw_polyline(stroke, UiTokens.SPOT, UiTokens.RULE_HAIR)
	_label(origin + Vector2(0.0, 76.0), "판 맞춤표", UiTokens.INK_MUTED)


func _draw_tear_sample(origin: Vector2) -> void:
	var rect := Rect2(origin, Vector2(136.0, 54.0))
	var torn := UiShape.deckle_edge(rect, UiTokens.TEAR_AMPLITUDE, UiTokens.TEAR_STEP, 2.0)
	_gallery.draw_colored_polygon(torn, UiTokens.PAPER_HIGH)
	_gallery.draw_polyline(
		UiShape.closed_outline(torn), UiTokens.fade(UiTokens.INK_FAINT, 0.7), UiTokens.RULE_HAIR
	)
	_gallery.draw_rect(Rect2(origin + Vector2(6.0, 6.0), Vector2(124.0, 5.0)), UiTokens.SPOT)
	_label(origin + Vector2(0.0, 76.0), "찢긴 가장자리", UiTokens.INK_MUTED)


func _draw_pennant_sample(origin: Vector2) -> void:
	var rect := Rect2(origin, Vector2(120.0, 34.0))
	_gallery.draw_colored_polygon(UiShape.pennant(rect, 12.0), UiTokens.SPOT)
	_label(origin + Vector2(0.0, 76.0), "속보 깃발", UiTokens.INK_MUTED)


func _draw_overprint_sample(origin: Vector2) -> void:
	var rect := Rect2(origin, Vector2(130.0, 54.0))
	_gallery.draw_rect(rect, UiTokens.PAPER_HIGH)
	var clip := UiShape.rect_polygon(rect)
	for piece in UiShape.hazard_stripes(rect, 12.0, 5.0, clip):
		_gallery.draw_colored_polygon(piece, UiTokens.fade(UiTokens.MARK, 0.85))
	_gallery.draw_rect(rect, UiTokens.MARK_DEEP, false, UiTokens.RULE_TEXT)
	_label(origin + Vector2(0.0, 76.0), "겹쳐찍기 (못 감)", UiTokens.INK_MUTED)


func _draw_link_sample(origin: Vector2) -> void:
	var span := 220.0
	_gallery.draw_line(origin, origin + Vector2(span, 0.0), UiTokens.INK, UiTokens.RULE_HEAVY)
	_gallery.draw_line(
		origin + Vector2(0.0, 6.0),
		origin + Vector2(span, 6.0),
		UiTokens.fade(UiTokens.INK, 0.55),
		UiTokens.RULE_HAIR
	)
	_label(origin + Vector2(0.0, 26.0), "지나갈 수 있는 통로", UiTokens.INK_MUTED)
	for segment in UiShape.dash_segments(
		origin + Vector2(0.0, 42.0),
		origin + Vector2(span, 42.0),
		UiTokens.DASH_LENGTH * 2.0,
		UiTokens.DASH_GAP
	):
		_gallery.draw_line(segment[0], segment[1], UiTokens.MARK_DEEP, UiTokens.RULE_TEXT)
	_label(origin + Vector2(0.0, 60.0), "길은 있으나 못 오른다", UiTokens.INK_MUTED)
	for segment in UiShape.dash_segments(
		origin + Vector2(0.0, 72.0),
		origin + Vector2(span, 72.0),
		UiTokens.DASH_LENGTH,
		UiTokens.DASH_GAP
	):
		_gallery.draw_line(
			segment[0], segment[1], UiTokens.fade(UiTokens.INK_FAINT, 0.8), UiTokens.RULE_HAIR
		)
	_label(origin + Vector2(0.0, 90.0), "지면에 실리지 않은 통로", UiTokens.INK_MUTED)


func _draw_gauge_sample(origin: Vector2) -> void:
	for step in 3:
		var base := origin + Vector2(float(step) * 52.0, 0.0)
		var slots := UiShape.gauge_bars(base, 3, Vector2(4.0, 16.0), 3.0)
		for index in slots.size():
			_gallery.draw_rect(
				slots[index], UiTokens.INK if index <= step else UiTokens.fade(UiTokens.INK, 0.22)
			)
	_label(origin + Vector2(0.0, 34.0), "판독률 — 원판이 얼마나 쓸 만한가", UiTokens.INK_MUTED)
	var center := origin + Vector2(16.0, 62.0)
	_gallery.draw_polyline(
		UiShape.chevron(center, 6.0, 6.0, true), UiTokens.INK_MUTED, UiTokens.RULE_TEXT
	)
	_gallery.draw_polyline(
		UiShape.chevron(center + Vector2(30.0, 0.0), 6.0, 6.0, false),
		UiTokens.INK_MUTED,
		UiTokens.RULE_TEXT
	)
	_label(origin + Vector2(0.0, 84.0), "오름 • 내림", UiTokens.INK_MUTED)


func _label(pos: Vector2, text: String, color: Color) -> void:
	if _font == null:
		return
	_gallery.draw_string(
		_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.TYPE_MICRO, color
	)
