extends SceneTree
## 던전 성격 다섯이 **실제로 갈리는지**와 **보장이 살아 있는지**를 크기마다 잰다.
##
## 성격은 판이 달라 보이게 만드는 것이지 규칙을 깨는 것이 아니다. 그래서 V2 를 성격마다,
## 크기마다 확인한다 (docs/design/17-dungeon-generation.md §17.18).
##
##   godot --headless --path . -s res://tools/survey_dungeon_characters.gd

const Metrics := preload("res://tools/dungeon_metrics.gd")

const _RUNS := 24


func _initialize() -> void:
	print("== 던전 성격 다섯 (크기마다 %d 판) ==" % _RUNS)
	for size in range(SampleDungeons.SIZE_MIN, SampleDungeons.SIZE_MAX + 1):
		print("\n-- 크기 %d (칸 %d개 안팎) --" % [size, SampleDungeons.room_estimate(size)])
		print(
			(
				"%-12s %6s %6s %5s %5s %6s %6s %6s %6s %6s"
				% ["성격", "간선", "고리", "d1%", "지름", "민첩2%", "탈출홉", "귀중", "위험", "V2%"]
			)
		)
		for index in DungeonCatalog.count():
			_row(size, index)
	quit()


func _row(size: int, character: int) -> void:
	var totals := {}
	for key in ["edges", "cycles", "d1", "diam", "reach", "exit", "treasure", "hazard", "v2"]:
		totals[key] = 0.0

	for run in _RUNS:
		var params := SampleDungeons.params_for_size(size, character)
		var blueprint := DungeonGenerator.new(run * 7919 + size, params).generate()
		var board := Metrics.from_blueprint(blueprint)
		var measured := Metrics.measure(board)
		totals["edges"] += float(measured["edges"])
		totals["cycles"] += float(measured["cycles"])
		totals["d1"] += float(measured["deg1_pct"])
		totals["diam"] += float(measured["diameter"])
		totals["reach"] += float(measured["reach_pct"])
		totals["v2"] += float(measured["exit_free_pct"])
		totals["treasure"] += float(blueprint.rooms_of_kind(Room.Kind.TREASURE).size())
		totals["hazard"] += float(blueprint.rooms_of_kind(Room.Kind.HAZARD).size())
		totals["exit"] += _exit_hops(board, blueprint)

	var runs := float(_RUNS)
	print(
		(
			"%-12s %6.1f %6.1f %5.1f %5.1f %6.1f %6.1f %6.1f %6.1f %6.1f"
			% [
				DungeonCatalog.name_of(character),
				totals["edges"] / runs,
				totals["cycles"] / runs,
				totals["d1"] / runs,
				totals["diam"] / runs,
				totals["reach"] / runs,
				totals["exit"] / runs,
				totals["treasure"] / runs,
				totals["hazard"] / runs,
				totals["v2"] / runs,
			]
		)
	)


func _exit_hops(board: Dictionary, blueprint: DungeonBlueprint) -> float:
	var exits := blueprint.rooms_of_kind(Room.Kind.EXIT)
	if exits.is_empty():
		return 0.0
	var ids := blueprint.room_ids()
	var count: int = (board["points"] as PackedVector2Array).size()
	var hops := Metrics.depths(count, board["edges"], int(board["entrance"]))
	for index in ids.size():
		if ids[index] == exits[0]:
			return float(int(hops.get(index, 0)))
	return 0.0
