class_name DelaunayTriangulation
extends RefCounted
## Bowyer-Watson 들로네 삼각분할.
##
## **이 파일 하나가 "간선이 교차하지 않는다"를 구조적으로 보장한다.**
##
## 삼각분할은 정의상 평면 직선 그래프다. 두 간선은 공유하는 끝점 말고는 만나지 않는다.
## 따라서 여기서 나온 간선 목록의 **어떤 부분집합을 골라도 교차가 생기지 않는다.**
##
## 이것이 이전 방식과의 결정적 차이다. 예전에는 그래프를 먼저 만들고 나중에 펼쳤고,
## 그러면 평면에 그릴 수 없는 그래프가 나와 레이아웃이 아무리 애써도 교차가 풀리지 않았다.
## 지금은 교차를 **검사해서 걸러 내는 것이 아니라, 나올 수 없는 후보에서만 고른다.**
## 그래서 실패하는 재시도 루프가 통째로 없다
## (docs/design/17-dungeon-generation.md §17.3).
##
## Geometry2D.triangulate_delaunay() 를 쓰지 않은 이유는 두 가지다.
## 판의 평면성이 이 판정 하나에 걸려 있어 내부를 알고 있어야 하고,
## 축퇴(네 점이 한 원 위)를 어느 쪽으로 처리할지 우리가 정해야 한다.

## 외접원 판정의 허용 오차.
##
## 네 점이 한 원 위에 놓인 축퇴를 "바깥"으로 처리한다. 안쪽으로 처리하면
## 삼각형이 필요 이상으로 지워져 구멍의 경계가 별 모양이 아니게 될 수 있고,
## 그러면 재삼각분할이 겹치는 삼각형을 만든다.
const _EPSILON := 1e-9


## 점 인덱스 3개씩 이어 붙인 삼각형 목록.
##
## 점이 3개 미만이면 빈 배열이다. 부르는 쪽이 그 경우를 따로 처리해야 한다.
static func triangulate(points: PackedVector2Array) -> PackedInt32Array:
	var result := PackedInt32Array()
	var count := points.size()
	if count < 3:
		return result

	var work := _with_super_triangle(points)
	var triangles: Array[Vector3i] = [_oriented(work, count, count + 1, count + 2)]
	for index in count:
		triangles = _insert(work, triangles, index)

	for triangle in triangles:
		# 슈퍼 삼각형의 꼭짓점에 닿은 삼각형은 판 바깥의 허구다.
		if triangle.x < count and triangle.y < count and triangle.z < count:
			result.append(triangle.x)
			result.append(triangle.y)
			result.append(triangle.z)
	return result


## 중복 없는 간선 목록. **여기서 나온 간선끼리는 교차하지 않는다.**
static func edges(points: PackedVector2Array) -> Array[Vector2i]:
	var triangles := triangulate(points)
	var seen := {}
	var result: Array[Vector2i] = []
	var index := 0
	while index + 2 < triangles.size():
		var a := triangles[index]
		var b := triangles[index + 1]
		var c := triangles[index + 2]
		_collect(seen, result, a, b)
		_collect(seen, result, b, c)
		_collect(seen, result, c, a)
		index += 3
	return result


## 정규화한 간선. 방향이 없으므로 작은 인덱스를 앞에 둔다.
static func edge_key(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a, b), maxi(a, b))


static func _collect(seen: Dictionary, result: Array[Vector2i], a: int, b: int) -> void:
	var key := edge_key(a, b)
	if seen.has(key):
		return
	seen[key] = true
	result.append(key)


## 점 하나를 넣고 삼각형 목록을 다시 만든다.
##
## 그 점을 외접원 안에 품은 삼각형을 전부 지우면 별 모양 구멍이 남는다.
## 그 구멍의 **경계 간선**(지워진 삼각형 중 하나에만 속했던 간선)과 새 점을 이으면
## 다시 유효한 삼각분할이 된다. 이것이 Bowyer-Watson 의 전부다.
static func _insert(
	work: PackedVector2Array, triangles: Array[Vector3i], index: int
) -> Array[Vector3i]:
	var point := work[index]
	var kept: Array[Vector3i] = []
	var cavity: Array[Vector2i] = []
	for triangle in triangles:
		if _in_circumcircle(work[triangle.x], work[triangle.y], work[triangle.z], point):
			cavity.append(edge_key(triangle.x, triangle.y))
			cavity.append(edge_key(triangle.y, triangle.z))
			cavity.append(edge_key(triangle.z, triangle.x))
		else:
			kept.append(triangle)
	for edge in _unshared(cavity):
		kept.append(_oriented(work, edge.x, edge.y, index))
	return kept


## 딱 한 번만 나온 간선들. 두 번 나온 것은 지워진 삼각형 사이의 내부 간선이다.
static func _unshared(edges_in: Array[Vector2i]) -> Array[Vector2i]:
	var tally := {}
	for edge in edges_in:
		tally[edge] = int(tally.get(edge, 0)) + 1
	var result: Array[Vector2i] = []
	for edge in edges_in:
		if int(tally[edge]) == 1:
			result.append(edge)
	return result


## 모든 점을 품는 거대한 삼각형을 뒤에 붙인다. 시작 삼각형이 있어야 삽입이 성립한다.
static func _with_super_triangle(points: PackedVector2Array) -> PackedVector2Array:
	var lowest := points[0]
	var highest := points[0]
	for point in points:
		lowest = lowest.min(point)
		highest = highest.max(point)
	var center := (lowest + highest) * 0.5
	var span := maxf(maxf(highest.x - lowest.x, highest.y - lowest.y), 1.0) * 20.0

	var work := PackedVector2Array(points)
	work.append(center + Vector2(0.0, -span))
	work.append(center + Vector2(-span, span))
	work.append(center + Vector2(span, span))
	return work


## 항상 같은 회전 방향으로 꼭짓점을 정렬한다.
##
## 외접원 판정식이 방향을 전제하므로, 방향이 섞이면 판정이 반대로 뒤집힌다.
static func _oriented(work: PackedVector2Array, a: int, b: int, c: int) -> Vector3i:
	var ab := work[b] - work[a]
	var ac := work[c] - work[a]
	if ab.cross(ac) < 0.0:
		return Vector3i(a, c, b)
	return Vector3i(a, b, c)


## p 가 삼각형 abc 의 외접원 안에 있는가. abc 는 _oriented() 로 정렬되어 있어야 한다.
##
## 외접원의 중심과 반지름을 구하지 않는다. 세 점이 거의 일직선일 때 중심이 무한대로
## 날아가 정밀도가 무너지기 때문이다. 행렬식은 그런 경우에도 부호가 안정적이다.
static func _in_circumcircle(a: Vector2, b: Vector2, c: Vector2, p: Vector2) -> bool:
	var ax := a.x - p.x
	var ay := a.y - p.y
	var bx := b.x - p.x
	var by := b.y - p.y
	var cx := c.x - p.x
	var cy := c.y - p.y
	var determinant := (
		(ax * ax + ay * ay) * (bx * cy - by * cx)
		- (bx * bx + by * by) * (ax * cy - ay * cx)
		+ (cx * cx + cy * cy) * (ax * by - ay * bx)
	)
	return determinant > _EPSILON
