class_name TitleScreen
extends Control
## **타이틀.** 이 게임의 첫 화면이고, 제목이 두 뜻을 진다는 것을 그림 하나로 말한다.
##
## 근거와 컨셉은 docs/design/21-title.md 에 있다. 요약하면 한 줄이다.
##
##   「금」은 신문지에 눌러 찍은 금박이다. 값싼 종이는 박을 붙들지 못한다.
##   그래서 **금은 반드시 금이 간다.**
##
## 이 씬은 **부팅이 닿는 첫 화면이다.** `main` 이 여기로 넘긴다
## (docs/design/34-systems.md §34.5) — 21.7 이 통합자에게 남겨 둔 자리를 채운 것이다.
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

const _SEEKER_SIZE := 0.20

## 이보다 가까워지면 더 다가가지 않고 **옆으로 돈다.** 노리는 것이지 덤비는 것이 아니다.
const _SEEKER_HOLD := 0.30

## 악마가 앉는 자리. 사람보다 위, 사람보다 작다 — 멀리 있기 때문이다.

const _DEMON_SIZE := 0.185
const _DEMON_LIFT := 0.26

## 사람이 앉는 각도(도)와 **저마다 다른 크기.**
##
## 처음에는 넷을 같은 크기로 사방에 고르게 놓았다. 심사자 둘이 같은 말을 했다 —
## "완벽한 좌우 대칭에 간격도 크기도 균일해서 문장(紋章)이나 로고 시안처럼 보인다.
##  스무 프레임 중 겹치는 것이 한 쌍뿐이라 **화면에 공간이 없다.**
##  눈이 멈추게 하는 것은 밀도 대비인데 이 화면에는 밀도가 하나뿐이다."
##
## 그래서 뭉치는 쪽과 비는 쪽을 만든다. 가까운 것은 크고 먼 것은 작다.
const _SEEKER_ANGLES: Array[float] = [204.0, 232.0, 342.0, 96.0]
const _SEEKER_SCALES: Array[float] = [1.22, 0.72, 1.0, 0.86]
const _SEEKER_RINGS: Array[float] = [0.33, 0.52, 0.40, 0.46]

## 악마가 앉는 각도(도). **한쪽 위에 몰아 둔다** — 셋이 한 자리에서 같이 본다.
const _DEMON_ANGLES: Array[float] = [258.0, 292.0, 316.0]
const _DEMON_SCALES: Array[float] = [1.34, 0.78, 0.56]
const _DEMON_RINGS: Array[float] = [0.50, 0.66, 0.80]

## 내려가는 문. **금을 누르는 것과 갈라 두었다** —
## 21.5 가 「금을 누르면 그 자리의 박이 떨어진다」를 확정해 두었으므로
## 금 위의 클릭을 시작 버튼으로 쓰면 그 규칙과 다툰다.
##
## **조형은 잠정이다** (§21.9 — *"메뉴 항목의 형태와 반응 미정"*).
## 여기 있는 것은 흐름이 서 있다는 것을 화면에서 확인하기 위한 최소한이고,
## 타이틀 레인이 메뉴를 정하면 이 한 줄만 그것으로 바뀐다.
const _ENTER_TEXT := "들어간다"

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
	# 이 씬이 이제 트리의 뿌리다. 예전에는 `main` 이 물려 준 테마를 받았는데
	# 씬을 갈아 끼우면 그것이 따라오지 않으므로 여기서 문다.
	theme = UiTheme.get_theme()
	_build()
	_build_door()
	_lay_out()
	resized.connect(_lay_out)
	descend_requested.connect(_descend)
	_stamp()


## 내려간다. **어느 씬인지 여기서 적지 않는다** — 화면 이름만 말한다
## (docs/design/34-systems.md §34.3.1).
func _descend() -> void:
	if _beat == Beat.DESCENDING:
		return
	_beat = Beat.DESCENDING
	Router.go_to(SceneRoutes.Screen.BASE)


## 문 하나. **다른 겹을 다 덮은 뒤에 놓는다** — 눌려야 하므로 맨 위여야 한다.
func _build_door() -> void:
	var door := Button.new()
	door.text = _ENTER_TEXT
	door.focus_mode = Control.FOCUS_NONE
	door.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	door.grow_horizontal = Control.GROW_DIRECTION_BOTH
	door.grow_vertical = Control.GROW_DIRECTION_BEGIN
	door.offset_bottom = -float(UiTokens.SPACE_RIFT)
	door.pressed.connect(func() -> void: Sfx.play(SfxEvent.Kind.UI_PRESS))
	door.pressed.connect(descend_requested.emit)
	add_child(door)


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
	_unfold_the_sheet()

	# **박은 판 뒤에 온다.** 공정이 그렇고, 그래서 금만 점이 아니게 된다.
	_glyph = FoilGlyph.new()
	add_child(_glyph)

	_plan = ApproachPlan.new(_seekers.size(), 4172)


## **이 지면만 접지 않는다.**
##
## 인쇄판은 지면에 접힌 자리를 만든다(`ink_plate.gdshader` §1). 판 화면에서는
## "판은 책상 위의 종이"라는 사실을 만드는 좋은 장치인데, 타이틀에서는 **재앙**이었다.
##
## 1280 폭에 접힘 주기가 1180 이라 화면 한가운데에 세로줄이 하나 선다.
## 심사자 둘이 각각 그 줄을 보고 이렇게 말했다 —
##
##   "화면에서 가장 큰 세로선이 균열인 줄 알았다. 자로 그은 듯 곧고 가운데 있어서
##    오히려 페이지 구분선이나 뷰포트 분할 버그로 읽힌다."
##   "세로선이 둘인데 서로 다른 선이다. 제목이 균열인 게임에서
##    **진짜 금이 접힌 자국에게 진다.**"
##
## 이 화면에서 세로선은 **하나여야 하고 그것은 금이어야 한다.** 그래서 접힘 주기를
## 화면 밖으로 밀어낸다. 셰이더를 고치는 것이 아니라 이 씬에서 값만 바꾼다 —
## `src/ui/style/` 는 다른 레인의 것이다.
func _unfold_the_sheet() -> void:
	var plate := _plate.material as ShaderMaterial
	if plate != null:
		plate.set_shader_parameter("fold_pitch", 100000.0)


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
		_seat(
			_seekers[index],
			_SEEKER_ANGLES[index],
			_SEEKER_RINGS[index],
			_SEEKER_SIZE * _SEEKER_SCALES[index],
			0.0
		)
	for index in _demons.size():
		_seat(
			_demons[index],
			_DEMON_ANGLES[index],
			_DEMON_RINGS[index],
			_DEMON_SIZE * _DEMON_SCALES[index],
			_DEMON_LIFT
		)
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
