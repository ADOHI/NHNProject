class_name GraphicCut
extends RefCounted
## **판이 직사각형이 아니다.** 자르고 · 기울이고 · 뜯는 순수 계산이다.
##
## docs/design/20-ui-kit.md §20.28.
##
## ## 왜 이것이 핵심인가
##
## 앞의 판들(§20.26 · §20.27)은 전부 **「이 UI 는 무슨 물질인가」**를 물었다 —
## 돌 · 금박 · 신문지 · 쇳물. 그게 기각당한 이유다.
##
## > **페르소나 5 계열은 물질을 흉내 내지 않는다. 그래픽 디자인으로 승부한다.**
##
## 그 문법의 첫 항목이 **직사각형이 아닌 판**이다. 사각형에 재료를 아무리 발라도
## 그 문법에 못 들어간다 — **형태가 먼저다.**
##
## ## 무늬도 재질이 아니라 그래픽이다
##
## 줄무늬와 망점을 **평평하게** 깐다. 판 안에만 들어가야 하므로 `Geometry2D` 로
## 잘라 낸다 — 흐릿하게 덧칠하는 게 아니라 **정확히 잘린 도형**이다.

## 기울기. 평행사변형이 이만큼 눕는다(가로 픽셀 / 세로 픽셀).
const LEAN := 0.28


## 평행사변형. **위가 오른쪽으로 밀린다.**
static func lean(box: Rect2, slant: float = LEAN) -> PackedVector2Array:
	var push := box.size.y * slant
	return PackedVector2Array(
		[
			Vector2(box.position.x + push, box.position.y),
			Vector2(box.end.x + push, box.position.y),
			Vector2(box.end.x, box.end.y),
			Vector2(box.position.x, box.end.y),
		]
	)


## 한쪽 모서리만 비스듬히 잘린 판. `which` 는 자를 모서리 넷의 비트다
## (1 왼위 · 2 오른위 · 4 오른아래 · 8 왼아래).
##
## **넷을 다 자르면 팔각형이 되어 얌전해진다.** 하나나 둘만 자른다.
static func clipped(box: Rect2, cut: float, which: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var reach := minf(cut, minf(box.size.x, box.size.y) * 0.5)
	if which & 1:
		out.append(Vector2(box.position.x + reach, box.position.y))
	else:
		out.append(box.position)
	if which & 2:
		out.append(Vector2(box.end.x - reach, box.position.y))
		out.append(Vector2(box.end.x, box.position.y + reach))
	else:
		out.append(Vector2(box.end.x, box.position.y))
	if which & 4:
		out.append(Vector2(box.end.x, box.end.y - reach))
		out.append(Vector2(box.end.x - reach, box.end.y))
	else:
		out.append(box.end)
	if which & 8:
		out.append(Vector2(box.position.x + reach, box.end.y))
		out.append(Vector2(box.position.x, box.end.y - reach))
	else:
		out.append(Vector2(box.position.x, box.end.y))
	if which & 1:
		out.append(Vector2(box.position.x, box.position.y + reach))
	return out


## 한쪽이 뾰족한 판. 오른쪽 변이 창끝처럼 나간다.
static func fang(box: Rect2, tip: float) -> PackedVector2Array:
	return PackedVector2Array(
		[
			box.position,
			Vector2(box.end.x, box.position.y),
			Vector2(box.end.x + tip, box.get_center().y),
			Vector2(box.end.x, box.end.y),
			Vector2(box.position.x, box.end.y),
		]
	)


## 가장자리가 뜯긴 판. 변마다 톱니가 몇 개 난다.
##
## **난수를 씨앗으로 고정한다** — 프레임마다 다르게 뜯기면 그건 뜯긴 게 아니라 떠는 것이다.
static func torn(box: Rect2, bite: float, seed_value: int) -> PackedVector2Array:
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	var out := PackedVector2Array()
	var corners := [
		box.position,
		Vector2(box.end.x, box.position.y),
		box.end,
		Vector2(box.position.x, box.end.y),
	]
	for i in 4:
		var from: Vector2 = corners[i]
		var to: Vector2 = corners[(i + 1) % 4]
		var steps := 5
		for step in steps:
			var t := float(step) / float(steps)
			var along := from.lerp(to, t)
			var normal := (to - from).orthogonal().normalized()
			out.append(along + normal * dice.randf_range(-bite, bite))
	return out


## **위 판이 아래 판을 잘라 낸다.** 겹친 자리를 아래 판에서 지우고 `bleed` 만큼 더 지운다.
##
## 뒤판을 그리고 그 위에 앞판을 덮으면 **가려진 것**이지 잘린 것이 아니다.
## 겹치는 데가 없어야 뒤판이 초승달 모양의 **독립한 판**으로 보이고,
## 그래야 「그림자가 아니라 판 한 겹 더」가 형태로 증명된다 — 사이의 빈 줄이 그 증거다.
static func notched(
	under: PackedVector2Array, over: PackedVector2Array, bleed: float
) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if under.is_empty():
		return out
	if over.is_empty():
		out.append(under)
		return out
	for piece in Geometry2D.clip_polygons(under, _fattened(over, bleed)):
		out.append(piece)
	return out


## 판을 바깥으로 `bleed` 만큼 불린다.
##
## `Geometry2D.offset_polygon` 은 **감는 방향에 따라 부호가 뒤집힌다** — 시계 방향
## 다각형에 양수를 주면 오히려 줄어든다. 여기 판들은 `lean` · `clipped` · `fang` 이
## 제각각 만들어서 방향이 한결같지 않으므로, **넓어진 쪽을 골라** 쓴다.
static func _fattened(shape: PackedVector2Array, bleed: float) -> PackedVector2Array:
	if bleed <= 0.0:
		return shape
	var was := _bounds(shape).get_area()
	for delta: float in [bleed, -bleed]:
		var grown := Geometry2D.offset_polygon(shape, delta)
		if not grown.is_empty() and _bounds(grown[0]).get_area() > was:
			return grown[0]
	return shape


## 판을 그만큼 부풀린 외곽. 뒤판이 삐져나오게 할 때 쓴다.
##
## **뒤판은 「그림자」가 아니라 한 겹 더 있는 판이다.** 그래서 어긋나게 놓는다.
static func swelled(points: PackedVector2Array, by: float, at: Vector2) -> PackedVector2Array:
	var middle := Vector2.ZERO
	for point in points:
		middle += point
	middle /= maxf(float(points.size()), 1.0)
	var out := PackedVector2Array()
	for point in points:
		out.append(middle + (point - middle) * (1.0 + by) + at)
	return out


## 판 안을 채우는 **사선 줄무늬.** 판 밖으로 안 나가게 잘라 낸다.
##
## `phase` 를 흘리면 줄무늬가 판 위를 지나간다 — **재질이 아니라 그래픽이 움직이는 것**이다.
static func stripes(
	shape: PackedVector2Array, angle: float, gap: float, thick: float, phase: float
) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if shape.is_empty() or gap <= 0.0:
		return out
	var span := _bounds(shape)
	var reach := span.size.length() + gap * 2.0
	var middle := span.get_center()
	var dir := Vector2.from_angle(angle)
	var side := dir.orthogonal()
	var count := int(reach / gap) + 2
	for i in range(-count, count):
		var offset := float(i) * gap + fposmod(phase, gap)
		var seat := middle + side * offset
		var bar := PackedVector2Array(
			[
				seat - dir * reach,
				seat - dir * reach + side * thick,
				seat + dir * reach + side * thick,
				seat + dir * reach,
			]
		)
		for piece in Geometry2D.intersect_polygons(shape, bar):
			out.append(piece)
	return out


## 판 안을 채우는 **망점.** 점의 중심이 판 안에 있는 것만 남긴다.
##
## 잘라 내지 않고 중심으로 거르는 이유는 **점이 가장자리에서 반쯤 잘리면 그게 더 인쇄물답기**
## 때문이다 — 다만 완전히 밖에 있는 점은 지운다.
static func halftone(shape: PackedVector2Array, step: float, phase: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	if shape.is_empty() or step <= 0.0:
		return out
	var span := _bounds(shape).grow(step)
	var rows := int(span.size.y / step) + 2
	var cols := int(span.size.x / step) + 2
	for row in rows:
		for col in cols:
			var at := (
				span.position
				+ Vector2(float(col) * step, float(row) * step)
				+ Vector2(fposmod(phase.x, step), fposmod(phase.y, step))
			)
			if Geometry2D.is_point_in_polygon(at, shape):
				out.append(at)
	return out


## 판을 사선으로 **찢어 여는** 두 조각. `open` 0 이면 닫혀 있고 1 이면 다 열렸다.
##
## 열림이 「커지는 것」이 아니라 **갈라지는 것**이라 P5 문법에 맞는다.
static func torn_open(
	shape: PackedVector2Array, angle: float, open: float, apart: float
) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if shape.is_empty():
		return out
	if open >= 0.999:
		out.append(shape)
		return out
	var span := _bounds(shape)
	var middle := span.get_center()
	var dir := Vector2.from_angle(angle)
	var side := dir.orthogonal()
	var reach := span.size.length()
	# 갈라진 틈. 덜 열렸을수록 틈이 넓고 조각이 멀리 물러나 있다.
	var gap := (1.0 - open) * apart
	# `sign` 은 GDScript 내장 함수 이름이다 — 지역 변수로 쓰면 가려지고,
	# 이 저장소는 경고를 오류로 취급하므로 **컴파일이 통째로 죽는다.**
	var ways: Array[float] = [-1.0, 1.0]
	for way in ways:
		var edge := middle + side * gap * way
		var half := PackedVector2Array(
			[
				edge - dir * reach,
				edge + dir * reach,
				edge + dir * reach + side * reach * way,
				edge - dir * reach + side * reach * way,
			]
		)
		for piece in Geometry2D.intersect_polygons(shape, half):
			var moved := PackedVector2Array()
			for point in piece:
				moved.append(point + side * gap * way * 1.6)
			out.append(moved)
	return out


## **한 줄이 지나가며 판을 벤다.** 선 하나를 화면 좌표로 받아 그 선에 걸린 판을
## 두 조각으로 가르고, 조각을 서로 반대로 밀어낸다.
##
## `torn_open` 과 다른 점은 **선이 판의 것이 아니라는 것**이다. 찢어 여는 것은 판마다
## 자기 가운데를 열지만, 이것은 **화면을 가로지르는 한 줄**을 판 여럿에 똑같이 대고
## 지나간다 — 그래서 벤 자리가 판을 건너 **한 줄로 이어져 보인다.**
##
## 「참격」이 지금까지 **무늬**였다(사선 줄무늬 · 기울어진 판). 이것은 벤 자국을
## **구조**로 만든다 — 판의 형태가 그 한 줄의 결과가 된다.
static func severed(
	shape: PackedVector2Array, angle: float, through: Vector2, apart: float
) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if shape.is_empty():
		return out
	if apart <= 0.01:
		out.append(shape)
		return out
	var dir := Vector2.from_angle(angle)
	var side := dir.orthogonal()
	# 자르는 반평면은 **판까지 닿아야 한다.** 판 크기만으로 잡으면 선에서 먼 작은 판이
	# 반평면 밖에 놓여 두 조각 다 비고 — **판이 통째로 사라진다.** 실제로 그렇게 났다:
	# 체크 상자와 손잡이와 버튼 둘이 글자만 남고 면이 없어졌다.
	var span := _bounds(shape)
	var reach := span.size.length() + through.distance_to(span.get_center()) + 64.0
	var ways: Array[float] = [-1.0, 1.0]
	for way in ways:
		var half := PackedVector2Array(
			[
				through - dir * reach,
				through + dir * reach,
				through + dir * reach + side * reach * way,
				through - dir * reach + side * reach * way,
			]
		)
		for piece in Geometry2D.intersect_polygons(shape, half):
			var moved := PackedVector2Array()
			# 벌어지기만 하면 틈이고, **베인 쪽으로 같이 밀려야** 지나간 자국이 된다.
			for point in piece:
				moved.append(point + side * way * apart * 0.5 + dir * way * apart * 0.34)
			out.append(moved)
	return out


## 판을 **위에서부터 `upto` 픽셀만큼만** 드러낸다. 한 줄씩 그려지는 표시에 쓴다.
##
## 잘라 내는 것이라 **판의 형태가 그대로 유지된다** — 사각형으로 가리면
## 평행사변형의 기울어진 변이 사라져 다른 판처럼 보인다.
static func revealed(shape: PackedVector2Array, upto: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if shape.is_empty():
		return out
	var span := _bounds(shape)
	if upto >= span.size.y:
		out.append(shape)
		return out
	if upto <= 0.0:
		return out
	var lid := PackedVector2Array(
		[
			Vector2(span.position.x - 4.0, span.position.y - 4.0),
			Vector2(span.end.x + 4.0, span.position.y - 4.0),
			Vector2(span.end.x + 4.0, span.position.y + upto),
			Vector2(span.position.x - 4.0, span.position.y + upto),
		]
	)
	for piece in Geometry2D.intersect_polygons(shape, lid):
		out.append(piece)
	return out


## 판의 위끝과 아래끝. 드러나는 높이를 재는 쪽이 쓴다.
static func span_of(shape: PackedVector2Array) -> Rect2:
	return _bounds(shape)


static func _bounds(shape: PackedVector2Array) -> Rect2:
	var span := Rect2(shape[0], Vector2.ZERO)
	for point in shape:
		span = span.expand(point)
	return span
