class_name PersonSheetView
extends Control
## 인물 상세 칸들을 그린다. **픽셀만 안다.**
##
## docs/design/24-npc-relations.md §24.17.9. 무엇을 보여줄지는 `PersonSheet` 가 정하고
## 여기는 그것을 어디에 몇 픽셀로 놓을지만 안다.
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

## 왼쪽 열 폭. 초상 액자가 이 폭의 정사각이므로 **초상 규격이 이 값을 정했다**
## (설계 24.20.4 — 1:1, 화면 340).
const LEFT_WIDTH := 340.0

const MARGIN := 16.0
const COLUMN_GAP := 12.0
const SECTION_GAP := 10.0
const PAD := 10.0

const TITLE_HEIGHT := 26.0
const ROW_HEIGHT := 22.0
const TITLE_SIZE := 17
const BODY_SIZE := 14

## 막대의 최대 폭과 두께. 좁은 열에서는 폭에 비례해 줄인다 (_bar_width).
const BAR_WIDTH_MAX := 150.0
const BAR_WIDTH_MIN := 70.0
const BAR_HEIGHT := 8.0

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

var _sections: Array[SheetSection] = []
var _font: Font


func _ready() -> void:
	# 프로젝트 테마의 기본 폰트를 쓴다. 킷을 참조하지 않는 대신 여기서 한 번만 잡는다.
	_font = get_theme_default_font()


## 그릴 칸들을 갈아 끼운다. **여기서만 다시 그린다.**
func show_sections(sections: Array[SheetSection]) -> void:
	_sections = sections
	queue_redraw()


func _draw() -> void:
	if _font == null or _sections.is_empty():
		return

	var right_x := MARGIN + LEFT_WIDTH + COLUMN_GAP
	var right_width := size.x - right_x - MARGIN
	_draw_column(PersonSheet.LEFT_TITLES, MARGIN, LEFT_WIDTH)
	_draw_column(PersonSheet.RIGHT_TITLES, right_x, right_width)


## 한 열을 위에서 아래로. 열 나누기가 §24.17.3 의 선언이다 —
## 왼쪽은 이 사람이 누구와 엮여 있나, 오른쪽은 이 사람 자체.
func _draw_column(titles: Array, x: float, width: float) -> void:
	var y := MARGIN
	for title in titles:
		var section := PersonSheet.section_of(_sections, str(title))
		if section == null:
			continue
		y += _draw_section(section, x, y, width) + SECTION_GAP


func _draw_section(section: SheetSection, x: float, y: float, width: float) -> float:
	var height := TITLE_HEIGHT + _body_height(section, width) + PAD
	var frame := Rect2(x, y, width, height)
	draw_rect(frame, _PANEL, true)
	draw_rect(frame, _BORDER, false, 1.0)
	draw_string(
		_font,
		Vector2(x + PAD, y + TITLE_HEIGHT - 8.0),
		section.title,
		HORIZONTAL_ALIGNMENT_LEFT,
		width - PAD * 2.0,
		TITLE_SIZE,
		_TITLE
	)

	var cursor := y + TITLE_HEIGHT
	if section.shape == SheetSection.Shape.FRAME:
		_draw_frame(section, x, cursor, width)
		return height

	var label_width := _label_width(width)
	for field in section.fields:
		cursor += _draw_field(field, x, cursor, width, label_width)
	return height


## 초상 자리. **전원이 초상을 갖는다**(설계 24.8 폐기) 이므로 「없는 인물」 경우가 없다.
## 정사각이고 그 규격이 곧 생성 규격이다 (설계 24.20.4).
func _draw_frame(section: SheetSection, x: float, y: float, width: float) -> void:
	var side := width - PAD * 2.0
	var box := Rect2(x + PAD, y, side, side)
	draw_rect(box, _BORDER, false, 1.0)
	# 대각선 둘로 「자리표시자」임을 말한다. 빈 사각형은 고장으로 읽힌다.
	draw_line(box.position, box.position + box.size, _BORDER, 1.0)
	draw_line(Vector2(box.position.x, box.end.y), Vector2(box.end.x, box.position.y), _BORDER, 1.0)
	if section.fields.is_empty():
		return
	var note: String = section.fields[0].display_text()
	draw_multiline_string(
		_font,
		Vector2(box.position.x + PAD, box.get_center().y),
		note,
		HORIZONTAL_ALIGNMENT_CENTER,
		side - PAD * 2.0,
		BODY_SIZE,
		3,
		_ABSENT
	)


func _draw_field(field: SheetField, x: float, y: float, width: float, label_width: float) -> float:
	var text := field.display_text()
	var color := _VALUE if field.is_filled() else _ABSENT
	var value_x := x + PAD + label_width
	var value_width := width - PAD * 2.0 - label_width

	if not field.label.is_empty():
		draw_string(
			_font,
			Vector2(x + PAD, y + ROW_HEIGHT - 6.0),
			field.label,
			HORIZONTAL_ALIGNMENT_LEFT,
			label_width,
			BODY_SIZE,
			_LABEL
		)

	if field.has_bar():
		var bar_width := _bar_width(width)
		draw_string(
			_font,
			Vector2(value_x, y + ROW_HEIGHT - 6.0),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			value_width - bar_width - PAD,
			BODY_SIZE,
			color
		)
		_draw_bar(
			field, x + width - PAD - bar_width, y + ROW_HEIGHT * 0.5 - BAR_HEIGHT * 0.5, bar_width
		)
		return ROW_HEIGHT

	# 사유 문장은 길다. 여러 줄로 감아야 잘리지 않는다 (설계 24.17.4).
	var lines := _font.get_multiline_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, value_width, BODY_SIZE
	)
	draw_multiline_string(
		_font,
		Vector2(value_x, y + ROW_HEIGHT - 6.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		value_width,
		BODY_SIZE,
		-1,
		color
	)
	return maxf(ROW_HEIGHT, lines.y + 6.0)


## 부호 있는 막대는 가운데가 0 이고 좌우로 자란다. 없는 막대는 왼쪽에서 차오른다.
func _draw_bar(field: SheetField, x: float, y: float, bar_width: float) -> void:
	draw_rect(Rect2(x, y, bar_width, BAR_HEIGHT), _BAR_TRACK, true)
	if not field.is_signed_bar:
		draw_rect(Rect2(x, y, bar_width * field.bar, BAR_HEIGHT), _BAR_FILL, true)
		return

	var middle := x + bar_width * 0.5
	draw_line(Vector2(middle, y), Vector2(middle, y + BAR_HEIGHT), _BAR_ZERO, 1.0)
	var span := bar_width * 0.5 * absf(field.bar)
	var left := middle if field.bar >= 0.0 else middle - span
	draw_rect(Rect2(left, y, span, BAR_HEIGHT), _BAR_FILL, true)


## 막대 폭. 좁은 열에서 막대가 값을 밀어내면 소속 인원이 잘린다.
func _bar_width(width: float) -> float:
	return clampf(width * 0.30, BAR_WIDTH_MIN, BAR_WIDTH_MAX)


## 칸이 비어 있을 때도 채워졌을 때의 높이를 잡는다.
##
## `expected_lines` 가 그 근거다 (SheetSection). **비어 있을 때 예뻐 보이는 높이로 잡으면
## 자료가 들어올 때 배치가 터진다** (설계 24.17.3).
func _body_height(section: SheetSection, width: float) -> float:
	if section.shape == SheetSection.Shape.FRAME:
		return width - PAD * 2.0

	var label_width := _label_width(width)
	var value_width := width - PAD * 2.0 - label_width
	var measured := 0.0
	for field in section.fields:
		if field.has_bar():
			measured += ROW_HEIGHT
			continue
		var lines := _font.get_multiline_string_size(
			field.display_text(), HORIZONTAL_ALIGNMENT_LEFT, value_width, BODY_SIZE
		)
		measured += maxf(ROW_HEIGHT, lines.y + 6.0)
	return maxf(measured, ROW_HEIGHT * float(section.expected_lines))


## 이름 칸의 폭. 열이 좁으면 이름도 좁아야 값이 들어간다.
func _label_width(width: float) -> float:
	return clampf(width * 0.34, 88.0, 150.0)
