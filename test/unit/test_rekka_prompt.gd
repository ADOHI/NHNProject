extends GutTest
## RekkaPrompt 의 **직렬화** 테스트.
##
## 여기서 지키는 것은 문체가 아니라 규칙이다.
## 사실은 그대로 나간다, 수치는 한 칸도 나가지 않는다, 조용한 턴도 블록이 나간다.
## 등급 변환은 test_rekka_grades.gd, 문체는 docs/design/samples/rekka/ 의 표본으로 판단한다.

const ActorScript := preload("res://src/core/dungeon/actor.gd")
const RoomScript := preload("res://src/core/dungeon/room.gd")
const EventScript := preload("res://src/core/event/game_event.gd")
const PromptScript := preload("res://src/core/rekka/rekka_prompt.gd")

const ALL_KINDS: Array[GameEvent.Kind] = [
	GameEvent.Kind.MOVED,
	GameEvent.Kind.SEARCHED,
	GameEvent.Kind.ACQUIRED,
	GameEvent.Kind.ENCOUNTERED,
	GameEvent.Kind.FOUGHT,
	GameEvent.Kind.NEGOTIATED,
	GameEvent.Kind.FLED,
	GameEvent.Kind.DOWNED,
	GameEvent.Kind.ESCAPED,
]

const DIGITS := "0123456789"


func _actor(id: String, name: String) -> Actor:
	return ActorScript.new(id, name, Actor.Kind.NPC_EXPLORER, 3)


func _event(kind: GameEvent.Kind, actor: Actor, room: Room, magnitude: int = 0) -> GameEvent:
	return EventScript.new(4, kind, actor, room, magnitude)


func _has_digit(text: String) -> bool:
	for i in text.length():
		if DIGITS.contains(text[i]):
			return true
	return false


# ---------------------------------------------------------------- 사건 한 줄


func test_event_line_carries_the_four_slots() -> void:
	var actor := _actor("johan", "칼날의 요한")
	var room: Room = RoomScript.new("vault", "봉인된 금고")
	var line := PromptScript.serialize_event(_event(GameEvent.Kind.ACQUIRED, actor, room, 11))

	assert_string_contains(line, "칼날의 요한")
	assert_string_contains(line, "봉인된 금고")
	assert_string_contains(line, "무엇을=획득")
	assert_string_contains(line, "수확=대박")


func test_headcount_uses_the_other_slot() -> void:
	var actor := _actor("bern", "웃는 베른")
	var room: Room = RoomScript.new("collapse", "붕괴 구간")
	var line := PromptScript.serialize_event(_event(GameEvent.Kind.DOWNED, actor, room, 2))

	assert_string_contains(line, "규모=한줌")
	assert_false(line.contains("수확"), line)


func test_no_number_reaches_the_prompt() -> void:
	# 이 게임의 전투는 피해가 오가는 방식이 아니다. 숫자가 한 자라도 새면
	# 있지도 않은 계량 감각이 기사에 생긴다 (docs/design/05-rules.md §5.8).
	var actor := _actor("squad", "우리 스쿼드")
	var room: Room = RoomScript.new("throne", "옥좌실")
	for kind in ALL_KINDS:
		for magnitude in [0, 1, 3, 7, 18, 999]:
			var line := PromptScript.serialize_event(_event(kind, actor, room, magnitude))
			assert_false(_has_digit(line), "수치가 새어 나갔다: %s" % line)


func test_moving_carries_no_grade() -> void:
	var actor := _actor("rahk", "장부의 라흐")
	var room: Room = RoomScript.new("hall", "회랑")
	var line := PromptScript.serialize_event(_event(GameEvent.Kind.MOVED, actor, room, 9))

	assert_false(line.contains("수확"), line)
	assert_false(line.contains("규모"), line)


func test_player_side_is_marked() -> void:
	# 자기 이야기를 못 읽으면 플레이어는 자기 노출도를 관리할 수 없다.
	var squad := _actor("player_squad", "우리 스쿼드")
	var room: Room = RoomScript.new("hall", "회랑")
	var line := PromptScript.serialize_event(
		_event(GameEvent.Kind.MOVED, squad, room), "player_squad"
	)

	assert_string_contains(line, "소속=플레이어")


func test_other_side_is_marked() -> void:
	var actor := _actor("johan", "칼날의 요한")
	var room: Room = RoomScript.new("hall", "회랑")
	var line := PromptScript.serialize_event(
		_event(GameEvent.Kind.MOVED, actor, room), "player_squad"
	)

	assert_string_contains(line, "소속=타인")


func test_related_ids_become_names() -> void:
	# GameEvent 는 상대를 id 로만 남긴다. 기사에 이름을 실으려면 되찾아야 한다.
	var squad := _actor("player_squad", "우리 스쿼드")
	var room: Room = RoomScript.new("hall", "회랑")
	var related: Array[String] = ["johan"]
	var event: GameEvent = EventScript.new(4, GameEvent.Kind.ENCOUNTERED, squad, room, 1, related)
	var line := PromptScript.serialize_event(event, "player_squad", {"johan": "칼날의 요한"})

	assert_string_contains(line, "상대=칼날의 요한")


func test_the_other_party_is_not_labelled_as_a_companion() -> void:
	# 칸 이름이 "함께" 였을 때 모델이 사냥개를 동행으로 읽었다.
	# "사냥개와 함께 도주했습니다", "우리 스쿼드와 파수꾼이 함께 쓰러졌습니다" 가 실제 산출이다.
	# 쓰러짐의 상대는 눕힌 쪽이지 같이 누운 쪽이 아니다 (§19.6.3).
	var squad := _actor("player_squad", "우리 스쿼드")
	var room: Room = RoomScript.new("deep", "심부")
	var related: Array[String] = ["boss_0"]
	var event: GameEvent = EventScript.new(13, GameEvent.Kind.DOWNED, squad, room, 1, related)
	var line := PromptScript.serialize_event(event, "player_squad", {"boss_0": "심부의 파수꾼"})

	assert_false(line.contains("함께"), line)
	assert_string_contains(line, "상대=심부의 파수꾼")


func test_unknown_related_id_survives_as_is() -> void:
	var squad := _actor("player_squad", "우리 스쿼드")
	var room: Room = RoomScript.new("hall", "회랑")
	var related: Array[String] = ["ghost_1"]
	var event: GameEvent = EventScript.new(4, GameEvent.Kind.ENCOUNTERED, squad, room, 1, related)

	assert_string_contains(PromptScript.serialize_event(event), "상대=ghost_1")


# ---------------------------------------------------------------- 턴 블록


func test_quiet_turn_still_produces_a_block() -> void:
	# 조용한 턴에도 기사는 나가야 한다. 아무도 안 움직였다는 것도 정보다.
	var empty: Array[GameEvent] = []
	var block := PromptScript.serialize_turn(9, empty, "우리 스쿼드")

	assert_string_contains(block, "턴: 9")
	assert_string_contains(block, "사건: 없음")


func test_turn_block_lists_every_event() -> void:
	var actor := _actor("johan", "칼날의 요한")
	var room: Room = RoomScript.new("hall", "회랑")
	var events: Array[GameEvent] = [
		_event(GameEvent.Kind.MOVED, actor, room),
		_event(GameEvent.Kind.SEARCHED, actor, room, 2),
	]
	var block := PromptScript.serialize_turn(5, events, "우리 스쿼드")

	assert_eq(block.split("\n").size(), 5, block)
	assert_string_contains(block, "무엇을=이동")
	assert_string_contains(block, "무엇을=탐색")


func test_recent_titles_are_handed_back_to_the_model() -> void:
	# 모델은 턴마다 새로 불려서 자기가 방금 무슨 결로 썼는지 모른다.
	# 최근 제목을 넘기는 것이 틀 반복을 깨는 유일한 장치다 (§19.4.2).
	var empty: Array[GameEvent] = []
	var recent: Array[String] = ["요한 근황", "수장고 털린 썰"]
	var block := PromptScript.serialize_turn(9, empty, "우리 스쿼드", "", {}, recent)

	assert_string_contains(block, "최근: 요한 근황 / 수장고 털린 썰")


func test_first_turn_has_no_recent_line() -> void:
	# 빈 칸을 보내면 모델이 그것을 제목 하나로 읽는다.
	var empty: Array[GameEvent] = []
	var block := PromptScript.serialize_turn(1, empty, "우리 스쿼드")

	assert_false(block.contains("최근"), block)
