extends GutTest
## RekkaPrompt 의 **등급 체계** 테스트.
##
## 수치를 기사에 싣지 않기로 하면서 magnitude 는 등급으로 옮겨졌다
## (docs/design/19-rekka-voice.md §19.3.3). 여기서 지키는 것은 그 변환의 성질이다 —
## 축이 갈린다, 순서가 뒤집히지 않는다, 경계가 고정이다, 같은 사건은 같은 등급이다.
##
## 직렬화와 턴 블록은 test_rekka_prompt.gd 에 있다.
## 한 파일에 몰면 공개 함수 20개 상한(gdlint max-public-methods)에 걸린다.
##
## **부풀리기 테스트는 폐기됐다.** 과장은 사실이 아니라 어투에만 있으므로
## 코드가 등급을 올리는 일이 없어졌다 (§19.5.5).

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

# ---------------------------------------------------------------- 라벨과 축


func test_every_kind_has_a_korean_label() -> void:
	# 종류는 기사에서 사실로 전달된다. 빈 라벨이 하나라도 있으면 그 사건은 전달되지 않는다.
	for kind in ALL_KINDS:
		assert_ne(PromptScript.kind_label(kind), "", "라벨 없음: %d" % kind)


func test_only_moving_counts_nothing() -> void:
	# 이동에는 셀 것이 없다. 나머지는 축이 있어야 모델이 값어치를 사람 수로 안 읽는다.
	assert_eq(PromptScript.axis_of(GameEvent.Kind.MOVED), PromptScript.Axis.NONE)
	for kind in ALL_KINDS:
		if kind == GameEvent.Kind.MOVED:
			continue
		assert_ne(PromptScript.axis_of(kind), PromptScript.Axis.NONE, "축 없음: %d" % kind)


func test_value_and_headcount_never_share_an_axis() -> void:
	# 획득의 4 와 전투의 4 는 전혀 다른 값이다. 같은 축에 실리면 기사가 오역된다.
	assert_eq(PromptScript.axis_of(GameEvent.Kind.ACQUIRED), PromptScript.Axis.HAUL)
	assert_eq(PromptScript.axis_of(GameEvent.Kind.FOUGHT), PromptScript.Axis.CROWD)


# ---------------------------------------------------------------- 순서와 경계


func test_haul_grade_never_goes_down_as_value_rises() -> void:
	# 등급은 순서가 있는 척도다. 뒤집히면 플레이어가 기사로 방을 고를 수 없다.
	var previous := 0
	for magnitude in 40:
		var index := PromptScript.HAUL_GRADES.find(PromptScript.haul_grade(magnitude))
		assert_true(index >= previous, "등급이 내려갔다: %d" % magnitude)
		previous = index


func test_crowd_grade_never_goes_down_as_headcount_rises() -> void:
	var previous := 0
	for magnitude in range(1, 40):
		var index := PromptScript.CROWD_GRADES.find(PromptScript.crowd_grade(magnitude))
		assert_true(index >= previous, "등급이 내려갔다: %d" % magnitude)
		previous = index


func test_haul_boundaries_are_fixed() -> void:
	# 경계가 흔들리면 표본과 실제 판이 어긋나 검증이 무의미해진다.
	assert_eq(PromptScript.haul_grade(0), "빈손")
	assert_eq(PromptScript.haul_grade(1), "푼돈")
	assert_eq(PromptScript.haul_grade(3), "푼돈")
	assert_eq(PromptScript.haul_grade(4), "한몫")
	assert_eq(PromptScript.haul_grade(9), "한몫")
	assert_eq(PromptScript.haul_grade(10), "대박")


func test_crowd_boundaries_are_fixed() -> void:
	assert_eq(PromptScript.crowd_grade(1), "맞대면")
	assert_eq(PromptScript.crowd_grade(2), "한줌")
	assert_eq(PromptScript.crowd_grade(3), "한줌")
	assert_eq(PromptScript.crowd_grade(4), "떼거리")


func test_empty_handed_is_still_a_grade() -> void:
	# 허탕도 정보다. 저 방은 이미 털렸다는 뜻이다.
	assert_eq(PromptScript.haul_grade(0), "빈손")


func test_missing_headcount_produces_no_grade() -> void:
	# 0 을 등급으로 만들면 "아무도 없는 전투" 가 기사에 실린다.
	assert_eq(PromptScript.crowd_grade(0), "")
	assert_eq(PromptScript.crowd_grade(-3), "")


func test_the_same_event_always_gets_the_same_grade() -> void:
	# 과장은 어투에만 있다. 코드가 등급을 올리는 일은 없다 (§19.5.5).
	var actor: Actor = ActorScript.new("mina", "두더지 미나", Actor.Kind.NPC_EXPLORER, 3)
	var room: Room = RoomScript.new("store", "수장고")
	var event: GameEvent = EventScript.new(4, GameEvent.Kind.ACQUIRED, actor, room, 5)
	var first := PromptScript.grade_of(event)

	assert_eq(first, "한몫")
	for _i in 20:
		assert_eq(PromptScript.grade_of(event), first)
