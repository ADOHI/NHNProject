extends SceneTree
## **멎은 뒤에 누가 움직이는가**, 그리고 **열린 곳은 40 에서만 늦는가.**
##
##     godot --headless --path . -s res://tools/probe_settled.gd
##
## 두 가지를 한 번에 답한다. 둘 다 "지표가 한 숫자로 뭉뚱그려 놓아 원인이 안 보이는" 자리다.
##
## | 물음 | 갈리는 것 |
## | --- | --- |
## | 뒤진동 3 px 이 누구인가 | 한 명이면 그 유닛의 경로, 여럿이면 규칙 |
## | 멎었다고 할 때 그 유닛의 상태는 | `도착`뿐이면 진짜 끝, `양보`가 남아 있으면 **깨어날 수 있다** |
## | 열린 곳 40 이 특별한가 | 앞뒤 인원도 같이 늦으면 추세, 40 만 늦으면 그 판의 배치다 |
##
## **`moving_count()` 는 `이동`만 센다.** `양보`(HOLDING)로 선 유닛이 남아 있어도 0 이 되고,
## 지표는 그 순간을 "전원 멎음"으로 적는다. 그런데 `양보`는 **되돌아올 수 있는 정지**라
## 그 뒤에 스스로 깨어난다. 뒤진동이 0 이 아니면 여기부터 봐야 한다.

const _STEP := 1.0 / 60.0
const _MAX_SECONDS := 40.0
const _AFTER_SECONDS := 3.0
const _COLS := 60
const _ROWS := 34
const _CELL := 32.0


func _initialize() -> void:
	_after_settle("좁은 통로 100", _choke_field(100, 2), Vector2(1500, 545))
	_after_settle("열린 곳 100", _open_field(100), Vector2(1500, 545))
	_open_series()
	quit()


# ----------------------------------------------------------------- 판 만들기


func _bordered_grid() -> ProtoNavGrid:
	var grid := ProtoNavGrid.new(_COLS, _ROWS, _CELL)
	for column in _COLS:
		grid.set_blocked(Vector2i(column, 0), true)
		grid.set_blocked(Vector2i(column, _ROWS - 1), true)
	for row in _ROWS:
		grid.set_blocked(Vector2i(0, row), true)
		grid.set_blocked(Vector2i(_COLS - 1, row), true)
	return grid


func _choke_field(count: int, gate_cells: int) -> ProtoUnitField:
	var grid := _bordered_grid()
	var gate := _ROWS / 2 - gate_cells / 2
	for row in range(1, _ROWS - 1):
		var inside := row >= gate and row < gate + gate_cells
		grid.set_blocked(Vector2i(30, row), not inside)
	return _populate(grid, count)


func _open_field(count: int) -> ProtoUnitField:
	return _populate(_bordered_grid(), count)


func _populate(grid: ProtoNavGrid, count: int) -> ProtoUnitField:
	var field := ProtoUnitField.new(grid, ProtoMoveTuning.new())
	for index in count:
		var at := Vector2(120.0 + (index % 6) * 34.0, 380.0 + (index / 6) * 34.0)
		field.spawn(index % ProtoUnitAgent.KIND_NAMES.size(), grid.push_out(at, 14.0))
	return field


# ----------------------------------------------------------------- 재기


## 멎은 그 순간의 상태를 적어 두고, 3 초 뒤에 누가 얼마나 옮겨졌는지 본다.
func _after_settle(label: String, field: ProtoUnitField, target: Vector2) -> void:
	field.issue_move(field.all_ids(), target)
	var elapsed := 0.0
	while elapsed < _MAX_SECONDS:
		field.step(_STEP)
		elapsed += _STEP
		if field.moving_count() == 0:
			break

	var resting := PackedVector2Array()
	var was := PackedStringArray()
	for agent in field.agents:
		resting.append(agent.position)
		was.append(agent.state_name())

	var tally := {}
	for name in was:
		tally[name] = int(tally.get(name, 0)) + 1
	print("")
	print("## %s - %.2f 초에 멎음. 그때의 상태: %s" % [label, elapsed, str(tally)])

	for _i in int(_AFTER_SECONDS / _STEP):
		field.step(_STEP)

	var total := 0.0
	var movers := 0
	print("")
	print("| 번호 | 멎을 때 | 3초 뒤 | 옮겨진 거리 | 자리까지 | 비켜 | 길대기 |")
	print("| --- | --- | --- | --- | --- | --- | --- |")
	for index in field.agents.size():
		var agent := field.agents[index]
		var shift := resting[index].distance_to(agent.position)
		total += shift
		if shift <= 0.05:
			continue
		movers += 1
		print(
			(
				"| %d | %s | %s | %.2f px | %.0f px | %s | %s |"
				% [
					agent.id,
					was[index],
					agent.state_name(),
					shift,
					agent.position.distance_to(agent.goal),
					"O" if agent.is_yielding() else "-",
					"O" if agent.waiting_for_path else "-",
				]
			)
		)
	print("")
	print("움직인 유닛 %d 명, 합계 %.2f px" % [movers, total])


## 열린 곳을 인원을 하나씩 올려 가며 잰다. **40 만 늦으면 그 판의 배치다.**
func _open_series() -> void:
	print("")
	print("## 열린 곳 인원별 정지 - 한 칸씩")
	print("")
	print("**눈금 사이가 넓으면 사이에 있는 것은 없는 것이 된다.** 표가 4, 8, 12, 24, 40, 100 만")
	print("재는 동안 42 와 48 이 헐거워진 것을 아무도 못 봤다. 어디가 헐거운지 지도를 만든다.")
	print("")
	print("**정지 두 칸을 나란히 낸다.** 지표가 쓰는 `moving_count()` 는 `이동`만 세므로")
	print("`양보`로 선 유닛이 남아 있어도 0 이 된다. 그런데 `양보`는 되돌아올 수 있는 정지라")
	print("그 뒤에 깨어나 걷고, 걸으면서 이미 **도착한 이웃을 옆으로 밀어낸다** - 그것이 뒤진동이다.")
	print("")
	print("| 인원 | 정지 (이동만) | 정지 (양보까지) | 멎을 때 양보 | 뒤진동 |")
	print("| --- | --- | --- | --- | --- |")
	for count in range(32, 51):
		var field := _open_field(count)
		field.issue_move(field.all_ids(), Vector2(1500, 545))
		var elapsed := 0.0
		var settled := -1.0
		var truly := -1.0
		var resting := PackedVector2Array()
		var waiting := 0
		while elapsed < _MAX_SECONDS:
			field.step(_STEP)
			elapsed += _STEP
			if settled < 0.0 and field.moving_count() == 0:
				settled = elapsed
				waiting = _waiting_count(field)
				resting = PackedVector2Array()
				for agent in field.agents:
					resting.append(agent.position)
			if field.moving_count() == 0 and _waiting_count(field) == 0:
				truly = elapsed
				break
		if resting.is_empty():
			for agent in field.agents:
				resting.append(agent.position)
		for _i in int(_AFTER_SECONDS / _STEP):
			field.step(_STEP)
		var after := 0.0
		for index in field.agents.size():
			after += resting[index].distance_to(field.agents[index].position)
		print(
			(
				"| %d | %s | %s | %d | %.1f px |"
				% [
					count,
					"못함" if settled < 0.0 else "%.2f s" % settled,
					"못함" if truly < 0.0 else "%.2f s" % truly,
					waiting,
					after,
				]
			)
		)


func _waiting_count(field: ProtoUnitField) -> int:
	var waiting := 0
	for agent in field.agents:
		if agent.state == ProtoUnitAgent.State.HOLDING:
			waiting += 1
	return waiting
