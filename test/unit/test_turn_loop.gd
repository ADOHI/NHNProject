extends GutTest
## 계획 페이즈와 행동 페이즈. **docs/design/03-core-loop.md §3.1 · §4.3.**
##
## *"계획과 행동을 나눈 것이 이 게임의 정체성이다.
## 계획 시점에는 정보가 불완전하고, 행동 시점에는 되돌릴 수 없다."*
##
## 여기서 보는 것은 **판이 두 국면을 실제로 나누고 있는가**다.
## 규칙의 내용은 `test_turn_resolver.gd` 와 `test_turn_encounter.gd` 가 맡는다.

const Fixtures := preload("res://test/support/turn_fixtures.gd")

# ---------------------------------------------------------------- 국면


func test_a_run_begins_by_letting_you_read() -> void:
	var run := Fixtures.run("hall")

	assert_eq(run.phase, TurnPhase.Kind.PLANNING)
	assert_true(run.accepts_input())


func test_the_phase_returns_to_planning_after_a_turn() -> void:
	# 행동 페이즈는 조작을 받지 않는다. 한 턴이 풀린 뒤에는 다시 읽는 시간이다.
	var run := Fixtures.run("hall")
	run.resolve_turn()

	assert_eq(run.phase, TurnPhase.Kind.PLANNING)
	assert_true(run.accepts_input())


# ---------------------------------------------------------------- 의도


func test_a_plan_can_be_changed_until_it_is_committed() -> void:
	# §4.3 — 확정 전 계획 변경 가능. 확정은 resolve_turn() 이다.
	var run := Fixtures.run("hall")
	run.submit_intent(TurnIntent.move("squad", "vault"))
	run.submit_intent(TurnIntent.move("squad", "gate"))

	run.resolve_turn()

	assert_eq(run.player_room_id(), "gate", "나중에 낸 계획이 안 이겼다")


func test_a_plan_can_be_taken_back() -> void:
	var run := Fixtures.run("hall")
	run.submit_intent(TurnIntent.move("squad", "vault"))
	run.clear_intent("squad")

	assert_null(run.player_intent())
	run.resolve_turn()
	assert_eq(run.player_room_id(), "hall", "물린 계획이 실행됐다")


func test_intents_do_not_survive_the_turn() -> void:
	# 남아 있으면 다음 턴에 저절로 같은 짓을 한다. 매 턴 다시 정하는 것이 이 게임이다.
	var run := Fixtures.run("hall")
	run.submit_intent(TurnIntent.move("squad", "vault"))
	run.resolve_turn()

	assert_null(run.player_intent())


func test_no_intent_means_standing_still() -> void:
	# 빠진 주체를 따로 처리하는 분기는 반드시 빠뜨리는 곳이 생긴다.
	var run := Fixtures.run("hall")

	var report := run.resolve_turn()

	assert_eq(run.player_room_id(), "hall")
	assert_true(report.moved_actor_ids.is_empty())


# ---------------------------------------------------------------- 기존 조작


func test_moving_the_player_still_works_the_old_way() -> void:
	# base_screen.gd · dungeon_board.gd · capture_rekka_feed.gd 가 이것을 부른다.
	# 달라진 것은 안쪽뿐이어야 한다.
	var run := Fixtures.run("hall")

	assert_true(run.move_player("vault"))
	assert_eq(run.player_room_id(), "vault")
	assert_eq(run.turn, 2)


func test_a_blocked_move_costs_nothing() -> void:
	var run := Fixtures.run("hall")

	assert_false(run.move_player("deep"), "이어지지 않은 방으로 갔다")
	assert_eq(run.turn, 1, "성사되지 않은 이동이 턴을 먹었다")
	assert_eq(run.walk.steps(), 0)


func test_walking_still_leaves_a_trace() -> void:
	var run := Fixtures.run("hall")
	run.move_player("vault")
	run.move_player("hall")

	assert_eq(run.walk.steps(), 2)
	assert_eq(run.walk.backtracks(), 1, "되돌아 나왔는데 안 셌다")


func test_searching_takes_a_whole_turn() -> void:
	var run := Fixtures.run("vault")

	assert_true(run.search_here())
	assert_eq(run.turn, 2, "탐색이 턴을 안 먹었다")
	assert_eq(run.haul.carried_by("squad"), Fixtures.VAULT_VALUE)


# ---------------------------------------------------------------- 신호


func test_a_resolved_turn_is_announced() -> void:
	# 렉카 피드가 여기에 붙을 수 있어야 한다 (§32.1 — 조용한 턴에도 기사는 나간다).
	var run := Fixtures.run("hall")
	watch_signals(run)

	run.resolve_turn()

	assert_signal_emitted(run, "turn_resolved")


func test_moving_still_announces_itself() -> void:
	var run := Fixtures.run("hall")
	watch_signals(run)

	run.move_player("vault")

	assert_signal_emitted(run, "player_moved")


# ---------------------------------------------------------------- 한 판이 돈다


func test_the_whole_board_moves_in_the_same_turn() -> void:
	# **이 저장소의 가장 큰 구멍이 이것이었다** — 부품은 많은데 한 판이 안 돌았다.
	var run := Fixtures.run("hall")
	var rival := Fixtures.rival(run, "gate")

	run.move_player("vault")

	assert_eq(run.player_room_id(), "vault")
	assert_ne(run.graph.find_actor_room(rival), "gate", "플레이어만 움직였다")
