extends SceneTree
## 설계안 프로토타입을 **지금 생성기와 같은 잣대로** 잰다.
##
## survey_dungeon_generation.gd / survey_dungeon_routes.gd 가 지금 생성기에 대해 재는 것과
## 같은 항목이다. 그래야 표 하나에 나란히 놓을 수 있다
## (docs/design/17-dungeon-generation.md §17.12.5).
##
##   godot --headless --path . -s res://tools/survey_proto_dungeon.gd

const Proto := preload("res://tools/proto_organic_dungeon.gd")

const _RUNS := 60

## 스쿼드 기본 민첩. 판의 몇 %가 이 값으로 열리는지 본다.
## **숫자를 다시 적지 않는다** — 게임 쪽이 바뀌면 이 도구만 옛 값으로 조용히 재게 된다 (§6.5).
const _SQUAD_AGILITY := SampleDungeons.SQUAD_AGILITY


func _initialize() -> void:
	print("== 설계안 프로토타입 실측 (크기마다 %d 판) ==" % _RUNS)
	print(
		(
			"%-5s %6s %6s %6s %6s %6s %6s %6s %6s %6s %6s"
			% [
				"size",
				"rooms",
				"edges",
				"cycle",
				"deg",
				"d1%",
				"d2%",
				"d3+%",
				"diam",
				"reach%",
				"valEl%"
			]
		)
	)
	for size in range(SampleDungeons.SIZE_MIN, SampleDungeons.SIZE_MAX + 1):
		_shape(size)

	print("")
	print("== 귀중 방 경로 ==")
	print(
		(
			"%-5s %7s %7s %7s %7s %7s %7s %7s %7s %7s"
			% [
				"size",
				"alt%",
				"len1",
				"len2",
				"climb1",
				"climb2",
				"thr1",
				"thr2",
				"domin%",
				"bossAlt%"
			]
		)
	)
	for size in range(SampleDungeons.SIZE_MIN, SampleDungeons.SIZE_MAX + 1):
		_routes(size)
	print("")
	print("thr 은 방 종류를 위험도로 환산한 값이다 (보스 6 · 위험 6 · 귀중 4 · 그 외 0).")
	print("프로토타입에는 아직 존재 배치가 없어서 SampleDungeons 와 같은 수를 쓸 수 없다.")
	quit()


func _shape(size: int) -> void:
	var totals := {}
	for key in ["rooms", "edges", "cycle", "deg", "d1", "d2", "d3", "diam", "reach", "valel"]:
		totals[key] = 0.0

	for run in _RUNS:
		var board := Proto.build(run * 7919 + size, SampleDungeons.room_estimate(size))
		if board.is_empty():
			continue
		var count: int = (board["points"] as PackedVector2Array).size()
		var edges: Array[Vector2i] = board["edges"]
		var degrees := _degrees(count, edges)

		totals["rooms"] += float(count)
		totals["edges"] += float(edges.size())
		totals["cycle"] += float(edges.size() - count + 1)
		var deg1 := 0.0
		var deg2 := 0.0
		var deg3 := 0.0
		var sum := 0.0
		for index in count:
			var degree := int(degrees.get(index, 0))
			sum += float(degree)
			if degree <= 1:
				deg1 += 1.0
			elif degree == 2:
				deg2 += 1.0
			else:
				deg3 += 1.0
		totals["deg"] += sum / float(count)
		totals["d1"] += 100.0 * deg1 / float(count)
		totals["d2"] += 100.0 * deg2 / float(count)
		totals["d3"] += 100.0 * deg3 / float(count)
		totals["diam"] += float(_diameter(count, edges))
		totals["reach"] += _reach_percent(board)
		totals["valel"] += _valuable_elevation_percentile(board)

	var runs := float(_RUNS)
	print(
		(
			"%-5d %6.1f %6.1f %6.1f %6.2f %6.1f %6.1f %6.1f %6.1f %6.1f %6.1f"
			% [
				size,
				totals["rooms"] / runs,
				totals["edges"] / runs,
				totals["cycle"] / runs,
				totals["deg"] / runs,
				totals["d1"] / runs,
				totals["d2"] / runs,
				totals["d3"] / runs,
				totals["diam"] / runs,
				totals["reach"] / runs,
				totals["valel"] / runs,
			]
		)
	)


func _routes(size: int) -> void:
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
		"boss": 0.0,
		"boss_alt": 0.0,
	}
	for run in _RUNS:
		var board := Proto.build(run * 7919 + size, SampleDungeons.room_estimate(size))
		if board.is_empty():
			continue
		_accumulate(totals, board)

	var alt := maxf(totals["with_alt"], 1.0)
	print(
		(
			"%-5d %7.1f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.1f %7.1f"
			% [
				size,
				100.0 * totals["with_alt"] / maxf(totals["valuables"], 1.0),
				totals["len1"] / alt,
				totals["len2"] / alt,
				totals["climb1"] / alt,
				totals["climb2"] / alt,
				totals["threat1"] / alt,
				totals["threat2"] / alt,
				100.0 * totals["dominated"] / alt,
				100.0 * totals["boss_alt"] / maxf(totals["boss"], 1.0),
			]
		)
	)


func _accumulate(totals: Dictionary, board: Dictionary) -> void:
	var count: int = (board["points"] as PackedVector2Array).size()
	var edges: Array[Vector2i] = board["edges"]
	var elevations: PackedInt32Array = board["elevations"]
	var kinds: Dictionary = board["kinds"]
	var entrance: int = board["entrance"]

	for index in count:
		var kind: Room.Kind = kinds.get(index, Room.Kind.EMPTY)
		if kind != Room.Kind.TREASURE and kind != Room.Kind.BOSS:
			continue
		totals["valuables"] += 1.0
		if kind == Room.Kind.BOSS:
			totals["boss"] = totals.get("boss", 0.0) + 1.0
		var primary := _path(count, edges, entrance, index)
		if primary.size() < 2:
			continue
		var reduced: Array[Vector2i] = []
		for edge in edges:
			if not _on_path(primary, edge):
				reduced.append(edge)
		var alternative := _path(count, reduced, entrance, index)
		if alternative.size() < 2:
			continue

		totals["with_alt"] += 1.0
		if kind == Room.Kind.BOSS:
			totals["boss_alt"] = totals.get("boss_alt", 0.0) + 1.0
		var a := _describe(primary, elevations, kinds)
		var b := _describe(alternative, elevations, kinds)
		totals["len1"] += a["length"]
		totals["len2"] += b["length"]
		totals["climb1"] += a["climb"]
		totals["climb2"] += b["climb"]
		totals["threat1"] += a["threat"]
		totals["threat2"] += b["threat"]
		if a["climb"] <= b["climb"] and a["threat"] <= b["threat"]:
			totals["dominated"] += 1.0


## 방 종류를 위험도로 환산한다. 프로토타입에는 존재 배치가 없어서 종류로 대신한다.
func _threat_of(kind: Room.Kind) -> float:
	match kind:
		Room.Kind.BOSS:
			return 6.0
		Room.Kind.HAZARD:
			return 6.0
		Room.Kind.TREASURE:
			return 4.0
		_:
			return 0.0


func _describe(
	path: PackedInt32Array, elevations: PackedInt32Array, kinds: Dictionary
) -> Dictionary:
	var climb := 0
	var threat := 0.0
	for index in range(1, path.size()):
		climb = maxi(climb, maxi(0, elevations[path[index]] - elevations[path[index - 1]]))
		if index < path.size() - 1:
			threat += _threat_of(kinds.get(path[index], Room.Kind.EMPTY))
	return {"length": float(path.size() - 1), "climb": float(climb), "threat": threat}


## 기본 민첩으로 닿는 방의 비율. 필요 민첩은 경로 위 최대 상승폭의 최솟값이다.
func _reach_percent(board: Dictionary) -> float:
	var count: int = (board["points"] as PackedVector2Array).size()
	var edges: Array[Vector2i] = board["edges"]
	var elevations: PackedInt32Array = board["elevations"]
	var neighbors := _adjacency(count, edges)

	var best := {int(board["entrance"]): 0}
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
			var climb := maxi(0, elevations[neighbor] - elevations[current])
			var cost := maxi(current_cost, climb)
			if not best.has(neighbor) or cost < int(best[neighbor]):
				best[neighbor] = cost

	var open := 0
	for index in best:
		if int(best[index]) <= _SQUAD_AGILITY:
			open += 1
	return 100.0 * float(open) / float(count)


func _valuable_elevation_percentile(board: Dictionary) -> float:
	var elevations: PackedInt32Array = board["elevations"]
	var kinds: Dictionary = board["kinds"]
	var total := 0.0
	var seen := 0.0
	for index in elevations.size():
		var kind: Room.Kind = kinds.get(index, Room.Kind.EMPTY)
		if kind != Room.Kind.TREASURE and kind != Room.Kind.BOSS:
			continue
		var below := 0.0
		for other in elevations:
			if other < elevations[index]:
				below += 1.0
		total += 100.0 * below / float(elevations.size())
		seen += 1.0
	return total / maxf(seen, 1.0)


func _diameter(count: int, edges: Array[Vector2i]) -> int:
	var longest := 0
	for start in count:
		var depths := _depths(count, edges, start)
		for index in depths:
			longest = maxi(longest, int(depths[index]))
	return longest


func _degrees(count: int, edges: Array[Vector2i]) -> Dictionary:
	var result := {}
	for index in count:
		result[index] = 0
	for edge in edges:
		result[edge.x] = int(result[edge.x]) + 1
		result[edge.y] = int(result[edge.y]) + 1
	return result


func _adjacency(count: int, edges: Array[Vector2i]) -> Dictionary:
	var result := {}
	for index in count:
		result[index] = [] as Array[int]
	for edge in edges:
		(result[edge.x] as Array[int]).append(edge.y)
		(result[edge.y] as Array[int]).append(edge.x)
	return result


func _depths(count: int, edges: Array[Vector2i], start: int) -> Dictionary:
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


func _path(count: int, edges: Array[Vector2i], start: int, target: int) -> PackedInt32Array:
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


func _on_path(path: PackedInt32Array, edge: Vector2i) -> bool:
	for index in range(1, path.size()):
		var a := path[index - 1]
		var b := path[index]
		if (edge.x == a and edge.y == b) or (edge.x == b and edge.y == a):
			return true
	return false
