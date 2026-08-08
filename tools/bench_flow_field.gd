extends SceneTree
## 흐름장 한 번 만드는 데 얼마나 드는가. **명령을 처리하는 그 프레임 안에서 동기로 돈다.**
##
##     godot --headless --path . -s res://tools/bench_flow_field.gd
##
## 지표 도구(`measure_unit_move.gd`)는 명령 한 번 주고 40 초를 굴리므로 이 비용이 평균에
## 묻힌다. `last_step_usec` 은 매 프레임 조향 비용이라 이것을 아예 안 센다. 그런데 사람이
## 느끼는 것은 **우클릭한 그 순간의 멈칫**이다. 그래서 따로 잰다.
##
## 벽 거리 비용이 이 값을 키울 수 있어서 함께 잰다 - `_integrate` 가 SPFA 라 칸값이 고르지
## 않으면 재완화가 늘어난다. 늘어난 만큼을 눈으로 보고 판단해야지 짐작하면 안 된다.

const _ROUNDS := 60
const _COLS := 60
const _ROWS := 34
const _CELL := 32.0


func _initialize() -> void:
	print("| 판 | 흐름장 평균 | 최악 | 벽거리 굽기 |")
	print("| --- | --- | --- | --- |")
	_bench("열린 곳", _open_grid())
	_bench("좁은 통로", _choke_grid())
	quit()


func _bench(label: String, grid: ProtoNavGrid) -> void:
	# 벽 거리는 지형당 한 번만 굽는다. 그 한 번이 얼마인지 따로 잰다.
	var bake_started := Time.get_ticks_usec()
	grid.clearance_at(Vector2i(1, 1))
	var bake := Time.get_ticks_usec() - bake_started

	var total := 0
	var worst := 0
	for round_index in _ROUNDS:
		# 목적지를 옮겨 가며 잰다. 한 점만 재면 그 점의 운에 값이 매인다.
		var target := Vector2(
			200.0 + float(round_index % 12) * 110.0, 200.0 + float(round_index % 5) * 90.0
		)
		var started := Time.get_ticks_usec()
		grid.build_flow_field(target)
		var spent := Time.get_ticks_usec() - started
		total += spent
		worst = maxi(worst, spent)
	print(
		(
			"| %s | %.1f ms | %.1f ms | %.2f ms |"
			% [
				label,
				float(total) / float(_ROUNDS) / 1000.0,
				float(worst) / 1000.0,
				float(bake) / 1000.0
			]
		)
	)


func _open_grid() -> ProtoNavGrid:
	var grid := ProtoNavGrid.new(_COLS, _ROWS, _CELL)
	for column in _COLS:
		grid.set_blocked(Vector2i(column, 0), true)
		grid.set_blocked(Vector2i(column, _ROWS - 1), true)
	for row in _ROWS:
		grid.set_blocked(Vector2i(0, row), true)
		grid.set_blocked(Vector2i(_COLS - 1, row), true)
	return grid


func _choke_grid() -> ProtoNavGrid:
	var grid := _open_grid()
	var gate := _ROWS / 2 - 1
	for row in range(1, _ROWS - 1):
		grid.set_blocked(Vector2i(30, row), row < gate or row >= gate + 2)
	return grid
