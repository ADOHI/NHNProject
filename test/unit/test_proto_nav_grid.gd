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


func test_flow_direction_does_not_jump_between_cells() -> void:
	# **지터의 진짜 원인이 여기 있었다.** 칸마다 방향은 8 방향 중 하나로 고정되어 있어,
	# 칸 하나만 읽으면 유닛이 칸 경계를 넘는 순간 조향 방향이 45 도씩 통째로 뛴다.
	# 회전 속도 제한은 그 뜀을 없애 주지 않는다 — 튀는 목표를 쫓게 만들어 좌우 왕복으로 바꾼다.
	# 둘레 네 칸을 섞어 읽으면 격자가 연속적인 장이 되어 그 뜀이 사라진다.
	# 벽이 없는 판에서 잰다. 벽에 몸이 걸릴 때의 보정은 따로 있고, 여기서 보려는 것은
	# **격자를 읽는 것만으로 생기는 뜀**이다.
	var grid := _open_grid()
	var field := grid.build_flow_field(grid.cell_to_world(Vector2i(17, 6)))
	var probe := grid.cell_to_world(Vector2i(3, 3))
	var previous := field.direction_at(probe, 8.0)
	var worst := 0.0
	for _i in 120:
		probe += Vector2(2.0, 1.0)
		var now := field.direction_at(probe, 8.0)
		if previous != Vector2.ZERO and now != Vector2.ZERO:
			worst = maxf(worst, absf(rad_to_deg(now.angle_to(previous))))
		previous = now
	assert_lt(worst, 20.0, "칸을 넘을 때 조향 방향이 %.0f 도 뛰었다" % worst)


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


## **막힘 표를 읽는 쪽과 쓰는 쪽이 같은 뜻으로 읽는가.**
##
## `unit_jam.gd` 는 막힌 칸에 `_JAM_FORGET`(3)을 적고 비면 하나씩 깎는데, 읽는 쪽이
## `== 1` 로 물어서 **지금 막힌 칸은 값을 안 물고 비운 지 오래된 칸만 값을 물었다.**
## 기억이 정확히 뒤집혀 있었고 지표로는 안 잡혔다 - 뒤집힌 기억도 값은 내기 때문이다.
## README §25. 여기서 못 박는다.
func test_jam_cost_applies_while_the_cell_is_still_marked() -> void:
	var grid := _open_grid()
	var goal := grid.cell_to_world(Vector2i(18, 6))
	var plain := grid.build_flow_field(goal)
	var jam := PackedByteArray()
	jam.resize(grid.cols * grid.rows)
	# 목적지로 가는 길 한복판을 세로로 막는다. 쓰는 쪽이 적는 값 그대로 3 이다.
	for row in grid.rows:
		jam[grid.cell_index(Vector2i(10, row))] = 3
	var jammed := grid.build_flow_field(goal, jam, 3.0)
	assert_gt(
		jammed.cost_at(Vector2i(2, 6)),
		plain.cost_at(Vector2i(2, 6)),
		"지금 막힌 칸(3)이 값을 물어야 한다. `== 1` 로 물으면 이 줄이 무너진다"
	)


## 잊어 가는 중인 칸도 0 이 되기 전까지는 막힘이다. 확인 횟수는 **얼마나 오래 믿을지**이지
## 어느 한 값에서만 막힘이라는 뜻이 아니다.
func test_jam_cost_applies_for_every_countdown_value() -> void:
	var plain := _lane_cost(0)
	for remaining in [1, 2, 3]:
		assert_gt(_lane_cost(remaining), plain, "남은 확인 횟수 %d 에서도 막힘이어야 한다" % remaining)


## 0 이면 기억이 없는 것과 같다.
func test_jam_cost_of_zero_changes_nothing() -> void:
	assert_almost_eq(_lane_cost(3, 0.0), _lane_cost(0), 0.0001)


## 길 한복판을 세로로 막아 두고 반대편 끝 칸의 비용을 잰다. `remaining` 이 막힘 표에 적히는
## 값이고, 0 이면 안 막힌 것이다.
func _lane_cost(remaining: int, cost: float = 3.0) -> float:
	var grid := _open_grid()
	var goal := grid.cell_to_world(Vector2i(18, 6))
	var jam := PackedByteArray()
	jam.resize(grid.cols * grid.rows)
	if remaining > 0:
		for row in grid.rows:
			jam[grid.cell_index(Vector2i(10, row))] = remaining
	return grid.build_flow_field(goal, jam, cost).cost_at(Vector2i(2, 6))
