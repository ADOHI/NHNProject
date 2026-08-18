extends GutTest
## 건물을 놓는 중인 상태의 단위 테스트.
##
## 지키는 것 셋이다 (docs/design/30-hideout.md §30.4).
##
## - **못 놓는 자리에 확정해도 판이 안 바뀐다**
## - **옮기는 중에는 제 몸이 걸림돌이 아니다** — 한 칸 옮기기가 막히면 그건 버그다
## - **취소하면 원래 자리 그대로다**

const GridScript := preload("res://src/core/hideout/hideout_grid.gd")
const BuildingScript := preload("res://src/core/hideout/hideout_building.gd")
const PlacementScript := preload("res://src/core/hideout/hideout_placement.gd")

var _grid: HideoutGrid
var _plan: HideoutPlacement


func before_each() -> void:
	_grid = GridScript.new(12, 12)
	_plan = PlacementScript.new(_grid)


func _put(building_id: String, kind: int, at: Vector2i) -> HideoutBuilding:
	var building: HideoutBuilding = BuildingScript.new(
		building_id, kind, HideoutBuilding.footprint_for(kind), at
	)
	_grid.place(building)
	return building


# ------------------------------------------------------------------ 발자국 출처


## 크기가 두 곳에 살면 미리보기와 실제 건물이 달라진다.
func test_footprint_has_one_source() -> void:
	assert_eq(HideoutBuilding.footprint_for(Facility.Kind.WORKSHOP), Vector2i(2, 2))
	assert_eq(HideoutBuilding.footprint_for(Facility.Kind.INTEL_ROOM), Vector2i(2, 3))
	_plan.begin_build(Facility.Kind.INTEL_ROOM)
	assert_eq(_plan.footprint(), HideoutBuilding.footprint_for(Facility.Kind.INTEL_ROOM))


func test_unknown_kind_falls_back_to_one_cell() -> void:
	assert_eq(HideoutBuilding.footprint_for(HideoutBuilding.NOT_A_FACILITY), Vector2i.ONE)


# ------------------------------------------------------------------ 짓기


func test_nothing_is_active_at_the_start() -> void:
	assert_false(_plan.is_active())
	assert_eq(_plan.commit(), "", "겨누지도 않았는데 놓이면 안 된다")


## 새로 짓는 것은 발자국 가운데를 잡은 셈 친다 — 커서 밑에서 건물이 튀지 않게.
func test_build_centres_the_footprint_on_the_cursor() -> void:
	_plan.begin_build(Facility.Kind.WORKSHOP)
	_plan.aim_at(Vector2i(5, 5))
	assert_eq(_plan.origin(), Vector2i(4, 4), "2x2 는 커서가 가운데다")


func test_commit_puts_a_real_building_on_the_grid() -> void:
	_plan.begin_build(Facility.Kind.WORKSHOP)
	_plan.aim_at(Vector2i(5, 5))
	var placed_id := _plan.commit()
	assert_ne(placed_id, "")
	assert_true(_grid.has_building(placed_id))
	assert_eq(_grid.building(placed_id).label(), Facility.label(Facility.Kind.WORKSHOP))
	assert_false(_plan.is_active(), "확정하면 놓는 중이 끝난다")


func test_two_builds_get_different_names() -> void:
	_plan.begin_build(Facility.Kind.WORKSHOP)
	_plan.aim_at(Vector2i(2, 2))
	var first := _plan.commit()
	_plan.begin_build(Facility.Kind.WORKSHOP)
	_plan.aim_at(Vector2i(8, 8))
	var second := _plan.commit()
	assert_ne(first, second, "같은 이름이면 나중 것이 앞의 것을 덮는다")
	assert_eq(_grid.buildings().size(), 2)


func test_commit_on_a_blocked_cell_changes_nothing() -> void:
	_put("shop", Facility.Kind.WORKSHOP, Vector2i(4, 4))
	var before := _grid.free_cell_count()
	_plan.begin_build(Facility.Kind.CONTACT_POINT)
	_plan.aim_at(Vector2i(5, 5))
	assert_false(_plan.can_commit())
	assert_eq(_plan.commit(), "")
	assert_eq(_grid.free_cell_count(), before)
	assert_eq(_grid.buildings().size(), 1)


func test_commit_off_the_board_changes_nothing() -> void:
	_plan.begin_build(Facility.Kind.WORKSHOP)
	_plan.aim_at(Vector2i(20, 20))
	assert_eq(_plan.reason(), "판 밖이다")
	assert_eq(_plan.commit(), "")
	assert_eq(_grid.buildings().size(), 0)


## 이유 문장은 코어가 만든다 — 화면이 지어내면 규칙과 설명이 따로 논다.
func test_reason_names_the_blocker() -> void:
	_put("shop", Facility.Kind.WORKSHOP, Vector2i(4, 4))
	_plan.begin_build(Facility.Kind.INTEL_ROOM)
	_plan.aim_at(Vector2i(5, 5))
	assert_string_contains(_plan.reason(), Facility.label(Facility.Kind.WORKSHOP))


# ------------------------------------------------------------------ 옮기기


func test_grabbing_empty_ground_does_nothing() -> void:
	assert_false(_plan.begin_move(Vector2i(0, 0)))
	assert_false(_plan.is_active())


## 잡은 자리를 기억해야 큰 건물이 커서 밑에서 튀지 않는다.
func test_move_keeps_the_grab_offset() -> void:
	_put("intel", Facility.Kind.INTEL_ROOM, Vector2i(4, 4))
	assert_true(_plan.begin_move(Vector2i(5, 6)))
	assert_eq(_plan.origin(), Vector2i(4, 4), "잡자마자는 제자리다")
	_plan.aim_at(Vector2i(8, 9))
	assert_eq(_plan.origin(), Vector2i(7, 7), "어긋남이 유지된다")


## 한 칸 옮기려는데 제 몸이 걸려 막히면 그것은 규칙이 아니라 버그다.
func test_moving_ignores_its_own_body() -> void:
	_put("intel", Facility.Kind.INTEL_ROOM, Vector2i(4, 4))
	_plan.begin_move(Vector2i(4, 4))
	_plan.aim_at(Vector2i(4, 5))
	assert_eq(_plan.reason(), "", "제 몸은 걸림돌이 아니다")
	assert_ne(_plan.commit(), "")
	assert_eq(_grid.building("intel").origin, Vector2i(4, 5))


func test_moving_onto_another_building_is_refused() -> void:
	_put("shop", Facility.Kind.WORKSHOP, Vector2i(0, 0))
	_put("intel", Facility.Kind.INTEL_ROOM, Vector2i(6, 6))
	_plan.begin_move(Vector2i(6, 6))
	_plan.aim_at(Vector2i(1, 1))
	assert_false(_plan.reason().is_empty())
	assert_eq(_plan.commit(), "")
	assert_eq(_grid.building("intel").origin, Vector2i(6, 6), "실패한 이동은 제자리다")


func test_the_board_is_untouched_until_commit() -> void:
	_put("intel", Facility.Kind.INTEL_ROOM, Vector2i(4, 4))
	_plan.begin_move(Vector2i(4, 4))
	_plan.aim_at(Vector2i(9, 9))
	assert_eq(_grid.occupant_at(Vector2i(4, 4)), "intel", "확정 전에는 아직 원래 자리다")
	assert_eq(_grid.occupant_at(Vector2i(9, 9)), "", "확정 전에는 새 자리가 비어 있다")


func test_cancelling_a_move_leaves_it_where_it_was() -> void:
	_put("intel", Facility.Kind.INTEL_ROOM, Vector2i(4, 4))
	_plan.begin_move(Vector2i(4, 4))
	_plan.aim_at(Vector2i(9, 9))
	_plan.cancel()
	assert_false(_plan.is_active())
	assert_eq(_grid.building("intel").origin, Vector2i(4, 4))
	assert_eq(_grid.buildings().size(), 1)


func test_cancelling_a_build_puts_nothing_down() -> void:
	_plan.begin_build(Facility.Kind.WORKSHOP)
	_plan.aim_at(Vector2i(5, 5))
	_plan.cancel()
	assert_eq(_grid.buildings().size(), 0)
	assert_eq(_plan.commit(), "", "그만둔 뒤에는 확정할 것이 없다")
