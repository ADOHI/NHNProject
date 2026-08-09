class_name PersonSheetView
extends Control
## 인물 상세 칸들을 그린다. **픽셀만 안다.**
##
## docs/design/24-npc-relations.md §24.17.9 · docs/design/20-ui-kit.md §20.23.3.
## 무엇을 보여줄지는 `PersonSheet` 가 정하고, **어디에 놓을지는 `SheetLayout` 이 정한다.**
## 여기는 그 자리에 색을 칠할 뿐이다.
##
## ## 자리를 스스로 안 잡는다
##
## 예전에는 `_draw()` 가 그리면서 y 를 더해 갔다. 그러면 **눌린 자리가 어느 줄인지**
## 알 방법이 없고, 따로 계산하면 그림과 어긋난다(§20.23.3). 지금은 자리 배열이
## 하나뿐이고 그리기와 눌림이 **둘 다 그것을 읽는다.**
##
## ## 왜 노드가 아니라 _draw() 인가
##
## 칸 여섯에 필드 스무 개 남짓이라 노드로도 되지만, `_draw()` 는
## **`queue_redraw()` 를 부를 때만 돈다.** 인물을 갈아 끼울 때만 비용이 들고
## 가만히 있으면 프레임당 0 이다. 그리고 자식 노드가 없으니
## **UI 킷 컨셉이 정해져 배치를 갈아엎을 때 트리를 손댈 일이 없다.**
##
## ## 꾸미지 않는다
##
## `src/ui/kit/` 을 참조하지 않는다. 컨셉이 다섯 번째를 잡는 중이라
## 지금 붙이면 정해질 때 통째로 뜯는다. **글자와 막대뿐이다.**

## 눌러서 갈 곳이 있는 줄에 붙는 표. **클릭만으로 조작하려면 무엇이 눌리는지 보여야 한다**
## (§4.1 · §20.23.2). 화살표 하나가 「여기서 저기로 간다」를 말한다.
## **꺾쇠 하나여야 한다** — `›`(U+203A) 를 먼저 썼다가 글리프 검사에 걸렸다.
## 송명체에 없는 글자라 웹 빌드에서 두부(□)가 된다.
const LINK_MARK := ">"

const _PANEL := Color(1.0, 1.0, 1.0, 0.028)
const _BORDER := Color(1.0, 1.0, 1.0, 0.16)
const _TITLE := Color(0.86, 0.88, 0.93)
const _LABEL := Color(0.56, 0.60, 0.69)
const _VALUE := Color(0.93, 0.95, 0.99)

## 아직 없는 자료. **흐리지만 읽히게** — 안 보이면 고장으로 오해한다.
const _ABSENT := Color(0.52, 0.55, 0.63)

const _BAR_TRACK := Color(1.0, 1.0, 1.0, 0.08)
const _BAR_FILL := Color(0.63, 0.71, 0.86, 0.9)

## 막대 가운데의 0 선. 부호 있는 축에서만 그린다.
const _BAR_ZERO := Color(1.0, 1.0, 1.0, 0.28)

## 갈 곳이 있는 줄, 그리고 그 줄에 커서가 올라간 상태.
const _LINK := Color(0.72, 0.82, 0.98)
const _HOVER := Color(1.0, 1.0, 1.0, 0.06)

## 정보 확인(§4.2)이 띄우는 쪽지.
const _NOTE_FILL := Color(0.07, 0.08, 0.11, 0.96)
const _NOTE_EDGE := Color(0.62, 0.70, 0.86, 0.85)
const _NOTE_WIDTH := 320.0
const _NOTE_PAD := 10.0

var _sections: Array[SheetSection] = []
var _layout := SheetLayout.new()
var _font: Font

## 커서가 올라간 줄. `Vector2i(칸, 필드)` 이고 없으면 (-1, -1).
var _hover := Vector2i(-1, -1)

var _note := ""
var _note_at := Vector2.ZERO


func _ready() -> void:
	# 프로젝트 테마의 기본 폰트를 쓴다. 킷을 참조하지 않는 대신 여기서 한 번만 잡는다.
	_font = get_theme_default_font()
	resized.connect(_relayout)
	_relayout()


## 그릴 칸들을 갈아 끼운다. **여기서만 다시 그린다.**
func show_sections(sections: Array[SheetSection]) -> void:
	_sections = sections
	_hover = Vector2i(-1, -1)
	_note = ""
	_relayout()


## 자리 배열. **손이 이것을 읽고 눌린 줄을 찾는다** — 그림과 같은 배열이다.
func layout() -> SheetLayout:
	return _layout


## 지금 그리고 있는 칸들. 눌린 줄에서 필드를 되찾을 때 쓴다.
func sections() -> Array[SheetSection]:
	return _sections


## 지금 떠 있는 정보 확인 쪽지. 비어 있으면 안 떠 있다.
func note() -> String:
	return _note


## 커서가 올라간 줄을 바꾼다. 갈 곳이 있는 줄에서만 표시가 달라진다.
func set_hover(row: Vector2i) -> void:
	if row == _hover:
		return
	_hover = row
	queue_redraw()


## 정보 확인 쪽지를 띄운다 (§4.2 · §20.23.5). 빈 글이면 지운다.
func show_note(at: Vector2, text: String) -> void:
	_note = text
	_note_at = at
	queue_redraw()


func _relayout() -> void:
	if _font == null:
		return
	_layout = SheetLayout.build(
		_sections, size, _font, PersonSheet.LEFT_TITLES, PersonSheet.RIGHT_TITLES
	)
	queue_redraw()


func _draw() -> void:
	if _font == null or _sections.is_empty():
		return
	for i in _layout.panels.size():
		_draw_panel(_layout.panels[i], _sections[_layout.panel_of[i]])
	for i in _layout.rows.size():
		var section := _sections[_layout.row_section[i]]
		var field := section.fields[_layout.row_field[i]]
		var here := Vector2i(_layout.row_section[i], _layout.row_field[i])
		_draw_field(field, _layout.rows[i], here == _hover)
	_draw_note()


func _draw_panel(frame: Rect2, section: SheetSection) -> void:
	draw_rect(frame, _PANEL, true)
	draw_rect(frame, _BORDER, false, 1.0)
	draw_string(
		_font,
		Vector2(
			frame.position.x + SheetLayout.PAD, frame.position.y + SheetLayout.TITLE_HEIGHT - 8.0
		),
		section.title,
		HORIZONTAL_ALIGNMENT_LEFT,
		frame.size.x - SheetLayout.PAD * 2.0,
		SheetLayout.TITLE_SIZE,
		_TITLE
	)
	if section.shape == SheetSection.Shape.FRAME:
		_draw_frame(section, frame)


## 초상 자리. **전원이 초상을 갖는다**(설계 24.8 폐기) 이므로 「없는 인물」 경우가 없다.
## 정사각이고 그 규격이 곧 생성 규격이다 (설계 24.20.4).
func _draw_frame(section: SheetSection, frame: Rect2) -> void:
	var side := frame.size.x - SheetLayout.PAD * 2.0
	var top := frame.position.y + SheetLayout.TITLE_HEIGHT
	var box := Rect2(frame.position.x + SheetLayout.PAD, top, side, side)
	draw_rect(box, _BORDER, false, 1.0)
	# 대각선 둘로 「자리표시자」임을 말한다. 빈 사각형은 고장으로 읽힌다.
	draw_line(box.position, box.position + box.size, _BORDER, 1.0)
	draw_line(Vector2(box.position.x, box.end.y), Vector2(box.end.x, box.position.y), _BORDER, 1.0)
	if section.fields.is_empty():
		return
	draw_multiline_string(
		_font,
		Vector2(box.position.x + SheetLayout.PAD, box.get_center().y),
		section.fields[0].display_text(),
		HORIZONTAL_ALIGNMENT_CENTER,
		side - SheetLayout.PAD * 2.0,
		SheetLayout.BODY_SIZE,
		3,
		_ABSENT
	)


func _draw_field(field: SheetField, row: Rect2, hovered: bool) -> void:
	var width := row.size.x
	var label_width := SheetLayout.label_width(width)
	var x := row.position.x
	var y := row.position.y
	var text := field.display_text()
	var color := _VALUE if field.is_filled() else _ABSENT
	if field.has_link():
		color = _LINK
	var value_x := x + SheetLayout.PAD + label_width
	var value_width := width - SheetLayout.PAD * 2.0 - label_width
	var baseline := y + SheetLayout.ROW_HEIGHT - 6.0

	if hovered and field.has_link():
		draw_rect(row, _HOVER, true)

	if not field.label.is_empty():
		draw_string(
			_font,
			Vector2(x + SheetLayout.PAD, baseline),
			field.label,
			HORIZONTAL_ALIGNMENT_LEFT,
			label_width,
			SheetLayout.BODY_SIZE,
			_LABEL
		)

	if field.has_bar():
		var bar_width := SheetLayout.bar_width(width)
		draw_string(
			_font,
			Vector2(value_x, baseline),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			value_width - bar_width - SheetLayout.PAD,
			SheetLayout.BODY_SIZE,
			color
		)
		_draw_bar(
			field,
			x + width - SheetLayout.PAD - bar_width,
			y + SheetLayout.ROW_HEIGHT * 0.5 - SheetLayout.BAR_HEIGHT * 0.5,
			bar_width
		)
		return

	if field.has_link():
		draw_string(
			_font,
			Vector2(x + width - SheetLayout.PAD * 1.6, baseline),
			LINK_MARK,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			SheetLayout.BODY_SIZE,
			_LINK
		)

	# 사유 문장은 길다. 여러 줄로 감아야 잘리지 않는다 (설계 24.17.4).
	draw_multiline_string(
		_font,
		Vector2(value_x, baseline),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		value_width,
		SheetLayout.BODY_SIZE,
		-1,
		color
	)


## 부호 있는 막대는 가운데가 0 이고 좌우로 자란다. 없는 막대는 왼쪽에서 차오른다.
func _draw_bar(field: SheetField, x: float, y: float, bar_width: float) -> void:
	draw_rect(Rect2(x, y, bar_width, SheetLayout.BAR_HEIGHT), _BAR_TRACK, true)
	if not field.is_signed_bar:
		draw_rect(Rect2(x, y, bar_width * field.bar, SheetLayout.BAR_HEIGHT), _BAR_FILL, true)
		return

	var middle := x + bar_width * 0.5
	draw_line(Vector2(middle, y), Vector2(middle, y + SheetLayout.BAR_HEIGHT), _BAR_ZERO, 1.0)
	var span := bar_width * 0.5 * absf(field.bar)
	var left := middle if field.bar >= 0.0 else middle - span
	draw_rect(Rect2(left, y, span, SheetLayout.BAR_HEIGHT), _BAR_FILL, true)


## 정보 확인 쪽지. **누른 자리 옆에 뜨고 화면 안으로 밀어 넣는다** —
## 가장자리를 누르면 쪽지가 화면 밖으로 나가 안 읽힌다.
func _draw_note() -> void:
	if _note.is_empty():
		return
	var inner := _NOTE_WIDTH - _NOTE_PAD * 2.0
	var measured := _font.get_multiline_string_size(
		_note, HORIZONTAL_ALIGNMENT_LEFT, inner, SheetLayout.BODY_SIZE
	)
	var box := Rect2(
		_note_at + Vector2(12.0, 12.0), Vector2(_NOTE_WIDTH, measured.y + _NOTE_PAD * 2.0)
	)
	box.position.x = clampf(box.position.x, 0.0, maxf(size.x - box.size.x, 0.0))
	box.position.y = clampf(box.position.y, 0.0, maxf(size.y - box.size.y, 0.0))
	draw_rect(box, _NOTE_FILL, true)
	draw_rect(box, _NOTE_EDGE, false, 1.0)
	draw_multiline_string(
		_font,
		box.position + Vector2(_NOTE_PAD, _NOTE_PAD + SheetLayout.BODY_SIZE),
		_note,
		HORIZONTAL_ALIGNMENT_LEFT,
		inner,
		SheetLayout.BODY_SIZE,
		-1,
		_VALUE
	)
