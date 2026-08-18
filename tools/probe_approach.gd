extends SceneTree
## **적이 다가오는 것을 실제 이동으로 잰다.** 전투 레인의 `approach_speed` 가 흉내 내는 수다.
##
##     godot --headless --path . -s res://tools/probe_approach.gd
##
## 전투(§28.20.55)는 `approach_speed = ProtoMoveTuning.max_speed` 로 적이 다가오는 것을
## **1 차원으로** 흉내 낸다 - 길찾기도 대열도 막힘도 없다. 그쪽이 스스로 "거친 흉내"라고 적었다.
##
## **여기서 답하는 것은 하나다 - 진짜로 걸으면 몇 초에 몇 명이 닿나.**
##
## | 전투가 쓰는 수 | 이 도구가 주는 수 |
## | --- | --- |
## | 초당 230 픽셀로 곧장 | **n 번째가 닿는 시각.** 대열 자리 · 서로 막힘 · 도착 판정이 들어간 값 |
##
## 「한 번에 닿는 것은 여섯」이 전투의 상한이고, **줄을 메우는 것은 이동의 일**이다.

const _STEP := 1.0 / 60.0
const _MAX_SECONDS := 120.0
const _COLS := 60
const _ROWS := 34
const _CELL := 32.0

## 스쿼드가 선 자리. 적은 이리로 온다.
const _SQUAD := Vector2(1500.0, 545.0)

## 이 거리 안에 들면 **닿은 것으로 친다.** 전투의 접촉 사거리에 해당한다.
##
## 몸 지름이 18~24 이므로 세 몸 남짓이다. 정확한 값은 전투가 정하고, 여기서는
## **시각이 인원에 어떻게 붙는가**를 보는 것이 목적이라 자릿수만 맞으면 된다.
const _REACH := 72.0


func _initialize() -> void:
	print("# 적이 다가오는 데 걸리는 시간 - **실제 이동으로 잰 값**")
	print("")
	print("| 판 | 인원 | 첫째 닿음 | 여섯째 | 스무째 | 절반 | 전원 | 전원 멎음 |")
	print("| --- | --- | --- | --- | --- | --- | --- | --- |")
	for count in [6, 20, 40, 100]:
		_run("열린 곳", _open_grid(), count)
	for count in [20, 40, 100]:
		_run("문 하나", _gate_grid(2), count)
	quit()


func _open_grid() -> ProtoNavGrid:
	var grid := ProtoNavGrid.new(_COLS, _ROWS, _CELL)
	for column in _COLS:
		grid.set_blocked(Vector2i(column, 0), true)
		grid.set_blocked(Vector2i(column, _ROWS - 1), true)
	for row in _ROWS:
		grid.set_blocked(Vector2i(0, row), true)
		grid.set_blocked(Vector2i(_COLS - 1, row), true)
	return grid


## 적이 문을 지나 와야 하는 판. 던전이면 흔하다.
func _gate_grid(gate_cells: int) -> ProtoNavGrid:
	var grid := _open_grid()
	var gate := _ROWS / 2 - gate_cells / 2
	for row in range(1, _ROWS - 1):
		grid.set_blocked(Vector2i(30, row), row < gate or row >= gate + gate_cells)
	return grid


func _run(label: String, grid: ProtoNavGrid, count: int) -> void:
	var field := ProtoUnitField.new(grid, ProtoMoveTuning.new())
	for index in count:
		var at := Vector2(120.0 + (index % 6) * 34.0, 380.0 + (index / 6) * 34.0)
		field.spawn(index % ProtoUnitAgent.KIND_NAMES.size(), grid.push_out(at, 14.0))
	field.issue_move(field.all_ids(), _SQUAD)

	var arrived := PackedFloat32Array()
	arrived.resize(count)
	for index in count:
		arrived[index] = -1.0
	var elapsed := 0.0
	var settled := -1.0
	while elapsed < _MAX_SECONDS:
		field.step(_STEP)
		elapsed += _STEP
		for index in count:
			if arrived[index] < 0.0:
				if field.agents[index].position.distance_to(_SQUAD) <= _REACH:
					arrived[index] = elapsed
		if settled < 0.0 and field.moving_count() == 0:
			settled = elapsed
			break

	var times: Array[float] = []
	for index in count:
		if arrived[index] >= 0.0:
			times.append(arrived[index])
	times.sort()
	print(
		(
			"| %s | %d | %s | %s | %s | %s | %s | %s |"
			% [
				label,
				count,
				_nth(times, 1),
				_nth(times, 6),
				_nth(times, 20),
				_nth(times, count / 2),
				_nth(times, count),
				"못함" if settled < 0.0 else "%.1f s" % settled,
			]
		)
	)


## n 번째가 닿은 시각. 그만큼 안 닿았으면 「못함」이다.
func _nth(times: Array[float], n: int) -> String:
	if n <= 0 or times.size() < n:
		return "-" if n <= 0 else "못함"
	return "%.1f s" % times[n - 1]
