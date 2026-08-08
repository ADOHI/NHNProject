extends RefCounted
## **설계안 프로토타입.** 그림으로 비교하기 위한 것이지 제품 코드가 아니다.
##
## src/ 에 넣지 않았고 class_name 도 없다. 승인 전에는 게임이 이 파일을 모르게 둔다
## (CLAUDE.md 개발 원칙 5).
##
## 지금 생성기와 다른 점은 **간선을 고르는 규칙이 아니라 순서**다.
## 지금은 자리 -> 간선 -> (그 결과로) 방 종류다. 여기서는 자리 -> **구역** ->
## **구역 사이의 관문** -> 보상 자리 -> **그 보상까지의 두 경로** -> 나머지 간선이다.
##
## | 요구 (사용자 피드백 2026-08-08) | 이 프로토타입이 하는 일 |
## | --- | --- |
## | 빨리 가는 길과 돌아가는 길 | 보상 구역에 입구를 **둘** 뚫고 둘의 성격을 일부러 벌린다 |
## | 간선은 적은데 fully connected | 구역 사이는 나무 + 고리 하나. 거시 구조가 성기다 |
## | 갈림길이 많아야 한다 | 구역 **안**은 촘촘하게. 간선을 허브에 몰아 차수를 불균등하게 만든다 |
## | 귀중한 방은 고도가 높다 | 고도를 거리가 아니라 **구역 등급**에서 만든다. 관문이 절벽이 된다 |
##
## docs/design/17-dungeon-generation.md §17.12 참고.

const _NOISE_AMPLITUDE := 1.1
const _NOISE_FREQUENCY := 0.22

## 구역 하나가 담을 방의 대략적인 수. 작을수록 관문이 늘고 판이 길어진다.
const _ROOMS_PER_REGION := 6.0

## 보상 방이 가져야 할 최소 연결 수. **보상이 곧 노출이다.**
##
## 조우는 방에서만 일어나므로(05-rules.md §5.6) 차수가 곧 들어오는 길의 수다.
## 값진 방일수록 사방이 뚫려 있어야 "챙길수록 위험해진다"가 지형에서 나온다.
const _PRIZE_DEGREE := 4

## 구역 등급이 하나 오를 때의 단차. **기본 민첩으로 넘을 수 있는 크기여야 한다.**
##
## 두 번 틀렸다. 3 으로 두면 관문마다 벽이 서서 판의 20~50% 밖에 못 간다.
## 고도 폭을 고정하고 나눠 갖게 하면 작은 판만 가팔라진다(구역이 적어 단차가 커진다).
##
## **고도로 판 전체를 막는 것이 애초에 틀린 접근이다.** 지형은 걸어 다닐 수 있게 두고,
## 벽은 **보상 봉우리와 지름길에만** 세운다. 그래야 벽이 있는 곳이 곧 의도가 된다.
const _REGION_STEP := 2


## 판 하나를 만든다. 반환값은 그리기 도구가 그대로 읽는 사전이다.
static func build(seed_value: int, room_count: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var region_size := PoissonDiskSampler.region_for_count(room_count)
	var points := PoissonDiskSampler.new(region_size).generate(rng)
	if points.size() < 6:
		return {}
	var delaunay := DelaunayTriangulation.edges(points)
	var entrance := _corner_room(points, region_size, rng)

	var zone_total := _zone_count(points.size())
	var zones := _zones(points, entrance, zone_total)
	var zone_edges := _zone_adjacency(delaunay, zones)
	var zone_links := _zone_ring(points, zones, zone_edges, zone_total)
	var ranks := _zone_ranks(zone_links, zones[entrance], zone_total)
	var prize_zone := _highest_rank(ranks)

	var elevations := _elevations(points, zones, ranks, entrance, seed_value)
	var edges := _edges(points, delaunay, zones, zone_links, rng)
	edges = _repair(points, delaunay, edges, entrance)

	var boss := _prize_room(points, zones, elevations, prize_zone, entrance)
	edges = _expose(points, delaunay, edges, boss)
	edges = _ensure_two_routes(points.size(), delaunay, edges, entrance, boss)
	var routes := _routes(points.size(), edges, entrance, boss)
	elevations = _sharpen(elevations, routes, edges, entrance)

	var exit_index := _exit_room(points, zones, ranks, edges, entrance)
	elevations = _carve(elevations, _path(points.size(), edges, entrance, exit_index))

	return {
		"points": points,
		"edges": edges,
		"elevations": elevations,
		"zones": zones,
		"ranks": ranks,
		"entrance": entrance,
		"exit": exit_index,
		"boss": boss,
		"kinds": _kinds(points.size(), edges, zones, elevations, entrance, exit_index, boss, rng),
		"fast": routes["fast"],
		"slow": routes["slow"],
	}


## 입구는 판 가장자리. 지금 생성기와 같은 규칙이라 비교에서 이 축이 변수가 되지 않는다.
static func _corner_room(
	points: PackedVector2Array, region: Vector2, rng: RandomNumberGenerator
) -> int:
	var corners: Array[Vector2] = [
		Vector2.ZERO, Vector2(region.x, 0.0), Vector2(0.0, region.y), region
	]
	var corner := corners[rng.randi() % corners.size()]
	var best := 0
	var best_distance := INF
	for index in points.size():
		var distance := corner.distance_squared_to(points[index])
		if distance < best_distance:
			best_distance = distance
			best = index
	return best


static func _zone_count(rooms: int) -> int:
	return clampi(int(round(float(rooms) / _ROOMS_PER_REGION)), 3, 8)


## 입구를 첫 씨앗으로 하는 최원점 샘플링. 씨앗이 정해지면 가장 가까운 씨앗에 붙인다.
##
## 무작위 씨앗을 쓰지 않는 이유는 구역 크기가 들쭉날쭉해지기 때문이다.
## 최원점 샘플링은 씨앗끼리 최대한 떨어뜨려 구역이 고르게 나뉜다.
static func _zones(points: PackedVector2Array, entrance: int, wanted: int) -> PackedInt32Array:
	var seeds: Array[int] = [entrance]
	while seeds.size() < wanted:
		var best := -1
		var best_distance := -1.0
		for index in points.size():
			var nearest := INF
			for seed_index in seeds:
				nearest = minf(nearest, points[seed_index].distance_squared_to(points[index]))
			if nearest > best_distance:
				best_distance = nearest
				best = index
		seeds.append(best)

	var result := PackedInt32Array()
	result.resize(points.size())
	for index in points.size():
		var best_zone := 0
		var best_distance := INF
		for slot in seeds.size():
			var distance := points[seeds[slot]].distance_squared_to(points[index])
			if distance < best_distance:
				best_distance = distance
				best_zone = slot
		result[index] = best_zone
	return result


## 구역 쌍 -> 그 둘을 잇는 가장 짧은 들로네 간선.
static func _zone_adjacency(delaunay: Array[Vector2i], zones: PackedInt32Array) -> Dictionary:
	var result := {}
	for edge in delaunay:
		var a := zones[edge.x]
		var b := zones[edge.y]
		if a == b:
			continue
		var key := Vector2i(mini(a, b), maxi(a, b))
		if not result.has(key):
			result[key] = [] as Array[Vector2i]
		(result[key] as Array[Vector2i]).append(edge)
	return result


## 구역을 **고리**로 잇는다. 여기가 이 설계안의 심장이다.
##
## 나무로 이으면 어느 목적지든 통로가 하나뿐이라 "돌아가는 길"이 원리적으로 없다.
## 프로토타입을 나무로 먼저 만들어 봤더니 보스 방에 대안 경로가 있는 판이 8~42%
## 밖에 안 됐다 (§17.12.5). 보상 구역에만 고리를 덧대도 마찬가지였다 —
## **입구 구역이 그 고리 위에 없으면** 두 경로가 앞부분을 공유하기 때문이다.
##
## 고리로 만들면 입구가 반드시 고리 위에 있고, 어느 구역으로 가든 좌우 두 방향이 생긴다.
## 간선은 구역 수만큼만 쓴다 — 거시 순환 계수가 정확히 1 이다.
static func _zone_ring(
	points: PackedVector2Array, zones: PackedInt32Array, zone_edges: Dictionary, count: int
) -> Array[Vector2i]:
	var centers := _zone_centers(points, zones, count)
	var middle := Vector2.ZERO
	for center in centers:
		middle += center
	middle /= float(count)

	var order: Array[int] = []
	for index in count:
		order.append(index)
	order.sort_custom(
		func(a: int, b: int) -> bool:
			return (centers[a] - middle).angle() < (centers[b] - middle).angle()
	)

	var result: Array[Vector2i] = []
	for slot in count:
		var a: int = order[slot]
		var b: int = order[(slot + 1) % count]
		var key := Vector2i(mini(a, b), maxi(a, b))
		# 들로네에서 두 구역이 실제로 맞닿아 있을 때만 통로를 낸다.
		if zone_edges.has(key) and not result.has(key):
			result.append(key)

	# 각도 순서가 맞닿지 않는 쌍을 만들었으면 남은 쌍으로 연결만 보장한다.
	var parent: Array[int] = []
	for index in count:
		parent.append(index)
	for key in result:
		_union(parent, key.x, key.y)
	for key in zone_edges:
		if _union(parent, key.x, key.y):
			result.append(key)
	return result


static func _zone_centers(
	points: PackedVector2Array, zones: PackedInt32Array, count: int
) -> Array[Vector2]:
	var totals: Array[Vector2] = []
	var seen: Array[float] = []
	for index in count:
		totals.append(Vector2.ZERO)
		seen.append(0.0)
	for index in points.size():
		totals[zones[index]] += points[index]
		seen[zones[index]] += 1.0
	for index in count:
		totals[index] /= maxf(seen[index], 1.0)
	return totals


static func _shortest_of(edges: Array[Vector2i], points: PackedVector2Array) -> float:
	var best := INF
	for edge in edges:
		best = minf(best, points[edge.x].distance_squared_to(points[edge.y]))
	return best


## 입구 구역에서 몇 단계 떨어져 있는가. 그대로 고도의 기본값이 된다.
static func _zone_ranks(links: Array[Vector2i], start: int, count: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(count)
	result.fill(-1)
	result[start] = 0
	var frontier: Array[int] = [start]
	while not frontier.is_empty():
		var current: int = frontier.pop_front()
		for link in links:
			var other := -1
			if link.x == current:
				other = link.y
			elif link.y == current:
				other = link.x
			if other >= 0 and result[other] < 0:
				result[other] = result[current] + 1
				frontier.append(other)
	for index in count:
		if result[index] < 0:
			result[index] = 0
	return result


static func _highest_rank(ranks: PackedInt32Array) -> int:
	var best := 0
	for index in ranks.size():
		if ranks[index] > ranks[best]:
			best = index
	return best


## 고도는 거리가 아니라 **구역 등급**에서 나온다.
##
## 지금 생성기는 입구에서의 거리로 매끈한 원뿔을 만든다. 그러면 어디를 봐도 기울기가
## 같아서 "여기부터 위쪽"이라는 경계가 생기지 않는다. 등급으로 만들면 구역 안은
## 평탄하고 **구역 경계에서만 층이 진다** — 관문이 눈에 보이는 지형이 된다.
static func _elevations(
	points: PackedVector2Array,
	zones: PackedInt32Array,
	ranks: PackedInt32Array,
	entrance: int,
	noise_seed: int
) -> PackedInt32Array:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = _NOISE_FREQUENCY

	var result := PackedInt32Array()
	var lowest := 0
	for index in points.size():
		var base := float(ranks[zones[index]] * _REGION_STEP)
		var value := int(
			round(base + noise.get_noise_2d(points[index].x, points[index].y) * _NOISE_AMPLITUDE)
		)
		lowest = mini(lowest, value)
		result.append(value)
	for index in result.size():
		result[index] -= lowest
	result[entrance] = 0
	return result


## 간선을 고른다. **구역 안은 촘촘하게, 구역 사이는 관문 하나씩.**
##
## 안쪽을 촘촘하게 하되 고르게 뿌리지 않는다. 허브 하나에 몰아 주면 같은 간선 수로도
## 차수 4 짜리 갈림길과 차수 1 짜리 막다른 방이 함께 생긴다.
## 고르게 뿌리면 전부 차수 2~3 이 되어 어느 방이나 똑같아 보인다.
static func _edges(
	points: PackedVector2Array,
	delaunay: Array[Vector2i],
	zones: PackedInt32Array,
	zone_links: Array[Vector2i],
	rng: RandomNumberGenerator
) -> Array[Vector2i]:
	var inside: Array[Vector2i] = []
	for edge in delaunay:
		if zones[edge.x] == zones[edge.y]:
			inside.append(edge)

	var chosen := ProximityGraphs.minimum_spanning_tree(points, inside)
	var taken := {}
	for edge in chosen:
		taken[DelaunayTriangulation.edge_key(edge.x, edge.y)] = true

	var hubs := _hubs(points.size(), inside, zones)
	for edge in ProximityGraphs.gabriel(points, inside):
		var key := DelaunayTriangulation.edge_key(edge.x, edge.y)
		if taken.has(key):
			continue
		# 허브에 닿는 간선만 받는다. 그 방이 판의 갈림길이 된다.
		if not (hubs.has(edge.x) or hubs.has(edge.y)):
			continue
		if rng.randf() > 0.75:
			continue
		taken[key] = true
		chosen.append(key)

	for link in zone_links:
		var gate := _gate_edge(points, delaunay, zones, link)
		if gate == Vector2i(-1, -1):
			continue
		var key := DelaunayTriangulation.edge_key(gate.x, gate.y)
		if taken.has(key):
			continue
		taken[key] = true
		chosen.append(key)
	return chosen


## 구역마다 들로네 이웃이 가장 많은 방 하나. 여기에 간선을 몰아 준다.
static func _hubs(count: int, inside: Array[Vector2i], zones: PackedInt32Array) -> Dictionary:
	var degrees := {}
	for edge in inside:
		degrees[edge.x] = int(degrees.get(edge.x, 0)) + 1
		degrees[edge.y] = int(degrees.get(edge.y, 0)) + 1

	var best := {}
	for index in count:
		var zone := zones[index]
		var current: int = best.get(zone, -1)
		if current < 0 or int(degrees.get(index, 0)) > int(degrees.get(current, 0)):
			best[zone] = index

	var result := {}
	for zone in best:
		result[best[zone]] = true
	return result


## 두 구역을 잇는 가장 짧은 들로네 간선. 이것 하나만 통로가 된다.
static func _gate_edge(
	points: PackedVector2Array, delaunay: Array[Vector2i], zones: PackedInt32Array, link: Vector2i
) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_distance := INF
	for edge in delaunay:
		var pair := Vector2i(mini(zones[edge.x], zones[edge.y]), maxi(zones[edge.x], zones[edge.y]))
		if pair != link:
			continue
		var distance := points[edge.x].distance_squared_to(points[edge.y])
		if distance < best_distance:
			best_distance = distance
			best = edge
	return best


## 떨어져 나온 방이 있으면 들로네 간선으로 도로 붙인다 (V1 은 프로토타입에서도 지킨다).
static func _repair(
	points: PackedVector2Array, delaunay: Array[Vector2i], edges: Array[Vector2i], entrance: int
) -> Array[Vector2i]:
	var result := edges.duplicate()
	for attempt in 8:
		var seen := _reachable(points.size(), result, entrance)
		if seen.size() == points.size():
			return result
		var added := false
		for edge in delaunay:
			if seen.has(edge.x) != seen.has(edge.y):
				result.append(DelaunayTriangulation.edge_key(edge.x, edge.y))
				added = true
				break
		if not added:
			return result
	return result


## **보상 방을 사방으로 뚫는다.** 연결이 많다는 것은 들어오는 길이 많다는 뜻이고,
## 조우가 방에서만 일어나므로(05-rules.md §5.6) 그대로 위협의 크기가 된다.
##
## 실측에서 지금 생성기의 귀중 방 평균 차수는 **1.86** 이다 (판 평균 3.00).
## 값진 방이 판에서 가장 외진 방이라는 뜻이고, 사용자 요구의 정반대다 (§17.13.2).
##
## 접근이 어려워야 한다는 요구와 부딪히지 않는다. **길은 많되 전부 험하게** 만든다 —
## 뚫는 것은 여기서 하고, 험하게 만드는 것은 _sharpen 이 봉우리로 세워서 한다.
static func _expose(
	points: PackedVector2Array, delaunay: Array[Vector2i], edges: Array[Vector2i], target: int
) -> Array[Vector2i]:
	var result := edges.duplicate()
	var taken := {}
	var degree := 0
	for edge in result:
		taken[DelaunayTriangulation.edge_key(edge.x, edge.y)] = true
		if edge.x == target or edge.y == target:
			degree += 1

	var candidates: Array[Vector2i] = []
	for edge in delaunay:
		if edge.x != target and edge.y != target:
			continue
		var key := DelaunayTriangulation.edge_key(edge.x, edge.y)
		if not taken.has(key):
			candidates.append(key)
	candidates.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return (
				points[a.x].distance_squared_to(points[a.y])
				< points[b.x].distance_squared_to(points[b.y])
			)
	)
	for key in candidates:
		if degree >= _PRIZE_DEGREE:
			break
		result.append(key)
		degree += 1
	return result


## **보상까지 가는 길을 둘로 만든다. 검사가 아니라 시공이다.**
##
## 지금 생성기는 대안 경로가 생기면 생기고 말면 만다 — 실측에서 귀중 방의 31% 만
## 대안이 있었다 (§17.11.6). 여기서는 없으면 **판다.** 들로네에는 이미 쓰이지 않은
## 간선이 남아 있고, 그 부분집합이라 교차는 여전히 생기지 않는다 (§17.5 V8).
##
## 이것이 §17.5 가 세운 원칙("검사에서 보장으로")을 경로에도 적용한 것이다.
static func _ensure_two_routes(
	count: int, delaunay: Array[Vector2i], edges: Array[Vector2i], entrance: int, target: int
) -> Array[Vector2i]:
	var result := edges.duplicate()
	var fast := _path(count, result, entrance, target)
	if fast.size() < 2:
		return result

	var reduced: Array[Vector2i] = []
	for edge in result:
		if not _on_path(fast, edge):
			reduced.append(edge)
	if not _path(count, reduced, entrance, target).is_empty():
		return result

	# 들로네에서 빠른 길의 간선만 뺀 그래프에 두 번째 길이 있는지 본다.
	var reservoir: Array[Vector2i] = []
	for edge in delaunay:
		if not _on_path(fast, edge):
			reservoir.append(DelaunayTriangulation.edge_key(edge.x, edge.y))
	var carved := _path(count, reservoir, entrance, target)
	if carved.size() < 2:
		return result

	var taken := {}
	for edge in result:
		taken[DelaunayTriangulation.edge_key(edge.x, edge.y)] = true
	for index in range(1, carved.size()):
		var key := DelaunayTriangulation.edge_key(carved[index - 1], carved[index])
		if not taken.has(key):
			taken[key] = true
			result.append(key)
	return result


## 빠른 길과 돌아가는 길. 두 번째는 첫 번째의 간선을 빼고 다시 찾는다.
static func _routes(count: int, edges: Array[Vector2i], entrance: int, target: int) -> Dictionary:
	var fast := _path(count, edges, entrance, target)
	var reduced: Array[Vector2i] = []
	for edge in edges:
		if not _on_path(fast, edge):
			reduced.append(edge)
	return {"fast": fast, "slow": _path(count, reduced, entrance, target)}


## 두 경로의 성격을 **일부러 벌린다.**
##
## 대안이 있기만 해서는 선택이 되지 않는다. 실측에서 대안 경로는 더 길고 더 위험하고
## 기울기는 같았다 — 그러면 아무도 고르지 않는다 (§17.11.6).
## 그래서 빠른 길에는 절벽을 하나 세우고, 돌아가는 길은 기본 민첩으로 넘게 깎는다.
static func _sharpen(
	elevations: PackedInt32Array, routes: Dictionary, edges: Array[Vector2i], entrance: int
) -> PackedInt32Array:
	var result := elevations.duplicate()
	var fast: PackedInt32Array = routes["fast"]
	var slow: PackedInt32Array = routes["slow"]
	if fast.size() < 2 or slow.size() < 2:
		return result
	var goal := fast[fast.size() - 1]

	# 0) 돌아가는 길을 **한 칸에 1 씩만** 오르도록 깎는다. 관문의 층까지 함께 눕는다.
	#    이 길이 「고도 낮은 차이를 여러 번 거쳐서 가는 길」이다.
	for index in range(1, slow.size()):
		result[slow[index]] = mini(result[slow[index]], result[slow[index - 1]] + 1)

	# 1) 보상 방을 **봉우리**로 세운다. 이웃 어디에서 보든 올려다보는 자리가 된다.
	var around := 0
	for edge in edges:
		if edge.x == goal:
			around = maxi(around, result[edge.y])
		elif edge.y == goal:
			around = maxi(around, result[edge.x])
	result[goal] = around + 3

	# 2) 돌아가는 길에만 **경사로**를 놓는다. 목표에 가까울수록 한 칸씩 올라오게.
	for index in range(slow.size() - 2, 0, -1):
		var wanted := result[goal] - (slow.size() - 1 - index)
		if wanted <= result[slow[index]]:
			break
		result[slow[index]] = wanted

	# 3) 빠른 길의 마지막 한 칸은 **떨어뜨린다.** 짧은 쪽은 기어올라야 한다.
	var steep := fast[fast.size() - 2]
	if steep != entrance and not _has(slow, steep):
		result[steep] = maxi(0, result[goal] - 3)
	return result


static func _has(route: PackedInt32Array, node: int) -> bool:
	for index in route:
		if index == node:
			return true
	return false


static func _carve(elevations: PackedInt32Array, route: PackedInt32Array) -> PackedInt32Array:
	var result := elevations.duplicate()
	for index in route:
		result[index] = 0
	return result


## 보상 방 = 보상 구역에서 가장 높은 방.
static func _prize_room(
	points: PackedVector2Array,
	zones: PackedInt32Array,
	elevations: PackedInt32Array,
	prize_zone: int,
	entrance: int
) -> int:
	var best := -1
	for index in points.size():
		if zones[index] != prize_zone or index == entrance:
			continue
		if best < 0 or elevations[index] > elevations[best]:
			best = index
	return best if best >= 0 else entrance


## 탈출구 = 입구 구역이 아니면서 등급이 낮은 구역의, 입구에서 가장 먼 방.
static func _exit_room(
	points: PackedVector2Array,
	zones: PackedInt32Array,
	ranks: PackedInt32Array,
	edges: Array[Vector2i],
	entrance: int
) -> int:
	var depths := _depths(points.size(), edges, entrance)
	var best := entrance
	var best_depth := -1
	for index in points.size():
		if zones[index] == zones[entrance] or ranks[zones[index]] > 1:
			continue
		var depth := int(depths.get(index, -1))
		if depth > best_depth:
			best_depth = depth
			best = index
	return best


static func _kinds(
	count: int,
	edges: Array[Vector2i],
	zones: PackedInt32Array,
	elevations: PackedInt32Array,
	entrance: int,
	exit_index: int,
	boss: int,
	rng: RandomNumberGenerator
) -> Dictionary:
	var degrees := {}
	for edge in edges:
		degrees[edge.x] = int(degrees.get(edge.x, 0)) + 1
		degrees[edge.y] = int(degrees.get(edge.y, 0)) + 1

	var result := {entrance: Room.Kind.ENTRANCE, exit_index: Room.Kind.EXIT, boss: Room.Kind.BOSS}
	# 귀중품은 **막다른 방에** 놓는다. 들어갔다 도로 나와야 하는 것이 대가다.
	var dead_ends: Array[int] = []
	for index in count:
		if result.has(index):
			continue
		if int(degrees.get(index, 0)) <= 1:
			dead_ends.append(index)
	dead_ends.sort_custom(func(a: int, b: int) -> bool: return elevations[a] > elevations[b])
	var budget := maxi(1, int(round(float(count) * 0.14)))
	for index in dead_ends:
		if budget <= 0:
			break
		result[index] = Room.Kind.TREASURE
		budget -= 1

	for index in count:
		if result.has(index):
			continue
		# 위험방은 등급이 높은 구역에 몰아 준다. 깊은 곳이 험해야 판이 읽힌다.
		var weight := 0.06 + 0.09 * float(zones[index] != zones[entrance])
		if rng.randf() < weight + 0.04 * float(elevations[index]):
			result[index] = Room.Kind.HAZARD
		else:
			result[index] = Room.Kind.EMPTY
	return result


# ------------------------------------------------------------------ 그래프 도구


static func _adjacency(count: int, edges: Array[Vector2i]) -> Dictionary:
	var result := {}
	for index in count:
		result[index] = [] as Array[int]
	for edge in edges:
		(result[edge.x] as Array[int]).append(edge.y)
		(result[edge.y] as Array[int]).append(edge.x)
	return result


static func _depths(count: int, edges: Array[Vector2i], start: int) -> Dictionary:
	var neighbors := _adjacency(count, edges)
	var depths := {start: 0}
	var frontier: Array[int] = [start]
	while not frontier.is_empty():
		var current: int = frontier.pop_front()
		for neighbor in neighbors[current] as Array[int]:
			if depths.has(neighbor):
				continue
			depths[neighbor] = int(depths[current]) + 1
			frontier.append(neighbor)
	return depths


static func _reachable(count: int, edges: Array[Vector2i], start: int) -> Dictionary:
	return _depths(count, edges, start)


static func _path(count: int, edges: Array[Vector2i], start: int, target: int) -> PackedInt32Array:
	var neighbors := _adjacency(count, edges)
	var parent := {start: -1}
	var frontier: Array[int] = [start]
	while not frontier.is_empty():
		var current: int = frontier.pop_front()
		if current == target:
			break
		for neighbor in neighbors[current] as Array[int]:
			if parent.has(neighbor):
				continue
			parent[neighbor] = current
			frontier.append(neighbor)

	var result := PackedInt32Array()
	if not parent.has(target):
		return result
	var walk := target
	while walk >= 0:
		result.append(walk)
		walk = int(parent[walk])
	result.reverse()
	return result


static func _on_path(path: PackedInt32Array, edge: Vector2i) -> bool:
	for index in range(1, path.size()):
		var a := path[index - 1]
		var b := path[index]
		if (edge.x == a and edge.y == b) or (edge.x == b and edge.y == a):
			return true
	return false


static func _find(parent: Array[int], node: int) -> int:
	var root := node
	while parent[root] != root:
		root = parent[root]
	return root


static func _union(parent: Array[int], a: int, b: int) -> bool:
	var root_a := _find(parent, a)
	var root_b := _find(parent, b)
	if root_a == root_b:
		return false
	parent[root_b] = root_a
	return true
