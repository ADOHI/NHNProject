extends GutTest
## 부대 지정의 단위 테스트.
##
## 연타 판정은 시간에 의존한다. 손으로는 확인이 어렵고(연타에 실패했는지 규칙이 틀렸는지
## 구분되지 않는다) 회귀도 조용히 일어난다. 시각을 인자로 받게 만든 이유가 여기 있다.


func test_assign_then_recall() -> void:
	var groups := ProtoControlGroups.new()
	groups.assign(1, PackedInt32Array([3, 4, 5]))
	assert_eq(groups.members(1), PackedInt32Array([3, 4, 5]))
	assert_eq(groups.size(1), 3)
	assert_true(groups.has_members(1))


func test_assign_replaces_previous() -> void:
	var groups := ProtoControlGroups.new()
	groups.assign(2, PackedInt32Array([1, 2]))
	groups.assign(2, PackedInt32Array([9]))
	assert_eq(groups.members(2), PackedInt32Array([9]))


func test_append_merges_without_duplicates() -> void:
	var groups := ProtoControlGroups.new()
	groups.assign(3, PackedInt32Array([1, 2]))
	groups.append(3, PackedInt32Array([2, 3]))
	assert_eq(groups.members(3), PackedInt32Array([1, 2, 3]))


func test_empty_slot_is_empty() -> void:
	var groups := ProtoControlGroups.new()
	assert_false(groups.has_members(5))
	assert_eq(groups.size(5), 0)


func test_slot_out_of_range_is_ignored() -> void:
	var groups := ProtoControlGroups.new()
	groups.assign(ProtoControlGroups.SLOT_COUNT, PackedInt32Array([1]))
	groups.assign(-1, PackedInt32Array([1]))
	assert_eq(groups.members(ProtoControlGroups.SLOT_COUNT), PackedInt32Array())


func test_members_returns_a_copy() -> void:
	# 밖에서 고쳐도 저장된 부대는 그대로여야 한다. 화면 코드가 실수로 부대를 지우면 안 된다.
	var groups := ProtoControlGroups.new()
	groups.assign(1, PackedInt32Array([1, 2]))
	var taken := groups.members(1)
	taken.append(3)
	assert_eq(groups.size(1), 2)


func test_second_press_within_window_is_a_double_tap() -> void:
	var groups := ProtoControlGroups.new()
	assert_false(groups.note_press(1, 1000), "첫 누름은 연타가 아니다")
	assert_true(groups.note_press(1, 1000 + ProtoControlGroups.DOUBLE_TAP_MSEC - 1))


func test_slow_second_press_is_not_a_double_tap() -> void:
	var groups := ProtoControlGroups.new()
	groups.note_press(1, 1000)
	assert_false(groups.note_press(1, 1000 + ProtoControlGroups.DOUBLE_TAP_MSEC + 1))


func test_different_slot_breaks_the_double_tap() -> void:
	var groups := ProtoControlGroups.new()
	groups.note_press(1, 1000)
	assert_false(groups.note_press(2, 1010), "다른 부대를 부른 것은 연타가 아니다")


func test_third_press_does_not_double_tap_again() -> void:
	# 연타로 화면을 옮긴 뒤 한 번 더 누른 것까지 화면 이동이 되면 손이 미끄러진다.
	var groups := ProtoControlGroups.new()
	groups.note_press(1, 1000)
	assert_true(groups.note_press(1, 1100))
	assert_false(groups.note_press(1, 1200))


func test_retain_drops_missing_units_from_every_slot() -> void:
	var groups := ProtoControlGroups.new()
	groups.assign(1, PackedInt32Array([1, 2, 3]))
	groups.assign(2, PackedInt32Array([3, 4]))
	groups.retain(PackedInt32Array([1, 3]))
	assert_eq(groups.members(1), PackedInt32Array([1, 3]))
	assert_eq(groups.members(2), PackedInt32Array([3]))
