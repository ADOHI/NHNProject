extends GutTest
## DungeonRun 의 단위 테스트.
##
## 판은 절차적으로 생성되므로 특정 방 이름이나 수치를 기대하지 않는다.
## 대신 **어떤 판에서도 성립해야 하는 규칙**을 본다.
## 생성 규칙 자체는 test_dungeon_generator.gd 가 맡는다.

const RoomScript := preload("res://src/core/dungeon/room.gd")
const ActorScript := preload("res://src/core/dungeon/actor.gd")
const BlueprintScript := preload("res://src/core/dungeon/dungeon_blueprint.gd")
const RunScript := preload("res://src/core/dungeon/dungeon_run.gd")

const _SEED := 5


## 수치를 확정해 두고 검사하기 위한 손수 만든 판.
##
##   home(0) --- east(0) --- ledge(4)
##
## east 에는 위험도 3, ledge 에는 위험도 5 가 있고 ledge 는 상승 4 라 막혀 있다.
func _make_fixed_run(agility: int) -> DungeonRun:
	var blueprint: DungeonBlueprint = BlueprintScript.new()
	blueprint.add_room("home", "본거지", 0, Room.Kind.ENTRANCE)
	blueprint.add_room("east", "동쪽 방", 0)
	blueprint.add_room("ledge", "선반", 4)
	blueprint.connect_rooms("home", "east")
	blueprint.connect_rooms("home", "ledge")

	var graph := blueprint.build()
	graph.place_actor(ActorScript.new("m1", "몹", Actor.Kind.MONSTER, 3, 0), "east")
	graph.place_actor(ActorScript.new("m2", "높은 곳의 것", Actor.Kind.MONSTER, 5, 9), "ledge")

	var squad := ActorScript.new("squad", "스쿼드", Actor.Kind.PLAYER_SQUAD, 8, agility)
	graph.place_actor(squad, "home")
	return RunScript.new(blueprint, graph, squad)


# ---------------------------------------------------------------- 시작 상태


func test_run_starts_at_the_entrance() -> void:
	var run := SampleDungeons.create_run(_SEED)
	assert_eq(run.blueprint.kind_of(run.player_room_id()), Room.Kind.ENTRANCE)
	assert_eq(run.turn, 1)
	assert_true(run.event_log.is_empty())


func test_player_threat_is_not_counted_in_its_own_view() -> void:
	# 스쿼드 전투력이 인접 합에 섞이면 판이 거짓말을 한다.
	var run := _make_fixed_run(9)
	assert_eq(run.player.threat, 8)
	assert_eq(run.adjacent_threat(), 8, "east(3) + ledge(5) 여야 한다")


# ---------------------------------------------------------------- 고도와 도달


func test_blocked_neighbor_is_excluded_from_reachable() -> void:
	var run := _make_fixed_run(1)
	assert_true(run.reachable_room_ids().has("east"))
	assert_false(run.reachable_room_ids().has("ledge"), "민첩 1 로 상승 4 를 올랐다")
	assert_true(run.blocked_room_ids().has("ledge"))


func test_blocked_neighbor_still_counts_toward_the_number() -> void:
	# 못 가는 방도 합에는 들어간다. 저기 있는 것은 내려올 수 있다
	# (docs/design/07-level-design.md §7.2.7).
	var run := _make_fixed_run(1)
	assert_eq(run.adjacent_threat(), 8, "막혔다고 합에서 빠지면 안 된다")


func test_agility_turns_a_threat_into_an_opportunity() -> void:
	# 같은 판이라도 민첩이 오르면 갈 수 있는 곳이 늘어난다.
	var weak := _make_fixed_run(1)
	var nimble := _make_fixed_run(4)
	assert_eq(weak.reachable_room_ids().size(), 1)
	assert_eq(nimble.reachable_room_ids().size(), 2)
	assert_eq(weak.adjacent_threat(), nimble.adjacent_threat(), "보이는 숫자는 같아야 한다")


func test_cannot_move_into_a_blocked_room() -> void:
	var run := _make_fixed_run(1)
	assert_false(run.move_player("ledge"))
	assert_eq(run.player_room_id(), "home")
	assert_true(run.event_log.is_empty(), "실패한 이동이 기록됐다")


func test_descending_is_always_allowed() -> void:
	# 들어가긴 쉽고 나오긴 어렵다 (§7.2.6.2).
	var run := _make_fixed_run(4)
	run.move_player("ledge")
	assert_eq(run.player_room_id(), "ledge")

	var stuck := _make_fixed_run(0)
	stuck.graph.place_actor(stuck.player, "ledge")
	assert_true(stuck.reachable_room_ids().has("home"), "민첩 0 인데 내려가지 못한다")


# ---------------------------------------------------------------- 이동과 기록


func test_move_updates_position_turn_and_log() -> void:
	var run := _make_fixed_run(1)
	assert_true(run.move_player("east"))
	assert_eq(run.player_room_id(), "east")
	assert_eq(run.turn, 2)
	assert_eq(run.event_log.count(), 1)
	assert_eq(run.event_log.all()[0].kind, GameEvent.Kind.MOVED)
	assert_eq(run.event_log.all()[0].room_name, "동쪽 방")


func test_illegal_move_changes_nothing() -> void:
	var run := SampleDungeons.create_run(_SEED)
	var start := run.player_room_id()
	assert_false(run.move_player("존재하지 않는 방"))
	assert_eq(run.player_room_id(), start)
	assert_eq(run.turn, 1)
	assert_true(run.event_log.is_empty())


func test_move_emits_signal() -> void:
	var run := _make_fixed_run(1)
	watch_signals(run)
	run.move_player("east")
	assert_signal_emitted(run, "player_moved")


func test_the_visible_number_changes_as_you_walk() -> void:
	# 판을 걸어 다니면 보이는 숫자가 바뀐다 — 플레이어가 읽는 유일한 정보다.
	var run := _make_fixed_run(9)
	var before := run.adjacent_threat()
	run.move_player("east")
	assert_ne(before, run.adjacent_threat(), "이동했는데 보이는 숫자가 그대로다")


func test_npc_explorer_is_mobile_but_monsters_are_not() -> void:
	# 몬스터가 고정이라는 전제가 위험도 변화량 추론을 성립시킨다
	# (docs/design/13-information-design.md §13.5).
	var run := SampleDungeons.create_run(_SEED)
	var found_rival := false
	for id in run.blueprint.room_ids():
		for actor in run.graph.get_room(id).occupants():
			if actor.kind == Actor.Kind.NPC_EXPLORER:
				found_rival = true
				assert_true(actor.is_mobile())
			elif actor.kind == Actor.Kind.MONSTER:
				assert_false(actor.is_mobile())
	assert_true(found_rival, "경쟁자가 판에 없다")


# ---------------------------------------------------------------- 걸음 기록


func test_the_walk_record_starts_on_the_room_we_stand_in() -> void:
	# 판이 만들어진 순간 이미 한 방에 서 있다. 그 방은 본 방이다.
	var run := _make_fixed_run(9)
	assert_false(run.walk.has_walked(), "안 걸었는데 걸은 것으로 나온다")
	assert_eq(run.walk.seen_room_count(), 1, "선 방이 본 방에 안 들어갔다")


## **기록은 이동과 같은 함수에 묶여 있다.** 신호를 듣는 쪽에 맡기면 안 듣는 판이 생긴다.
func test_moving_leaves_a_trace_in_the_walk_record() -> void:
	var run := _make_fixed_run(9)
	run.move_player("east")
	run.move_player("home")
	assert_eq(run.walk.steps(), 2, "이동이 걸음으로 안 남았다")
	assert_eq(run.walk.backtracks(), 1, "되돌아 나왔는데 안 셌다")
	assert_eq(run.walk.retraced_corridors(), 1, "같은 통로를 양쪽으로 걸었는데 안 셌다")


func test_a_refused_move_never_touches_the_walk_record() -> void:
	# 막힌 이동까지 세면 "되돌아섬"이 손가락 실수와 섞인다.
	var run := _make_fixed_run(0)
	assert_false(run.move_player("ledge"), "막힌 방으로 이동이 성사됐다")
	assert_eq(run.walk.steps(), 0, "성사되지 않은 이동이 걸음으로 남았다")
