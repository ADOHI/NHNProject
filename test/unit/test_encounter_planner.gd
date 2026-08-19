extends GutTest
## NPC 가 조우에서 무엇을 고르는가. **docs/design/05-rules.md §5.4.**
##
## §5.4 가 협상의 조건을 이렇게 적었다.
##
## > 성향이 완전히 숨겨져 있으면 협상은 도박이고, 완전히 공개되면 긴장이 없다.
## > *"단서는 보이지만 확신은 못 한다"* 가 목표 지점이다.
##
## **난수로 고르면 읽을 것이 없다.** 그래서 이 파일이 지키는 것은 둘이다.
##
## | | |
## | --- | --- |
## | 성향이 선택을 바꾼다 | 안 바뀌면 성향이 조우에서 아무 일도 안 하는 것이다 |
## | 같은 판이 같은 선택을 낸다 | 난수가 새면 이상한 판을 다시 볼 수 없다 |
##
## 수치의 정확한 값은 잠정이다 (docs/design/35-encounter.md §35.7).
## **여기서 잠그는 것은 방향뿐이다** — 무모하면 치고 신중하면 뺀다.

const Fixtures := preload("res://test/support/turn_fixtures.gd")


## 금고에서 마주 선 둘. 스쿼드 8 · 경쟁자 6 · 판돈 5.
func _standoff() -> DungeonRun:
	var run := Fixtures.run("vault")
	Fixtures.rival(run, "vault", "rival", 6, 3)
	return run


func _plan(run: DungeonRun, actor_id: String, room_id: String) -> EncounterPlan:
	var room := run.graph.get_room(room_id)
	var stakes := EncounterStakes.of(room.kind, run.loot.value_at(room_id))
	return run.encounter_planner.plan_for(
		Fixtures.actor(run, actor_id), room.occupants(), stakes, [] as Array[String], 0
	)


func _choice(run: DungeonRun, axis: NpcAxis.Kind, value: int) -> EncounterChoice.Kind:
	run.planner.set_temperament("rival", Fixtures.temper(axis, value))
	return _plan(run, "rival", "vault").choice


# ---------------------------------------------------------------- 성향이 바꾼다


func test_the_reckless_one_strikes() -> void:
	var run := _standoff()

	assert_eq(
		_choice(run, NpcAxis.Kind.RECKLESS, NpcAxis.MAX_VALUE),
		EncounterChoice.Kind.FIGHT,
		"무모한데 안 쳤다"
	)


func test_the_careful_one_backs_off() -> void:
	# **불리한 쪽이다** — 경쟁자 6 대 스쿼드 8.
	var run := _standoff()

	assert_eq(
		_choice(run, NpcAxis.Kind.RECKLESS, NpcAxis.MIN_VALUE),
		EncounterChoice.Kind.FLEE,
		"신중한데 안 물러났다"
	)


func test_the_wicked_one_strikes_first() -> void:
	var run := _standoff()

	assert_eq(_choice(run, NpcAxis.Kind.GOOD, NpcAxis.MIN_VALUE), EncounterChoice.Kind.FIGHT)


func test_the_good_one_talks() -> void:
	var run := _standoff()

	assert_eq(_choice(run, NpcAxis.Kind.GOOD, NpcAxis.MAX_VALUE), EncounterChoice.Kind.NEGOTIATE)


func test_a_neutral_one_talks_when_the_odds_are_even() -> void:
	# 아무 기질도 없으면 상황만 남는다. 힘이 비슷하면 말로 푸는 것이 싸다.
	var run := _standoff()

	assert_eq(_choice(run, NpcAxis.Kind.HONEST, 0), EncounterChoice.Kind.NEGOTIATE)


# ---------------------------------------------------------------- E9 협력


func test_a_loyal_one_helps_against_a_monster() -> void:
	# §5.6 E9 — 몬스터방에서 탐험가끼리 만나면 협력할지 각자 싸울지 고른다.
	var run := _standoff()
	Fixtures.monster(run, "vault", "beast", 5)

	assert_eq(
		_choice(run, NpcAxis.Kind.LOYAL, NpcAxis.MAX_VALUE),
		EncounterChoice.Kind.COOPERATE,
		"의리가 있는데 안 도왔다"
	)


func test_a_calculating_one_leaves_you_to_it() -> void:
	var run := _standoff()
	Fixtures.monster(run, "vault", "beast", 5)

	assert_ne(
		_choice(run, NpcAxis.Kind.LOYAL, NpcAxis.MIN_VALUE),
		EncounterChoice.Kind.COOPERATE,
		"실리를 따지는데 도왔다"
	)


func test_there_is_no_one_to_talk_to_in_a_monster_room() -> void:
	# 몬스터는 말을 걸 상대가 아니다. 후보로 남겨 두면 혼자 서서 협상을 고른다.
	var run := Fixtures.run("hall")
	Fixtures.rival(run, "vault", "rival", 6, 3)
	Fixtures.monster(run, "vault", "beast", 5)

	var plan := _plan(run, "rival", "vault")

	assert_ne(plan.choice, EncounterChoice.Kind.NEGOTIATE)
	assert_true(
		plan.score_of(EncounterChoice.Kind.NEGOTIATE) <= EncounterPlanner.NO_SCORE,
		"말 걸 상대가 없는데 협상이 후보로 남았다"
	)


# ---------------------------------------------------------------- 관계도


func test_being_liked_buys_you_a_conversation() -> void:
	# §5.10 — 친밀도가 높으면 싸울 확률이 준다.
	var run := _standoff()
	run.encounter_planner.set_affinity("squad", RelationGraph.AFFINITY_MAX)

	assert_eq(_choice(run, NpcAxis.Kind.GOOD, 0), EncounterChoice.Kind.NEGOTIATE)


func test_being_hated_buys_you_a_fight() -> void:
	var run := _standoff()
	run.encounter_planner.set_affinity("squad", RelationGraph.AFFINITY_MIN)

	assert_eq(_choice(run, NpcAxis.Kind.GOOD, 0), EncounterChoice.Kind.FIGHT)


# ---------------------------------------------------------------- 설명이 된다


func test_every_choice_comes_with_a_reason() -> void:
	# 점수만 내면 **왜 그렇게 골랐는지 아무 데도 안 남는다** (§35.4.4).
	var run := _standoff()
	for value in [NpcAxis.MIN_VALUE, 0, NpcAxis.MAX_VALUE]:
		run.planner.set_temperament("rival", Fixtures.temper(NpcAxis.Kind.RECKLESS, value))
		var plan := _plan(run, "rival", "vault")
		assert_false(plan.reason.is_empty(), "근거 없이 골랐다: %d" % value)


func test_the_reason_names_what_pushed_it() -> void:
	var run := _standoff()
	run.planner.set_temperament("rival", Fixtures.temper(NpcAxis.Kind.RECKLESS, NpcAxis.MAX_VALUE))

	var plan := _plan(run, "rival", "vault")

	assert_eq(plan.choice, EncounterChoice.Kind.FIGHT)
	assert_true(plan.reason.contains("무모"), "무모해서 골랐는데 근거에 안 나온다: %s" % plan.reason)


func test_the_scores_of_every_choice_are_kept() -> void:
	var run := _standoff()

	var plan := _plan(run, "rival", "vault")

	assert_eq(plan.scores.size(), EncounterChoice.count(), "안 재진 선택지가 있다")


# ---------------------------------------------------------------- 다시 볼 수 있다


func test_the_same_board_makes_the_same_choice() -> void:
	# 전역 난수를 쓰지 않는다. 같은 시드가 같은 판을 내야 이상한 판을 다시 본다.
	var first := _standoff()
	var second := _standoff()

	assert_eq(
		_choice(first, NpcAxis.Kind.LOYAL, 25),
		_choice(second, NpcAxis.Kind.LOYAL, 25),
		"같은 판이 다른 선택을 냈다"
	)
