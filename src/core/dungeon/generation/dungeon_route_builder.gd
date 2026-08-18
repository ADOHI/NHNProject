class_name DungeonRouteBuilder
extends RefCounted
## 보상 방을 고르고 **거기까지 가는 길을 둘로 만든다.**
##
## 지금까지 방 종류는 간선 선택이 끝난 **뒤에** 정했다. 그래서 보상 근처에 우회로가 있는지가
## 우연이었다 — 실측에서 귀중 방의 31% 만 대안 경로가 있었고, 방 50개에서는 보스에
## 대안 경로가 있는 판이 7.5% 였다 (docs/design/17-dungeon-generation.md §17.11.7).
##
## 순서를 뒤집는다. **보상 자리를 먼저 정하고 그 주변을 설계한다.**
##
## | 하는 일 | 무엇을 보장하나 |
## | --- | --- |
## | `pick_prize` | 봉우리로 세울 수 있고 두 경로를 낼 수 있는 방만 **후보에 넣는다** |
## | `expose` | 보상 방의 차수를 4 이상으로 (P3 — 보상이 곧 노출) |
## | `ensure_two_routes` | 간선이 겹치지 않는 두 경로를 **없으면 판다** |
##
## ## 후보를 거르지 않으면 「가장 덜 나쁜 것」이 통과한다
##
## 덩어리 2 에서 배운 것이다. 관문을 「후보 중 여유가 가장 큰 것」으로 골랐더니 여전히
## 방을 스쳤다 — 그 구역 쌍의 **모든** 후보가 나빴기 때문이다 (§17.17.9).
##
## > **고를 수 있는 것 중 최선을 고르는 것으로는 모자라다. 최선이 나쁘면 결과가 나쁘다.**
##
## 그래서 보상 자리도 점수로 고르지 않고 **자격으로 거른다.** 차수 4 를 만들 수 없거나
## 두 경로를 낼 수 없는 방은 애초에 후보가 아니다.
##
## ## 새로 잇는 간선은 전부 들로네 부분집합이다
##
## 교차가 없다는 보장(V8)이 여기 걸려 있다. 없는 간선을 파더라도 들로네 밖에서 가져오지
## 않는다. 그리고 **여유(DungeonZones.CLEARANCE_MIN)를 지키는 것만** 받는다 —
## 그러지 않으면 통로가 상관없는 방을 스친다 (§17.6).

## 보상 방이 가져야 할 최소 연결 수. **보상이 곧 노출이다.**
##
## 조우는 방에서만 일어나므로(docs/design/05-rules.md §5.6) 차수가 곧 들어오는 길의 수다.
## 실측에서 지금 생성기의 보스 방 차수는 1.08 이었다 — 판 평균이 3.00 인데 주인공만
## 외길이었고, 사용자 요구의 정반대였다 (§17.14.2).
const PRIZE_DEGREE := 4

## 봉우리가 주변보다 얼마나 높기를 바라는가. 후보를 거를 때만 쓴다 —
## 실제로 세우는 것은 DungeonTerrain 이고 그쪽 상수가 정답이다.
const PEAK_RISE := DungeonTerrain.PEAK_RISE


## 보상 방. 자격을 갖춘 방이 없으면 -1 을 돌려준다.
##
## 자격은 셋이다 — **깊은 구역** · **차수 4 를 만들 수 있다** · **두 경로를 낼 수 있다.**
## 그 안에서 가장 높은 방을 고른다. 같은 높이면 들로네 이웃이 많은 쪽, 그다음은 인덱스다
## (난수를 쓰지 않는다. 같은 시드가 같은 판을 만들어야 한다 — §17.7).
static func pick_prize(
	points: PackedVector2Array,
	delaunay: Array[Vector2i],
	elevations: PackedInt32Array,
	zones: PackedInt32Array,
	ranks: PackedInt32Array,
	entrance: int
) -> int:
	# **여유 검사를 한 번만 한다.** 후보마다 다시 하면 방 개수 x 간선 수 만큼 거리를 재게 되고,
	# 방 50개에서 생성이 7.1 ms 에서 14.6 ms 로 두 배가 됐다 (프레임 예산 16.7 의 88%).
	var usable := _readable_only(points, delaunay)

	# **이웃도 그 집합으로 센다.**
	#
	# 예전에는 들로네 전체로 셌다. 그런데 `expose` 는 읽히는 간선만 붙이므로, 들로네 이웃이
	# 넷이어도 그중 셋만 읽히면 차수 4 를 못 채운다. **자격을 재는 자와 실제로 쓰는 자가
	# 달랐던 것**이고, 그래서 보스 차수가 3.7 에 머물렀다 (§17.17.9 의 교훈).
	var neighbours := _adjacency(points.size(), usable)
	var deepest := 0
	for index in points.size():
		deepest = maxi(deepest, _rank_of(zones, ranks, index))

	# 가장 깊은 등급에서 시작해 자격자가 나올 때까지 한 단계씩 물러난다.
	# **경사로가 올라올 만큼 긴 두 번째 길을 가진 방을 먼저 찾는다** (아래 설명).
	# **입구 구역(등급 0)은 마지막 물러남에서만 본다.** 등급 0 을 함께 훑게 두었더니
	# 보상이 입구 구역에 놓여 필요 민첩이 0 이 됐다 (V3 가 깨졌다).
	for strict in [true, false]:
		var rank := deepest
		while rank > 0:
			var found := _best_candidate(
				points, usable, elevations, zones, ranks, entrance, rank, neighbours, strict
			)
			if found >= 0:
				return found
			rank -= 1
	return _best_candidate(points, usable, elevations, zones, ranks, entrance, 0, neighbours, false)


static func _best_candidate(
	points: PackedVector2Array,
	usable: Array[Vector2i],
	elevations: PackedInt32Array,
	zones: PackedInt32Array,
	ranks: PackedInt32Array,
	entrance: int,
	rank: int,
	neighbours: Dictionary,
	require_ramp: bool
) -> int:
	var best := -1
	var best_key := -INF
	for index in points.size():
		if index == entrance or _rank_of(zones, ranks, index) != rank:
			continue
		if (neighbours[index] as Array[int]).size() < PRIZE_DEGREE:
			continue
		var second := _second_route(points.size(), usable, entrance, index)
		if second.size() < 2:
			continue
		# **경사로가 봉우리까지 1 씩 올라올 만큼 길어야 한다.**
		#
		# 봉우리 높이는 계단이 닿는 높이로 묶여 있다(DungeonTerrain.sharpen). 두 번째 길이
		# 짧으면 봉우리가 낮아지고, 그러면 **보상 방이 평범한 방보다 싸게 닿는다** —
		# 실측에서 고가치 방 평균 필요 민첩 1.0 대 평범한 방 1.19 가 나와 V3 정신이 깨졌다.
		#
		# 고르는 쪽에서 물러나지 않고 **후보에서 걸러 낸다** (§17.17.9 의 교훈).
		# 자격자가 없으면 부르는 쪽이 이 조건을 놓고 다시 찾는다.
		if require_ramp and second.size() - 1 < elevations[index] + PEAK_RISE:
			continue
		# 높은 곳 우선, 같으면 이웃이 많은 쪽, 그다음 인덱스로 확정한다.
		var key := (
			float(elevations[index]) * 1000.0
			+ float((neighbours[index] as Array[int]).size())
			- float(index) * 0.001
		)
		if key > best_key:
			best_key = key
			best = index
	return best


## 간선이 겹치지 않는 **두 번째** 길. 없으면 빈 배열.
##
## `usable` 은 **이미 여유를 통과한** 들로네 간선들이다. 부르는 쪽이 한 번만 걸러서 넘긴다.
static func _second_route(
	count: int, usable: Array[Vector2i], entrance: int, target: int
) -> PackedInt32Array:
	var first := _path(count, usable, entrance, target)
	if first.size() < 2:
		return PackedInt32Array()
	var reduced: Array[Vector2i] = []
	for edge in usable:
		if not on_path(first, edge):
			reduced.append(edge)
	return _path(count, reduced, entrance, target)


## **보상 방을 사방으로 뚫는다** (P3). 차수가 모자라면 짧고 읽히는 들로네 간선을 붙인다.
static func expose(
	points: PackedVector2Array, delaunay: Array[Vector2i], edges: Array[Vector2i], target: int
) -> Array[Vector2i]:
	var result := edges.duplicate()
	if target < 0:
		return result
	var taken := {}
	var degree := 0
	for edge in result:
		taken[DelaunayTriangulation.edge_key(edge.x, edge.y)] = true
		if edge.x == target or edge.y == target:
			degree += 1

	# 막다른 방을 이어 버리면 정찰 지점이 사라진다 (V5). 실측에서 막다른 방 비율이
	# 4.76% 까지 떨어져 하한을 깼다 — 노출이 V5 보정보다 **뒤에** 오기 때문이다.
	# 그래서 이미 차수 2 이상인 이웃을 먼저 쓴다.
	var degrees := {}
	for edge in result:
		degrees[edge.x] = int(degrees.get(edge.x, 0)) + 1
		degrees[edge.y] = int(degrees.get(edge.y, 0)) + 1

	var entries: Array = []
	for edge in delaunay:
		if edge.x != target and edge.y != target:
			continue
		var key := DelaunayTriangulation.edge_key(edge.x, edge.y)
		if taken.has(key) or not _readable(points, edge):
			continue
		var other: int = edge.y if edge.x == target else edge.x
		var keeps_scout := 1.0 if int(degrees.get(other, 0)) >= 2 else 0.0
		# 정찰 지점을 지키는 쪽을 먼저, 그 안에서 가까운 방부터 (§17.6).
		entries.append(
			{
				"edge": key,
				"key": keeps_scout * 1e9 - points[edge.x].distance_squared_to(points[edge.y])
			}
		)
	for key in _by_key(entries):
		if degree >= PRIZE_DEGREE:
			break
		result.append(key)
		degree += 1
	return result


## **보상까지 가는 길을 둘로 만든다. 검사가 아니라 시공이다.**
##
## 대안 경로가 있으면 생기고 없으면 마는 것이 아니라, 없으면 **판다.**
## 들로네에는 아직 쓰이지 않은 간선이 남아 있고, 그 부분집합이라 교차는 생기지 않는다 (V8).
static func ensure_two_routes(
	points: PackedVector2Array,
	delaunay: Array[Vector2i],
	edges: Array[Vector2i],
	entrance: int,
	target: int
) -> Array[Vector2i]:
	var result := edges.duplicate()
	if target < 0:
		return result
	var fast := _path(points.size(), result, entrance, target)
	if fast.size() < 2:
		return result

	var reduced: Array[Vector2i] = []
	for edge in result:
		if not on_path(fast, edge):
			reduced.append(edge)
	if _path(points.size(), reduced, entrance, target).size() >= 2:
		return result

	# 빠른 길의 간선만 뺀 들로네에서 두 번째 길을 찾아 없는 간선을 채운다.
	var reservoir: Array[Vector2i] = []
	for edge in _readable_only(points, delaunay):
		if not on_path(fast, edge):
			reservoir.append(edge)
	var carved := _path(points.size(), reservoir, entrance, target)
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
static func routes(count: int, edges: Array[Vector2i], entrance: int, target: int) -> Dictionary:
	var fast := _path(count, edges, entrance, target)
	var reduced: Array[Vector2i] = []
	for edge in edges:
		if not on_path(fast, edge):
			reduced.append(edge)
	return {"fast": fast, "slow": _path(count, reduced, entrance, target)}


# ---------------------------------------------------------------- 도구


static func _readable_only(
	points: PackedVector2Array, delaunay: Array[Vector2i]
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for edge in delaunay:
		if _readable(points, edge):
			result.append(edge)
	return result


static func _readable(points: PackedVector2Array, edge: Vector2i) -> bool:
	return DungeonZones.clearance(points, edge) >= DungeonZones.CLEARANCE_MIN


static func _rank_of(zones: PackedInt32Array, ranks: PackedInt32Array, index: int) -> int:
	if index >= zones.size():
		return 0
	var zone := zones[index]
	if zone < 0 or zone >= ranks.size():
		return 0
	return ranks[zone]


static func _adjacency(count: int, edges: Array[Vector2i]) -> Dictionary:
	var result := {}
	for index in count:
		result[index] = [] as Array[int]
	for edge in edges:
		if edge.x < 0 or edge.y < 0 or edge.x >= count or edge.y >= count:
			continue
		(result[edge.x] as Array[int]).append(edge.y)
		(result[edge.y] as Array[int]).append(edge.x)
	return result


static func _path(count: int, edges: Array[Vector2i], start: int, target: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	if start < 0 or target < 0 or start == target:
		return result
	var neighbours := _adjacency(count, edges)
	var parent := {start: -1}
	var frontier: Array[int] = [start]
	while not frontier.is_empty():
		var current: int = frontier.pop_front()
		if current == target:
			break
		for other in neighbours[current] as Array[int]:
			if parent.has(other):
				continue
			parent[other] = current
			frontier.append(other)
	if not parent.has(target):
		return result

	var walk := target
	while walk >= 0:
		result.append(walk)
		walk = int(parent[walk])
	result.reverse()
	return result


## 그 간선이 길 위에 놓여 있는가. 방향은 보지 않는다.
##
## **공개해 둔다.** 같은 판정이 `tools/dungeon_metrics.gd` 에 한 글자도 안 틀리고 한 벌 더
## 있었다. 도구는 `src/` 를 불러도 되므로(반대는 안 된다) 그쪽이 이 함수를 쓴다.
## 갈리면 **화면이 그리는 두 길과 계측기가 재는 두 길이 달라진다** — 그리고 아무 데도
## 안 빨개진다 (docs/design/17-dungeon-generation.md §17.32).
static func on_path(route: PackedInt32Array, edge: Vector2i) -> bool:
	for index in range(1, route.size()):
		var a := route[index - 1]
		var b := route[index]
		if (edge.x == a and edge.y == b) or (edge.x == b and edge.y == a):
			return true
	return false


## {"edge": Vector2i, "key": float} 목록을 key 내림차순으로 세워 간선만 뽑는다.
##
## 비교 함수 안에서는 값만 본다. 난수를 뽑거나 바깥 값을 들여다보면 같은 시드가 다른 판을
## 만든다 (§17.7).
static func _by_key(entries: Array) -> Array[Vector2i]:
	entries.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return float(a["key"]) > float(b["key"])
	)
	var result: Array[Vector2i] = []
	for entry in entries:
		result.append(entry["edge"])
	return result
