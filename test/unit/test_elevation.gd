extends GutTest
## 고도와 이동 가능성의 단위 테스트.
##
## 규칙은 docs/design/07-level-design.md §7.2.6~7.2.8 이다.
## 내려가기는 자유, 올라가기는 상승폭 ≤ 민첩.

const ActorScript := preload("res://src/core/dungeon/actor.gd")
const RoomScript := preload("res://src/core/dungeon/room.gd")
const GraphScript := preload("res://src/core/dungeon/dungeon_graph.gd")
const StatsScript := preload("res://src/core/dungeon/squad_stats.gd")


## low(0) - mid(3) - high(7) 로 이어진 계단형 판.
func _make_stairs() -> DungeonGraph:
	var graph: DungeonGraph = GraphScript.new()
	graph.add_room(RoomScript.new("low", "아래", 0))
	graph.add_room(RoomScript.new("mid", "중간", 3))
	graph.add_room(RoomScript.new("high", "위", 7))
	graph.connect_rooms("low", "mid")
	graph.connect_rooms("mid", "high")
	return graph


func _make_actor(id: String, threat: int, agility: int) -> Actor:
	return ActorScript.new(id, id, Actor.Kind.MONSTER, threat, agility)


# ---------------------------------------------------------------- 상승폭


func test_climb_is_zero_when_going_down() -> void:
	# 내려가는 것은 언제나 자유다.
	var graph := _make_stairs()
	assert_eq(graph.climb_between("mid", "low"), 0)
	assert_eq(graph.climb_between("high", "mid"), 0)


func test_climb_is_the_elevation_difference_going_up() -> void:
	var graph := _make_stairs()
	assert_eq(graph.climb_between("low", "mid"), 3)
	assert_eq(graph.climb_between("mid", "high"), 4)


func test_descend_is_always_allowed_even_with_zero_agility() -> void:
	# "들어가긴 쉽고 나오긴 어렵다" 의 근거 (§7.2.6.2).
	var graph := _make_stairs()
	assert_true(graph.can_traverse("high", "mid", 0))
	assert_true(graph.can_traverse("mid", "low", 0))


func test_ascend_requires_agility() -> void:
	var graph := _make_stairs()
	assert_false(graph.can_traverse("low", "mid", 2))
	assert_true(graph.can_traverse("low", "mid", 3))
	assert_true(graph.can_traverse("low", "mid", 9))


func test_unconnected_rooms_are_never_traversable() -> void:
	var graph := _make_stairs()
	assert_false(graph.can_traverse("low", "high", 999))


# ---------------------------------------------------------------- 비대칭


func test_a_stronger_climber_can_come_down_on_you() -> void:
	# 나는 못 올라가는데 쟤는 내려올 수 있다 — 고도의 공포 (§7.2.7).
	var graph := _make_stairs()
	var player := _make_actor("player", 8, 2)
	var hunter := _make_actor("hunter", 5, 0)
	graph.place_actor(player, "low")
	graph.place_actor(hunter, "mid")

	assert_false(graph.move_actor(player, "mid"), "민첩 2 로 3 을 올랐다")
	assert_true(graph.move_actor(hunter, "low"), "내려오는 것은 자유여야 한다")


func test_blocked_neighbor_still_counts_toward_threat() -> void:
	# 못 가는 방도 위험도 합에 들어간다. 저기 있는 것들은 내려올 수 있기 때문이다 (§7.2.7).
	var graph := _make_stairs()
	graph.place_actor(_make_actor("mob", 5, 0), "mid")
	assert_eq(graph.adjacent_threat("low"), 5)
	assert_eq(graph.traversable_neighbors("low", 0).size(), 0, "민첩 0 인데 오를 수 있다고 나온다")


func test_traversable_neighbors_grows_with_agility() -> void:
	# 민첩이 오르면 같은 위협이 기회로 바뀐다.
	var graph := _make_stairs()
	assert_eq(graph.traversable_neighbors("low", 0).size(), 0)
	assert_eq(graph.traversable_neighbors("low", 3).size(), 1)


# ---------------------------------------------------------------- 필요 민첩


func test_required_agility_is_the_worst_climb_on_the_path() -> void:
	# low -> mid(3) -> high(4) 이므로 high 에 닿으려면 4 가 필요하다.
	var graph := _make_stairs()
	var costs := graph.required_agility_from("low")
	assert_eq(costs["low"], 0)
	assert_eq(costs["mid"], 3)
	assert_eq(costs["high"], 4)


func test_required_agility_prefers_the_gentler_route() -> void:
	# 가파른 직행로와 완만한 우회로가 있으면 우회로 쪽이 기준이 된다.
	var graph: DungeonGraph = GraphScript.new()
	graph.add_room(RoomScript.new("start", "시작", 0))
	graph.add_room(RoomScript.new("step", "계단참", 2))
	graph.add_room(RoomScript.new("top", "정상", 4))
	graph.connect_rooms("start", "top")  # 상승 4 짜리 직행
	graph.connect_rooms("start", "step")  # 상승 2
	graph.connect_rooms("step", "top")  # 상승 2

	var costs := graph.required_agility_from("start")
	assert_eq(costs["top"], 2, "완만한 우회로를 못 찾았다")


func test_descending_route_costs_nothing() -> void:
	var graph: DungeonGraph = GraphScript.new()
	graph.add_room(RoomScript.new("peak", "정상", 9))
	graph.add_room(RoomScript.new("valley", "골짜기", 0))
	graph.connect_rooms("peak", "valley")
	var costs := graph.required_agility_from("peak")
	assert_eq(costs["valley"], 0)


# ---------------------------------------------------------------- 스쿼드 집계


func test_squad_threat_is_the_sum() -> void:
	assert_eq(StatsScript.threat_of([3, 4, 2] as Array[int]), 9)


func test_squad_agility_is_the_average() -> void:
	assert_eq(StatsScript.agility_of([2, 4] as Array[int]), 3)
	assert_eq(StatsScript.agility_of([1, 2] as Array[int]), 1, "내림이어야 한다")


func test_nimble_member_raises_reach() -> void:
	# 최솟값이었다면 이 값이 오르지 않고, 민첩 특화 직업이 존재할 이유가 사라진다.
	var without := StatsScript.agility_of([1, 1] as Array[int])
	var with_scout := StatsScript.agility_of([1, 1, 7] as Array[int])
	assert_eq(without, 1)
	assert_eq(with_scout, 3)


func test_heavy_member_lowers_reach() -> void:
	# 전투력 ↔ 기동성 트레이드오프 (§14.3.1).
	var light := StatsScript.agility_of([4, 4] as Array[int])
	var heavy := StatsScript.agility_of([4, 4, 0] as Array[int])
	assert_eq(light, 4)
	assert_eq(heavy, 2)


func test_empty_squad_has_no_agility() -> void:
	assert_eq(StatsScript.agility_of([] as Array[int]), 0)
