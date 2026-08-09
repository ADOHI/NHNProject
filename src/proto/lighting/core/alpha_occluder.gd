class_name ProtoAlphaOccluder
extends RefCounted
## **소품 컷아웃의 알파에서 그림자용 외곽선을 뽑는다.** 노드에 의존하지 않는 순수 변환이다.
##
## 방 하나에 소품이 일곱~아홉 장이고 던전이 여러 방이므로 **손으로 그리는 것은 성립하지
## 않는다.** 그렇다고 알파를 그대로 따면 못 쓴다 — 700×900 짜리 컷아웃 하나의 외곽선이
## 수천 점이고, `26-2d-lighting.md` §26.3.2 의 실측에서 **가림 물건이 라이팅에서 제일
## 비싸고 그 비용이 CPU 였다** (64 개에서 렌더 CPU 가 2.8 배). 단일 스레드 웹에서 그건
## 통째로 우리 프레임이다. **그러므로 이 파일의 목적은 「뽑는 것」이 아니라 「줄이는 것」이다.**
##
## # 두 단계
##
## 1. **마칭 스퀘어**로 알파의 경계를 딴다. 화소 격자의 모서리를 따라가므로 계단 모양이
##    나오고, 점 수는 둘레에 비례한다
## 2. **더글러스-포이커**로 줄인다. `epsilon` 이 곧 **버리는 최대 오차(픽셀)** 이고,
##    이 값이 점 수와 정확도를 잇는 유일한 손잡이다
##
## # 왜 작업 해상도를 따로 두는가
##
## 원본 그대로 따면 점이 둘레만큼 나오고 (700×900 이면 수천), `Image.get_pixel` 을
## 63 만 번 부른다. **먼저 줄여서 딴다.** 줄이면 알파가 섞이면서 톱니가 미리 눕는
## 덤도 있다. 되돌릴 때는 원본 화소 좌표로 곱해 돌려주므로 **바깥에서 보는 좌표계는
## 언제나 원본 컷아웃의 화소**다.
##
## # 이 값을 어디에 쓰나
##
## `OccluderPolygon2D.polygon` 이다. 스프라이트가 `centered = true` 면
## `centered()` 로 옮겨서 넣는다 — 이 클래스가 돌려주는 좌표는 **좌상단이 원점**이다.

## 폴리곤이 되려면 최소 세 점이다.
const MIN_POINTS := 3

## 마칭 스퀘어의 진행 방향. 화면 좌표계(y 가 아래)다.
const _UP := Vector2i(0, -1)
const _DOWN := Vector2i(0, 1)
const _LEFT := Vector2i(-1, 0)
const _RIGHT := Vector2i(1, 0)


## **한 번에 다 한다.** 가장 큰 덩어리의 외곽선을 원본 화소 좌표로 돌려준다.
##
## `alpha_threshold` 이 값보다 알파가 크면 「막는다」로 본다.
## `work_size`       긴 변을 이 크기로 줄여서 딴다. 크면 정확하고 느리다.
## `epsilon_px`      **원본 화소 기준**으로 이만큼까지는 버린다. 점 수를 정하는 값이다.
static func build(
	image: Image, alpha_threshold := 0.5, work_size := 256, epsilon_px := 3.0
) -> PackedVector2Array:
	var loops := trace_all(image, alpha_threshold, work_size)
	if loops.is_empty():
		return PackedVector2Array()
	var best: PackedVector2Array = loops[0]
	var best_area := polygon_area(best)
	for i in range(1, loops.size()):
		var a := polygon_area(loops[i])
		if a > best_area:
			best_area = a
			best = loops[i]
	return simplify(best, epsilon_px)


## 알파 경계의 **모든** 닫힌 고리. 큰 것부터가 아니라 찾은 순서다.
##
## 소품이 한 덩어리가 아닐 수 있다 — `p_shards` 는 이름 그대로 흩어진 조각이다.
## `build()` 은 그중 제일 큰 것만 쓰지만, **몇 덩어리인지가 그 소품을 가림물체로
## 쓸지 말지를 정하는 값**이라 세는 길을 따로 열어 둔다.
static func trace_all(
	image: Image, alpha_threshold := 0.5, work_size := 256
) -> Array[PackedVector2Array]:
	var empty: Array[PackedVector2Array] = []
	var dim := work_dimensions(image, work_size)
	if dim.x < 2 or dim.y < 2:
		return empty
	var mask := _mask_of(image, alpha_threshold, dim)
	var grid_w := dim.x + 1
	var grid_h := dim.y + 1
	var seen := PackedByteArray()
	seen.resize(grid_w * grid_h)
	seen.fill(0)
	# 되돌리는 배율. 딴 좌표는 줄인 격자의 것이고 바깥은 원본 화소를 기대한다.
	var back := Vector2(
		float(image.get_width()) / float(dim.x), float(image.get_height()) / float(dim.y)
	)
	var out: Array[PackedVector2Array] = []
	for y in grid_h:
		for x in grid_w:
			if seen[y * grid_w + x] == 1:
				continue
			var state := _state(mask, dim, x, y)
			# 0 은 전부 비었고 15 는 전부 찼다. 경계가 아니다.
			if state == 0 or state == 15:
				continue
			var loop := _walk(mask, dim, seen, x, y)
			if loop.size() < MIN_POINTS:
				continue
			var scaled := PackedVector2Array()
			for p in loop:
				scaled.append(Vector2(p.x * back.x, p.y * back.y))
			out.append(scaled)
	return out


## **더글러스-포이커.** `epsilon` 은 버려도 되는 최대 벗어남(픽셀)이다.
##
## 닫힌 고리에는 「양 끝」이 없으므로 그냥 0 번을 끝으로 잡으면 그 근처가 뭉개진다.
## **0 번에서 가장 먼 점을 찾아 두 사슬로 가른 뒤** 각각 줄인다.
static func simplify(points: PackedVector2Array, epsilon: float) -> PackedVector2Array:
	if points.size() <= MIN_POINTS or epsilon <= 0.0:
		return points
	var far := 0
	var best := -1.0
	for i in points.size():
		var d := points[0].distance_squared_to(points[i])
		if d > best:
			best = d
			far = i
	if far < 2 or far > points.size() - 2:
		return _reduce(points, epsilon)
	var head := _reduce(points.slice(0, far + 1), epsilon)
	var tail := _reduce(points.slice(far), epsilon)
	var out := PackedVector2Array(head)
	# `tail` 의 첫 점은 `head` 의 마지막 점(= far)과 같다. 한 번만 남긴다.
	for i in range(1, tail.size()):
		out.append(tail[i])
	return out


## 신발끈 공식. 부호를 버리므로 감김 방향과 무관하다.
static func polygon_area(points: PackedVector2Array) -> float:
	var n := points.size()
	if n < MIN_POINTS:
		return 0.0
	var total := 0.0
	for i in n:
		var a := points[i]
		var b := points[(i + 1) % n]
		total += a.x * b.y - b.x * a.y
	return absf(total) * 0.5


## **줄인 폴리곤이 원본에서 얼마나 벗어났나.** 원본의 각 점에서 줄인 고리까지의
## 최단 거리 중 최대값이다.
##
## 점 수만 적고 이 값을 안 적으면 「점을 줄였다」가 「모양을 버렸다」와 구분되지 않는다.
static func max_deviation(dense: PackedVector2Array, simple: PackedVector2Array) -> float:
	if dense.is_empty() or simple.size() < 2:
		return 0.0
	var worst := 0.0
	for p in dense:
		var nearest := INF
		for i in simple.size():
			var d := _segment_distance(p, simple[i], simple[(i + 1) % simple.size()])
			if d < nearest:
				nearest = d
		if nearest > worst:
			worst = nearest
	return worst


## 좌상단 원점을 **스프라이트 중심 원점**으로 옮긴다.
## `Sprite2D.centered` 가 기본값 `true` 라서 이걸 안 하면 그림자가 통째로 어긋난다.
static func centered(points: PackedVector2Array, texture_size: Vector2) -> PackedVector2Array:
	var half := texture_size * 0.5
	var out := PackedVector2Array()
	for p in points:
		out.append(p - half)
	return out


## 원본을 줄였을 때의 작업 격자 크기. 원본이 이미 작으면 그대로 쓴다.
static func work_dimensions(image: Image, work_size: int) -> Vector2i:
	var w := image.get_width()
	var h := image.get_height()
	var longest := maxi(w, h)
	if work_size <= 0 or longest <= work_size:
		return Vector2i(w, h)
	var k := float(work_size) / float(longest)
	return Vector2i(maxi(2, int(round(w * k))), maxi(2, int(round(h * k))))


static func _mask_of(image: Image, alpha_threshold: float, dim: Vector2i) -> PackedByteArray:
	var small := image.duplicate() as Image
	if small.get_format() != Image.FORMAT_RGBA8:
		small.convert(Image.FORMAT_RGBA8)
	if small.get_width() != dim.x or small.get_height() != dim.y:
		small.resize(dim.x, dim.y, Image.INTERPOLATE_BILINEAR)
	var mask := PackedByteArray()
	mask.resize(dim.x * dim.y)
	for y in dim.y:
		for x in dim.x:
			mask[y * dim.x + x] = 1 if small.get_pixel(x, y).a > alpha_threshold else 0
	return mask


## 격자 모서리 `(x, y)` 를 둘러싼 네 화소의 채움 상태.
## 비트: 1 = 좌상, 2 = 우상, 4 = 좌하, 8 = 우하.
static func _state(mask: PackedByteArray, dim: Vector2i, x: int, y: int) -> int:
	var s := 0
	if _solid(mask, dim, x - 1, y - 1):
		s |= 1
	if _solid(mask, dim, x, y - 1):
		s |= 2
	if _solid(mask, dim, x - 1, y):
		s |= 4
	if _solid(mask, dim, x, y):
		s |= 8
	return s


static func _solid(mask: PackedByteArray, dim: Vector2i, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= dim.x or y >= dim.y:
		return false
	return mask[y * dim.x + x] == 1


## 상태에서 다음 걸음. **안장(6 · 9)은 어디서 왔는지로 가른다** — 그러지 않으면
## 두 덩어리가 모서리 하나로 닿은 자리에서 고리가 엉킨다.
static func _step(state: int, previous: Vector2i) -> Vector2i:
	match state:
		1, 5, 13:
			return _UP
		2, 3, 7:
			return _RIGHT
		4, 12, 14:
			return _LEFT
		8, 10, 11:
			return _DOWN
		6:
			return _LEFT if previous == _UP else _RIGHT
		9:
			return _UP if previous == _RIGHT else _DOWN
	return Vector2i.ZERO


static func _walk(
	mask: PackedByteArray, dim: Vector2i, seen: PackedByteArray, start_x: int, start_y: int
) -> PackedVector2Array:
	var grid_w := dim.x + 1
	var grid_h := dim.y + 1
	var points := PackedVector2Array()
	var x := start_x
	var y := start_y
	var previous := Vector2i.ZERO
	# **상한을 둔다.** 안장이나 반올림으로 고리가 안 닫히면 여기서 멈춰야 한다.
	# 무한 반복은 헤드리스에서 「멈춘 것처럼」 보이고 원인을 찾는 데 한나절이 든다.
	var limit := (dim.x + dim.y) * 8 + 32
	for _i in limit:
		seen[y * grid_w + x] = 1
		points.append(Vector2(x, y))
		var step := _step(_state(mask, dim, x, y), previous)
		if step == Vector2i.ZERO:
			break
		x += step.x
		y += step.y
		previous = step
		if x < 0 or y < 0 or x >= grid_w or y >= grid_h:
			break
		if x == start_x and y == start_y:
			break
	return points


## 열린 사슬 하나를 줄인다. **재귀가 아니라 스택**이다 — 사슬이 수천 점이면
## 재귀 깊이가 그만큼 들어갈 수 있다.
static func _reduce(chain: PackedVector2Array, epsilon: float) -> PackedVector2Array:
	var n := chain.size()
	if n <= 2:
		return chain
	var keep := PackedByteArray()
	keep.resize(n)
	keep.fill(0)
	keep[0] = 1
	keep[n - 1] = 1
	var stack: Array[Vector2i] = [Vector2i(0, n - 1)]
	while not stack.is_empty():
		var seg: Vector2i = stack.pop_back()
		if seg.y <= seg.x + 1:
			continue
		var worst := -1.0
		var at := -1
		for k in range(seg.x + 1, seg.y):
			var d := _segment_distance(chain[k], chain[seg.x], chain[seg.y])
			if d > worst:
				worst = d
				at = k
		if worst > epsilon and at > 0:
			keep[at] = 1
			stack.push_back(Vector2i(seg.x, at))
			stack.push_back(Vector2i(at, seg.y))
	var out := PackedVector2Array()
	for k in n:
		if keep[k] == 1:
			out.append(chain[k])
	return out


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq <= 0.000001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)
