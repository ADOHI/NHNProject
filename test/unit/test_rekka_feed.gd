extends GutTest
## RekkaFeed 테스트 — 판 한 판의 피드.
##
## 여기서 지키는 것은 **편끼리 이어져야 하는 것들**이다
## (docs/design/19-rekka-voice.md §19.B.4).
## 한 편만 보면 안 보이고 스무 편째에 보이는 결함이라 사람 눈으로는 못 잡는다.

const ActorScript := preload("res://src/core/dungeon/actor.gd")
const RoomScript := preload("res://src/core/dungeon/room.gd")
const GraphScript := preload("res://src/core/dungeon/dungeon_graph.gd")
const RunScript := preload("res://src/core/dungeon/dungeon_run.gd")
const EventScript := preload("res://src/core/event/game_event.gd")
const FeedScript := preload("res://src/core/rekka/rekka_feed.gd")

var _run: DungeonRun
var _graph: DungeonGraph
var _feed: RekkaFeed


##     입구 광장 --- 회랑 --- 탈출 승강기
##                    |
##                  수장고
func before_each() -> void:
	_graph = GraphScript.new()
	_graph.add_room(RoomScript.new("start", "입구 광장", 0, Room.Kind.ENTRANCE))
	_graph.add_room(RoomScript.new("hall", "회랑", 0, Room.Kind.EMPTY))
	_graph.add_room(RoomScript.new("gate", "탈출 승강기", 0, Room.Kind.EXIT))
	_graph.add_room(RoomScript.new("vault", "수장고", 0, Room.Kind.TREASURE))
	_graph.connect_rooms("start", "hall")
	_graph.connect_rooms("hall", "gate")
	_graph.connect_rooms("hall", "vault")
	var squad: Actor = ActorScript.new("player_squad", "우리 스쿼드", Actor.Kind.PLAYER_SQUAD, 8, 2)
	_graph.place_actor(squad, "start")
	_run = RunScript.new(null, _graph, squad)
	_run.turn = 4
	_feed = FeedScript.new(20260808)


func _npc() -> Actor:
	return ActorScript.new("johan", "칼날의 요한", Actor.Kind.NPC_EXPLORER, 4, 2)


func _events(kind: GameEvent.Kind, turn: int = 4, magnitude: int = 3) -> Array[GameEvent]:
	return [EventScript.new(turn, kind, _npc(), _graph.get_room("vault"), magnitude)]


# ---------------------------------------------------------------- 편이 걸린다


func test_a_turn_becomes_a_post() -> void:
	var entry := _feed.record_turn(_run, _events(GameEvent.Kind.SEARCHED))

	assert_not_null(entry)
	assert_eq(_feed.count(), 1)
	assert_false(entry.title.is_empty())


func test_a_quiet_turn_becomes_a_post_too() -> void:
	# 조용한 턴이야말로 문맥이 제일 필요한 턴이다 (§19.B.1).
	var entry := _feed.record_turn(_run, [] as Array[GameEvent])

	assert_not_null(entry)
	assert_false(entry.title.is_empty())


func test_the_post_is_announced() -> void:
	watch_signals(_feed)
	_feed.record_turn(_run, _events(GameEvent.Kind.MOVED))

	assert_signal_emitted(_feed, "post_added")


func test_the_turn_comes_from_the_event_not_the_run() -> void:
	# `move_player()` 는 사건을 기록한 뒤에 턴을 올린다. run.turn 을 쓰면 하나씩 밀린다.
	var entry := _feed.record_turn(_run, _events(GameEvent.Kind.SEARCHED, 2))

	assert_eq(entry.turn, 2)


func test_newest_is_first() -> void:
	_feed.record_turn(_run, _events(GameEvent.Kind.SEARCHED, 1))
	_feed.record_turn(_run, _events(GameEvent.Kind.FOUGHT, 2))

	assert_eq(_feed.newest_first()[0].turn, 2)
	assert_eq(_feed.latest().turn, 2)


func test_a_null_run_gives_nothing_instead_of_crashing() -> void:
	assert_null(_feed.record_turn(null, [] as Array[GameEvent]))


# ---------------------------------------------------------------- 이어 세기


func test_handles_do_not_repeat_across_posts() -> void:
	# 실측에서 닉 139개 중 서로 다른 것이 113개였다 (§19.B.4).
	var seen: Dictionary = {}
	var total := 0
	for turn in 6:
		var entry := _feed.record_turn(_run, _events(GameEvent.Kind.SEARCHED, turn + 1))
		for line in entry.comments:
			var nick := line.substr(0, line.find("]") + 1)
			seen[nick] = true
			total += 1
	assert_eq(seen.size(), total, "여섯 편 안에서 닉이 겹쳤다")


func test_two_runs_do_not_share_the_same_arrangement() -> void:
	# 판이 바뀌면 접두어와 닉네임 고리가 다시 섞여야 한다 (§19.B.9 2차).
	var other: RekkaFeed = FeedScript.new(31337)
	var here := _feed.record_turn(_run, _events(GameEvent.Kind.SEARCHED, 1))
	var there := other.record_turn(_run, _events(GameEvent.Kind.SEARCHED, 1))

	assert_ne(here.text, there.text)


# ---------------------------------------------------------------- 판과 잇기


func test_the_post_knows_which_rooms_it_named() -> void:
	var entry := _feed.record_turn(_run, _events(GameEvent.Kind.SEARCHED))

	assert_has(entry.room_ids(), "vault")


func test_room_names_of_maps_every_room_on_the_board() -> void:
	var rooms := FeedScript.room_names_of(_run)

	assert_eq(rooms.size(), 4, str(rooms))
	assert_eq(rooms.get("수장고"), "vault")


func test_room_names_of_a_missing_run_is_empty() -> void:
	assert_eq(FeedScript.room_names_of(null), {})


func test_clearing_starts_the_count_over() -> void:
	_feed.record_turn(_run, _events(GameEvent.Kind.SEARCHED, 1))
	_feed.clear()

	assert_eq(_feed.count(), 0)
	assert_null(_feed.latest())
