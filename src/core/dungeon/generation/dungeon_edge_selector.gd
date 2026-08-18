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
## | 뼈대 | **구역 안** RNG + MST | 연결성 보장. 유기적인 모양 (ProximityGraphs 참고) |
## | 관문 | 구역 **사이** 가장 짧은 간선 하나씩 | 거시 구조를 성기게 (DungeonZones 참고) |
## | 곁가지 | 허브에 닿는 가브리엘 간선 | 순환을 만들되 차수를 몰아 갈림길을 만든다 |
## | 보정 | 입구 차수 · 막다른 방 비율 | 규칙을 검증이 아니라 수선으로 맞춘다 |
##
## ## 축척을 둘로 나눈다 (§17.12.4-A)
##
## 예전에는 판 전체에 하나의 규칙을 걸었다. 그 결과가 **균질한 그물망**이다 —
## 순환 계수가 방 개수의 0.47 배인데 지름은 8.9 밖에 안 되고, 어느 방에 서도
## 서너 갈래고 어느 갈래로 가도 비슷한 곳이 나왔다 (§17.11.7).
##
## 지금은 구역 **안**은 촘촘하게, 구역 **사이**는 관문 하나씩만 잇는다.
## 성김과 촘촘함이 다른 축척에 있으므로 **갈림길을 유지하면서 거시 구조를 성기게** 만든다.
##
## **앞 레인의 판단은 그대로 쓴다** — 구역 안에서는 여전히 RNG∪MST 에 가브리엘 곁가지다
## (§17.3.4). 바뀐 것은 그 규칙을 판 전체가 아니라 구역마다 거는 것과, 구역 사이를
## 관문으로만 잇는 것뿐이다.
##
## ## 깊이 페널티를 뺐다
##
## 예전 점수에는 「얕음」 항이 있어 입구에서 먼 곳을 성기게 이었다. 의도는 좋았지만
## 실측에서 **얕은 쪽 평균 차수 3.4 대 깊은 쪽 2.05** 가 되어 **깊은 절반이 사실상 나무**가
## 됐고, 하필 그 깊은 곳에 보상이 놓였다. 귀중 방의 31% 만 대안 경로가 있었던 직접 원인이다
## (§17.11.7-2). 깊이를 성기게 만드는 일은 이제 **구역과 관문**이 대신한다.

## 막다른 방을 만들려고 간선을 끊어 보는 횟수. 무한 루프를 막는 상한이다.
const _CARVE_PASSES := 6

## 구역마다 간선을 몰아 줄 방의 수. **갈림길의 밀도를 정하는 손잡이다.**
##
## 하나만 두면 구역 안이 그 방을 지나는 별 모양이 되어 차수 3 이상이 45% 까지 떨어졌다.
## 둘이면 갈림길이 두 군데 생긴다 (프로토타입 실측, §17.14.3).
const _HUBS_PER_ZONE := 2

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

var _points: PackedVector2Array
var _delaunay: Array[Vector2i]
var _elevations: PackedInt32Array
var _entrance: int
var _zones: PackedInt32Array
var _zone_links: Array[Vector2i]
var _boundaries: Dictionary


func _init(
	points: PackedVector2Array,
	delaunay: Array[Vector2i],
	elevations: PackedInt32Array,
	entrance: int,
	zones: PackedInt32Array,
	zone_links: Array[Vector2i]
) -> void:
	_points = points
	_delaunay = delaunay
	_elevations = elevations
	_entrance = entrance
	_zones = zones
	_zone_links = zone_links
	# 그릴 수 있는 경계만. 생성기가 고리를 만들 때 쓴 것과 같은 집합이어야 한다.
	_boundaries = DungeonZones.readable_boundaries(points, delaunay, zones)


## V5 하한을 **다시** 맞춘다. 보상 노출과 경로 시공이 끝난 뒤 부르는 것이다.
##
## 막다른 방 비율은 `select()` 안에서 맞추는데, 그 뒤에 오는 단계들(보상 방을 사방으로
## 뚫기, 두 경로 시공)이 간선을 더하면서 **정찰 지점을 먹는다.** 실측에서 비율이 4.8% 까지
## 떨어져 하한을 깼다.
##
## **그래서 막다른 방 관리가 위상의 마지막 단계여야 한다.** 다만 방금 시공한 두 경로를
## 끊어 버리면 안 되므로 `protected` 로 받는다.
func enforce_dead_end_floor(
	edges: Array[Vector2i], protected_edges: Array[Vector2i]
) -> Array[Vector2i]:
	var guarded := {}
	for edge in protected_edges:
		guarded[DelaunayTriangulation.edge_key(edge.x, edge.y)] = true
	return _carve_dead_ends(edges, guarded)


## 최종 간선 목록.
func select(rng: RandomNumberGenerator) -> Array[Vector2i]:
	var chosen := _skeleton()
	var pool := _ranked_pool(chosen, rng)
	var used := _add_extras(chosen, pool, int(round(float(_points.size()) * extra_ratio)))
	chosen = _ensure_entrance_choice(chosen)
	chosen = _relieve_dead_ends(chosen, pool, used)
	chosen = _carve_dead_ends(chosen, {})
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
	# **갈림길을 가장 싸게 얻는 간선부터 받는다.**
	#
	# 곁가지 하나는 언제나 순환을 하나 만든다. 그런데 **갈림길은 하나 만들 수도 둘 만들 수도
	# 있다** — 양쪽 끝이 다 차수 2 면 둘 다 차수 3 이 되어 갈림길이 둘 늘고, 한쪽이 이미
	# 갈림길이면 하나만 는다.
	#
	# 실측에서 순환 17.5 (목표 12~15 초과) 인데 갈림길은 57.6% (목표 55~60) 였다.
	# 같은 갈림길을 **더 적은 순환으로** 얻을 수 있다는 뜻이고, 그 방법이 이 두 겹이다.
	var added := 0
	var index := 0
	for pass_index in 2:
		index = 0
		while added < wanted and index < pool.size():
			var edge := pool[index]
			index += 1
			if chosen.has(edge):
				continue
			# 첫 겹은 양쪽 다 차수 2 이하인 것만 받는다. 둘째 겹은 남은 것을 받는다.
			var both_plain := int(degrees.get(edge.x, 0)) <= 2 and int(degrees.get(edge.y, 0)) <= 2
			if pass_index == 0 and not both_plain:
				continue
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


## 뼈대. **구역 안**은 RNG, 구역 **사이**는 관문 하나씩. 연결은 `_repair` 가 마감한다.
##
## RNG 판정은 구역 안 간선만 후보로 받지만 **판의 모든 방을 상대로** 검사한다.
## 구역 안 방들만 보면 다른 구역의 방을 건너뛰는 통로가 생겨 선이 엉뚱한 방을 관통한다.
##
## **MST 를 여기서 뺐다.** 예전에는 판 전체 들로네를 후보로 MST 를 돌렸으므로 짧은 간선만
## 골랐다. 후보를 구역 안으로 줄이면 사정이 달라진다 — 구역이 기하적으로 두 조각이면
## Kruskal 이 그 둘을 잇는 **긴** 간선을 받아들이고, 그 선이 제3의 방을 스친다.
## 실측에서 통로가 방 17 px 앞까지 다가왔다(기준 84 px).
## 연결성은 `_repair` 가 **가브리엘 간선 중 가장 짧은 것**으로 마감하므로 더 안전하다.
func _skeleton() -> Array[Vector2i]:
	var inside := _inside_edges()
	var relative := ProximityGraphs.relative_neighborhood(_points, inside)
	return _repair(_add_gates(relative))


## 같은 구역에 양쪽 끝이 있는 들로네 간선들.
func _inside_edges() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for edge in _delaunay:
		if _zones[edge.x] == _zones[edge.y]:
			result.append(edge)
	return result


## 구역 연결마다 관문 간선 하나를 놓는다.
func _add_gates(chosen: Array[Vector2i]) -> Array[Vector2i]:
	var result := chosen.duplicate()
	var taken := {}
	for edge in result:
		taken[DelaunayTriangulation.edge_key(edge.x, edge.y)] = true
	for link in _zone_links:
		var gate := DungeonZones.gate(_points, _boundaries, link)
		if gate == Vector2i(-1, -1):
			continue
		var key := DelaunayTriangulation.edge_key(gate.x, gate.y)
		if taken.has(key):
			continue
		taken[key] = true
		result.append(key)
	return result


## V1 — 떨어져 나온 방이 있으면 **가장 짧은** 들로네 간선으로 도로 붙인다.
##
## 구역 안 RNG 가 구역을 하나로 잇지 못하는 경우가 있다. 구역 안 후보 간선 집합이
## 그 구역 안에서 이어져 있다는 보장이 없기 때문이다(들로네가 구역 경계를 가로지르며
## 구역을 두 조각으로 나눌 수 있다). MST 도 후보 안에서만 도니 같은 한계를 갖는다.
##
## **여유(DungeonZones.CLEARANCE_MIN)를 지키는 것 중 가장 짧은 것을 고른다.**
## 아무 것이나 잇으면 판을 가로지르는 통로가 생기고, 짧기만 한 간선은 제3의 방을 스친다 (§17.6).
func _repair(chosen: Array[Vector2i]) -> Array[Vector2i]:
	var result := chosen.duplicate()
	for attempt in _points.size():
		var reached := _depths(result)
		if reached.size() == _points.size():
			return result
		var best := Vector2i(-1, -1)
		var best_length := INF
		var clean := Vector2i(-1, -1)
		var clean_length := INF
		for edge in _delaunay:
			if reached.has(edge.x) == reached.has(edge.y):
				continue
			var length := _points[edge.x].distance_squared_to(_points[edge.y])
			if length < best_length:
				best_length = length
				best = edge
			if DungeonZones.clearance(_points, edge) >= DungeonZones.CLEARANCE_MIN:
				if length < clean_length:
					clean_length = length
					clean = edge
		if clean != Vector2i(-1, -1):
			best = clean
		if best == Vector2i(-1, -1):
			push_error("떨어져 나온 방을 붙일 간선이 없습니다")
			return result
		result.append(DelaunayTriangulation.edge_key(best.x, best.y))
	return result


## 구역마다 들로네 이웃이 가장 많은 방 몇 개. 여기에 곁가지를 몰아 준다.
##
## 고르게 뿌리면 전부 차수 2~3 이 되어 어느 방이나 똑같아 보인다. 몰아 주면 같은 간선
## 수로도 **차수 4 짜리 갈림길과 차수 1 짜리 막다른 방이 함께** 생긴다.
func _hubs(inside: Array[Vector2i]) -> Dictionary:
	var degrees := {}
	for edge in inside:
		degrees[edge.x] = int(degrees.get(edge.x, 0)) + 1
		degrees[edge.y] = int(degrees.get(edge.y, 0)) + 1

	var members := {}
	for index in _points.size():
		var zone := _zones[index]
		if not members.has(zone):
			members[zone] = [] as Array[int]
		(members[zone] as Array[int]).append(index)

	var result := {}
	for zone in members:
		var entries: Array = []
		for index in members[zone] as Array[int]:
			# 같은 이웃 수일 때 순서가 흔들리지 않도록 인덱스를 아래 자리에 넣는다 (§17.7).
			entries.append(
				{
					"edge": Vector2i(index, index),
					"key": float(int(degrees.get(index, 0))) - 0.000001 * float(index)
				}
			)
		var ranked := _by_key(entries)
		for slot in mini(_HUBS_PER_ZONE, ranked.size()):
			result[ranked[slot].x] = true
	return result


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
func _carve_dead_ends(chosen: Array[Vector2i], guarded: Dictionary) -> Array[Vector2i]:
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
		if not _carve_once(result, order, target, guarded):
			break
	return result


## 한 바퀴 돌며 끊는다. 하나라도 끊었으면 true.
func _carve_once(
	edges: Array[Vector2i], order: Array[Vector2i], target: int, guarded: Dictionary
) -> bool:
	var cut := false
	for edge in order:
		if _dead_end_count(edges) >= target:
			return cut
		if not edges.has(edge) or edge.x == _entrance or edge.y == _entrance:
			continue
		# 방금 시공한 두 경로는 끊지 않는다. 끊으면 「빨리 가는 길」이 사라진다.
		if guarded.has(DelaunayTriangulation.edge_key(edge.x, edge.y)):
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


## 곁가지 후보를 점수 순으로 세운다. **세 겹이다.**
##
## | 겹 | 무엇 | 왜 |
## | --- | --- | --- |
## | 1 | 구역 안 가브리엘 간선 중 **허브에 닿는 것** | 차수를 몰아 갈림길을 만든다 |
## | 2 | 구역 안 나머지 가브리엘 간선 | 막다른 방 비율을 맞출 때 쓴다 (V5) |
## | 3 | 구역을 넘는 가브리엘 간선 | 관문이 늘어 거시 구조가 흐려지므로 뒤에 둔다 |
## | 4 | 나머지 들로네 간선 중 **읽히는 것** | 정말 모자랄 때만 |
##
## **3·4 겹은 여유(`_readable`)를 통과한 것만 받는다.** 처음에는 3겹을 「나머지 들로네」로
## 두었는데, 1·2 겹이 작아 3겹까지 내려가는 판이 흔했고 그때 들어온 간선이 방을 24 px
## 앞까지 스쳤다 (§17.17.6).
##
## 가브리엘 간선은 두 방 사이에 낀 방이 없다는 뜻이라, 그 선을 그어도 엉뚱한 제3의 방을
## 스치지 않는다. 겹의 순서가 곧 우선순위이고, `_add_extras` 가 앞에서부터 쓴다.
func _ranked_pool(chosen: Array[Vector2i], rng: RandomNumberGenerator) -> Array[Vector2i]:
	var taken := {}
	for edge in chosen:
		taken[edge] = true

	var inside := _inside_edges()
	var hubs := _hubs(inside)
	var hub_edges: Array[Vector2i] = []
	var inner: Array[Vector2i] = []
	for edge in ProximityGraphs.gabriel(_points, inside):
		if taken.has(edge):
			continue
		taken[edge] = true
		if hubs.has(edge.x) or hubs.has(edge.y):
			hub_edges.append(edge)
		else:
			inner.append(edge)

	# 구역을 넘는 후보는 가브리엘만 받는다. 관문이 하나라는 성질을 흐리는 대신 V5 를 맞출 때
	# 쓰이므로 아주 버릴 수는 없지만, 아무 간선이나 받으면 통로가 방을 스친다.
	var crossing: Array[Vector2i] = []
	for edge in ProximityGraphs.gabriel(_points, _delaunay):
		if not taken.has(edge) and _readable(edge):
			taken[edge] = true
			crossing.append(edge)

	# 마지막 겹. 여기까지 왔으면 정말 모자란 것이므로 **읽히는 것만** 받는다.
	var rest: Array[Vector2i] = []
	for edge in _delaunay:
		if not taken.has(edge) and _readable(edge):
			rest.append(edge)

	return (
		_by_score(hub_edges, rng)
		+ _by_score(inner, rng)
		+ _by_score(crossing, rng)
		+ _by_score(rest, rng)
	)


## 그 간선을 그어도 상관없는 방을 스치지 않는가.
##
## **모든 단계가 이걸 지켜야 한다.** 뼈대는 RNG 라 저절로 지켜지지만, 관문 · 수선 · 곁가지는
## 후보가 줄어든 상태에서 고르므로 직접 확인해야 한다. 한 군데라도 빠지면
## 「통로가 방을 관통하지 않는다」가 깨진다 (§17.6, `test_dungeon_layout.gd`).
func _readable(edge: Vector2i) -> bool:
	return DungeonZones.clearance(_points, edge) >= DungeonZones.CLEARANCE_MIN


## 점수 내림차순. 점수를 미리 계산해 두는 이유는, 비교 함수 안에서 난수를 뽑으면
## 호출 순서에 따라 결과가 달라져 **같은 시드가 같은 판을 만들지 못하기 때문이다** (§17.7).
func _by_score(edges: Array[Vector2i], rng: RandomNumberGenerator) -> Array[Vector2i]:
	var scored: Array = []
	for edge in edges:
		scored.append({"edge": edge, "key": _score(edge, rng)})
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
##
## **깊이 항이 없다.** 깊은 곳을 성기게 만드는 일은 구역과 관문이 대신한다 (위 주석 참고).
func _score(edge: Vector2i, rng: RandomNumberGenerator) -> float:
	var climb := absi(_elevations[edge.x] - _elevations[edge.y])
	# 가파른 통로가 흔해지면 필요 민첩이라는 등급 자체가 의미를 잃는다 (§17.4).
	var gentle := 1.0 / (1.0 + float(climb))
	# 흔들어 주지 않으면 같은 지형에서 늘 같은 곁가지가 나온다.
	return gentle * rng.randf_range(0.55, 1.45)


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
	var fallback: Array = []
	for edge in _delaunay:
		if (edge.x == _entrance or edge.y == _entrance) and not result.has(edge):
			# 가까운 방부터 붙인다. 판 반대편까지 뻗는 긴 통로가 입구에 생기면
			# 첫 선택지가 판을 가로지르는 이상한 그림이 된다.
			var entry := {
				"edge": edge, "key": -_points[edge.x].distance_squared_to(_points[edge.y])
			}
			if _readable(edge):
				entries.append(entry)
			else:
				fallback.append(entry)
	# 읽히는 후보를 먼저 쓰고, 없으면 스치는 것이라도 쓴다 —
	# **선택지가 하나뿐인 시작을 막는 것이 읽힘보다 앞선다** (V7 은 공정성 규칙이다).
	var candidates := _by_key(entries) + _by_key(fallback)
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
