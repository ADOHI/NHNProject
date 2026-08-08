extends SceneTree
## 이동의 **지터 · 튕김 · 정지**를 숫자로 잰다. 헤드리스로 돈다.
##
##     godot --headless --path . -s res://tools/measure_unit_move.gd
##     godot --headless --path . -s res://tools/measure_unit_move.gd -- probe
##
## 눈으로 "좋아졌다"고 말하는 것은 증거가 아니다. 고치기 전과 후에 같은 숫자를 뽑아
## 나란히 놓아야 무엇이 나아졌고 무엇이 나빠졌는지 갈린다.
##
## `probe` 를 붙이면 항을 하나씩 꺼 보며 **어느 항이 지터를 만드는지**를 가른다.
## 원인을 짚지 않고 고치면 증상만 옮겨 다닌다.
##
## | 지표 | 무엇의 크기인가 |
## | --- | --- |
## | 꺾임 | 유닛당 초당 진행 방향이 꺾인 각도. **지터의 크기다** |
## | 역주행 | 제 목표에서 멀어지는 쪽으로 움직인 프레임의 비율. **튕김의 크기다** |
## | 굽이 | 실제 이동 거리 / 직선 거리. 1.0 이 완전한 직선이다 |
## | 벽보정 | 지형 보정이 위치를 강제로 옮긴 총 거리. 평상시에는 0 이다 |
## | 정지밀림 | **서 있는 유닛이 제 뜻과 무관하게 옮겨진 총 거리. 0 이어야 한다** |
## | 최대겹침 | 몸이 서로 파고든 최대 깊이. 통과하려면 몸 지름까지 자라야 한다 |
## | 막힌이동 | 가려 했으나 앞이 막혀 못 간 거리. 밀치기를 걷어낸 값이다 |
## | 정지 | 명령부터 전원이 멎기까지의 시간 |
## | 90% | 열에 아홉이 멎기까지의 시간. 정지와의 차이가 뒤끝이다 |
## | 통과 | 전원이 벽 너머로 넘어가기까지의 시간(괄호는 못 넘은 인원) |
## | 뒤진동 | 멎은 뒤 3 초 동안 움직인 총 거리 |
##
## **꺾임 · 역주행 · 굽이는 속도가 아니라 실제로 옮겨 간 위치로 잰다.**
##
## 속도로 재면 거짓말을 한다. 이웃의 몸에 막힌 유닛은 속도계가 초당 160 픽셀을 가리키면서
## 한 뼘도 못 간다. 그 속도를 그대로 세면 **가지도 않은 거리를 갔다고 하고, 서 있는 유닛의
## 꺾임을 이동의 꺾임으로 센다.** 사람 눈에 떨림으로 보이는 것은 조향의 의도가 아니라
## 몸이 실제로 그린 자취다. 밀치기를 걷어내면서 "속도는 있는데 못 가는" 프레임이 크게 늘어
## 이 구분이 결과를 뒤집을 만큼 커졌다.
##
## 처음에 "진행 방향이 한 프레임에 뒤집힌 횟수"를 세었더니 어느 상황에서도 0 에 붙었다.
## 회전 속도 제한이 프레임당 15 도로 걸려 있어 **한 프레임 안에서는 뒤집힐 수가 없기 때문이다.**
## 지터는 한 프레임의 반전이 아니라 여러 프레임에 걸친 좌우 왕복이므로, 누적 꺾임 각도와
## 역주행 비율로 갈아탔다. 이 둘은 같은 왕복을 서로 다른 각도에서 잡는다.

const _STEP := 1.0 / 60.0

## 이 시간까지 안 멎으면 못 멎은 것으로 기록한다.
const _MAX_SECONDS := 40.0

## 멎은 뒤 도착 진동을 재는 시간.
const _AFTER_SECONDS := 3.0

const _COLS := 60
const _ROWS := 34
const _CELL := 32.0

## 이 속도 아래에서는 방향이 의미 없어 꺾임도 역주행도 세지 않는다(최대 속도 배수).
const _MOVING_RATIO := 0.25


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] == "probe":
		_run_probe()
	else:
		_run_cases()
	quit()


func _run_cases() -> void:
	var rows: Array[Dictionary] = []
	rows.append(_measure("좁은 통로 40", _choke_field(40, 2), Vector2(1500, 545), 30 * _CELL))
	rows.append(_measure("좁은 통로 100", _choke_field(100, 2), Vector2(1500, 545), 30 * _CELL))
	rows.append(_measure("열린 곳 40", _open_field(40), Vector2(1500, 545), -1.0))
	rows.append(_measure("열린 곳 100", _open_field(100), Vector2(1500, 545), -1.0))
	rows.append(_measure("구석 24", _open_field(24), Vector2(60, 60), -1.0))
	rows.append(_measure("맞교차 40", _facing_field(40), Vector2(1500, 545), -1.0, Vector2(200, 545)))
	_print_table(rows)


## 두 무리가 서로의 자리를 바꾼다. **정면 교착이 생기는지 보는 판이다.**
##
## 지터를 잡겠다고 옆으로 비껴가는 성분을 걷어내면 마주 오는 둘이 그 자리에서 굳는다.
## 통로와 열린 곳만 재면 그 부작용이 안 보인다.
##
## `gate_cells` 를 주면 그 교차가 **좁은 문 안에서** 일어난다. 열린 곳에서는 서로 피할 자리가
## 넉넉해 교착이 생기지 않으므로, 규칙이 정말 필요한지는 문 안에서만 갈린다.
func _facing_field(count: int, gate_cells: int = 0) -> ProtoUnitField:
	var grid := _bordered_grid()
	if gate_cells > 0:
		var gate := _ROWS / 2 - gate_cells / 2
		for row in range(1, _ROWS - 1):
			grid.set_blocked(Vector2i(30, row), row < gate or row >= gate + gate_cells)
	var field := ProtoUnitField.new(grid, ProtoMoveTuning.new())
	var half := count / 2
	for index in count:
		var side := 200.0 if index < half else 1500.0
		var rank := index if index < half else index - half
		var at := Vector2(side + (rank % 5) * 34.0, 420.0 + (rank / 5) * 34.0)
		field.spawn(index % ProtoUnitAgent.KIND_NAMES.size(), grid.push_out(at, 14.0))
	return field


## 새로 넣은 장치를 하나씩 꺼 본다. **켜 두는 값은 꺼 봤을 때 나빠져야 자격이 있다.**
##
## 예전에는 힘 항(비껴가기 · 겹침 해소 · 분리 · 양보)을 하나씩 꺼 봤고, 어느 하나도 지터를
## 혼자 만들지 않았다. 그 항들이 통째로 없어졌으므로 이제 끌 수 있는 것은 **자기 몸의 성질**
## 뿐이다 — 조향 평활 · 회전 제한 · 대형 유지. 꺼도 나빠지지 않는 값은 있을 이유가 없다.
func _run_probe() -> void:
	var target := Vector2(1500, 545)
	var gate := 30 * _CELL
	var rows: Array[Dictionary] = []
	rows.append(_measure("전부 켬", _choke_field(40, 2), target, gate))
	rows.append(_measure("조향 평활 끔", _tuned(_choke_field(40, 2), "steer_smooth", 0.0), target, gate))
	rows.append(
		_measure("회전 제한 풀기", _tuned(_choke_field(40, 2), "turn_rate", 2000.0), target, gate)
	)
	rows.append(_measure("대형 유지 끔", _tuned(_choke_field(40, 2), "group_sync", 0.0), target, gate))
	rows.append(_measure("한 칸 문", _choke_field(40, 1), target, gate))
	rows.append(_measure("전부 켬 100", _choke_field(100, 2), target, gate))
	rows.append(
		_measure("조향 평활 끔 100", _tuned(_choke_field(100, 2), "steer_smooth", 0.0), target, gate)
	)
	var back := Vector2(200, 545)
	rows.append(_measure("문 맞교차 전부 켬", _facing_field(40, 2), target, -1.0, back))
	rows.append(
		_measure(
			"문 맞교차 평활 끔", _tuned(_facing_field(40, 2), "steer_smooth", 0.0), target, -1.0, back
		)
	)
	_print_table(rows)


func _tuned(field: ProtoUnitField, key: String, value: float) -> ProtoUnitField:
	field.tuning.set_value(key, value)
	return field


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


## 문 하나짜리 세로 벽. 여럿이 한 줄로 통과해야 하는 상황이다.
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
	var columns := 6
	for index in count:
		var at := Vector2(120.0 + (index % columns) * 34.0, 380.0 + (index / columns) * 34.0)
		field.spawn(index % ProtoUnitAgent.KIND_NAMES.size(), grid.push_out(at, 14.0))
	return field


# ----------------------------------------------------------------- 재기


func _measure(
	label: String,
	field: ProtoUnitField,
	target: Vector2,
	cross_x: float,
	other_target: Vector2 = Vector2.INF
) -> Dictionary:
	var count := field.agents.size()
	var heading := PackedVector2Array()
	var travelled := PackedFloat32Array()
	var origin := PackedVector2Array()
	var previous := PackedVector2Array()
	heading.resize(count)
	travelled.resize(count)
	origin.resize(count)
	previous.resize(count)
	for index in count:
		heading[index] = Vector2.ZERO
		travelled[index] = 0.0
		origin[index] = field.agents[index].position
		previous[index] = field.agents[index].position

	field.overlap_push_total = 0.0
	field.overlap_push_peak = 0.0
	field.settled_push_total = 0.0
	field.max_penetration = 0.0
	field.blocked_move_total = 0.0
	if other_target == Vector2.INF:
		field.issue_move(field.all_ids(), target)
	else:
		var ids := field.all_ids()
		var first := PackedInt32Array()
		var second := PackedInt32Array()
		for index in ids.size():
			if index < ids.size() / 2:
				first.append(ids[index])
			else:
				second.append(ids[index])
		field.issue_move(first, target)
		field.issue_move(second, other_target)
	var step_total := 0
	var step_frames := 0

	var moving_speed := field.tuning.get_value("max_speed") * _MOVING_RATIO
	var churn := 0.0
	var live_frames := 0
	var back_frames := 0
	var overrun_frames := 0
	var force_frames := 0
	var flow_frames := 0
	var seek_churn := 0.0
	var seek_dir := PackedVector2Array()
	seek_dir.resize(count)
	for index in count:
		seek_dir[index] = Vector2.ZERO
	var elapsed := 0.0
	var settle_time := -1.0
	var ninety_time := -1.0
	var cross_time := -1.0
	var worst_usec := 0
	var ninety := maxi(1, int(ceil(count * 0.1)))

	while elapsed < _MAX_SECONDS:
		field.step(_STEP)
		elapsed += _STEP
		# 명령을 낸 첫 프레임은 흐름장 계산이 얹혀 있어 최악값을 혼자 정한다. 그 프레임은
		# 명령 비용이지 이동 비용이 아니므로 정상 상태를 재는 표본에서 뺀다.
		if step_frames > 0:
			worst_usec = maxi(worst_usec, field.last_step_usec)
			step_total += field.last_step_usec
		step_frames += 1
		for index in count:
			var agent := field.agents[index]
			# **실제로 옮겨 간 거리로 잰다.** 막힌 유닛은 속도가 살아 있어도 위치가 그대로다.
			var moved := agent.position - previous[index]
			previous[index] = agent.position
			var speed := moved.length() / _STEP
			travelled[index] += moved.length()
			# 가려 했는데 앞이 막혀 절반도 못 간 프레임. **힘이 없어진 판에서 얼마나 눌려
			# 있는지를 재는 자리다.** 예전에는 분리력이 조향을 압도한 비율을 셌는데,
			# 분리력이 없어졌으므로 뜻과 결과의 차이로 갈아탔다.
			if agent.is_moving() and agent.debug_seek.length_squared() > 0.01:
				force_frames += 1
				if agent.velocity.length() < agent.debug_seek.length() * 0.5:
					overrun_frames += 1
				if not agent.has_sight:
					flow_frames += 1
				# 조향이 **가리키는** 방향이 프레임마다 얼마나 튀는가. 속도의 꺾임은 회전 제한을
				# 거친 결과라 원인을 감춘다. 입력이 튀는지 결과가 튀는지를 갈라야 한다.
				var wanted := agent.debug_seek.normalized()
				if seek_dir[index] != Vector2.ZERO:
					seek_churn += absf(rad_to_deg(wanted.angle_to(seek_dir[index])))
				seek_dir[index] = wanted
			if speed < moving_speed:
				continue
			var direction := moved.normalized()
			live_frames += 1
			var to_goal := agent.goal - agent.position
			if to_goal.length_squared() > 1.0 and direction.dot(to_goal.normalized()) < 0.0:
				back_frames += 1
			if heading[index] != Vector2.ZERO:
				churn += absf(rad_to_deg(direction.angle_to(heading[index])))
			heading[index] = direction
		var moving := field.moving_count()
		if ninety_time < 0.0 and moving <= ninety:
			ninety_time = elapsed
		if cross_time < 0.0 and cross_x > 0.0 and _all_past(field, cross_x):
			cross_time = elapsed
		if moving == 0:
			settle_time = elapsed
			break

	var resting := PackedVector2Array()
	for agent in field.agents:
		resting.append(agent.position)
	for _i in int(_AFTER_SECONDS / _STEP):
		field.step(_STEP)
	var after := 0.0
	for index in count:
		after += resting[index].distance_to(field.agents[index].position)

	var wiggle := 0.0
	for index in count:
		var straight := origin[index].distance_to(field.agents[index].position)
		wiggle += travelled[index] / maxf(straight, 1.0)

	var stranded := 0
	if cross_x > 0.0:
		for agent in field.agents:
			if agent.position.x < cross_x:
				stranded += 1
	var giving_up := 0
	var waiting := 0
	for agent in field.agents:
		if agent.state == ProtoUnitAgent.State.BLOCKED:
			giving_up += 1
		elif agent.state == ProtoUnitAgent.State.HOLDING:
			waiting += 1
	return {
		"label": label,
		"units": count,
		"churn": churn / maxf(float(live_frames), 1.0) * 60.0,
		"back": 100.0 * float(back_frames) / maxf(float(live_frames), 1.0),
		"overrun": 100.0 * float(overrun_frames) / maxf(float(force_frames), 1.0),
		"seek_churn": seek_churn / maxf(float(force_frames), 1.0) * 60.0,
		"flow": 100.0 * float(flow_frames) / maxf(float(force_frames), 1.0),
		"wiggle": wiggle / float(count),
		"push": field.overlap_push_total,
		"settle": settle_time,
		"ninety": ninety_time,
		"cross": cross_time,
		"stranded": stranded,
		"after": after,
		"blocked": giving_up,
		"waiting": waiting,
		"peak": field.overlap_push_peak,
		"settled_push": field.settled_push_total,
		"pierce": field.max_penetration,
		# 통과가 일어나려면 겹침이 여기까지 자라야 한다. 최대겹침을 이것과 나란히 놓아야
		# "겹치긴 했는데 얼마나 겹쳤나"에 답이 된다.
		"body": _smallest_body(field),
		"blocked_move": field.blocked_move_total,
		"step_ms": float(step_total) / maxf(float(step_frames - 1), 1.0) / 1000.0,
		"worst_ms": float(worst_usec) / 1000.0,
	}


## 가장 작은 두 몸이 닿는 거리. 겹침이 이만큼 자라면 중심이 반대편으로 넘어간 것이다.
func _smallest_body(field: ProtoUnitField) -> float:
	var smallest := INF
	for agent in field.agents:
		smallest = minf(smallest, agent.radius)
	return 0.0 if smallest == INF else smallest * 2.0


func _all_past(field: ProtoUnitField, cross_x: float) -> bool:
	for agent in field.agents:
		if agent.position.x < cross_x:
			return false
	return true


# ----------------------------------------------------------------- 내보내기


## 표를 둘로 나눈다. **묻는 질문이 다르기 때문이다.**
##
## 하나는 "얼마나 떠는가 · 언제 멎는가", 다른 하나는 "정말 밀치지 않는가"다.
## 한 줄에 열여섯 칸을 밀어 넣으면 어느 쪽도 읽히지 않는다.
func _print_table(rows: Array[Dictionary]) -> void:
	print(
		(
			"| 상황 | 꺾임 도/초 | 조향꺾임 도/초 | 눌림 % | 역주행 % | 굽이 | 튕김 최대 "
			+ "| 정지 | 90% | 통과 | 뒤진동 | 막힘 | 양보 | step 평균 | step 최악 |"
		)
	)
	print(
		(
			"| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- "
			+ "| --- | --- |"
		)
	)
	for row in rows:
		print(
			(
				(
					"| %s | %.0f | %.0f | %.0f | %.1f | %.2f | %.1f px | %s | %s | %s "
					+ "| %.1f px | %d | %d | %.3f ms | %.2f ms |"
				)
				% [
					row["label"],
					row["churn"],
					row["seek_churn"],
					row["overrun"],
					row["back"],
					row["wiggle"],
					row["peak"],
					_seconds(row["settle"]),
					_seconds(row["ninety"]),
					_crossing(row["cross"], row["stranded"]),
					row["after"],
					row["blocked"],
					row["waiting"],
					row["step_ms"],
					row["worst_ms"],
				]
			)
		)
	print("")
	print("| 상황 | 정지밀림 | 최대겹침 | 몸 지름 | 막힌이동 | 벽보정 |")
	print("| --- | --- | --- | --- | --- | --- |")
	for row in rows:
		print(
			(
				"| %s | %.2f px | %.2f px | %.0f px | %.0f px | %.0f px |"
				% [
					row["label"],
					row["settled_push"],
					row["pierce"],
					row["body"],
					row["blocked_move"],
					row["push"],
				]
			)
		)


func _seconds(value: float) -> String:
	return "못함" if value < 0.0 else "%.2f s" % value


func _crossing(value: float, stranded: int) -> String:
	if value >= 0.0:
		return "%.2f s" % value
	return "-" if stranded == 0 else "못함 (%d 명)" % stranded
