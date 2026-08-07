extends GutTest
## RekkaPrompt 의 **편집 규칙** 테스트 — 몇 편을 쓰는가, 어떤 결로 쓰는가.
##
## 이 둘은 원래 프롬프트의 지침이었고, 모델은 둘 다 지키지 않았다
## (docs/design/19-rekka-voice.md §19.6). 실제 호출로 확인한 뒤 코드로 옮긴 것이다.
##
## 등급 변환은 test_rekka_grades.gd, 직렬화는 test_rekka_prompt.gd 에 있다.

const ActorScript := preload("res://src/core/dungeon/actor.gd")
const RoomScript := preload("res://src/core/dungeon/room.gd")
const EventScript := preload("res://src/core/event/game_event.gd")
const PromptScript := preload("res://src/core/rekka/rekka_prompt.gd")


func _actor(id: String, name: String) -> Actor:
	return ActorScript.new(id, name, Actor.Kind.NPC_EXPLORER, 3)


func _event(kind: GameEvent.Kind, room_id: String, magnitude: int = 0) -> GameEvent:
	var room: Room = RoomScript.new(room_id, room_id)
	return EventScript.new(4, kind, _actor("johan", "칼날의 요한"), room, magnitude)


# ---------------------------------------------------------------- 편수


func test_quiet_turn_gets_exactly_one_article() -> void:
	# 모델에게 맡겼더니 사건 없는 턴에 세 편을 썼다. 편수는 규칙이다.
	var empty: Array[GameEvent] = []
	assert_eq(PromptScript.article_count(empty), 1)


func test_movement_only_turn_is_collapsed_into_one() -> void:
	# 이동만 있는 턴은 한 편에 몰아 담는다. 방마다 한 편씩 쓰면 피드가 이동으로 덮인다.
	var events: Array[GameEvent] = [
		_event(GameEvent.Kind.MOVED, "hall"),
		_event(GameEvent.Kind.MOVED, "stair"),
		_event(GameEvent.Kind.MOVED, "yard"),
	]
	assert_eq(PromptScript.article_count(events), 1)


func test_one_article_per_room() -> void:
	# 같은 방 사건은 한 기사로 묶이므로 방의 수가 곧 편수다.
	var events: Array[GameEvent] = [
		_event(GameEvent.Kind.FOUGHT, "throne", 4),
		_event(GameEvent.Kind.ENCOUNTERED, "throne", 2),
	]
	assert_eq(PromptScript.article_count(events), 1)

	events.append(_event(GameEvent.Kind.SEARCHED, "cell", 1))
	assert_eq(PromptScript.article_count(events), 2)


func test_leftover_movement_earns_one_more_article() -> void:
	# 버려지는 이동도 방 이름은 살려야 한다. 자리가 남으면 한 편을 더 준다.
	var events: Array[GameEvent] = [
		_event(GameEvent.Kind.ACQUIRED, "vault", 6),
		_event(GameEvent.Kind.MOVED, "stair"),
	]
	assert_eq(PromptScript.article_count(events), 2)


func test_movement_into_a_room_that_already_has_news_adds_nothing() -> void:
	# 같은 사람이 옮겨 와서 뭔가 했으면 이동은 결과에 흡수된다.
	var events: Array[GameEvent] = [
		_event(GameEvent.Kind.MOVED, "throne"),
		_event(GameEvent.Kind.FOUGHT, "throne", 4),
	]
	assert_eq(PromptScript.article_count(events), 1)


func test_article_count_never_exceeds_the_cap() -> void:
	# 화면이 좁다. 여섯 건이 여섯 편이 되면 피드가 넘친다.
	var events: Array[GameEvent] = []
	for i in 9:
		events.append(_event(GameEvent.Kind.FOUGHT, "room_%d" % i, 2))
	assert_eq(PromptScript.article_count(events), PromptScript.MAX_ARTICLES)


# ---------------------------------------------------------------- 결


func test_shape_hint_names_both_a_title_and_a_body_shape() -> void:
	var hint := PromptScript.shape_hint(0)
	assert_string_contains(hint, "제목")
	assert_string_contains(hint, "본문")


func test_no_shape_pair_repeats_within_a_full_cycle() -> void:
	# 짝이 겹치기 시작하는 순간 그 판 기사는 같은 틀로 읽힌다.
	# 실측에서 이 배정이 없을 때 서로 다른 짝은 넷뿐이었다 (§19.6.2).
	var seen: Dictionary = {}
	var cycle := PromptScript.TITLE_SHAPES.size() * PromptScript.BODY_SHAPES.size()
	for index in cycle:
		var hint := PromptScript.shape_hint(index)
		assert_false(seen.has(hint), "짝이 겹쳤다: %d -> %s" % [index, hint])
		seen[hint] = true
	assert_eq(seen.size(), cycle)


func test_consecutive_articles_never_share_a_title_shape() -> void:
	for index in 40:
		assert_ne(
			PromptScript.shape_hint(index),
			PromptScript.shape_hint(index + 1),
			"연달아 같은 결: %d" % index
		)


func test_order_block_lists_exactly_the_requested_number() -> void:
	var order := PromptScript.serialize_order(0, 3)

	assert_string_contains(order, "정확히 3편")
	assert_string_contains(order, "1번째 기사")
	assert_string_contains(order, "3번째 기사")
	assert_false(order.contains("4번째"), order)
