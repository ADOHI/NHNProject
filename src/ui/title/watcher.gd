class_name Watcher
extends Control
## **지켜보는 것 하나.** 금을 노리는 사람이거나, 그 사람을 중계하는 악마다.
##
## 이 화면의 뼈대는 **시선의 사슬**이다(docs/design/21-title.md §21.3).
##
##   사람은 **금**을 본다 · 악마는 **사람**을 본다 · 플레이어는 전부를 본다
##
## 악마가 금을 보지 않는 것이 중요하다. **구경거리는 금이 아니라 사람이다**
## ([`02`](02-overview.md) §2.5).
##
## 그리고 잉크가 곧 겹이다 — 사람은 먹판(사실), 악마는 별색판(과장)이다.
## 인쇄판을 통과하면 사람은 검은 망점이 되고 악마는 붉은 망점이 된다.
##
## 지금은 형태를 코드가 만든다. 생성 이미지로 갈아 끼우더라도 **움직임과 배치는
## 여기 그대로 남는다** — 그림이 바뀌어도 시선의 사슬은 바뀌지 않기 때문이다.

enum Kind {
	## 탐험대. 금을 보고, 재고, 한 걸음씩 다가온다. 달려들지 않는다
	SEEKER,
	## 렉카 악마. 눈이 하나고, 사람을 보고, 웃는다
	DEMON,
}

## 다가오는 한 걸음의 길이(자기 폭 기준). 크게 주면 달려드는 것으로 보인다 —
## 이 게임은 턴제다.
const _STRIDE := 0.34

## 한 걸음에 걸리는 시간. 걸음보다 **멈춰 있는 시간이 훨씬 길다.**
const _STEP_SECONDS := 0.52

## 눈을 감았다 뜨는 시간. 사람의 것보다 빨라야 사람이 아닌 것으로 보인다.
const _BLINK_SECONDS := 0.09

@export var kind := Kind.SEEKER

## 무엇을 보고 있는가. 부모가 화면 좌표로 넣어 준다.
@export var watching := Vector2.ZERO

## 이 개체 고유의 흔들림. 같은 값을 주면 전부 한 몸처럼 움직인다.
@export var phase := 0.0

var _home := Vector2.ZERO
var _lean := 0.0
var _blink := 1.0
var _pupil := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_home = position
	if kind == Kind.DEMON:
		_keep_blinking()


func _process(_delta: float) -> void:
	var seconds := UiMotion.clock() + phase
	if kind == Kind.DEMON:
		# **눈동자가 상대를 겨눈다.** 이 화면의 주장이 여기 실려 있다 —
		# 악마는 금이 아니라 **사람**을 본다.
		#
		# 처음에는 눈동자를 사인파로 굴리기만 했다. 심사자 둘이 각각
		# "눈동자가 스무 프레임 내내 정가운데 박혀 있다. 못 움직이는 눈동자는
		# 노려볼 수 없고, 그 노려봄이 이 기획에서 가장 날카로운 생각인데
		# 화면에 전혀 없다" 고 지적했다. 굴러다니기만 하는 눈은 겨누지 못한다.
		var aim := _gaze()
		# 겨눔이 8, 흔들림이 2. 완전히 고정하면 인형 눈이 된다.
		_pupil = aim * 0.34 + Vector2(sin(seconds * 1.9), cos(seconds * 1.3)) * 0.05
	queue_redraw()


func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	if kind == Kind.SEEKER:
		_draw_seeker()
	else:
		_draw_demon()


## **한 걸음 다가간다.** 그리고 멈춘다.
##
## 이 게임은 턴제라 화면도 순서를 지켜야 한다. 여럿이 동시에 움직이면
## 그것은 돌격이지 탐색이 아니다 — 누가 언제 움직이는가는 부모가 정한다.
func creep(toward: Vector2) -> void:
	var direction := (toward - _center()).normalized()
	var tween := create_tween()
	tween.set_parallel(true)
	# 무게를 앞발에 옮겼다가 몸이 따라온다. 미끄러져 오면 인형이다.
	(
		tween
		. tween_method(_set_lean, 0.0, 1.0, _STEP_SECONDS * 0.35)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_QUINT)
	)
	(
		tween
		. tween_property(self, "position", position + direction * size.x * _STRIDE, _STEP_SECONDS)
		. set_ease(Tween.EASE_IN_OUT)
		. set_trans(Tween.TRANS_CUBIC)
	)
	(
		tween
		. chain()
		. tween_method(_set_lean, 1.0, 0.0, _STEP_SECONDS * 0.8)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_BACK)
	)


func _center() -> Vector2:
	return position + size * 0.5


func _set_lean(value: float) -> void:
	_lean = value


func _set_blink(value: float) -> void:
	_blink = value


## 깜빡임은 규칙적이면 기계가 된다. 개체마다 주기를 달리 잡는다.
func _keep_blinking() -> void:
	var tween := create_tween().set_loops()
	tween.tween_interval(1.6 + fmod(absf(phase) * 1.7, 2.9))
	tween.tween_method(_set_blink, 1.0, 0.06, _BLINK_SECONDS).set_ease(Tween.EASE_IN)
	tween.tween_method(_set_blink, 0.06, 1.0, _BLINK_SECONDS * 1.6).set_ease(Tween.EASE_OUT)


## 내가 보는 쪽. 화면 좌표를 내 안의 방향으로 바꾼다.
func _gaze() -> Vector2:
	var away := watching - _center()
	return Vector2.RIGHT if away.length_squared() < 1.0 else away.normalized()


# ---------------------------------------------------------------------------
# 탐험대 — 먹판
# ---------------------------------------------------------------------------


## 웅크리고 재는 자세.
##
## **머리가 등짐보다 낮아야 한다.** 이 하나가 서 있는 사람과 기어드는 사람을 가른다.
## 앞무릎은 세우고 뒷다리는 뒤에 길게 남긴다 — 언제든 물러설 수 있는 자세다.
## 처음에 다리를 곧게 세웠더니 "상자 진 사람"으로 보였다.
func _draw_seeker() -> void:
	var w := size.x
	var ink := UiTokens.INK
	# 기울기는 걸음에서 나온다. 멈춰 있을 때도 완전히 펴지 않는다.
	var tip := 0.05 + _lean * 0.09
	var mirror := _gaze().x < 0.0

	# 뒷다리 — 뒤로 길게 뻗어 땅을 짚는다. 무게가 뒤에 있다는 표시다.
	_limb(Vector2(0.46, 0.60), Vector2(0.24, 0.80), 0.13, 0.10, mirror)
	_limb(Vector2(0.24, 0.80), Vector2(0.13 - _lean * 0.05, 0.98), 0.10, 0.06, mirror)

	# 앞다리 — 무릎을 높이 세운다. 이 각이 웅크림을 만든다.
	_limb(Vector2(0.54, 0.60), Vector2(0.76 + tip, 0.66), 0.15, 0.11, mirror)
	_limb(Vector2(0.76 + tip, 0.66), Vector2(0.70 + tip, 0.98), 0.11, 0.07, mirror)

	# 몸통 — 앞으로 깊게 굽는다. 등이 둥글고 가슴이 무릎에 붙는다.
	_polygon(
		[
			Vector2(0.36, 0.46),
			Vector2(0.48 + tip, 0.38),
			Vector2(0.64 + tip, 0.44),
			Vector2(0.63, 0.64),
			Vector2(0.38, 0.64),
		],
		mirror
	)

	# 등짐 — **등에 낮게 묶인 보따리**다. 어깨 위로 올리지 않는다.
	#
	# 처음에는 머리 높이에 큰 사각형을 얹었는데, 심사자 둘이 각각
	# "어깨에 멘 방송 카메라" · "촬영기자 넷" 으로 읽었다. 치명적이다 —
	# **촬영은 악마의 역할**이라 두 진영이 통째로 뒤집혀 읽혔다.
	# 그래서 상자를 없애고, 등 뒤 아래쪽에 기울어진 보따리로 바꿨다.
	_polygon(
		[
			Vector2(0.26, 0.50),
			Vector2(0.40, 0.44),
			Vector2(0.44, 0.60),
			Vector2(0.29, 0.65),
		],
		mirror
	)

	# 머리 — 앞으로 **낮게** 내민다. 목이 보이도록 몸통에서 떼어 놓는다.
	# 상자에 붙은 동그라미가 되면 그 순간 렌즈로 읽힌다.
	_limb(Vector2(0.58 + tip, 0.44), Vector2(0.68 + tip, 0.40), 0.09, 0.08, mirror)
	_circle(Vector2(0.74 + tip, 0.395), 0.093, mirror, ink)

	# 앞팔 — **길게 뻗어 금 쪽으로 간다.** 닿지는 않는다.
	# 뻗은 팔 하나가 "재고 있다"를 자세만으로 말한다.
	var reach := Vector2(0.99 + tip, 0.60)
	_limb(Vector2(0.60 + tip, 0.46), Vector2(0.82 + tip, 0.50), 0.072, 0.058, mirror)
	_limb(Vector2(0.82 + tip, 0.50), reach, 0.058, 0.038, mirror)

	# 뒷팔 — 등불을 땅에 가깝게 늘어뜨린다. 높이 들면 자기가 먼저 보인다.
	# 등불은 **각진 통**이다. 동그라미로 만들면 렌즈가 된다.
	var grip := Vector2(0.40, 0.78)
	_limb(Vector2(0.44, 0.50), grip, 0.062, 0.045, mirror)
	_polygon(
		[
			Vector2(grip.x - 0.055, grip.y),
			Vector2(grip.x + 0.055, grip.y),
			Vector2(grip.x + 0.040, grip.y + 0.115),
			Vector2(grip.x - 0.040, grip.y + 0.115),
		],
		mirror
	)
	# 불빛은 종이색으로 **뚫는다.** 지면에서 밝다는 것은 잉크가 없다는 뜻이다.
	_polygon(
		[
			Vector2(grip.x - 0.026, grip.y + 0.028),
			Vector2(grip.x + 0.026, grip.y + 0.028),
			Vector2(grip.x + 0.019, grip.y + 0.088),
			Vector2(grip.x - 0.019, grip.y + 0.088),
		],
		mirror,
		UiTokens.PAPER
	)


## 왼쪽을 볼 때는 그림을 통째로 뒤집는다. 자세를 두 벌 그리지 않기 위해서다.
func _flip(point: Vector2, mirror: bool) -> Vector2:
	return Vector2((1.0 - point.x) if mirror else point.x, point.y) * size


func _polygon(points: Array, mirror: bool, tint: Color = UiTokens.INK) -> void:
	var out := PackedVector2Array()
	for point in points:
		out.append(_flip(point as Vector2, mirror))
	draw_colored_polygon(out, tint)


func _circle(at: Vector2, radius: float, mirror: bool, tint: Color) -> void:
	draw_circle(_flip(at, mirror), size.x * radius, tint)


## 팔다리 한 마디. 끝으로 갈수록 가늘어지는 사각형이다.
func _limb(from: Vector2, to: Vector2, thick: float, thin: float, mirror: bool) -> void:
	var a := _flip(from, mirror)
	var b := _flip(to, mirror)
	var normal := (b - a).orthogonal().normalized()
	if normal.length_squared() < 0.5:
		normal = Vector2.RIGHT
	draw_colored_polygon(
		PackedVector2Array(
			[
				a + normal * size.x * thick * 0.5,
				b + normal * size.x * thin * 0.5,
				b - normal * size.x * thin * 0.5,
				a - normal * size.x * thick * 0.5,
			]
		),
		UiTokens.INK
	)


# ---------------------------------------------------------------------------
# 렉카 악마 — 별색판
# ---------------------------------------------------------------------------


## 눈 하나와 이빨. **귀엽게 만들지 않는다** — 웃고 있지만 즐거운 쪽은 저쪽뿐이다.
func _draw_demon() -> void:
	var w := size.x
	var h := size.y
	var spot := UiTokens.SPOT
	var seconds := UiMotion.clock() + phase

	# 몸. 아래로 갈수록 흩어지는 누더기다. 바닥에 닿지 않으므로 떠 있는 것이 된다.
	var drape := PackedVector2Array()
	drape.append(Vector2(0.30, 0.44) * size)
	drape.append(Vector2(0.70, 0.44) * size)
	for step in 9:
		var ratio := float(step) / 8.0
		var jag := UiShape.wiggle(phase * 3.0 + float(step))
		var sway := sin(seconds * 0.9 + ratio * 2.4) * 0.03
		drape.append(Vector2(0.70 - ratio * 0.40 + sway, 0.80 + jag * 0.34) * size)
	draw_colored_polygon(drape, UiTokens.fade(spot, 0.92))

	# 팔. 길고 가늘다. 무언가를 가리키고 있다 — 저기 사람이 있다고
	var reach := _gaze()
	for side in [-1.0, 1.0]:
		var elbow := Vector2(0.5 + side * 0.24, 0.52)
		var hand := elbow + reach * 0.26 + Vector2(0.0, sin(seconds * 1.3 + side) * 0.03)
		draw_polyline(
			PackedVector2Array(
				[Vector2(0.5 + side * 0.14, 0.46) * size, elbow * size, hand * size]
			),
			spot,
			maxf(w * 0.022, 1.5)
		)

	# 눈 하나. 이 개체의 머리는 통째로 눈이다.
	#
	# **동심원을 그리면 안 된다.** 원 안의 원은 눈이 아니라 과녁이고,
	# 과녁은 이 화면에서 가장 흔한 도형이 된다. 그래서 셋을 어긋내 놓는다 —
	# 흰자는 세로로 길고, 홍채는 가운데가 아니며, 눈동자는 홍채 안에서 또 굴러다닌다.
	var eye := Vector2(0.5, 0.30) * size
	var radius := w * 0.26
	# 깜빡임은 위아래로 눌러서 만든다. 덮개를 그리면 눈꺼풀이 생겨 사람 얼굴이 된다.
	var lid := maxf(_blink, 0.02)
	draw_set_transform(eye, 0.0, Vector2(0.88, lid * 1.06))
	draw_circle(Vector2.ZERO, radius, UiTokens.PAPER)
	# 테두리는 한 바퀴가 아니다. 위쪽이 끊겨 있어야 그려 놓은 원이 아니라 살로 보인다.
	draw_arc(Vector2.ZERO, radius, -0.62, TAU - 1.05, 28, spot, maxf(w * 0.036, 1.5))
	var iris := _pupil * radius + Vector2(0.0, radius * 0.10)
	draw_circle(iris, radius * 0.52, UiTokens.fade(spot, 0.45))
	draw_circle(iris + _pupil * radius * 0.35, radius * 0.30, spot)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 이빨. 눈 밑에 바로 붙는다. 얼굴이 아니라 **입이 달린 눈**이다.
	var grin := PackedVector2Array()
	var left := 0.5 - 0.22
	grin.append(Vector2(left, 0.50) * size)
	for step in 7:
		var ratio := float(step) / 6.0
		var drop := 0.50 + (0.075 if step % 2 == 0 else 0.02)
		grin.append(Vector2(left + ratio * 0.44, drop) * size)
	grin.append(Vector2(left + 0.44, 0.50) * size)
	draw_colored_polygon(grin, spot)
