class_name DungeonEdgeSelector
extends RefCounted
## 어떤 방 쌍을 실제로 이을지 고른다.
##
## 후보가 전부 들로네 간선이라 **무엇을 골라도 교차가 생기지 않는다.**
## 그래서 이 파일에는 "교차하면 버리고 다시" 같은 재시도가 한 줄도 없다
## (docs/design/17-dungeon-generation.md §17.3).
##
## 고르는 순서는 이렇다.
##
## | 단계 | 무엇을 | 왜 |
## | --- | --- | --- |
## | 뼈대 | RNG + MST | 연결성 보장. 유기적인 모양 (ProximityGraphs 참고) |
## | 곁가지 | 가브리엘 간선 일부 | 순환을 만들어 막다른 길만 남지 않게 |
## | 보정 | 입구 차수 · 막다른 방 비율 | 규칙을 검증이 아니라 수선으로 맞춘다 |
##
## 곁가지를 고르는 기준이 이 게임의 레벨 디자인이다 (§17.3 4단계).
## 고도차가 큰 통로는 드물게, 입구에서 먼 곳은 성기게 잇는다.
## 그러면 **귀중품이 놓일 깊은 곳에 우회로가 적어져** 값을 치러야 닿는 자리가 되고,
## 입구 근처는 촘촘해져 첫 턴에 고를 것이 생긴다.

## 막다른 방을 만들려고 간선을 끊어 보는 횟수. 무한 루프를 막는 상한이다.
const _CARVE_PASSES := 6

## 곁가지로 추가할 간선 수 (방 개수 대비).
##
## 이 값이 곧 난이도 손잡이다. 차수가 올라갈수록 인접 위험도 합이 뭉쳐
## 읽기 어려워진다 (§17.2).
var extra_ratio := 0.24

## 막다른 방(차수 1) 비율의 허용 범위.
##
## **막다른 방은 없애야 할 결함이 아니라 자원이다.** 차수 1 인 방에 들어가면
## 인접 합이 곧 그 한 방의 정확한 위험도라 앞방을 정찰할 수 있다.
## 대신 퇴로가 하나뿐이다. 위험 대 정보의 트레이드오프가 판의 모양에서
## 저절로 나오므로 생성기는 비율만 관리한다 (§17.2).
##
## 하한이 없으면 곁가지가 막다른 방부터 채워 하나도 남지 않는다 (실측 4%).
var dead_end_ratio_min := 0.14
var dead_end_ratio_max := 0.30

## 깊이가 점수를 얼마나 깎는지. 크면 입구 근처만 촘촘해진다.
var depth_penalty := 0.30

var _points: PackedVector2Array
var _delaunay: Array[Vector2i]
var _elevations: PackedInt32Array
var _entrance: int


func _init(
	points: PackedVector2Array,
	delaunay: Array[Vector2i],
	elevations: PackedInt32Array,
	entrance: int
) -> void:
	_points = points
	_delaunay = delaunay
	_elevations = elevations
	_entrance = entrance


## 최종 간선 목록.
func select(rng: RandomNumberGenerator) -> Array[Vector2i]:
	var chosen := _skeleton()
	var pool := _ranked_pool(chosen, rng)
	var used := _add_extras(chosen, pool, int(round(float(_points.size()) * extra_ratio)))
	chosen = _ensure_entrance_choice(chosen)
	chosen = _relieve_dead_ends(chosen, pool, used)
	chosen = _carve_dead_ends(chosen)
	return chosen


## 곁가지를 붙이되 **막다른 방을 다 없애지는 않는다.** 소비한 후보 개수를 돌려준다.
##
## 점수가 높은 간선은 입구 근처의 완만한 간선이고, 그런 곳에는 막다른 방이 많다.
## 그래서 아무 제한 없이 붙이면 막다른 방이 먼저 사라진다.
## 하한에 닿으면 **양쪽 끝이 이미 막다른 방이 아닌 간선만** 받는다 —
## 그런 간선은 순환만 만들고 정찰 지점을 건드리지 않는다.
func _add_extras(chosen: Array[Vector2i], pool: Array[Vector2i], wanted: int) -> int:
	var degrees := _degrees(chosen)
	var remaining := _dead_ends_in(degrees)
	var floor_count := int(ceil(float(_points.size()) * dead_end_ratio_min))
	var added := 0
	var index := 0
	while added < wanted and index < pool.size():
		var edge := pool[index]
		index += 1
		var cost := _dead_end_cost(degrees, edge)
		if cost > 0 and remaining - cost < floor_count:
			continue
		chosen.append(edge)
		degrees[edge.x] = int(degrees.get(edge.x, 0)) + 1
		degrees[edge.y] = int(degrees.get(edge.y, 0)) + 1
		remaining -= cost
		added += 1
	return index


## 그 간선을 놓으면 막다른 방이 몇 개 사라지는가.
func _dead_end_cost(degrees: Dictionary, edge: Vector2i) -> int:
	var cost := 0
	if int(degrees.get(edge.x, 0)) <= 1:
		cost += 1
	if int(degrees.get(edge.y, 0)) <= 1:
		cost += 1
	return cost


func _dead_ends_in(degrees: Dictionary) -> int:
	var count := 0
	for index in _points.size():
		if int(degrees.get(index, 0)) <= 1:
			count += 1
	return count


## 뼈대. RNG 에 MST 를 합쳐 연결성을 확정한다.
func _skeleton() -> Array[Vector2i]:
	var relative := ProximityGraphs.relative_neighborhood(_points, _delaunay)
	var spanning := ProximityGraphs.minimum_spanning_tree(_points, _delaunay)
	return ProximityGraphs.merge(relative, spanning)


## 막다른 방이 모자라면 몇 군데를 일부러 끊는다.
##
## 블루 노이즈 위의 RNG 는 놀라울 만큼 고르다. 차수 1 인 방이 저절로는
## 방 수의 10% 도 나오지 않는다(실측 5~10%). 고른 것은 좋지만 그만큼
## **정찰 지점이 사라진다** — 인접 합이 늘 두세 방의 뭉친 값이라
## 확신을 얻을 방법이 판에서 없어진다 (§17.2).
##
## 끊어도 되는 간선을 미리 고르지 않고 **끊어 본 뒤 판이 갈라지면 되돌린다.**
## 다리(bridge)를 따로 계산하는 것보다 짧고, 판이 수십 개 방이라 비용도 무시할 만하다.
##
## 깊은 쪽부터 끊는다. 깊은 막다른 방이 정찰 대 퇴로의 거래를 더 날카롭게 만든다.
func _carve_dead_ends(chosen: Array[Vector2i]) -> Array[Vector2i]:
	var result := chosen.duplicate()
	var target := int(ceil(float(_points.size()) * dead_end_ratio_min))
	if _dead_end_count(result) >= target:
		return result

	var depths := _depths(result)
	var entries: Array = []
	for edge in result:
		entries.append({"edge": edge, "key": float(_edge_depth(depths, edge))})
	var order := _by_key(entries)

	# 여러 번 훑는다. 차수 3 인 방은 한 번에 막다른 방이 되지 못하고,
	# 옆 간선이 먼저 끊겨 차수 2 가 된 뒤에야 후보가 되기 때문이다.
	for pass_index in _CARVE_PASSES:
		if not _carve_once(result, order, target):
			break
	return result


## 한 바퀴 돌며 끊는다. 하나라도 끊었으면 true.
func _carve_once(edges: Array[Vector2i], order: Array[Vector2i], target: int) -> bool:
	var cut := false
	for edge in order:
		if _dead_end_count(edges) >= target:
			return cut
		if not edges.has(edge) or edge.x == _entrance or edge.y == _entrance:
			continue
		if not _makes_one_dead_end(_degrees(edges), edge):
			continue
		edges.erase(edge)
		if _is_connected(edges):
			cut = true
		else:
			# 다리였다. 끊으면 판이 두 조각이 나므로 되돌린다 (V1).
			edges.append(edge)
	return cut


## 모든 방이 입구에서 이어져 있는가.
func _is_connected(edges: Array[Vector2i]) -> bool:
	return _depths(edges).size() == _points.size()


## 이 간선을 끊으면 한쪽만 막다른 방이 되는가.
##
## 양쪽이 다 줄면 통로가 통째로 잘려 나간 것처럼 보이고, 한쪽이 차수 1 이었으면
## 그 방이 판에서 떨어진다.
func _makes_one_dead_end(degrees: Dictionary, edge: Vector2i) -> bool:
	var low := mini(int(degrees.get(edge.x, 0)), int(degrees.get(edge.y, 0)))
	var high := maxi(int(degrees.get(edge.x, 0)), int(degrees.get(edge.y, 0)))
	return low == 2 and high >= 3


func _edge_depth(depths: Dictionary, edge: Vector2i) -> int:
	return mini(int(depths.get(edge.x, 0)), int(depths.get(edge.y, 0)))


## 곁가지 후보를 점수 순으로 세운다.
##
## 가브리엘 간선을 먼저 놓고 나머지 들로네 간선을 뒤에 붙인다.
## 가브리엘 간선은 두 방 사이에 낀 방이 없다는 뜻이라, 그 선을 그어도
## 엉뚱한 제3의 방을 스치지 않는다. 나머지는 정말 모자랄 때만 쓴다.
func _ranked_pool(chosen: Array[Vector2i], rng: RandomNumberGenerator) -> Array[Vector2i]:
	var taken := {}
	for edge in chosen:
		taken[edge] = true
	var depths := _depths(chosen)

	var near: Array[Vector2i] = []
	var far: Array[Vector2i] = []
	for edge in ProximityGraphs.gabriel(_points, _delaunay):
		if not taken.has(edge):
			near.append(edge)
			taken[edge] = true
	for edge in _delaunay:
		if not taken.has(edge):
			far.append(edge)

	return _by_score(near, depths, rng) + _by_score(far, depths, rng)


## 점수 내림차순. 점수를 미리 계산해 두는 이유는, 비교 함수 안에서 난수를 뽑으면
## 호출 순서에 따라 결과가 달라져 **같은 시드가 같은 판을 만들지 못하기 때문이다** (§17.7).
func _by_score(
	edges: Array[Vector2i], depths: Dictionary, rng: RandomNumberGenerator
) -> Array[Vector2i]:
	var scored: Array = []
	for edge in edges:
		scored.append({"edge": edge, "key": _score(edge, depths, rng)})
	return _by_key(scored)


## {"edge": Vector2i, "key": float} 목록을 key 내림차순으로 세워 간선만 뽑는다.
##
## **비교 함수 안에서는 값만 본다.** self 의 메서드나 멤버를 건드리는 비교 함수를
## sort_custom 에 넘겼더니 엔진이 간헐적으로 죽었다.
## 정렬 기준을 미리 계산해 두면 그 위험도 없고 재현성도 확실해진다.
static func _by_key(entries: Array) -> Array[Vector2i]:
	entries.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return float(a["key"]) > float(b["key"])
	)
	var result: Array[Vector2i] = []
	for entry in entries:
		result.append(entry["edge"])
	return result


## 간선 하나의 점수. 클수록 먼저 채택된다.
func _score(edge: Vector2i, depths: Dictionary, rng: RandomNumberGenerator) -> float:
	var climb := absi(_elevations[edge.x] - _elevations[edge.y])
	var depth: int = mini(int(depths.get(edge.x, 0)), int(depths.get(edge.y, 0)))
	# 가파른 통로가 흔해지면 필요 민첩이라는 등급 자체가 의미를 잃는다 (§17.4).
	var gentle := 1.0 / (1.0 + float(climb))
	# 깊은 곳은 성기게. 우회로가 적어야 고가치 방이 값을 치르고 닿는 곳이 된다 (V3).
	var shallow := 1.0 / (1.0 + depth_penalty * float(depth))
	# 흔들어 주지 않으면 같은 지형에서 늘 같은 곁가지가 나온다.
	return gentle * shallow * rng.randf_range(0.55, 1.45)


## 입구에서의 간선 수(hop) 거리.
func _depths(edges: Array[Vector2i]) -> Dictionary:
	var neighbors := _adjacency(edges)
	var depths := {_entrance: 0}
	var frontier: Array[int] = [_entrance]
	while not frontier.is_empty():
		var current: int = frontier.pop_front()
		for neighbor in neighbors.get(current, [] as Array[int]) as Array[int]:
			if depths.has(neighbor):
				continue
			depths[neighbor] = int(depths[current]) + 1
			frontier.append(neighbor)
	return depths


## V7 — 입구의 차수가 2 미만이면 가장 짧은 들로네 간선을 붙여 준다.
##
## 선택지가 하나뿐인 시작은 게임이 아니다. 규칙상으로는 멀쩡한 판이지만
## 플레이어에게는 "누를 수 있는 버튼이 하나뿐인 화면"이라 판단이 시작되지 않는다.
func _ensure_entrance_choice(chosen: Array[Vector2i]) -> Array[Vector2i]:
	var result := chosen.duplicate()
	var entries: Array = []
	for edge in _delaunay:
		if (edge.x == _entrance or edge.y == _entrance) and not result.has(edge):
			# 가까운 방부터 붙인다. 판 반대편까지 뻗는 긴 통로가 입구에 생기면
			# 첫 선택지가 판을 가로지르는 이상한 그림이 된다.
			entries.append(
				{"edge": edge, "key": -_points[edge.x].distance_squared_to(_points[edge.y])}
			)
	var candidates := _by_key(entries)
	var index := 0
	while _degree_of(result, _entrance) < 2 and index < candidates.size():
		result.append(candidates[index])
		index += 1
	return result


## V5 — 막다른 방이 너무 많으면 남은 후보로 몇 개를 이어 준다.
##
## 없애는 것이 아니라 비율만 맞춘다. 막다른 방은 앞방의 위험도를 정확히 알려 주는
## 정찰 지점이고, 그 대가로 퇴로가 하나뿐이라는 트레이드오프가 판의 모양에서
## 저절로 나오기 때문이다 (§17.2).
func _relieve_dead_ends(
	chosen: Array[Vector2i], pool: Array[Vector2i], start: int
) -> Array[Vector2i]:
	var result := chosen.duplicate()
	var total := _points.size()
	if total == 0:
		return result
	var index := start
	while float(_dead_end_count(result)) / float(total) > dead_end_ratio_max:
		if index >= pool.size():
			break
		var edge := pool[index]
		index += 1
		if _degree_of(result, edge.x) <= 1 or _degree_of(result, edge.y) <= 1:
			result.append(edge)
	return result


func _dead_end_count(edges: Array[Vector2i]) -> int:
	return _dead_ends_in(_degrees(edges))


func _degree_of(edges: Array[Vector2i], node: int) -> int:
	var count := 0
	for edge in edges:
		if edge.x == node or edge.y == node:
			count += 1
	return count


func _degrees(edges: Array[Vector2i]) -> Dictionary:
	var result := {}
	for edge in edges:
		result[edge.x] = int(result.get(edge.x, 0)) + 1
		result[edge.y] = int(result.get(edge.y, 0)) + 1
	return result


func _adjacency(edges: Array[Vector2i]) -> Dictionary:
	var result := {}
	for edge in edges:
		if not result.has(edge.x):
			result[edge.x] = [] as Array[int]
		if not result.has(edge.y):
			result[edge.y] = [] as Array[int]
		(result[edge.x] as Array[int]).append(edge.y)
		(result[edge.y] as Array[int]).append(edge.x)
	return result
