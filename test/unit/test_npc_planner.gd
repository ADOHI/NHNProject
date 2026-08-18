extends GutTest
## NPC 탐험가의 행동 (M4). **docs/design/05-rules.md §5.2.2.**
##
## §16.8 — 없으면 *"흔한 턴제 로그라이크가 된다"*. 몬스터는 배치된 장애물이지만
## NPC 탐험가는 **같은 규칙 아래 같은 목표로 움직인다.**
##
## §5.2.2 가 정한 것은 셋뿐이다 — 이동 · 획득 · 탈출. 나머지 칸은 "미정"이고
## 이 시험도 그 셋만 잠근다.

const Fixtures := preload("res://test/support/turn_fixtures.gd")

# ---------------------------------------------------------------- 몬스터


func test_monsters_hold_their_ground() -> void:
	# **이 전제가 깨지면 위험도 변화량 추론 전체가 무너진다** (§13.5).
	# 몬스터가 안 움직여야 변화량이 전부 사람이 된다.
	var run := Fixtures.run("hall")
	var beast := Fixtures.monster(run, "deep")

	var intent := run.planner.plan_for(beast, "deep")

	assert_eq(intent.kind, TurnIntent.Kind.STAY)


# ---------------------------------------------------------------- 획득


func test_a_rival_standing_on_loot_digs() -> void:
	var run := Fixtures.run("hall")
	var rival := Fixtures.rival(run, "vault")

	var intent := run.planner.plan_for(rival, "vault")

	assert_eq(intent.kind, TurnIntent.Kind.SEARCH)


func test_a_rival_walks_toward_the_nearest_loot() -> void:
	var run := Fixtures.run("hall")
	var rival := Fixtures.rival(run, "gate")

	var intent := run.planner.plan_for(rival, "gate")

	assert_eq(intent.kind, TurnIntent.Kind.MOVE)
	assert_eq(intent.target_room_id, "hall", "금고로 가는 첫 걸음이 아니다")


func test_a_rival_actually_takes_what_it_finds() -> void:
	# 계획이 아니라 판이 바뀌는 것까지 본다 — 이것이 있어야 귀중품이 유한해진다.
	var run := Fixtures.run("hall")
	Fixtures.rival(run, "vault")

	run.submit_intent(TurnIntent.stay("squad"))
	run.resolve_turn()

	assert_eq(run.haul.carried_by("rival"), Fixtures.VAULT_VALUE)
	assert_false(run.loot.has_loot("vault"), "가져갔는데 방에 그대로 있다")


# ---------------------------------------------------------------- 탈출


func test_a_loaded_rival_heads_for_the_door() -> void:
	var run := Fixtures.run("hall")
	var rival := Fixtures.rival(run, "vault")
	run.haul.add("rival", 99)

	var intent := run.planner.plan_for(rival, "vault")

	assert_eq(intent.kind, TurnIntent.Kind.MOVE)
	assert_eq(intent.target_room_id, "hall", "관문 쪽으로 가지 않는다")


func test_a_loaded_rival_at_the_door_holds() -> void:
	var run := Fixtures.run("hall")
	var rival := Fixtures.rival(run, "gate")
	run.haul.add("rival", 99)

	var intent := run.planner.plan_for(rival, "gate")

	assert_eq(intent.kind, TurnIntent.Kind.ESCAPE)


func test_a_rival_leaves_when_nothing_is_left_to_take() -> void:
	# 판에 남은 것이 없으면 더 있을 이유가 없다.
	var run := Fixtures.run("hall")
	var rival := Fixtures.rival(run, "deep")
	run.loot.put("vault", 0)

	var intent := run.planner.plan_for(rival, "deep")

	assert_eq(intent.kind, TurnIntent.Kind.MOVE)
	assert_eq(intent.target_room_id, "vault", "관문 쪽 첫 걸음이 아니다")


# ---------------------------------------------------------------- 성향


func test_no_temperament_reads_as_neutral() -> void:
	var run := Fixtures.run("hall")

	assert_eq(run.planner.temperament_of("아무도아님").size(), NpcAxis.count())
	assert_eq(run.planner.target_value_of("아무도아님"), NpcPlanner.DEFAULT_TARGET_VALUE)


func test_the_reckless_one_wants_more_before_leaving() -> void:
	# 무모하면 더 챙기고 늦게 나간다. 그것이 곧 기사 소재가 된다.
	var run := Fixtures.run("hall")
	run.planner.set_temperament("rival", Fixtures.temper(NpcAxis.Kind.RECKLESS, 100))

	assert_gt(run.planner.target_value_of("rival"), NpcPlanner.DEFAULT_TARGET_VALUE)


func test_the_careful_one_leaves_earlier() -> void:
	var run := Fixtures.run("hall")
	run.planner.set_temperament("rival", Fixtures.temper(NpcAxis.Kind.RECKLESS, -100))

	assert_lt(run.planner.target_value_of("rival"), NpcPlanner.DEFAULT_TARGET_VALUE)


func test_the_careful_one_stops_in_front_of_something_bigger() -> void:
	var run := Fixtures.run("hall")
	var rival := Fixtures.rival(run, "hall", "rival", 2)
	Fixtures.monster(run, "vault", "warden", 9)
	run.planner.set_temperament("rival", Fixtures.temper(NpcAxis.Kind.RECKLESS, -80))

	var intent := run.planner.plan_for(rival, "hall")

	assert_eq(intent.kind, TurnIntent.Kind.STAY, "자기보다 큰 방으로 걸어 들어갔다")


func test_the_reckless_one_walks_straight_in() -> void:
	var run := Fixtures.run("hall")
	var rival := Fixtures.rival(run, "hall", "rival", 2)
	Fixtures.monster(run, "vault", "warden", 9)
	run.planner.set_temperament("rival", Fixtures.temper(NpcAxis.Kind.RECKLESS, 80))

	var intent := run.planner.plan_for(rival, "hall")

	assert_eq(intent.target_room_id, "vault")


# ---------------------------------------------------------------- 고도


func test_a_path_it_cannot_climb_is_not_a_path() -> void:
	# 민첩을 무시하면 못 오르는 방을 목표로 잡고 매 턴 벽에 부딪힌다 (§7.2.6).
	var blueprint := DungeonBlueprint.new()
	blueprint.add_room("low", "아래", 0, Room.Kind.ENTRANCE)
	blueprint.add_room("ledge", "선반", 5, Room.Kind.TREASURE)
	blueprint.connect_rooms("low", "ledge")
	var graph := blueprint.build()
	var rival := Actor.new("rival", "칼날의 요한", Actor.Kind.NPC_EXPLORER, 4, 1)
	graph.place_actor(rival, "low")
	var loot := LootTable.new()
	loot.put("ledge", 5)
	var planner := NpcPlanner.new(graph, loot, Haul.new())

	var intent := planner.plan_for(rival, "low")

	assert_eq(intent.kind, TurnIntent.Kind.STAY, "민첩 1 로 상승 5 를 올랐다")
