extends SceneTree
## 생성된 판의 **모양**을 재는 개발 도구. 속도는 bench_dungeon_generation.gd 가 잰다.
##
## 눈으로 보면 "그럴듯하다"까지밖에 말할 수 없다. 이 도구가 답하는 질문은 하나다 —
## **무엇이 시드마다 들쭉날쭉하고 무엇이 늘 똑같은가.**
## 늘 똑같은 값은 절차 생성이 아니라 상수이고, 상수는 판을 예측 가능하게 만든다
## (docs/design/17-dungeon-generation.md §17.11).
##
##   godot --headless --path . -s res://tools/survey_dungeon_generation.gd

## 크기마다 몇 판을 볼지. 표준편차를 믿으려면 30 으로는 모자란다.
const _RUNS := 60

## 스쿼드 기본 민첩. 이 값으로 판의 몇 %가 잠기는지 본다.
const _SQUAD_AGILITY := SampleDungeons.SQUAD_AGILITY

## 재는 항목. 순서대로 출력한다.
const _KEYS: Array[String] = [
	"rooms",
	"edges",
	"avg_degree",
	"deg1_pct",
	"deg2_pct",
	"deg3_pct",
	"deg4up_pct",
	"max_degree",
	"cycles",
	"bridge_pct",
	"diameter",
	"entrance_degree",
	"avg_deg_shallow",
	"avg_deg_deep",
	"max_elev",
	"elev0_pct",
	"climb_edge_pct",
	"max_climb",
	"req0_pct",
	"max_req",
	"reach_at_squad_pct",
	"boss_req",
	"boss_hops",
	"boss_is_max_req",
	"exit_hops",
	"max_hops",
	"treasure_n",
	"hazard_n",
	"valuable_clustered_pct",
	"entrance_threat",
	"total_threat",
	"threat_rooms_pct",
]


func _initialize() -> void:
	print("== 판 모양 실측 (크기마다 %d 판) ==" % _RUNS)
	for size in range(SampleDungeons.SIZE_MIN, SampleDungeons.SIZE_MAX + 1):
		_survey(size)
	quit()


func _survey(size: int) -> void:
	var samples := {}
	for key in _KEYS:
		samples[key] = [] as Array[float]

	for run in _RUNS:
		var measured := _measure(run * 7919 + size, size)
		for key in _KEYS:
			(samples[key] as Array[float]).append(float(measured.get(key, 0.0)))

	print("\n-- size %d (room_count=%d) --" % [size, SampleDungeons.room_estimate(size)])
	print("%-22s %8s %8s %8s %8s" % ["metric", "min", "avg", "max", "sd"])
	for key in _KEYS:
		var values: Array[float] = samples[key]
		print(
			(
				"%-22s %8.2f %8.2f %8.2f %8.2f"
				% [key, _lowest(values), _mean(values), _highest(values), _deviation(values)]
			)
		)


## 판 하나를 재서 항목 이름 -> 값 사전으로 돌려준다.
func _measure(seed_value: int, size: int) -> Dictionary:
	var run_state := SampleDungeons.create_run(seed_value, size)
	var blueprint := run_state.blueprint
	var graph := run_state.graph
	var ids := blueprint.room_ids()
	var entrance := _first_of_kind(blueprint, Room.Kind.ENTRANCE)
	var edges := blueprint.connections()

	var result := {}
	result["rooms"] = float(ids.size())
	result["edges"] = float(edges.size())
	result["cycles"] = float(edges.size() - ids.size() + 1)

	_fill_degrees(result, graph, ids)
	_fill_topology(result, graph, blueprint, ids, entrance, edges)
	_fill_elevation(result, graph, blueprint, ids, entrance, edges)
	_fill_kinds(result, graph, blueprint, ids, entrance)
	_fill_threat(result, graph, ids, entrance)
	return result


func _fill_degrees(result: Dictionary, graph: DungeonGraph, ids: Array[String]) -> void:
	var buckets := [0, 0, 0, 0]
	var total := 0
	var highest := 0
	for id in ids:
		var degree := graph.neighbors_of(id).size()
		total += degree
		highest = maxi(highest, degree)
		buckets[clampi(degree - 1, 0, 3)] += 1
	var count := maxf(float(ids.size()), 1.0)
	result["avg_degree"] = float(total) / count
	result["deg1_pct"] = 100.0 * float(buckets[0]) / count
	result["deg2_pct"] = 100.0 * float(buckets[1]) / count
	result["deg3_pct"] = 100.0 * float(buckets[2]) / count
	result["deg4up_pct"] = 100.0 * float(buckets[3]) / count
	result["max_degree"] = float(highest)


## 지름 · 다리 비율 · 깊이대별 차수. "입구 근처는 촘촘하고 깊은 곳은 성기다"(§17.3.5)가
## 실제로 나타나는지 보는 것이 avg_deg_shallow / avg_deg_deep 이다.
func _fill_topology(
	result: Dictionary,
	graph: DungeonGraph,
	blueprint: DungeonBlueprint,
	ids: Array[String],
	entrance: String,
	edges: Array[Array]
) -> void:
	var hops := RoomKindPlanner.hops_from(graph, entrance)
	var deepest := 0
	for id in hops:
		deepest = maxi(deepest, int(hops[id]))
	result["max_hops"] = float(deepest)
	result["entrance_degree"] = float(graph.neighbors_of(entrance).size())

	var diameter := 0
	for id in ids:
		var far := RoomKindPlanner.hops_from(graph, id)
		for other in far:
			diameter = maxi(diameter, int(far[other]))
	result["diameter"] = float(diameter)

	var shallow_total := 0
	var shallow_count := 0
	var deep_total := 0
	var deep_count := 0
	for id in ids:
		var depth := int(hops.get(id, 0))
		var degree := graph.neighbors_of(id).size()
		if depth * 3 <= deepest:
			shallow_total += degree
			shallow_count += 1
		elif depth * 3 >= deepest * 2:
			deep_total += degree
			deep_count += 1
	result["avg_deg_shallow"] = float(shallow_total) / maxf(float(shallow_count), 1.0)
	result["avg_deg_deep"] = float(deep_total) / maxf(float(deep_count), 1.0)

	result["bridge_pct"] = 100.0 * float(_bridges(ids, edges)) / maxf(float(edges.size()), 1.0)
	# blueprint 은 여기서 좌표 확인용으로만 쓴다.
	if blueprint.position_of(entrance) == DungeonBlueprint.NO_POSITION:
		push_error("생성된 판에 좌표가 없습니다")


## 끊으면 판이 두 조각 나는 간선의 개수. 다리가 많을수록 판이 나무에 가깝다.
func _bridges(ids: Array[String], edges: Array[Array]) -> int:
	var count := 0
	for skipped in edges.size():
		if not _connected_without(ids, edges, skipped):
			count += 1
	return count


func _connected_without(ids: Array[String], edges: Array[Array], skipped: int) -> bool:
	var neighbors := {}
	for id in ids:
		neighbors[id] = [] as Array[String]
	for index in edges.size():
		if index == skipped:
			continue
		var pair: Array = edges[index]
		(neighbors[pair[0]] as Array[String]).append(pair[1])
		(neighbors[pair[1]] as Array[String]).append(pair[0])

	var seen := {ids[0]: true}
	var frontier: Array[String] = [ids[0]]
	while not frontier.is_empty():
		var current: String = frontier.pop_front()
		for neighbor in neighbors[current] as Array[String]:
			if seen.has(neighbor):
				continue
			seen[neighbor] = true
			frontier.append(neighbor)
	return seen.size() == ids.size()


func _fill_elevation(
	result: Dictionary,
	graph: DungeonGraph,
	blueprint: DungeonBlueprint,
	ids: Array[String],
	entrance: String,
	edges: Array[Array]
) -> void:
	var highest := 0
	var flat := 0
	for id in ids:
		highest = maxi(highest, blueprint.elevation_of(id))
		if blueprint.elevation_of(id) == 0:
			flat += 1
	result["max_elev"] = float(highest)
	result["elev0_pct"] = 100.0 * float(flat) / maxf(float(ids.size()), 1.0)

	var climbing := 0
	var steepest := 0
	for pair in edges:
		var gap: int = absi(blueprint.elevation_of(pair[0]) - blueprint.elevation_of(pair[1]))
		if gap > 0:
			climbing += 1
		steepest = maxi(steepest, gap)
	result["climb_edge_pct"] = 100.0 * float(climbing) / maxf(float(edges.size()), 1.0)
	result["max_climb"] = float(steepest)

	var costs := graph.required_agility_from(entrance)
	var free := 0
	var reachable := 0
	var hardest := 0
	for id in ids:
		var cost := int(costs.get(id, 999))
		hardest = maxi(hardest, cost if cost < 999 else 0)
		if cost <= 0:
			free += 1
		if cost <= _SQUAD_AGILITY:
			reachable += 1
	var count := maxf(float(ids.size()), 1.0)
	result["req0_pct"] = 100.0 * float(free) / count
	result["max_req"] = float(hardest)
	result["reach_at_squad_pct"] = 100.0 * float(reachable) / count


func _fill_kinds(
	result: Dictionary,
	graph: DungeonGraph,
	blueprint: DungeonBlueprint,
	ids: Array[String],
	entrance: String
) -> void:
	var costs := graph.required_agility_from(entrance)
	var hops := RoomKindPlanner.hops_from(graph, entrance)
	var boss := _first_of_kind(blueprint, Room.Kind.BOSS)
	var exit_id := _first_of_kind(blueprint, Room.Kind.EXIT)
	var treasures := blueprint.rooms_of_kind(Room.Kind.TREASURE)

	result["boss_req"] = float(int(costs.get(boss, 0)))
	result["boss_hops"] = float(int(hops.get(boss, 0)))
	result["exit_hops"] = float(int(hops.get(exit_id, 0)))
	result["treasure_n"] = float(treasures.size())
	result["hazard_n"] = float(blueprint.rooms_of_kind(Room.Kind.HAZARD).size())

	var hardest := 0
	for id in ids:
		hardest = maxi(hardest, int(costs.get(id, 0)))
	var boss_cost := int(costs.get(boss, -1))
	result["boss_is_max_req"] = 100.0 if boss_cost == hardest else 0.0

	# 귀중품·보스가 서로 붙어 있는 비율. 뭉치면 판의 절반이 갈 이유 없는 곳이 된다.
	var valuables: Array[String] = treasures.duplicate()
	if not boss.is_empty():
		valuables.append(boss)
	var clustered := 0
	for id in valuables:
		for neighbor in graph.neighbors_of(id):
			if valuables.has(neighbor):
				clustered += 1
				break
	result["valuable_clustered_pct"] = 100.0 * float(clustered) / maxf(float(valuables.size()), 1.0)


func _fill_threat(
	result: Dictionary, graph: DungeonGraph, ids: Array[String], entrance: String
) -> void:
	var total := 0
	var occupied := 0
	for id in ids:
		var threat := graph.threat_at(id)
		total += threat
		if threat > 0:
			occupied += 1
	result["entrance_threat"] = float(graph.adjacent_threat(entrance))
	result["total_threat"] = float(total)
	result["threat_rooms_pct"] = 100.0 * float(occupied) / maxf(float(ids.size()), 1.0)


func _first_of_kind(blueprint: DungeonBlueprint, kind: Room.Kind) -> String:
	var found := blueprint.rooms_of_kind(kind)
	return found[0] if not found.is_empty() else ""


func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())


func _deviation(values: Array[float]) -> float:
	if values.size() < 2:
		return 0.0
	var average := _mean(values)
	var total := 0.0
	for value in values:
		total += (value - average) * (value - average)
	return sqrt(total / float(values.size()))


func _lowest(values: Array[float]) -> float:
	var result := INF
	for value in values:
		result = minf(result, value)
	return result if result < INF else 0.0


func _highest(values: Array[float]) -> float:
	var result := -INF
	for value in values:
		result = maxf(result, value)
	return result if result > -INF else 0.0
