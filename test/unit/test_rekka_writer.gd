extends GutTest
## RekkaWriter 테스트 — 자산과 규칙이 만나는 자리.
##
## 지키는 것은 셋이다 (docs/design/32-rekka-feed.md §32.2).
##
##   1. **사실 줄은 자산과 무관하게 언제나 나온다.** 자산에 빈칸이 있어도 정보가 안 샌다
##   2. **두 경로가 같은 문(RekkaPost.clean)을 지난다.** 갈리면 한쪽만 규칙을 어긴다
##   3. **자산이 사실을 말하지 않는다.** 자산이 쓸 수 있는 자리는 제목 · 논평 · 댓글뿐이다

const ActorScript := preload("res://src/core/dungeon/actor.gd")
const RoomScript := preload("res://src/core/dungeon/room.gd")
const EventScript := preload("res://src/core/event/game_event.gd")
const LibraryScript := preload("res://src/core/rekka/rekka_library.gd")
const WriterScript := preload("res://src/core/rekka/rekka_writer.gd")

var _room: Room
var _johan: Actor
var _empty: RekkaLibrary


func before_each() -> void:
	_room = RoomScript.new("hall", "회랑", 0, Room.Kind.EMPTY)
	_johan = ActorScript.new("johan", "칼날의 요한", Actor.Kind.NPC_EXPLORER, 4, 2)
	_empty = LibraryScript.new()


func _event(kind: GameEvent.Kind, magnitude: int = 0) -> GameEvent:
	return EventScript.new(4, kind, _johan, _room, magnitude)


func _rooms() -> Array[String]:
	return ["회랑"] as Array[String]


func _write(events: Array[GameEvent], library: RekkaLibrary, index: int = 0) -> String:
	var facts: Array[String] = ["<회랑>은 길목이라 지나갈 수밖에 없는 방이다"]
	return WriterScript.write(events, facts, {}, _rooms(), index, 0, 7, library)


# ---------------------------------------------------------------- 사실은 언제나 나간다


func test_the_facts_survive_an_empty_library() -> void:
	var text := _write([_event(GameEvent.Kind.SEARCHED, 2)], _empty)

	assert_string_contains(text, "칼날의 요한")
	assert_string_contains(text, "회랑")
	assert_string_contains(text, "푼돈")


func test_the_facts_survive_a_library_that_has_the_key() -> void:
	# 자산이 있어도 사실 줄이 밀려나면 그 편은 정보를 잃는다.
	var library: RekkaLibrary = LibraryScript.new()
	library.keys.append("SEARCHED:푼돈")
	library.posts.append("{방} 결과 푼돈이다\n[가] 그럴 줄 알았다")

	var text := _write([_event(GameEvent.Kind.SEARCHED, 2)], library)

	assert_string_contains(text, "칼날의 요한")
	assert_string_contains(text, "수색했다")


func test_a_quiet_turn_still_produces_a_post() -> void:
	# 피드는 절대 비지 않는다 (19-rekka-voice.md §19.10).
	var text := _write([] as Array[GameEvent], _empty)
	assert_false(text.strip_edges().is_empty())


func test_every_kind_and_grade_produces_something() -> void:
	for kind in GameEvent.Kind.values():
		for magnitude in [0, 1, 5, 12]:
			var text := _write([_event(kind, magnitude)], LibraryScript.shared())
			assert_false(text.strip_edges().is_empty(), "종류 %d 규모 %d" % [kind, magnitude])


# ---------------------------------------------------------------- 하나의 문


func test_both_paths_pass_through_the_post_filter() -> void:
	# 자산 쪽에만 꺾쇠가 남거나 규칙 쪽에만 접두어가 안 붙으면 스무 편째에 보인다.
	var library: RekkaLibrary = LibraryScript.new()
	library.keys.append("MOVED:")
	library.posts.append("<{주체}> 또 움직임\n[가] 어디 가냐")

	for pair in [[library, "자산"], [_empty, "규칙"]]:
		var text := _write([_event(GameEvent.Kind.MOVED)], pair[0])
		assert_false(text.contains("<"), "%s 경로에 꺾쇠가 남았다: %s" % [pair[1], text])
		assert_false(text.contains(">"), "%s 경로에 꺾쇠가 남았다: %s" % [pair[1], text])


func test_no_measured_numbers_reach_the_screen() -> void:
	# 이 게임의 전투는 피해가 오가는 방식이 아니다 (05-rules.md §5.8).
	for index in 8:
		var text := _write([_event(GameEvent.Kind.FOUGHT, 3)], LibraryScript.shared(), index)
		assert_eq(RekkaPost.blocked_numbers(text), [] as Array[String], text)


func test_the_title_prefix_is_the_assigned_one() -> void:
	# 모델이 붙인 접두어는 버린다 — 실측에서 `[속보]` 가 5편 중 4편에 붙었다.
	var library: RekkaLibrary = LibraryScript.new()
	library.keys.append("MOVED:")
	library.posts.append("[속보] {주체} 움직임\n[가] ㅇㅇ")

	var text := _write([_event(GameEvent.Kind.MOVED)], library)
	var title: String = text.split("\n")[0]

	assert_false(title.begins_with("[속보]"), title)


# ---------------------------------------------------------------- 머리 사건


func test_the_key_follows_the_ranked_event_not_the_first_one() -> void:
	# 순위는 "플레이어가 다음 턴 결정을 내리는 데 얼마나 쓸모 있는가" 다.
	var moved := _event(GameEvent.Kind.MOVED)
	var downed := _event(GameEvent.Kind.DOWNED, 1)

	assert_eq(WriterScript.head_of([moved, downed] as Array[GameEvent]), downed)
	assert_eq(WriterScript.head_of([downed, moved] as Array[GameEvent]), downed)


func test_head_of_an_empty_turn_is_null() -> void:
	assert_null(WriterScript.head_of([] as Array[GameEvent]))


func test_an_asset_line_that_cannot_be_filled_is_replaced_not_shown() -> void:
	# 상대가 없는데 `{상대}` 가 남으면 문장이 거짓이 된다.
	var library: RekkaLibrary = LibraryScript.new()
	library.keys.append("MOVED:")
	library.posts.append("{상대이} 어디 갔냐\n[가] {상대} 봤음")

	var text := _write([_event(GameEvent.Kind.MOVED)], library)

	assert_false(text.contains("{"), text)
	assert_false(text.contains("상대"), text)
	assert_string_contains(text, "[")
