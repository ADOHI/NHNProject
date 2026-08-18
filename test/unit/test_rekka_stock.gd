extends GutTest
## RekkaStock 테스트 — **예비 문안은 지어내지 않는다.**
##
## 자산에 없는 조합에서도 피드는 비지 않아야 한다
## (docs/design/32-rekka-feed.md §32.4, 19-rekka-voice.md §19.10).
## 밋밋한 것은 톤 손실이지만 **틀린 것은 정보원의 죽음**이므로,
## 여기서 지키는 것은 "언제나 나온다" 와 "사실을 안 건드린다" 둘이다.

const ActorScript := preload("res://src/core/dungeon/actor.gd")
const RoomScript := preload("res://src/core/dungeon/room.gd")
const EventScript := preload("res://src/core/event/game_event.gd")
const StockScript := preload("res://src/core/rekka/rekka_stock.gd")
const PromptScript := preload("res://src/core/rekka/rekka_prompt.gd")

var _room: Room
var _johan: Actor
var _mina: Actor


func before_each() -> void:
	_room = RoomScript.new("hall", "회랑", 0, Room.Kind.EMPTY)
	_johan = ActorScript.new("johan", "칼날의 요한", Actor.Kind.NPC_EXPLORER, 4, 2)
	_mina = ActorScript.new("mina", "두더지 미나", Actor.Kind.NPC_EXPLORER, 3, 2)


func _event(kind: GameEvent.Kind, magnitude: int = 0, with_other: bool = false) -> GameEvent:
	var related: Array[String] = ["mina"] if with_other else [] as Array[String]
	return EventScript.new(4, kind, _johan, _room, magnitude, related)


func _names() -> Dictionary:
	return {"johan": "칼날의 요한", "mina": "두더지 미나"}


# ---------------------------------------------------------------- 사실 줄


func test_fact_lines_carry_the_serialised_event_word_for_word() -> void:
	# 사실 줄을 새로 쓰지 않는다. 이미 사실인 문장을 쓰고 말투만 얹는다.
	var event := _event(GameEvent.Kind.SEARCHED, 2)
	var lines := StockScript.fact_lines([event], [] as Array[String], _names(), 0, 7)

	var sentence := PromptScript.serialize_event(event, _names())
	assert_eq(lines.size(), 1, str(lines))
	assert_true(lines[0].begins_with(sentence.trim_suffix(".")), "%s / %s" % [lines[0], sentence])


func test_the_grade_is_never_rewritten() -> void:
	# 등급은 사실이다. 코드가 올리지도 내리지도 않는다 (19-rekka-voice.md §19.3.3).
	for index in 12:
		var lines := StockScript.fact_lines(
			[_event(GameEvent.Kind.SEARCHED, 12)], [] as Array[String], _names(), index, 3
		)
		assert_string_contains(lines[0], "대박")
		assert_false(lines[0].contains("한몫"), lines[0])


func test_context_facts_are_never_all_dropped() -> void:
	# 문맥이 있는데 한 줄도 안 나가면 판을 읽을 재료가 없다 (§19.B.9 1차).
	var events: Array[GameEvent] = []
	for i in RekkaPrompt.MAX_EVENTS:
		events.append(_event(GameEvent.Kind.MOVED))
	var facts: Array[String] = ["회랑은 길목이다", "밀실은 막다른 방이다"]

	for index in 16:
		var lines := StockScript.fact_lines(events, facts, _names(), index, 11)
		assert_gt(lines.size(), events.size(), "문맥이 한 줄도 안 나갔다 (번호 %d)" % index)


func test_body_length_is_not_always_the_same() -> void:
	# 실측에서 28편의 본문이 전부 정확히 여섯 줄이었다 (§19.B.8).
	var seen: Dictionary = {}
	for index in 20:
		seen[StockScript.body_limit(index, 20260808)] = true
	assert_gt(seen.size(), 1, "본문 길이 분산이 0 이다")


func test_body_limit_stays_inside_its_band() -> void:
	for index in 40:
		var limit := StockScript.body_limit(index, 771)
		assert_between(limit, StockScript.BODY_MIN, StockScript.BODY_MAX, "번호 %d" % index)


# ---------------------------------------------------------------- 제목


func test_a_title_never_comes_out_empty() -> void:
	for kind in GameEvent.Kind.values():
		for index in 6:
			var title := StockScript.title_for(_event(kind, 3), _names(), index, 5)
			assert_false(title.is_empty(), "종류 %d 번호 %d" % [kind, index])


func test_a_title_never_names_a_partner_that_is_not_there() -> void:
	# 상대가 없는 사건에 상대 이름이 나오면 그 순간 기사가 거짓말이 된다.
	for index in 12:
		var title := StockScript.title_for(_event(GameEvent.Kind.FOUGHT, 2), _names(), index, 9)
		assert_false(title.contains("두더지 미나"), title)


func test_a_quiet_turn_still_gets_a_title() -> void:
	# 조용한 턴에도 기사는 나간다. 아무 일도 없었다는 것 자체가 판을 읽는 재료다.
	var title := StockScript.title_for(null, {}, 0, 0)
	assert_has(StockScript.QUIET_TITLES, title)


# ---------------------------------------------------------------- 댓글


func test_comments_in_one_post_get_different_placeholders() -> void:
	# 자리표시가 같으면 후처리가 **같은 사람**으로 보고 닉을 하나만 배정한다.
	for index in 8:
		var lines := StockScript.comment_lines(index, 13)
		var marks: Dictionary = {}
		for line in lines:
			marks[line.substr(0, line.find("]") + 1)] = true
		assert_eq(marks.size(), lines.size(), "자리표시가 겹친다: %s" % str(lines))


func test_the_number_of_comments_varies() -> void:
	var seen: Dictionary = {}
	for index in 20:
		seen[StockScript.comment_lines(index, 31337).size()] = true
	assert_gt(seen.size(), 1, "댓글 수가 편마다 같다")


func test_remarks_never_state_a_fact() -> void:
	# 논평은 어떤 사건에나 붙는다. 사실을 담으면 그 사건이 아닌 편에서 거짓말이 된다.
	for line in StockScript.REMARKS:
		assert_false(line.contains("{"), "논평에 자리표시가 있다: %s" % line)
