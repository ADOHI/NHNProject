extends SceneTree
## **경로가 선택이 되는가**를 재는 개발 도구.
##
## survey_dungeon_generation.gd 가 판 전체의 모양을 잰다면 여기는 한 가지만 본다 —
## 귀중한 방까지 가는 길이 **둘 이상 있는가, 그리고 그 둘의 성격이 다른가.**
##
## 길이만 다른 두 경로는 선택이 아니다. 짧은 쪽이 더 안전하고 더 완만하기까지 하면
## 긴 쪽은 존재하지 않는 것과 같다. 그것을 dominated 로 센다
## (docs/design/17-dungeon-generation.md §17.11.6).
##
##   godot --headless --path . -s res://tools/survey_dungeon_routes.gd

const _RUNS := 60


func _initialize() -> void:
	print("== 귀중 방 경로 실측 (크기마다 %d 판) ==" % _RUNS)
	print(
		(
			"%-6s %7s %7s %7s %7s %7s %7s %7s %7s"
			% ["size", "alt%", "len1", "len2", "climb1", "climb2", "thr1", "thr2", "domin%"]
		)
	)
	for size in range(SampleDungeons.SIZE_MIN, SampleDungeons.SIZE_MAX + 1):
		_survey(size)
	print("")
	print("alt%%   : 대안 경로(간선 서로 겹치지 않음)가 있는 귀중 방의 비율")
	print("len/climb/thr : 1=최단 경로, 2=대안 경로. climb 은 경로 위 최대 상승폭")
	print("domin%%: 대안이 있는데 최단 경로가 길이·상승·위험 전부에서 낫거나 같은 비율")
	print("        (= 대안을 고를 이유가 없는 판. 선택이 아니다)")
	print("")
	_survey_elevation()
	quit()


func _survey(size: int) -> void:
	var totals := {
		"valuables": 0.0,
		"with_alt": 0.0,
		"len1": 0.0,
		"len2": 0.0,
		"climb1": 0.0,
		"climb2": 0.0,
		"threat1": 0.0,
		"threat2": 0.0,
		"dominated": 0.0,
	}
	for run in _RUNS:
		_accumulate(totals, run * 7919 + size, size)

	var alt := maxf(totals["with_alt"], 1.0)
	var all := maxf(totals["valuables"], 1.0)
	print(
		(
			"%-6d %7.1f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.1f"
			% [
				size,
				100.0 * totals["with_alt"] / all,
				totals["len1"] / alt,
				totals["len2"] / alt,
				totals["climb1"] / alt,
				totals["climb2"] / alt,
				totals["threat1"] / alt,
				totals["threat2"] / alt,
				100.0 * totals["dominated"] / alt,
			]
		)
	)


func _accumulate(totals: Dictionary, seed_value: int, size: int) -> void:
	var run_state := SampleDungeons.create_run(seed_value, size)
	var blueprint := run_state.blueprint
	var graph := run_state.graph
	var entrance := _first_of_kind(blueprint, Room.Kind.ENTRANCE)
	var adjacency := _adjacency(blueprint)

	var valuables: Array[String] = blueprint.rooms_of_kind(Room.Kind.TREASURE)
	valuables.append_array(blueprint.rooms_of_kind(Room.Kind.BOSS))

	for target in valuables:
		totals["valuables"] += 1.0
		var primary := _shortest(adjacency, entrance, target)
		if primary.is_empty():
			continue
		var reduced := _without_edges(adjacency, primary)
		var alternative := _shortest(reduced, entrance, target)
		if alternative.is_empty():
			continue

		totals["with_alt"] += 1.0
		var a := _describe(graph, primary)
		var b := _describe(graph, alternative)
		totals["len1"] += a["length"]
		totals["len2"] += b["length"]
		totals["climb1"] += a["climb"]
		totals["climb2"] += b["climb"]
		totals["threat1"] += a["threat"]
		totals["threat2"] += b["threat"]
		if a["climb"] <= b["climb"] and a["threat"] <= b["threat"]:
			# 최단 경로가 세 축 모두에서 뒤지지 않는다. 대안을 고를 이유가 없다.
			totals["dominated"] += 1.0


## 고도와 방 종류가 상관이 있는가. "귀중한 방은 고도가 높다"가 성립하는지 본다.
func _survey_elevation() -> void:
	print("== 고도와 방 종류 (크기마다 %d 판) ==" % _RUNS)
	print(
		(
			"%-6s %9s %9s %9s %9s %9s"
			% ["size", "elev_all", "elev_val", "val_pct", "val_dead%", "exit_elev"]
		)
	)
	for size in range(SampleDungeons.SIZE_MIN, SampleDungeons.SIZE_MAX + 1):
		var all_total := 0.0
		var all_count := 0.0
		var value_total := 0.0
		var value_count := 0.0
		var rank_total := 0.0
		var dead := 0.0
		var exit_total := 0.0

		for run in _RUNS:
			var run_state := SampleDungeons.create_run(run * 7919 + size, size)
			var blueprint := run_state.blueprint
			var graph := run_state.graph
			var elevations: Array[float] = []
			for id in blueprint.room_ids():
				elevations.append(float(blueprint.elevation_of(id)))
				all_total += float(blueprint.elevation_of(id))
				all_count += 1.0

			var valuables: Array[String] = blueprint.rooms_of_kind(Room.Kind.TREASURE)
			valuables.append_array(blueprint.rooms_of_kind(Room.Kind.BOSS))
			for id in valuables:
				var height := float(blueprint.elevation_of(id))
				value_total += height
				value_count += 1.0
				rank_total += _percentile(elevations, height)
				if graph.is_dead_end(id):
					dead += 1.0
			exit_total += float(blueprint.elevation_of(_first_of_kind(blueprint, Room.Kind.EXIT)))

		print(
			(
				"%-6d %9.2f %9.2f %9.1f %9.1f %9.2f"
				% [
					size,
					all_total / maxf(all_count, 1.0),
					value_total / maxf(value_count, 1.0),
					rank_total / maxf(value_count, 1.0),
					100.0 * dead / maxf(value_count, 1.0),
					exit_total / float(_RUNS),
				]
			)
		)
	print("")
	print("val_pct  : 귀중 방 고도의 판 안 백분위 (50 이면 평범한 높이라는 뜻)")
	print("val_dead%%: 귀중 방이 막다른 방인 비율")


## 값이 배열 안에서 몇 백분위인가.
func _percentile(values: Array[float], value: float) -> float:
	var below := 0.0
	for other in values:
		if other < value:
			below += 1.0
	return 100.0 * below / maxf(float(values.size()), 1.0)


## 경로의 길이 · 최대 상승폭 · 지나는 방들의 위험도 합.
func _describe(graph: DungeonGraph, path: Array[String]) -> Dictionary:
	var climb := 0
	var threat := 0
	for index in range(1, path.size()):
		climb = maxi(climb, graph.climb_between(path[index - 1], path[index]))
		if index < path.size() - 1:
			threat += graph.threat_at(path[index])
	return {"length": float(path.size() - 1), "climb": float(climb), "threat": float(threat)}


func _adjacency(blueprint: DungeonBlueprint) -> Dictionary:
	var result := {}
	for id in blueprint.room_ids():
		result[id] = [] as Array[String]
	for pair in blueprint.connections():
		(result[pair[0]] as Array[String]).append(pair[1])
		(result[pair[1]] as Array[String]).append(pair[0])
	return result


## 경로 위의 간선을 전부 뺀 인접 목록. 간선이 겹치지 않는 두 번째 경로를 찾기 위한 것이다.
func _without_edges(adjacency: Dictionary, path: Array[String]) -> Dictionary:
	var result := {}
	for id in adjacency:
		result[id] = (adjacency[id] as Array[String]).duplicate()
	for index in range(1, path.size()):
		var a: String = path[index - 1]
		var b: String = path[index]
		(result[a] as Array[String]).erase(b)
		(result[b] as Array[String]).erase(a)
	return result


func _shortest(adjacency: Dictionary, start: String, target: String) -> Array[String]:
	if start.is_empty() or target.is_empty() or start == target:
		return [] as Array[String]
	var parent := {start: ""}
	var frontier: Array[String] = [start]
	while not frontier.is_empty():
		var current: String = frontier.pop_front()
		if current == target:
			break
		for neighbor in adjacency.get(current, [] as Array[String]) as Array[String]:
			if parent.has(neighbor):
				continue
			parent[neighbor] = current
			frontier.append(neighbor)
	if not parent.has(target):
		return [] as Array[String]

	var reversed: Array[String] = []
	var walk := target
	while not walk.is_empty():
		reversed.append(walk)
		walk = parent[walk]
	reversed.reverse()
	return reversed


func _first_of_kind(blueprint: DungeonBlueprint, kind: Room.Kind) -> String:
	var found := blueprint.rooms_of_kind(kind)
	return found[0] if not found.is_empty() else ""
