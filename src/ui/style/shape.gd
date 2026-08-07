class_name UiShape
extends RefCounted
## 인쇄물의 **형태를 절차적으로 만든다.** 이미지 파일을 하나도 쓰지 않기 위한 도구다.
##
## 여기 있는 함수는 전부 순수하다 — 노드도 캔버스도 모르고, 점 목록만 돌려준다.
## 그리는 일은 부르는 쪽이 draw_polyline / draw_colored_polygon 으로 한다.
## 그래서 씬 없이 단위 테스트할 수 있다 (test/unit/test_ui_shape.gd).
##
## 형태를 셰이더에 넣지 않는 이유가 있다. 형태까지 GLSL 안에 들어가면
## 모서리 규칙이 셰이더마다 복제되고 테스트도 재사용도 안 된다.
## **셰이더는 질감, 여기는 형태.**
##
## 아이콘을 글자로 찍지 않는 이유도 있다. 폰트가 SongMyung 하나뿐이고
## 그 안에 화살표•기호 글리프가 없어서 웹 빌드에서 두부(□)가 된다
## (docs/conventions.md §5.1). **없는 글자를 쓰느니 형태를 만든다.**

## 모서리 순서. 판 맞춤표를 놓을 자리를 고를 때 쓴다.
enum Corner { TOP_LEFT, TOP_RIGHT, BOTTOM_RIGHT, BOTTOM_LEFT }

## 45도 사선의 방향과 법선. 오커 겹쳐찍기에 쓴다.
const _DIAGONAL := Vector2(0.70710678, -0.70710678)
const _DIAGONAL_NORMAL := Vector2(0.70710678, 0.70710678)

const _EPSILON := 0.001


## 사각형을 폴리곤으로. 잘라내기(clip)에 넘길 때 쓴다.
static func rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y),
		]
	)


## 닫힌 윤곽선. draw_polyline 은 마지막 점과 첫 점을 잇지 않으므로 첫 점을 덧붙인다.
static func closed_outline(polygon: PackedVector2Array) -> PackedVector2Array:
	if polygon.is_empty():
		return polygon
	var outline := PackedVector2Array(polygon)
	outline.append(polygon[0])
	return outline


## **찢긴 가장자리.** 오려 낸 조각은 자로 자른 것이 아니다.
##
## 이 게임에서 오려 낸 조각은 곧 **렉카가 실어 나른 말**이다
## (docs/design/18-visual-identity.md §18.4). 계측은 괘선으로 반듯하게 갇히고
## 송출은 찢겨 나온다 — 읽기 전에 어느 쪽인지 알 수 있어야 한다.
##
## 흔들림은 자리에서 결정된다. 프레임마다 다시 뽑으면 종이가 지직거린다.
static func deckle_edge(
	rect: Rect2, amplitude: float, step: float, seed_value: float = 0.0
) -> PackedVector2Array:
	var points := PackedVector2Array()
	var stride := maxf(step, 2.0)
	var index := 0.0
	for pair in [
		[rect.position, Vector2(rect.end.x, rect.position.y)],
		[Vector2(rect.end.x, rect.position.y), rect.end],
		[rect.end, Vector2(rect.position.x, rect.end.y)],
		[Vector2(rect.position.x, rect.end.y), rect.position],
	]:
		var from: Vector2 = pair[0]
		var to: Vector2 = pair[1]
		var span := from.distance_to(to)
		if span <= _EPSILON:
			continue
		var normal := (to - from).orthogonal().normalized()
		var count := maxi(2, int(span / stride))
		for slot in count:
			index += 1.0
			var ratio := float(slot) / float(count)
			var wobble := wiggle(seed_value * 7.0 + index)
			points.append(from.lerp(to, ratio) + normal * wobble * amplitude)
	return points


## 같은 자리에서는 늘 같은 값이 나오는 -0.5 ~ 0.5 흔들림.
##
## 난수 발생기를 쓰지 않는 이유는, 다시 그릴 때마다 값이 달라지면
## 가만히 있어야 할 종이가 프레임마다 떨리기 때문이다.
static func wiggle(seed_value: float) -> float:
	return fmod(absf(sin(seed_value * 12.9898) * 43758.5453), 1.0) - 0.5


## **판 맞춤표.** 인쇄판을 겹쳐 앉힐 때 쓰는 십자 표적이다.
##
## 사방 테두리를 두르는 대신 귀퉁이에만 표를 둔다. 얇은 테두리를 두른 사각형은
## 어느 게임에나 있지만, 맞춤표는 **이 화면이 인쇄 중인 판이라는 사실 자체**다.
## 그리고 이 게임의 서명이 정합이므로, 맞춤표는 서명이 놓인 자리이기도 하다.
static func register_mark(center: Vector2, arm: float, gap: float) -> Array[PackedVector2Array]:
	var strokes: Array[PackedVector2Array] = []
	var inner := clampf(gap, 0.0, arm)
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		strokes.append(PackedVector2Array([center + direction * inner, center + direction * arm]))
	return strokes


## 맞춤표를 감싸는 원. 십자만 있으면 눈금으로 보이고, 원이 붙어야 표적이 된다.
static func register_ring(center: Vector2, radius: float, segments: int = 20) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in segments + 1:
		var angle := float(index) / float(segments) * TAU
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


## **괘선 다발.** 신문의 굵은 선 밑에는 늘 가는 선이 한 줄 더 있다.
##
## 선 하나로는 위계가 안 나온다. 굵기가 다른 선을 붙여 놓으면
## 그 자리가 "면이 갈리는 곳"이라는 뜻이 된다.
static func rule_stack(
	origin: Vector2, width: float, weights: PackedFloat32Array, gap: float
) -> Array[Rect2]:
	var rules: Array[Rect2] = []
	var cursor := origin.y
	for weight in weights:
		if weight <= _EPSILON:
			cursor += gap
			continue
		rules.append(Rect2(Vector2(origin.x, cursor), Vector2(width, weight)))
		cursor += weight + gap
	return rules


## **속보 깃발.** 오른쪽 끝이 안쪽으로 파인 조각이다.
##
## 축에 정렬된 사각형만 있으면 화면이 표가 된다. 별색판에만 이 형태를 주어
## 사실과 이야기를 형태로도 갈라 놓는다.
static func pennant(rect: Rect2, notch: float) -> PackedVector2Array:
	var bite := clampf(notch, 0.0, rect.size.x * 0.5)
	return PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			Vector2(rect.end.x - bite, rect.get_center().y),
			Vector2(rect.end.x, rect.end.y),
			Vector2(rect.position.x, rect.end.y),
		]
	)


## 점선 한 줄을 이루는 선분들. 각 원소는 점 두 개다.
##
## 통로를 이어진 선으로 그리지 않는 이유는 세계관에서 나온다.
## **통로는 중계 구역이 아니다** — 카메라가 없으니 지면에 실을 그림도 없다
## (docs/design/02-overview.md §2.6.1).
static func dash_segments(
	from: Vector2, to: Vector2, dash: float, gap: float
) -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array] = []
	var span := from.distance_to(to)
	var stride := maxf(dash + gap, _EPSILON)
	if span <= _EPSILON or dash <= _EPSILON:
		return segments
	var direction := (to - from) / span
	var travelled := 0.0
	while travelled < span:
		var tail := minf(travelled + dash, span)
		segments.append(PackedVector2Array([from + direction * travelled, from + direction * tail]))
		travelled += stride
	return segments


## **오커 겹쳐찍기.** 산업 안전 표지의 사선을 한 판 더 얹은 것이다.
##
## "못 간다"를 색만으로 말하면 색약자에게 사라지고, 글자로 말하면 자리를 먹는다.
## 겹쳐찍기는 인쇄물에서 실제로 쓰는 강조라 지면의 문법과도 어긋나지 않는다.
static func hazard_stripes(
	rect: Rect2, pitch: float, thickness: float, clip: PackedVector2Array
) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = []
	if pitch <= _EPSILON or clip.size() < 3:
		return pieces
	var lowest := INF
	var highest := -INF
	# 사선 방향으로도 어디까지 뻗어야 하는지 재 둔다.
	#
	# 여기를 rect.size 로만 잡으면 원점 근처의 사각형에서만 맞고, 화면 한가운데 놓인
	# 사각형에서는 사선이 도형에 닿기도 전에 끝나 아무것도 안 그려진다.
	# 실제로 그렇게 만들었다가 견본쇄에서 겹쳐찍기가 통째로 사라진 적이 있다.
	var near := INF
	var far := -INF
	for corner in [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	]:
		var point: Vector2 = corner
		lowest = minf(lowest, point.dot(_DIAGONAL_NORMAL))
		highest = maxf(highest, point.dot(_DIAGONAL_NORMAL))
		near = minf(near, point.dot(_DIAGONAL))
		far = maxf(far, point.dot(_DIAGONAL))
	var reach := maxf(absf(near), absf(far)) + pitch
	var offset := floorf(lowest / pitch) * pitch
	while offset < highest:
		var base := _DIAGONAL_NORMAL * offset
		var stripe := PackedVector2Array(
			[
				base - _DIAGONAL * reach,
				base + _DIAGONAL * reach,
				base + _DIAGONAL * reach + _DIAGONAL_NORMAL * thickness,
				base - _DIAGONAL * reach + _DIAGONAL_NORMAL * thickness,
			]
		)
		for piece in Geometry2D.intersect_polygons(stripe, clip):
			pieces.append(piece)
		offset += pitch
	return pieces


## 오르내림을 알리는 갈매기표. 글리프가 없어서 직접 그린다.
static func chevron(
	center: Vector2, half_width: float, height: float, upward: bool
) -> PackedVector2Array:
	var lift := height * (-0.5 if upward else 0.5)
	return PackedVector2Array(
		[
			Vector2(center.x - half_width, center.y - lift),
			Vector2(center.x, center.y + lift),
			Vector2(center.x + half_width, center.y - lift),
		]
	)


## **판독률 눈금.** 이 방의 원판이 얼마나 쓸 만한가를 칸으로 보여 준다.
##
## 몇 칸이 찼는지가 곧 이 숫자를 얼마나 믿어도 되는가다
## (docs/design/13-information-design.md §13.6).
static func gauge_bars(origin: Vector2, count: int, bar: Vector2, gap: float) -> Array[Rect2]:
	var bars: Array[Rect2] = []
	for index in count:
		var height := bar.y * (0.45 + 0.55 * (float(index) / maxf(float(count - 1), 1.0)))
		var left := origin.x + float(index) * (bar.x + gap)
		bars.append(Rect2(Vector2(left, origin.y + bar.y - height), Vector2(bar.x, height)))
	return bars


## 지면 눈금. 선 하나를 따라 수직으로 짧은 선을 세운다.
static func tick_ruler(
	from: Vector2, to: Vector2, count: int, length: float
) -> Array[PackedVector2Array]:
	var ticks: Array[PackedVector2Array] = []
	if count <= 0:
		return ticks
	var normal := (to - from).orthogonal().normalized()
	for index in count:
		var ratio := float(index) / float(maxi(count - 1, 1))
		var point := from.lerp(to, ratio)
		var reach := length if index % 2 == 0 else length * 0.5
		ticks.append(PackedVector2Array([point, point + normal * reach]))
	return ticks
