extends SceneTree
## **좁은 목 찾기가 두 칸 문을 한 칸 문과 같이 잡는가, 그리고 정말 공짜인가.**
##
##     godot --headless --path . -s res://tools/probe_choke.gd
##
## §28 의 설계가 "벽 거리 1 인 통행 가능 칸의 연결 성분이 곧 좁은 목이고, 벽 거리 맵은
## 이미 굽고 있으니 공짜다"라고 적었다. **미확인 둘을 여기서 잰다.**
##
## | 물음 | 왜 무서운가 |
## | --- | --- |
## | 두 칸 문도 잡히나 | 잡히면 설계가 **지금 잘 도는 판**(좁은 통로)을 건드린다 |
## | 찾는 값이 얼마인가 | "공짜다"가 이 프로젝트에서 몇 번 틀렸다 |
##
## 두 칸 문이 잡히면 줄이 하나여서 **폭의 절반만 쓰게 되고**, 그것이 §28 미확인 셋 중
## 제일 무서운 항목이다.

const _COLS := 60
const _ROWS := 34
const _CELL := 32.0

## 벽 거리가 이 값 이하인 통행 가능 칸을 좁은 목으로 본다.
const _CHOKE_CLEARANCE := 1

## 값을 재는 반복 횟수.
const _ROUNDS := 200


func _initialize() -> void:
	print("| 판 | 벽거리 칸 | 성분 | 문 | 값 " + "| **복도 칸** | **성분** | **문** | **값** |")
	print("| --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	_survey("한 칸 문", _gate_grid(1), 1)
	_survey("두 칸 문", _gate_grid(2), 2)
	_survey("열린 곳", _bordered_grid(), 0)
	print("")
	_slots_check()
	quit()


## **좁은 목을 피하는 자리 배정이 실제로 무엇을 바꾸는가.**
##
## 지표 판 열다섯에서는 한 칸도 안 바뀌었다 - 목적지가 전부 문에서 먼 열린 곳이라
## 자리가 애초에 좁은 목에 안 놓인다. **그러면 이 장치는 언제 일하는가**를 여기서 본다.
## 목적지를 문 한가운데로 찍는다 - 사람이 실제로 하는 짓이다.
func _slots_check() -> void:
	var grid := _gate_grid(1)
	var gate_center := grid.cell_to_world(Vector2i(30, _ROWS / 2))
	var walkable := func(point: Vector2) -> bool: return grid.is_circle_free(point, 12.0)
	var spacious := func(point: Vector2) -> bool:
		return grid.is_circle_free(point, 12.0) and not grid.is_choke_at(point)
	print("## 목적지를 문 한가운데로 찍었을 때")
	print("")
	print("| 인원 | 좁은 목에 놓인 자리 (지금) | 좁은 목에 놓인 자리 (피하게) |")
	print("| --- | --- | --- |")
	for count in [4, 12, 40]:
		var plain := ProtoFormation.build_slots(count, gate_center, 30.0, walkable)
		var avoid := ProtoFormation.build_slots(count, gate_center, 30.0, walkable, spacious)
		print("| %d | %d | %d |" % [count, _on_choke(grid, plain), _on_choke(grid, avoid)])


func _on_choke(grid: ProtoNavGrid, slots: PackedVector2Array) -> int:
	var hits := 0
	for slot in slots:
		if grid.is_choke_at(slot):
			hits += 1
	return hits


func _bordered_grid() -> ProtoNavGrid:
	var grid := ProtoNavGrid.new(_COLS, _ROWS, _CELL)
	for column in _COLS:
		grid.set_blocked(Vector2i(column, 0), true)
		grid.set_blocked(Vector2i(column, _ROWS - 1), true)
	for row in _ROWS:
		grid.set_blocked(Vector2i(0, row), true)
		grid.set_blocked(Vector2i(_COLS - 1, row), true)
	return grid


func _gate_grid(gate_cells: int) -> ProtoNavGrid:
	var grid := _bordered_grid()
	var gate := _ROWS / 2 - gate_cells / 2
	for row in range(1, _ROWS - 1):
		var inside := row >= gate and row < gate + gate_cells
		grid.set_blocked(Vector2i(30, row), not inside)
	return grid


## 좁은 목 칸을 모아 연결 성분으로 묶는다. **문 칸이 실제로 잡히는지**를 함께 본다.
func _survey(label: String, grid: ProtoNavGrid, gate_cells: int) -> void:
	# 벽 거리 맵을 미리 굽혀 둔다. 찾는 값에 굽는 값을 섞으면 답이 안 나온다.
	grid.clearance_at(Vector2i(1, 1))

	var started := Time.get_ticks_usec()
	var found := PackedInt32Array()
	for _round in _ROUNDS:
		found = _choke_cells(grid)
	var find_usec := float(Time.get_ticks_usec() - started) / float(_ROUNDS)

	var corridor_started := Time.get_ticks_usec()
	var corridor := PackedInt32Array()
	for _round in _ROUNDS:
		corridor = _corridor_cells(grid)
	var corridor_usec := float(Time.get_ticks_usec() - corridor_started) / float(_ROUNDS)

	var groups := _components(grid, found)
	var corridor_groups := _components(grid, corridor)
	var corridor_hit := 0
	var gate_row2 := _ROWS / 2 - gate_cells / 2
	for cell_index in corridor:
		var cell := Vector2i(cell_index % grid.cols, cell_index / grid.cols)
		if (
			cell.x == 30
			and gate_cells > 0
			and cell.y >= gate_row2
			and cell.y < gate_row2 + gate_cells
		):
			corridor_hit += 1
	# 문 칸이 실제로 목록에 들었는가.
	var gate_row := _ROWS / 2 - gate_cells / 2
	var gate_hit := 0
	for cell_index in found:
		var cell := Vector2i(cell_index % grid.cols, cell_index / grid.cols)
		if (
			cell.x == 30
			and gate_cells > 0
			and cell.y >= gate_row
			and cell.y < gate_row + gate_cells
		):
			gate_hit += 1
	var mark := "-"
	if gate_cells > 0:
		mark = "**%d / %d 칸 잡힘**" % [gate_hit, gate_cells]
	var corridor_mark := "-"
	if gate_cells > 0:
		corridor_mark = "**%d / %d 칸**" % [corridor_hit, gate_cells]
	print(
		(
			"| %s | %d | %d | %s | %.3f ms | %d | %d | %s | %.3f ms |"
			% [
				label,
				found.size(),
				groups,
				mark,
				find_usec / 1000.0,
				corridor.size(),
				corridor_groups,
				corridor_mark,
				corridor_usec / 1000.0,
			]
		)
	)


## **복도 칸.** 네 이웃 중 통행 가능한 것이 둘 이하이고 그 둘이 마주 보고 있으면 복도다.
##
## 벽 거리로 묻는 것이 왜 틀렸는지가 이 함수와의 대조로 드러난다. 벽 거리 1 은 "벽에
## 붙어 있다"이지 "좁다"가 아니다. 방 둘레는 전부 벽에 붙어 있지만 좁지 않다.
## **좁다는 것은 마주 보는 두 쪽이 다 막혔다는 뜻이다.**
func _corridor_cells(grid: ProtoNavGrid) -> PackedInt32Array:
	var cells := PackedInt32Array()
	for row in grid.rows:
		for column in grid.cols:
			var cell := Vector2i(column, row)
			if not grid.is_walkable(cell):
				continue
			var west := grid.is_walkable(cell + Vector2i(-1, 0))
			var east := grid.is_walkable(cell + Vector2i(1, 0))
			var north := grid.is_walkable(cell + Vector2i(0, -1))
			var south := grid.is_walkable(cell + Vector2i(0, 1))
			var horizontal := west and east and not north and not south
			var vertical := north and south and not west and not east
			if horizontal or vertical:
				cells.append(grid.cell_index(cell))
	return cells


## 벽 거리가 문턱 이하인 통행 가능 칸.
func _choke_cells(grid: ProtoNavGrid) -> PackedInt32Array:
	var cells := PackedInt32Array()
	for row in grid.rows:
		for column in grid.cols:
			var cell := Vector2i(column, row)
			if not grid.is_walkable(cell):
				continue
			if grid.clearance_at(cell) <= _CHOKE_CLEARANCE:
				cells.append(grid.cell_index(cell))
	return cells


## 이웃한 좁은 목 칸끼리 묶어 성분 수를 센다.
func _components(grid: ProtoNavGrid, cells: PackedInt32Array) -> int:
	var member := {}
	for index in cells:
		member[index] = true
	var seen := {}
	var groups := 0
	for index in cells:
		if seen.has(index):
			continue
		groups += 1
		var stack: Array[int] = [index]
		seen[index] = true
		while not stack.is_empty():
			var at: int = stack.pop_back()
			var cell := Vector2i(at % grid.cols, at / grid.cols)
			for offset_y in range(-1, 2):
				for offset_x in range(-1, 2):
					var next := cell + Vector2i(offset_x, offset_y)
					if not grid.is_inside(next):
						continue
					var next_index := grid.cell_index(next)
					if member.has(next_index) and not seen.has(next_index):
						seen[next_index] = true
						stack.append(next_index)
	return groups
