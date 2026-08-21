extends SceneTree
## **군중이 언제 멎는가**의 분포를 잰다. 헤드리스로 돈다.
##
##     godot --headless --path . -s res://tools/measure_grind_tail.gd -- spawn 200
##     godot --headless --path . -s res://tools/measure_grind_tail.gd -- target 100
##     godot --headless --path . -s res://tools/measure_grind_tail.gd -- count
##     godot --headless --path . -s res://tools/measure_grind_tail.gd -- grid
##     godot --headless --path . -s res://tools/measure_grind_tail.gd -- one spawn 37
##
## `test_nobody_grinds_forever_in_a_crowd` 이 **CI(우분투)에서만** 30 초를 넘긴다.
## 이 기계에서는 6.55 초에 멎는다. 가를 것은 하나다 —
##
## | 가설 | 이 도구가 보는 것 |
## | --- | --- |
## | **(가) 꼬리가 두껍다** | 전부 멎는데 분포의 꼬리가 30 초에 닿는가 |
## | **(나) 진짜 교착** | **한도 안에 안 멎는 판이 하나라도 있는가** |
##
## 시뮬레이션에는 난수가 없다(§23.11). 난수는 **판을 흔드는 데만** 쓰고 씨앗을 찍어 두어
## 어떤 판이든 `one` 으로 그대로 되살릴 수 있게 한다.
##
## | 값 | 뜻 |
## | --- | --- |
## | `첫정지` | `moving_count()` 가 처음 0 이 된 시각 |
## | `최종정지` | `MOVING` 이 있던 **마지막** 시각. 이쪽이 진짜 "끝났다"이다 |
## | `깨어남` | 한 번 0 이 된 뒤 다시 `MOVING` 이 생긴 횟수 |
## | `30초` | 시험이 묻는 그 순간에 `MOVING` 이던 유닛 수 |

const _STEP := 1.0 / 60.0

## 시험이 묻는 시각(프레임). 여기서의 `moving_count()` 가 곧 시험의 판정이다.
const _TEST_FRAMES := 1800

## 여기까지 굴려도 안 멎으면 **교착으로 친다**(프레임). 시험 한도의 두 배다.
const _CAP_FRAMES := 3600

## `MOVING` 이 없는 채 이만큼 이어지면 그 판은 끝난 것으로 보고 일찍 끊는다(프레임).
##
## 기다림은 6 프레임마다 다시 보고, 깨어날 계기는 남이 움직이는 것뿐이다. 10 초 동안
## 아무도 안 움직였으면 계기가 생길 데가 없다. 끊지 않으면 수백 판이 전부 60 초를 다 돈다.
const _QUIET_FRAMES := 600

## 시험이 쓰는 판. **여기를 시험과 다르게 두면 재는 것이 다른 판이 된다.**
const _COLS := 40
const _ROWS := 24
const _CELL := 32.0
const _COUNT := 40
const _TARGET := Vector2(800, 400)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if args.size() > 0 else "spawn"
	match mode:
		"spawn":
			_sweep_spawn(int(args[1]) if args.size() > 1 else 200)
		"target":
			_sweep_target(int(args[1]) if args.size() > 1 else 100)
		"count":
			_sweep_count()
		"grid":
			_sweep_grid()
		"one":
			_run_one(args[1] if args.size() > 2 else "spawn", int(args[2]) if args.size() > 2 else 0)
		_:
			print("모드: spawn | target | count | grid | one <모드> <씨앗>")
	quit()


# ----------------------------------------------------------------- 훑기


## **시작 자리를 흔든다.** 통합자가 24 회 흔든 그 축을 수백 회로 넓힌 것이다.
func _sweep_spawn(trials: int) -> void:
	var rows: Array[Dictionary] = []
	rows.append(_measure("기준", _crowd_field(_COUNT, _COLS, _ROWS, 0.0, 0), _TARGET))
	for seed_value in range(1, trials + 1):
		var field := _crowd_field(_COUNT, _COLS, _ROWS, 0.5, seed_value)
		rows.append(_measure("자리 %d" % seed_value, field, _TARGET))
	_report("시작 자리 흔들기 (±0.5 px)", rows)


## **목표 지점을 흔든다.** 목표가 벽에 붙으면 자리 배정이 눌려 뭉친다.
func _sweep_target(trials: int) -> void:
	var rng := RandomNumberGenerator.new()
	var rows: Array[Dictionary] = []
	for seed_value in range(1, trials + 1):
		rng.seed = seed_value * 7919
		var target := Vector2(
			rng.randf_range(120.0, float(_COLS) * _CELL - 120.0),
			rng.randf_range(120.0, float(_ROWS) * _CELL - 120.0)
		)
		var field := _crowd_field(_COUNT, _COLS, _ROWS, 0.0, 0)
		rows.append(_measure("목표 %d (%.0f,%.0f)" % [seed_value, target.x, target.y], field, target))
	_report("목표 지점 흔들기", rows)


## **인원을 한 명씩 훑는다.** `_LINE_LIMIT` 이 44 와 46 에서만 무너진 전례가 있다.
func _sweep_count() -> void:
	var rows: Array[Dictionary] = []
	for count in range(4, 65):
		rows.append(_measure("%d 명" % count, _crowd_field(count, _COLS, _ROWS, 0.0, 0), _TARGET))
	_report("인원 훑기", rows)


## **방 크기를 훑는다.** 좁으면 뭉칠 자리가 없고 넓으면 흩어질 자리가 있다.
func _sweep_grid() -> void:
	var rows: Array[Dictionary] = []
	for cols in [20, 24, 28, 32, 36, 40, 48, 56, 64]:
		for rows_count in [14, 18, 24, 30, 36]:
			var field := _crowd_field(_COUNT, cols, rows_count, 0.0, 0)
			var target := Vector2(float(cols) * _CELL * 0.62, float(rows_count) * _CELL * 0.5)
			rows.append(_measure("%dx%d" % [cols, rows_count], field, target))
	_report("격자 크기 훑기", rows)


## 판 하나를 다시 굴리고 **끝에 무엇이 남았는지** 유닛마다 뱉는다.
func _run_one(mode: String, seed_value: int) -> void:
	var field: ProtoUnitField
	var target := _TARGET
	if mode == "target":
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value * 7919
		target = Vector2(
			rng.randf_range(120.0, float(_COLS) * _CELL - 120.0),
			rng.randf_range(120.0, float(_ROWS) * _CELL - 120.0)
		)
		field = _crowd_field(_COUNT, _COLS, _ROWS, 0.0, 0)
	else:
		field = _crowd_field(_COUNT, _COLS, _ROWS, 0.5 if seed_value != 0 else 0.0, seed_value)
	var row := _measure("%s %d" % [mode, seed_value], field, target, true)
	print("")
	print(
		(
			"첫정지 %s · 최종정지 %s · 깨어남 %d · 30 초에 이동 %d"
			% [
				_seconds(row["first_zero"]),
				_seconds(row["last_moving"]),
				row["wakes"],
				row["moving_at_test"],
			]
		)
	)
	print("")
	print("| 번호 | 상태 | 남은거리 | 정체 | 비빔 | 눌림 | 재시도 | 막은놈 | 양보 | 문 |")
	print("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	for agent in field.agents:
		print(
			(
				"| %d | %s | %.1f | %d | %d | %d | %d | %d | %d | %d |"
				% [
					agent.id,
					agent.state_name(),
					agent.position.distance_to(agent.goal),
					agent.creep_frames,
					agent.grind_frames,
					agent.press_frames,
					agent.hold_retries,
					agent.blocker_id,
					agent.yield_for,
					agent.gate_id,
				]
			)
		)


# ----------------------------------------------------------------- 판 만들기


## 시험과 **같은 판**을 만든다. 흔드는 폭이 0 이면 시험 그 자체다.
func _crowd_field(
	count: int, cols: int, rows: int, jitter: float, seed_value: int
) -> ProtoUnitField:
	var grid := NavGrid.new(cols, rows, _CELL)
	for column in cols:
		grid.set_blocked(Vector2i(column, 0), true)
		grid.set_blocked(Vector2i(column, rows - 1), true)
	for row in rows:
		grid.set_blocked(Vector2i(0, row), true)
		grid.set_blocked(Vector2i(cols - 1, row), true)
	var field := ProtoUnitField.new(grid, ProtoMoveTuning.new())
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 104_729 + 17
	for index in count:
		var at := Vector2(120.0 + (index % 5) * 34.0, 200.0 + (index / 5) * 34.0)
		if jitter > 0.0:
			at += Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter))
		field.spawn(index % ProtoUnitAgent.KIND_NAMES.size(), at)
	return field


# ----------------------------------------------------------------- 재기


## 판 하나를 굴리고 **언제 멎었는지**를 돌려준다.
func _measure(
	label: String, field: ProtoUnitField, target: Vector2, verbose: bool = false
) -> Dictionary:
	field.issue_move(field.all_ids(), target)
	var first_zero := -1
	var last_moving := -1
	var wakes := 0
	var moving_at_test := -1
	var quiet := 0
	var frame := 0
	while frame < _CAP_FRAMES:
		field.step(_STEP)
		frame += 1
		var moving := field.moving_count()
		if moving > 0:
			if first_zero >= 0 and quiet > 0:
				wakes += 1
			last_moving = frame
			quiet = 0
		else:
			if first_zero < 0:
				first_zero = frame
			quiet += 1
		if frame == _TEST_FRAMES:
			moving_at_test = moving
		if quiet >= _QUIET_FRAMES and frame >= _TEST_FRAMES:
			break
	if moving_at_test < 0:
		moving_at_test = 0
	var holding := 0
	var stuck_moving := 0
	for agent in field.agents:
		if agent.state == ProtoUnitAgent.State.HOLDING:
			holding += 1
		elif agent.is_moving():
			stuck_moving += 1
	if verbose:
		print("| %s | 굴린 프레임 %d |" % [label, frame])
	return {
		"label": label,
		"first_zero": _to_seconds(first_zero),
		"last_moving": _to_seconds(last_moving),
		"wakes": wakes,
		"moving_at_test": moving_at_test,
		"holding": holding,
		"stuck_moving": stuck_moving,
		"capped": last_moving >= _CAP_FRAMES,
	}


func _to_seconds(frame: int) -> float:
	return -1.0 if frame < 0 else float(frame) * _STEP


# ----------------------------------------------------------------- 내놓기


## **꼬리를 본다.** 평균은 이 물음에 아무 답도 못 준다.
func _report(title: String, rows: Array[Dictionary]) -> void:
	var settle: Array[float] = []
	var never: Array[Dictionary] = []
	var over_test: Array[Dictionary] = []
	for row in rows:
		if row["capped"] or row["first_zero"] < 0.0:
			never.append(row)
		else:
			settle.append(row["last_moving"])
		if row["moving_at_test"] > 0:
			over_test.append(row)
	settle.sort()
	print("")
	print("# %s — %d 판" % [title, rows.size()])
	print("")
	print("| 값 | 결과 |")
	print("| --- | --- |")
	print("| 안 멎은 판 (%d 초 한도) | **%d** |" % [_CAP_FRAMES / 60, never.size()])
	print("| 30 초에 이동 유닛이 남은 판 | **%d** |" % over_test.size())
	if not settle.is_empty():
		print("| 최종정지 최소 | %s |" % _seconds(settle[0]))
		print("| 최종정지 중앙 | %s |" % _seconds(settle[settle.size() / 2]))
		print("| 최종정지 90 % | %s |" % _seconds(settle[mini(settle.size() - 1, settle.size() * 9 / 10)]))
		print("| 최종정지 99 % | %s |" % _seconds(settle[mini(settle.size() - 1, settle.size() * 99 / 100)]))
		print("| 최종정지 **최대** | **%s** |" % _seconds(settle[settle.size() - 1]))
	print("")
	var worst := rows.duplicate()
	worst.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return a["last_moving"] > b["last_moving"]
	)
	print("## 오래 걸린 열")
	print("")
	print("| 판 | 첫정지 | 최종정지 | 깨어남 | 30 초에 이동 | 양보 | 남은 이동 |")
	print("| --- | --- | --- | --- | --- | --- | --- |")
	for index in mini(10, worst.size()):
		var row: Dictionary = worst[index]
		print(
			(
				"| %s | %s | %s | %d | %d | %d | %d |"
				% [
					row["label"],
					_seconds(row["first_zero"]),
					_seconds(row["last_moving"]),
					row["wakes"],
					row["moving_at_test"],
					row["holding"],
					row["stuck_moving"],
				]
			)
		)


func _seconds(value: float) -> String:
	return "안 멎음" if value < 0.0 else "%.2f s" % value
