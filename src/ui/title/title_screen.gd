class_name TitleScreen
extends Control
## **타이틀.** 이 게임의 첫 화면이고, 제목이 두 뜻을 진다는 것을 그림 하나로 말한다.
##
## 근거와 컨셉은 docs/design/21-title.md 에 있다. 요약하면 한 줄이다.
##
##   「금」은 신문지에 눌러 찍은 금박이다. 값싼 종이는 박을 붙들지 못한다.
##   그래서 **금은 반드시 금이 간다.**
##
## 이 씬은 `main.tscn` 에 붙어 있지 않다. 부팅 흐름에 끼우는 것은 통합자가 한다
## (docs/design/21-title.md §21.7).
##
## ---
##
## **노드 순서가 곧 인쇄 공정이다.**
##
##   종이 → 악마(별색) → 사람(먹) → 글 → **인쇄판** → **금박**
##
## 박은 잉크가 아니라 다 찍은 종이에 열로 눌러 붙이는 후가공이라 판 뒤에 온다.
## 그래서 화면에서 유일하게 망점이 아닌 것이 금이 된다.

## 시작을 눌렀다. 균열이 지도가 되기 시작한다.
signal descend_requested

## 화면이 지나는 세 박자. 머무름에서만 사람들이 움직인다.
enum Beat { STAMPING, DWELLING, DESCENDING }

## 금이 차지하는 화면 비율. 이보다 작으면 다른 겹에 먹히고,
## 크면 사방에서 다가오는 자들이 앉을 자리가 없다.
##
## **금이 화면에서 가장 강해야 한다.** 그런데 밝기나 크기로 그렇게 만들지 않는다 —
## 재질이 달라서(화면에서 유일하게 망점이 아니라서) 강하다. 그래도 작으면
## 그 대비를 볼 수가 없다.
const _GLYPH_SHARE := 0.62

## 화면이 뜨자마자 박이 종이에 닿기까지. 종이가 먼저 찍히고 박이 나중이다.
const _STAMP_DELAY := 0.42

## 다가오는 자들이 앉는 반지름(화면 짧은 변 기준)과 그들의 크기.
const _SEEKER_RING := 0.40
const _SEEKER_SIZE := 0.20

## 이보다 가까워지면 더 다가가지 않고 **옆으로 돈다.** 노리는 것이지 덤비는 것이 아니다.
const _SEEKER_HOLD := 0.30

## 악마가 앉는 자리. 사람보다 위, 사람보다 작다 — 멀리 있기 때문이다.
const _DEMON_RING := 0.54
const _DEMON_SIZE := 0.185
const _DEMON_LIFT := 0.26

## 사람이 앉는 각도(도). 사방에서 온다. 정사각으로 놓으면 표가 되므로 흩어 놓는다.
const _SEEKER_ANGLES: Array[float] = [196.0, 341.0, 71.0, 128.0]

## 악마가 앉는 각도(도). 사람 뒤에 겹치지 않게 사이에 앉힌다.
const _DEMON_ANGLES: Array[float] = [232.0, 300.0, 24.0]

var _paper: ColorRect
var _glyph: FoilGlyph
var _plate: PressPlate
var _far: Control
var _mid: Control
var _seekers: Array[Watcher] = []
var _demons: Array[Watcher] = []
var _plan: ApproachPlan
var _beat := Beat.STAMPING


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_lay_out()
	resized.connect(_lay_out)
	_stamp()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# 빛의 자리가 곧 커서다. 박을 기울이면 광택이 흐른다.
		_glyph.light_from(_to_glyph_uv((event as InputEventMouseMotion).position))
	elif event is InputEventMouseButton:
		var press := event as InputEventMouseButton
		if press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
			_strike_at(press.position)


func _draw() -> void:
	# 사방 테두리 대신 귀퉁이의 판 맞춤표. 이 화면이 인쇄 중인 판이라는 표시다
	# (docs/design/18-visual-identity.md §18.4).
	var inset := UiTokens.SPACE_RIFT
	for corner in [
		Vector2(inset, inset),
		Vector2(size.x - inset, inset),
		Vector2(size.x - inset, size.y - inset),
		Vector2(inset, size.y - inset),
	]:
		for stroke in UiShape.register_mark(corner, UiTokens.REGISTER_ARM, UiTokens.REGISTER_GAP):
			draw_polyline(stroke, UiTokens.INK_MUTED, UiTokens.RULE_HAIR)
		draw_polyline(
			UiShape.register_ring(corner, UiTokens.REGISTER_GAP * 1.6),
			UiTokens.INK_MUTED,
			UiTokens.RULE_HAIR
		)


## 노드 순서가 곧 인쇄 공정이다. 순서를 바꾸면 그림이 아니라 **공정이** 틀린다.
func _build() -> void:
	_paper = ColorRect.new()
	_paper.color = UiTokens.PAPER
	_paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_paper)

	# 원경 — 별색판. 렉카 악마들이 사람을 내려다본다.
	_far = _layer()
	for index in _DEMON_ANGLES.size():
		_demons.append(_place(_far, Watcher.Kind.DEMON, index))

	# 중경 — 먹판. 사방에서 다가오는 탐험대.
	_mid = _layer()
	for index in _SEEKER_ANGLES.size():
		_seekers.append(_place(_mid, Watcher.Kind.SEEKER, index))

	# 인쇄판. 이 아래 그려진 모든 것이 망점으로 다시 태어난다.
	_plate = PressPlate.new()
	_plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_plate)

	# **박은 판 뒤에 온다.** 공정이 그렇고, 그래서 금만 점이 아니게 된다.
	_glyph = FoilGlyph.new()
	add_child(_glyph)

	_plan = ApproachPlan.new(_seekers.size(), 4172)


func _layer() -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	return layer


func _place(into: Control, kind: Watcher.Kind, index: int) -> Watcher:
	var watcher := Watcher.new()
	watcher.kind = kind
	# 개체마다 어긋난 시각을 준다. 같은 값이면 넷이 한 몸처럼 깜빡인다.
	watcher.phase = float(index) * 2.137 + (0.0 if kind == Watcher.Kind.SEEKER else 11.3)
	into.add_child(watcher)
	return watcher


func _lay_out() -> void:
	if _glyph == null:
		return
	var short := minf(size.x, size.y)
	var side := short * _GLYPH_SHARE
	_glyph.size = Vector2(side, side)
	_glyph.position = (size - _glyph.size) * 0.5

	var middle := size * 0.5
	for index in _seekers.size():
		_seat(_seekers[index], _SEEKER_ANGLES[index], _SEEKER_RING, _SEEKER_SIZE, 0.0)
	for index in _demons.size():
		_seat(_demons[index], _DEMON_ANGLES[index], _DEMON_RING, _DEMON_SIZE, _DEMON_LIFT)
	# 사람은 금을 보고, 악마는 **가장 가까운 사람**을 본다. 시선의 사슬이다.
	for seeker in _seekers:
		seeker.watching = middle
	for demon in _demons:
		demon.watching = _nearest_seeker(demon.position + demon.size * 0.5)
	queue_redraw()


## 자리 하나. 화면이 가로로 길어도 원이 찌그러지지 않게 짧은 변으로 잰다.
##
## 마지막에 화면 안으로 **가둔다.** 가로로 벌리는 보정만 걸었다가 악마 셋 중 둘이
## 화면 밖으로 나가 버린 적이 있다 — 원경이 안 보이면 시선의 사슬이 끊긴다.
func _seat(watcher: Watcher, degrees: float, ring: float, share: float, lift: float) -> void:
	var short := minf(size.x, size.y)
	var span := short * share
	watcher.size = Vector2(span, span * 1.25)
	var away := Vector2.from_angle(deg_to_rad(degrees)) * short * ring
	# 가로로 넓은 화면에서는 옆으로 더 벌린다. 안 그러면 좌우가 텅 빈다.
	away.x *= maxf(size.x / maxf(size.y, 1.0), 1.0) * 0.82
	var seat := size * 0.5 + away - watcher.size * 0.5 - Vector2(0.0, short * lift)
	var edge := UiTokens.SPACE_GAP
	watcher.position = Vector2(
		clampf(seat.x, edge, maxf(size.x - watcher.size.x - edge, edge)),
		clampf(seat.y, edge, maxf(size.y - watcher.size.y - edge, edge))
	)


func _nearest_seeker(from: Vector2) -> Vector2:
	var best := size * 0.5
	var span := INF
	for seeker in _seekers:
		var middle := seeker.position + seeker.size * 0.5
		var away := from.distance_squared_to(middle)
		if away < span:
			span = away
			best = middle
	return best


## **한 번에 하나만 움직인다.** 순서는 ApproachPlan 이 정한다.
func _keep_creeping() -> void:
	var timer := get_tree().create_timer(_plan.wait())
	timer.timeout.connect(_creep_once)


func _creep_once() -> void:
	if _beat != Beat.DWELLING:
		return
	var index := _plan.next()
	if index >= 0 and index < _seekers.size():
		var seeker := _seekers[index]
		var middle := size * 0.5
		var away := (seeker.position + seeker.size * 0.5) - middle
		var short := minf(size.x, size.y)
		# 너무 가까워지면 **옆으로 돈다.** 노리는 것이지 덤비는 것이 아니다.
		var toward := (
			middle
			if away.length() > short * _SEEKER_HOLD
			else middle + away.orthogonal().normalized() * short
		)
		seeker.creep(toward)
	_keep_creeping()


## 첫 판을 찍고, 그 위에 박을 누른다. **화면이 뜨는 것 자체가 인쇄다.**
func _stamp() -> void:
	_beat = Beat.STAMPING
	_plate.print_edition(true)
	var tween := create_tween()
	tween.tween_interval(_STAMP_DELAY)
	tween.tween_callback(_glyph.strike)
	tween.tween_callback(
		func() -> void:
			_beat = Beat.DWELLING
			_keep_creeping()
	)


func _strike_at(where: Vector2) -> void:
	# 누른 자리에서 파문이 지면을 밀고 지나간다.
	_plate.strike_at(where)
	if _glyph.get_global_rect().has_point(get_global_transform() * where):
		_glyph.bruise_at(_to_glyph_uv(where))


func _to_glyph_uv(where: Vector2) -> Vector2:
	var span := _glyph.size
	if span.x < 1.0 or span.y < 1.0:
		return Vector2(0.5, 0.5)
	return (where - _glyph.position) / span
