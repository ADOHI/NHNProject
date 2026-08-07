extends GutTest
## 대형 자리 만들기와 배정의 단위 테스트.
##
## **뭉침 처리의 절반이 여기서 결정된다.** 전원에게 같은 좌표를 주면 서로 그 한 점을
## 차지하려고 영원히 밀어댄다. 자리가 서로 다르고, 두 유닛이 같은 자리를 받지 않는 것이
## 도착이 끝나기 위한 최소 조건이다.

const _ALWAYS_FREE := "_free"


func _free(_point: Vector2) -> bool:
	return true


func _left_half_only(point: Vector2) -> bool:
	return point.x < 500.0


func test_slot_count_matches_request() -> void:
	var slots := ProtoFormation.build_slots(
		12, Vector2(300, 300), 30.0, Callable(self, _ALWAYS_FREE)
	)
	assert_eq(slots.size(), 12)


func test_zero_units_get_no_slots() -> void:
	var slots := ProtoFormation.build_slots(0, Vector2.ZERO, 30.0, Callable(self, _ALWAYS_FREE))
	assert_eq(slots.size(), 0)


func test_slots_do_not_sit_on_top_of_each_other() -> void:
	var slots := ProtoFormation.build_slots(
		20, Vector2(400, 400), 30.0, Callable(self, _ALWAYS_FREE)
	)
	for i in slots.size():
		for j in range(i + 1, slots.size()):
			assert_gt(slots[i].distance_to(slots[j]), 20.0, "자리 %d 와 %d 가 겹친다" % [i, j])


func test_first_slot_is_the_command_point() -> void:
	# 한 명만 보내면 찍은 자리에 정확히 서야 한다. 여기서 어긋나면 명령이 부정확해 보인다.
	var slots := ProtoFormation.build_slots(
		1, Vector2(123, 456), 30.0, Callable(self, _ALWAYS_FREE)
	)
	assert_almost_eq(slots[0].x, 123.0, 0.01)
	assert_almost_eq(slots[0].y, 456.0, 0.01)


func test_blocked_area_is_skipped() -> void:
	var slots := ProtoFormation.build_slots(
		10, Vector2(480, 300), 30.0, Callable(self, "_left_half_only")
	)
	assert_eq(slots.size(), 10)
	for slot in slots:
		assert_lt(slot.x, 500.0, "통행 불가 자리가 배정되었다")


func test_every_unit_gets_a_distinct_slot() -> void:
	var positions := PackedVector2Array(
		[Vector2(0, 0), Vector2(50, 0), Vector2(0, 50), Vector2(50, 50)]
	)
	var slots := ProtoFormation.build_slots(
		4, Vector2(400, 400), 30.0, Callable(self, _ALWAYS_FREE)
	)
	var assignment := ProtoFormation.assign(positions, slots)
	var seen := {}
	for index in assignment:
		assert_false(seen.has(index), "같은 자리를 두 유닛이 받았다")
		assert_gt(index, -1, "자리를 못 받은 유닛이 있다")
		seen[index] = true


func test_nearest_unit_takes_the_inner_slot() -> void:
	# 가까운 유닛이 안쪽을 차지해야 접근 순서가 그대로 대형이 된다.
	var positions := PackedVector2Array([Vector2(1000, 400), Vector2(430, 400)])
	var slots := ProtoFormation.build_slots(
		2, Vector2(400, 400), 30.0, Callable(self, _ALWAYS_FREE)
	)
	var assignment := ProtoFormation.assign(positions, slots)
	assert_eq(assignment[1], 0, "가까운 유닛이 첫 자리를 받아야 한다")
	assert_eq(assignment[0], 1)


func test_more_units_than_slots_leaves_some_unassigned() -> void:
	var positions := PackedVector2Array([Vector2.ZERO, Vector2(10, 0), Vector2(20, 0)])
	var slots := PackedVector2Array([Vector2(100, 100)])
	var assignment := ProtoFormation.assign(positions, slots)
	var assigned := 0
	for index in assignment:
		if index >= 0:
			assigned += 1
	assert_eq(assigned, 1)
