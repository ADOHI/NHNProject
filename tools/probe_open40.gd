extends SceneTree
## **안 멎는 판에서 실제로 무슨 일이 벌어지는가.** 「멎었나 못 멎었나」만 보던 것을 연다.
##
##     godot --headless --path . -s res://tools/probe_open40.gd
##
## 세 가지를 한 번에 답한다.
##
## | 물음 | 갈리는 것 |
## | --- | --- |
## | 몇 명이 안 멎나 | 전원이면 정지 판정 임계값, 두셋이면 국소 라이브락 |
## | 무엇을 하고 있나 | 제자리 진동 · 작게 돌기 · 자리 맞바꾸기 |
## | 재현되나 | 늘 같으면 구조, 들쭉날쭉하면 **순서 의존 경합** |
##
## 셋째가 특히 중요하다. 난수를 안 쓰므로 **결정론이어야 정상**이고, 아니면 그 자체가 발견이다.

const _STEP := 1.0 / 60.0
const _SECONDS := 40.0
const _COLS := 60
const _ROWS := 34
const _CELL := 32.0

## 마지막에 이 시간 동안 움직인 거리를 재서 "무엇을 하고 있는지"를 가른다.
const _WATCH := 2.0


func _initialize() -> void:
	print("| 회차 | 인원 | 안 멎은 수 | 총 이동 | 순 변위 | 이동/변위 | 상태 |")
	print("| --- | --- | --- | --- | --- | --- | --- |")
	for round_index in 5:
		_run(40, round_index + 1)
	quit()


func _run(count: int, round_index: int) -> void:
	var grid := ProtoNavGrid.new(_COLS, _ROWS, _CELL)
	for column in _COLS:
		grid.set_blocked(Vector2i(column, 0), true)
		grid.set_blocked(Vector2i(column, _ROWS - 1), true)
	for row in _ROWS:
		grid.set_blocked(Vector2i(0, row), true)
		grid.set_blocked(Vector2i(_COLS - 1, row), true)
	var field := ProtoUnitField.new(grid, ProtoMoveTuning.new())
	for index in count:
		var at := Vector2(120.0 + (index % 6) * 34.0, 380.0 + (index / 6) * 34.0)
		field.spawn(index % ProtoUnitAgent.KIND_NAMES.size(), grid.push_out(at, 14.0))
	field.issue_move(field.all_ids(), Vector2(1500, 545))

	var elapsed := 0.0
	while elapsed < _SECONDS - _WATCH:
		field.step(_STEP)
		elapsed += _STEP
		if field.moving_count() == 0:
			break

	# 마지막 구간에서 **총 이동 거리**와 **순 변위**를 따로 잰다.
	# 총 이동이 큰데 순 변위가 작으면 제자리에서 왕복하는 것이고, 둘 다 크면 돌고 있는 것이다.
	var start := PackedVector2Array()
	var previous := PackedVector2Array()
	for agent in field.agents:
		start.append(agent.position)
		previous.append(agent.position)
	var travelled := 0.0
	for _i in int(_WATCH / _STEP):
		field.step(_STEP)
		for index in field.agents.size():
			travelled += previous[index].distance_to(field.agents[index].position)
			previous[index] = field.agents[index].position
	var drift := 0.0
	for index in field.agents.size():
		drift += start[index].distance_to(field.agents[index].position)

	# **왕복하는 둘을 찍는다.** 서로를 지목하면 길이 2 고리이고, 각자 다른 것에 막혀 있으면
	# 조향에 이력이 없는 것이다. 결정론이라 한 번만 찍으면 된다.
	if round_index == 1:
		var moving: Array[ProtoUnitAgent] = []
		for agent in field.agents:
			if agent.is_moving():
				moving.append(agent)
		for _i in 12:
			var row := "    "
			for agent in moving:
				row += (
					"[%d 막은놈%d 조향%.0f도 우회%.0f도 속력%.0f 비켜%s] "
					% [
						agent.id,
						agent.blocker_id,
						rad_to_deg(agent.steer_dir.angle()),
						rad_to_deg(agent.detour),
						agent.speed,
						"O" if agent.is_yielding() else "-",
					]
				)
			print(row)
			field.step(_STEP)

	var busy := field.moving_count()
	var waiting := 0
	var yielding := 0
	for agent in field.agents:
		if agent.state == ProtoUnitAgent.State.HOLDING:
			waiting += 1
		if agent.is_yielding():
			yielding += 1
	print(
		(
			"| %d | %d | %d | %.1f px | %.1f px | %.1f | 기다림 %d 비켜서는중 %d |"
			% [
				round_index,
				count,
				busy,
				travelled,
				drift,
				travelled / maxf(drift, 0.1),
				waiting,
				yielding
			]
		)
	)
