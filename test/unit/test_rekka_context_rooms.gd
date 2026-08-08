extends GutTest
## RekkaContext 테스트 — 방의 상태와 위상.
##
## 여기서 지키는 것은 하나다. **여기서 나가는 줄은 전부 실제 값이다.**
## 지어낸 설정이 한 줄이라도 섞이면 그 순간 게시글이 거짓말이 되고,
## 플레이어는 기사로 판을 추론할 수 없게 된다
## (docs/design/13-information-design.md §13.3.1).
##
## 판은 손으로 세운다. 생성기를 쓰면 시드마다 지형이 달라져
## "길목이면 길목이라고 말하는가" 를 못 박을 수 없다.
##
## 인물 이력 · 관계 · 형태는 test_rekka_context.gd 에 있다.

const ActorScript := preload("res://src/core/dungeon/actor.gd")
const RoomScript := preload("res://src/core/dungeon/room.gd")
const GraphScript := preload("res://src/core/dungeon/dungeon_graph.gd")
const RunScript := preload("res://src/core/dungeon/dungeon_run.gd")
const EventScript := preload("res://src/core/event/game_event.gd")
const ContextScript := preload("res://src/core/rekka/rekka_context.gd")

var _run: DungeonRun
var _graph: DungeonGraph


##     입구 광장 --- 회랑 --- 탈출 승강기
##                    |  \
##                  수장고  밀실
##
## 회랑은 출구로 가는 유일한 길이고, 밀실은 막다른 방이고,
## 수장고는 고도가 높아 스쿼드 민첩으로는 못 오른다.
func before_each() -> void:
	_graph = GraphScript.new()
	_graph.add_room(RoomScript.new("start", "입구 광장", 0, Room.Kind.ENTRANCE))
	_graph.add_room(RoomScript.new("hall", "회랑", 0, Room.Kind.EMPTY))
	_graph.add_room(RoomScript.new("gate", "탈출 승강기", 0, Room.Kind.EXIT))
	_graph.add_room(RoomScript.new("vault", "수장고", 5, Room.Kind.TREASURE))
	_graph.add_room(RoomScript.new("cell", "밀실", 0, Room.Kind.TREASURE))
	_graph.connect_rooms("start", "hall")
	_graph.connect_rooms("hall", "gate")
	_graph.connect_rooms("hall", "vault")
	_graph.connect_rooms("hall", "cell")

	var squad: Actor = ActorScript.new("player_squad", "우리 스쿼드", Actor.Kind.PLAYER_SQUAD, 8, 2)
	_graph.place_actor(squad, "start")
	_run = RunScript.new(null, _graph, squad)
	_run.turn = 5


func _npc(id: String, name: String) -> Actor:
	return ActorScript.new(id, name, Actor.Kind.NPC_EXPLORER, 4, 2)


func _event(
	kind: GameEvent.Kind,
	actor: Actor,
	room_id: String,
	turn: int = 5,
	magnitude: int = 0,
	related: Array[String] = [] as Array[String]
) -> GameEvent:
	return EventScript.new(turn, kind, actor, _graph.get_room(room_id), magnitude, related)


func _facts(events: Array[GameEvent]) -> Array[String]:
	return ContextScript.for_turn(_run, events)


func _joined(events: Array[GameEvent]) -> String:
	return "\n".join(_facts(events))


# ---------------------------------------------------------------- 방의 역할


func test_a_gateway_room_is_named_as_one() -> void:
	# 지나갈 수밖에 없는 방이라는 것은 그 자체로 다음 턴의 결정을 바꾼다.
	var johan := _npc("johan", "칼날의 요한")
	var events: Array[GameEvent] = [_event(GameEvent.Kind.MOVED, johan, "hall")]

	assert_string_contains(_joined(events), "<회랑>은 <탈출 승강기>로 가는 길목")


func test_a_dead_end_is_named_as_one() -> void:
	var johan := _npc("johan", "칼날의 요한")
	var events: Array[GameEvent] = [_event(GameEvent.Kind.MOVED, johan, "cell")]

	assert_string_contains(_joined(events), "<밀실>은 막다른 방이라")


func test_a_room_out_of_reach_is_named_as_one() -> void:
	# 못 가는 방은 경로에서 통째로 빠진다. 막다른 방이라는 것보다 먼저 알아야 한다.
	var johan := _npc("johan", "칼날의 요한")
	var events: Array[GameEvent] = [_event(GameEvent.Kind.MOVED, johan, "vault")]

	assert_string_contains(_joined(events), "<수장고>는 지금 스쿼드 민첩으로는 오를 수 없는 방")


func test_topology_the_player_can_already_see_is_not_reported() -> void:
	# 갈래 수와 출구 거리는 판이 통째로 보이는 화면이면 플레이어가 이미 세고 있다.
	# 그것을 기사로 다시 읽어 주면 정보원이 아니라 나레이션이 된다.
	_graph.place_actor(_run.player, "hall")
	var johan := _npc("johan", "칼날의 요한")
	var events: Array[GameEvent] = [_event(GameEvent.Kind.MOVED, johan, "hall")]
	var joined := _joined(events)

	assert_false(joined.contains("갈래"), joined)
	assert_false(joined.contains("방 떨어져"), joined)


func test_an_untouched_treasure_room_is_reported_as_untouched() -> void:
	# 방 안에 뭐가 있고 그게 아직 남았는지는 인접 위험도 합에서 절대 안 나온다.
	var johan := _npc("johan", "칼날의 요한")
	var events: Array[GameEvent] = [_event(GameEvent.Kind.MOVED, johan, "cell")]

	assert_string_contains(_joined(events), "<밀실>은 귀중품이 있는 방인데 이번 판 들어 아직 아무도 손대지 않았다")


func test_a_room_searched_this_turn_says_so() -> void:
	var johan := _npc("johan", "칼날의 요한")
	var events: Array[GameEvent] = [_event(GameEvent.Kind.SEARCHED, johan, "cell", 5, 3)]

	assert_string_contains(_joined(events), "<밀실>은 이번 판 들어 처음으로 수색된 방이다")


func test_a_room_searched_earlier_is_never_called_first_again() -> void:
	# 실측 결함이다. 세 턴 간격으로 같은 방이 두 번 처녀지가 됐다.
	# 그 글을 믿고 달려간 플레이어는 빈 방을 만나고, 그러면 그 판 기사 전부가 무가치해진다.
	var johan := _npc("johan", "칼날의 요한")
	_run.event_log.record(_event(GameEvent.Kind.SEARCHED, johan, "cell", 2, 7))
	var events: Array[GameEvent] = [_event(GameEvent.Kind.MOVED, johan, "cell")]
	var joined := _joined(events)

	assert_false(joined.contains("처음으로 수색"), joined)
	assert_string_contains(joined, "<밀실>은 이번 판에 이미 수색이 끝난 방이다")
