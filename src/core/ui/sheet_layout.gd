class_name SheetLayout
extends RefCounted
## 인물 상세의 **자리를 정한다.** 노드도 그리기도 모르는 순수 계산이다.
##
## docs/design/20-ui-kit.md §20.23.3 · docs/design/24-npc-relations.md §24.17.3.
##
## ## 왜 그리기에서 떼어냈나
##
## `PersonSheetView._draw()` 는 **그리면서** 자리를 계산했다. 그림만 나가는 동안에는
## 그래도 됐다. 그런데 §4.1 이 *「클릭(터치)만으로 전부 조작 가능해야 한다」* 이므로
## **눌린 자리가 어느 줄인지**를 알아야 하고, 그러려면 같은 자리를 다시 계산해야 한다.
##
## > **계산이 둘이면 눈에 보이는 자리와 손이 닿는 자리가 서로 모르게 어긋난다.
## > 그리고 어긋난 것은 검사에 안 잡힌다** — 그림은 맞고 클릭도 「어딘가」에는 맞는다.
##
## 캡처가 시계를 직접 꽂던 것과 같은 모양이다(§20.22). **문이 둘이면 대역이 낀다.**
## 그래서 자리 배열이 **하나뿐이고** 그리기와 눌림이 둘 다 그것을 읽는다.
##
## ## 덤 — 배치를 헤드리스로 잰다
##
## 창 없이 「관계 칸이 왼쪽 열 아래에 있나」를 테스트가 묻는다.
## 지금까지 이 화면의 배치는 **눈으로만** 확인됐다.

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

## 막대의 최대 폭과 두께. 좁은 열에서는 폭에 비례해 줄인다 (`bar_width`).
const BAR_WIDTH_MAX := 150.0
const BAR_WIDTH_MIN := 70.0
const BAR_HEIGHT := 8.0

## 여러 줄 값이 줄 상자에 더 먹는 높이. `_draw_field` 가 쓰던 여백 그대로다.
const WRAP_PAD := 6.0

## 탭 띠. **화면 맨 위에 선다** — 탭이 아래에 있으면 「지금 어느 탭인가」를
## 내용을 다 읽은 뒤에 알게 된다.
const TAB_HEIGHT := 28.0
const TAB_WIDTH := 92.0
const TAB_GAP := 6.0

## 육각형 칸이 차지하는 높이. **정사각에 가깝게 잡는다** — 육각형을 납작하게 누르면
## 「얼마나 뚜렷한가」가 면적이 아니라 폭으로 읽힌다 (§20.25.3 규칙 3).
## **아래 여백 검사가 이 값의 상한을 정한다** — 306 으로 잡았더니 오른쪽 열이
## 666px 로 끝나 화면과 4px 만 남겼다 (§20.23.6 과 같은 자리).
const WHEEL_HEIGHT := 282.0

## 육각형 바깥에 이름이 앉을 자리. 여기를 아끼면 「무모」가 잘린다.
const WHEEL_LABEL_ROOM := 34.0

## 칸이 놓인 자리. `panel_of[i]` 가 `sections` 안의 인덱스다.
var panels: Array[Rect2] = []
var panel_of: PackedInt32Array = PackedInt32Array()

## 줄이 놓인 자리. `row_section[i]` · `row_field[i]` 가 그 줄의 출처다.
##
## 액자 칸(`FRAME`)과 육각형 칸은 줄을 안 낸다 — 눌러야 할 낱줄이 없고
## 칸 하나가 통째로 그림이다.
var rows: Array[Rect2] = []
var row_section: PackedInt32Array = PackedInt32Array()
var row_field: PackedInt32Array = PackedInt32Array()

## 탭 띠의 탭 하나하나. 없으면 탭 없는 화면이다.
var tabs: Array[Rect2] = []

## 육각형으로 그릴 칸들. `sections` 안의 인덱스다.
var wheels: PackedInt32Array = PackedInt32Array()


## 한 화면분의 자리를 전부 잡는다.
##
## `left` · `right` 는 열마다 위에서 아래로 놓을 칸 제목이다 (`PersonSheet.LEFT_TITLES`).
## **뷰가 제목 순서를 정하지 않는다** — 무엇이 어느 열에 오는가는 §24.17.3 의 선언이다.
static func build(
	sections: Array[SheetSection],
	view: Vector2,
	font: Font,
	left: Array,
	right: Array,
	wheel_titles: Array = [],
	tab_count: int = 0
) -> SheetLayout:
	var out := SheetLayout.new()
	if font == null:
		return out
	for title in wheel_titles:
		var index := out._index_of(sections, str(title))
		if index >= 0:
			out.wheels.append(index)

	var top := MARGIN
	for tab in tab_count:
		out.tabs.append(
			Rect2(MARGIN + float(tab) * (TAB_WIDTH + TAB_GAP), MARGIN, TAB_WIDTH, TAB_HEIGHT)
		)
	if tab_count > 0:
		top += TAB_HEIGHT + SECTION_GAP

	var right_x := MARGIN + LEFT_WIDTH + COLUMN_GAP
	out._column(sections, left, MARGIN, LEFT_WIDTH, top, font)
	out._column(sections, right, right_x, view.x - right_x - MARGIN, top, font)
	return out


## 점이 든 탭. 없으면 -1.
func tab_at(point: Vector2) -> int:
	for i in tabs.size():
		if tabs[i].has_point(point):
			return i
	return -1


## 이 칸을 육각형으로 그리나.
func is_wheel(section: int) -> bool:
	return wheels.has(section)


## 막대 폭. 좁은 열에서 막대가 값을 밀어내면 소속 인원이 잘린다.
static func bar_width(width: float) -> float:
	return clampf(width * 0.30, BAR_WIDTH_MIN, BAR_WIDTH_MAX)


## 이름 칸의 폭. 열이 좁으면 이름도 좁아야 값이 들어간다.
static func label_width(width: float) -> float:
	return clampf(width * 0.34, 88.0, 150.0)


## 한 줄이 차지하는 높이. **재는 자와 그리는 자가 이 하나를 쓴다.**
static func row_height(field: SheetField, value_width: float, font: Font) -> float:
	if field.has_bar():
		return ROW_HEIGHT
	var lines := font.get_multiline_string_size(
		field.display_text(), HORIZONTAL_ALIGNMENT_LEFT, value_width, BODY_SIZE
	)
	return maxf(ROW_HEIGHT, lines.y + WRAP_PAD)


## 점이 든 칸. 없으면 -1.
func section_at(point: Vector2) -> int:
	for i in panels.size():
		if panels[i].has_point(point):
			return panel_of[i]
	return -1


## 점이 든 줄. `Vector2i(칸, 필드)` 이고 없으면 `Vector2i(-1, -1)`.
##
## **칸만 맞고 줄이 안 맞는 자리가 있다** — 칸 아래쪽의 예비 높이(`expected_lines`)다.
## 그 자리는 「아직 안 채워진 곳」이라 줄이 없는 게 맞다.
func field_at(point: Vector2) -> Vector2i:
	for i in rows.size():
		if rows[i].has_point(point):
			return Vector2i(row_section[i], row_field[i])
	return Vector2i(-1, -1)


## 한 칸의 사각형. 없으면 크기 0.
func panel_rect(section: int) -> Rect2:
	for i in panels.size():
		if panel_of[i] == section:
			return panels[i]
	return Rect2()


func _column(
	sections: Array[SheetSection], titles: Array, x: float, width: float, top: float, font: Font
) -> void:
	var y := top
	for title in titles:
		var index := _index_of(sections, str(title))
		if index < 0:
			continue
		y += _place(sections, index, x, y, width, font) + SECTION_GAP


## 칸 하나를 놓고 그 높이를 낸다.
func _place(
	sections: Array[SheetSection], index: int, x: float, y: float, width: float, font: Font
) -> float:
	var section := sections[index]
	var height := TITLE_HEIGHT + _body_height(section, index, width, font) + PAD
	panels.append(Rect2(x, y, width, height))
	panel_of.append(index)
	if section.shape == SheetSection.Shape.FRAME or is_wheel(index):
		return height

	var value_width := width - PAD * 2.0 - label_width(width)
	var cursor := y + TITLE_HEIGHT
	for field in section.fields.size():
		var tall := row_height(section.fields[field], value_width, font)
		rows.append(Rect2(x, cursor, width, tall))
		row_section.append(index)
		row_field.append(field)
		cursor += tall
	return height


## 칸이 비어 있을 때도 채워졌을 때의 높이를 잡는다.
##
## `expected_lines` 가 그 근거다 (`SheetSection`). **비어 있을 때 예뻐 보이는 높이로 잡으면
## 자료가 들어올 때 배치가 터진다** (설계 24.17.3).
func _body_height(section: SheetSection, index: int, width: float, font: Font) -> float:
	if section.shape == SheetSection.Shape.FRAME:
		return width - PAD * 2.0
	# 육각형은 글 높이와 무관하다 — **도형이 자리를 정하지 자료가 정하지 않는다.**
	if is_wheel(index):
		return WHEEL_HEIGHT
	var value_width := width - PAD * 2.0 - label_width(width)
	var measured := 0.0
	for field in section.fields:
		measured += row_height(field, value_width, font)
	return maxf(measured, ROW_HEIGHT * float(section.expected_lines))


func _index_of(sections: Array[SheetSection], title: String) -> int:
	for i in sections.size():
		if sections[i].title == title:
			return i
	return -1
