extends GutTest
## **유닛이 언제 멈추는가**의 단위 테스트. 포기 시간을 걷어낸 자리다.
##
## 예전에는 "이만큼 못 나아가면 포기"였다. 그런데 포기한 유닛에게 다시 명령하면 가는 일이
## 있었다 — 실제로는 막히지 않았는데 알고리즘이 막혔다고 잘못 결론 낸 것이고, 포기 시간은
## 그 오판을 시간으로 덮는 장치였다. 늘리면 굼떠지고 줄이면 일찍 포기하니 어느 쪽도 답이 아니다.
##
## 시간 대신 상태로 묻게 바꾸었으므로, 지켜야 할 성질은 넷이다.
##
## | 성질 | 지키는 테스트 |
## | --- | --- |
## | 영원히 비비지 않는다 | `test_nobody_grinds_forever_in_a_crowd` |
## | **흔든 판에서도 그렇다** | `test_nobody_grinds_forever_in_shaken_crowds` |
## | 정말 갈 수 없으면 멎는다 | `test_sealed_goal_stops_everyone` |
## | 상황이 바뀌면 스스로 재개한다 | `test_waiting_unit_resumes_when_the_blocker_leaves` |
## | 기다림이 포기로 바뀌지 않는다 | `test_waiting_never_becomes_giving_up` |

const _STEP := 1.0 / 60.0

## 군중이 멎기까지 기다려 주는 한도(초). **분포를 재서 정했다.**
##
## 예전에는 30 초였고 근거가 없었다. 그리고 **그 값으로는 잡을 것을 못 잡고 있었다** —
## 시작 자리를 ±0.5 px 흔든 300 판 중 **16 판(5.4 %)이 영원히 안 멎었는데**(기획 §23.11.5)
## 이 기계의 기준 판은 6.55 초에 멎어서 안 보였고, CI 는 그 5 % 중 하나를 뽑아 매번 빨갛게 났다.
##
## 교착을 고친 뒤 다시 재니 **최장이 25.92 초**다. 30 초는 여유가 1.16 배뿐이다.
##
## 그리고 이 시뮬레이션은 **한 기계 안에서만** 결정론이다. `sin`·`cos`·`atan2` 가 libm
## 구현이라 리눅스와 윈도우가 마지막 자리에서 갈리고, 걸음 고르기가 그 값으로 **이산 선택**을
## 하므로 두 기계는 사실상 **다른 판**을 돈다(기획 §23.11.3). 그러므로 한도는 이 기계에서 본
## 최장이 아니라 **그 몇 배**여야 한다. 60 초는 2.3 배다.
##
## > **늘려도 이 시험이 잡는 것은 그대로다** — 「영원히 안 멎는 것」이다.
## > 고치기 전의 그 판들은 **300 초를 굴려도** 안 멎었고, 주기 50 초로 되풀이했다.
const _CROWD_LIMIT := 60.0

## 멎었다고 인정하려면 이만큼 `이동`이 없어야 한다(초).
##
## **한 순간만 보면 한계 순환에 속는다.** 고치기 전 어떤 판은 `이동`이 0 이 된 뒤에도
## 60 초 동안 **179 번** 다시 깨어났다 — 초당 세 번이다. 그런 판에서 딱 30 초에 한 번
## 물어보는 것은 판정이 아니라 동전 던지기다. 그래서 **한동안 조용한지**를 묻는다.
const _CROWD_QUIET := 2.0


func _run(field: ProtoUnitField, seconds: float) -> void:
	for _i in int(seconds / _STEP):
		field.step(_STEP)


## 한 칸 폭 복도와 그 너머의 방. 복도에서는 옆으로 비켜 지나갈 수 없다.
func _make_corridor_field() -> ProtoUnitField:
	var grid := NavGrid.new(40, 24, 32.0)
	for row in grid.rows:
		for column in grid.cols:
			grid.set_blocked(Vector2i(column, row), true)
	for column in range(15, 26):
		grid.set_blocked(Vector2i(column, 12), false)
	for column in range(26, 34):
		for row in range(8, 17):
			grid.set_blocked(Vector2i(column, row), false)
	return ProtoUnitField.new(grid, ProtoMoveTuning.new())


## 비키지 않는 아군 앞에서 굴린다. **못을 박지 않고 정말 그 자리에 있었는지 확인한다.**
##
## 예전에는 걸음마다 제자리로 되돌려야 했다. 서 있는 쪽이 더 많이 밀리도록 되어 있어서
## 지나가는 유닛이 그대로 밀고 나갔기 때문이다. 되돌리기가 판정을 가려 주고 있었다.
##
## 지금은 **진행 방향으로만 못을 박는다.** 복도는 가로로 뚫려 있으므로 x 가 그대로여야 하고,
## y 는 길에서 비켜서느라 움직일 수 있다 - 그것은 밀고 나아가기가 아니다.
func _run_pinned(field: ProtoUnitField, blocker: ProtoUnitAgent, seconds: float) -> void:
	var anchor := blocker.position
	for _i in int(seconds / _STEP):
		field.step(_STEP)
	assert_lt(absf(blocker.position.x - anchor.x), 0.5, "막고 선 아군이 진행 방향으로 떠밀렸다")


## 복도를 막은 아군과 그 뒤에 선 유닛을 만든다.
func _make_blocked_walker(field: ProtoUnitField) -> Array[ProtoUnitAgent]:
	var grid := field.grid
	var blocker := field.spawn(0, grid.cell_to_world(Vector2i(22, 12)))
	var walker := field.spawn(0, grid.cell_to_world(Vector2i(17, 12)))
	field.issue_move(PackedInt32Array([walker.id]), grid.cell_to_world(Vector2i(32, 12)))
	return [blocker, walker]


func test_giving_up_by_time_is_gone() -> void:
	# 슬라이더가 되살아나면 판정이 시간으로 돌아갔다는 뜻이다.
	for definition in ProtoMoveTuning.DEFS:
		assert_ne(String(definition["key"]), "stuck_timeout", "포기 시간이 되살아났다")


func test_waiting_unit_resumes_when_the_blocker_leaves() -> void:
	# **이번 요구의 핵심이다.** 막은 쪽이 비키면 재명령 없이 스스로 간다.
	var field := _make_corridor_field()
	var pair := _make_blocked_walker(field)
	var blocker := pair[0]
	var walker := pair[1]
	_run_pinned(field, blocker, 6.0)
	assert_eq(walker.state, ProtoUnitAgent.State.HOLDING, "복도를 막은 아군 앞에서 기다리지 않았다")
	assert_ne(walker.order_id, 0, "기다리는 유닛이 명령을 놓아 버리면 다시 갈 수 없다")
	assert_eq(field.moving_count(), 0, "서서 기다리는 유닛이 이동중으로 세이면 도착 판정이 끝나지 않는다")

	# 막고 있던 유닛이 비킨다. **명령을 다시 내리지 않는다.**
	blocker.position = field.grid.cell_to_world(Vector2i(30, 15))
	_run(field, 8.0)
	assert_eq(walker.state, ProtoUnitAgent.State.ARRIVED, "막은 유닛이 비켰는데도 다시 가지 않았다")
	assert_gt(walker.position.x, 1000.0, "복도를 지나지 못했다")


func test_waiting_never_becomes_giving_up() -> void:
	# 오래 기다려도 포기로 떨어지면 안 된다. 그것이 예전의 포기 시간이 하던 일이다.
	var field := _make_corridor_field()
	var pair := _make_blocked_walker(field)
	_run_pinned(field, pair[0], 25.0)
	assert_eq(pair[1].state, ProtoUnitAgent.State.HOLDING, "기다리던 유닛이 결국 포기해 버렸다")


func test_sealed_goal_stops_everyone() -> void:
	# 정말 갈 수 없는 곳이다. 흐름장이 내가 선 칸까지 못 닿았다는 것으로 **즉시** 안다 —
	# 시간을 들여 확인할 일이 아니다.
	var grid := NavGrid.new(40, 24, 32.0)
	for column in grid.cols:
		grid.set_blocked(Vector2i(column, 0), true)
		grid.set_blocked(Vector2i(column, grid.rows - 1), true)
	for row in grid.rows:
		grid.set_blocked(Vector2i(0, row), true)
		grid.set_blocked(Vector2i(grid.cols - 1, row), true)
	# 완전히 둘러싸인 한 칸. 통행은 가능하지만 어디서도 닿을 수 없다.
	for offset_y in range(-1, 2):
		for offset_x in range(-1, 2):
			if offset_x != 0 or offset_y != 0:
				grid.set_blocked(Vector2i(30 + offset_x, 12 + offset_y), true)
	var field := ProtoUnitField.new(grid, ProtoMoveTuning.new())
	for index in 6:
		field.spawn(index % 3, Vector2(120.0 + (index % 3) * 34.0, 200.0 + (index / 3) * 34.0))
	field.issue_move(field.all_ids(), grid.cell_to_world(Vector2i(30, 12)))
	_run(field, 1.0)
	assert_eq(field.moving_count(), 0, "닿을 수 없는 자리를 두고 계속 움직였다")
	for agent in field.agents:
		assert_eq(agent.state, ProtoUnitAgent.State.BLOCKED, "%d 번이 막힘으로 멎지 않았다" % agent.id)


## 테두리만 막힌 방에 유닛 40 대와 한 점짜리 명령. **흔드는 폭이 0 이면 예전 판 그대로다.**
##
## 난수는 **판을 흔드는 데만** 쓴다. 시뮬레이션에는 난수가 한 톨도 없고, 씨앗을 박아 두므로
## 같은 씨앗은 언제나 같은 판이다. 흔드는 폭 0.5 px 는 몸 반지름의 4 % 로, 사람 눈에는
## 같은 판이지만 걸음 고르기의 이산 선택을 갈라 **다른 판**으로 만든다.
func _make_crowd_field(jitter: float, shake_seed: int) -> ProtoUnitField:
	var grid := NavGrid.new(40, 24, 32.0)
	for column in grid.cols:
		grid.set_blocked(Vector2i(column, 0), true)
		grid.set_blocked(Vector2i(column, grid.rows - 1), true)
	for row in grid.rows:
		grid.set_blocked(Vector2i(0, row), true)
		grid.set_blocked(Vector2i(grid.cols - 1, row), true)
	var field := ProtoUnitField.new(grid, ProtoMoveTuning.new())
	var rng := RandomNumberGenerator.new()
	rng.seed = shake_seed * 104_729 + 17
	for index in 40:
		var at := Vector2(120.0 + (index % 5) * 34.0, 200.0 + (index / 5) * 34.0)
		if jitter > 0.0:
			at += Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter))
		field.spawn(index % 3, at)
	field.issue_move(field.all_ids(), Vector2(800, 400))
	return field


## 전원이 멎어 **한동안 조용해질 때까지** 굴린다. 끝내 안 조용해지면 음수를 돌려준다.
##
## 흔한 판은 7 초 언저리에 조용해지므로 예전처럼 30 초를 꽉 채워 굴리지 않는다 —
## **한도는 못 멎는 판에만 든다.**
func _seconds_until_quiet(field: ProtoUnitField) -> float:
	var need := int(_CROWD_QUIET / _STEP)
	var quiet := 0
	for index in int(_CROWD_LIMIT / _STEP):
		field.step(_STEP)
		if field.moving_count() != 0:
			quiet = 0
			continue
		quiet += 1
		if quiet >= need:
			return float(index + 1 - quiet) * _STEP
	return -1.0


func test_nobody_grinds_forever_in_a_crowd() -> void:
	# 포기 시간이 막고 있던 것이 이것이다. 걷어내되 무한 루프를 만들면 안 된다.
	var settled_at := _seconds_until_quiet(_make_crowd_field(0.0, 0))
	assert_gt(settled_at, 0.0, "%.0f 초가 지나도 비비고 있는 유닛이 있다" % _CROWD_LIMIT)


func test_nobody_grinds_forever_in_shaken_crowds() -> void:
	# **판 하나만 보는 것이 결함을 숨겼다.**
	#
	# 이 판은 이 기계에서 6.55 초에 멎었고, 그래서 여기서는 늘 초록이었다. 그런데 같은
	# 판을 ±0.5 px 흔들면 **스무 판에 하나꼴로 영원히 안 멎었다**(기획 §23.11.5).
	# CI 는 부동소수점이 갈려 사실상 흔든 판을 돌고 있었고, 그래서 CI 에서만 빨갛게 났다.
	#
	# **점 하나로 성질을 지킬 수 없다.** 몇 판을 더 본다.
	for shake in range(1, 4):
		var settled_at := _seconds_until_quiet(_make_crowd_field(0.5, shake))
		assert_gt(settled_at, 0.0, "%d 번 흔든 판이 %.0f 초 안에 안 멎었다" % [shake, _CROWD_LIMIT])
