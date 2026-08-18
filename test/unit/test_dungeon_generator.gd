extends GutTest
## 던전 생성기의 단위 테스트.
##
## 생성기는 무작위이므로 "이 판이 이렇게 나온다"를 검증할 수 없다.
## 대신 **여러 시드에 걸쳐 규칙이 항상 성립하는지**를 본다
## (docs/design/17-dungeon-generation.md §17.5).

const GeneratorScript := preload("res://src/core/dungeon/dungeon_generator.gd")

## 검사할 시드 수. 늘리면 촘촘해지지만 테스트가 느려진다.
const _SEEDS := 12


func _entrance_of(blueprint: DungeonBlueprint) -> String:
	return blueprint.rooms_of_kind(Room.Kind.ENTRANCE)[0]


func _valuables_of(blueprint: DungeonBlueprint) -> Array[String]:
	return blueprint.rooms_of_kind(Room.Kind.TREASURE) + blueprint.rooms_of_kind(Room.Kind.BOSS)


func _average_of(values: Dictionary, ids: Array[String]) -> float:
	var total := 0.0
	for id in ids:
		total += float(values.get(id, 0))
	return total / float(maxi(ids.size(), 1))


# ---------------------------------------------------------------- 재현성


func test_same_seed_gives_the_same_dungeon() -> void:
	# 시드가 고정되지 않으면 버그를 다시 볼 수 없고 밸런싱 비교도 불가능하다 (§17.7).
	var a: DungeonBlueprint = GeneratorScript.new(42).generate()
	var b: DungeonBlueprint = GeneratorScript.new(42).generate()
	assert_eq(a.room_ids(), b.room_ids())
	assert_eq(a.connections().size(), b.connections().size())
	for id in a.room_ids():
		assert_eq(a.elevation_of(id), b.elevation_of(id))
		assert_eq(a.kind_of(id), b.kind_of(id))
		assert_eq(a.display_name_of(id), b.display_name_of(id))


func test_different_seeds_give_different_dungeons() -> void:
	var a: DungeonBlueprint = GeneratorScript.new(1).generate()
	var b: DungeonBlueprint = GeneratorScript.new(2).generate()
	var same := a.connections().size() == b.connections().size()
	for id in a.room_ids():
		if not b.has_room(id) or a.elevation_of(id) != b.elevation_of(id):
			same = false
	assert_false(same, "서로 다른 시드가 같은 판을 만들었다")


# ---------------------------------------------------------------- 검증 규칙


func test_every_room_is_reachable() -> void:
	# V1 — 고립된 방은 존재하지 않는 것과 같다.
	for seed_value in _SEEDS:
		var blueprint: DungeonBlueprint = GeneratorScript.new(seed_value).generate()
		var costs := blueprint.build().required_agility_from(_entrance_of(blueprint))
		assert_eq(costs.size(), blueprint.room_ids().size(), "시드 %d 에 고립된 방이 있다" % seed_value)


func test_a_free_exit_always_exists() -> void:
	# V2 — 이게 깨지면 시작하자마자 진 판이다.
	for seed_value in _SEEDS:
		var blueprint: DungeonBlueprint = GeneratorScript.new(seed_value).generate()
		var costs := blueprint.build().required_agility_from(_entrance_of(blueprint))
		var exits := blueprint.rooms_of_kind(Room.Kind.EXIT)
		assert_gt(exits.size(), 0, "시드 %d 에 탈출구가 없다" % seed_value)
		var free_exits := 0
		for id in exits:
			if costs.get(id, 999) == 0:
				free_exits += 1
		assert_gt(free_exits, 0, "시드 %d 에 민첩 0 으로 닿는 탈출구가 없다" % seed_value)


func test_valuables_cost_more_than_the_free_exit() -> void:
	# V3 — 보상은 대가를 요구해야 한다.
	for seed_value in _SEEDS:
		var blueprint: DungeonBlueprint = GeneratorScript.new(seed_value).generate()
		var costs := blueprint.build().required_agility_from(_entrance_of(blueprint))
		for id in _valuables_of(blueprint):
			assert_gt(costs.get(id, 0), 0, "시드 %d 의 고가치 방이 공짜로 닿는다" % seed_value)


func test_valuables_cost_more_agility_than_an_ordinary_room() -> void:
	# 0 보다 크기만 해서는 부족하다. 평범한 방보다 비싸야 "값을 치렀다"가 성립한다.
	for seed_value in _SEEDS:
		var blueprint: DungeonBlueprint = GeneratorScript.new(seed_value).generate()
		var costs := blueprint.build().required_agility_from(_entrance_of(blueprint))
		var average := _average_of(costs, blueprint.room_ids())
		for id in _valuables_of(blueprint):
			assert_gt(
				float(costs.get(id, 0)), average, "시드 %d 의 고가치 방이 평범한 방보다 싸게 닿는다" % seed_value
			)


func test_the_exit_is_far_even_though_it_is_free() -> void:
	# 탈출구는 민첩 0 으로 닿아야 하므로(V2) 능력으로 막을 수 없다.
	# 대신 **거리로** 값을 받는다. 코앞에 있으면 "언제 나갈까"가 판단이 아니게 된다.
	for seed_value in _SEEDS:
		var blueprint: DungeonBlueprint = GeneratorScript.new(seed_value).generate()
		var graph := blueprint.build()
		var entrance := _entrance_of(blueprint)
		var hops := RoomKindPlanner.hops_from(graph, entrance)
		var average := _average_of(hops, blueprint.room_ids())
		for id in blueprint.rooms_of_kind(Room.Kind.EXIT):
			assert_gt(float(hops.get(id, 0)), average, "시드 %d 의 탈출구가 입구에서 가깝다" % seed_value)


func test_exactly_one_entrance() -> void:
	for seed_value in _SEEDS:
		var blueprint: DungeonBlueprint = GeneratorScript.new(seed_value).generate()
		assert_eq(blueprint.rooms_of_kind(Room.Kind.ENTRANCE).size(), 1)


func test_entrance_always_offers_a_choice() -> void:
	# V7 — 차수가 1 이면 첫 턴에 누를 수 있는 버튼이 하나뿐이라 게임이 시작되지 않는다.
	for seed_value in _SEEDS:
		var blueprint: DungeonBlueprint = GeneratorScript.new(seed_value).generate()
		var graph := blueprint.build()
		assert_gte(
			graph.neighbors_of(_entrance_of(blueprint)).size(),
			2,
			"시드 %d 의 입구에 갈림길이 없다" % seed_value
		)


func test_entrance_shows_a_number_to_read() -> void:
	# 0 도 정보이긴 하지만, 첫 화면부터 0 이면 이 게임이 뭘 하는 게임인지 안 드러난다.
	for seed_value in _SEEDS:
		var run := SampleDungeons.create_run(seed_value)
		assert_gt(run.adjacent_threat(), 0, "시드 %d 의 첫 화면에 읽을 숫자가 없다" % seed_value)


func test_a_boss_room_exists() -> void:
	for seed_value in _SEEDS:
		var blueprint: DungeonBlueprint = GeneratorScript.new(seed_value).generate()
		assert_gt(blueprint.rooms_of_kind(Room.Kind.BOSS).size(), 0)


# ---------------------------------------------------------------- 판의 성질


func test_elevation_actually_varies() -> void:
	# 고도가 전부 같으면 이 게임의 절반(메트로배니아 게이트)이 없는 것과 같다.
	for seed_value in _SEEDS:
		var blueprint: DungeonBlueprint = GeneratorScript.new(seed_value).generate()
		var lowest := 0
		var highest := 0
		for id in blueprint.room_ids():
			lowest = mini(lowest, blueprint.elevation_of(id))
			highest = maxi(highest, blueprint.elevation_of(id))
		assert_gt(highest - lowest, 0, "시드 %d 의 판이 평평하다" % seed_value)


func test_entrance_sits_at_the_bottom() -> void:
	# 입구가 꼭대기에 있으면 "내려갈수록 깊어진다"는 구도가 뒤집힌다.
	for seed_value in _SEEDS:
		var blueprint: DungeonBlueprint = GeneratorScript.new(seed_value).generate()
		var entrance := _entrance_of(blueprint)
		for id in blueprint.room_ids():
			assert_true(
				blueprint.elevation_of(entrance) <= blueprint.elevation_of(id),
				"시드 %d 에서 입구보다 낮은 방이 있다" % seed_value
			)


func test_dead_ends_exist_but_do_not_take_over() -> void:
	# V5 — 막다른 방은 앞방을 정확히 읽는 정찰 지점이라 없애지 않는다.
	# 대신 너무 많으면 정보가 다 새고 판이 나뭇가지처럼 보인다 (§17.2).
	for seed_value in _SEEDS:
		var blueprint: DungeonBlueprint = GeneratorScript.new(seed_value).generate()
		var graph := blueprint.build()
		var dead_ends := 0
		for id in blueprint.room_ids():
			if graph.is_dead_end(id):
				dead_ends += 1
		var ratio := float(dead_ends) / float(blueprint.room_ids().size())
		assert_between(ratio, 0.05, 0.35, "시드 %d 의 막다른 방 비율이 %.2f" % [seed_value, ratio])


func test_every_generated_room_gets_a_position() -> void:
	for seed_value in _SEEDS:
		var blueprint: DungeonBlueprint = GeneratorScript.new(seed_value).generate()
		var positions := blueprint.layout(seed_value)
		assert_eq(
			positions.size(), blueprint.room_ids().size(), "시드 %d 에 자리를 못 잡은 방이 있다" % seed_value
		)


func test_map_size_changes_room_count() -> void:
	# 슬라이더가 실제로 판 규모를 바꾸는지 본다.
	var small := SampleDungeons.create_run(11, SampleDungeons.SIZE_MIN)
	var large := SampleDungeons.create_run(11, SampleDungeons.SIZE_MAX)
	assert_gt(
		large.blueprint.room_ids().size(), small.blueprint.room_ids().size(), "맵 크기를 올렸는데 방이 늘지 않았다"
	)


func test_every_map_size_produces_a_playable_run() -> void:
	for size in range(SampleDungeons.SIZE_MIN, SampleDungeons.SIZE_MAX + 1):
		var run := SampleDungeons.create_run(size * 17, size)
		assert_gt(run.reachable_room_ids().size(), 0, "크기 %d 에서 갈 곳이 없다" % size)
		assert_gt(run.blueprint.rooms_of_kind(Room.Kind.EXIT).size(), 0)


func test_generated_run_is_playable() -> void:
	# 조립까지 포함해 실제로 굴러가는지 본다.
	for seed_value in _SEEDS:
		var run := SampleDungeons.create_run(seed_value)
		assert_false(run.player_room_id().is_empty(), "스쿼드가 판 위에 없다")
		assert_gt(run.reachable_room_ids().size(), 0, "시드 %d 에서 갈 곳이 없다" % seed_value)


func test_entrance_is_not_a_death_trap() -> void:
	# V4 — 판단할 기회도 없이 죽는 배치를 막는다.
	for seed_value in _SEEDS:
		var run := SampleDungeons.create_run(seed_value)
		assert_lte(
			run.adjacent_threat(),
			SampleDungeons.ENTRANCE_THREAT_MAX,
			"시드 %d 의 입구 인접 위험도가 상한을 넘었다" % seed_value
		)
