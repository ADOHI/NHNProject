extends RefCounted
## 판 하나를 재는 공용 함수 모음. 계측 도구들이 같은 정의를 쓰게 하려고 뽑아냈다.
##
## 도구마다 지름이나 필요 민첩을 따로 구현하면 **같은 판을 재고도 다른 수가 나온다.**
## 지금 생성기와 설계안 프로토타입을 나란히 놓는 것이 목적이라 그건 치명적이다.
##
## class_name 을 두지 않는다. 게임은 이 파일을 몰라야 한다.


## 판 하나를 받아 지표 사전을 돌려준다.
##
## board 는 {points, edges, elevations, entrance, kinds} 를 가진 사전이다.
## 지금 생성기의 결과든 프로토타입의 결과든 이 모양으로 맞춰서 넘긴다.
static func measure(board: Dictionary) -> Dictionary:
	var count: int = (board["points"] as PackedVector2Array).size()
	var edges: Array[Vector2i] = board["edges"]
	var elevations: PackedInt32Array = board["elevations"]
	var kinds: Dictionary = board["kinds"]
	var entrance: int = board["entrance"]

	var degrees := degrees_of(count, edges)
	var deg1 := 0.0
	var deg2 := 0.0
	var deg3 := 0.0
	var total := 0.0
	for index in count:
		var degree := int(degrees[index])
		total += float(degree)
		if degree <= 1:
			deg1 += 1.0
		elif degree == 2:
			deg2 += 1.0
		else:
			deg3 += 1.0

	var costs := required_agility(count, edges, elevations, entrance)
	var open := 0
	for index in costs:
		if int(costs[index]) <= 2:
			open += 1

	var floor_count := maxf(float(count), 1.0)
	var result := {
		"rooms": float(count),
		"edges": float(edges.size()),
		"cycles": float(edges.size() - count + 1),
		"avg_degree": total / floor_count,
		"deg1_pct": 100.0 * deg1 / floor_count,
		"deg2_pct": 100.0 * deg2 / floor_count,
		"deg3_pct": 100.0 * deg3 / floor_count,
		"diameter": float(diameter(count, edges)),
		"reach_pct": 100.0 * float(open) / floor_count,
	}
	result.merge(_valuables(board, count, edges, elevations, kinds, degrees, entrance))
	return result


## 귀중 방에 관한 지표. 두 경로가 있는가, 그 둘의 성격이 다른가, 연결이 많은가.
static func _valuables(
	board: Dictionary,
	count: int,
	edges: Array[Vector2i],
	elevations: PackedInt32Array,
	kinds: Dictionary,
	degrees: Dictionary,
	entrance: int
) -> Dictionary:
	var seen := 0.0
	var with_alt := 0.0
	var dominated := 0.0
	var climb_fast := 0.0
	var climb_slow := 0.0
	var length_fast := 0.0
	var length_slow := 0.0
	var degree_total := 0.0
	var elevation_rank := 0.0
	var boss_alt := 0.0
	var boss_seen := 0.0

	for index in count:
		var kind: Room.Kind = kinds.get(index, Room.Kind.EMPTY)
		if kind != Room.Kind.TREASURE and kind != Room.Kind.BOSS:
			continue
		seen += 1.0
		degree_total += float(int(degrees.get(index, 0)))
		elevation_rank += _percentile(elevations, elevations[index])
		if kind == Room.Kind.BOSS:
			boss_seen += 1.0

		var fast := path(count, edges, entrance, index)
		if fast.size() < 2:
			continue
		var reduced: Array[Vector2i] = []
		for edge in edges:
			if not on_path(fast, edge):
				reduced.append(edge)
		var slow := path(count, reduced, entrance, index)
		if slow.size() < 2:
			continue

		with_alt += 1.0
		if kind == Room.Kind.BOSS:
			boss_alt += 1.0
		var a := describe(fast, elevations)
		var b := describe(slow, elevations)
		length_fast += a["length"]
		length_slow += b["length"]
		climb_fast += a["climb"]
		climb_slow += b["climb"]
		if a["climb"] <= b["climb"]:
			dominated += 1.0

	var alt := maxf(with_alt, 1.0)
	# board 는 여기서 더 쓰이지 않지만 호출 계약을 분명히 하려고 받는다.
	if board.is_empty():
		push_error("빈 판입니다")
	return {
		"alt_pct": 100.0 * with_alt / maxf(seen, 1.0),
		"boss_alt_pct": 100.0 * boss_alt / maxf(boss_seen, 1.0),
		"dominated_pct": 100.0 * dominated / alt,
		"len_fast": length_fast / alt,
		"len_slow": length_slow / alt,
		"climb_fast": climb_fast / alt,
		"climb_slow": climb_slow / alt,
		"valuable_degree": degree_total / maxf(seen, 1.0),
		"valuable_elev_pct": elevation_rank / maxf(seen, 1.0),
	}


static func describe(route: PackedInt32Array, elevations: PackedInt32Array) -> Dictionary:
	var climb := 0
	for index in range(1, route.size()):
		climb = maxi(climb, maxi(0, elevations[route[index]] - elevations[route[index - 1]]))
	return {"length": float(route.size() - 1), "climb": float(climb)}


static func _percentile(values: PackedInt32Array, value: int) -> float:
	var below := 0.0
	for other in values:
		if other < value:
			below += 1.0
	return 100.0 * below / maxf(float(values.size()), 1.0)


## 필요 민첩 = 경로 위 최대 상승폭의 최솟값 (docs/design/07-level-design.md §7.2.8).
static func required_agility(
	count: int, edges: Array[Vector2i], elevations: PackedInt32Array, start: int
) -> Dictionary:
	var neighbors := adjacency(count, edges)
	var best := {start: 0}
	var settled := {}
	while true:
		var current := -1
		var current_cost := -1
		for index in best:
			if settled.has(index):
				continue
			if current_cost < 0 or int(best[index]) < current_cost:
				current = int(index)
				current_cost = int(best[index])
		if current < 0:
			break
		settled[current] = true
		for neighbor in neighbors[current] as Array[int]:
			var cost := maxi(current_cost, maxi(0, elevations[neighbor] - elevations[current]))
			if not best.has(neighbor) or cost < int(best[neighbor]):
				best[neighbor] = cost
	return best


static func degrees_of(count: int, edges: Array[Vector2i]) -> Dictionary:
	var result := {}
	for index in count:
		result[index] = 0
	for edge in edges:
		result[edge.x] = int(result[edge.x]) + 1
		result[edge.y] = int(result[edge.y]) + 1
	return result


static func adjacency(count: int, edges: Array[Vector2i]) -> Dictionary:
	var result := {}
	for index in count:
		result[index] = [] as Array[int]
	for edge in edges:
		(result[edge.x] as Array[int]).append(edge.y)
		(result[edge.y] as Array[int]).append(edge.x)
	return result


static func depths(count: int, edges: Array[Vector2i], start: int) -> Dictionary:
	var neighbors := adjacency(count, edges)
	var result := {start: 0}
	var frontier: Array[int] = [start]
	while not frontier.is_empty():
		var current: int = frontier.pop_front()
		for neighbor in neighbors[current] as Array[int]:
			if result.has(neighbor):
				continue
			result[neighbor] = int(result[current]) + 1
			frontier.append(neighbor)
	return result


static func diameter(count: int, edges: Array[Vector2i]) -> int:
	var longest := 0
	for start in count:
		var found := depths(count, edges, start)
		for index in found:
			longest = maxi(longest, int(found[index]))
	return longest


static func path(count: int, edges: Array[Vector2i], start: int, target: int) -> PackedInt32Array:
	var neighbors := adjacency(count, edges)
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


static func on_path(route: PackedInt32Array, edge: Vector2i) -> bool:
	for index in range(1, route.size()):
		var a := route[index - 1]
		var b := route[index]
		if (edge.x == a and edge.y == b) or (edge.x == b and edge.y == a):
			return true
	return false


## 지금 생성기의 설계도를 공용 사전 모양으로 옮긴다.
static func from_blueprint(blueprint: DungeonBlueprint) -> Dictionary:
	var ids := blueprint.room_ids()
	var slot := {}
	for index in ids.size():
		slot[ids[index]] = index

	var points := PackedVector2Array()
	var elevations := PackedInt32Array()
	var kinds := {}
	for index in ids.size():
		points.append(blueprint.position_of(ids[index]))
		elevations.append(blueprint.elevation_of(ids[index]))
		kinds[index] = blueprint.kind_of(ids[index])

	var edges: Array[Vector2i] = []
	for pair in blueprint.connections():
		edges.append(Vector2i(int(slot[pair[0]]), int(slot[pair[1]])))

	var entrance := 0
	for index in ids.size():
		if blueprint.kind_of(ids[index]) == Room.Kind.ENTRANCE:
			entrance = index
			break

	return {
		"points": points,
		"edges": edges,
		"elevations": elevations,
		"kinds": kinds,
		"entrance": entrance,
		"zones": PackedInt32Array(),
		"fast": PackedInt32Array(),
		"slow": PackedInt32Array(),
	}
