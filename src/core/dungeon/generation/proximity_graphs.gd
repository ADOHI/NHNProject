class_name ProximityGraphs
extends RefCounted
## 들로네 간선에서 부분그래프를 골라낸다.
##
## 여기서 나오는 모든 그래프는 **들로네의 부분집합**이라 평면성이 그대로 유지된다.
## 즉 무엇을 고르든 간선은 교차하지 않는다
## (docs/design/17-dungeon-generation.md §17.3).
##
##     MST  ⊆  RNG(상대이웃)  ⊆  가브리엘  ⊆  들로네
##
## ## 왜 MST + 무작위 복원이 아닌가
##
## MST 는 나무라 순환이 없다. 순환이 없으면 판의 절반이 막다른 길이 되고
## 되돌아 나오는 길 말고는 선택지가 없어 추리판이 아니라 미로가 된다.
## 거기에 들로네 간선을 무작위로 되살리면 **모양이 지형과 무관해진다** —
## 어떤 곳은 삼각형이 빽빽하고 어떤 곳은 한 줄만 남는다.
##
## RNG 는 "두 방 사이에 낀 방이 없을 때만 잇는다"는 기하 조건이다.
## 조건이 자리에서 나오므로 결과가 자리와 어긋날 수 없고,
## EMST 를 포함하므로 **연결성이 공짜로 따라온다.**
## 사람이 손으로 그린 길처럼 보이는 것은 이 조건의 부수 효과다.
##
## 가브리엘은 RNG 보다 한 단계 촘촘하다. 곁가지 후보로 쓰기 좋은데,
## 가브리엘 간선은 **두 방을 지름으로 하는 원 안에 다른 방이 없다**는 뜻이라
## 그 선을 그어도 엉뚱한 제3의 방을 스치고 지나가지 않는다.

## 기하 판정의 허용 오차. 경계에 딱 걸친 점 때문에 간선이 사라지지 않게 한다.
const _EPSILON := 1e-9


## 가브리엘 그래프 — ab 를 지름으로 하는 원 안에 다른 방이 없을 때만 잇는다.
static func gabriel(points: PackedVector2Array, candidates: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for edge in candidates:
		var center := (points[edge.x] + points[edge.y]) * 0.5
		var radius_squared := center.distance_squared_to(points[edge.x])
		if not _has_point_inside(points, edge, center, radius_squared):
			result.append(edge)
	return result


## 상대이웃 그래프 — a 에서도 b 에서도 ab 보다 가까운 제3의 방이 없을 때만 잇는다.
##
## 두 방 사이에 다른 방이 "끼어 있으면" 직접 잇지 않는다는 뜻이다.
## 판을 보면 통로가 이웃한 방들을 건너뛰지 않고 차례로 이어진다.
static func relative_neighborhood(
	points: PackedVector2Array, candidates: Array[Vector2i]
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for edge in candidates:
		if not _has_point_between(points, edge):
			result.append(edge)
	return result


## 최소 신장 트리 (Kruskal). **연결성의 최후 보루다.**
##
## RNG 가 이론상 MST 를 포함하므로 보통은 아무것도 더하지 않는다.
## 부동소수 오차로 RNG 간선 하나가 떨어져 나가는 경우에만 다리를 놓는다.
## 그 한 번을 위해 검증-재시도 루프를 두는 것보다 이쪽이 싸고 확실하다.
static func minimum_spanning_tree(
	points: PackedVector2Array, candidates: Array[Vector2i]
) -> Array[Vector2i]:
	# 정렬 기준을 미리 계산해 둔다. 비교 함수 안에서 바깥 값을 들여다보지 않는 편이
	# 안전하고, 같은 입력이면 언제나 같은 순서가 나온다 (§17.7).
	var entries: Array = []
	for edge in candidates:
		entries.append({"edge": edge, "key": points[edge.x].distance_squared_to(points[edge.y])})
	entries.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return float(a["key"]) < float(b["key"])
	)
	var ordered: Array[Vector2i] = []
	for entry in entries:
		ordered.append(entry["edge"])

	var parent: Array[int] = []
	for index in points.size():
		parent.append(index)

	var result: Array[Vector2i] = []
	for edge in ordered:
		if _union(parent, edge.x, edge.y):
			result.append(edge)
	return result


## 두 간선 목록을 중복 없이 합친다.
static func merge(first: Array[Vector2i], second: Array[Vector2i]) -> Array[Vector2i]:
	var seen := {}
	var result: Array[Vector2i] = []
	for edge in first + second:
		var key := DelaunayTriangulation.edge_key(edge.x, edge.y)
		if seen.has(key):
			continue
		seen[key] = true
		result.append(key)
	return result


static func _has_point_inside(
	points: PackedVector2Array, edge: Vector2i, center: Vector2, radius_squared: float
) -> bool:
	for index in points.size():
		if index == edge.x or index == edge.y:
			continue
		if center.distance_squared_to(points[index]) < radius_squared - _EPSILON:
			return true
	return false


static func _has_point_between(points: PackedVector2Array, edge: Vector2i) -> bool:
	var span := points[edge.x].distance_to(points[edge.y])
	for index in points.size():
		if index == edge.x or index == edge.y:
			continue
		var farther := maxf(
			points[edge.x].distance_to(points[index]), points[edge.y].distance_to(points[index])
		)
		if farther < span - _EPSILON:
			return true
	return false


static func _find(parent: Array[int], node: int) -> int:
	var root := node
	while parent[root] != root:
		root = parent[root]
	# 경로 압축. 방 개수가 수십이라 없어도 되지만 한 줄이라 넣어 둔다.
	var walk := node
	while parent[walk] != root:
		var next := parent[walk]
		parent[walk] = root
		walk = next
	return root


## 두 집합을 합쳤으면 true. 이미 같은 집합이면 그 간선은 순환을 만든다.
static func _union(parent: Array[int], a: int, b: int) -> bool:
	var root_a := _find(parent, a)
	var root_b := _find(parent, b)
	if root_a == root_b:
		return false
	parent[root_b] = root_a
	return true
