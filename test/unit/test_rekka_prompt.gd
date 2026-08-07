extends GutTest
## RekkaPrompt 의 단위 테스트.
##
## 여기서 지키는 것은 문체가 아니라 **규칙**이다.
## 부풀리기만 하고 축소하지 않는다, 종류마다 단위가 붙는다, 조용한 턴도 블록이 나간다.
## 문체는 docs/design/samples/rekka/ 의 표본으로 판단한다.

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


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _actor(id: String, name: String) -> Actor:
	return ActorScript.new(id, name, Actor.Kind.NPC_EXPLORER, 3)


func _event(kind: GameEvent.Kind, actor: Actor, room: Room, magnitude: int = 0) -> GameEvent:
	return EventScript.new(4, kind, actor, room, magnitude)


# ---------------------------------------------------------------- 라벨과 단위


func test_every_kind_has_a_korean_label() -> void:
	# 종류는 기사에서 사실로 전달된다. 빈 라벨이 하나라도 있으면 그 사건은 전달되지 않는다.
	for kind in ALL_KINDS:
		assert_ne(PromptScript.kind_label(kind), "", "라벨 없음: %d" % kind)


func test_only_moving_has_no_unit() -> void:
	# 이동에는 수치가 없다. 나머지는 단위가 있어야 모델이 "8명" 같은 오역을 안 한다.
	assert_eq(PromptScript.magnitude_unit(GameEvent.Kind.MOVED), "")
	for kind in ALL_KINDS:
		if kind == GameEvent.Kind.MOVED:
			continue
		assert_ne(PromptScript.magnitude_unit(kind), "", "단위 없음: %d" % kind)


# ---------------------------------------------------------------- 부풀리기


func test_inflate_never_shrinks() -> void:
	# 이 게임에서 가장 중요한 불변식이다 (docs/design/13-information-design.md §13.3).
	var rng := _rng(7)
	for i in 200:
		var actual := 1 + i % 13
		assert_true(PromptScript.inflate(actual, rng) >= actual, "축소 발생: %d" % actual)


func test_inflate_stays_within_bound() -> void:
	var rng := _rng(11)
	for i in 200:
		var actual := 1 + i % 13
		var reported := PromptScript.inflate(actual, rng)
		assert_true(reported <= actual * RekkaPrompt.INFLATE_MAX, "상한 초과: %d" % reported)


func test_zero_stays_zero() -> void:
	# 없는 일에 숫자를 붙이면 사건을 지어내는 것과 같다.
	assert_eq(PromptScript.inflate(0, _rng()), 0)
	assert_eq(PromptScript.inflate(-5, _rng()), 0)


# ---------------------------------------------------------------- 직렬화


func test_event_line_carries_the_four_slots() -> void:
	var actor := _actor("johan", "칼날의 요한")
	var room: Room = RoomScript.new("vault", "봉인된 금고")
	var line := PromptScript.serialize_event(_event(GameEvent.Kind.ACQUIRED, actor, room, 4), 11)

	assert_string_contains(line, "칼날의 요한")
	assert_string_contains(line, "봉인된 금고")
	assert_string_contains(line, "획득")
	assert_string_contains(line, "보도값=11")
	assert_string_contains(line, "단위=가치")


func test_actual_magnitude_is_not_leaked() -> void:
	# 실제값을 함께 넘기면 모델이 둘 사이에서 타협해 보도값보다 작은 수를 적는다.
	var actor := _actor("mina", "두더지 미나")
	var room: Room = RoomScript.new("store", "수장고")
	var line := PromptScript.serialize_event(_event(GameEvent.Kind.ACQUIRED, actor, room, 3), 8)

	assert_false(line.contains("=3"), "실제값이 프롬프트에 새어 나갔다: %s" % line)


func test_moving_carries_no_number() -> void:
	var actor := _actor("rahk", "장부의 라흐")
	var room: Room = RoomScript.new("hall", "회랑")
	var line := PromptScript.serialize_event(_event(GameEvent.Kind.MOVED, actor, room, 0), 0)

	assert_false(line.contains("보도값"), line)


func test_player_side_is_marked() -> void:
	# 자기 이야기를 못 읽으면 플레이어는 자기 노출도를 관리할 수 없다.
	var squad := _actor("player_squad", "우리 스쿼드")
	var room: Room = RoomScript.new("hall", "회랑")
	var line := PromptScript.serialize_event(
		_event(GameEvent.Kind.MOVED, squad, room), 0, "player_squad"
	)

	assert_string_contains(line, "소속=플레이어")


func test_other_side_is_marked() -> void:
	var actor := _actor("johan", "칼날의 요한")
	var room: Room = RoomScript.new("hall", "회랑")
	var line := PromptScript.serialize_event(
		_event(GameEvent.Kind.MOVED, actor, room), 0, "player_squad"
	)

	assert_string_contains(line, "소속=타인")


func test_related_ids_become_names() -> void:
	# GameEvent 는 상대를 id 로만 남긴다. 기사에 이름을 실으려면 되찾아야 한다.
	var squad := _actor("player_squad", "우리 스쿼드")
	var room: Room = RoomScript.new("hall", "회랑")
	var related: Array[String] = ["johan"]
	var event: GameEvent = EventScript.new(4, GameEvent.Kind.ENCOUNTERED, squad, room, 1, related)
	var line := PromptScript.serialize_event(event, 2, "player_squad", {"johan": "칼날의 요한"})

	assert_string_contains(line, "함께=칼날의 요한")


func test_unknown_related_id_survives_as_is() -> void:
	var squad := _actor("player_squad", "우리 스쿼드")
	var room: Room = RoomScript.new("hall", "회랑")
	var related: Array[String] = ["ghost_1"]
	var event: GameEvent = EventScript.new(4, GameEvent.Kind.ENCOUNTERED, squad, room, 1, related)

	assert_string_contains(PromptScript.serialize_event(event, 2), "함께=ghost_1")


# ---------------------------------------------------------------- 턴 블록


func test_quiet_turn_still_produces_a_block() -> void:
	# 조용한 턴에도 기사는 나가야 한다. 아무도 안 움직였다는 것도 정보다.
	var empty: Array[GameEvent] = []
	var block := PromptScript.serialize_turn(9, empty, "우리 스쿼드", _rng())

	assert_string_contains(block, "턴: 9")
	assert_string_contains(block, "사건: 없음")


func test_turn_block_lists_every_event() -> void:
	var actor := _actor("johan", "칼날의 요한")
	var room: Room = RoomScript.new("hall", "회랑")
	var events: Array[GameEvent] = [
		_event(GameEvent.Kind.MOVED, actor, room),
		_event(GameEvent.Kind.SEARCHED, actor, room, 2),
	]
	var block := PromptScript.serialize_turn(5, events, "우리 스쿼드", _rng())

	assert_eq(block.split("\n").size(), 5, block)
	assert_string_contains(block, "무엇을=이동")
	assert_string_contains(block, "무엇을=탐색")
