extends GutTest
## 탈출과 정산. **docs/design/05-rules.md §5.9 · §5.3.**
##
## §5.9 — *"탈출은 즉시 이뤄지지 않는다."* 탈출 지점에서 몇 턴 버텨야 완료된다.
## **이 구간이 이 게임의 절정이다** — 다 챙기고 문 앞에서 죽는 것.
## 한 턴에 끝나면 그 장면이 아예 만들어지지 않는다.
##
## E7(탈출 중 공격받음)이 여기서 잠긴다. §5.6 은 방향만 정해 뒀고
## (*"소요 턴은 가변"*), 이 레인이 잠정으로 하나를 박았다 —
## **조우가 난 턴은 진행이 오르지 않는다.**

const Fixtures := preload("res://test/support/turn_fixtures.gd")


func _escaped(report: TurnReport) -> Array[GameEvent]:
	var found: Array[GameEvent] = []
	for event in report.events:
		if event.kind == GameEvent.Kind.ESCAPED:
			found.append(event)
	return found


# ---------------------------------------------------------------- 버티기


func test_escaping_is_not_instant() -> void:
	var run := Fixtures.run("gate")

	var held := run.hold_at_exit()

	assert_true(held, "탈출 지점에서 버티지 못했다")
	assert_false(run.finished, "한 턴 만에 나갔다")
	assert_eq(run.escape_progress(), 1)


func test_holding_long_enough_gets_you_out() -> void:
	var run := Fixtures.run("gate")

	for _turn in TurnResolver.ESCAPE_TURNS:
		run.hold_at_exit()

	assert_true(run.finished, "버텼는데 못 나갔다")
	assert_eq(run.escape_turns_left(), 0)


func test_getting_out_is_an_event() -> void:
	# 탈출 시도는 렉카 기사의 최고 소재다 (§5.9).
	var run := Fixtures.run("gate")
	run.hold_at_exit()
	run.hold_at_exit()
	var report := run.last_report

	assert_eq(_escaped(report).size(), 1)
	assert_eq(_escaped(report)[0].room_name, "관문")


func test_you_cannot_hold_where_there_is_no_exit() -> void:
	var run := Fixtures.run("hall")

	assert_false(run.hold_at_exit(), "탈출 지점이 아닌데 버티기가 받아들여졌다")
	assert_eq(run.turn, 1, "성사되지 않은 행동이 턴을 먹었다")


func test_an_escape_intent_away_from_the_exit_is_refused() -> void:
	# 의도는 약속이지 결과가 아니다. 화면을 거치지 않고 들어온 의도도 해결기가 막는다.
	var run := Fixtures.run("hall")
	run.submit_intent(TurnIntent.escape("squad"))

	var report := run.resolve_turn()

	assert_true(report.refused_actor_ids.has("squad"))
	assert_eq(run.escape_progress(), 0)


# ---------------------------------------------------------------- E7


func test_e7_being_met_costs_you_the_turn() -> void:
	# §5.6 E7 — 탈출 중 공격받음. 버티지 못했다는 뜻이다.
	var run := Fixtures.run("gate")
	Fixtures.rival(run, "hall")
	run.submit_intent(TurnIntent.escape("squad"))
	run.submit_intent(TurnIntent.move("rival", "gate"))

	run.resolve_turn()

	assert_eq(run.escape_progress(), 0, "마주쳤는데 탈출이 진행됐다")
	assert_false(run.finished)


func test_e7_does_not_take_back_what_was_already_held() -> void:
	# 되돌리면 조우가 잦은 판에서 탈출이 영영 안 끝난다.
	var run := Fixtures.run("gate")
	Fixtures.rival(run, "hall")
	run.submit_intent(TurnIntent.escape("squad"))
	run.submit_intent(TurnIntent.stay("rival"))
	run.resolve_turn()

	run.submit_intent(TurnIntent.escape("squad"))
	run.submit_intent(TurnIntent.move("rival", "gate"))
	run.resolve_turn()

	assert_eq(run.escape_progress(), 1, "버틴 것이 지워졌다")


# ---------------------------------------------------------------- 정산


func test_what_you_carried_out_becomes_yours() -> void:
	# §5.3 — 탈출 시 획득 확정.
	var run := Fixtures.run("vault")
	run.submit_intent(TurnIntent.search("squad"))
	run.resolve_turn()
	run.move_player("hall")
	run.move_player("gate")
	for _turn in TurnResolver.ESCAPE_TURNS:
		run.hold_at_exit()

	assert_eq(run.haul.banked_by("squad"), Fixtures.VAULT_VALUE, "가지고 나온 것이 안 남았다")
	assert_eq(run.haul.carried_by("squad"), 0, "아직 들고 있는 것으로 잡힌다")


func test_the_escape_event_says_how_much_came_out() -> void:
	# 얼마나 — 기사에서 유일하게 과장되는 값이고, 로그에는 진실이 들어간다 (§13.3.1).
	var run := Fixtures.run("vault")
	run.submit_intent(TurnIntent.search("squad"))
	run.resolve_turn()
	run.move_player("hall")
	run.move_player("gate")
	run.hold_at_exit()
	run.hold_at_exit()

	assert_eq(_escaped(run.last_report)[0].magnitude, Fixtures.VAULT_VALUE)


# ---------------------------------------------------------------- 판이 끝난다


func test_the_run_stops_taking_orders_once_you_are_out() -> void:
	var run := Fixtures.run("gate")
	for _turn in TurnResolver.ESCAPE_TURNS:
		run.hold_at_exit()

	assert_false(run.accepts_input())
	assert_false(run.move_player("hall"), "나간 판이 아직 움직인다")
	assert_null(run.resolve_turn(), "끝난 판이 턴을 또 돌렸다")


func test_an_npc_who_gets_out_is_gone_from_the_board() -> void:
	# §5.2.2 — "플레이어가 늦게 도착하면 NPC 는 이미 나가고 없다."
	var run := Fixtures.run("hall")
	var rival := Fixtures.rival(run, "gate")
	for _turn in TurnResolver.ESCAPE_TURNS:
		run.submit_intent(TurnIntent.escape("rival"))
		run.submit_intent(TurnIntent.stay("squad"))
		run.resolve_turn()

	assert_eq(run.graph.find_actor_room(rival), "", "나간 NPC 가 판에 남아 있다")
	assert_eq(run.graph.threat_at("gate"), 0, "위험도에 유령이 남았다")


func test_the_player_stays_on_the_board_after_getting_out() -> void:
	# 판이 끝나면 지울 다음 턴이 없다. 지우면 화면이 마지막으로 그릴 때 빈 방을 가리킨다.
	var run := Fixtures.run("gate")
	for _turn in TurnResolver.ESCAPE_TURNS:
		run.hold_at_exit()

	assert_eq(run.player_room_id(), "gate")
