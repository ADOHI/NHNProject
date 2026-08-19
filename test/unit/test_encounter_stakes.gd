extends GutTest
## **E5 — 특수방에서 마주쳤을 때.** docs/design/05-rules.md §5.6 E5.
##
## §5.6 이 *"보류 — 구현하며 결정"* 으로 남긴 것을
## docs/design/35-encounter.md §35.3.2 가 이렇게 채웠다.
##
## > **방은 분기를 바꾸지 않는다. 방은 판돈과 확률을 바꾼다.**
##
## 이 파일이 지키는 것이 그 한 줄이다 — **어느 방에서도 고를 수 있는 것은 같다.**
## 방마다 선택지가 달라지면 심리전이 *"이 방에서는 무엇을 고를 수 있더라"* 라는
## 암기 문제가 된다.

# ---------------------------------------------------------------- 방은 분기를 안 바꾼다


func test_no_room_takes_a_choice_away() -> void:
	# 몬스터가 없으면 어느 방에서도 협력이 안 열리고, 나머지 셋은 어디서나 열린다.
	for kind in [
		Room.Kind.ENTRANCE,
		Room.Kind.EMPTY,
		Room.Kind.TREASURE,
		Room.Kind.HAZARD,
		Room.Kind.BOSS,
		Room.Kind.EXIT
	]:
		var stakes := EncounterStakes.of(kind, 0)
		assert_not_null(stakes, "방 종류가 판돈을 못 냈다")
		assert_true(EncounterChoice.is_open(EncounterChoice.Kind.FIGHT, false))
		assert_true(EncounterChoice.is_open(EncounterChoice.Kind.NEGOTIATE, false))
		assert_true(EncounterChoice.is_open(EncounterChoice.Kind.FLEE, false))


# ---------------------------------------------------------------- 판돈


func test_a_treasure_room_puts_what_is_left_on_the_table() -> void:
	# *"늦으면 이미 털려 있다"*(§5.2)가 조우에서도 성립해야 한다.
	var stakes := EncounterStakes.of(Room.Kind.TREASURE, 5)

	assert_true(stakes.has_pot())
	assert_eq(stakes.pot, 5)


func test_an_emptied_room_has_nothing_on_the_table() -> void:
	assert_false(EncounterStakes.of(Room.Kind.TREASURE, 0).has_pot())


func test_the_pot_is_split_and_the_rest_stays_in_the_room() -> void:
	# 나눠떨어지지 않는 것을 누구에게 얹으면 "누구부터 세는가"가 규칙이 된다.
	var stakes := EncounterStakes.of(Room.Kind.TREASURE, 5)

	assert_eq(stakes.share_for(2), 2, "몫이 다르다")
	assert_eq(stakes.remainder_for(2), 1, "남은 것이 방에 안 남는다")


func test_a_pot_smaller_than_the_table_splits_into_nothing() -> void:
	var stakes := EncounterStakes.of(Room.Kind.TREASURE, 1)

	assert_eq(stakes.share_for(3), 0)
	assert_eq(stakes.remainder_for(3), 1, "나눌 수 없는 것이 사라졌다")


# ---------------------------------------------------------------- 확률


func test_a_hazard_room_is_a_good_place_to_run() -> void:
	# 함정방을 「그냥 나쁜 방」이 아니라 **쓸 데가 있는 방**으로 만든다.
	assert_eq(
		EncounterStakes.of(Room.Kind.HAZARD, 0).flight_bonus, EncounterStakes.HAZARD_FLIGHT_BONUS
	)


func test_ordinary_rooms_do_not_help_you_run() -> void:
	for kind in [Room.Kind.EMPTY, Room.Kind.TREASURE, Room.Kind.BOSS, Room.Kind.EXIT]:
		assert_eq(EncounterStakes.of(kind, 0).flight_bonus, 0, "보통 방이 도주를 도왔다")


# ---------------------------------------------------------------- 문 앞


func test_backing_off_at_the_door_costs_you_the_wait() -> void:
	# §5.9 — *"다 챙기고 문 앞에서 죽는 것"* 이 절정이다.
	# **문 앞에서 물러나는 데 대가가 없으면 절정이 없다.**
	assert_true(EncounterStakes.of(Room.Kind.EXIT, 0).flight_clears_escape)


func test_backing_off_anywhere_else_costs_nothing() -> void:
	for kind in [Room.Kind.EMPTY, Room.Kind.TREASURE, Room.Kind.HAZARD, Room.Kind.BOSS]:
		assert_false(EncounterStakes.of(kind, 0).flight_clears_escape, "탈출 지점이 아닌데 진행이 지워진다")
