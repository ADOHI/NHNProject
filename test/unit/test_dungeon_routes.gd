extends GutTest
## 보스까지 두 길(지름길 • 우회로)의 단위 테스트.
##
## 이 값은 **화면이 험난 축을 판정하는 근거**다. 화면이 「갈린다」고 했는데 판이 안 갈렸으면
## 그 표시는 없는 것만 못하다 (docs/design/17-dungeon-generation.md §17.27).
##
## | 성질 | 왜 |
## | --- | --- |
## | 지름길이 최단이다 | 더 짧은 길이 있는데 우회로라고 부르면 화면이 거짓말한다 |
## | 두 길이 간선을 안 나눈다 | 같은 통로를 두 번 세면 「두 길」이 아니라 한 길이다 |
## | 오름은 합이 아니라 최댓값 | 막는 것은 총량이 아니라 가장 높은 한 단이다 (§7.2.8) |
## | 내려가는 것은 0 | 내려가기는 언제나 자유다 (§7.2.6) |
## | 없는 것은 빈 것으로 | 보스 없음과 우회로 없음이 구분되어야 화면이 다르게 말한다 |
## | **계측기와 같은 수** | 같은 계산이 두 곳에 있다. 갈리면 조용히 틀린 수가 나온다 (§17.27.3) |

const RoutesScript := preload("res://src/core/dungeon/dungeon_routes.gd")
const MetricsScript := preload("res://tools/dungeon_metrics.gd")
const GeneratorScript := preload("res://src/core/dungeon/dungeon_generator.gd")

const _SEEDS := 6


## 두 갈래가 분명한 손판.
##
##       b(0) -- c(3)
##      /             \
##   a(0)              d(3) 보스
##      \             /
##       e(1) - f(1) - g(2)
##
## 지름길 a-b-c-d 는 3 칸에 한 번에 3 을 오르고,
## 우회로 a-e-f-g-d 는 4 칸이지만 한 걸음에 1 씩만 오른다.
func _forked_board() -> DungeonBlueprint:
	var plan := DungeonBlueprint.new()
	plan.add_room("a", "입구", 0, Room.Kind.ENTRANCE)
	plan.add_room("b", "b", 0)
	plan.add_room("c", "c", 3)
	plan.add_room("d", "제단", 3, Room.Kind.BOSS)
	plan.add_room("e", "e", 1)
	plan.add_room("f", "f", 1)
	plan.add_room("g", "g", 2)
	plan.connect_rooms("a", "b")
	plan.connect_rooms("b", "c")
	plan.connect_rooms("c", "d")
	plan.connect_rooms("a", "e")
	plan.connect_rooms("e", "f")
	plan.connect_rooms("f", "g")
	plan.connect_rooms("g", "d")
	return plan


func test_the_shortcut_is_the_shorter_and_steeper_way() -> void:
	var routes := RoutesScript.to_boss(_forked_board())
	assert_eq(routes["boss"], "d", "보스를 못 찾았다")
	assert_eq(routes["entrance"], "a", "입구를 못 찾았다")
	assert_eq(routes["shortcut"], ["a", "b", "c", "d"], "지름길이 최단이 아니다")
	assert_eq(routes["detour"], ["a", "e", "f", "g", "d"], "우회로가 남은 길이 아니다")
	assert_eq(int(routes["shortcut_length"]), 3, "지름길 칸 수가 틀렸다")
	assert_eq(int(routes["detour_length"]), 4, "우회로 칸 수가 틀렸다")
	assert_eq(int(routes["shortcut_climb"]), 3, "지름길 최대 오름이 틀렸다")
	assert_eq(int(routes["detour_climb"]), 1, "우회로 최대 오름이 틀렸다")


func test_the_two_ways_never_share_a_corridor() -> void:
	var routes := RoutesScript.to_boss(_forked_board())
	var detour: Array = routes["detour"]
	var shortcut: Array[String] = []
	shortcut.assign(routes["shortcut"])
	for index in range(1, detour.size()):
		assert_false(
			RoutesScript.route_uses(shortcut, detour[index - 1], detour[index]),
			"두 길이 같은 통로를 쓴다: %s" % str(detour)
		)


## 오름은 걸음마다의 **최댓값**이지 합이 아니다. 그리고 내려가는 것은 세지 않는다.
func test_the_climb_is_the_worst_single_step_and_ignores_descents() -> void:
	var plan := DungeonBlueprint.new()
	plan.add_room("a", "입구", 0, Room.Kind.ENTRANCE)
	plan.add_room("b", "b", 2)
	plan.add_room("c", "c", 4)
	plan.add_room("d", "제단", 1, Room.Kind.BOSS)
	plan.connect_rooms("a", "b")
	plan.connect_rooms("b", "c")
	plan.connect_rooms("c", "d")

	var routes := RoutesScript.to_boss(plan)
	# 걸음은 +2, +2, -3. 합이면 4, 최댓값이면 2, 내려가기를 세면 3 이 된다.
	assert_eq(int(routes["shortcut_climb"]), 2, "최대 오름이 걸음의 최댓값이 아니다")


func test_a_board_without_a_boss_draws_nothing() -> void:
	var plan := DungeonBlueprint.new()
	plan.add_room("a", "입구", 0, Room.Kind.ENTRANCE)
	plan.add_room("b", "b", 0)
	plan.connect_rooms("a", "b")

	var routes := RoutesScript.to_boss(plan)
	assert_eq(routes["boss"], "", "없는 보스를 찾아냈다")
	assert_eq((routes["shortcut"] as Array).size(), 0, "보스가 없는데 지름길이 나왔다")
	assert_eq((routes["detour"] as Array).size(), 0, "보스가 없는데 우회로가 나왔다")


## 외길 판은 **우회로만** 비어 있어야 한다. 둘 다 비면 화면이 "보스가 없다"고 말한다.
func test_a_single_way_board_leaves_only_the_detour_empty() -> void:
	var plan := DungeonBlueprint.new()
	plan.add_room("a", "입구", 0, Room.Kind.ENTRANCE)
	plan.add_room("b", "b", 1)
	plan.add_room("c", "제단", 2, Room.Kind.BOSS)
	plan.connect_rooms("a", "b")
	plan.connect_rooms("b", "c")

	var routes := RoutesScript.to_boss(plan)
	assert_eq(routes["shortcut"], ["a", "b", "c"], "외길인데 지름길이 안 나왔다")
	assert_eq((routes["detour"] as Array).size(), 0, "외길인데 우회로가 나왔다")
	assert_eq(int(routes["detour_length"]), 0, "없는 우회로에 길이가 붙었다")


func test_the_same_board_always_gives_the_same_two_ways() -> void:
	var plan := _forked_board()
	assert_eq(RoutesScript.to_boss(plan), RoutesScript.to_boss(plan), "같은 판이 다른 길을 냈다")


## **같은 계산이 두 곳에 있다.** 화면(`DungeonRoutes`)과 계측기(`tools/dungeon_metrics.gd`)가
## 같은 판에서 같은 수를 내야 한다. 한쪽만 고치면 여기가 깨진다 (§17.27.3).
func test_the_screen_and_the_metrics_measure_the_same_two_ways() -> void:
	var measured := 0
	for seed_value in _SEEDS:
		for rooms in [12, 32, 52]:
			var plan := _generated(seed_value, rooms)
			var routes := RoutesScript.to_boss(plan)
			var expected := _metrics_routes(plan)
			var where := "시드 %d 방 %d" % [seed_value, rooms]
			assert_eq(
				int(routes["shortcut_length"]), int(expected["fast_length"]), "지름길 칸 수 " + where
			)
			assert_eq(int(routes["shortcut_climb"]), int(expected["fast_climb"]), "지름길 오름 " + where)
			assert_eq(
				int(routes["detour_length"]), int(expected["slow_length"]), "우회로 칸 수 " + where
			)
			assert_eq(int(routes["detour_climb"]), int(expected["slow_climb"]), "우회로 오름 " + where)
			if int(routes["shortcut_length"]) > 0:
				measured += 1
	# 전부 0 이면 위의 비교가 전부 0 == 0 이라 아무것도 안 잰 것이 된다.
	assert_gt(measured, 0, "생성된 판에서 보스까지의 길을 한 번도 못 쟀다")


func _generated(seed_value: int, rooms: int) -> DungeonBlueprint:
	var params := DungeonGenerator.Params.new()
	params.room_count = rooms
	return GeneratorScript.new(seed_value, params).generate()


## 계측기 쪽 정의로 같은 판을 잰다. 계측기의 공개 함수만 쓴다.
func _metrics_routes(blueprint: DungeonBlueprint) -> Dictionary:
	var result := {"fast_length": 0, "fast_climb": 0, "slow_length": 0, "slow_climb": 0}
	var board: Dictionary = MetricsScript.from_blueprint(blueprint)
	var count: int = (board["points"] as PackedVector2Array).size()
	var edges: Array[Vector2i] = board["edges"]
	var elevations: PackedInt32Array = board["elevations"]
	var kinds: Dictionary = board["kinds"]
	var entrance: int = board["entrance"]

	var boss := -1
	for index in count:
		if kinds.get(index, Room.Kind.EMPTY) == Room.Kind.BOSS:
			boss = index
			break
	if boss < 0:
		return result

	var fast: PackedInt32Array = MetricsScript.path(count, edges, entrance, boss)
	if fast.size() < 2:
		return result
	var fast_shape: Dictionary = MetricsScript.describe(fast, elevations)
	result["fast_length"] = int(fast_shape["length"])
	result["fast_climb"] = int(fast_shape["climb"])

	var reduced: Array[Vector2i] = []
	for edge in edges:
		if not MetricsScript.on_path(fast, edge):
			reduced.append(edge)
	var slow: PackedInt32Array = MetricsScript.path(count, reduced, entrance, boss)
	if slow.size() < 2:
		return result
	var slow_shape: Dictionary = MetricsScript.describe(slow, elevations)
	result["slow_length"] = int(slow_shape["length"])
	result["slow_climb"] = int(slow_shape["climb"])
	return result
