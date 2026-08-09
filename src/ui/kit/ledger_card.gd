class_name LedgerCard
extends Control
## **글이 많은 화면을 `LedgerForm` 위에 얹는다.** 인물 상세(`PersonSheet`)가 내용이다.
##
## ## 재는 것과 그리는 것이 다르면 잰 값은 거짓말이다
##
## 앞 판(`DossierCard`)은 `draw_string(..., wide, ...)` 로 **자르면서** 그리고
## `get_string_size(..., -1, ...)` 로 **안 자르고** 쟀다. 그래서 「옆 73px 넘침」이
## 나왔는데 화면에서는 그 글자가 잘려 있었다. **넘친 것도 아니고 들어간 것도 아닌**
## 값이었다.
##
## 여기서는 배치 함수 하나를 **두 번 돈다** — 한 번은 안 그리고 재기만(`dry`),
## 한 번은 그리기만. 같은 코드라 잰 것과 그린 것이 어긋날 수 없다.
##
## ## 첫 바퀴가 이음매 자리를 낸다
##
## 안 그리는 바퀴가 **줄 상자 목록**을 남기고, 그것을 `LedgerLayout` 에 넘겨
## 두 열의 빈틈이 겹치는 자리를 얻는다. 그 자리만 이음매가 된다. 형태는
## 「몇 등분」을 모른 채로 층 경계를 받는다.

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

const TITLE_SIZE: int = 18
const SECTION_SIZE: int = 14
const LINE_SIZE: int = 13
const LINE_STEP: float = 16.0
const SECTION_GAP: float = 11.0

## 성향 막대의 길이. 6 축이 나란히 서야 축끼리 비교가 되므로 고정이다.
const BAR_WIDTH: float = 64.0

## 이름 칸이 줄에서 차지하는 비율. 값은 그 뒤부터다.
const LABEL_SHARE: float = 0.42

@export var form: LedgerForm.Kind = LedgerForm.Kind.STRATA
@export var person_name: String = ""

var sections: Array[SheetSection] = []

var _motion := PopupMotion.new()
var _driven := false

var _left: Array[Rect2] = []
var _right: Array[Rect2] = []
var _cuts := PackedFloat32Array()
var _edges := PackedFloat32Array()
var _reach := PackedFloat32Array()
var _event := Vector3.ZERO

## 글이 판 밖으로 나간 픽셀. `x` 오른쪽, `y` 아래.
var _overflow := Vector2.ZERO

## 이음매가 글줄을 가로지른 횟수. **이 형태 묶음이 0 을 목표로 만들어졌다.**
var _crossed := 0


func _ready() -> void:
	if not _driven:
		set_process(true)
		_motion.open()


func drive_externally() -> void:
	_driven = true
	set_process(false)


## 캡처가 시각을 직접 앉힌다.
func pose(phase: PopupMotion.Phase, clock: float, since_open: float, event: Vector3) -> void:
	_motion.phase = phase
	_motion.pose(clock, since_open, -1.0)
	_event = event
	queue_redraw()


func _process(delta: float) -> void:
	_motion.advance(delta)
	if _motion.phase == PopupMotion.Phase.OPENING:
		_motion.phase = PopupMotion.Phase.OPEN
	queue_redraw()


func overflow() -> Vector2:
	return _overflow


func crossings() -> int:
	return _crossed


## 판이 실제로 몇 조각인가. **층 경계 수가 아니다** — 「테만 부순다」는 이음매를
## 받아도 한 장이고 「겹친 장」은 이음매가 없어도 넉 장이다. 처음에 경계 수로
## 적었더니 화면의 숫자와 눈에 보이는 조각 수가 어긋났다.
func bands() -> int:
	return LedgerForm.bands(form, size, _cuts, _reach, _event).size()


## 판이 가로로 몇 층으로 나뉘었나. **조각 수와 다르다** — 「층계」는 층이 일곱이어도
## 한 장이다. 층은 오른쪽 변의 디딤으로만 드러난다.
func steps() -> int:
	return maxi(_edges.size() - 1, 1)


func _draw() -> void:
	var shown := _motion.presence()
	if shown <= 0.001:
		return
	_plan()
	var here := LedgerForm.bands(form, size, _cuts, _reach, _event)
	var count := here.size()
	for i in count:
		var piece := _fly(here[i], i, count)
		_stroke(piece, i, count, shown)
	for shard in LedgerForm.shards(form, size, _event):
		draw_colored_polygon(shard, Color(RULE_SOFT, 0.55 * shown))
	_ornament(shown)
	_write_sheet()


## 층 하나를 그린다. 그림자 — 채움 — 겹인쇄 — 테두리 순서다.
func _stroke(piece: PackedVector2Array, index: int, count: int, shown: float) -> void:
	if piece.is_empty():
		return
	var dropped := PackedVector2Array()
	for point in piece:
		dropped.append(point + Vector2(0.0, 4.0))
	draw_colored_polygon(dropped, Color(SHADOW, 0.45 * shown))

	# 층마다 명도를 살짝 벌린다. 골고루면 한 장으로 보이고 층이 있는 뜻이 사라진다.
	var turn := fposmod(0.11 + float(index) * 0.6180339887, 1.0)
	var lit := PLATE.lerp(PLATE_HIGH, 0.18 + 0.44 * turn)
	draw_colored_polygon(piece, Color(lit, shown))

	if LedgerForm.overprints(form) and index == _hottest(count):
		# **한 겹만** 겹인쇄한다. 전부 찍으면 골고루가 되어 밀도 대비가 죽는다(§20.9.4).
		var ghost := PackedVector2Array()
		for point in piece:
			ghost.append(point + LedgerForm.MISPRINT)
		draw_polyline(_closed(ghost), Color(ACCENT, 0.62 * shown), 1.4, true)
	draw_polyline(_closed(piece), Color(RULE, shown), 1.4, true)


## 형태마다 **한 자리에서만** 터진다. 골고루 뿌리면 죽는다(§20.9.4).
func _ornament(shown: float) -> void:
	match form:
		LedgerForm.Kind.TERRACE:
			# 챌판마다 강세 표. 계단이 곧 이 형태의 뜨거운 자리다.
			var rights := LedgerForm.step_rights(form, size, _cuts, _reach, _event)
			for i in rights.size():
				draw_rect(Rect2(rights[i] - 11.0, _edges[i] + 5.0, 9.0, 2.0), Color(ACCENT, shown))
		LedgerForm.Kind.RIM:
			var lane := LedgerForm.text_box(form, size).position.x - 6.0
			draw_rect(Rect2(lane, 44.0, 1.5, size.y - 60.0), Color(ACCENT, 0.8 * shown))
		LedgerForm.Kind.SHEAF:
			var step := size.x * 0.020
			for back in range(1, LedgerForm.SHEAF_DEPTH + 1):
				var x := size.x - step * float(LedgerForm.SHEAF_DEPTH - back)
				draw_rect(
					Rect2(x - 2.0, -step * float(back) * 0.42, 2.0, size.y),
					Color(ACCENT, 0.30 * float(back) / 3.0 * shown)
				)
		LedgerForm.Kind.DOCK:
			# 등뼈와 눈금. **눈금 간격은 절대값이다** — 판이 커진다고 성겨지지 않는다.
			draw_rect(Rect2(0.0, 0.0, 5.0, size.y), Color(ACCENT, 0.85 * shown))
			var y := 12.0
			while y < size.y - 8.0:
				var long_tick := 12.0 if int(y) % 45 < 9 else 6.0
				draw_rect(Rect2(7.0, y, long_tick, 1.0), Color(RULE, 0.7 * shown))
				y += 9.0
		LedgerForm.Kind.SCROLL:
			var win := LedgerForm.window(form, size)
			draw_rect(Rect2(20.0, win.position.y - 9.0, size.x - 40.0, 2.0), Color(ACCENT, shown))
			for i in 14:
				draw_rect(
					Rect2(20.0 + float(i) * 11.0, 20.0, 5.0, 5.0), Color(RULE_SOFT, 0.65 * shown)
				)
			# 창의 위아래 끝이 흐려진다. 글이 흘러 들어오고 나가는 자리다.
			for i in 7:
				var fade := float(i) / 7.0
				draw_rect(
					Rect2(win.position.x, win.position.y + float(i) * 2.0, win.size.x, 2.0),
					Color(PLATE_HIGH, (1.0 - fade) * 0.5 * shown)
				)
		_:
			pass


## 겹인쇄를 받을 층. **가장 많이 밀린 층**이라야 어긋남이 형태에서 읽힌다.
## 「겹친 장」은 조각이 겹쳐 있으므로 맨 앞장이다.
func _hottest(count: int) -> int:
	if form != LedgerForm.Kind.STRATA:
		return count - 1
	var best := 0
	for i in count:
		var here := absf(LedgerForm.band_shift(form, i, count, size, _event))
		if here > absf(LedgerForm.band_shift(form, best, count, size, _event)):
			best = i
	return best


func _fly(piece: PackedVector2Array, index: int, count: int) -> PackedVector2Array:
	var come := _motion.piece(index, count)
	var from := LedgerForm.entry(form, index, count, size)
	var grow := lerpf(LedgerForm.entry_scale(form), 1.0, come)
	var shift := from * (1.0 - come)
	var middle := size * 0.5
	var out := PackedVector2Array()
	for point in piece:
		out.append(middle + (point - middle) * grow + shift)
	return out


## 안 그리는 바퀴. **줄 상자를 재고 이음매 자리를 얻는다.**
func _plan() -> void:
	var box := LedgerForm.text_box(form, size)
	var column := (box.size.x - 18.0) * 0.5
	_left = []
	_right = []
	var floor_left := _column(PersonSheet.LEFT_TITLES, box.position, column, 1.0, true, _left)
	var floor_right := _column(
		PersonSheet.RIGHT_TITLES,
		Vector2(box.position.x + column + 18.0, box.position.y),
		column,
		1.0,
		true,
		_right
	)

	var bottom := maxf(floor_left, floor_right)
	var holes_left := LedgerLayout.gaps(_left, box.position.y, bottom)
	var holes_right := LedgerLayout.gaps(_right, box.position.y, bottom)
	# 이음매가 보이는 형태는 **두 열이 동시에 빈 자리**에만 설 수 있고, 안 보이는
	# 형태는 아무 데나 선다. 자유도가 네 배 다르다 — `LedgerForm.seam_shows()`.
	var where := (
		LedgerLayout.common(holes_left, holes_right)
		if LedgerForm.seam_shows(form)
		else LedgerLayout.merge(holes_left, holes_right)
	)
	_cuts = LedgerLayout.cuts(where, LedgerForm.max_bands(form) - 1)
	_edges = LedgerForm.edges(form, size, _cuts)
	var all_lines: Array[Rect2] = []
	all_lines.append_array(_left)
	all_lines.append_array(_right)
	_reach = LedgerLayout.reaches(all_lines, _edges)
	_crossed = 0
	if LedgerForm.seam_shows(form):
		_crossed = LedgerLayout.crossings(all_lines, _seams())

	var far := box.position.x
	for line in all_lines:
		far = maxf(far, line.end.x)
	_overflow = Vector2(maxf(0.0, far - box.end.x), maxf(0.0, bottom - box.end.y))


## 실제로 판이 갈린 자리. `_cuts` 중 형태가 받아들인 것만 남는다.
func _seams() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in range(1, maxi(_edges.size() - 1, 1)):
		out.append(_edges[i])
	return out


func _write_sheet() -> void:
	var shown := _motion.content()
	if shown <= 0.02:
		return
	var box := LedgerForm.text_box(form, size)
	var head := LedgerForm.title_at(form, size)
	draw_string(
		FONT, head, person_name, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, Color(INK, shown)
	)
	draw_rect(Rect2(head.x, head.y + 7.0, 24.0, 2.0), Color(ACCENT, shown))

	var column := (box.size.x - 18.0) * 0.5
	var spare: Array[Rect2] = []
	_column(PersonSheet.LEFT_TITLES, box.position, column, shown, false, spare)
	_column(
		PersonSheet.RIGHT_TITLES,
		Vector2(box.position.x + column + 18.0, box.position.y),
		column,
		shown,
		false,
		spare
	)
	if _overflow.x > 0.5:
		draw_rect(Rect2(box.end.x, 0.0, 2.0, size.y), Color(ALARM, 0.9 * shown))
	if _overflow.y > 0.5:
		draw_rect(Rect2(0.0, box.end.y, size.x, 2.0), Color(ALARM, 0.9 * shown))


## 열 하나. `dry` 면 아무것도 안 그리고 `into` 에 줄 상자만 쌓는다.
##
## **그리는 바퀴와 같은 함수다.** 다르면 잰 값이 화면과 어긋난다.
func _column(
	titles: Array, at: Vector2, wide: float, shown: float, dry: bool, into: Array[Rect2]
) -> float:
	var y := at.y
	for title in titles:
		var section := PersonSheet.section_of(sections, title)
		if section == null:
			continue
		var head_wide := FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, SECTION_SIZE).x
		if dry:
			into.append(Rect2(at.x, y - 12.0, head_wide, 20.0))
		else:
			draw_string(
				FONT,
				Vector2(at.x, y),
				title,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				SECTION_SIZE,
				Color(INK, shown)
			)
			draw_rect(Rect2(at.x, y + 4.0, wide, 1.0), Color(RULE_SOFT, 0.8 * shown))
		y += 16.0
		y = _section(section, Vector2(at.x, y), wide, shown, dry, into)
		y += SECTION_GAP
	return y


func _section(
	section: SheetSection, at: Vector2, wide: float, shown: float, dry: bool, into: Array[Rect2]
) -> float:
	if section.shape == SheetSection.Shape.FRAME:
		var side := minf(wide, 66.0)
		if dry:
			into.append(Rect2(at.x, at.y, side, side))
		else:
			draw_rect(Rect2(at.x, at.y, side, side), Color(RULE_SOFT, 0.28 * shown))
			draw_rect(Rect2(at.x, at.y, side, side), Color(RULE, 0.8 * shown), false, 1.0)
		return at.y + side + 4.0

	var y := at.y
	for field in section.fields:
		y = _field(field, Vector2(at.x, y), wide, shown, dry, into)
	return y


func _field(
	field: SheetField, at: Vector2, wide: float, shown: float, dry: bool, into: Array[Rect2]
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
		return _flow(text, at, wide, LINE_SIZE, Color(tone, shown), dry, into)

	var label_wide := wide * LABEL_SHARE
	_put(field.label, at, LINE_SIZE, Color(FAINT_INK, shown), dry, into)
	var value_x := at.x + label_wide
	if field.bar < 0.0:
		return _flow(
			text,
			Vector2(value_x, at.y),
			wide - label_wide,
			LINE_SIZE,
			Color(tone, shown),
			dry,
			into
		)

	if not dry:
		draw_rect(Rect2(value_x, at.y - 9.0, BAR_WIDTH, 5.0), Color(RULE_SOFT, 0.45 * shown))
		draw_rect(
			Rect2(value_x, at.y - 9.0, BAR_WIDTH * clampf(field.bar, 0.0, 1.0), 5.0),
			Color(ACCENT, shown)
		)
	# **막대 뒤에 값 글자가 붙는 줄이 앞 판을 옆으로 터뜨렸다**(§20.13.1).
	# 자리가 모자라면 자르지 않고 다음 줄로 내린다 — 잘린 글자는 넘친 것보다 나쁘다.
	var rest := wide - label_wide - BAR_WIDTH - 6.0
	var value_wide := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_SIZE).x
	if value_wide <= rest:
		_put(
			text, Vector2(value_x + BAR_WIDTH + 6.0, at.y), LINE_SIZE, Color(tone, shown), dry, into
		)
		return at.y + LINE_STEP
	return _flow(
		text,
		Vector2(value_x, at.y + LINE_STEP),
		wide - label_wide,
		LINE_SIZE,
		Color(tone, shown),
		dry,
		into
	)


## 글줄 하나. 재는 폭과 그리는 폭이 같은 곳이 여기뿐이다.
func _put(
	text: String, at: Vector2, points: int, tone: Color, dry: bool, into: Array[Rect2]
) -> void:
	var reach := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, points).x
	if dry:
		into.append(Rect2(at.x, at.y - float(points), reach, float(points) + 4.0))
		return
	draw_string(FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, points, tone)


## 폭에 맞춰 감아 여러 줄로 흘린다. **자르지 않는다** — 자르면 잰 값이 거짓이 된다.
func _flow(
	text: String, at: Vector2, wide: float, points: int, tone: Color, dry: bool, into: Array[Rect2]
) -> float:
	var y := at.y
	for line in _wrap(text, wide, points):
		_put(line, Vector2(at.x, y), points, tone, dry, into)
		y += LINE_STEP
	return y


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
