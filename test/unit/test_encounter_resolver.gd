extends GutTest
## **조우 절차의 분기 셋.** docs/design/05-rules.md §5.8 의 흐름도가 이 파일의 명세다.
##
## | 여기서 잠그는 것 | |
## | --- | --- |
## | 전투 | **한 턴에 결판나지 않는다.** 밀림이 쌓이고 문턱을 넘을 때만 무너진다 |
## | 협상 | **양쪽이 다 골라야 성립한다.** 난수가 없다 |
## | 도주 | **쫓는 자가 없으면 무조건 성공한다** |
## | 협력 | 몬스터가 있고 둘 이상이 골라야 성립한다 (E9) |
##
## §5.8 이 얻으려던 것은 *"버티면 기회가 생긴다"* 와 *"도망다니는 장면"* 이다.
## **한 턴에 결판나면 둘 다 사라진다.** 그래서 첫 줄이 가장 중요하다.
##
## 수치는 잠정이다 (docs/design/35-encounter.md §35.7). 여기서 잠그는 것은
## **누가 이기고 무엇이 남는가**이지 몇 턴에 끝나는가가 아니다 —
## 다만 「한 턴이 아니다」만은 규칙이라 잠근다.

const Fixtures := preload("res://test/support/turn_fixtures.gd")


func _outcome(run: DungeonRun) -> EncounterOutcome:
	var report := run.last_report
	return report.outcomes[0] if report != null and not report.outcomes.is_empty() else null


func _marked(outcome: EncounterOutcome, kind: RelationEvent.Kind) -> EncounterMark:
	for mark in outcome.marks:
		if mark.kind == kind:
			return mark
	return null


## 이웃이 하나도 없는 방. **갇힌 것**을 만드는 유일한 방법이다.
func _cell() -> DungeonRun:
	var blueprint := DungeonBlueprint.new()
	blueprint.add_room("cell", "독방", 0, Room.Kind.EMPTY)
	var graph := blueprint.build()
	var squad := Actor.new("squad", "우리 스쿼드", Actor.Kind.PLAYER_SQUAD, 8, 3)
	graph.place_actor(squad, "cell")
	graph.place_actor(Actor.new("rival", "칼날의 요한", Actor.Kind.NPC_EXPLORER, 4, 3), "cell")
	return DungeonRun.new(blueprint, graph, squad, 1)


# ---------------------------------------------------------------- 전투


func test_a_fight_does_not_settle_in_one_turn() -> void:
	# §5.8 — *"전투 지속 -> 다음 턴에도 조우 상태"*. 여기가 무너지면
	# *"버티면 기회가 생긴다"* 도 *"도망다니는 장면"* 도 만들어지지 않는다.
	var run := Fixtures.run("vault")
	Fixtures.rival(run, "vault", "rival", 4, 3)
	Fixtures.hold(run, "squad", EncounterChoice.Kind.FIGHT)
	Fixtures.hold(run, "rival", EncounterChoice.Kind.FIGHT)

	var report := run.resolve_turn()

	assert_true(report.subdued_actor_ids.is_empty(), "한 턴에 결판났다")
	assert_true(_outcome(run).continues, "조우가 이어지지 않는다")


func test_the_weaker_side_is_the_one_that_gets_pushed() -> void:
	var run := Fixtures.run("vault")
	Fixtures.rival(run, "vault", "rival", 4, 3)
	Fixtures.hold(run, "squad", EncounterChoice.Kind.FIGHT)
	Fixtures.hold(run, "rival", EncounterChoice.Kind.FIGHT)

	run.resolve_turn()
	var outcome := _outcome(run)

	assert_true(outcome.pressure_on("rival") > 0, "약한 쪽이 안 밀렸다")
	assert_eq(outcome.pressure_on("squad"), 0, "이긴 쪽이 밀렸다")
	assert_true(outcome.victor_ids.has("squad"))


func test_holding_out_long_enough_breaks_someone() -> void:
	var run := Fixtures.run("vault")
	Fixtures.rival(run, "vault", "rival", 4, 3)
	run.haul.add("rival", 4)
	for _turn in 3:
		Fixtures.hold(run, "squad", EncounterChoice.Kind.FIGHT)
		Fixtures.hold(run, "rival", EncounterChoice.Kind.FIGHT)
		run.resolve_turn()

	assert_true(run.last_report.subdued_actor_ids.has("rival"), "밀렸는데 안 무너졌다")
	assert_null(Fixtures.actor(run, "rival"), "제압됐는데 판에 남아 있다")


func test_a_subdued_person_walks_out_empty_handed() -> void:
	# docs/design/28-combat.md §28.10 — 사람은 죽지 않고 제압된다.
	# 셋 중 「약탈만 하고 보내주기」를 기본으로 박았다 (§35.2.3).
	var run := Fixtures.run("vault")
	Fixtures.rival(run, "vault", "rival", 4, 3)
	run.haul.add("rival", 4)
	for _turn in 3:
		Fixtures.hold(run, "squad", EncounterChoice.Kind.FIGHT)
		Fixtures.hold(run, "rival", EncounterChoice.Kind.FIGHT)
		run.resolve_turn()

	assert_eq(run.haul.carried_by("rival"), 0, "제압당했는데 짐을 들고 있다")
	assert_eq(run.haul.carried_by("squad"), 4, "뺏은 것이 안 왔다")
	assert_true(run.last_report.slain_actor_ids.is_empty(), "사람이 죽었다")


func test_a_broken_monster_dies() -> void:
	# §28.10 — *"몬스터는 죽고 사람은 제압이야."*
	var run := Fixtures.run("vault")
	Fixtures.monster(run, "vault", "beast", 1)
	for _turn in 2:
		Fixtures.hold(run, "squad", EncounterChoice.Kind.FIGHT)
		run.resolve_turn()

	assert_true(run.last_report.slain_actor_ids.has("beast"), "몬스터가 안 죽었다")
	assert_null(Fixtures.actor(run, "beast"), "죽었는데 판에 남아 있다")


func test_the_player_can_be_put_down_too() -> void:
	# **게임 오버가 아니라 손실이다** (§28.10 — 대원은 잃지 않는다).
	var run := Fixtures.run("vault")
	Fixtures.rival(run, "vault", "bruiser", 20, 3)
	run.haul.add("squad", 3)
	Fixtures.hold(run, "bruiser", EncounterChoice.Kind.FIGHT)

	run.resolve_turn()

	assert_true(run.defeated, "제압당했는데 판이 안 끝났다")
	assert_true(run.finished)
	assert_eq(run.haul.carried_by("squad"), 0, "백팩을 안 잃었다")
	assert_not_null(Fixtures.actor(run, "squad"), "플레이어를 판에서 지웠다")


func test_nobody_swings_means_nobody_gets_hurt() -> void:
	# 가만히 서 있었더니 맞았다가 되면 태세를 고를 이유가 사라진다.
	var run := Fixtures.run("vault")
	Fixtures.rival(run, "vault", "rival", 4, 3)
	Fixtures.hold(run, "squad", EncounterChoice.Kind.STAND)
	Fixtures.hold(run, "rival", EncounterChoice.Kind.STAND)

	run.resolve_turn()

	assert_eq(_outcome(run).pressure_on("rival"), 0)
	assert_eq(_outcome(run).pressure_on("squad"), 0)
	assert_not_null(_marked(_outcome(run), RelationEvent.Kind.PASS_BY), "지나친 것이 안 남았다")


# ---------------------------------------------------------------- 협상


func test_talking_needs_both_of_them() -> void:
	var run := Fixtures.run("vault")
	Fixtures.rival(run, "vault", "rival", 6, 3)
	Fixtures.hold(run, "squad", EncounterChoice.Kind.NEGOTIATE)
	Fixtures.hold(run, "rival", EncounterChoice.Kind.NEGOTIATE)

	run.resolve_turn()
	var outcome := _outcome(run)

	assert_true(outcome.negotiated_ids.has("squad"))
	assert_true(outcome.negotiated_ids.has("rival"))
	assert_not_null(_marked(outcome, RelationEvent.Kind.BARGAIN), "관계도로 갈 것이 안 남았다")


func test_a_deal_splits_what_is_left_in_the_room() -> void:
	# **E5** — 귀중품방에서 협상이 값을 갖게 하는 유일한 장치다 (§35.3.2).
	var run := Fixtures.run("vault")
	Fixtures.rival(run, "vault", "rival", 6, 3)
	Fixtures.hold(run, "squad", EncounterChoice.Kind.NEGOTIATE)
	Fixtures.hold(run, "rival", EncounterChoice.Kind.NEGOTIATE)

	run.resolve_turn()

	assert_eq(run.haul.carried_by("squad"), Fixtures.VAULT_VALUE / 2)
	assert_eq(run.haul.carried_by("rival"), Fixtures.VAULT_VALUE / 2)
	assert_eq(run.loot.value_at("vault"), Fixtures.VAULT_VALUE % 2, "나머지가 방에 안 남았다")


func test_talking_to_someone_who_swings_gets_you_hit() -> void:
	# **E3 의 뒷면이다** — 한쪽만 쳤을 때만 보정이 붙는다 (§35.3.1).
	var run := Fixtures.run("vault")
	Fixtures.rival(run, "vault", "rival", 6, 3)
	Fixtures.hold(run, "squad", EncounterChoice.Kind.NEGOTIATE)
	Fixtures.hold(run, "rival", EncounterChoice.Kind.FIGHT)

	run.resolve_turn()
	var outcome := _outcome(run)

	assert_true(outcome.negotiated_ids.is_empty(), "혼자 말을 걸었는데 성립했다")
	assert_true(outcome.pressure_on("squad") > 0, "말을 걸다 맞았는데 안 밀렸다")
	assert_not_null(_marked(outcome, RelationEvent.Kind.AMBUSH), "선제 공격이 안 남았다")


# ---------------------------------------------------------------- 도주


func test_running_from_nobody_always_works() -> void:
	# **쫓는 자가 없으면 무조건 성공한다.** 이것이 있어야 동시 선택이 무겁다.
	var run := Fixtures.run("vault")
	Fixtures.rival(run, "vault", "rival", 4, 3)
	Fixtures.hold(run, "squad", EncounterChoice.Kind.FLEE)
	Fixtures.hold(run, "rival", EncounterChoice.Kind.NEGOTIATE)

	run.resolve_turn()

	assert_true(_outcome(run).fled_ids.has("squad"), "아무도 안 쫓는데 못 도망쳤다")
	assert_ne(run.player_room_id(), "vault", "도망쳤는데 그 방에 있다")


func test_you_run_back_the_way_you_came() -> void:
	# 아무 방향이 아니라 온 곳이다. 도망친 곳을 알 수 있어야 추격이 성립한다.
	var run := Fixtures.run("hall")
	Fixtures.rival(run, "vault", "rival", 4, 3)
	run.submit_intent(TurnIntent.move("squad", "vault").facing(EncounterChoice.Kind.FLEE))
	Fixtures.hold(run, "rival", EncounterChoice.Kind.NEGOTIATE)

	run.resolve_turn()

	assert_eq(run.player_room_id(), "hall", "온 곳으로 안 돌아갔다")


func test_being_cornered_is_not_running() -> void:
	# 갈 데가 없다. **갇힌 것이지 안 도망친 것이 아니다.**
	var run := _cell()
	run.submit_intent(TurnIntent.stay("squad").facing(EncounterChoice.Kind.FLEE))
	run.submit_intent(TurnIntent.stay("rival").facing(EncounterChoice.Kind.NEGOTIATE))

	run.resolve_turn()

	assert_true(_outcome(run).failed_flight_ids.has("squad"))
	assert_eq(run.player_room_id(), "cell")


func test_carrying_more_makes_running_harder() -> void:
	# §5.9 가 탈출에 대해 적은 것과 같은 논리다 — 챙긴 것이 발을 묶어야 한다.
	var run := Fixtures.run("vault")
	var rival := Fixtures.rival(run, "vault", "rival", 4, 3)
	var stakes := EncounterStakes.of(Room.Kind.TREASURE, 0)
	var chasers: Array[Actor] = [run.player]
	var light := run.encounters.flight_chance(rival, chasers, stakes)
	run.haul.add("rival", 5)

	assert_true(run.encounters.flight_chance(rival, chasers, stakes) < light, "짐을 지고도 똑같이 도망친다")


func test_a_hazard_room_is_easier_to_slip_out_of() -> void:
	# **E5** — 함정방을 쓸 데가 있는 방으로 만든다 (§35.3.2).
	var run := Fixtures.run("vault")
	var rival := Fixtures.rival(run, "vault", "rival", 4, 3)
	var chasers: Array[Actor] = [run.player]

	assert_true(
		(
			run.encounters.flight_chance(rival, chasers, EncounterStakes.of(Room.Kind.HAZARD, 0))
			> run.encounters.flight_chance(
				rival, chasers, EncounterStakes.of(Room.Kind.TREASURE, 0)
			)
		),
		"함정방이 도주를 안 도왔다"
	)


# ---------------------------------------------------------------- E9 협력과 E8 배신


func test_two_who_help_each_other_face_the_monster_together() -> void:
	# §5.6 E9 — *"협력해서 몬스터와 싸울지, 각자 싸울지 선택"*.
	var run := Fixtures.run("vault")
	Fixtures.rival(run, "vault", "rival", 6, 3)
	Fixtures.monster(run, "vault", "beast", 10)
	Fixtures.hold(run, "squad", EncounterChoice.Kind.COOPERATE)
	Fixtures.hold(run, "rival", EncounterChoice.Kind.COOPERATE)

	run.resolve_turn()
	var outcome := _outcome(run)

	assert_true(outcome.allied_ids.has("squad") and outcome.allied_ids.has("rival"))
	assert_true(outcome.pressure_on("beast") > 0, "둘이 붙었는데 몬스터가 안 밀렸다")
	assert_not_null(_marked(outcome, RelationEvent.Kind.COOPERATION))


func test_each_for_themselves_lets_the_monster_hit_both() -> void:
	# §5.6 E9 의 뒷면이다 — 협력을 안 고르면 **몬스터가 양쪽을 친다.**
	# 그리고 몬스터가 이긴 판은 **관계도에 아무것도 안 남긴다** —
	# `RelationGraph` 는 인물끼리의 것이라(§24.2) 몬스터가 설 자리가 없다.
	var run := Fixtures.run("vault")
	Fixtures.rival(run, "vault", "rival", 4, 3)
	Fixtures.monster(run, "vault", "beast", 30)

	run.resolve_turn()
	var outcome := _outcome(run)

	assert_true(outcome.subdued_ids.has("squad"), "스쿼드가 안 눕었다")
	assert_true(outcome.subdued_ids.has("rival"), "경쟁자가 안 눕었다")
	assert_null(_marked(outcome, RelationEvent.Kind.PLUNDER), "몬스터가 관계도에 올랐다")


func test_turning_on_yesterdays_partner_is_betrayal() -> void:
	# §5.6 E8 — 협력과 배신. **조우가 여러 턴에 걸치므로 자리가 생겼다** (§35.4.2).
	var run := Fixtures.run("vault")
	Fixtures.rival(run, "vault", "rival", 6, 3)
	Fixtures.monster(run, "vault", "beast", 10)
	Fixtures.hold(run, "squad", EncounterChoice.Kind.COOPERATE)
	Fixtures.hold(run, "rival", EncounterChoice.Kind.COOPERATE)
	run.resolve_turn()

	Fixtures.hold(run, "squad", EncounterChoice.Kind.COOPERATE)
	Fixtures.hold(run, "rival", EncounterChoice.Kind.FIGHT)
	run.resolve_turn()
	var mark := _marked(_outcome(run), RelationEvent.Kind.BETRAYAL)

	assert_not_null(mark, "어제의 동료를 쳤는데 배신이 안 남았다")
	assert_eq(mark.actor_id, "rival")


func test_fighting_side_by_side_twice_is_not_betrayal() -> void:
	# 오늘도 같은 편이면 배신이 아니다. 안 가르면 **함께 싸울수록 사이가 나빠진다.**
	var run := Fixtures.run("vault")
	Fixtures.rival(run, "vault", "rival", 6, 3)
	Fixtures.monster(run, "vault", "beast", 10)
	for _turn in 2:
		Fixtures.hold(run, "squad", EncounterChoice.Kind.COOPERATE)
		Fixtures.hold(run, "rival", EncounterChoice.Kind.COOPERATE)
		run.resolve_turn()

	assert_null(_marked(_outcome(run), RelationEvent.Kind.BETRAYAL), "함께 싸웠는데 배신으로 적혔다")
