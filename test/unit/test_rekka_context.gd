extends GutTest
## RekkaContext 테스트 — 인물 이력 · 관계 · 형태.
##
## 여기서 지키는 것은 하나다. **여기서 나가는 줄은 전부 실제 값이다.**
## 지어낸 설정이 한 줄이라도 섞이면 그 순간 게시글이 거짓말이 되고,
## 플레이어는 기사로 판을 추론할 수 없게 된다
## (docs/design/13-information-design.md §13.3.1).
##
## 방의 상태와 위상은 test_rekka_context_rooms.gd 에 있다.
## 한 파일에 몰면 공개 함수 20개 상한(gdlint max-public-methods)에 걸린다.

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


# ---------------------------------------------------------------- 인접 상황


func test_neighbours_name_the_people_who_move() -> void:
	var bern := _npc("bern", "웃는 베른")
	_graph.place_actor(bern, "gate")
	var johan := _npc("johan", "칼날의 요한")
	var events: Array[GameEvent] = [_event(GameEvent.Kind.MOVED, johan, "hall")]

	# 스쿼드도 옆방(입구 광장)에 있으므로 같은 줄에 함께 실린다.
	assert_string_contains(_joined(events), "옆방에 <우리 스쿼드>와 <웃는 베른>이 있다")


func test_monsters_are_never_named_in_the_neighbour_line() -> void:
	# 인접 위험도는 합만 보이고 구성은 안 보이는 것이 이 게임의 핵심이다
	# (07-level-design.md §7.2). 옆방 몬스터를 이름으로 불러 주면 그게 무너진다.
	var hound: Actor = ActorScript.new("hound", "사냥개", Actor.Kind.MONSTER, 2, 1)
	_graph.place_actor(hound, "gate")
	var johan := _npc("johan", "칼날의 요한")
	var events: Array[GameEvent] = [_event(GameEvent.Kind.MOVED, johan, "hall")]

	assert_false(_joined(events).contains("사냥개"), _joined(events))


func test_several_neighbours_are_joined_into_one_line() -> void:
	_graph.place_actor(_npc("bern", "웃는 베른"), "gate")
	_graph.place_actor(_npc("mina", "두더지 미나"), "cell")
	var johan := _npc("johan", "칼날의 요한")
	var events: Array[GameEvent] = [_event(GameEvent.Kind.MOVED, johan, "hall")]

	assert_string_contains(_joined(events), "<웃는 베른>과 <두더지 미나>")


# ---------------------------------------------------------------- 인물 이력


func test_an_empty_handed_actor_is_reported_as_such() -> void:
	# 아직 빈손이라는 것도 정보다. 누가 급한지를 알려 준다.
	var johan := _npc("johan", "칼날의 요한")
	var events: Array[GameEvent] = [_event(GameEvent.Kind.MOVED, johan, "hall")]

	assert_string_contains(_joined(events), "<칼날의 요한>은 이번 판 들어 아직 아무것도 못 챙겼다")


func test_a_past_haul_carries_its_room_and_its_age() -> void:
	var mina := _npc("mina", "두더지 미나")
	_run.event_log.record(_event(GameEvent.Kind.ACQUIRED, mina, "vault", 3, 11))
	var events: Array[GameEvent] = [_event(GameEvent.Kind.MOVED, mina, "hall")]

	assert_string_contains(_joined(events), "<두더지 미나>는 두 턴 전 <수장고>에서 대박을 챙겼다")


func test_several_hauls_are_graded_on_the_total_and_name_no_room() -> void:
	# 제일 큰 한 건만 보고 등급을 매겼더니, 나갈 때 합으로 계산된 등급과 어긋나
	# 같은 사람의 수확이 한몫에서 대박으로 승격됐다.
	# 그리고 합으로 매긴 등급에 방 이름을 붙이면 그 방에서 다 나온 것처럼 읽힌다.
	var mina := _npc("mina", "두더지 미나")
	_run.event_log.record(_event(GameEvent.Kind.ACQUIRED, mina, "cell", 2, 3))
	_run.event_log.record(_event(GameEvent.Kind.ACQUIRED, mina, "vault", 4, 8))
	var events: Array[GameEvent] = [_event(GameEvent.Kind.MOVED, mina, "hall")]
	var joined := _joined(events)

	# 합이라는 것을 말로 밝혀야 한다. 안 밝혔더니 한몫짜리를 두 번 챙긴 자가
	# 어떤 편에서는 `대박`, 어떤 편에서는 `한몫씩` 으로 나가 편끼리 모순됐다.
	assert_string_contains(joined, "<두더지 미나>는 이번 판에 챙긴 것이 다 합쳐서 대박이다")
	assert_false(joined.contains("<수장고>에서 대박"), joined)


func test_an_old_haul_stops_counting_the_turns() -> void:
	# 실측 결함이다. `두 턴 전` 부터 `일곱 턴 전` 까지 여섯 편이 숫자만 다른 같은 줄이었다.
	var mina := _npc("mina", "두더지 미나")
	_run.turn = 12
	_run.event_log.record(_event(GameEvent.Kind.ACQUIRED, mina, "vault", 2, 11))
	var events: Array[GameEvent] = [_event(GameEvent.Kind.MOVED, mina, "hall", 12)]
	var joined := _joined(events)

	assert_false(joined.contains("턴 전"), joined)
	assert_string_contains(joined, "이번 판에 이미 대박을 챙겨 둔 상태다")


# ---------------------------------------------------------------- 관계와 수색


func test_an_earlier_meeting_this_run_is_reported() -> void:
	var mina := _npc("mina", "두더지 미나")
	var related: Array[String] = ["bern"]
	_run.event_log.record(_event(GameEvent.Kind.NEGOTIATED, mina, "hall", 2, 3, related))
	_graph.place_actor(_npc("bern", "웃는 베른"), "cell")
	var events: Array[GameEvent] = [_event(GameEvent.Kind.ENCOUNTERED, mina, "hall", 5, 2, related)]

	assert_string_contains(_joined(events), "거래를 맺고 헤어진 사이다")


func test_relationships_never_reach_back_past_this_run() -> void:
	# 판 사이를 잇는 관계 기록이 아직 없다. 없는 것을 지어내면 게시글이 거짓말이 된다.
	var mina := _npc("mina", "두더지 미나")
	var related: Array[String] = ["bern"]
	var events: Array[GameEvent] = [_event(GameEvent.Kind.ENCOUNTERED, mina, "hall", 5, 2, related)]

	assert_false(_joined(events).contains("사이다"), _joined(events))


# ---------------------------------------------------------------- 형태


func test_facts_are_capped() -> void:
	# 프롬프트가 길수록 산출이 나빠진다 (§19.A.2 발견 1).
	_graph.place_actor(_npc("bern", "웃는 베른"), "gate")
	_graph.place_actor(_npc("mina", "두더지 미나"), "cell")
	var johan := _npc("johan", "칼날의 요한")
	var events: Array[GameEvent] = [
		_event(GameEvent.Kind.MOVED, johan, "hall"),
		_event(GameEvent.Kind.MOVED, _npc("mina", "두더지 미나"), "cell"),
		_event(GameEvent.Kind.MOVED, _npc("bern", "웃는 베른"), "gate"),
	]

	assert_lte(_facts(events).size(), ContextScript.MAX_FACTS)


func test_every_name_is_wrapped_for_the_model() -> void:
	# 감싸지 않으면 `웃는 베른` 을 서술로 읽는다 (§19.A.5).
	_graph.place_actor(_npc("bern", "웃는 베른"), "gate")
	var johan := _npc("johan", "칼날의 요한")
	var events: Array[GameEvent] = [_event(GameEvent.Kind.MOVED, johan, "hall")]
	for fact in _facts(events):
		assert_eq(fact.count("<"), fact.count(">"), fact)


func test_a_quiet_turn_reports_what_absence_tells_us() -> void:
	# 사건이 없으면 방도 인물도 없어서 문맥이 한 줄도 안 나온다. 그런데 조용한 턴이야말로
	# 문맥이 제일 필요한 턴이다 — 실측에서 사건 없는 두 편이 거의 같은 글이었다.
	_graph.place_actor(_npc("bern", "웃는 베른"), "gate")
	var empty: Array[GameEvent] = []
	var joined := "\n".join(ContextScript.for_turn(_run, empty))

	assert_string_contains(joined, "<웃는 베른>")
	assert_string_contains(joined, "남아 있다")
	assert_string_contains(joined, "아무도 손대지 않은 귀중품 방이다")


func test_the_turn_the_squad_leaves_carries_over_to_the_next_run() -> void:
	# 스쿼드가 나가면 이 판의 마지막 편이다. 방 이름과 옆방 상황을 알려 줘도 쓸 턴이 없다.
	# 심사자 둘이 각각 판마다 마지막 한 편이 통째로 죽어 있다고 셌다.
	_graph.place_actor(_npc("bern", "웃는 베른"), "gate")
	var events: Array[GameEvent] = [_event(GameEvent.Kind.ESCAPED, _run.player, "gate", 5, 0)]
	var joined := _joined(events)

	assert_string_contains(joined, "아무도 손대지 않은 귀중품 방이다")
	assert_false(joined.contains("옆방에"), joined)


func test_a_run_with_no_history_still_yields_room_facts() -> void:
	var johan := _npc("johan", "칼날의 요한")
	var events: Array[GameEvent] = [_event(GameEvent.Kind.MOVED, johan, "hall")]

	assert_gt(_facts(events).size(), 0)
	for fact in _facts(events):
		assert_ne(fact.strip_edges(), "")
