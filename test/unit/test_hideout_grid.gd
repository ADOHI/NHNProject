extends GutTest
## 아지트 격자의 단위 테스트.
##
## 지키는 것 둘이다 — **겹쳐 놓이지 않는다**와 **실패한 배치가 판을 건드리지 않는다**
## (docs/design/30-hideout.md §30.4).

const GridScript := preload("res://src/core/hideout/hideout_grid.gd")
const BuildingScript := preload("res://src/core/hideout/hideout_building.gd")


func _grid(wide: int = 10, tall: int = 10) -> HideoutGrid:
	return GridScript.new(wide, tall)


func _building(
	building_id: String, size: Vector2i, at: Vector2i, kind: int = HideoutBuilding.NOT_A_FACILITY
) -> HideoutBuilding:
	return BuildingScript.new(building_id, kind, size, at)


func test_empty_board_is_all_free() -> void:
	var grid := _grid(4, 5)
	assert_eq(grid.free_cell_count(), 20)
	assert_true(grid.is_free(Vector2i(3, 4)))


func test_bounds_are_exclusive_at_the_far_edge() -> void:
	var grid := _grid(4, 5)
	assert_true(grid.in_bounds(Vector2i(3, 4)))
	assert_false(grid.in_bounds(Vector2i(4, 4)))
	assert_false(grid.in_bounds(Vector2i(-1, 0)))


func test_placing_marks_every_cell_of_the_footprint() -> void:
	var grid := _grid()
	assert_true(grid.place(_building("a", Vector2i(2, 3), Vector2i(1, 1))))
	assert_eq(grid.occupant_at(Vector2i(1, 1)), "a")
	assert_eq(grid.occupant_at(Vector2i(2, 3)), "a")
	assert_eq(grid.occupant_at(Vector2i(3, 3)), "", "발자국 밖은 비어 있다")
	assert_eq(grid.free_cell_count(), 94)


func test_overlap_is_refused() -> void:
	var grid := _grid()
	grid.place(_building("a", Vector2i(2, 2), Vector2i(1, 1)))
	assert_false(grid.place(_building("b", Vector2i(2, 2), Vector2i(2, 2))), "겹치면 못 놓는다")


## 절반만 놓인 상태를 만들면 되돌리는 코드가 필요해지고, 되돌리기는 조용히 틀린다.
func test_failed_placement_changes_nothing() -> void:
	var grid := _grid()
	grid.place(_building("a", Vector2i(2, 2), Vector2i(1, 1)))
	var before := grid.free_cell_count()
	grid.place(_building("b", Vector2i(3, 3), Vector2i(0, 0)))
	assert_eq(grid.free_cell_count(), before)
	assert_eq(grid.occupant_at(Vector2i(0, 0)), "", "실패한 건물의 칸이 남아 있으면 안 된다")
	assert_false(grid.has_building("b"))


func test_out_of_bounds_is_refused() -> void:
	var grid := _grid(4, 4)
	assert_false(grid.place(_building("a", Vector2i(2, 2), Vector2i(3, 3))))


## 참/거짓만 돌려주면 화면이 "왜 안 놓이는가" 를 스스로 지어내게 된다 (§22.8.5).
func test_blocked_reason_tells_the_two_causes_apart() -> void:
	var grid := _grid(4, 4)
	grid.place(_building("shop", Vector2i(2, 2), Vector2i(0, 0), Facility.Kind.WORKSHOP))
	assert_eq(grid.blocked_reason(Vector2i(1, 1), Vector2i(4, 0)), "판 밖이다")
	assert_eq(grid.blocked_reason(Vector2i(1, 1), Vector2i(0, 0)), "공방과 겹친다")
	assert_eq(grid.blocked_reason(Vector2i(1, 1), Vector2i(3, 3)), "", "빈 칸은 이유가 없다")


func test_moving_frees_the_old_cells() -> void:
	var grid := _grid()
	grid.place(_building("a", Vector2i(2, 2), Vector2i(1, 1)))
	assert_true(grid.move("a", Vector2i(5, 5)))
	assert_eq(grid.occupant_at(Vector2i(1, 1)), "", "옮긴 자리는 비어야 한다")
	assert_eq(grid.occupant_at(Vector2i(5, 5)), "a")
	assert_eq(grid.free_cell_count(), 96)


func test_move_onto_another_building_leaves_it_where_it_was() -> void:
	var grid := _grid()
	grid.place(_building("a", Vector2i(2, 2), Vector2i(0, 0)))
	grid.place(_building("b", Vector2i(2, 2), Vector2i(5, 5)))
	assert_false(grid.move("b", Vector2i(1, 1)))
	assert_eq(grid.building("b").origin, Vector2i(5, 5), "실패한 이동은 원래 자리를 지킨다")
	assert_eq(grid.occupant_at(Vector2i(5, 5)), "b")


func test_remove_frees_the_cells() -> void:
	var grid := _grid()
	grid.place(_building("a", Vector2i(2, 2), Vector2i(1, 1)))
	assert_true(grid.remove("a"))
	assert_eq(grid.free_cell_count(), 100)
	assert_false(grid.remove("a"), "없는 것을 지우면 실패다")


func test_walkable_is_the_free_cells() -> void:
	var grid := _grid()
	grid.place(_building("a", Vector2i(2, 2), Vector2i(1, 1)))
	assert_false(grid.is_walkable(Vector2i(1, 1)), "건물 위는 못 지나간다")
	assert_true(grid.is_walkable(Vector2i(0, 0)))
	assert_false(grid.is_walkable(Vector2i(-1, 0)), "판 밖도 못 지나간다")


## 화면이 정렬을 맡으면 그 규칙을 테스트가 못 지킨다.
func test_buildings_come_out_back_to_front() -> void:
	var grid := _grid()
	grid.place(_building("front", Vector2i(1, 1), Vector2i(7, 7)))
	grid.place(_building("back", Vector2i(1, 1), Vector2i(1, 1)))
	var order := grid.buildings_by_depth()
	assert_eq(order[0].id, "back")
	assert_eq(order[1].id, "front")


func test_facility_building_borrows_its_name_from_facility() -> void:
	var shop := _building("a", Vector2i(2, 2), Vector2i.ZERO, Facility.Kind.WORKSHOP)
	assert_true(shop.is_facility())
	assert_eq(shop.label(), Facility.label(Facility.Kind.WORKSHOP))
	assert_eq(shop.note(), Facility.note(Facility.Kind.WORKSHOP))


func test_plain_building_is_not_a_facility() -> void:
	var plain := _building("a", Vector2i.ONE, Vector2i.ZERO)
	assert_false(plain.is_facility())
	assert_eq(plain.note(), "", "없는 설명을 지어내지 않는다")


func test_covers_and_cells_agree() -> void:
	var shop := _building("a", Vector2i(2, 3), Vector2i(4, 4))
	assert_eq(shop.cells().size(), 6)
	for cell in shop.cells():
		assert_true(shop.covers(cell))
	assert_false(shop.covers(Vector2i(6, 4)))


## 발자국 안에 세우면 건물에 가려 안 보인다 (②가 이 자리를 쓴다).
func test_entrance_sits_in_front_of_the_footprint() -> void:
	var shop := _building("a", Vector2i(2, 2), Vector2i(4, 4))
	assert_eq(shop.entrance_cell(), Vector2i(5, 6))
	assert_false(shop.covers(shop.entrance_cell()))
