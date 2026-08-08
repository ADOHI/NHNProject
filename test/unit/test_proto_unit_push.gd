extends GutTest
## **유닛은 다른 유닛을 밀 수 없고 통과할 수 없다.** 이 요구를 못 박는다.
##
## 이 게임은 물리력 게임이 아니다. 예전에는 겹친 몸을 위치로 떼어 놓으면서 서 있는 쪽을 더
## 많이 옮겼고(0.75), 그래서 지나가려는 유닛이 남을 밀쳐 내고 그 자리를 차지했다. 눈에는
## 물리 시뮬레이션처럼 보였고 지터의 큰 몫이기도 했다.
##
## | 성질 | 지키는 테스트 |
## | --- | --- |
## | 서 있는 유닛은 밀려나지 않는다 | `test_a_standing_unit_is_never_shoved` |
## | 몸을 통과하지 못한다 | `test_nobody_walks_through_a_standing_body` |
## | 여럿이 몰려도 몸이 파고들지 않는다 | `test_a_crowd_never_pierces_a_body` |
## | 밀치기는 이동 수단이 아니다 | `test_pushing_is_not_a_way_to_move` |
## | 멎은 뒤 몸이 겹쳐 있지 않다 | `test_bodies_do_not_overlap_once_everyone_stops` |
##
## 지표로도 함께 묻는다. `settled_push_total` 이 0 이 아니면 서 있는 유닛이 밀려난 것이고,
## `max_penetration` 이 몸 지름에 닿으면 중심이 반대편으로 넘어간 것이다.

const _STEP := 1.0 / 60.0

## 몸이 이만큼 넘게 파고들면 통과를 향해 가고 있는 것으로 본다(가장 작은 몸 지름의 비율).
##
## 0 을 요구하지는 않는다. 벽 보정(`push_out`)이 몸을 옮기는 순간과 스폰이 겹쳐 놓은 순간이
## 있어 몇 픽셀은 늘 생긴다. 묻는 것은 **그 겹침이 자라는가**이고, 자라지 않으면 통과는 없다.
const _PIERCE_LIMIT := 0.75


func _run(field: ProtoUnitField, seconds: float) -> void:
	for _i in int(seconds / _STEP):
		field.step(_STEP)


func _bordered_grid(cols: int, rows: int) -> ProtoNavGrid:
	var grid := ProtoNavGrid.new(cols, rows, 32.0)
	for column in cols:
		grid.set_blocked(Vector2i(column, 0), true)
		grid.set_blocked(Vector2i(column, rows - 1), true)
	for row in rows:
		grid.set_blocked(Vector2i(0, row), true)
		grid.set_blocked(Vector2i(cols - 1, row), true)
	return grid


## 한 칸 폭 복도. **옆으로 비켜 지나갈 수 없으므로 밀치기가 있으면 반드시 드러난다.**
func _corridor_field() -> ProtoUnitField:
	var grid := ProtoNavGrid.new(40, 24, 32.0)
	for row in grid.rows:
		for column in grid.cols:
			grid.set_blocked(Vector2i(column, row), true)
	for column in range(15, 30):
		grid.set_blocked(Vector2i(column, 12), false)
	return ProtoUnitField.new(grid, ProtoMoveTuning.new())


## 복도를 막고 선 아군과, 그 너머를 목표로 받은 유닛.
func _blocked_pair(field: ProtoUnitField) -> Array[ProtoUnitAgent]:
	var grid := field.grid
	var blocker := field.spawn(0, grid.cell_to_world(Vector2i(22, 12)))
	var walker := field.spawn(0, grid.cell_to_world(Vector2i(17, 12)))
	field.issue_move(PackedInt32Array([walker.id]), grid.cell_to_world(Vector2i(27, 12)))
	return [blocker, walker]


func _smallest_body(field: ProtoUnitField) -> float:
	var smallest := INF
	for agent in field.agents:
		smallest = minf(smallest, agent.radius)
	return smallest * 2.0


func test_a_standing_unit_is_never_shoved() -> void:
	# 못을 박지 않는다. 정말 그 자리에 있는지가 이 테스트의 전부다.
	var field := _corridor_field()
	var pair := _blocked_pair(field)
	var blocker := pair[0]
	var anchor := blocker.position
	_run(field, 12.0)
	assert_almost_eq(blocker.position.x, anchor.x, 0.001, "서 있는 아군이 밀려났다")
	assert_almost_eq(blocker.position.y, anchor.y, 0.001, "서 있는 아군이 밀려났다")
	assert_eq(field.settled_push_total, 0.0, "서 있는 유닛을 밀어낸 거리가 잡혔다")


func test_nobody_walks_through_a_standing_body() -> void:
	var field := _corridor_field()
	var pair := _blocked_pair(field)
	var blocker := pair[0]
	var walker := pair[1]
	var touching := blocker.radius + walker.radius
	var closest := INF
	for _i in int(12.0 / _STEP):
		field.step(_STEP)
		closest = minf(closest, walker.position.distance_to(blocker.position))
		assert_lt(walker.position.x, blocker.position.x, "막고 선 아군의 반대편으로 넘어갔다")
	assert_gt(closest, touching - _PIERCE_LIMIT * touching, "몸이 통과할 만큼 파고들었다")


func test_pushing_is_not_a_way_to_move() -> void:
	# 막힌 이동은 **사라져야 한다.** 예전에는 그 거리가 남의 몸을 밀어내는 데 쓰였다.
	var field := _corridor_field()
	_blocked_pair(field)
	_run(field, 12.0)
	assert_gt(field.blocked_move_total, 0.0, "막힌 이동이 하나도 없다면 판이 막지 못한 것이다")
	assert_eq(field.settled_push_total, 0.0, "막힌 이동의 일부가 남을 미는 데 쓰였다")


func test_a_crowd_never_pierces_a_body() -> void:
	# 한 점으로 예순 명을 몰아넣는다. 밀치기가 남아 있으면 여기서 몸이 서로를 파고든다.
	var grid := _bordered_grid(40, 24)
	var field := ProtoUnitField.new(grid, ProtoMoveTuning.new())
	for index in 60:
		field.spawn(index % 3, Vector2(120.0 + (index % 6) * 34.0, 200.0 + (index / 6) * 34.0))
	field.issue_move(field.all_ids(), Vector2(800.0, 380.0))
	_run(field, 25.0)
	assert_eq(field.settled_push_total, 0.0, "서 있는 유닛이 밀려났다")
	assert_lt(field.max_penetration, _smallest_body(field) * _PIERCE_LIMIT, "몸이 통과를 향해 갈 만큼 파고들었다")


func test_bodies_do_not_overlap_once_everyone_stops() -> void:
	var grid := _bordered_grid(40, 24)
	var field := ProtoUnitField.new(grid, ProtoMoveTuning.new())
	for index in 30:
		field.spawn(index % 3, Vector2(120.0 + (index % 6) * 34.0, 200.0 + (index / 6) * 34.0))
	field.issue_move(field.all_ids(), Vector2(700.0, 380.0))
	_run(field, 25.0)
	assert_eq(field.moving_count(), 0, "전원이 멎지 않아 겹침을 물을 수 없다")
	for agent in field.agents:
		for other in field.agents:
			if other.id <= agent.id:
				continue
			var gap := agent.position.distance_to(other.position)
			assert_gt(gap, agent.radius + other.radius - 1.0, "멎은 뒤에도 몸이 겹쳐 있다")
