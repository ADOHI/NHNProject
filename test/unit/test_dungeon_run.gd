extends GutTest
## DungeonRun 과 표본 던전의 단위 테스트.
##
## 화면 없이 판이 굴러가는지 확인한다. 이동이 성사되면 반드시 사건으로 남아야 하고,
## 기록되지 않은 이동이 생기면 렉카 기사와 세계 갱신이 판과 어긋난다
## (docs/design/16-build-order.md §16.2).

const SampleScript := preload("res://src/core/dungeon/sample_dungeons.gd")


func _make_run() -> DungeonRun:
	return SampleScript.create_first_run()


# ---------------------------------------------------------------- 시작 상태


func test_run_starts_at_entrance() -> void:
	var run := _make_run()
	assert_eq(run.player_room_id(), "entrance")
	assert_eq(run.turn, 1)
	assert_true(run.event_log.is_empty())


func test_entrance_shows_the_sum_of_its_neighbors() -> void:
	# 서쪽 회랑(칼날의 요한 4) + 저수조(물귀신 1+1) = 6
	var run := _make_run()
	assert_eq(run.adjacent_threat(), 6)


func test_player_threat_is_not_counted_in_its_own_view() -> void:
	# 스쿼드 전투력 8 이 인접 합에 섞이면 판이 거짓말을 한다.
	var run := _make_run()
	assert_eq(run.player.threat, 8)
	assert_eq(run.adjacent_threat(), 6)


func test_reachable_rooms_are_the_neighbors() -> void:
	var run := _make_run()
	var reachable := run.reachable_room_ids()
	assert_eq(reachable.size(), 2)
	assert_true(reachable.has("west_hall"))
	assert_true(reachable.has("cistern"))
	assert_false(run.can_move_to("shrine"), "이어지지 않은 방에 갈 수 있다고 나온다")


# ---------------------------------------------------------------- 이동


func test_move_updates_position_turn_and_log() -> void:
	var run := _make_run()
	assert_true(run.move_player("west_hall"))
	assert_eq(run.player_room_id(), "west_hall")
	assert_eq(run.turn, 2)
	assert_eq(run.event_log.count(), 1)
	assert_eq(run.event_log.all()[0].kind, GameEvent.Kind.MOVED)
	assert_eq(run.event_log.all()[0].room_name, "서쪽 회랑")


func test_illegal_move_changes_nothing() -> void:
	var run := _make_run()
	assert_false(run.move_player("vault"))
	assert_eq(run.player_room_id(), "entrance")
	assert_eq(run.turn, 1)
	assert_true(run.event_log.is_empty(), "실패한 이동이 사건으로 기록됐다")


func test_move_emits_signal() -> void:
	var run := _make_run()
	watch_signals(run)
	run.move_player("cistern")
	assert_signal_emitted(run, "player_moved")


func test_the_visible_number_changes_as_you_walk() -> void:
	# 판을 걸어 다니면 보이는 숫자가 바뀐다 — 이게 플레이어가 읽는 유일한 정보다.
	var run := _make_run()
	assert_eq(run.adjacent_threat(), 6)

	run.move_player("cistern")
	# 저수조 인접 = 입구(0) + 제단(제단 수호자 5) = 5
	assert_eq(run.adjacent_threat(), 5)


# ---------------------------------------------------------------- 표본 던전의 의도


func test_vault_and_kennel_look_identical_by_number() -> void:
	# 이 표본 던전의 존재 이유. 봉인된 금고와 사육장은 합이 똑같이 6 이지만
	# 하나는 보스 하나, 하나는 무리 셋이다. 숫자만으로는 구분되지 않는다
	# (docs/design/07-level-design.md §7.2.1).
	var run := _make_run()
	assert_eq(run.graph.threat_at("vault"), 6)
	assert_eq(run.graph.threat_at("kennel"), 6)
	assert_eq(run.graph.get_room("vault").occupant_count(), 1)
	assert_eq(run.graph.get_room("kennel").occupant_count(), 3)


func test_shrine_sees_both_sixes_as_one_number() -> void:
	# 제단에 서면 금고 6 · 사육장 6 · 전시실 2 · 저수조 2 가 하나의 16 으로 뭉친다.
	# 어느 쪽이 보스인지는 이 숫자로 알 수 없다.
	var run := _make_run()
	run.graph.place_actor(run.player, "shrine")
	assert_eq(run.adjacent_threat(), 16)
	assert_eq(run.graph.adjacent_occupant_count("shrine"), 7)
	assert_eq(run.graph.adjacent_max_threat("shrine"), 6)


func test_gallery_and_cistern_also_collide_at_two() -> void:
	# 작은 규모에서도 같은 모호함이 성립한다. 전시실 2(하나) 와 저수조 2(둘).
	var run := _make_run()
	assert_eq(run.graph.threat_at("gallery"), 2)
	assert_eq(run.graph.threat_at("cistern"), 2)
	assert_eq(run.graph.get_room("gallery").occupant_count(), 1)
	assert_eq(run.graph.get_room("cistern").occupant_count(), 2)


func test_npc_explorer_is_mobile_but_monsters_are_not() -> void:
	# 몬스터가 고정이라는 전제가 위험도 변화량 추론을 성립시킨다
	# (docs/design/13-information-design.md §13.5).
	var run := _make_run()
	var johan: Actor = run.graph.get_room("west_hall").occupants()[0]
	var warden: Actor = run.graph.get_room("vault").occupants()[0]
	assert_true(johan.is_mobile())
	assert_false(warden.is_mobile())
