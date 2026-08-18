extends GutTest
## 동시 해결의 경계 상황. **docs/design/05-rules.md §5.6 의 표가 이 파일의 명세다.**
##
## §5.6 은 동시 해결(§3.6)의 **대가**로 정의해야 하는 상황을 아홉 개 적어 뒤,
## 넷을 확정하고 둘을 보류하고 셋의 방향만 잡았다. 확정된 것과 방향이 잡힌 것을
## 항목마다 여기서 잠근다.
##
## | 여기서 잠그는 것 | |
## | --- | --- |
## | E1 | 둘이 같은 방에 동시 진입 → 조우 발생 |
## | E2 | 서로 지나쳐 감 → **아무 일도 없다. 단 서로를 봤다** |
## | E4 | 공격 대상이 그 턴에 도망감 |
## | E6 | 협상 중 제3자 난입 |
## | E9 | 몬스터방에서 탐험가끼리 조우 |
##
## **E3 · E5 는 시험이 없다. 그것이 의도다** — §5.6 이 보류로 남겼고,
## *"지금 정하면 구현 중에 어차피 뒤집힌다"* 고 적었다.

const Fixtures := preload("res://test/support/turn_fixtures.gd")


func _encountered(report: TurnReport) -> Array[GameEvent]:
	var found: Array[GameEvent] = []
	for event in report.events:
		if event.kind == GameEvent.Kind.ENCOUNTERED:
			found.append(event)
	return found


# ---------------------------------------------------------------- E1


func test_e1_two_entering_the_same_room_meet() -> void:
	var run := Fixtures.run("hall")
	Fixtures.rival(run, "deep")
	run.submit_intent(TurnIntent.move("squad", "vault"))
	run.submit_intent(TurnIntent.move("rival", "vault"))

	var report := run.resolve_turn()

	assert_eq(report.encounters.size(), 1, "같은 방에 들어갔는데 조우가 안 났다")
	assert_eq(report.encounters[0].room_id, "vault")
	assert_true(report.encounters[0].is_between_explorers())


func test_e1_leaves_an_event_in_the_log() -> void:
	# 조우는 렉카 기사의 최고 소재다. 기록되지 않으면 기사가 나오지 않는다.
	var run := Fixtures.run("hall")
	Fixtures.rival(run, "deep")
	run.submit_intent(TurnIntent.move("squad", "vault"))
	run.submit_intent(TurnIntent.move("rival", "vault"))

	var report := run.resolve_turn()

	assert_eq(_encountered(report).size(), 1)
	assert_eq(_encountered(report)[0].room_name, "금고", "기사에 장소는 사실로 들어간다")
	assert_true(_encountered(report)[0].related_actor_ids.has("rival"), "상대가 안 엮였다")


func test_e1_also_leaves_a_sighting() -> void:
	# 같은 방에 섰으면 당연히 본 것이다. "봤다"는 한 곳에서만 만들어져야 한다.
	var run := Fixtures.run("hall")
	Fixtures.rival(run, "deep")
	run.submit_intent(TurnIntent.move("squad", "vault"))
	run.submit_intent(TurnIntent.move("rival", "vault"))

	var report := run.resolve_turn()

	assert_true(report.saw("squad", "rival"))
	assert_true(report.saw("rival", "squad"))


# ---------------------------------------------------------------- E2


func test_e2_passing_each_other_changes_nothing_on_the_board() -> void:
	# §5.6 E2 — "아무 일도 없다". 통로에는 아무것도 없다.
	var run := Fixtures.run("hall")
	var rival := Fixtures.rival(run, "vault")
	run.submit_intent(TurnIntent.move("squad", "vault"))
	run.submit_intent(TurnIntent.move("rival", "hall"))

	var report := run.resolve_turn()

	assert_eq(run.player_room_id(), "vault", "서로 지나가지 못했다")
	assert_eq(run.graph.find_actor_room(rival), "hall")
	assert_true(report.encounters.is_empty(), "지나쳐 갔는데 조우가 났다")
	assert_eq(_encountered(report).size(), 0, "사건이 아닌 것이 기록됐다")


func test_e2_still_leaves_the_information() -> void:
	# **뒷문장이 본체다** — "단 서로를 봤다는 정보는 얻는다".
	# 아무 일도 없게 만드는 것은 쉽고, 그러면서 정보만 남기는 것이 어렵다.
	var run := Fixtures.run("hall")
	Fixtures.rival(run, "vault")
	run.submit_intent(TurnIntent.move("squad", "vault"))
	run.submit_intent(TurnIntent.move("rival", "hall"))

	var report := run.resolve_turn()

	assert_true(report.saw("squad", "rival"), "지나친 상대를 못 봤다")
	assert_true(report.saw("rival", "squad"), "한쪽만 봤다")


func test_e2_tells_where_the_other_one_went() -> void:
	# 회피를 실질적 선택지로 만드는 정보다 — 상대가 어디로 갔는지까지 알려 준다.
	var run := Fixtures.run("hall")
	Fixtures.rival(run, "vault")
	run.submit_intent(TurnIntent.move("squad", "vault"))
	run.submit_intent(TurnIntent.move("rival", "hall"))

	var seen := run.resolve_turn().sightings_by("squad")

	assert_eq(seen.size(), 1)
	assert_true(seen[0].crossed, "교차가 같은 방 목격과 구분되지 않는다")
	assert_eq(seen[0].room_id, "hall", "상대가 들어간 방이 아니다")
	assert_eq(seen[0].seen_name, "칼날의 rival", "이름이 안 남았다")


func test_walking_side_by_side_is_not_a_crossing() -> void:
	# 같은 방향으로 나란히 걸은 것은 교차가 아니다. 서로를 지나치지 않았다.
	var run := Fixtures.run("hall")
	Fixtures.rival(run, "hall")
	run.submit_intent(TurnIntent.move("squad", "vault"))
	run.submit_intent(TurnIntent.move("rival", "vault"))

	var report := run.resolve_turn()

	for sighting in report.sightings:
		assert_false(sighting.crossed, "나란히 걸었는데 교차로 셌다")


# ---------------------------------------------------------------- E4


func test_e4_the_one_who_fled_is_not_there_anymore() -> void:
	# 이동이 조우보다 **먼저** 풀린다. 그래서 도망친 쪽은 판정 시점에 그 방에 없다.
	var run := Fixtures.run("vault")
	Fixtures.rival(run, "hall")
	run.submit_intent(TurnIntent.move("squad", "deep"))
	run.submit_intent(TurnIntent.move("rival", "vault"))

	var report := run.resolve_turn()

	assert_true(report.encounters.is_empty(), "빠져나갔는데 붙잡혔다")
	assert_eq(run.player_room_id(), "deep")


# ---------------------------------------------------------------- E6 · 조우 유지


func test_staying_together_is_not_a_new_event() -> void:
	# §5.8 — "전투 지속 → 다음 턴에도 조우 상태". 이어지는 상태는 새 사건이 아니다.
	# 안 그러면 몬스터방에 서 있는 동안 매 턴 같은 기사가 나간다.
	var run := Fixtures.run("hall")
	Fixtures.rival(run, "hall")

	run.submit_intent(TurnIntent.stay("rival"))
	var first := run.resolve_turn()
	run.submit_intent(TurnIntent.stay("rival"))
	var second := run.resolve_turn()

	assert_eq(_encountered(first).size(), 1, "처음 마주친 것이 사건이 아니다")
	assert_eq(second.encounters.size(), 1, "조우 상태가 풀렸다")
	assert_eq(_encountered(second).size(), 0, "같은 조합인데 또 기사가 나갔다")


func test_e6_a_third_one_joining_is_a_new_encounter() -> void:
	# §5.6 E6 — 협상은 1턴 안에 끝나므로 **턴을 넘는 협상 상태가 없다.**
	# 난입은 별도 기능이 아니라 그냥 **참가자 조합이 달라진 것**이다.
	var run := Fixtures.run("hall")
	Fixtures.rival(run, "hall")
	Fixtures.rival(run, "vault", "second")
	run.submit_intent(TurnIntent.stay("rival"))
	run.submit_intent(TurnIntent.stay("second"))
	run.resolve_turn()

	run.submit_intent(TurnIntent.stay("rival"))
	run.submit_intent(TurnIntent.move("second", "hall"))
	var report := run.resolve_turn()

	assert_eq(_encountered(report).size(), 1, "조합이 바뀌었는데 사건이 안 났다")
	assert_eq(report.encounters[0].participant_ids.size(), 3)


# ---------------------------------------------------------------- E9


func test_e9_monsters_and_explorers_are_kept_apart() -> void:
	# §5.6 E9 — "협력해서 몬스터와 싸울지, 각자 싸울지 선택".
	# 그 선택은 §5.8 의 것이고, 이 레인은 **고를 것을 갈라서 준다.**
	var run := Fixtures.run("hall")
	Fixtures.monster(run, "vault")
	Fixtures.rival(run, "deep")
	run.submit_intent(TurnIntent.move("squad", "vault"))
	run.submit_intent(TurnIntent.move("rival", "vault"))

	var encounter := run.resolve_turn().encounters[0]

	assert_true(encounter.has_monsters())
	assert_true(encounter.is_between_explorers())
	assert_eq(encounter.monster_ids, ["beast"] as Array[String])
	assert_eq(encounter.explorer_ids.size(), 2, "탐험가 둘이 안 갈렸다")


func test_monsters_alone_do_not_encounter_each_other() -> void:
	# 함정방에 사냥개 셋이 같이 있는 것은 **배치**이지 사건이 아니다.
	var run := Fixtures.run("hall")
	Fixtures.monster(run, "deep", "hound_a")
	Fixtures.monster(run, "deep", "hound_b")

	var report := run.resolve_turn()

	assert_true(report.encounters.is_empty(), "몬스터끼리 조우가 났다")


func test_the_lead_of_an_encounter_is_never_a_monster() -> void:
	# 몬스터를 주인공으로 세우면 기사가 사람 이야기가 아니게 된다 (§8.3.6).
	var run := Fixtures.run("hall")
	Fixtures.monster(run, "vault")
	run.submit_intent(TurnIntent.move("squad", "vault"))

	var report := run.resolve_turn()

	assert_eq(_encountered(report)[0].actor_id, "squad")
	assert_true(_encountered(report)[0].related_actor_ids.has("beast"))


# ---------------------------------------------------------------- 순서


func test_an_encounter_blocks_searching_that_room() -> void:
	# 조우가 상호작용보다 **먼저** 풀리는 이유다.
	# 마주친 방에서 태연히 상자를 뒤지면 안 된다.
	var run := Fixtures.run("vault")
	Fixtures.rival(run, "hall")
	run.submit_intent(TurnIntent.search("squad"))
	run.submit_intent(TurnIntent.move("rival", "vault"))

	run.resolve_turn()

	assert_eq(run.haul.carried_by("squad"), 0, "마주친 방에서 상자를 뒤졌다")
	assert_eq(run.loot.value_at("vault"), Fixtures.VAULT_VALUE, "귀중품이 사라졌다")
