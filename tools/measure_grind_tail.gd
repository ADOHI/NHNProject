extends SceneTree
## **군중이 언제 멎는가**의 분포를 잰다. 헤드리스로 돈다.
##
##     godot --headless --path . -s res://tools/measure_grind_tail.gd -- spawn 1 10
##     godot --headless --path . -s res://tools/measure_grind_tail.gd -- target 1 10
##     godot --headless --path . -s res://tools/measure_grind_tail.gd -- count 4 20
##     godot --headless --path . -s res://tools/measure_grind_tail.gd -- grid 0 10
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
## # **한 판마다 한 줄씩 뱉고, 범위를 잘라 받는다**
##
## 이 기계는 예고 없이 프로세스를 죽인다 — 폭사율이 **그 프로세스가 한 일의 양에 비례한다**
## (`docs/test-stability.md`). 처음에 수백 판을 한 프로세스에 몰아넣었더니 **네 번 돌려 네 번
## 다 `signal 11`** 이 났고, 표를 끝에만 찍고 있어서 그때까지 잰 것이 통째로 사라졌다.
##
## 그래서 둘을 바꿨다. **범위(`from`..`to`)를 받아 짧게 돌고**, **판 하나가 끝날 때마다
## `RESULT` 한 줄을 즉시 뱉는다.** 폭사해도 그때까지의 줄은 남고, 부르는 쪽이 그 범위만
## 다시 돌리면 된다 — `tools/run_gut_retry.py` 가 쓰는 것과 같은 수법이다.
##
## | 값 | 뜻 |
## | --- | --- |
## | `first_zero` | `moving_count()` 가 처음 0 이 된 시각(초). -1 이면 끝내 안 멎었다 |
## | `last_moving` | `MOVING` 이 있던 **마지막** 시각. 이쪽이 진짜 "끝났다"이다 |
## | `wakes` | 한 번 0 이 된 뒤 다시 `MOVING` 이 생긴 횟수 |
## | `at_test` | 시험이 묻는 그 순간(30 초)에 `MOVING` 이던 유닛 수 |
## | `capped` | 한도까지 굴려도 안 멎었다. **1 이 하나라도 나오면 (나)다** |

const _STEP := 1.0 / 60.0

## 시험이 묻는 시각(프레임). 여기서의 `moving_count()` 가 곧 시험의 판정이다.
const _TEST_FRAMES := 1800

## 여기까지 굴려도 안 멎으면 **교착으로 친다**(프레임). 시험 한도의 두 배다.
const _CAP_FRAMES := 3600

## `MOVING` 이 없는 채 이만큼 이어지면 그 판은 끝난 것으로 보고 일찍 끊는다(프레임).
##
## 기다림은 6 프레임마다 다시 보고, 깨어날 계기는 남이 움직이는 것뿐이다. 10 초 동안
## 아무도 안 움직였으면 계기가 생길 데가 없다. 끊지 않으면 판마다 한도를 다 돈다.
const _QUIET_FRAMES := 600

## 시험이 쓰는 판. **여기를 시험과 다르게 두면 재는 것이 다른 판이 된다.**
const _COLS := 40
const _ROWS := 24
const _CELL := 32.0
const _COUNT := 40
const _TARGET := Vector2(800, 400)

## 격자 훑기가 도는 방 크기. 번호로 잘라 받으려고 펼쳐 둔다.
const _GRID_COLS: Array[int] = [20, 24, 28, 32, 36, 40, 48, 56, 64]
const _GRID_ROWS: Array[int] = [14, 18, 24, 30, 36]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if args.size() > 0 else "spawn"
	if mode == "one" or mode == "trace":
		var axis := args[1] if args.size() > 2 else "spawn"
		var value := int(args[2]) if args.size() > 2 else 0
		var cap := int(args[3]) * 60 if args.size() > 3 else _CAP_FRAMES
		_run_one(axis, value, cap, mode == "trace")
		quit()
		return
	var from := int(args[1]) if args.size() > 1 else 0
	var to := int(args[2]) if args.size() > 2 else from
	for index in range(from, to + 1):
		match mode:
			"spawn":
				_run_spawn(index)
			"target":
				_run_target(index)
			"count":
				_run_count(index)
			"grid":
				_run_grid(index)
			_:
				print("모드: spawn | target | count | grid | one <모드> <씨앗>")
				break
	quit()


# ----------------------------------------------------------------- 축 넷


## **시작 자리를 흔든다.** 통합자가 24 회 흔든 그 축이다. 0 번은 시험 그대로다.
func _run_spawn(seed_value: int) -> void:
	var jitter := 0.0 if seed_value == 0 else 0.5
	_measure("자리 %d" % seed_value, _crowd_field(_COUNT, _COLS, _ROWS, jitter, seed_value), _TARGET)


## **목표 지점을 흔든다.** 목표가 벽에 붙으면 자리 배정이 눌려 뭉친다.
func _run_target(seed_value: int) -> void:
	var target := _target_of(seed_value)
	var field := _crowd_field(_COUNT, _COLS, _ROWS, 0.0, 0)
	_measure("목표 %d (%.0f,%.0f)" % [seed_value, target.x, target.y], field, target)


## **인원을 한 명씩 훑는다.** `_LINE_LIMIT` 이 44 와 46 에서만 무너진 전례가 있다.
func _run_count(count: int) -> void:
	if count < 1:
		return
	_measure("%d 명" % count, _crowd_field(count, _COLS, _ROWS, 0.0, 0), _TARGET)


## **방 크기를 훑는다.** 좁으면 뭉칠 자리가 없고 넓으면 흩어질 자리가 있다.
func _run_grid(index: int) -> void:
	if index < 0 or index >= _GRID_COLS.size() * _GRID_ROWS.size():
		return
	var cols := _GRID_COLS[index / _GRID_ROWS.size()]
	var rows := _GRID_ROWS[index % _GRID_ROWS.size()]
	var target := Vector2(float(cols) * _CELL * 0.62, float(rows) * _CELL * 0.5)
	_measure("%dx%d" % [cols, rows], _crowd_field(_COUNT, cols, rows, 0.0, 0), target)


func _target_of(seed_value: int) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919
	return Vector2(
		rng.randf_range(120.0, float(_COLS) * _CELL - 120.0),
		rng.randf_range(120.0, float(_ROWS) * _CELL - 120.0)
	)


## 판 하나를 다시 굴리고 **끝에 무엇이 남았는지** 유닛마다 뱉는다.
##
## `trace` 를 켜면 **초마다 누가 `MOVING` 인지**를 함께 뱉는다. 한계 순환인지 아주 느린
## 수렴인지는 끝 상태 한 장으로는 못 가른다 - 시간에 따라 누가 깨어 있는지를 봐야 한다.
func _run_one(mode: String, seed_value: int, cap: int, trace: bool) -> void:
	var target := _target_of(seed_value) if mode == "target" else _TARGET
	var jitter := 0.0 if mode == "target" or seed_value == 0 else 0.5
	var count := seed_value if mode == "count" else _COUNT
	var field := _crowd_field(count, _COLS, _ROWS, jitter, seed_value)
	_measure("%s %d" % [mode, seed_value], field, target, cap, trace)
	print("")
	print("| 번호 | 상태 | 남은거리 | 정체 | 비빔 | 눌림 | 재시도 | 막은놈 | 양보 | 대기 | 문 |")
	print("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	for agent in field.agents:
		print(
			(
				"| %d | %s | %.1f | %d | %d | %d | %d | %d | %d | %s | %d |"
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
					"예" if agent.waiting_for_path else "-",
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
		field.spawn(index % ProtoUnitAgent.KIND_NAMES.size(), grid.push_out(at, 14.0))
	return field


# ----------------------------------------------------------------- 재기


## 판 하나를 굴리고 **언제 멎었는지**를 한 줄로 뱉는다.
func _measure(
	label: String,
	field: ProtoUnitField,
	target: Vector2,
	cap: int = _CAP_FRAMES,
	trace: bool = false
) -> void:
	field.issue_move(field.all_ids(), target)
	var first_zero := -1
	var last_moving := -1
	var wakes := 0
	var at_test := 0
	var quiet := 0
	var frame := 0
	while frame < cap:
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
			at_test = moving
		if trace and frame % 60 == 0:
			_trace_line(field, frame)
		if quiet >= _QUIET_FRAMES and frame >= _TEST_FRAMES:
			break
	var holding := 0
	var stuck := 0
	for agent in field.agents:
		if agent.state == ProtoUnitAgent.State.HOLDING:
			holding += 1
		elif agent.is_moving():
			stuck += 1
	# **한 판이 끝날 때마다 바로 뱉는다.** 폭사해도 여기까지는 남는다.
	print(
		(
			"RESULT\t%s\t%.2f\t%.2f\t%d\t%d\t%d\t%d\t%d"
			% [
				label,
				_to_seconds(first_zero),
				_to_seconds(last_moving),
				wakes,
				at_test,
				holding,
				stuck,
				1 if last_moving >= _CAP_FRAMES else 0,
			]
		)
	)


func _to_seconds(frame: int) -> float:
	return -1.0 if frame < 0 else float(frame) * _STEP


## **초마다 깨어 있는 유닛과 그 사정.** 한계 순환이면 같은 번호가 되풀이해서 나온다.
func _trace_line(field: ProtoUnitField, frame: int) -> void:
	var awake := PackedStringArray()
	var holding := 0
	for agent in field.agents:
		if agent.state == ProtoUnitAgent.State.HOLDING:
			holding += 1
			continue
		if not agent.is_moving():
			continue
		awake.append(_awake_note(field, agent))
	print("TRACE\t%.1f\t양보 %d\t%s" % [float(frame) * _STEP, holding, " ".join(awake)])


## 깨어 있는 유닛 하나의 사정. **자리를 누가 차지하고 있는지도 함께 뽑는다.**
##
## 아무도 안 막는데(`b0`) 못 가는 유닛이 있으면 막은 것은 앞이 아니라 **자리**다.
func _awake_note(field: ProtoUnitField, agent: ProtoUnitAgent) -> String:
	var squatter := INF
	var squatter_id := 0
	for other in field.agents:
		if other.id == agent.id:
			continue
		var gap := other.position.distance_to(agent.goal)
		if gap < squatter:
			squatter = gap
			squatter_id = other.id
	return (
		"%d(d%.1f c%d g%d p%d b%d h%d 자리%d@%.1f%s)"
		% [
			agent.id,
			agent.position.distance_to(agent.goal),
			agent.creep_frames,
			agent.grind_frames,
			agent.press_frames,
			agent.blocker_id,
			agent.hold_retries,
			squatter_id,
			squatter,
			"y" if agent.is_yielding() else "",
		]
	)
