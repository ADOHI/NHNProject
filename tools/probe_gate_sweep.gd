extends SceneTree
## **한 칸 문을 인원별로 훑고, 아직 안 재 본 두 판을 연다.**
##
##     godot --headless --path . -s res://tools/probe_gate_sweep.gd
##
## §27 이 가르친 것을 문에도 적용한다 - **눈금 사이가 넓으면 사이에 있는 것은 없는 것이 된다.**
## 열린 곳에서 42, 43, 49 가 표 사이에 숨어 있었다. 문은 아직 40 한 점만 쟀다.
##
## | 무엇 | 왜 |
## | --- | --- |
## | 인원 4 ~ 50 | **적을 때 오히려 느려질 수 있다** - 줄을 서느라 |
## | 문 차례 껐다 켜기 | 켠 것이 이긴다는 것을 인원마다 확인한다 |
## | **문 안에서 맞교차** | 규칙이 없다. 없으면 무슨 일이 나는지부터 본다 |
## | **문이 벽에 붙은 판** | 줄 자리가 벽 밖으로 나간다. **터지나, 조용히 이상해지나** |

const _STEP := 1.0 / 60.0
const _MAX_SECONDS := 40.0
const _COLS := 60
const _ROWS := 34
const _CELL := 32.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] == "facing":
		_facing()
		quit()
		return
	_sweep()
	_facing()
	_cornered()
	quit()


func _bordered_grid() -> ProtoNavGrid:
	var grid := ProtoNavGrid.new(_COLS, _ROWS, _CELL)
	for column in _COLS:
		grid.set_blocked(Vector2i(column, 0), true)
		grid.set_blocked(Vector2i(column, _ROWS - 1), true)
	for row in _ROWS:
		grid.set_blocked(Vector2i(0, row), true)
		grid.set_blocked(Vector2i(_COLS - 1, row), true)
	return grid


## 문 하나짜리 세로 벽. `gate_row` 를 주면 문의 위치를 옮긴다.
func _gate_grid(gate_cells: int, gate_row: int = -1) -> ProtoNavGrid:
	var grid := _bordered_grid()
	var gate := gate_row if gate_row >= 0 else _ROWS / 2 - gate_cells / 2
	for row in range(1, _ROWS - 1):
		var inside := row >= gate and row < gate + gate_cells
		grid.set_blocked(Vector2i(30, row), not inside)
	return grid


func _populate(grid: ProtoNavGrid, count: int, origin: Vector2) -> ProtoUnitField:
	var field := ProtoUnitField.new(grid, ProtoMoveTuning.new())
	for index in count:
		var at := origin + Vector2((index % 6) * 34.0, (index / 6) * 34.0)
		field.spawn(index % ProtoUnitAgent.KIND_NAMES.size(), grid.push_out(at, 14.0))
	return field


## 한 판 굴려 통과와 정지와 전원끝을 돌려준다.
func _run(field: ProtoUnitField, target: Vector2, cross_x: float) -> Dictionary:
	field.issue_move(field.all_ids(), target)
	var elapsed := 0.0
	var cross := -1.0
	var settle := -1.0
	var done := -1.0
	while elapsed < _MAX_SECONDS:
		field.step(_STEP)
		elapsed += _STEP
		if cross < 0.0 and cross_x > 0.0 and _all_past(field, cross_x):
			cross = elapsed
		var moving := field.moving_count()
		var waiting := _waiting(field)
		if settle < 0.0 and moving == 0:
			settle = elapsed
		if done < 0.0 and moving == 0 and waiting == 0:
			done = elapsed
			break
	var stranded := 0
	var giving_up := 0
	for agent in field.agents:
		if cross_x > 0.0 and agent.position.x < cross_x:
			stranded += 1
		if agent.state == ProtoUnitAgent.State.BLOCKED:
			giving_up += 1
	return {
		"cross": cross,
		"settle": settle,
		"done": done,
		"stranded": stranded,
		"blocked": giving_up,
		"relays": field.propagate_relays,
	}


func _waiting(field: ProtoUnitField) -> int:
	var waiting := 0
	for agent in field.agents:
		if agent.state == ProtoUnitAgent.State.HOLDING:
			waiting += 1
	return waiting


func _all_past(field: ProtoUnitField, cross_x: float) -> bool:
	for agent in field.agents:
		if agent.position.x < cross_x:
			return false
	return true


func _seconds(value: float) -> String:
	return "못함" if value < 0.0 else "%.2f s" % value


func _crossing(value: float, stranded: int) -> String:
	if value >= 0.0:
		return "%.2f s" % value
	return "-" if stranded == 0 else "못함 (%d)" % stranded


# ----------------------------------------------------------------- 인원 훑기


func _sweep() -> void:
	print("# 한 칸 문 인원별 - 문 차례 켬 / 끔")
	print("")
	print("| 인원 | 통과 (켬) | 통과 (끔) | 정지 (켬) | 전원끝 (켬) | 막힘 | 이어밀기 (켬) | (끔) |")
	print("| --- | --- | --- | --- | --- | --- | --- | --- |")
	var target := Vector2(1500, 545)
	var gate := 30.0 * _CELL
	var counts: Array[int] = [4, 8, 12, 24]
	for count in range(32, 51):
		counts.append(count)
	for count in counts:
		var on := _populate(_gate_grid(1), count, Vector2(120.0, 380.0))
		var on_result := _run(on, target, gate)
		var off := _populate(_gate_grid(1), count, Vector2(120.0, 380.0))
		off.tuning.set_value("gate_queue", 0.0)
		var off_result := _run(off, target, gate)
		print(
			(
				"| %d | %s | %s | %s | %s | %d | %d | %d |"
				% [
					count,
					_crossing(on_result["cross"], on_result["stranded"]),
					_crossing(off_result["cross"], off_result["stranded"]),
					_seconds(on_result["settle"]),
					_seconds(on_result["done"]),
					int(on_result["blocked"]),
					int(on_result["relays"]),
					int(off_result["relays"]),
				]
			)
		)


# ----------------------------------------------------------------- 문 안에서 맞교차


## **규칙이 없다. 없으면 무슨 일이 나는지부터 본다.**
##
## §23.10.3 이 SWAP 과 ROTATE 를 안 쓰기로 못 박았으므로 자리 맞바꾸기로는 못 푼다.
## 그러면 남는 것은 "한쪽이 물러나 준다"뿐인데, 그것이 저절로 되는지 아니면 굳는지를 본다.
func _facing() -> void:
	print("")
	print("# 문 안에서 맞교차 - **규칙 없음. 무슨 일이 나나**")
	print("")
	print("| 문 폭 | 인원 | 정지 | 전원끝 | 막힘 | 왼쪽에 남은 수 |")
	print("| --- | --- | --- | --- | --- | --- |")
	var widths: Array[int] = [1, 2]
	# **인원을 훑는다.** 40 에서만 굳는다면 인원 문제이고, 이 레인은 인원 훑는 법을 안다.
	var crowds: Array[int] = [8, 16, 24, 28, 32, 36, 40, 44]
	for gate_cells in widths:
		for count in crowds:
			var grid := _gate_grid(gate_cells)
			var field := ProtoUnitField.new(grid, ProtoMoveTuning.new())
			var half := count / 2
			for index in count:
				var side := 200.0 if index < half else 1500.0
				var rank := index if index < half else index - half
				var at := Vector2(side + (rank % 5) * 34.0, 420.0 + (rank / 5) * 34.0)
				field.spawn(index % ProtoUnitAgent.KIND_NAMES.size(), grid.push_out(at, 14.0))
			var ids := field.all_ids()
			var first := PackedInt32Array()
			var second := PackedInt32Array()
			for index in ids.size():
				if index < ids.size() / 2:
					first.append(ids[index])
				else:
					second.append(ids[index])
			field.issue_move(first, Vector2(1500, 545))
			field.issue_move(second, Vector2(200, 545))
			var elapsed := 0.0
			var settle := -1.0
			var done := -1.0
			while elapsed < _MAX_SECONDS:
				field.step(_STEP)
				elapsed += _STEP
				var moving := field.moving_count()
				if settle < 0.0 and moving == 0:
					settle = elapsed
				if moving == 0 and _waiting(field) == 0:
					done = elapsed
					break
			var left := 0
			var giving_up := 0
			for agent in field.agents:
				if agent.position.x < 30.0 * _CELL:
					left += 1
				if agent.state == ProtoUnitAgent.State.BLOCKED:
					giving_up += 1
			print(
				(
					"| %d 칸 | %d | %s | %s | %d | %d |"
					% [gate_cells, count, _seconds(settle), _seconds(done), giving_up, left]
				)
			)


# ----------------------------------------------------------------- 문이 벽에 붙은 판


## **줄 자리가 벽 밖으로 나가는 판.** 터지나, 조용히 이상해지나.
##
## 문을 방 맨 위로 올린다. 줄은 문에서 들어온 길로 뻗는데, 그 길이 벽에 바로 닿는다.
func _cornered() -> void:
	print("")
	print("# 문이 벽에 붙은 판 - **줄 자리가 벽 밖으로 나간다**")
	print("")
	print("| 문 줄 | 인원 | 통과 | 정지 | 전원끝 | 막힘 | 벽보정 |")
	print("| --- | --- | --- | --- | --- | --- | --- |")
	var rows_to_try: Array[int] = [1, 2]
	var crowds: Array[int] = [12, 40]
	for gate_row in rows_to_try:
		for count in crowds:
			var grid := _gate_grid(1, gate_row)
			var field := _populate(grid, count, Vector2(120.0, 120.0))
			var target := Vector2(1500, float(gate_row) * _CELL + 16.0)
			var result := _run(field, target, 30.0 * _CELL)
			print(
				(
					"| %d | %d | %s | %s | %s | %d | %.0f px |"
					% [
						gate_row,
						count,
						_crossing(result["cross"], result["stranded"]),
						_seconds(result["settle"]),
						_seconds(result["done"]),
						int(result["blocked"]),
						field.overlap_push_total,
					]
				)
			)
