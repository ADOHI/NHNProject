extends SceneTree
## **한 칸 문 40 에서 못 넘는 유닛을 찍는다.** 「못 넘었다」만 보던 것을 연다.
##
##     godot --headless --path . -s res://tools/probe_gate1.gd
##
## 라이브락은 §21 에서 고쳤는데도 한 칸 문이 안 넘는다. 그러면 **원인이 다르다.**
## 짐작으로 고치지 않기 위해, 못 넘는 유닛이 무엇을 하고 있는지부터 본다.
##
## | 물음 | 갈리는 것 |
## | --- | --- |
## | 어디에 있나 | 문 앞에 몰려 있나, 뒤에 흩어져 있나 |
## | 무엇을 하고 있나 | 왕복인가, 서로 지목인가, 아예 안 움직이나 |
## | 물러나기가 도나 | 돌았는데 안 먹히나, 아예 안 도나(`건너뜀`) |

const _STEP := 1.0 / 60.0
const _SECONDS := 40.0
const _COLS := 60
const _ROWS := 34
const _CELL := 32.0

## 마지막에 이 시간 동안 움직인 거리를 재서 "무엇을 하고 있는지"를 가른다.
const _WATCH := 2.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var count := 40
	var gate_cells := 1
	if args.size() > 0:
		count = int(args[0])
	if args.size() > 1:
		gate_cells = int(args[1])
	_run(count, gate_cells)
	quit()


func _field(count: int, gate_cells: int) -> ProtoUnitField:
	var grid := ProtoNavGrid.new(_COLS, _ROWS, _CELL)
	for column in _COLS:
		grid.set_blocked(Vector2i(column, 0), true)
		grid.set_blocked(Vector2i(column, _ROWS - 1), true)
	for row in _ROWS:
		grid.set_blocked(Vector2i(0, row), true)
		grid.set_blocked(Vector2i(_COLS - 1, row), true)
	var gate := _ROWS / 2 - gate_cells / 2
	for row in range(1, _ROWS - 1):
		var inside := row >= gate and row < gate + gate_cells
		grid.set_blocked(Vector2i(30, row), not inside)
	var field := ProtoUnitField.new(grid, ProtoMoveTuning.new())
	for index in count:
		var at := Vector2(120.0 + (index % 6) * 34.0, 380.0 + (index / 6) * 34.0)
		field.spawn(index % ProtoUnitAgent.KIND_NAMES.size(), grid.push_out(at, 14.0))
	return field


func _run(count: int, gate_cells: int) -> void:
	var field := _field(count, gate_cells)
	var cross_x := 30.0 * _CELL
	field.issue_move(field.all_ids(), Vector2(1500, 545))

	var elapsed := 0.0
	# 초마다 넘은 인원을 적는다. **언제 멈췄는지**가 보이면 원인이 절반 갈린다.
	var per_second := PackedInt32Array()
	var next_mark := 1.0
	while elapsed < _SECONDS - _WATCH:
		field.step(_STEP)
		elapsed += _STEP
		if elapsed >= next_mark:
			next_mark += 1.0
			per_second.append(_crossed(field, cross_x))
		if field.moving_count() == 0:
			break

	var start := PackedVector2Array()
	var previous := PackedVector2Array()
	for agent in field.agents:
		start.append(agent.position)
		previous.append(agent.position)
	var travelled := PackedFloat32Array()
	travelled.resize(field.agents.size())
	for _i in int(_WATCH / _STEP):
		field.step(_STEP)
		for index in field.agents.size():
			travelled[index] += previous[index].distance_to(field.agents[index].position)
			previous[index] = field.agents[index].position

	print("인원 %d, 문 폭 %d 칸" % [count, gate_cells])
	print("")
	print("초마다 넘은 인원: %s" % str(per_second))
	print("")
	print(
		(
			"전파 %d 회, 옮김 %d, 못비킴 %d, 물러남 %d, 물러나기 건너뜀 %d, 이어밀기 %d, 굽기 %d"
			% [
				field.propagate_runs,
				field.propagate_moves,
				field.propagate_blocked,
				field.propagate_recoils,
				field.propagate_recoil_skips,
				field.propagate_relays,
				field.rebake_count,
			]
		)
	)
	print("")
	# **막힘 기억이 몇 칸을 물고 있나.** 「안 가보고 안다」가 실제로 몇 칸인지 이 값이 답한다.
	# 너무 많으면 길 자체가 통째로 비싸져 흐름장이 헤맨다.
	for order in field.orders:
		var marked := 0
		for value in order.jam:
			if value > 0:
				marked += 1
		print("막힘으로 적힌 칸 %d / %d" % [marked, field.grid.cols * field.grid.rows])
	print("")
	print(
		"| 번호 | 상태 | x | y | 문까지 | 막은놈 | 서로지목 | 2초이동 | 2초변위 | 우회 | " + "비켜 | 길대기 | 굳음 | 비빔 | 재시도 |"
	)
	print(
		"| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"
	)
	for index in field.agents.size():
		var agent := field.agents[index]
		if agent.position.x >= cross_x:
			continue
		var blocker := field.agent_of(agent.blocker_id)
		var mutual := blocker != null and blocker.blocker_id == agent.id
		print(
			(
				"| %d | %s | %.0f | %.0f | %.0f | %d | %s | %.0f px | %.0f px | %.0f도 | %s | %s | %d |"
				% [
					agent.id,
					agent.state_name(),
					agent.position.x,
					agent.position.y,
					cross_x - agent.position.x,
					agent.blocker_id,
					"O" if mutual else "-",
					travelled[index],
					start[index].distance_to(agent.position),
					rad_to_deg(agent.detour),
					"O" if agent.is_yielding() else "-",
					"줄%d" % agent.gate_id if agent.gate_id != 0 else "-",
					agent.stall_frames,
				]
			)
		)


func _crossed(field: ProtoUnitField, cross_x: float) -> int:
	var crossed := 0
	for agent in field.agents:
		if agent.position.x >= cross_x:
			crossed += 1
	return crossed
