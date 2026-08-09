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

## 탭 띠. 고른 탭만 면이 차고 나머지는 선뿐이다 — **면이 「여기 있다」를 말한다.**
const _TAB_ON := Color(1.0, 1.0, 1.0, 0.10)
const _TAB_OFF := Color(1.0, 1.0, 1.0, 0.02)
const _TAB_EDGE := Color(1.0, 1.0, 1.0, 0.20)

## 성향 육각형. 면 · 선 · 점선 셋뿐이다 (§20.25.3).
const _WHEEL_FILL := Color(0.63, 0.71, 0.86, 0.22)
const _WHEEL_EDGE := Color(0.72, 0.82, 0.98, 0.92)
const _WHEEL_FRAME := Color(1.0, 1.0, 1.0, 0.14)

## 극 경계 육각형. **이 선 밖으로 나간 꼭짓점이 딱지에 이름이 적히는 축이다.**
const _WHEEL_POLE := Color(0.93, 0.78, 0.52, 0.55)

## 인구 중앙값 눈금. 막대 위에 서는 선 하나다.
const _MARK := Color(1.0, 0.98, 0.90, 0.85)

## 계열 도형이 앉는 자리와 크기. **머리 칸 오른쪽 위**다 — 이름 옆이라
## 「이 이름이 어느 계열인가」가 한 눈에 붙는다.
const _DISCIPLINE_RADIUS := 15.0
const _DISCIPLINE_INSET := 26.0

## 유명세가 만드는 도드라짐. **테 하나뿐이다** — 실측에서 유명세는 여섯을 가르는 값이
## 아니라 한 명을 튀게 하는 값이었다 (§20.25.7).
const _STANDOUT := Color(1.0, 0.94, 0.72)

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

## 지금 고른 탭. 자리 계산과 그리기가 이 하나를 본다.
var _tab := SheetTab.Kind.ENCOUNTER

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


## 탭을 고른다. **칸이 바뀌는 게 아니라 세우는 칸이 바뀐다** (§20.25.4).
func show_tab(tab: SheetTab.Kind) -> void:
	if tab == _tab:
		return
	_tab = tab
	_hover = Vector2i(-1, -1)
	_note = ""
	_relayout()


## 지금 고른 탭.
func tab() -> SheetTab.Kind:
	return _tab


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
		_sections,
		size,
		_font,
		PersonSheet.left_titles(_tab),
		PersonSheet.right_titles(_tab),
		PersonSheet.wheel_titles(_tab),
		SheetTab.count()
	)
	queue_redraw()


func _draw() -> void:
	if _font == null or _sections.is_empty():
		return
	_draw_tabs()
	for i in _layout.panels.size():
		_draw_panel(_layout.panels[i], _sections[_layout.panel_of[i]], _layout.panel_of[i])
	for i in _layout.rows.size():
		var section := _sections[_layout.row_section[i]]
		var field := section.fields[_layout.row_field[i]]
		var here := Vector2i(_layout.row_section[i], _layout.row_field[i])
		_draw_field(field, _layout.rows[i], here == _hover)
	_draw_note()


## 탭 띠. 고른 것만 면이 차고 나머지는 선뿐이다.
func _draw_tabs() -> void:
	for i in _layout.tabs.size():
		var box := _layout.tabs[i]
		var chosen := i == int(_tab)
		draw_rect(box, _TAB_ON if chosen else _TAB_OFF, true)
		draw_rect(box, _TAB_EDGE, false, 1.0)
		# 고른 탭은 아래 변을 지운다 — **탭과 내용이 한 덩어리라는 말**이다.
		if chosen:
			draw_line(
				Vector2(box.position.x + 1.0, box.end.y),
				Vector2(box.end.x - 1.0, box.end.y),
				_TAB_ON,
				2.0
			)
		draw_string(
			_font,
			Vector2(box.position.x, box.position.y + SheetLayout.TAB_HEIGHT - 9.0),
			SheetTab.label(i as SheetTab.Kind),
			HORIZONTAL_ALIGNMENT_CENTER,
			box.size.x,
			SheetLayout.BODY_SIZE,
			_TITLE if chosen else _LABEL
		)


func _draw_panel(frame: Rect2, section: SheetSection, index: int) -> void:
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
	elif _layout.is_wheel(index):
		_draw_wheel(section, frame)
	elif section.title == "인물":
		_draw_discipline(section, frame)


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


## 계열 도형 (§20.25.7). **변 수가 계열마다 다르다** — 작게 그려도, 색을 못 봐도 갈린다.
##
## 실측이 이 자리를 정했다: 조우 스쿼드 여섯에서 **소속은 전혀 안 갈리고 계열이
## 가장 잘 갈린다.** 얼굴이 3000명분 안 나오므로 **여섯을 가르는 일이 곧 계열을
## 그리는 일**이다. 상세와 스쿼드가 `DisciplineMark` 한 표를 같이 쓴다.
func _draw_discipline(section: SheetSection, frame: Rect2) -> void:
	if section.numbers.is_empty():
		return
	var kind := section.numbers[0] as MemberDiscipline.Kind
	var at := Vector2(frame.end.x - _DISCIPLINE_INSET, frame.position.y + _DISCIPLINE_INSET)
	var shape := DisciplineMark.points(kind, at, _DISCIPLINE_RADIUS)
	draw_colored_polygon(shape, DisciplineMark.fill(kind))
	draw_polyline(_closed(shape), _BORDER, 1.0)

	# 유명세는 **테 하나로만** 말한다. 모두에게 조금씩 주면 「여섯이 다 좀 유명하다」가 된다.
	var fame := _fame_of(section)
	if fame <= 0.0:
		return
	var ring := DisciplineMark.points(kind, at, _DISCIPLINE_RADIUS + 5.0)
	draw_polyline(_closed(ring), Color(_STANDOUT, fame), 1.0 + fame * 2.0)


## 머리 칸의 유명세 비율. 막대가 이미 들고 있는 값을 쓴다 —
## **인구를 따로 들여다보면 테와 막대가 갈라진다.**
func _fame_of(section: SheetSection) -> float:
	for field in section.fields:
		if field.has_bar():
			return DisciplineMark.standout(int(field.bar * 100.0), 100)
	return 0.0


## 성향 육각형 (§20.25.3). **도형 · 선 · 면 셋뿐이다.**
##
## 딱지는 칸 아래에 한 줄로 남는다 — 육각형이 모양을 말하고 딱지가 이름을 말한다.
func _draw_wheel(section: SheetSection, frame: Rect2) -> void:
	var traits := section.numbers
	if traits.size() < NpcAxis.count():
		return
	# 딱지 한 줄을 아래에 남기고 나머지를 육각형이 다 쓴다. **작게 그리면 면적이
	# 「얼마나 뚜렷한가」를 못 말한다** (§20.25.3 규칙 3).
	var top := frame.position.y + SheetLayout.TITLE_HEIGHT
	var room := SheetLayout.WHEEL_HEIGHT - SheetLayout.TITLE_SIZE - SheetLayout.PAD * 2.0
	var center := Vector2(frame.position.x + frame.size.x * 0.5, top + room * 0.5)
	var radius := minf(room * 0.5, frame.size.x * 0.5) - SheetLayout.WHEEL_LABEL_ROOM

	# 바깥 틀과 극 경계. **극 경계가 이 도형의 뜻을 만든다** — 그 선 밖의 꼭짓점이
	# 곧 딱지에 이름이 적히는 축이다.
	draw_polyline(_closed(TraitWheel.ring(center, radius, 1.0)), _WHEEL_FRAME, 1.0)
	_draw_dashed(_closed(TraitWheel.ring(center, radius, TraitWheel.pole_ratio())), _WHEEL_POLE)
	for axis in NpcAxis.count():
		draw_line(center, TraitWheel.label_point(axis, center, radius, 0.0), _WHEEL_FRAME, 1.0)

	var shape := TraitWheel.points(traits, center, radius)
	draw_colored_polygon(shape, _WHEEL_FILL)
	draw_polyline(_closed(shape), _WHEEL_EDGE, 2.0)

	# 꼭짓점 이름이 **부호를 말한다** (§20.25.3 규칙 1).
	for axis in NpcAxis.count():
		var at := TraitWheel.label_point(axis, center, radius, SheetLayout.WHEEL_LABEL_ROOM * 0.52)
		var pole := TraitDistribution.is_pole(traits[axis])
		draw_string(
			_font,
			at - Vector2(44.0, -5.0),
			TraitWheel.vertex_label(axis, traits[axis]),
			HORIZONTAL_ALIGNMENT_CENTER,
			88.0,
			SheetLayout.BODY_SIZE,
			_VALUE if pole else _LABEL
		)

	if section.fields.is_empty():
		return
	# 딱지는 **육각형 바로 아래**다. 멀리 두면 이름과 얼굴이 따로 논다.
	draw_string(
		_font,
		Vector2(frame.position.x + SheetLayout.PAD, top + room + SheetLayout.TITLE_SIZE),
		section.fields[0].display_text(),
		HORIZONTAL_ALIGNMENT_CENTER,
		frame.size.x - SheetLayout.PAD * 2.0,
		SheetLayout.TITLE_SIZE,
		_VALUE
	)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	if not out.is_empty():
		out.append(out[0])
	return out


## 점선. `draw_dashed_line` 은 선분마다 부르면 이음매가 어긋나므로 직접 나눈다.
func _draw_dashed(points: PackedVector2Array, color: Color) -> void:
	for i in points.size() - 1:
		draw_dashed_line(points[i], points[i + 1], color, 1.0, 5.0)


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
		_draw_mark(field, x, y, bar_width)
		return

	var middle := x + bar_width * 0.5
	draw_line(Vector2(middle, y), Vector2(middle, y + SheetLayout.BAR_HEIGHT), _BAR_ZERO, 1.0)
	var span := bar_width * 0.5 * absf(field.bar)
	var left := middle if field.bar >= 0.0 else middle - span
	draw_rect(Rect2(left, y, span, SheetLayout.BAR_HEIGHT), _BAR_FILL, true)


## 인구 중앙값 눈금. **막대 위로 조금 넘치게 긋는다** — 막대 안에만 있으면
## 채워진 부분에 묻혀 안 보인다.
func _draw_mark(field: SheetField, x: float, y: float, bar_width: float) -> void:
	if not field.has_mark():
		return
	var at := x + bar_width * field.mark
	draw_line(Vector2(at, y - 2.0), Vector2(at, y + SheetLayout.BAR_HEIGHT + 2.0), _MARK, 1.0)


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
