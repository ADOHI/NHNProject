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
		# 눈알이 천천히 돈다. 지켜보는 것은 가만히 있어도 눈은 움직인다.
		_pupil = Vector2(sin(seconds * 0.7), cos(seconds * 0.53) * 0.6) * 0.16
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

	# 몸통 — 앞으로 깊게 굽는다. 위가 좁고 아래가 넓다.
	_polygon(
		[
			Vector2(0.40 + tip, 0.36),
			Vector2(0.63 + tip, 0.40),
			Vector2(0.62, 0.64),
			Vector2(0.38, 0.62),
		],
		mirror
	)

	# 등짐 — 등 쪽 혹. **실루엣에서 가장 높은 것이 이것이어야 한다.**
	_polygon(
		[
			Vector2(0.26, 0.30),
			Vector2(0.45 + tip, 0.30),
			Vector2(0.46, 0.58),
			Vector2(0.22, 0.54),
		],
		mirror
	)

	# 머리 — 앞으로 내밀되 **등짐보다 아래**다. 들여다보는 자세다.
	_circle(Vector2(0.66 + tip, 0.40), 0.105, mirror, ink)

	# 팔 — 등불을 땅 가까이 든다. 높이 들면 자기가 먼저 보인다.
	var grip := Vector2(0.86 + tip, 0.74)
	_limb(Vector2(0.58 + tip, 0.44), grip, 0.075, 0.055, mirror)
	# 불빛은 종이색으로 뚫는다. 지면에서 밝다는 것은 **잉크가 없다**는 뜻이다.
	_circle(grip, 0.052, mirror, ink)
	_circle(grip, 0.026, mirror, UiTokens.PAPER)


## 왼쪽을 볼 때는 그림을 통째로 뒤집는다. 자세를 두 벌 그리지 않기 위해서다.
func _flip(point: Vector2, mirror: bool) -> Vector2:
	return Vector2((1.0 - point.x) if mirror else point.x, point.y) * size


func _polygon(points: Array, mirror: bool) -> void:
	var out := PackedVector2Array()
	for point in points:
		out.append(_flip(point as Vector2, mirror))
	draw_colored_polygon(out, UiTokens.INK)


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
	var eye := Vector2(0.5, 0.30) * size
	var radius := w * 0.26
	# 깜빡임은 위아래로 눌러서 만든다. 덮개를 그리면 눈꺼풀이 생겨 사람 얼굴이 된다.
	var lid := maxf(_blink, 0.02)
	draw_set_transform(eye, 0.0, Vector2(1.0, lid))
	draw_circle(Vector2.ZERO, radius, UiTokens.PAPER)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 30, spot, maxf(w * 0.03, 1.5))
	draw_circle(_pupil * radius, radius * 0.44, spot)
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
