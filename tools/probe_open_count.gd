extends SceneTree
## **인원 하나를 찍어 열어 본다.** 지도(§27)가 이름을 붙인 자리를 하나씩 들여다보는 도구다.
##
##     godot --headless --path . -s res://tools/probe_open_count.gd -- 42 43
##
## 세 가지를 순서대로 답한다. **순서가 중요하다** - 재현되지 않는 것을 고치면 안 된다.
##
## | 물음 | 갈리는 것 |
## | --- | --- |
## | 다섯 번 돌려 같은가 | 같으면 **짜임**, 다르면 확률. 난수를 안 쓰니 같아야 정상이다 |
## | 끝에 안 끝난 유닛이 누구인가 | 상태, 자리까지의 거리, 누가 막았나 |
## | **막은 놈이 어떤 놈인가** | 같은 명령의 도착한 유닛인가, 남의 명령인가, 세워 둔 유닛인가 |
##
## 셋째가 이 도구의 핵심이다. `양보` 예산(§27)은 **"같은 명령을 받은 무리가 전부 자리를
## 잡았고 나를 막은 것이 그중 하나일 때"** 만 걸린다. 안 걸리는 유닛이 남았다면
## **막은 놈이 그 조건 밖**이라는 뜻이고, 어느 쪽으로 벗어났는지를 여기서 본다.

const _STEP := 1.0 / 60.0
const _MAX_SECONDS := 40.0
const _ROUNDS := 5
const _COLS := 60
const _ROWS := 34
const _CELL := 32.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var counts: Array[int] = []
	for value in args:
		counts.append(int(value))
	if counts.is_empty():
		counts = [42, 43]
	for count in counts:
		_look(count)
	quit()


func _open_field(count: int) -> ProtoUnitField:
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
	return field


## 한 판을 끝까지 굴린다. 멎은 시각과 전원끝 시각을 함께 돌려준다.
func _run(field: ProtoUnitField) -> Dictionary:
	field.issue_move(field.all_ids(), Vector2(1500, 545))
	var elapsed := 0.0
	var settled := -1.0
	var done := -1.0
	while elapsed < _MAX_SECONDS:
		field.step(_STEP)
		elapsed += _STEP
		var moving := field.moving_count()
		if settled < 0.0 and moving == 0:
			settled = elapsed
		if done < 0.0 and moving == 0 and _waiting(field) == 0:
			done = elapsed
			break
	return {"settle": settled, "done": done, "waiting": _waiting(field)}


func _waiting(field: ProtoUnitField) -> int:
	var waiting := 0
	for agent in field.agents:
		if agent.state == ProtoUnitAgent.State.HOLDING:
			waiting += 1
	return waiting


func _look(count: int) -> void:
	print("")
	print("# 열린 곳 %d" % count)
	print("")
	# **먼저 재현되는지부터.** 재현 안 되는 것을 고치면 증상만 옮겨 다닌다.
	print("| 회차 | 정지 | 전원끝 | 남은 양보 |")
	print("| --- | --- | --- | --- |")
	for round_index in _ROUNDS:
		var probe := _run(_open_field(count))
		print(
			(
				"| %d | %s | %s | %d |"
				% [
					round_index + 1,
					_seconds(probe["settle"]),
					_seconds(probe["done"]),
					int(probe["waiting"]),
				]
			)
		)

	var field := _open_field(count)
	var last := _run(field)
	print("")
	print("끝난 뒤: 정지 %s, 전원끝 %s" % [_seconds(last["settle"]), _seconds(last["done"])])
	print("")
	print("| 번호 | 상태 | 자리까지 | 막은놈 | 막은놈 상태 | **같은 명령인가** | 서로지목 | " + "비켜 | 길대기 | 굳음 | 비빔 |")
	print("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	for agent in field.agents:
		if agent.state == ProtoUnitAgent.State.ARRIVED:
			continue
		var blocker := field.agent_of(agent.blocker_id)
		var mutual := blocker != null and blocker.blocker_id == agent.id
		print(
			(
				"| %d | %s | %.0f px | %d | %s | %s | %s | %s | %s | %d | %d |"
				% [
					agent.id,
					agent.state_name(),
					agent.position.distance_to(agent.goal),
					agent.blocker_id,
					"-" if blocker == null else blocker.state_name(),
					_same_order(field, agent, blocker),
					"O" if mutual else "-",
					"O" if agent.is_yielding() else "-",
					"O" if agent.waiting_for_path else "-",
					agent.stall_frames,
					agent.grind_frames,
				]
			)
		)
	_ahead(field)


## **막은 놈이 같은 명령의 유닛인가.** `settle` 이 `order_id` 를 지우므로 명단으로 묻는다.
func _same_order(field: ProtoUnitField, agent: ProtoUnitAgent, blocker: ProtoUnitAgent) -> String:
	if blocker == null:
		return "막은놈 없음"
	var order: ProtoUnitField.MoveOrder = field.order_by_id(agent.order_id)
	if order == null:
		return "내 명령이 사라짐"
	return "같은 명령" if order.member_ids.has(blocker.id) else "**남의 명령**"


## 기다리는 유닛의 진행 방향 앞에 실제로 무엇이 서 있는가. **예산이 보는 것과 같은 눈이다.**
##
## `_blocked_by_own_settled` 는 「같은 명령 + 도착 + 진행 방향 앞」 셋을 다 만족해야 건다.
## 셋 중 어느 것이 빠져서 안 걸리는지가 여기서 갈린다.
func _ahead(field: ProtoUnitField) -> void:
	var scratch: Array[ProtoUnitAgent] = []
	for agent in field.agents:
		if agent.state != ProtoUnitAgent.State.HOLDING:
			continue
		var order: ProtoUnitField.MoveOrder = field.order_by_id(agent.order_id)
		field.collect_neighbors(agent, scratch)
		print("")
		print("유닛 %d 의 앞(진행 방향 %.0f 도):" % [agent.id, rad_to_deg(agent.steer_dir.angle())])
		for other in scratch:
			var offset := other.position - agent.position
			var gap := offset.length()
			if gap > agent.radius + other.radius + ProtoUnitStep.HOLD_RELEASE:
				continue
			var cone := offset.dot(agent.steer_dir) / maxf(gap, 0.001)
			print(
				(
					"    %d %s 거리%.1f 앞각도%.2f%s %s"
					% [
						other.id,
						other.state_name(),
						gap,
						cone,
						" (앞)" if cone >= ProtoUnitStep.AHEAD_CONE else "",
						(
							"같은 명령"
							if order != null and order.member_ids.has(other.id)
							else "**남의 명령**"
						),
					]
				)
			)


func _seconds(value: float) -> String:
	return "못함" if value < 0.0 else "%.2f s" % value
