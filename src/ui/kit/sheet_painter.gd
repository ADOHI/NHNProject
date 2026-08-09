class_name SheetPainter
extends RefCounted
## **인물 상세의 글을 상자 하나에 앉힌다.** 판이 어떻게 생겼는지는 모른다.
##
## `LedgerCard` 안에 있던 배치·그리기를 떼어냈다. 떼어낸 이유는 셋이다.
##
## | 왜 | 무엇 |
## | --- | --- |
## | **떠 있는 창**이 같은 글을 그린다 | 세 번째로 같은 코드를 쓸 참이었다 |
## | **열 수가 창 폭에 따라 바뀐다** | 좁은 창에서 두 열이 되는지 재려면 열 수가 값이어야 한다 |
## | 판과 글이 붙어 있으면 못 잰다 | 형태를 안 바꾸고 글만 바꿔 비교할 수 없었다 |
##
## ## 배치 함수를 두 번 돈다
##
## 한 번은 안 그리고 재기만(`plan`), 한 번은 그리기만(`paint`). **같은 코드다.**
## 앞 판은 `draw_string(..., wide, ...)` 로 자르면서 `get_string_size(..., -1, ...)` 로
## 안 자르고 쟀고, 그래서 「옆 73px 넘침」이라는 **있지도 않은 값**을 냈다
## (docs/design/20-ui-kit.md §20.13.0).

const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")

const INK := Color("#212a37")
const BODY_INK := Color("#4a5768")
const FAINT_INK := Color("#7c8798")
const RULE := Color("#6f8098")
const RULE_SOFT := Color("#93a2b5")
const ACCENT := Color("#c0705f")

const SECTION_SIZE: int = 14
const LINE_SIZE: int = 13
const LINE_STEP: float = 16.0
const SECTION_GAP: float = 11.0

## 열과 열 사이. **비율이 아니라 절대값이다** — 손이 읽는 사이라 창 크기와 무관하다.
const COLUMN_GAP: float = 18.0

## 성향 막대의 길이. 6 축이 나란히 서야 축끼리 비교가 된다.
const BAR_WIDTH: float = 64.0

## 이름 칸이 줄에서 차지하는 비율.
const LABEL_SHARE: float = 0.42

## 열 하나가 이보다 좁으면 두 열이 아니라 **두 줄**이다(px).
##
## 막대 줄은 이름(폭의 42%) + 막대 64px + 값이 한 줄에 들어가야 뜻이 있다.
## 그보다 좁으면 축마다 값이 다음 줄로 내려가 **줄 수가 두 배가 되고 열을 나눈 이득이
## 사라진다.** 실제로 256px 도킹 창에서 두 열을 시켰더니 한 줄에 두세 글자가 됐다.
const MIN_COLUMN: float = 190.0

## 한 열로 갈 때의 칸 순서. 두 열일 때의 왼쪽 · 오른쪽을 그냥 이어 붙이면
## **「누구와 엮였나」와 「이 사람 자체」가 뒤섞인다**(PersonSheet 모듈 주석).
## 사람 자체를 먼저 세우고 관계를 뒤에 둔다.
## **두 열 목록과 같은 칸을 담아야 한다** — 안 그러면 같은 카드가 폭에 따라 다른 것을
## 보여 준다. `test_sheet_painter_order.gd` 가 그것을 지킨다.
const SINGLE_ORDER := ["면식", "생김새", "인물", "위협", "성향", "길드", "신원", "관계", "인물 열전"]

var sections: Array[SheetSection] = []

## 이 상자에 넣을 칸만 골라 적는다. 비면 인물 상세 전부다.
##
## **떠 있는 창은 창마다 다른 칸을 든다** — 그게 창이 여럿인 이유다.
## 정보 설계 명세가 오면 이 배정이 명세에서 온다.
var only: Array = []

## 열이 몇이나. **1 과 2 만 뜻이 있다** — 3 열이면 인물 상세의 칸 하나가 열보다 넓다.
var columns: int = 2

## 글이 위로 얼마나 흘러 올라갔나(px).
var scroll := 0.0

## 상자 밖으로 나간 줄을 안 그리는가. **줄 단위로 자른다** — 픽셀로 자르면
## 창 끝에서 글자가 반만 남아 「고장난 것」으로 읽힌다.
var paged := false

## 마지막으로 잰 줄 상자 전부.
var lines: Array[Rect2] = []

## 열마다의 줄 상자. 이음매가 설 자리를 찾을 때 **열별로** 있어야 한다 —
## 두 열이 동시에 비는 자리만 이음매가 될 수 있기 때문이다(§20.14.3).
var by_column: Array = []

## 글이 끝난 높이.
var bottom := 0.0

## 글이 닿은 가장 오른쪽.
var widest := 0.0

var _box := Rect2()


## 안 그리고 재기만 한다.
func plan(box: Rect2) -> void:
	_run(null, box, 1.0)


## 재면서 그린다. `plan()` 과 같은 코드를 돈다.
func paint(on: CanvasItem, box: Rect2, alpha: float) -> void:
	_run(on, box, alpha)


## 이 열 수로 상자에 들어가나. **좁은 창에서 두 열이 되는지 재는 자다.**
##
## **`paged` 를 반드시 꺼고 잰다.** 켠 채로 재면 넘친 줄이 애초에 안 그려져서
## `bottom` 이 상자를 넘을 수가 없고, **무슨 폭을 주든 「들어간다」가 나온다.**
## 처음에 그렇게 만들었고 256px 창이 두 열로 통과했다.
func fits(box: Rect2, how_many: int) -> bool:
	var wide := (box.size.x - COLUMN_GAP * float(how_many - 1)) / float(how_many)
	if wide < MIN_COLUMN:
		return false
	var was_columns := columns
	var was_paged := paged
	columns = how_many
	paged = false
	plan(box)
	var ok := widest <= box.end.x + 0.5
	columns = was_columns
	paged = was_paged
	return ok


func _run(on: CanvasItem, box: Rect2, alpha: float) -> void:
	_box = box
	lines = []
	by_column = []
	widest = box.position.x
	bottom = box.position.y

	var groups := _groups()
	var wide := (box.size.x - COLUMN_GAP * float(groups.size() - 1)) / float(groups.size())
	for i in groups.size():
		var here: Array[Rect2] = []
		var at := Vector2(box.position.x + (wide + COLUMN_GAP) * float(i), box.position.y - scroll)
		bottom = maxf(bottom, _column(on, groups[i], at, wide, alpha, here))
		by_column.append(here)
		lines.append_array(here)
	for line in lines:
		widest = maxf(widest, line.end.x)


## 열마다 어느 칸이 들어가나.
func _groups() -> Array:
	if not only.is_empty():
		# 칸이 하나뿐이면 열을 나눌 것이 없다. 나누면 **한쪽이 빈 열**이 되고
		# 화면에 적히는 「2 열」이 거짓말이 된다.
		if columns <= 1 or only.size() < 2:
			return [only]
		var half := int(ceil(float(only.size()) * 0.5))
		return [only.slice(0, half), only.slice(half)]
	if columns <= 1:
		return [SINGLE_ORDER]
	return [PersonSheet.LEFT_TITLES, PersonSheet.RIGHT_TITLES]


func _column(
	on: CanvasItem, titles: Array, at: Vector2, wide: float, alpha: float, into: Array[Rect2]
) -> float:
	var y := at.y
	for title in titles:
		var section := PersonSheet.section_of(sections, title)
		if section == null:
			continue
		if _in_view(y - 12.0, 20.0):
			if on == null:
				var head := FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, SECTION_SIZE)
				into.append(Rect2(at.x, y - 12.0, head.x, 20.0))
			else:
				on.draw_string(
					FONT,
					Vector2(at.x, y),
					title,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					SECTION_SIZE,
					Color(INK, alpha)
				)
				on.draw_rect(Rect2(at.x, y + 4.0, wide, 1.0), Color(RULE_SOFT, 0.8 * alpha))
		y += 16.0
		y = _section(on, section, Vector2(at.x, y), wide, alpha, into)
		y += SECTION_GAP
	return y


func _section(
	on: CanvasItem,
	section: SheetSection,
	at: Vector2,
	wide: float,
	alpha: float,
	into: Array[Rect2]
) -> float:
	if section.shape == SheetSection.Shape.FRAME:
		var side := minf(wide, 66.0)
		if not _in_view(at.y, side):
			return at.y + side + 4.0
		if on == null:
			into.append(Rect2(at.x, at.y, side, side))
		else:
			on.draw_rect(Rect2(at.x, at.y, side, side), Color(RULE_SOFT, 0.28 * alpha))
			on.draw_rect(Rect2(at.x, at.y, side, side), Color(RULE, 0.8 * alpha), false, 1.0)
		return at.y + side + 4.0

	var y := at.y
	for field in section.fields:
		y = _field(on, field, Vector2(at.x, y), wide, alpha, into)
	return y


func _field(
	on: CanvasItem, field: SheetField, at: Vector2, wide: float, alpha: float, into: Array[Rect2]
) -> float:
	var tone := BODY_INK
	var text := field.value
	if field.state == SheetField.State.MISSING:
		tone = FAINT_INK
		text = field.reason
	elif field.state == SheetField.State.HIDDEN:
		tone = FAINT_INK
		text = "가려짐"

	if field.label.is_empty():
		return _flow(on, text, at, wide, Color(tone, alpha), into)

	var label_wide := wide * LABEL_SHARE
	_put(on, field.label, at, LINE_SIZE, Color(FAINT_INK, alpha), into)
	var value_x := at.x + label_wide
	if not field.has_bar():
		return _flow(on, text, Vector2(value_x, at.y), wide - label_wide, Color(tone, alpha), into)

	if on != null and _in_view(at.y - 13.0, 17.0):
		on.draw_rect(Rect2(value_x, at.y - 9.0, BAR_WIDTH, 5.0), Color(RULE_SOFT, 0.45 * alpha))
		# **부호 있는 막대는 가운데에서 좌우로 자란다.** 0 으로 자르면 축값이 음수인
		# 사람의 막대가 통째로 빈 칸이 된다 — 그게 정확히 `NO_BAR` 사고의 짝이다.
		var span := BAR_WIDTH * (0.5 if field.is_signed_bar else 1.0) * absf(field.bar)
		var from_x := value_x
		if field.is_signed_bar:
			from_x = value_x + BAR_WIDTH * 0.5 - (span if field.bar < 0.0 else 0.0)
			on.draw_rect(
				Rect2(value_x + BAR_WIDTH * 0.5, at.y - 11.0, 1.0, 9.0), Color(RULE, 0.6 * alpha)
			)
		on.draw_rect(Rect2(from_x, at.y - 9.0, span, 5.0), Color(ACCENT, alpha))
	# **막대 뒤에 값 글자가 붙는 줄이 앞 판을 터뜨렸다**(§20.13). 자리가 모자라면
	# 자르지 않고 다음 줄로 내린다 — 잘린 글자는 넘친 것보다 나쁘다.
	var rest := wide - label_wide - BAR_WIDTH - 6.0
	var value_wide := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_SIZE).x
	if value_wide <= rest:
		_put(
			on, text, Vector2(value_x + BAR_WIDTH + 6.0, at.y), LINE_SIZE, Color(tone, alpha), into
		)
		return at.y + LINE_STEP
	return _flow(
		on, text, Vector2(value_x, at.y + LINE_STEP), wide - label_wide, Color(tone, alpha), into
	)


## 이 줄이 상자 안에 온전히 들어오나. 페이지 모드가 아니면 늘 참이다.
func _in_view(top: float, tall: float) -> bool:
	if not paged:
		return true
	return top >= _box.position.y - 1.0 and top + tall <= _box.end.y + 1.0


func _put(
	on: CanvasItem, text: String, at: Vector2, points: int, tone: Color, into: Array[Rect2]
) -> void:
	if not _in_view(at.y - float(points), float(points) + 4.0):
		return
	if on == null:
		var reach := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, points).x
		into.append(Rect2(at.x, at.y - float(points), reach, float(points) + 4.0))
		return
	on.draw_string(FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, points, tone)


## 폭에 맞춰 감아 여러 줄로 흘린다. **자르지 않는다.**
func _flow(
	on: CanvasItem, text: String, at: Vector2, wide: float, tone: Color, into: Array[Rect2]
) -> float:
	var y := at.y
	for line in fold(text, wide, LINE_SIZE):
		_put(on, line, Vector2(at.x, y), LINE_SIZE, tone, into)
		y += LINE_STEP
	return y


## 낱말 사이에서만 감는다. 낱말 안에서 끊으면 읽기가 무너진다.
##
## **이름이 `wrap` 이면 안 된다** — Godot 전역 유틸 `wrap()` 과 부딪혀 그쪽이 불린다.
## `--import` 0 에러 · GUT 762 통과 · 린트 통과였고 **씬을 띄우자 터졌다.**
static func fold(text: String, wide: float, points: int) -> Array[String]:
	var out: Array[String] = []
	var line := ""
	for word in text.split(" ", false):
		var trial := word if line.is_empty() else line + " " + word
		if FONT.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, points).x > wide:
			if not line.is_empty():
				out.append(line)
			line = word
		else:
			line = trial
	if not line.is_empty():
		out.append(line)
	return out
