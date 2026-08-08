extends GutTest
## RekkaPrompt 의 **직렬화** 테스트.
##
## 여기서 지키는 것은 문체가 아니라 규칙이다.
## 사실은 그대로 나간다, 수치는 한 칸도 나가지 않는다, 이름은 감싸여 나간다,
## 조용한 턴도 블록이 나간다.
##
## 등급 변환은 test_rekka_grades.gd, 문맥 수집은 test_rekka_context.gd,
## 후처리는 test_rekka_post.gd 에 있다.
## 한 파일에 몰면 공개 함수 20개 상한(gdlint max-public-methods)에 걸린다.

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

## 모델이 다른 뜻으로 읽은 적이 있는 말들 (§19.B.5).
##
## `뒤졌다` 는 실측이다. 나머지는 같은 결의 말이라 미리 뺐다.
const AMBIGUOUS: Array[String] = ["뒤졌", "털렸", "눕혔", "접었", "먹었", "날아갔", "쓸었"]


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


func test_event_line_carries_who_where_what_and_grade() -> void:
	var actor := _actor("johan", "칼날의 요한")
	var room: Room = RoomScript.new("vault", "봉인된 금고")
	var line := PromptScript.serialize_event(_event(GameEvent.Kind.ACQUIRED, actor, room, 11))

	assert_string_contains(line, "칼날의 요한")
	assert_string_contains(line, "봉인된 금고")
	assert_string_contains(line, "챙겼다")
	assert_string_contains(line, "대박")


func test_names_are_wrapped_for_the_model() -> void:
	# 감싸지 않으면 `웃는 베른` 을 서술로 읽어 "베른이 웃고 있었습니다" 를 낸다.
	var actor := _actor("bern", "웃는 베른")
	var room: Room = RoomScript.new("hall", "회랑")
	var line := PromptScript.serialize_event(_event(GameEvent.Kind.MOVED, actor, room))

	assert_string_contains(line, "<웃는 베른>")
	assert_string_contains(line, "<회랑>")


func test_headcount_uses_the_crowd_axis() -> void:
	var actor := _actor("bern", "웃는 베른")
	var room: Room = RoomScript.new("collapse", "붕괴 구간")
	var line := PromptScript.serialize_event(_event(GameEvent.Kind.DOWNED, actor, room, 2))

	assert_string_contains(line, "규모는 한줌이다")
	assert_false(line.contains("수확"), line)


func test_no_number_reaches_the_prompt() -> void:
	# 이 게임의 전투는 피해가 오가는 방식이 아니다. 숫자가 한 자라도 새면
	# 있지도 않은 계량 감각이 게시글에 생긴다 (docs/design/05-rules.md §5.8).
	var actor := _actor("squad", "우리 스쿼드")
	var room: Room = RoomScript.new("throne", "옥좌실")
	for kind in ALL_KINDS:
		for magnitude in [0, 1, 3, 7, 18, 999]:
			var line := PromptScript.serialize_event(_event(kind, actor, room, magnitude))
			assert_false(_has_digit(line), "수치가 새어 나갔다: %s" % line)


func test_no_ambiguous_verb_reaches_the_prompt() -> void:
	# `뒤졌다` 를 모델이 "죽었다" 로 읽었다. 중의어는 직렬화에서 뺀다.
	var actor := _actor("mina", "두더지 미나")
	var room: Room = RoomScript.new("store", "수장고")
	for kind in ALL_KINDS:
		var line := PromptScript.serialize_event(_event(kind, actor, room, 5))
		for word in AMBIGUOUS:
			assert_false(line.contains(word), "중의어가 새어 나갔다: %s" % line)


func test_searching_says_it_plainly() -> void:
	var actor := _actor("mina", "두더지 미나")
	var room: Room = RoomScript.new("store", "수장고")
	var line := PromptScript.serialize_event(_event(GameEvent.Kind.SEARCHED, actor, room, 2))

	assert_string_contains(line, "수색했다")


func test_moving_carries_no_grade() -> void:
	var actor := _actor("rahk", "장부의 라흐")
	var room: Room = RoomScript.new("hall", "회랑")
	var line := PromptScript.serialize_event(_event(GameEvent.Kind.MOVED, actor, room, 9))

	assert_false(line.contains("수확"), line)
	assert_false(line.contains("규모"), line)


func test_related_ids_become_names() -> void:
	# GameEvent 는 상대를 id 로만 남긴다. 게시글에 이름을 실으려면 되찾아야 한다.
	var squad := _actor("player_squad", "우리 스쿼드")
	var room: Room = RoomScript.new("hall", "회랑")
	var related: Array[String] = ["johan"]
	var event: GameEvent = EventScript.new(4, GameEvent.Kind.ENCOUNTERED, squad, room, 1, related)
	var line := PromptScript.serialize_event(event, {"johan": "칼날의 요한"})

	assert_string_contains(line, "<칼날의 요한>과 마주쳤다")


func test_the_other_party_is_not_a_companion() -> void:
	# 칸 이름이 "함께" 였을 때 모델이 사냥개를 동행으로 읽었다.
	# 쓰러짐의 상대는 눕힌 쪽이지 같이 누운 쪽이 아니다 (§19.3.4).
	var squad := _actor("player_squad", "우리 스쿼드")
	var room: Room = RoomScript.new("deep", "심부")
	var related: Array[String] = ["boss_0"]
	var event: GameEvent = EventScript.new(13, GameEvent.Kind.DOWNED, squad, room, 1, related)
	var line := PromptScript.serialize_event(event, {"boss_0": "심부의 파수꾼"})

	assert_false(line.contains("함께"), line)
	assert_string_contains(line, "제압한 쪽은 <심부의 파수꾼>")


func test_missing_other_party_is_not_invented() -> void:
	# 상대가 없는데 이름을 만들어 붙이면 그 순간 게시글이 거짓말이 된다.
	var actor := _actor("bern", "웃는 베른")
	var room: Room = RoomScript.new("hall", "회랑")
	var line := PromptScript.serialize_event(_event(GameEvent.Kind.DOWNED, actor, room, 1))

	assert_string_contains(line, "쓰러졌다")
	assert_false(line.contains("제압한 쪽"), line)


func test_unknown_related_id_survives_as_is() -> void:
	var squad := _actor("player_squad", "우리 스쿼드")
	var room: Room = RoomScript.new("hall", "회랑")
	var related: Array[String] = ["ghost_1"]
	var event: GameEvent = EventScript.new(4, GameEvent.Kind.ENCOUNTERED, squad, room, 1, related)

	assert_string_contains(PromptScript.serialize_event(event), "<ghost_1>")


# ---------------------------------------------------------------- 소재 고르기


func test_the_loudest_events_are_picked_first() -> void:
	# 고르는 일을 모델에게 맡기면 매번 같은 것을 고른다. 편집은 규칙이다.
	var actor := _actor("johan", "칼날의 요한")
	var room: Room = RoomScript.new("hall", "회랑")
	var events: Array[GameEvent] = [
		_event(GameEvent.Kind.MOVED, actor, room),
		_event(GameEvent.Kind.SEARCHED, actor, room, 1),
		_event(GameEvent.Kind.DOWNED, actor, room, 1),
	]
	var picked := PromptScript.pick_events(events, 1)

	assert_eq(picked.size(), 1)
	assert_eq(picked[0].kind, GameEvent.Kind.DOWNED)


func test_pick_never_exceeds_the_cap() -> void:
	var actor := _actor("johan", "칼날의 요한")
	var room: Room = RoomScript.new("hall", "회랑")
	var events: Array[GameEvent] = []
	for i in 9:
		events.append(_event(GameEvent.Kind.FOUGHT, actor, room, 2))

	assert_eq(PromptScript.pick_events(events).size(), PromptScript.MAX_EVENTS)


# ---------------------------------------------------------------- 턴 블록


func test_turn_block_has_two_sections() -> void:
	# 이번 턴에 벌어진 것과 판이 이미 들고 있는 것. 후자가 없으면
	# 모델은 짧게 쓰거나 되풀이하거나 지어낸다 (§19.A.3).
	var actor := _actor("johan", "칼날의 요한")
	var room: Room = RoomScript.new("hall", "회랑")
	var events: Array[GameEvent] = [_event(GameEvent.Kind.MOVED, actor, room)]
	var context: Array[String] = ["<회랑>은 출구로 가는 길목이다"]
	var block := PromptScript.serialize_turn(events, context)

	assert_string_contains(block, "이번 턴 사건")
	assert_string_contains(block, "판이 이미 아는 것")
	assert_string_contains(block, "- <회랑>은 출구로 가는 길목이다")


func test_quiet_turn_still_produces_a_block() -> void:
	# 조용한 턴에도 게시글은 나가야 한다. 아무도 안 움직였다는 것도 정보다.
	var empty: Array[GameEvent] = []
	var block := PromptScript.serialize_turn(empty)

	assert_string_contains(block, "이번 턴 사건")
	assert_string_contains(block, "아무 일도 없었다")


func test_context_section_is_omitted_when_empty() -> void:
	# 빈 제목만 남기면 모델이 그 아래를 상상으로 채운다.
	var empty: Array[GameEvent] = []

	assert_false(PromptScript.serialize_turn(empty).contains("판이 이미 아는 것"))


func test_spent_phrases_are_handed_back_to_the_model() -> void:
	# 모델은 턴마다 새로 불려서 자기가 방금 무슨 밈을 썼는지 모른다.
	var empty: Array[GameEvent] = []
	var spent: Array[String] = ["학계 정설", "국룰임"]
	var block := PromptScript.serialize_turn(empty, [] as Array[String], {}, spent)

	assert_string_contains(block, "학계 정설, 국룰임")


func test_system_prompt_stays_short() -> void:
	# 프롬프트가 길수록 합니다체와 지어내기가 는다 (§19.A.2 발견 1 —
	# 188자에서 8회, 330자에서 26회). 줄을 더하면 이 테스트가 깨진다.
	assert_lt(PromptScript.SYSTEM.length(), 260, PromptScript.SYSTEM)
	assert_string_contains(PromptScript.SYSTEM, "대괄호로 닉네임")
