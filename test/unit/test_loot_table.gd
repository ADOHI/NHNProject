extends GutTest
## 방에 남은 귀중품. **docs/design/05-rules.md §5.2.**
##
## *"던전의 귀중품은 유한하고, 늦으면 이미 털려 있다."*
## 이 한 줄이 NPC 탐험가를 장애물이 아니라 경쟁자로 만든다.
## 무한하면 남이 먼저 가든 말든 상관없고, 그러면 판에 사람이 여럿 있을 이유가 없다.


func _board() -> DungeonGraph:
	var blueprint := DungeonBlueprint.new()
	blueprint.add_room("hall", "큰 방", 0, Room.Kind.ENTRANCE)
	blueprint.add_room("vault", "금고", 0, Room.Kind.TREASURE)
	blueprint.add_room("deep", "심부", 0, Room.Kind.BOSS)
	blueprint.connect_rooms("hall", "vault")
	blueprint.connect_rooms("vault", "deep")
	return blueprint.build()


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	return rng


func test_loot_lands_only_where_it_belongs() -> void:
	var table := LootTable.for_graph(_board(), _rng())

	assert_false(table.has_loot("hall"), "통로에 귀중품이 놓였다")
	assert_true(table.has_loot("vault"))
	assert_true(table.has_loot("deep"))


func test_the_boss_room_is_worth_more() -> void:
	# 고위험 고보상 (§5.2). 큰 것이 한 자리에 있어야 보스를 노릴 이유가 생긴다.
	var table := LootTable.for_graph(_board(), _rng())

	assert_gt(table.value_at("deep"), table.value_at("vault"))


func test_taking_empties_the_room() -> void:
	var table := LootTable.new()
	table.put("vault", 5)

	assert_eq(table.take("vault"), 5)
	assert_false(table.has_loot("vault"), "가져갔는데 그대로 있다")


func test_the_second_hand_comes_back_empty() -> void:
	var table := LootTable.new()
	table.put("vault", 5)
	table.take("vault")

	assert_eq(table.take("vault"), 0, "같은 방을 두 번 털었다")


func test_putting_nothing_clears_the_room() -> void:
	# 시험이 판을 못 박을 때 쓴다. 0 을 넣어 두면 "값이 0 인 방"이 생겨 셈이 흐려진다.
	var table := LootTable.new()
	table.put("vault", 5)
	table.put("vault", 0)

	assert_false(table.has_loot("vault"))
	assert_true(table.is_empty())


func test_it_knows_what_is_left() -> void:
	# NPC 가 어디로 갈지 이것을 보고 고른다.
	var table := LootTable.new()
	table.put("vault", 5)
	table.put("deep", 9)

	assert_eq(table.remaining_room_ids().size(), 2)
	assert_eq(table.total_remaining(), 14)


func test_a_board_without_rooms_is_not_a_crash() -> void:
	var table := LootTable.for_graph(null, _rng())

	assert_true(table.is_empty())
