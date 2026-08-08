class_name ActionButton
extends BaseButton
## 게임에 그대로 들어가는 **버튼 한 개.** 「출격」 · 「탐사 개시」가 이것이다.
##
## 확인 화면은 `src/ui/kit/button_bench.tscn` (docs/design/20-ui-kit.md §20.8).
##
## ## 배색 — 채도 낮은 파스텔, 디지털
##
## 검정 + 금 판본은 **「진짜 20년 전 중국 게임 UI」**로 폐기됐다. 금 테두리 ·
## 놋쇠 무늬 · 빗금이 정확히 그 시절 MMO 버튼의 세 요소였다. 재질 묘사를 전부
## 걷어내고 **밝고 채도 낮은 파스텔**로 간다. 재료가 아니라 **화면**의 느낌이다.
##
## | 하지 않는다 | 왜 |
## | --- | --- |
## | 금 테두리 · 금속 질감 · 빗금 | 그 셋이 폐기 사유였다 |
## | 네온 · 홀로그램 · 글로우 | 세 번 배제됐다 |
## | 말랑한 볼록 · 흐린 그림자 · 안쪽 그림자 | 뉴모피즘. 아주 많이 복제된 기본값이다 |
## | 반투명 유리판 | 글래스모피즘. 같은 이유 |
##
## **채도만 낮추고 명도는 벌린다.** 상태 넷도 색상이 아니라 **명도 순서**로 갈린다 —
## 비활성 < 평상 < 커서, 눌림은 혼자 뒤집힌다.
##
## ## 화려함은 평상이 아니라 **사건**에 있다
##
## 가만히 있을 때 화려하면 시끄럽고 손이 닿을 때 화려하면 반응이다. 그래서 평상은
## 조용하고, 커서에서 **밀도가 폭발**하고(눈금 · 모서리 표 · 게이지가 늘어난다),
## 눌림에서 **여럿이 한 시각에 번쩍인다.** 그 낙차가 화려함이다.
##
## ## 형태는 `PlateForm` 이 정한다 — 여덟 판 동안 안 건드린 축
##
## 윤곽 · 글자의 자리와 각도 · 판이 몇 장인가가 전부 거기 있다. 이 파일은 **색과
## 거동만** 안다. 사각형에 장식을 붙이면 아무리 해도 「장식 붙인 사각형」이다.

const MOTION_STATE := ActionButtonMotion.State

const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")

## 글자 자간. 자간이 0 이면 두 글자 낱말이 뭉쳐 보인다.
const TRACKING: float = 3.0

## 안쪽 괘선이 바깥에서 떨어진 거리. 두 줄이 있어야 **테두리를 가진 화면**으로
## 읽힌다. 한 줄이면 그냥 색면이다.
const INSET: float = 4.5

## 그림자가 밀린 거리. 흐리지 않으므로 이 값이 곧 깊이다.
const DROP: float = 3.0

## 좌우 대칭으로 그리는 것들이 도는 방향. 배열에 형을 안 주면 원소가 Variant 가
## 되어 산술에서 형 추론이 끊긴다.
const _SIDES: Array[float] = [-1.0, 1.0]

const PLATE := Color("#c2cedc")
const HOVER_PLATE := Color("#dae4ef")
const PRESS_PLATE := Color("#4f6379")
const RULE := Color("#6f8098")
const RULE_SOFT := Color("#93a2b5")
const INK := Color("#212a37")
const INK_ON_PRESS := Color("#eef3f9")
const SHADOW := Color("#b6bec9")
const ACCENT := Color("#c0705f")
const ACCENT_SOFT := Color("#d79c8e")
const DEAD_TOP := Color("#d8dbdf")
const DEAD_RULE := Color("#aab0b8")
const DEAD_INK := Color("#6d7681")

## 화면에 나갈 글자. 「출격」 「탐사 개시」 같은 실제 문구가 들어간다.
@export var text: String = "출격":
	set(value):
		text = value
		_refresh_size()
		queue_redraw()

## 판의 형태. **색도 거동도 안 바꾸고 이것만 갈아 끼운다.**
@export var form: PlateForm.Kind = PlateForm.Kind.SLAB:
	set(value):
		form = value
		_refresh_size()
		queue_redraw()

var _motion := ActionButtonMotion.new()
var _was_hovering := false
var _was_holding := false

## 지금 프레임의 판 변형(떠오름 · 눌림 압축). 기운 글자가 여기에 얹혀야 하므로
## 값을 들고 있는다 — `draw_set_transform` 은 **덮어쓰기**라 곱해 줄 것이 필요하다.
var _plate_xform := Transform2D.IDENTITY

## 참이면 밖에서 시계를 앉힌다. **`_ready()` 도 이걸 본다** — 안 보면 되살아난다.
var _driven := false

## 비활성은 정지 화면이다. 한 장 그린 뒤로는 다시 그리지 않는다.
var _static_drawn := false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_refresh_size()
	if not _driven:
		set_process(true)


## 캡처 도구가 시계를 잡는다. **`add_child()` 앞에서 불러야 한다.**
func drive_externally() -> void:
	_driven = true
	set_process(false)


## 밖에서 시각을 앉힌다. 프레임 번호에서 계산해 넣으면 캡처가 재현된다.
func pose(
	state: ActionButtonMotion.State,
	ambient: float,
	since_hover: float,
	since_down: float,
	since_up: float
) -> void:
	_motion.state = state
	var leave := -1.0 if since_hover >= 0.0 else 0.6
	_motion.pose(ambient, since_hover, leave, since_down, since_up)
	queue_redraw()


## 확인 화면이 네 상태를 나란히 세울 때 쓴다. 자리잡은 뒤의 모습을 앉힌다.
func preview(state: ActionButtonMotion.State) -> void:
	_driven = true
	set_process(false)
	match state:
		MOTION_STATE.DISABLED:
			pose(state, 0.0, -1.0, -1.0, -1.0)
		MOTION_STATE.PRESSED:
			# 섬광이 살아 있는 시각을 앉힌다. 눌림은 **사건**이라 그 순간이 그 상태다.
			pose(state, 1.4, 0.9, 0.05, -1.0)
		MOTION_STATE.HOVER:
			pose(state, 1.4, 0.9, -1.0, -1.0)
		_:
			pose(MOTION_STATE.NORMAL, 1.4, -1.0, -1.0, -1.0)


func _process(delta: float) -> void:
	if _driven:
		return
	_sync()
	_motion.advance(delta)
	if _motion.state == MOTION_STATE.DISABLED and _static_drawn:
		return
	queue_redraw()


## 버튼의 실제 상태에서 시계 사건을 뽑는다. 신호를 여럿 잇는 대신 한 자리에서
## 가장자리를 본다 — 비활성 전환처럼 신호가 없는 변화도 같이 잡힌다.
func _sync() -> void:
	if disabled:
		if _motion.state != MOTION_STATE.DISABLED:
			_motion.disable()
			_static_drawn = false
			queue_redraw()
		_was_hovering = false
		_was_holding = false
		return
	if _motion.state == MOTION_STATE.DISABLED:
		_motion.state = MOTION_STATE.NORMAL
		_static_drawn = false

	var hovering := is_hovered()
	if hovering and not _was_hovering:
		_motion.enter_hover()
	elif not hovering and _was_hovering:
		_motion.exit_hover()
	_was_hovering = hovering

	var holding := button_pressed
	if holding and not _was_holding:
		_motion.press()
	elif not holding and _was_holding:
		_motion.release()
	_was_holding = holding

	if holding:
		_motion.state = MOTION_STATE.PRESSED
	elif hovering:
		_motion.state = MOTION_STATE.HOVER
	else:
		_motion.state = MOTION_STATE.NORMAL


## 크기는 글자에서 나온다. 형태마다 글자 크기와 여백이 달라 **같은 낱말이라도
## 형태를 바꾸면 버튼이 커지거나 작아진다** — 위계가 색이 아니라 형태에서 나온다.
func _refresh_size() -> void:
	var points := PlateForm.font_size(form)
	var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, points).x
	width += TRACKING * maxf(0.0, float(text.length() - 1))
	custom_minimum_size = Vector2(ceilf(width + PlateForm.padding(form)), PlateForm.height(form))


func _draw() -> void:
	var dead := _motion.state == MOTION_STATE.DISABLED
	_static_drawn = dead

	var body := Vector2(size.x, PlateForm.height(form))
	var shape := PlateForm.outline(form, body)
	var box := PlateForm.bounds(shape)
	var lift := _motion.lift()
	var squash := _motion.squash()

	if not dead:
		_draw_shadow(shape, lift)

	# 판 전체를 아래 모서리 기준으로 누른다. 가운데 기준이면 눌렀을 때 판이
	# **바닥에서 떠올라** 눌린 것으로 안 보인다.
	var pivot := Vector2(body.x * 0.5, body.y)
	_plate_xform = Transform2D(
		Vector2(squash.x, 0.0), Vector2(0.0, squash.y), pivot - squash * pivot + Vector2(0.0, -lift)
	)
	draw_set_transform_matrix(_plate_xform)

	var warmth := _motion.warmth()
	_draw_plate(shape, body, warmth, dead)
	_draw_ticks(body, dead)
	_draw_rules(shape, warmth, dead)
	_draw_marks(box, body, warmth, dead)
	_draw_text(body, dead)
	if not dead:
		_draw_brackets(box)
		_draw_impact(box)
	if has_focus():
		_dashed(_closed(PlateForm.shrink(shape, -3.0)), INK, 1.0, 3.0, 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 밀린 한 겹. **흐리지 않는다** — 흐린 그림자가 말랑한 볼록(뉴모피즘)을 만든다.
## 비활성에는 아예 없다. 눌릴 수 없는 것은 떠 있지 않다.
func _draw_shadow(shape: PackedVector2Array, lift: float) -> void:
	var drop := Vector2(0.0, DROP + lift * 0.8)
	var moved := shape.duplicate()
	for i in moved.size():
		moved[i] += drop
	draw_colored_polygon(moved, SHADOW)
	var extra := PlateForm.second(form, Vector2(size.x, PlateForm.height(form)))
	if extra.is_empty():
		return
	for i in extra.size():
		extra[i] += drop
	draw_colored_polygon(extra, SHADOW)


## 판. **단색이다.** 세로 그라디언트를 조금이라도 주면 플라스틱 사출물로 보였고,
## 세게 주면 유리판(글래스모피즘)이 된다. 파스텔에서는 면이 그냥 면이어야 한다.
func _draw_plate(shape: PackedVector2Array, body: Vector2, warmth: float, dead: bool) -> void:
	var tone := PLATE.lerp(HOVER_PLATE, warmth)
	if dead:
		tone = DEAD_TOP
	else:
		tone = tone.lerp(PRESS_PLATE, _motion.inversion())
	var extra := PlateForm.second(form, body)
	if not extra.is_empty():
		# 어긋난 두 번째 조각은 본판보다 한 단 어둡다. 같은 색이면 한 장으로 붙어 보인다.
		draw_colored_polygon(extra, tone.lerp(RULE, 0.35))
		draw_polyline(_closed(extra), RULE if not dead else DEAD_RULE, 1.0, true)
	draw_colored_polygon(shape, tone)


## 판 위쪽의 눈금 띠. **커서가 붙어야 생긴다.**
##
## 화려함은 요소를 더해서가 아니라 **밀도 대비**에서 나온다. 평상에서 이 자리는
## 완전히 비어 있고, 손이 닿는 순간 눈금 열넷이 **왼쪽부터 좍 그어진다.**
func _draw_ticks(body: Vector2, dead: bool) -> void:
	if dead:
		return
	var grown := minf(_motion.reveal(), 1.0)
	if grown <= 0.01:
		return
	var span := PlateForm.ticks(form, body)
	var flare := _motion.flare()
	var tone := RULE_SOFT.lerp(ACCENT, flare)
	var count := 14
	var step := (span.y - span.x) / float(count - 1)
	for i in count:
		# 왼쪽부터 차례로 선다. 한꺼번에 켜면 그냥 밝아진 것이다.
		if grown <= float(i) / float(count):
			continue
		draw_rect(Rect2(span.x + float(i) * step, span.z, 1.0, 3.0 + 2.0 * flare), tone)
	draw_line(
		Vector2(span.x, span.z + 6.0),
		Vector2(span.x + (span.y - span.x) * grown, span.z + 6.0),
		Color(tone, 0.45 + 0.55 * flare),
		1.0
	)


## 괘선 두 줄. 바깥은 실선, 안쪽은 한 겹 여린 선.
## 비활성은 바깥 줄이 **점선**이 된다 — 색을 흐리는 것보다 훨씬 확실하게 갈린다.
func _draw_rules(shape: PackedVector2Array, warmth: float, dead: bool) -> void:
	var inner := PlateForm.shrink(shape, INSET)
	var line := RULE.lerp(INK, 0.35 * warmth)
	var soft := RULE_SOFT.lerp(RULE, warmth)
	if dead:
		_dashed(_closed(shape), DEAD_RULE, 1.5, 5.0, 4.0)
		draw_polyline(_closed(inner), Color(DEAD_RULE, 0.55), 1.0, true)
		return
	var invert := _motion.inversion()
	if invert > 0.0:
		line = line.lerp(Color("#31404f"), invert)
		soft = soft.lerp(Color("#7f93a8"), invert)
	# 눌린 순간 테두리가 굵어지며 강세색이 된다. 사건은 **여럿이 같이** 번쩍여야 한다.
	var flare := _motion.flare()
	draw_polyline(_closed(shape), line.lerp(ACCENT, flare), 1.5 + 2.0 * flare, true)
	draw_polyline(
		_closed(inner), Color(soft.lerp(ACCENT_SOFT, flare), 0.75 + 0.25 * flare), 1.0, true
	)


## 표지와 게이지. 자리는 형태가 정하고 이 함수는 색과 개수만 안다.
func _draw_marks(box: Rect2, body: Vector2, warmth: float, dead: bool) -> void:
	var invert := _motion.inversion()
	var strong := ACCENT
	var weak := RULE_SOFT
	if dead:
		strong = DEAD_RULE
		weak = DEAD_RULE
	elif invert > 0.0:
		strong = strong.lerp(Color("#e2a79c"), invert)
		weak = weak.lerp(Color("#8fa2b6"), invert)
	var grown := minf(_motion.reveal(), 1.0)
	var flare := _motion.flare()
	if not dead:
		strong = strong.lerp(Color("#eec0b2"), flare)

	var mark := PlateForm.marker(form, body)
	if not mark.is_empty():
		draw_colored_polygon(mark, strong)

	# 게이지. 평상에는 칸 셋, 커서가 붙으면 **일곱으로 늘어난다.** 눌리면 전부 찬다.
	var right := PlateForm.gauge_at(form, body)
	var phase := _motion.runner_at()
	var count := 3 + int(round(4.0 * grown))
	for i in count:
		var cell := Rect2(right.x - float(count - i) * 6.5 + 1.5, right.y - 2.5, 5.0, 5.0)
		if dead:
			draw_rect(cell, weak, false, 1.0)
		elif flare > 0.15 or invert > 0.5 or (phase >= 0.0 and int(phase * count) == i):
			draw_rect(cell, strong)
		else:
			draw_rect(cell, weak.lerp(strong, 0.30 * warmth))

	if dead:
		return
	# 커서에서만 나오는 아래 강세 줄. 끝을 지나쳤다 되돌아온다.
	var wipe := _motion.accent()
	if wipe > 0.001:
		var y := box.end.y - INSET - 3.0
		var half := (box.size.x - 40.0) * 0.5 * wipe
		var cx := box.get_center().x
		draw_rect(Rect2(cx - half, y, half * 2.0, 2.0 + 2.0 * flare), strong)
		for way in _SIDES:
			draw_rect(
				Rect2(cx + way * half - (0.0 if way < 0.0 else 1.5), y - 2.5, 1.5, 7.0),
				Color(strong, wipe)
			)


## 네 모서리의 표. **커서에 튀어나오고 눌림에 밖으로 차인다.**
##
## 판 **바깥**에 있어서 글자와 자리를 다투지 않는다. 파스텔은 대비 여유가 적어서
## 판 안에 무엇을 더 넣을수록 읽힘이 먼저 무너진다 — 그래서 화려함을 밖으로 뺐다.
func _draw_brackets(box: Rect2) -> void:
	var out := _motion.reveal()
	if out <= 0.01:
		return
	# `reveal` 이 1 을 지나쳤다 돌아오므로 표가 제자리를 지나쳐 튀어 나간다.
	var away := 2.0 + 3.0 * out + 9.0 * _motion.flare()
	var arm := 7.0 + 3.0 * minf(out, 1.0)
	var tone := Color(ACCENT.lerp(Color("#e8b3a4"), _motion.flare()), minf(out, 1.0))
	var grown := box.grow(away)
	for corner in 4:
		var way := Vector2(-1.0 if corner % 2 == 0 else 1.0, -1.0 if corner < 2 else 1.0)
		var at := Vector2(
			grown.position.x if way.x < 0.0 else grown.end.x,
			grown.position.y if way.y < 0.0 else grown.end.y
		)
		draw_polyline(
			PackedVector2Array(
				[at + Vector2(way.x * -arm, 0.0), at, at + Vector2(0.0, way.y * -arm)]
			),
			tone,
			1.5,
			true
		)


## 눌린 순간 판에서 퍼져 나가는 테두리 두 겹.
##
## **처음에는 금 조각이 사방으로 튀게 했다가 버렸다.** 실제 크기에서 그것은
## 불꽃이 아니라 **판에 난 흠집**으로 읽혔다. 얹은 장식이 기본을 갉으면
## 그 장식을 버리는 것이 이 판의 규칙이다.
func _draw_impact(box: Rect2) -> void:
	var u := _motion.impact()
	if u < 0.0:
		return
	# 한 겹이면 테두리가 한 번 커진 것으로 보이고, **두 겹이면 퍼져 나간 것**으로 보인다.
	var delays: Array[float] = [0.0, 0.16]
	for delay in delays:
		var when := u - delay
		if when < 0.0 or when >= 1.0:
			continue
		var fade := (1.0 - when) * (1.0 - when)
		var grow := 1.0 + 16.0 * KitEase.out_expo(when, 3.2)
		draw_polyline(
			_closed(PlateShape.octagon(box.grow(grow), 9.0 + grow * 0.4)),
			Color(ACCENT, 0.75 * fade),
			1.0 + 0.8 * fade,
			true
		)


## 글자. 자리와 각도는 형태가 정한다. **가운데가 아니어도 되고 판을 넘어가도 된다.**
##
## 그림자를 깔지 않는다 — 밝은 판 위의 어두운 글자는 그 자체로 대비가 충분하고,
## 판 밖으로 넘어가도 바탕이 밝아서 대비가 유지된다. 검은 바탕이었으면 못 할 짓이다.
func _draw_text(body: Vector2, dead: bool) -> void:
	var points := PlateForm.font_size(form)
	var invert := _motion.inversion()
	var ink := DEAD_INK if dead else INK.lerp(INK_ON_PRESS, invert)

	# 눌린 순간 자간이 잠깐 벌어졌다 되돌아온다. 글자를 흔들지 않으면서
	# **글자도 사건에 참여하는** 유일한 방법이다.
	var spread := TRACKING + 2.2 * clampf(_motion.squeeze(), 0.0, 1.0)
	var width := 0.0
	for i in text.length():
		width += FONT.get_char_size(text.unicode_at(i), points).x
	width += spread * maxf(0.0, float(text.length() - 1))

	var at := PlateForm.text_at(form, body)
	var tilt := PlateForm.tilt(form)
	if not is_zero_approx(tilt):
		# `draw_set_transform` 은 덮어쓰기라 판 변형이 사라진다. 곱해서 얹는다.
		draw_set_transform_matrix(_plate_xform * Transform2D(tilt, at))
		at = Vector2.ZERO

	var x := at.x - width * 0.5
	var baseline := at.y + (FONT.get_ascent(points) - FONT.get_descent(points)) * 0.5
	baseline += _motion.text_dip()
	for i in text.length():
		var code := text.unicode_at(i)
		FONT.draw_char(get_canvas_item(), Vector2(x, baseline), code, points, ink)
		x += FONT.get_char_size(code, points).x + spread
	if not is_zero_approx(tilt):
		draw_set_transform_matrix(_plate_xform)


## 점선. 비활성을 **흐리게** 만드는 대신 선의 종류를 바꾼다 — 파스텔에서 명도만
## 낮추면 「조금 덜 중요한 버튼」으로 읽히고, 그건 사실과 다르다.
func _dashed(
	points: PackedVector2Array, color: Color, width: float, dash: float, gap: float
) -> void:
	var carry := 0.0
	for i in points.size() - 1:
		var from := points[i]
		var to := points[i + 1]
		var length := from.distance_to(to)
		if length <= 0.0:
			continue
		var step := (to - from) / length
		var walked := carry
		while walked < length:
			var end := minf(walked + dash, length)
			draw_line(from + step * walked, from + step * end, color, width)
			walked += dash + gap
		carry = maxf(0.0, walked - length)


func _closed(shape: PackedVector2Array) -> PackedVector2Array:
	var out := shape.duplicate()
	out.append(shape[0])
	return out
