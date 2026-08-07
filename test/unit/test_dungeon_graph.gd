extends GutTest
## DungeonGraph 의 단위 테스트.
##
## 이 게임의 심장은 adjacent_threat() 다. 같은 숫자가 서로 다른 구성에서 나온다는
## 모호함이 게임의 재미 자체이므로, 그 성질을 테스트로 못 박는다
## (docs/design/07-level-design.md §7.2).

const ActorScript := preload("res://src/core/dungeon/actor.gd")
const RoomScript := preload("res://src/core/dungeon/room.gd")
const GraphScript := preload("res://src/core/dungeon/dungeon_graph.gd")


func _make_actor(id: String, threat: int, kind := Actor.Kind.MONSTER) -> Actor:
	return ActorScript.new(id, id, kind, threat)


## 가운데 방 hub 에 north / east / south / west 가 붙은 별 모양 판.
func _make_hub_graph() -> DungeonGraph:
	var graph: DungeonGraph = GraphScript.new()
	graph.add_room(RoomScript.new("hub", "중앙 홀"))
	for id in ["north", "east", "south", "west"]:
		graph.add_room(RoomScript.new(id, id))
		graph.connect_rooms("hub", id)
	return graph


# ---------------------------------------------------------------- 판 구성


func test_connection_is_bidirectional() -> void:
	var graph := _make_hub_graph()
	assert_true(graph.are_connected("hub", "north"))
	assert_true(graph.are_connected("north", "hub"))


func test_unconnected_rooms_are_not_adjacent() -> void:
	var graph := _make_hub_graph()
	assert_false(graph.are_connected("north", "south"), "허브를 거쳐야 하는 방끼리 이어져 있다")


func test_duplicate_room_is_rejected() -> void:
	# 조용히 덮어쓰면 그 방에 있던 존재가 통째로 사라져 판이 어긋난다. 소리 내어 거부한다.
	var graph: DungeonGraph = GraphScript.new()
	graph.add_room(RoomScript.new("hub"))
	graph.add_room(RoomScript.new("hub"))
	assert_eq(graph.room_ids().size(), 1)
	assert_push_error("이미 존재하는 방 id 입니다: hub")


func test_connecting_unknown_room_is_rejected() -> void:
	var graph := _make_hub_graph()
	graph.connect_rooms("hub", "nowhere")
	assert_false(graph.are_connected("hub", "nowhere"))
	assert_push_error_count(1)


func test_room_cannot_connect_to_itself() -> void:
	# 자기 자신이 인접해 있으면 내 방의 위험도가 인접 합에 섞인다.
	var graph := _make_hub_graph()
	graph.connect_rooms("hub", "hub")
	assert_false(graph.are_connected("hub", "hub"))
	assert_push_error_count(1)


# ---------------------------------------------------------------- 위험도 합산


func test_adjacent_threat_sums_neighbors() -> void:
	var graph := _make_hub_graph()
	graph.place_actor(_make_actor("boss", 6), "north")
	assert_eq(graph.adjacent_threat("hub"), 6)


func test_adjacent_threat_excludes_the_room_itself() -> void:
	# 내가 선 방의 위험도가 합에 섞이면, 내가 강할수록 주변이 위험해 보이는 거짓말이 된다.
	var graph := _make_hub_graph()
	graph.place_actor(_make_actor("squad", 8, Actor.Kind.PLAYER_SQUAD), "hub")
	graph.place_actor(_make_actor("mob", 2), "north")
	assert_eq(graph.adjacent_threat("hub"), 2)


func test_same_sum_from_one_boss_or_many_mobs() -> void:
	# 이 게임의 핵심. 합 6 이 보스 하나인지 잡몹 넷인지 플레이어는 알 수 없다.
	var one_boss := _make_hub_graph()
	one_boss.place_actor(_make_actor("boss", 6), "north")

	var many_mobs := _make_hub_graph()
	var threats := [1, 2, 2, 1]
	var directions := ["north", "east", "south", "west"]
	for i in directions.size():
		many_mobs.place_actor(_make_actor("mob_%d" % i, threats[i]), directions[i])

	assert_eq(one_boss.adjacent_threat("hub"), 6)
	assert_eq(many_mobs.adjacent_threat("hub"), 6, "구성이 달라도 합은 같아야 한다")


func test_occupant_count_disambiguates_the_sum() -> void:
	# 합만으로는 안 갈리던 것이 개체 수를 알면 갈린다 — 정찰 계열의 눈.
	var one_boss := _make_hub_graph()
	one_boss.place_actor(_make_actor("boss", 6), "north")

	var many_mobs := _make_hub_graph()
	var directions := ["north", "east", "south", "west"]
	for i in directions.size():
		many_mobs.place_actor(_make_actor("mob_%d" % i, 1), directions[i])
		many_mobs.place_actor(_make_actor("extra_%d" % i, 1), directions[i])

	assert_eq(one_boss.adjacent_occupant_count("hub"), 1)
	assert_eq(many_mobs.adjacent_occupant_count("hub"), 8)


func test_max_threat_disambiguates_differently() -> void:
	# 개체 수와는 다른 각도의 눈. 합 6 · 최댓값 2 라면 한 방에 몰려 있지 않다.
	var graph := _make_hub_graph()
	graph.place_actor(_make_actor("a", 2), "north")
	graph.place_actor(_make_actor("b", 2), "east")
	graph.place_actor(_make_actor("c", 2), "south")
	assert_eq(graph.adjacent_threat("hub"), 6)
	assert_eq(graph.adjacent_max_threat("hub"), 2)


func test_empty_neighbors_give_zero() -> void:
	var graph := _make_hub_graph()
	assert_eq(graph.adjacent_threat("hub"), 0)


func test_all_actor_kinds_count_the_same() -> void:
	# 몬스터든 NPC 든 플레이어든 위험도는 같은 단위다. 종류가 합산을 가르면 안 된다.
	var graph := _make_hub_graph()
	graph.place_actor(_make_actor("m", 3, Actor.Kind.MONSTER), "north")
	graph.place_actor(_make_actor("n", 3, Actor.Kind.NPC_EXPLORER), "east")
	graph.place_actor(_make_actor("p", 3, Actor.Kind.PLAYER_SQUAD), "south")
	assert_eq(graph.adjacent_threat("hub"), 9)


# ---------------------------------------------------------------- 이동


func test_actor_exists_in_exactly_one_room() -> void:
	# 두 방에 동시에 존재하면 위험도가 이중 계산되어 판이 거짓말을 한다.
	var graph := _make_hub_graph()
	var actor := _make_actor("npc", 4, Actor.Kind.NPC_EXPLORER)
	graph.place_actor(actor, "north")
	graph.place_actor(actor, "hub")
	assert_eq(graph.threat_at("north"), 0)
	assert_eq(graph.threat_at("hub"), 4)


func test_move_to_connected_room_succeeds() -> void:
	var graph := _make_hub_graph()
	var actor := _make_actor("npc", 4, Actor.Kind.NPC_EXPLORER)
	graph.place_actor(actor, "hub")
	assert_true(graph.move_actor(actor, "north"))
	assert_eq(graph.find_actor_room(actor), "north")


func test_move_to_unconnected_room_fails() -> void:
	var graph := _make_hub_graph()
	var actor := _make_actor("npc", 4, Actor.Kind.NPC_EXPLORER)
	graph.place_actor(actor, "north")
	assert_false(graph.move_actor(actor, "south"), "이어지지 않은 방으로 이동했다")
	assert_eq(graph.find_actor_room(actor), "north")


func test_movement_changes_the_adjacent_number() -> void:
	# "숫자의 변화량은 사람을 알려 준다" 의 근거
	# (docs/design/13-information-design.md §13.5).
	var graph := _make_hub_graph()
	graph.place_actor(_make_actor("mob", 3), "north")
	var before := graph.adjacent_threat("hub")

	var npc := _make_actor("npc", 4, Actor.Kind.NPC_EXPLORER)
	graph.place_actor(npc, "east")
	var after := graph.adjacent_threat("hub")

	assert_eq(before, 3)
	assert_eq(after, 7, "누가 들어오면 인접 합이 그만큼 오른다")


func test_remove_actor_clears_threat() -> void:
	var graph := _make_hub_graph()
	var actor := _make_actor("npc", 5, Actor.Kind.NPC_EXPLORER)
	graph.place_actor(actor, "north")
	graph.remove_actor(actor)
	assert_eq(graph.adjacent_threat("hub"), 0)
	assert_eq(graph.find_actor_room(actor), "")
