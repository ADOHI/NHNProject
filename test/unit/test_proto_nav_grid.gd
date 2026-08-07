extends GutTest
## 통행 격자와 흐름장의 단위 테스트.
##
## 흐름장이 틀리면 유닛은 벽에 붙어 비비거나 엉뚱한 방향으로 돈다. 화면으로는
## "왜 저러지" 밖에 알 수 없어서, 방향이 실제로 목적지로 이어지는지를 여기서 확인한다.


func _open_grid() -> ProtoNavGrid:
	return ProtoNavGrid.new(20, 12, 32.0)


## 가운데에 문 하나 뚫린 세로 벽을 세운다. 좁은 통로가 흐름장의 시험대다.
func _grid_with_gate() -> ProtoNavGrid:
	var grid := _open_grid()
	for row in grid.rows:
		grid.set_blocked(Vector2i(10, row), row != 6)
	return grid


func test_cell_and_world_round_trip() -> void:
	var grid := _open_grid()
	var center := grid.cell_to_world(Vector2i(3, 4))
	assert_eq(grid.world_to_cell(center), Vector2i(3, 4))


func test_field_size_matches_cells() -> void:
	var grid := _open_grid()
	assert_eq(grid.field_size(), Vector2(640, 384))


func test_outside_cells_are_not_walkable() -> void:
	var grid := _open_grid()
	assert_false(grid.is_walkable(Vector2i(-1, 0)))
	assert_false(grid.is_walkable(Vector2i(20, 0)))


func test_circle_check_sees_neighbouring_cells() -> void:
	# 칸 중심만 보면 몸통이 모서리에 낀다. 반지름만큼의 칸을 함께 봐야 한다.
	var grid := _open_grid()
	grid.set_blocked(Vector2i(5, 5), true)
	var beside := grid.cell_to_world(Vector2i(4, 5))
	assert_true(grid.is_point_walkable(beside))
	assert_false(grid.is_circle_free(beside, 20.0), "옆 칸의 벽에 몸이 닿는다")


func test_nearest_walkable_returns_a_free_spot() -> void:
	var grid := _grid_with_gate()
	var wall_point := grid.cell_to_world(Vector2i(10, 2))
	var moved := grid.nearest_walkable(wall_point)
	assert_true(grid.is_point_walkable(moved), "벽을 찍어도 갈 수 있는 곳으로 돌려야 한다")


func test_walkable_point_is_left_alone() -> void:
	var grid := _open_grid()
	var point := Vector2(101.0, 77.0)
	assert_eq(grid.nearest_walkable(point), point)


func test_push_out_frees_a_stuck_body() -> void:
	var grid := _open_grid()
	grid.set_blocked(Vector2i(5, 5), true)
	var inside := grid.cell_to_world(Vector2i(5, 5))
	var freed := grid.push_out(inside, 10.0)
	assert_true(grid.is_circle_free(freed, 10.0), "벽에 박힌 몸을 빼내지 못했다")


func test_line_of_sight_blocked_by_wall() -> void:
	var grid := _grid_with_gate()
	var left := grid.cell_to_world(Vector2i(2, 2))
	var right := grid.cell_to_world(Vector2i(17, 2))
	assert_false(grid.has_line_of_sight(left, right, 10.0))
	assert_true(grid.has_line_of_sight(left, grid.cell_to_world(Vector2i(8, 2)), 10.0))


func test_flow_field_reaches_the_goal_through_the_gate() -> void:
	# 방향을 따라 걸었을 때 실제로 목적지에 닿아야 한다. 이것이 흐름장의 유일한 계약이다.
	var grid := _grid_with_gate()
	var goal := grid.cell_to_world(Vector2i(17, 2))
	var field := grid.build_flow_field(goal)
	var walker := grid.cell_to_world(Vector2i(2, 9))
	var steps := 0
	while walker.distance_to(goal) > 20.0 and steps < 400:
		walker += field.direction_at(walker, 8.0) * 8.0
		steps += 1
	assert_lt(walker.distance_to(goal), 20.0, "흐름장을 따라가도 목적지에 닿지 못했다")


func test_flow_field_cost_grows_with_distance() -> void:
	var grid := _open_grid()
	var field := grid.build_flow_field(grid.cell_to_world(Vector2i(1, 1)))
	assert_almost_eq(field.cost_at(Vector2i(1, 1)), 0.0, 0.001)
	assert_lt(field.cost_at(Vector2i(3, 1)), field.cost_at(Vector2i(9, 1)))


func test_unreachable_cell_keeps_the_unreachable_cost() -> void:
	var grid := _open_grid()
	for row in grid.rows:
		grid.set_blocked(Vector2i(10, row), true)
	var field := grid.build_flow_field(grid.cell_to_world(Vector2i(2, 2)))
	# 비용은 float32 로 담기므로 정확히 같은 값이 되지 않는다. 크기만 본다.
	assert_gt(field.cost_at(Vector2i(15, 2)), 1.0e17)
	assert_eq(field.dirs[grid.cell_index(Vector2i(15, 2))], Vector2.ZERO)


func test_goal_on_a_wall_moves_to_the_nearest_free_cell() -> void:
	var grid := _grid_with_gate()
	var field := grid.build_flow_field(grid.cell_to_world(Vector2i(10, 2)))
	assert_true(grid.is_walkable(field.goal_cell), "목적지 칸이 벽이면 명령이 통째로 죽는다")
