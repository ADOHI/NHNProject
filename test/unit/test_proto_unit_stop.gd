extends GutTest
## **유닛이 언제 멈추는가**의 단위 테스트. 포기 시간을 걷어낸 자리다.
##
## 예전에는 "이만큼 못 나아가면 포기"였다. 그런데 포기한 유닛에게 다시 명령하면 가는 일이
## 있었다 — 실제로는 막히지 않았는데 알고리즘이 막혔다고 잘못 결론 낸 것이고, 포기 시간은
## 그 오판을 시간으로 덮는 장치였다. 늘리면 굼떠지고 줄이면 일찍 포기하니 어느 쪽도 답이 아니다.
##
## 시간 대신 상태로 묻게 바꾸었으므로, 지켜야 할 성질은 넷이다.
##
## | 성질 | 지키는 테스트 |
## | --- | --- |
## | 영원히 비비지 않는다 | `test_nobody_grinds_forever_in_a_crowd` |
## | 정말 갈 수 없으면 멎는다 | `test_sealed_goal_stops_everyone` |
## | 상황이 바뀌면 스스로 재개한다 | `test_waiting_unit_resumes_when_the_blocker_leaves` |
## | 기다림이 포기로 바뀌지 않는다 | `test_waiting_never_becomes_giving_up` |

const _STEP := 1.0 / 60.0


func _run(field: ProtoUnitField, seconds: float) -> void:
	for _i in int(seconds / _STEP):
		field.step(_STEP)


## 한 칸 폭 복도와 그 너머의 방. 복도에서는 옆으로 비켜 지나갈 수 없다.
func _make_corridor_field() -> ProtoUnitField:
	var grid := ProtoNavGrid.new(40, 24, 32.0)
	for row in grid.rows:
		for column in grid.cols:
			grid.set_blocked(Vector2i(column, row), true)
	for column in range(15, 26):
		grid.set_blocked(Vector2i(column, 12), false)
	for column in range(26, 34):
		for row in range(8, 17):
			grid.set_blocked(Vector2i(column, row), false)
	return ProtoUnitField.new(grid, ProtoMoveTuning.new())


## 비키지 않는 아군 앞에서 굴린다. **밀치기를 걷어낸 뒤로는 못을 박을 필요가 없다.**
##
## 예전에는 걸음마다 제자리로 되돌려야 했다. 서 있는 쪽이 더 많이 밀리도록 되어 있어서
## 지나가는 유닛이 그대로 밀고 나갔기 때문이다. 지금은 서 있는 유닛이 벽과 같으므로
## 되돌리는 대신 **정말 그 자리에 있었는지 확인한다.** 되돌리기가 판정을 가려 주고 있었는지
## 아닌지가 이 한 줄에서 갈린다.
func _run_pinned(field: ProtoUnitField, blocker: ProtoUnitAgent, seconds: float) -> void:
	var anchor := blocker.position
	for _i in int(seconds / _STEP):
		field.step(_STEP)
	assert_lt(blocker.position.distance_to(anchor), 0.5, "막고 선 아군이 밀려났다")


## 복도를 막은 아군과 그 뒤에 선 유닛을 만든다.
func _make_blocked_walker(field: ProtoUnitField) -> Array[ProtoUnitAgent]:
	var grid := field.grid
	var blocker := field.spawn(0, grid.cell_to_world(Vector2i(22, 12)))
	var walker := field.spawn(0, grid.cell_to_world(Vector2i(17, 12)))
	field.issue_move(PackedInt32Array([walker.id]), grid.cell_to_world(Vector2i(32, 12)))
	return [blocker, walker]


func test_giving_up_by_time_is_gone() -> void:
	# 슬라이더가 되살아나면 판정이 시간으로 돌아갔다는 뜻이다.
	for definition in ProtoMoveTuning.DEFS:
		assert_ne(String(definition["key"]), "stuck_timeout", "포기 시간이 되살아났다")


func test_waiting_unit_resumes_when_the_blocker_leaves() -> void:
	# **이번 요구의 핵심이다.** 막은 쪽이 비키면 재명령 없이 스스로 간다.
	var field := _make_corridor_field()
	var pair := _make_blocked_walker(field)
	var blocker := pair[0]
	var walker := pair[1]
	_run_pinned(field, blocker, 6.0)
	assert_eq(walker.state, ProtoUnitAgent.State.HOLDING, "복도를 막은 아군 앞에서 기다리지 않았다")
	assert_ne(walker.order_id, 0, "기다리는 유닛이 명령을 놓아 버리면 다시 갈 수 없다")
	assert_eq(field.moving_count(), 0, "서서 기다리는 유닛이 이동중으로 세이면 도착 판정이 끝나지 않는다")

	# 막고 있던 유닛이 비킨다. **명령을 다시 내리지 않는다.**
	blocker.position = field.grid.cell_to_world(Vector2i(30, 15))
	_run(field, 8.0)
	assert_eq(walker.state, ProtoUnitAgent.State.ARRIVED, "막은 유닛이 비켰는데도 다시 가지 않았다")
	assert_gt(walker.position.x, 1000.0, "복도를 지나지 못했다")


func test_waiting_never_becomes_giving_up() -> void:
	# 오래 기다려도 포기로 떨어지면 안 된다. 그것이 예전의 포기 시간이 하던 일이다.
	var field := _make_corridor_field()
	var pair := _make_blocked_walker(field)
	_run_pinned(field, pair[0], 25.0)
	assert_eq(pair[1].state, ProtoUnitAgent.State.HOLDING, "기다리던 유닛이 결국 포기해 버렸다")


func test_sealed_goal_stops_everyone() -> void:
	# 정말 갈 수 없는 곳이다. 흐름장이 내가 선 칸까지 못 닿았다는 것으로 **즉시** 안다 —
	# 시간을 들여 확인할 일이 아니다.
	var grid := ProtoNavGrid.new(40, 24, 32.0)
	for column in grid.cols:
		grid.set_blocked(Vector2i(column, 0), true)
		grid.set_blocked(Vector2i(column, grid.rows - 1), true)
	for row in grid.rows:
		grid.set_blocked(Vector2i(0, row), true)
		grid.set_blocked(Vector2i(grid.cols - 1, row), true)
	# 완전히 둘러싸인 한 칸. 통행은 가능하지만 어디서도 닿을 수 없다.
	for offset_y in range(-1, 2):
		for offset_x in range(-1, 2):
			if offset_x != 0 or offset_y != 0:
				grid.set_blocked(Vector2i(30 + offset_x, 12 + offset_y), true)
	var field := ProtoUnitField.new(grid, ProtoMoveTuning.new())
	for index in 6:
		field.spawn(index % 3, Vector2(120.0 + (index % 3) * 34.0, 200.0 + (index / 3) * 34.0))
	field.issue_move(field.all_ids(), grid.cell_to_world(Vector2i(30, 12)))
	_run(field, 1.0)
	assert_eq(field.moving_count(), 0, "닿을 수 없는 자리를 두고 계속 움직였다")
	for agent in field.agents:
		assert_eq(agent.state, ProtoUnitAgent.State.BLOCKED, "%d 번이 막힘으로 멎지 않았다" % agent.id)


func test_nobody_grinds_forever_in_a_crowd() -> void:
	# 포기 시간이 막고 있던 것이 이것이다. 걷어내되 무한 루프를 만들면 안 된다.
	var grid := ProtoNavGrid.new(40, 24, 32.0)
	for column in grid.cols:
		grid.set_blocked(Vector2i(column, 0), true)
		grid.set_blocked(Vector2i(column, grid.rows - 1), true)
	for row in grid.rows:
		grid.set_blocked(Vector2i(0, row), true)
		grid.set_blocked(Vector2i(grid.cols - 1, row), true)
	var field := ProtoUnitField.new(grid, ProtoMoveTuning.new())
	for index in 40:
		field.spawn(index % 3, Vector2(120.0 + (index % 5) * 34.0, 200.0 + (index / 5) * 34.0))
	field.issue_move(field.all_ids(), Vector2(800, 400))
	_run(field, 30.0)
	assert_eq(field.moving_count(), 0, "30 초가 지나도 비비고 있는 유닛이 있다")
