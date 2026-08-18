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
##
## `agility` 는 **누구를 기준으로 「열린 방」을 세는가**다. 예전에는 2 가 이 안에
## 박혀 있었는데, 그러면 어느 스쿼드를 잰 값인지가 자 안에 숨는다 — 편성이 붙으면
## 민첩은 대원 평균이라 1 도 나올 수 있고, 민첩 한 칸이 판을 20~49%p 닫는다
## (`design/17-dungeon-generation.md` §17.38.2 · §17.38.3).
## **기본값은 게임의 자리값 하나를 가리킨다.** 여기 숫자를 다시 적지 않는다 (§6.5).
static func measure(board: Dictionary, agility: int = SampleDungeons.SQUAD_AGILITY) -> Dictionary:
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
		if int(costs[index]) <= agility:
			open += 1

	var exit_free := 0.0
	for index in count:
		if kinds.get(index, Room.Kind.EMPTY) == Room.Kind.EXIT:
			exit_free = 100.0 if int(costs.get(index, 99)) == 0 else 0.0
			break

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
		# **누구 기준인지를 값 옆에 붙여 낸다.** 표에 `reach_pct` 만 적히면 다음 사람이
		# 어느 민첩의 값인지 알 수 없고, 그 표는 §6.3 규칙 4 를 어긴 것이 된다.
		"reach_agility": float(agility),
		"exit_free_pct": exit_free,
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
	var boss_degree := 0.0
	var treasure_degree := 0.0
	var treasure_seen := 0.0
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
		# **P3(노출된 보상)과 P4(막다른 보물)는 서로 반대다.** 한 평균으로 재면 둘 다
		# 실패로 보인다. 보스는 차수가 높아야 하고 부차 귀중품은 1 이어야 한다.
		if kind == Room.Kind.BOSS:
			boss_degree += float(int(degrees.get(index, 0)))
		else:
			treasure_degree += float(int(degrees.get(index, 0)))
			treasure_seen += 1.0
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
		"boss_degree": boss_degree / maxf(boss_seen, 1.0),
		"treasure_degree": treasure_degree / maxf(treasure_seen, 1.0),
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


## **막다른 방 판정은 `DungeonGraph.is_dead_end()` 와 같은 것을 말해야 한다** (차수 <= 1).
##
## 여기서 그 함수를 부르지 않는 이유는 이 자가 **색인 기반 판**도 재기 때문이다 —
## 설계안 프로토타입에는 `DungeonGraph` 가 없다. 그래서 `measure()` 의 `deg1_pct` 는
## 같은 판정을 색인 위에서 한 번 더 구현한 것이다.
##
## **둘이 같은 수를 내는지는 테스트가 묶는다** (`test_dead_end_definition.gd`).
## 200 판에서 어긋난 적이 없지만, 그건 지금 그렇다는 것이지 앞으로도 그렇다는 뜻이 아니다.
static func degrees_of(count: int, edges: Array[Vector2i]) -> Dictionary:
	var result := {}
	for index in count:
		result[index] = 0
	for edge in edges:
		result[edge.x] = int(result[edge.x]) + 1
		result[edge.y] = int(result[edge.y]) + 1
	return result


## 인접 목록. **범위 밖 간선은 조용히 넘기지 않고 시끄럽게 실패한다.**
##
## 한 번 여기서 "Invalid cast" 가 났는데 GDScript 가 그 호출만 건너뛰고 계속 돌아서
## 지표가 틀린 값으로 계산됐다. 그 뒤 실행에서는 재현되지 않았다(스크립트 캐시로 짐작한다).
## **소리 없이 틀린 수를 내놓는 것이 가장 비싸다.** 그래서 원인을 남기는 검사를 둔다.
static func adjacency(count: int, edges: Array[Vector2i]) -> Dictionary:
	var result := {}
	for index in count:
		result[index] = [] as Array[int]
	for edge in edges:
		if edge.x < 0 or edge.y < 0 or edge.x >= count or edge.y >= count:
			push_error("방 범위를 벗어난 간선입니다: %s (방 %d개)" % [edge, count])
			continue
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


## 그 간선이 길 위에 놓여 있는가.
##
## **런타임 판정을 그대로 쓴다.** 예전에는 여기에 같은 코드가 한 벌 더 있었는데,
## 갈리면 화면이 그리는 두 길과 이 자가 재는 두 길이 달라진다.
## 도구가 `src/` 를 부르는 것은 허용된 방향이다 (`docs/conventions.md` §3.1).
static func on_path(route: PackedInt32Array, edge: Vector2i) -> bool:
	return DungeonRouteBuilder.on_path(route, edge)


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
