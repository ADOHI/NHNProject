extends GutTest
## 시설 배치의 단위 테스트.
##
## 배치가 결정이 되는 이유는 하나뿐이다 —
## **던전에 데려간 대원은 시설 효과를 내지 못한다** (docs/design/22-guild-base.md §22.4).
## 그것을 확인하는 것이 이 파일의 목적이다.

const AssignmentScript := preload("res://src/core/guild/facility_assignment.gd")


func _assignment() -> FacilityAssignment:
	return AssignmentScript.new()


func test_assign_and_read_back() -> void:
	var assignment := _assignment()
	assert_true(assignment.assign("a", Facility.Kind.WORKSHOP))
	assert_eq(assignment.facility_of("a"), int(Facility.Kind.WORKSHOP))
	assert_true(assignment.is_assigned("a"))


func test_unassigned_member_has_no_facility() -> void:
	assert_eq(_assignment().facility_of("a"), -1, "어디에도 없음은 시설의 한 종류가 아니다")


func test_one_member_one_facility() -> void:
	var assignment := _assignment()
	assignment.assign("a", Facility.Kind.WORKSHOP)
	assignment.assign("a", Facility.Kind.INTEL_ROOM)
	assert_eq(assignment.members_at(Facility.Kind.WORKSHOP).size(), 0, "겸직은 없다")
	assert_eq(assignment.members_at(Facility.Kind.INTEL_ROOM), ["a"] as Array[String])


func test_facility_capacity_is_enforced() -> void:
	var assignment := _assignment()
	for index in GuildBalance.FACILITY_CAPACITY:
		assert_true(assignment.assign("m%d" % index, Facility.Kind.WORKSHOP))
	assert_false(assignment.assign("overflow", Facility.Kind.WORKSHOP), "정원을 넘길 수 없다")


func test_reassigning_to_same_facility_is_allowed_when_full() -> void:
	var assignment := _assignment()
	for index in GuildBalance.FACILITY_CAPACITY:
		assignment.assign("m%d" % index, Facility.Kind.WORKSHOP)
	assert_true(assignment.assign("m0", Facility.Kind.WORKSHOP), "이미 있는 자리는 다시 넣어도 된다")


## 핵심 — 출전한 대원은 배치가 남아 있어도 일하지 않는다.
func test_deployed_members_do_not_staff_facilities() -> void:
	var assignment := _assignment()
	assignment.assign("a", Facility.Kind.WORKSHOP)
	assignment.assign("b", Facility.Kind.WORKSHOP)
	assert_eq(assignment.staff_count(Facility.Kind.WORKSHOP), 2)
	assert_eq(
		assignment.staff_count(Facility.Kind.WORKSHOP, ["a"] as Array[String]), 1, "출전한 대원은 세지 않는다"
	)


func test_deployed_member_keeps_its_slot() -> void:
	var assignment := _assignment()
	assignment.assign("a", Facility.Kind.INTEL_ROOM)
	assert_eq(assignment.staff_count(Facility.Kind.INTEL_ROOM, ["a"] as Array[String]), 0)
	assert_true(assignment.is_assigned("a"), "돌아오면 원래 자리로 돌아가야 한다")


func test_unassign_and_retain_only() -> void:
	var assignment := _assignment()
	assignment.assign("a", Facility.Kind.WORKSHOP)
	assignment.assign("b", Facility.Kind.CONTACT_POINT)
	assignment.unassign("a")
	assert_false(assignment.is_assigned("a"))
	assignment.retain_only([] as Array[String])
	assert_false(assignment.is_assigned("b"), "길드에서 빠진 대원의 배치는 정리된다")
