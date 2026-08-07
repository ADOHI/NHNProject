extends GutTest
## GameEvent · EventLog 의 단위 테스트.
##
## 로그는 판의 진실이고, 과장은 기사 생성 단계에서만 일어난다
## (docs/design/13-information-design.md §13.3). 그 경계를 테스트로 지킨다.

const ActorScript := preload("res://src/core/dungeon/actor.gd")
const RoomScript := preload("res://src/core/dungeon/room.gd")
const EventScript := preload("res://src/core/event/game_event.gd")
const LogScript := preload("res://src/core/event/event_log.gd")


func _make_actor(id: String, name: String = "") -> Actor:
	return ActorScript.new(id, name if not name.is_empty() else id, Actor.Kind.NPC_EXPLORER, 3)


func _make_event(
	turn: int, kind: GameEvent.Kind, actor: Actor, room: Room, magnitude: int = 0
) -> GameEvent:
	return EventScript.new(turn, kind, actor, room, magnitude)


# ---------------------------------------------------------------- GameEvent


func test_event_captures_four_slots() -> void:
	# 누가 · 어디서 · 무엇을 · 얼마나 (docs/design/08-ui-ux.md §8.3.6).
	var actor := _make_actor("johan", "칼날의 요한")
	var room: Room = RoomScript.new("west_hall", "서쪽 회랑")
	var event := _make_event(3, GameEvent.Kind.ACQUIRED, actor, room, 120)

	assert_eq(event.actor_name, "칼날의 요한")
	assert_eq(event.room_name, "서쪽 회랑")
	assert_eq(event.kind, GameEvent.Kind.ACQUIRED)
	assert_eq(event.magnitude, 120)


func test_event_keeps_names_not_just_ids() -> void:
	# 기사는 사건보다 오래 산다. 죽거나 떠난 주체를 나중에 조회할 수 없다.
	var actor := _make_actor("johan", "칼날의 요한")
	var room: Room = RoomScript.new("west_hall", "서쪽 회랑")
	var event := _make_event(1, GameEvent.Kind.MOVED, actor, room)
	assert_false(event.actor_name.is_empty())
	assert_false(event.room_name.is_empty())


func test_related_actors_mark_entangled_events() -> void:
	var actor := _make_actor("johan")
	var room: Room = RoomScript.new("west_hall")
	var solo := _make_event(1, GameEvent.Kind.SEARCHED, actor, room)
	var duel: GameEvent = EventScript.new(
		1, GameEvent.Kind.FOUGHT, actor, room, 2, ["rival"] as Array[String]
	)
	assert_false(solo.involves_others())
	assert_true(duel.involves_others())


# ---------------------------------------------------------------- EventLog


func test_log_starts_empty() -> void:
	var log: EventLog = LogScript.new()
	assert_true(log.is_empty())
	assert_eq(log.count(), 0)


func test_record_emits_signal() -> void:
	# 기사 생성기가 여기에 붙는다.
	var log: EventLog = LogScript.new()
	watch_signals(log)
	var actor := _make_actor("johan")
	var room: Room = RoomScript.new("west_hall")
	log.record(_make_event(1, GameEvent.Kind.MOVED, actor, room))
	assert_signal_emitted(log, "event_recorded")


func test_events_in_turn_filters_by_turn() -> void:
	# 렉카 피드는 매 행동 페이즈 직후 그 턴의 사건에서 기사를 고른다.
	var log: EventLog = LogScript.new()
	var actor := _make_actor("johan")
	var room: Room = RoomScript.new("west_hall")
	log.record(_make_event(1, GameEvent.Kind.MOVED, actor, room))
	log.record(_make_event(2, GameEvent.Kind.SEARCHED, actor, room))
	log.record(_make_event(2, GameEvent.Kind.ACQUIRED, actor, room, 40))

	assert_eq(log.events_in_turn(1).size(), 1)
	assert_eq(log.events_in_turn(2).size(), 2)
	assert_eq(log.events_in_turn(9).size(), 0)


func test_events_involving_includes_related_actors() -> void:
	# 주목도 계산은 "주인공인 사건"만이 아니라 "얽힌 사건"까지 센다.
	var log: EventLog = LogScript.new()
	var actor := _make_actor("johan")
	var room: Room = RoomScript.new("west_hall")
	log.record(
		EventScript.new(1, GameEvent.Kind.FOUGHT, actor, room, 1, ["rival"] as Array[String])
	)
	assert_eq(log.events_involving("johan").size(), 1)
	assert_eq(log.events_involving("rival").size(), 1)
	assert_eq(log.events_involving("stranger").size(), 0)


func test_events_of_kind_filters() -> void:
	var log: EventLog = LogScript.new()
	var actor := _make_actor("johan")
	var room: Room = RoomScript.new("west_hall")
	log.record(_make_event(1, GameEvent.Kind.MOVED, actor, room))
	log.record(_make_event(1, GameEvent.Kind.DOWNED, actor, room))
	assert_eq(log.events_of_kind(GameEvent.Kind.DOWNED).size(), 1)


func test_events_in_room_filters() -> void:
	var log: EventLog = LogScript.new()
	var actor := _make_actor("johan")
	var west: Room = RoomScript.new("west_hall")
	var east: Room = RoomScript.new("east_hall")
	log.record(_make_event(1, GameEvent.Kind.MOVED, actor, west))
	log.record(_make_event(1, GameEvent.Kind.MOVED, actor, east))
	assert_eq(log.events_in_room("west_hall").size(), 1)


func test_recent_returns_newest_first() -> void:
	# 피드는 최신순으로 읽힌다.
	var log: EventLog = LogScript.new()
	var actor := _make_actor("johan")
	var room: Room = RoomScript.new("west_hall")
	log.record(_make_event(1, GameEvent.Kind.MOVED, actor, room))
	log.record(_make_event(2, GameEvent.Kind.SEARCHED, actor, room))
	log.record(_make_event(3, GameEvent.Kind.ACQUIRED, actor, room, 10))

	var recent := log.recent(2)
	assert_eq(recent.size(), 2)
	assert_eq(recent[0].turn, 3)
	assert_eq(recent[1].turn, 2)


func test_recent_handles_limits_beyond_size() -> void:
	var log: EventLog = LogScript.new()
	var actor := _make_actor("johan")
	var room: Room = RoomScript.new("west_hall")
	log.record(_make_event(1, GameEvent.Kind.MOVED, actor, room))
	assert_eq(log.recent(10).size(), 1)
	assert_eq(log.recent(0).size(), 0)


func test_all_returns_a_copy() -> void:
	var log: EventLog = LogScript.new()
	var actor := _make_actor("johan")
	var room: Room = RoomScript.new("west_hall")
	log.record(_make_event(1, GameEvent.Kind.MOVED, actor, room))
	var listed := log.all()
	listed.clear()
	assert_eq(log.count(), 1)
