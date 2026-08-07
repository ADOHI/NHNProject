extends GutTest
## 이동 시뮬레이션의 단위 테스트.
##
## **조작감이 갈리는 네 지점을 여기서 지킨다.** 자동 테스트가 손맛을 알려 주지는 못하지만,
## 한번 잡아 둔 손맛이 조용히 무너지는 것은 막을 수 있다. 지키는 것은 넷이다.
##
## | 지점 | 여기서 지키는 것 |
## | --- | --- |
## | 반응 지연 | 명령 직후 몇 프레임 안에 실제로 속도가 붙는가 |
## | 뭉침 | 두 유닛이 같은 목표를 받지 않는가, 멎은 뒤 몸이 겹치지 않는가 |
## | 도착 | 전원이 유한 시간에 멎는가, 멎은 뒤 다시 움직이지 않는가 |
## | 대형 | 같이 갈 때 무리가 흩어지지 않는가 |

const _STEP := 1.0 / 60.0


## 테두리가 막힌 빈 방과 그 안에 늘어선 유닛들.
func _make_field(count: int) -> ProtoUnitField:
	var grid := ProtoNavGrid.new(40, 24, 32.0)
	for column in grid.cols:
		grid.set_blocked(Vector2i(column, 0), true)
		grid.set_blocked(Vector2i(column, grid.rows - 1), true)
	for row in grid.rows:
		grid.set_blocked(Vector2i(0, row), true)
		grid.set_blocked(Vector2i(grid.cols - 1, row), true)
	var field := ProtoUnitField.new(grid, ProtoMoveTuning.new())
	for index in count:
		var at := Vector2(120.0 + (index % 5) * 34.0, 200.0 + (index / 5) * 34.0)
		field.spawn(index % 3, at)
	return field


func _run(field: ProtoUnitField, seconds: float) -> void:
	for _i in int(seconds / _STEP):
		field.step(_STEP)


func _spread(field: ProtoUnitField) -> float:
	var center := Vector2.ZERO
	for agent in field.agents:
		center += agent.position
	center /= float(field.agents.size())
	var widest := 0.0
	for agent in field.agents:
		widest = maxf(widest, agent.position.distance_to(center))
	return widest


# ----------------------------------------------------------------- 반응 지연


func test_units_pick_up_speed_within_three_frames() -> void:
	# 명령을 냈는데 한참 뒤에 움직이면 씹힌 것으로 느껴진다. 기본값에서 이 정도는 나와야 한다.
	var field := _make_field(6)
	field.issue_move(field.all_ids(), Vector2(900, 400))
	_run(field, _STEP * 3.0)
	for agent in field.agents:
		assert_gt(agent.velocity.length(), 60.0, "%d 번이 세 프레임 안에 움직이지 않았다" % agent.id)


func test_order_reaches_the_agents_the_same_step() -> void:
	var field := _make_field(4)
	field.issue_move(field.all_ids(), Vector2(900, 400))
	assert_eq(field.moving_count(), 4)
	for agent in field.agents:
		assert_eq(agent.state, ProtoUnitAgent.State.MOVING)


# ----------------------------------------------------------------- 뭉침


func test_no_two_units_share_a_goal() -> void:
	# 전원에게 같은 좌표를 주면 그 한 점을 두고 영원히 밀어댄다. 도착이 끝나지 않는다.
	var field := _make_field(16)
	field.issue_move(field.all_ids(), Vector2(800, 400))
	var seen := {}
	for agent in field.agents:
		var key := "%.1f,%.1f" % [agent.goal.x, agent.goal.y]
		assert_false(seen.has(key), "두 유닛이 같은 자리를 받았다")
		seen[key] = true


func test_settled_units_do_not_overlap() -> void:
	var field := _make_field(16)
	field.issue_move(field.all_ids(), Vector2(800, 400))
	_run(field, 20.0)
	for i in field.agents.size():
		for j in range(i + 1, field.agents.size()):
			var a: ProtoUnitAgent = field.agents[i]
			var b: ProtoUnitAgent = field.agents[j]
			var gap := a.position.distance_to(b.position)
			assert_gt(gap, a.radius + b.radius - 3.0, "%d 과 %d 의 몸이 겹쳤다" % [a.id, b.id])


func test_units_stay_out_of_walls() -> void:
	var field := _make_field(12)
	field.issue_move(field.all_ids(), Vector2(60, 60))
	_run(field, 20.0)
	for agent in field.agents:
		assert_true(
			field.grid.is_circle_free(agent.position, agent.radius - 0.5),
			"%d 번이 벽 안에 있다" % agent.id
		)


# ----------------------------------------------------------------- 도착


func test_everyone_settles() -> void:
	var field := _make_field(16)
	field.issue_move(field.all_ids(), Vector2(800, 400))
	_run(field, 20.0)
	assert_eq(field.moving_count(), 0, "20 초가 지나도 멎지 않은 유닛이 있다")


func test_settled_units_stop_dead() -> void:
	# 목적지에서 미세하게 떠는 것이 도착 처리의 가장 흔한 실패다.
	var field := _make_field(16)
	field.issue_move(field.all_ids(), Vector2(800, 400))
	_run(field, 20.0)
	var before: PackedVector2Array = PackedVector2Array()
	for agent in field.agents:
		before.append(agent.position)
	_run(field, 3.0)
	for index in field.agents.size():
		var moved: float = before[index].distance_to(field.agents[index].position)
		assert_lt(moved, 1.0, "멎은 뒤에도 %.2f 픽셀 떨었다" % moved)


func test_cramped_corner_still_settles() -> void:
	# 자리가 모자란 구석으로 몰아넣어도 끝나야 한다. 못 들어가는 자리를 두고
	# 영원히 밀어대는 것이 도착 처리의 최악이다.
	var field := _make_field(20)
	field.issue_move(field.all_ids(), Vector2(50, 50))
	_run(field, 25.0)
	assert_eq(field.moving_count(), 0, "구석에서 멎지 못한 유닛이 있다")


func test_order_onto_a_wall_still_moves_units() -> void:
	# 명령이 조용히 무시되는 것이 조작감을 가장 크게 해친다. 벽을 찍어도 움직여야 한다.
	var field := _make_field(4)
	var order := field.issue_move(field.all_ids(), Vector2(4, 4))
	assert_not_null(order)
	assert_true(field.grid.is_point_walkable(order.target))
	_run(field, 0.5)
	assert_gt(field.agents[0].position.distance_to(Vector2(120, 200)), 20.0)


func test_stop_halts_immediately() -> void:
	var field := _make_field(6)
	field.issue_move(field.all_ids(), Vector2(900, 400))
	_run(field, 1.0)
	field.stop(field.all_ids())
	assert_eq(field.moving_count(), 0)
	for agent in field.agents:
		assert_almost_eq(agent.velocity.length(), 0.0, 0.001)


func test_finished_orders_are_dropped() -> void:
	var field := _make_field(6)
	field.issue_move(field.all_ids(), Vector2(700, 400))
	_run(field, 20.0)
	assert_eq(field.orders.size(), 0, "끝난 명령이 계속 쌓이면 개발 표시가 못 쓰게 된다")


# ----------------------------------------------------------------- 대형


func test_group_does_not_scatter_on_the_way() -> void:
	# 속도가 다른 유닛이 섞여 있다. 대형 유지가 없으면 빠른 쪽만 먼저 가서 무리가 늘어진다.
	var field := _make_field(15)
	var before := _spread(field)
	field.issue_move(field.all_ids(), Vector2(1000, 400))
	_run(field, 2.5)
	assert_lt(_spread(field), before * 2.0, "가는 도중 무리가 흩어졌다")


func test_group_sync_off_scatters_more() -> void:
	# 대형 유지 값이 실제로 일하고 있는지 확인한다. 슬라이더가 장식이면 안 된다.
	var loose := _make_field(15)
	loose.tuning.set_value("group_sync", 0.0)
	loose.issue_move(loose.all_ids(), Vector2(1000, 400))
	_run(loose, 2.5)
	var tight := _make_field(15)
	tight.tuning.set_value("group_sync", 1.0)
	tight.issue_move(tight.all_ids(), Vector2(1000, 400))
	_run(tight, 2.5)
	assert_lt(_spread(tight), _spread(loose))


# ----------------------------------------------------------------- 선택 질의


func test_rect_picks_units_inside() -> void:
	var field := _make_field(10)
	var picked := field.ids_in_rect(Rect2(100, 180, 80, 80))
	assert_gt(picked.size(), 0)
	for id in picked:
		var agent := field.agent_of(id)
		assert_lt(agent.position.x, 200.0)


func test_point_picks_the_unit_under_it() -> void:
	var field := _make_field(4)
	var target: ProtoUnitAgent = field.agents[2]
	assert_eq(field.agent_at_point(target.position).id, target.id)
	assert_null(field.agent_at_point(Vector2(900, 700)))


func test_kind_query_returns_only_that_kind() -> void:
	var field := _make_field(9)
	var scouts := field.ids_of_kind(2)
	assert_eq(scouts.size(), 3)
	for id in scouts:
		assert_eq(field.agent_of(id).kind, 2)


func test_despawn_removes_from_the_back() -> void:
	var field := _make_field(6)
	field.despawn(2)
	assert_eq(field.agents.size(), 4)
	assert_null(field.agent_of(6))
