extends Control
## 시각 언어를 한 화면에 늘어놓은 확인용 씬.
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
const _BACKDROP_SHADER := preload("res://src/ui/style/shaders/facility_backdrop.gdshader")

## 색 견본. 역할이 같은 것끼리 붙이고 역할이 다르면 크게 벌린다 —
## 간격 규칙 자체가 이 줄에서 눈에 보인다.
const _SWATCH_GROUPS := [
	[
		"계측 — 사실",
		[["신호", UiTokens.SIGNAL], ["강조", UiTokens.SIGNAL_HOT], ["죽임", UiTokens.SIGNAL_DIM]]
	],
	["송출 — 과장", [["방송", UiTokens.ONAIR], ["죽임", UiTokens.ONAIR_DIM]]],
	["금지", [["안전 표지", UiTokens.HAZARD], ["죽임", UiTokens.HAZARD_DIM]]],
	["글자", [["본문", UiTokens.INK], ["보조", UiTokens.INK_MUTED], ["희미", UiTokens.INK_FAINT]]],
	["시설", [["면", UiTokens.PLATE_HIGH], ["이음", UiTokens.SEAM], ["바닥", UiTokens.FLOOR]]],
]

const _TYPE_SAMPLES := [
	[UiTheme.DISPLAY, "38  판단의 숫자"],
	[UiTheme.NUMERIC, "27  방의 숫자"],
	[UiTheme.TITLE, "19  지금 어디인가"],
	["Label", "15  본문"],
	[UiTheme.CAPTION, "13  곁들이는 말"],
	[UiTheme.MICRO, "11  안 읽어도 되는 말"],
]

const _SWATCH := Vector2(76.0, 34.0)
const _GALLERY_TOP := 96.0
const _SHAPE_TOP := 196.0

var _tiles: Array[RoomNode] = []
var _random := RandomNumberGenerator.new()

@onready var _background: ColorRect = %Background
@onready var _gallery: Control = %Gallery
@onready var _tile_row: HBoxContainer = %Tiles
@onready var _panel_row: HBoxContainer = %Panels
@onready var _type_column: VBoxContainer = %TypeColumn
@onready var _reroll_button: Button = %RerollButton


func _ready() -> void:
	theme = UiTheme.get_theme()
	_random.seed = 7
	_build_backdrop()
	_build_tiles()
	_build_panels()
	_build_type_column()
	_gallery.draw.connect(_draw_gallery)
	_reroll_button.pressed.connect(_reroll)


func _build_backdrop() -> void:
	var material := ShaderMaterial.new()
	material.shader = _BACKDROP_SHADER
	material.set_shader_parameter("floor_color", UiTokens.FLOOR)
	material.set_shader_parameter("seam_color", UiTokens.SEAM)
	material.set_shader_parameter("glow_color", UiTokens.SIGNAL)
	_background.material = material


## 방 타일 네 상태를 나란히 둔다. **이 화면의 핵심**이다 —
## "지금 있는 곳 / 갈 수 있는 곳 / 보이지만 못 가는 곳 / 먼 곳"이
## 한눈에 구분되지 않으면 판은 읽히지 않는다.
func _build_tiles() -> void:
	var rows := [
		["r_current", "관제실", "6", RoomNode.State.CURRENT, ""],
		["r_reach", "화물 리프트", "?", RoomNode.State.REACHABLE, "내림 1"],
		["r_block", "봉인된 금고", "?", RoomNode.State.BLOCKED, "오름 4"],
		["r_far", "제단", "?", RoomNode.State.DISTANT, "고도 7"],
	]
	for row in rows:
		var tile: RoomNode = RoomNodeScene.instantiate()
		_tile_row.add_child(tile)
		_tiles.append(tile)
		tile.display(row[0], row[1], row[2], row[3], row[4], RoomNode.Detail.FULL)


## 패널 세 종류. 어느 레이어의 정보인지가 **읽기 전에** 보여야 한다.
func _build_panels() -> void:
	_panel_row.add_child(
		_make_panel(
			SignalPanel.Layer.INSTRUMENT,
			"계측 패널",
			"시설이 잰 값이다. 모서리가 반듯하고 잡티가 없다.\n숫자는 정확하고, 대신 무엇으로 이루어졌는지는 말해 주지 않는다."
		)
	)
	_panel_row.add_child(
		_make_panel(
			SignalPanel.Layer.BROADCAST,
			"송출 패널",
			"렉카가 쓴 것이다. 기울어 있고 신호가 흔들린다.\n장소와 종류는 사실이지만 규모는 부풀려져 있다."
		)
	)
	_panel_row.add_child(
		_make_panel(
			SignalPanel.Layer.TRUTH,
			"판의 진실",
			"송출되지 않는 화면이다. 방송의 문법을 쓰지 않는다.\n모서리를 자르지 않고 프레임도 두르지 않는다."
		)
	)


func _make_panel(layer: SignalPanel.Layer, title: String, body: String) -> SignalPanel:
	var panel := SignalPanel.new()
	panel.layer = layer
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", UiTokens.SPACE_SNUG)
	margin.add_child(rows)
	var heading := Label.new()
	heading.theme_type_variation = (
		UiTheme.HYPE if layer == SignalPanel.Layer.BROADCAST else UiTheme.TITLE
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
	caption.text = "글자 위계 — 폰트가 하나뿐이라 크기와 색만이 위계를 만든다"
	_type_column.add_child(caption)
	for sample in _TYPE_SAMPLES:
		var label := Label.new()
		label.theme_type_variation = sample[0]
		label.text = sample[1]
		_type_column.add_child(label)
	_type_column.add_child(_spacer(UiTokens.SPACE_RIFT))
	var motion := Label.new()
	motion.theme_type_variation = UiTheme.CAPTION
	motion.text = "모션 — 움직이는 것은 변한 것이다"
	_type_column.add_child(motion)
	var note := Label.new()
	note.theme_type_variation = UiTheme.MICRO
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = (
		"상시 움직임은 둘뿐이다. 모르는 방의 신호 잡음과 송출 중 표시의 맥동."
		+ " 둘 다 정보다. 나머지는 값이 바뀔 때만 움직인다 —"
		+ " 왼쪽 아래 버튼으로 숫자를 흔들면 변화 표시가 떠오른다."
	)
	_type_column.add_child(note)


func _spacer(height: int) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, float(height))
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


## 숫자를 흔들어 **변화 표시**를 눈으로 확인한다.
## 이 게임에서 움직이는 것은 변한 것뿐이므로, 움직임을 보려면 값을 바꾸는 수밖에 없다.
func _reroll() -> void:
	for index in _tiles.size():
		var tile := _tiles[index]
		var value := str(_random.randi_range(0, 12))
		var state: RoomNode.State = [
			RoomNode.State.CURRENT,
			RoomNode.State.REACHABLE,
			RoomNode.State.BLOCKED,
			RoomNode.State.DISTANT,
		][index]
		tile.display(tile.room_id, tile.name, value, state, "평지", RoomNode.Detail.FULL)


# ---------------------------------------------------------------------------
# 절차적 형태 갤러리
# ---------------------------------------------------------------------------


func _draw_gallery() -> void:
	_draw_swatches()
	_draw_shapes()


func _draw_swatches() -> void:
	var cursor := Vector2(40.0, _GALLERY_TOP)
	for group in _SWATCH_GROUPS:
		_label(Vector2(cursor.x, cursor.y - 8.0), group[0], UiTokens.INK_MUTED)
		for entry in group[1]:
			var rect := Rect2(cursor, _SWATCH)
			var polygon := UiShape.chamfer_polygon(rect, UiTokens.chip_cuts())
			_gallery.draw_colored_polygon(polygon, entry[1])
			# 어두운 색은 배경에 묻힌다. 견본은 경계가 보여야 견본이다.
			_gallery.draw_polyline(
				UiShape.closed_outline(polygon),
				UiTokens.fade(UiTokens.SEAM, 0.8),
				UiTokens.STROKE_HAIR,
				true
			)
			_label(cursor + Vector2(0.0, _SWATCH.y + 14.0), entry[0], UiTokens.INK_FAINT)
			cursor.x += _SWATCH.x + UiTokens.SPACE_TIGHT
		# 역할이 바뀌는 자리에서만 크게 벌린다. 이 간격이 곧 분류다.
		cursor.x += UiTokens.SPACE_RIFT


func _draw_shapes() -> void:
	var y := _SHAPE_TOP
	_label(Vector2(40.0, y - 12.0), "형태 — 전부 코드가 만든다. 이미지 파일은 하나도 없다", UiTokens.INK_MUTED)
	_draw_cut_samples(Vector2(40.0, y))
	_draw_bracket_sample(Vector2(376.0, y))
	_draw_hazard_sample(Vector2(508.0, y))
	_draw_line_samples(Vector2(640.0, y))
	_draw_mark_samples(Vector2(852.0, y))


## 잘린 모서리 세 종류. 역할마다 자르는 자리가 다르다.
func _draw_cut_samples(origin: Vector2) -> void:
	var cuts := [UiTokens.tile_cuts(), UiTokens.panel_cuts(), UiTokens.chip_cuts()]
	var names := ["타일 (좌상)", "패널 (우하)", "자막 (대각)"]
	for index in cuts.size():
		var rect := Rect2(origin + Vector2(float(index) * 112.0, 0.0), Vector2(100.0, 56.0))
		var polygon := UiShape.chamfer_polygon(rect, cuts[index])
		_gallery.draw_colored_polygon(polygon, UiTokens.PLATE_HIGH)
		_gallery.draw_polyline(
			UiShape.closed_outline(polygon), UiTokens.SIGNAL_DIM, UiTokens.STROKE_RULE, true
		)
		_label(rect.position + Vector2(0.0, 72.0), names[index], UiTokens.INK_FAINT)


func _draw_bracket_sample(origin: Vector2) -> void:
	var rect := Rect2(origin, Vector2(100.0, 56.0))
	for corner in 4:
		_gallery.draw_polyline(
			UiShape.bracket(rect, corner, UiTokens.BRACKET_ARM),
			UiTokens.SIGNAL,
			UiTokens.STROKE_HAIR
		)
	_label(rect.position + Vector2(0.0, 72.0), "코너 브래킷", UiTokens.INK_FAINT)


func _draw_hazard_sample(origin: Vector2) -> void:
	var rect := Rect2(origin, Vector2(100.0, 56.0))
	var polygon := UiShape.chamfer_polygon(rect, UiTokens.tile_cuts())
	_gallery.draw_colored_polygon(polygon, UiTokens.PLATE)
	for piece in UiShape.hazard_stripes(rect, 13.0, 4.0, polygon):
		_gallery.draw_colored_polygon(piece, UiTokens.fade(UiTokens.HAZARD, 0.35))
	_gallery.draw_polyline(
		UiShape.closed_outline(polygon), UiTokens.HAZARD_DIM, UiTokens.STROKE_HAIR, true
	)
	_label(rect.position + Vector2(0.0, 72.0), "경고 사선 (못 감)", UiTokens.INK_FAINT)


func _draw_line_samples(origin: Vector2) -> void:
	_gallery.draw_line(
		origin, origin + Vector2(168.0, 0.0), UiTokens.SIGNAL_DIM, UiTokens.STROKE_RULE, true
	)
	_label(origin + Vector2(0.0, 18.0), "살아 있는 통로", UiTokens.INK_FAINT)
	var dashed := origin + Vector2(0.0, 34.0)
	for segment in UiShape.dash_segments(
		dashed, dashed + Vector2(168.0, 0.0), UiTokens.DASH_LENGTH, UiTokens.DASH_GAP
	):
		_gallery.draw_line(segment[0], segment[1], UiTokens.SEAM, UiTokens.STROKE_RULE, true)
	_label(dashed + Vector2(0.0, 18.0), "중계되지 않는 통로", UiTokens.INK_FAINT)
	var ruler := origin + Vector2(0.0, 68.0)
	for tick in UiShape.tick_ruler(ruler, ruler + Vector2(168.0, 0.0), 17, 7.0):
		_gallery.draw_polyline(tick, UiTokens.SIGNAL_DIM, UiTokens.STROKE_HAIR)
	_label(ruler + Vector2(0.0, 32.0), "계측 눈금", UiTokens.INK_FAINT)


## 글리프가 없어서 직접 그리는 것들. 화살표·별표·사각형 기호는 웹에서 두부가 된다.
func _draw_mark_samples(origin: Vector2) -> void:
	var marks := [true, false]
	for index in marks.size():
		var center := origin + Vector2(float(index) * 30.0 + 10.0, 12.0)
		_gallery.draw_polyline(
			UiShape.chevron(center, 6.0, 6.0, marks[index]), UiTokens.SIGNAL, UiTokens.STROKE_RULE
		)
	var flat := origin + Vector2(70.0, 12.0)
	_gallery.draw_line(
		flat - Vector2(6.0, 0.0), flat + Vector2(6.0, 0.0), UiTokens.SIGNAL, UiTokens.STROKE_RULE
	)
	# 가운뎃점은 폰트에 없다. 공백으로 벌린다 (docs/conventions.md §5.1).
	_label(origin + Vector2(0.0, 34.0), "오름   내림   평지", UiTokens.INK_FAINT)

	for level in 3:
		var slot_origin := origin + Vector2(float(level) * 44.0, 56.0)
		var slots := UiShape.signal_bars(slot_origin, 3, Vector2(4.0, 12.0), 3.0)
		for index in slots.size():
			var lit := index <= level
			_gallery.draw_rect(
				slots[index], UiTokens.SIGNAL if lit else UiTokens.fade(UiTokens.SEAM, 0.8)
			)
	_label(origin + Vector2(0.0, 88.0), "신호 세기 — 이 숫자를 얼마나 믿는가", UiTokens.INK_FAINT)


func _label(position: Vector2, text: String, color: Color) -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	_gallery.draw_string(
		font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiTokens.TYPE_MICRO, color
	)
