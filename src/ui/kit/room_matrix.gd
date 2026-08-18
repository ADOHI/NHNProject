class_name RoomMatrix
extends Control
## 방 종류 여섯 x 처지 셋을 **실제 크기(58x30px)** 로 늘어놓은 확인용 화면.
##
## 확대해서 보면 안 된다. 「배율 0.40 에서 보스방과 빈방이 똑같이 생겼다」가 문제였으므로
## **그 크기 그대로** 찍어야 답이 됐는지 알 수 있다. 아래에 4배 확대 줄을 따로 두지만
## 그건 세공을 확인하는 용도이고, 판정은 위쪽 실제 크기 줄에서 한다.
##
## `1`~`5` 로 컨셉 배색을 갈아 끼운다. 방 위젯이 다섯 배색 어디에 얹혀도
## 구분이 유지되는지가 이 화면의 두 번째 질문이다.

## 배율 0.40 에서의 방 위젯 실측 크기.
const CELL := Vector2(58.0, 30.0)

const ZOOM: float = 4.0
const GAP: float = 26.0
const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")

const KINDS: Array[RoomMark.Kind] = [
	RoomMark.Kind.EMPTY,
	RoomMark.Kind.TREASURE,
	RoomMark.Kind.HAZARD,
	RoomMark.Kind.BOSS,
	RoomMark.Kind.ENTRANCE,
	RoomMark.Kind.EXIT,
]

const STATES: Array[RoomPalette.State] = [
	RoomPalette.State.REACHABLE,
	RoomPalette.State.BLOCKED,
	RoomPalette.State.HERE,
]

## 방마다 다른 숫자를 넣는다. 전부 같은 숫자면 글자 폭이 같아 구분이 쉬워 보이는
## 착시가 생기고, 실제 판에서는 자릿수가 섞인다.
const NUMBERS: Array[String] = ["0", "4", "7", "12", "2", "9"]

var _palette: RoomPalette
var _concept := "slam"
var _label_font: FontVariation


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_label_font = FontVariation.new()
	_label_font.base_font = FONT
	set_concept(_concept)


func set_concept(name: String) -> void:
	_concept = name
	_palette = RoomPalette.for_concept(name)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	match (event as InputEventKey).keycode:
		KEY_1:
			set_concept("slam")
		KEY_2:
			set_concept("shear")
		KEY_3:
			set_concept("hold")
		KEY_4:
			set_concept("squash")
		KEY_5:
			set_concept("afterimage")
		KEY_ESCAPE:
			get_tree().quit()


func _draw() -> void:
	# 판 바탕은 컨셉의 무대와 같은 값을 쓴다. 방이 얹히는 자리가 곧 무대다.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.086, 0.086, 0.094))
	_draw_title()
	var origin := Vector2(150.0, 96.0)
	for row in range(STATES.size()):
		_draw_state_label(origin, row)
		for column in range(KINDS.size()):
			var at := origin + Vector2(float(column) * (CELL.x + GAP), float(row) * 58.0)
			_draw_room(Rect2(at, CELL), KINDS[column], STATES[row], NUMBERS[column], 1.0)
	_draw_kind_labels(origin)
	_draw_zoom_row(origin + Vector2(0.0, 226.0))


func _draw_room(
	rect: Rect2, kind: RoomMark.Kind, state: RoomPalette.State, number: String, scale: float
) -> void:
	var plate := RoomMark.plate_polygon(rect, kind)
	var fill := _palette.fill_for(state)
	if fill.a > 0.0:
		draw_colored_polygon(plate, fill)
	var outline := _palette.outline_for(state)
	if outline.a > 0.0:
		var closed := plate.duplicate()
		closed.append(plate[0])
		draw_polyline(closed, outline, maxf(1.0, scale))

	if RoomMark.has_wedge(kind):
		draw_colored_polygon(RoomMark.wedge_polygon(rect), _palette.reward_for(state))
	if RoomMark.has_hatch(kind):
		var threat := _palette.threat_for(state)
		for segment in RoomMark.hatch_segments(rect):
			draw_line(segment[0], segment[1], threat, RoomMark.HATCH_WIDTH * scale)

	var font_size := int(round(15.0 * scale))
	var measured := _label_font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(
		_label_font,
		(
			rect.position
			+ Vector2((rect.size.x - measured.x) * 0.5, rect.size.y * 0.5 + measured.y * 0.32)
		),
		number,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		_palette.number_for(state)
	)


## 4배 확대 줄. 세공 확인용이지 판정용이 아니다.
func _draw_zoom_row(origin: Vector2) -> void:
	_note(origin + Vector2(0.0, -14.0), "아래는 4배 확대 (세공 확인용). 판정은 위쪽 실제 크기에서 한다")
	var at := origin
	for kind in KINDS:
		var rect := Rect2(at, CELL * ZOOM)
		_draw_room(rect, kind, RoomPalette.State.REACHABLE, "7", ZOOM)
		_note(at + Vector2(0.0, CELL.y * ZOOM + 16.0), RoomMark.kind_name(kind))
		at.x += CELL.x * ZOOM + 22.0


func _draw_title() -> void:
	_note(Vector2(40.0, 40.0), "방 종류 여섯 x 처지 셋 — 실제 크기 58x30px  [%s 배색]" % _concept.to_upper())
	_note(Vector2(40.0, 60.0), "1 SLAM  2 SHEAR  3 HOLD  4 SQUASH  5 AFTERIMAGE   Esc 닫기")


func _draw_kind_labels(origin: Vector2) -> void:
	for column in range(KINDS.size()):
		_note(
			origin + Vector2(float(column) * (CELL.x + GAP), -12.0),
			RoomMark.kind_name(KINDS[column])
		)


func _draw_state_label(origin: Vector2, row: int) -> void:
	var names := ["갈 수 있다", "못 간다", "여기 있다"]
	_note(origin + Vector2(-104.0, float(row) * 58.0 + 20.0), names[row])


func _note(at: Vector2, text: String) -> void:
	draw_string(_label_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.66, 0.66, 0.63))
