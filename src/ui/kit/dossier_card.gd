class_name DossierCard
extends Control
## **진짜 내용을 얹은 팝업.** `PersonSheet` 이 낸 칸들을 `PopupForm` 형태 위에 그린다.
##
## ## 왜 이것이 필요한가 — 형태 스물하나가 전부 견본 문구로만 검증됐다
##
## 「선만」이 낱말 하나(`출격`)에서는 살고 본문 두 줄에서는 죽었다.
## **내용이 형태를 죽인다.** 그런데 지금까지 만든 형태는 전부 「견본 문구가 든 상자」
## 안에서만 봤다. 사용자가 형태를 고르고 나서 실제 화면을 만들 때 안 되면 처음부터다.
##
## 인물 상세가 가장 가혹하다 — 이름 · 나이 · 길드 · **성향 6축 막대** · 관계 목록 ·
## **열전 여러 줄**이 한 창에 다 들어간다.
##
## ## 이 파일은 고치는 것이 아니라 **재는 것**이다
##
## 내용이 판을 넘치면 숨기거나 줄이지 않고 **넘친 만큼을 그대로 그리고 표시한다**
## (`overflow()`). 어느 형태가 어느 내용에서 무너지는지 보여 주는 것이 목적이므로
## 여기서 잘라 내면 **그 사실이 사라진다.**

const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")

const PLATE := Color("#c9d4e0")
const PLATE_HIGH := Color("#dde5ee")
const RULE := Color("#6f8098")
const RULE_SOFT := Color("#93a2b5")
const INK := Color("#212a37")
const BODY_INK := Color("#4a5768")
const FAINT_INK := Color("#7c8798")
const SHADOW := Color("#a8b1bd")
const ACCENT := Color("#c0705f")
const ALARM := Color("#b03a2b")

const TITLE_SIZE: int = 19
const SECTION_SIZE: int = 14
const LINE_SIZE: int = 13
const LINE_STEP: float = 17.0
const SECTION_GAP: float = 13.0

## 성향 막대의 길이. 6 축이 나란히 서야 하므로 고정이다.
const BAR_WIDTH: float = 64.0

@export var form: PopupForm.Kind = PopupForm.Kind.SHUTTER
@export var person_name: String = ""

var sections: Array[SheetSection] = []

var _motion := PopupMotion.new()
var _driven := false

## 내용이 판을 넘친 픽셀. `x` 는 오른쪽, `y` 는 아래다. **이 값이 이 화면의 결과물이다.**
##
## **처음에 아래로 넘친 것만 쟀다가 틀렸다.** 진짜 자료를 얹어 보니 성향 6 축의
## 값이 **옆으로** 삐져나갔는데 재는 쪽이 세로만 봐서 넷 다 「들어간다」로 나왔다.
## 화면에는 글자가 판 밖에 나가 있었다. **재는 축이 모자라면 없는 합격이 나온다.**
var _overflow := Vector2.ZERO

## 글이 조각 이음매를 가로지른 횟수. 낱말 하나는 걸쳐도 읽히지만 **문장은 끊긴다.**
var _cut := 0

## 이번 그리기에서 글자가 닿은 가장 오른쪽. 옆으로 넘쳤는지 재는 값이다.
var _widest := 0.0


func _ready() -> void:
	if not _driven:
		set_process(true)
		_motion.open()


func drive_externally() -> void:
	_driven = true
	set_process(false)


func pose(phase: PopupMotion.Phase, clock: float, since_open: float, since_close: float) -> void:
	_motion.phase = phase
	_motion.pose(clock, since_open, since_close)
	queue_redraw()


func _process(delta: float) -> void:
	_motion.advance(delta)
	if _motion.phase == PopupMotion.Phase.OPENING:
		_motion.phase = PopupMotion.Phase.OPEN
	queue_redraw()


## 마지막으로 그렸을 때 내용이 판을 얼마나 넘쳤나(px). `x` 오른쪽, `y` 아래.
func overflow() -> Vector2:
	return _overflow


## 글줄이 조각 이음매에 몇 번 잘렸나.
func cuts() -> int:
	return _cut


func _draw() -> void:
	var here := PopupForm.pieces(form, size)
	var count := here.size()
	var shown := _motion.presence()
	if shown <= 0.001:
		return
	var lit := PLATE.lerp(PLATE_HIGH, 0.35)
	for i in count:
		var piece := _fly(here[i], i, count)
		if piece.is_empty():
			continue
		var moved := PackedVector2Array()
		for point in piece:
			moved.append(point + Vector2(0.0, 5.0))
		draw_colored_polygon(moved, Color(SHADOW, 0.5 * shown))
		if PopupForm.filled(form):
			var step := 1.0 - absf(float(i) - float(count - 1) * 0.5) * 0.035
			draw_colored_polygon(piece, Color(lit.r * step, lit.g * step, lit.b * step, shown))
		draw_polyline(_closed(piece), Color(RULE, shown), 1.5, true)
	_draw_sheet()


func _fly(piece: PackedVector2Array, index: int, count: int) -> PackedVector2Array:
	var come := _motion.piece(index, count)
	var from := PopupForm.entry(form, index, count, size)
	var grow := lerpf(PopupForm.entry_scale(form), 1.0, come)
	var shift := from * (1.0 - come)
	var middle := size * 0.5
	var out := PackedVector2Array()
	for point in piece:
		out.append(middle + (point - middle) * grow + shift)
	return out


## 두 열. 왼쪽은 **이 사람이 누구와 엮여 있나**, 오른쪽은 **이 사람 자체**다
## (`PersonSheet` 모듈 주석). 열을 바꾸지 않는다 — 배치는 자료가 정한 것이다.
func _draw_sheet() -> void:
	var shown := _motion.content()
	if shown <= 0.02:
		return
	var box := PopupForm.body(form, size)
	var top := box.position.y - 6.0
	var floor_y := size.y - 14.0

	var head := Vector2(box.position.x, PopupForm.title_at(form).y)
	draw_string(
		FONT, head, person_name, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, Color(INK, shown)
	)
	draw_rect(Rect2(head.x, head.y + 8.0, 26.0, 2.0), Color(ACCENT, shown))

	_widest = 0.0
	var column := (box.size.x - 18.0) * 0.5
	var left := _draw_column(["생김새", "길드", "관계"], Vector2(box.position.x, top), column, shown)
	var right := _draw_column(
		["인물", "성향", "인물 열전"], Vector2(box.position.x + column + 18.0, top), column, shown
	)
	_overflow = Vector2(maxf(0.0, _widest - (size.x - 8.0)), maxf(0.0, maxf(left, right) - floor_y))
	_cut = _count_cuts(box)
	if _overflow.length() > 0.5:
		_mark_overflow(floor_y, shown)


func _draw_column(titles: Array, at: Vector2, wide: float, shown: float) -> float:
	var y := at.y
	for title in titles:
		var section := PersonSheet.section_of(sections, title)
		if section == null:
			continue
		draw_string(
			FONT,
			Vector2(at.x, y),
			title,
			HORIZONTAL_ALIGNMENT_LEFT,
			wide,
			SECTION_SIZE,
			Color(INK, shown)
		)
		draw_rect(Rect2(at.x, y + 4.0, wide, 1.0), Color(RULE_SOFT, 0.8 * shown))
		y += 15.0
		y = _draw_section(section, Vector2(at.x, y), wide, shown)
		y += SECTION_GAP
	return y


func _draw_section(section: SheetSection, at: Vector2, wide: float, shown: float) -> float:
	var y := at.y
	if section.shape == SheetSection.Shape.FRAME:
		# 초상 액자. 아직 그림이 없으므로 자리만 잡는다 — 자리를 안 잡으면
		# 그림이 들어올 때 배치가 통째로 밀린다.
		var side := minf(wide, 74.0)
		draw_rect(Rect2(at.x, y, side, side), Color(RULE_SOFT, 0.30 * shown))
		draw_rect(Rect2(at.x, y, side, side), Color(RULE, 0.8 * shown), false, 1.0)
		return y + side + 4.0

	for field in section.fields:
		y = _draw_field(field, Vector2(at.x, y), wide, shown)
	return y


## 글자 하나를 그리고 **닿은 오른쪽 끝을 기록한다.** 기록하지 않으면 옆으로
## 넘친 것을 못 잰다.
func _write(at: Vector2, text: String, wide: float, points: int, tone: Color) -> void:
	draw_string(FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, wide, points, tone)
	var reach := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, points).x
	_widest = maxf(_widest, at.x + reach)


## 조각 이음매가 글자 칸을 가로지르는 횟수. 세로 이음매만 센다 — 가로 이음매는
## 줄 사이로 지나가면 티가 안 나지만 세로 이음매는 **낱말을 자른다.**
func _count_cuts(box: Rect2) -> int:
	var seams := 0
	var pieces := PopupForm.pieces(form, size)
	if pieces.size() < 2:
		return 0
	for i in range(1, pieces.size()):
		var edge := PlateForm.bounds(pieces[i]).position.x
		if edge > box.position.x + 4.0 and edge < box.end.x - 4.0:
			seams += 1
	return seams


func _draw_field(field: SheetField, at: Vector2, wide: float, shown: float) -> float:
	var tone := BODY_INK
	var text := field.value
	if field.state == SheetField.State.MISSING:
		tone = FAINT_INK
		text = field.reason
	elif field.state == SheetField.State.HIDDEN:
		tone = FAINT_INK
		text = "가려짐"

	if field.label.is_empty():
		# 문장 한 줄. 열전이 이 모양이라 **줄이 감기면 세로로 자란다.**
		var wrapped := _wrap(text, wide, LINE_SIZE)
		for line in wrapped:
			_write(Vector2(at.x, at.y), line, wide, LINE_SIZE, Color(tone, shown))
			at.y += LINE_STEP
		return at.y

	_write(Vector2(at.x, at.y), field.label, wide * 0.5, LINE_SIZE, Color(FAINT_INK, shown))
	var value_x := at.x + wide * 0.42
	if field.bar >= 0.0:
		# 성향 6 축. **막대가 나란히 서야** 축끼리 비교가 된다.
		var mid := at.y - 4.0
		draw_rect(Rect2(value_x, mid, BAR_WIDTH, 5.0), Color(RULE_SOFT, 0.45 * shown))
		draw_rect(
			Rect2(value_x, mid, BAR_WIDTH * clampf(field.bar, 0.0, 1.0), 5.0), Color(ACCENT, shown)
		)
		_write(Vector2(value_x + BAR_WIDTH + 6.0, at.y), text, wide, LINE_SIZE, Color(tone, shown))
	else:
		_write(Vector2(value_x, at.y), text, wide - wide * 0.42, LINE_SIZE, Color(tone, shown))
	return at.y + LINE_STEP


## 넘친 자리를 **가리지 않고 표시한다.** 이 화면의 목적이 그것이다.
func _mark_overflow(floor_y: float, shown: float) -> void:
	if _overflow.y > 0.5:
		draw_rect(Rect2(0.0, floor_y, size.x, 2.0), Color(ALARM, 0.9 * shown))
	if _overflow.x > 0.5:
		draw_rect(Rect2(size.x - 8.0, 0.0, 2.0, size.y), Color(ALARM, 0.9 * shown))


## 글자 폭으로 줄을 감는다. 열전이 문장이라 감기고, **감기면 세로로 자란다.**
func _wrap(text: String, wide: float, points: int) -> Array[String]:
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


func _closed(shape: PackedVector2Array) -> PackedVector2Array:
	var out := shape.duplicate()
	out.append(shape[0])
	return out
