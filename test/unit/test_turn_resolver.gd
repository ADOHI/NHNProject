extends GutTest
## 해결기의 다섯 단계. **docs/design/33-turn-loop.md §33.1 이 순서를 확정했다.**
##
##     이동 -> 조우 판정 -> 상호작용 -> 결과 -> 사건 기록
##
## 경계 상황(E1~E9)은 `test_turn_encounter.gd` 가, 탈출은 `test_turn_escape.gd` 가 맡는다.
## 여기서 보는 것은 **순서 자체와 기록의 단일 통로**다.

const Fixtures := preload("res://test/support/turn_fixtures.gd")


func _kinds(report: TurnReport) -> Array[int]:
	var found: Array[int] = []
	for event in report.events:
		found.append(int(event.kind))
	return found


# ---------------------------------------------------------------- 턴과 기록


func test_a_quiet_turn_is_still_a_turn() -> void:
	# 아무도 아무것도 안 해도 턴은 넘어간다. **조용한 턴에도 기사는 나간다** (§32.1).
	var run := Fixtures.run("hall")

	var report := run.resolve_turn()

	assert_eq(report.turn, 1, "리포트가 방금 푼 턴을 가리키지 않는다")
	assert_eq(run.turn, 2, "턴이 안 올랐다")
	assert_true(report.is_quiet())


func test_the_turn_rises_after_the_events_are_written() -> void:
	# 순서를 뒤집으면 main.gd 의 _publish_turn() 이 빈 턴을 낸다 — 그쪽은 turn-1 을 읽는다.
	var run := Fixtures.run("hall")
	run.submit_intent(TurnIntent.move("squad", "vault"))

	run.resolve_turn()

	assert_eq(run.turn, 2)
	assert_eq(run.event_log.events_in_turn(1).size(), 1, "직전 턴에 사건이 안 남았다")
	assert_true(run.event_log.events_in_turn(2).is_empty(), "이번 턴에 미리 적혔다")


func test_the_log_is_written_in_exactly_one_place() -> void:
	# 단계마다 제각기 로그에 쓰면 기록을 빠뜨린 경로가 생긴다 (§16.2).
	var run := Fixtures.run("vault")
	Fixtures.monster(run, "deep")
	run.submit_intent(TurnIntent.search("squad"))

	var report := run.resolve_turn()

	assert_eq(run.event_log.count(), report.events.size(), "리포트와 로그가 어긋난다")
	for event in report.events:
		assert_eq(event.turn, 1)


# ---------------------------------------------------------------- 1. 이동


func test_an_intent_is_checked_again_at_resolution() -> void:
	# **의도는 약속이지 결과가 아니다.** 낼 때 갈 수 있었어도 성사되지 않을 수 있다.
	var run := Fixtures.run("hall")
	run.submit_intent(TurnIntent.move("squad", "deep"))

	var report := run.resolve_turn()

	assert_false(report.did_move("squad"), "이어지지 않은 방으로 갔다")
	assert_true(report.refused_actor_ids.has("squad"), "거절이 안 남았다")
	assert_eq(run.player_room_id(), "hall")


func test_a_refused_intent_leaves_no_event() -> void:
	var run := Fixtures.run("hall")
	run.submit_intent(TurnIntent.move("squad", "없는 방"))

	var report := run.resolve_turn()

	assert_true(report.events.is_empty(), "성사되지 않은 이동이 기록됐다")


func test_a_move_remembers_where_it_came_from() -> void:
	# 걸음 기록과 화면 연출이 이것을 읽는다.
	var run := Fixtures.run("hall")
	run.submit_intent(TurnIntent.move("squad", "vault"))

	var report := run.resolve_turn()

	assert_eq(report.moved_from("squad"), "hall")
	assert_eq(report.moved_to("squad"), "vault")


func test_everyone_moves_at_the_same_time() -> void:
	# 동시 해결 — 먼저 움직인 쪽이 남의 결과를 보고 정하면 안 된다 (§3.6).
	var run := Fixtures.run("hall")
	var rival := Fixtures.rival(run, "vault")
	run.submit_intent(TurnIntent.move("squad", "vault"))
	run.submit_intent(TurnIntent.move("rival", "deep"))

	run.resolve_turn()

	assert_eq(run.player_room_id(), "vault")
	assert_eq(run.graph.find_actor_room(rival), "deep", "남의 이동에 막혔다")


# ---------------------------------------------------------------- 순서


func test_moving_is_recorded_before_meeting() -> void:
	# 순서가 곧 규칙이다. 이동이 조우보다 먼저 풀린다.
	var run := Fixtures.run("hall")
	Fixtures.monster(run, "vault")
	run.submit_intent(TurnIntent.move("squad", "vault"))

	var kinds := _kinds(run.resolve_turn())

	assert_eq(kinds[0], int(GameEvent.Kind.MOVED))
	assert_eq(kinds[1], int(GameEvent.Kind.ENCOUNTERED))


# ---------------------------------------------------------------- 3. 상호작용


func test_searching_a_vault_gives_what_is_there() -> void:
	var run := Fixtures.run("vault")
	run.submit_intent(TurnIntent.search("squad"))

	var report := run.resolve_turn()

	assert_eq(run.haul.carried_by("squad"), Fixtures.VAULT_VALUE)
	assert_eq(report.events[0].kind, GameEvent.Kind.ACQUIRED)
	assert_eq(report.events[0].magnitude, Fixtures.VAULT_VALUE, "얼마나가 안 실렸다")


func test_searching_an_empty_room_is_still_an_event() -> void:
	# 빈손도 정보다. 기록하지 않으면 "뒤졌는데 없었다"가 기사에 안 나간다.
	var run := Fixtures.run("hall")
	run.submit_intent(TurnIntent.search("squad"))

	var report := run.resolve_turn()

	assert_eq(report.events[0].kind, GameEvent.Kind.SEARCHED)
	assert_eq(report.events[0].magnitude, 0)


func test_the_second_one_to_arrive_finds_nothing() -> void:
	# **던전의 귀중품은 유한하다** (§5.2). 이것이 NPC 를 경쟁자로 만든다.
	var run := Fixtures.run("vault")
	Fixtures.rival(run, "deep")
	run.submit_intent(TurnIntent.search("squad"))
	run.submit_intent(TurnIntent.stay("rival"))
	run.resolve_turn()

	# 자리를 비켜 준다. 남아 있으면 조우가 나서 **다른 이유로** 못 뒤진다.
	run.submit_intent(TurnIntent.move("squad", "hall"))
	run.submit_intent(TurnIntent.move("rival", "vault"))
	run.resolve_turn()
	run.submit_intent(TurnIntent.search("rival"))
	run.resolve_turn()

	assert_eq(run.haul.carried_by("squad"), Fixtures.VAULT_VALUE)
	assert_eq(run.haul.carried_by("rival"), 0, "이미 털린 방에서 무언가를 얻었다")
