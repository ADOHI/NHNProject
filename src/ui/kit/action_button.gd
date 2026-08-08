class_name ActionButton
extends BaseButton
## 게임에 그대로 들어가는 **버튼 한 개.** 「출격」 · 「탐사 개시」가 이것이다.
##
## 확인 화면은 `src/ui/kit/button_bench.tscn` (docs/design/20-ui-kit.md §20.8).
##
## ## 기본이 먼저다 — 이 순서를 뒤집으면 다섯 판이 죽은 자리로 돌아간다
##
## 앞의 다섯 판은 「아름다움 · 화려함 · 동적임」만 보고 만들어서 **장식이 기능을
## 이겼다.** 5판은 금 광선이 사방으로 뻗는 세공품이었는데 **버튼으로 보이지 않았다.**
## 그래서 여기서는 아래 여섯을 먼저 세우고, 장식은 **그 위에 얹되 얹을 때마다 여섯이
## 깨지는지 다시 본다.**
##
## | 기본 | 이 파일에서 |
## | --- | --- |
## | 읽힌다 | 글자는 **어두운 안쪽 칸** 위에만 온다. 금과 무늬는 전부 테두리 쪽이다 |
## | 눌러 보인다 | 위로 뜬 그림자 + 위쪽 사면 하이라이트 + 아래쪽 그늘. **판이 떠 있다** |
## | 상태가 갈린다 | 평상=금테, 커서=떠오름·발광, 눌림=**안쪽 칸 반전**, 비활성=금이 없고 빗금이 덮인다 |
## | 정렬·여백 | 글자는 안쪽 칸 정중앙. 좌우 장식은 같은 폭을 차지해 **글자가 광학적으로도 가운데**다 |
## | 위계 | 화면에서 가장 밝은 것이 글자다. 금은 글자보다 어둡다 |
## | 크기 | 56px 높이 · 최소 184px 폭. 1280x720 에서 실측한 값이다 |
##
## ## 금을 어디에 두었나 — 「화려한데 읽힌다」의 유일한 해법
##
## 4판은 금을 압인 하나로 아껴서 **밋밋**했고, 5판은 금을 화면에 뿌려서 **글자가
## 죽었다.** 여기서는 금이 **7px 폭의 테두리 띠 전체**를 차지한다. 면적으로는
## 넉넉하고, 글자가 앉는 자리와는 **겹치지 않는다.** 놋쇠 질감도 그 띠 안에서만
## 진하게 쓴다.
##
## ## 시계를 두 군데서 흘리지 않는다
##
## `_ready()` 가 캡처 도구의 설정을 되돌린 사고가 이 저장소에서 있었다.
## 그래서 `_driven` 을 `_ready()` 와 `_process()` 가 **둘 다** 본다.

const MOTION_STATE := ActionButtonMotion.State

const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")
const BRASS := preload("res://assets/ui/kit/brass.webp")

## 실제 크기. 시연용 확대가 아니다 — 1280x720 화면에 이 크기로 앉는다.
const HEIGHT: float = 56.0
const MIN_WIDTH: float = 184.0
const CHAMFER: float = 9.0

## 금 테두리 띠의 폭. 여기까지가 금이고 그 안쪽은 글자 자리다.
const BEZEL: float = 7.0

## 테두리와 안쪽 칸 사이의 홈. 두 겹이 맞닿지 않아야 세공으로 보인다.
const GROOVE: float = 1.5

## 글자 크기와 자간. 자간이 0 이면 두 글자 낱말이 뭉쳐 보인다.
const FONT_SIZE: int = 22
const TRACKING: float = 3.0

## 좌우 장식이 차지하는 폭. **좌우가 같아야** 글자가 광학적으로 가운데 온다.
const ORNAMENT_ZONE: float = 30.0

const GOLD_DEEP := Color("#8a6220")
const GOLD_MID := Color("#c1913c")
const GOLD_LIT := Color("#f2d68d")
const GOLD_RULE := Color("#5d4212")
const PANEL_TOP := Color("#241d14")
const PANEL_BOT := Color("#120e09")
const GROOVE_INK := Color("#0a0806")
const IVORY := Color("#f8f0dc")
const CRIMSON := Color("#d8452c")
const DEAD_BAND := Color("#2a2d33")
const DEAD_BAND_LOW := Color("#1d2025")
const DEAD_PANEL := Color("#191b1f")
const DEAD_RULE := Color("#3c414a")
const DEAD_TEXT := Color("#7b818c")

## 화면에 나갈 글자. 「출격」 「탐사 개시」 같은 실제 문구가 들어간다.
@export var text: String = "출격":
	set(value):
		text = value
		_refresh_size()
		queue_redraw()

var _motion := ActionButtonMotion.new()
var _was_hovering := false
var _was_holding := false

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
			# 충격파가 지나간 뒤다. 안 그러면 정지 화면에 링 하나가 남아 찍힌다.
			pose(state, 1.4, 0.9, ActionButtonMotion.IMPACT_TIME + 0.05, -1.0)
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


func _refresh_size() -> void:
	var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	width += TRACKING * maxf(0.0, float(text.length() - 1))
	var needed := width + ORNAMENT_ZONE * 2.0 + (BEZEL + GROOVE) * 2.0 + 16.0
	custom_minimum_size = Vector2(maxf(MIN_WIDTH, ceilf(needed)), HEIGHT)


func _draw() -> void:
	var dead := _motion.state == MOTION_STATE.DISABLED
	_static_drawn = dead

	var body := Rect2(Vector2.ZERO, Vector2(size.x, HEIGHT))
	var lift := _motion.lift()
	var scale := _motion.squash()

	if not dead:
		_draw_shadow(body, lift)

	# 판 전체를 아래 모서리 기준으로 누른다. 가운데 기준이면 눌렀을 때 판이
	# **바닥에서 떠올라** 눌린 것으로 안 보인다.
	var pivot := Vector2(body.size.x * 0.5, body.size.y)
	draw_set_transform(pivot - scale * pivot + Vector2(0.0, -lift), 0.0, scale)

	var warmth := _motion.warmth()
	if not dead:
		_draw_glow(body, warmth)
	_draw_bezel(body, warmth, dead)
	var panel := body.grow(-(BEZEL + GROOVE))
	_draw_groove(body, dead)
	_draw_panel(body, panel, warmth, dead)
	if dead:
		_draw_hatch(body)
	_draw_ornaments(body, panel, warmth, dead)
	_draw_text(panel, dead)
	if not dead:
		_draw_impact(body)
	if has_focus():
		_draw_focus(body)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 떠 있는 판에는 그림자가 있다. **비활성에는 없다** — 눌릴 수 없는 것은 뜨지 않는다.
func _draw_shadow(body: Rect2, lift: float) -> void:
	var drop := 4.0 + lift * 0.7
	var spread := 1.0 + lift * 0.25
	var shape := PlateShape.octagon(body.grow(spread), CHAMFER)
	for i in shape.size():
		shape[i] += Vector2(0.0, drop)
	draw_colored_polygon(shape, Color(0.0, 0.0, 0.0, 0.42))


func _draw_glow(body: Rect2, warmth: float) -> void:
	if warmth <= 0.01:
		return
	for i in 3:
		var grow := 2.0 + float(i) * 3.0
		var ring := PlateShape.octagon(body.grow(grow), CHAMFER + grow * 0.5)
		var alpha := 0.20 * warmth / float(i + 1)
		draw_polyline(_closed(ring), Color(GOLD_LIT, alpha), 2.0, true)


## 금 테두리 띠. 화면에서 금이 차지하는 자리는 전부 여기다.
func _draw_bezel(body: Rect2, warmth: float, dead: bool) -> void:
	var shape := PlateShape.octagon(body, CHAMFER)
	var top := GOLD_MID.lerp(GOLD_LIT, 0.45 * warmth)
	var bottom := GOLD_DEEP.lerp(GOLD_MID, 0.35 * warmth)
	if dead:
		top = DEAD_BAND
		bottom = DEAD_BAND_LOW
	_fill_vertical(shape, body, top, bottom)
	if not dead:
		# 놋쇠 무늬는 세로로 늘리면 국수가 된다. 원본의 가로 띠 한 줄만 쓴다.
		var uv := Rect2(0.02, 0.34, 0.94, 0.20)
		_fill_texture(shape, body, BRASS, uv, Color(1.0, 1.0, 1.0, 0.22 + 0.08 * warmth))

	# **질감을 얹으면 위에서 오던 빛이 지워진다.** 무늬의 명암이 그라디언트를 덮어
	# 아래쪽이 위쪽보다 밝아지고, 그러면 판이 뒤집혀 보인다. 유약을 한 겹 더 발라
	# 위가 밝고 아래가 어두운 것을 되돌린다.
	_fill_vertical(shape, body, Color(1.0, 0.94, 0.78, 0.10), Color(0.0, 0.0, 0.0, 0.36))

	var rule := GOLD_RULE.lerp(GOLD_LIT, 0.30 * warmth)
	draw_polyline(_closed(shape), DEAD_RULE if dead else rule, 1.5, true)
	# 위쪽에 빛, 아래쪽에 그늘. 이 두 줄이 「판이 떠 있다」를 만든다.
	var bevel := PlateShape.inset(body, CHAMFER, 1.2)
	draw_polyline(_edge(bevel, 7, 4), Color(GOLD_LIT, 0.75 if not dead else 0.28), 1.6, true)
	draw_polyline(_edge(bevel, 3, 4), Color(0.0, 0.0, 0.0, 0.40), 1.6, true)


func _draw_groove(body: Rect2, dead: bool) -> void:
	var shape := PlateShape.inset(body, CHAMFER, BEZEL)
	draw_colored_polygon(shape, GROOVE_INK if not dead else Color("#0f1013"))


## 글자가 앉는 어두운 칸. 광택도 무늬도 여기서는 약하게만 쓴다.
func _draw_panel(body: Rect2, panel: Rect2, warmth: float, dead: bool) -> void:
	var shape := PlateShape.inset(body, CHAMFER, BEZEL + GROOVE)
	var invert := _motion.inversion()
	var top := PANEL_TOP.lerp(Color("#33291b"), warmth)
	var bottom := PANEL_BOT.lerp(Color("#1b1509"), warmth)
	if dead:
		top = DEAD_PANEL
		bottom = Color("#131519")
	elif invert > 0.0:
		# 눌림 = 반전. 안쪽 칸이 통째로 금이 되고 글자가 어두워진다.
		top = top.lerp(GOLD_LIT, invert)
		bottom = bottom.lerp(GOLD_MID, invert)
	_fill_vertical(shape, panel, top, bottom)

	if dead:
		return
	_fill_texture(shape, panel, BRASS, Rect2(0.1, 0.6, 0.8, 0.18), Color(1, 1, 1, 0.07))

	var at := _motion.sheen_at()
	if at > -0.5:
		# **한 겹으로 그리면 판이 밝은 쪽과 어두운 쪽으로 두 동강 난 것처럼 보인다.**
		# 넓은 것부터 좁은 것까지 여러 겹을 포개 가장자리를 뭉갠다. 겹마다의 알파는
		# 다 포갠 한복판이 정확히 `strength` 가 되도록 역산한다 — 안 그러면 겹수를
		# 바꿀 때마다 밝기가 같이 변한다.
		var strength := _motion.sheen_strength()
		var widths := [60.0, 46.0, 34.0, 24.0, 15.0, 7.0]
		var each := 1.0 - pow(1.0 - strength, 1.0 / float(widths.size()))
		for width in widths:
			var band := PlateShape.sweep_band(panel, at, width, 14.0)
			for piece in Geometry2D.intersect_polygons(band, shape):
				draw_colored_polygon(piece, Color(1.0, 0.96, 0.86, each))

	# 안쪽 칸은 파인 것이라 위가 어둡고 아래가 밝다 — 테두리와 반대다.
	draw_polyline(_edge(shape, 7, 4), Color(0.0, 0.0, 0.0, 0.45), 1.0, true)
	draw_polyline(_edge(shape, 3, 4), Color(GOLD_LIT, 0.20), 1.0, true)

	var wipe := _motion.accent()
	if wipe > 0.001:
		var y := panel.end.y - 3.0
		var half := (panel.size.x - CHAMFER * 2.0) * 0.40 * wipe
		var mid := panel.position.x + panel.size.x * 0.5
		# 눌리면 칸이 금이 된다. 주홍을 그대로 두면 금 위에서 탁해진다.
		var tone := CRIMSON.lerp(Color("#7d2413"), invert)
		draw_line(Vector2(mid - half, y), Vector2(mid + half, y), tone, 1.6)


## 비활성의 빗금. 흐리게 만드는 것과 다르다 — **막혀 있다**로 읽힌다.
##
## **글자 칸 위로는 지나가지 않는다.** 처음에 판 전체에 그었더니 빗금이 글자를
## 가로질러 「비활성이지만 안 읽히는」 것이 됐다. 금이 있던 띠만 긋는다 —
## 값진 자리가 막혀 있다는 뜻이라 읽기도 그쪽이 맞다.
func _draw_hatch(body: Rect2) -> void:
	var band := PlateShape.octagon(body, CHAMFER)
	var hole := PlateShape.inset(body, CHAMFER, BEZEL)
	var step := 7.0
	var x := body.position.x - body.size.y
	while x < body.end.x:
		var line := PackedVector2Array(
			[Vector2(x, body.end.y), Vector2(x + body.size.y, body.position.y)]
		)
		for inside in Geometry2D.intersect_polyline_with_polygon(line, band):
			for piece in Geometry2D.clip_polyline_with_polygon(inside, hole):
				draw_polyline(piece, Color("#0d0f12"), 1.6, true)
		x += step


## 좌우 장식. **같은 폭을 쓴다** — 한쪽만 있으면 글자가 가운데로 안 보인다.
func _draw_ornaments(body: Rect2, panel: Rect2, warmth: float, dead: bool) -> void:
	var invert := _motion.inversion()
	var gold := GOLD_MID.lerp(GOLD_LIT, warmth)
	if dead:
		gold = DEAD_RULE
	elif invert > 0.0:
		gold = gold.lerp(Color("#2a2012"), invert)
	var mid := panel.position.y + panel.size.y * 0.5

	# 왼쪽 — 괘선 하나에 마름모와 끝 장식. 오른쪽 갈매기표와 무게를 맞춘다.
	var lx := panel.position.x + 12.0
	draw_line(Vector2(lx, mid - 8.0), Vector2(lx, mid + 8.0), Color(gold, 0.9), 1.0)
	for way in [-8.0, 8.0]:
		draw_line(Vector2(lx - 2.5, mid + way), Vector2(lx + 2.5, mid + way), Color(gold, 0.9), 1.0)
	_diamond(Vector2(lx, mid), 3.6, gold)
	_diamond(Vector2(lx, mid), 1.6, Color(GOLD_LIT, 0.9) if not dead else gold)

	# 오른쪽 — 갈매기표 둘. 「나아간다」가 이 버튼의 뜻이다.
	var phase := _motion.chevron_at()
	for i in 2:
		var cx := panel.end.x - 23.0 + float(i) * 9.0
		var lead := 0.0
		if phase >= 0.0:
			var d := absf(fposmod(phase - float(i) * 0.18 + 0.5, 1.0) - 0.5)
			lead = exp(-d * d * 60.0)
		var tint := gold.lerp(GOLD_LIT, lead * (0.35 + 0.65 * warmth))
		var arrow := PackedVector2Array(
			[
				Vector2(cx - 3.0 + lead * warmth * 2.0, mid - 6.0),
				Vector2(cx + 3.0 + lead * warmth * 2.0, mid),
				Vector2(cx - 3.0 + lead * warmth * 2.0, mid + 6.0),
			]
		)
		draw_polyline(arrow, tint, 2.0, true)

	if dead:
		return
	# 모따기 네 면마다 작은 마름모. 세공이라는 신호는 이 넷이 다 낸다.
	var facets := PlateShape.inset(body, CHAMFER, BEZEL * 0.5)
	for i in 4:
		var a := facets[i * 2 + 1]
		var b := facets[(i * 2 + 2) % facets.size()]
		_diamond(a.lerp(b, 0.5), 2.2, GOLD_LIT.lerp(gold, 0.3))

	# 테두리를 타고 도는 빛 둘. 평상 상태에서 버튼이 살아 있게 하는 유일한 것이다.
	var at := _motion.runner_at()
	if at < 0.0:
		return
	var outline := PlateShape.octagon(body, CHAMFER)
	for k in 2:
		var s := fposmod(at + float(k) * 0.5, 1.0)
		var trail := PackedVector2Array()
		for j in 7:
			trail.append(PlateShape.along(outline, s - 0.030 + float(j) * 0.010))
		draw_polyline(trail, Color(GOLD_LIT, 0.35 + 0.45 * warmth), 1.8, true)
		draw_circle(PlateShape.along(outline, s), 1.6, Color(1.0, 0.95, 0.82, 0.75))


## 눌린 순간 판에서 퍼져 나가는 충격파 한 겹.
##
## **처음에는 금 조각이 사방으로 튀게 했다가 버렸다.** 실제 크기에서 그것은
## 불꽃이 아니라 **판에 난 흠집**으로 읽혔고, 조각마다 각도가 달라 좌우가
## 어긋나 보였다. 얹은 장식이 기본(「이게 버튼인지 한눈에 아나」)을 갉으면
## 그 장식을 버리는 것이 이 판의 규칙이다.
func _draw_impact(body: Rect2) -> void:
	var u := _motion.impact()
	if u < 0.0:
		return
	var fade := (1.0 - u) * (1.0 - u)
	var grow := 1.0 + 11.0 * KitEase.out_expo(u, 3.2)
	var ring := PlateShape.octagon(body.grow(grow), CHAMFER + grow * 0.4)
	draw_polyline(_closed(ring), Color(GOLD_LIT, 0.65 * fade), 1.0 + 1.4 * fade, true)


## 키보드 초점. 마우스가 없어도 어디에 있는지 보여야 한다.
func _draw_focus(body: Rect2) -> void:
	var ring := PlateShape.octagon(body.grow(3.0), CHAMFER + 1.5)
	draw_polyline(_closed(ring), Color(IVORY, 0.70), 1.0, true)


## 글자. 안쪽 칸의 정중앙에 오고, 어두운 그림자 한 겹을 깔아 어떤 상태에서도 읽힌다.
func _draw_text(panel: Rect2, dead: bool) -> void:
	var invert := _motion.inversion()
	var ink := DEAD_TEXT if dead else IVORY.lerp(Color("#181206"), invert)
	var width := 0.0
	for i in text.length():
		width += FONT.get_char_size(text.unicode_at(i), FONT_SIZE).x
	width += TRACKING * maxf(0.0, float(text.length() - 1))

	var x := panel.position.x + (panel.size.x - width) * 0.5
	var baseline := panel.position.y + panel.size.y * 0.5
	baseline += (FONT.get_ascent(FONT_SIZE) - FONT.get_descent(FONT_SIZE)) * 0.5
	baseline += _motion.text_dip()

	var shade := Color(0.0, 0.0, 0.0, 0.55 * (1.0 - invert))
	for i in text.length():
		var code := text.unicode_at(i)
		var at := Vector2(x, baseline)
		if not dead:
			FONT.draw_char(get_canvas_item(), at + Vector2(0.0, 1.0), code, FONT_SIZE, shade)
		FONT.draw_char(get_canvas_item(), at, code, FONT_SIZE, ink)
		x += FONT.get_char_size(code, FONT_SIZE).x + TRACKING


func _diamond(at: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(
		PackedVector2Array(
			[
				at + Vector2(0.0, -radius),
				at + Vector2(radius, 0.0),
				at + Vector2(0.0, radius),
				at + Vector2(-radius, 0.0),
			]
		),
		color
	)


## 세로 그라디언트로 채운다. 폴리곤 꼭짓점마다 색을 주면 팔각에서는
## **부채 중심 쪽으로 색이 몰려** 가로줄이 생긴다. 높이만 보고 섞는다.
func _fill_vertical(shape: PackedVector2Array, box: Rect2, top: Color, bottom: Color) -> void:
	var colors := PackedColorArray()
	for point in shape:
		var t := clampf((point.y - box.position.y) / maxf(1.0, box.size.y), 0.0, 1.0)
		colors.append(top.lerp(bottom, t))
	draw_polygon(shape, colors)


func _fill_texture(
	shape: PackedVector2Array, box: Rect2, texture: Texture2D, uv: Rect2, tint: Color
) -> void:
	var uvs := PackedVector2Array()
	for point in shape:
		uvs.append(
			Vector2(
				uv.position.x + uv.size.x * clampf((point.x - box.position.x) / box.size.x, 0, 1),
				uv.position.y + uv.size.y * clampf((point.y - box.position.y) / box.size.y, 0, 1)
			)
		)
	var colors := PackedColorArray()
	colors.resize(shape.size())
	colors.fill(tint)
	draw_polygon(shape, colors, uvs, texture)


func _closed(shape: PackedVector2Array) -> PackedVector2Array:
	var out := shape.duplicate()
	out.append(shape[0])
	return out


## 윤곽에서 `index` 번째 꼭짓점부터 `count` 개를 이은 조각. 위쪽 사면과 아래쪽
## 그늘을 따로 그리려면 팔각의 일부만 있어야 한다.
func _edge(shape: PackedVector2Array, index: int, count: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in count:
		out.append(shape[(index + i) % shape.size()])
	return out
