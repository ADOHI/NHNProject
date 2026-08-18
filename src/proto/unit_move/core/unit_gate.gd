class_name ProtoUnitGate
extends RefCounted
## **한 칸 문에 차례를 준다.** 문 앞에 선 유닛들에게 없던 것이 차례다.
##
## 설계는 README §28 에 먼저 썼다. 요점 넷.
##
## | 물음 | 답 |
## | --- | --- |
## | 차례가 무엇에 붙나 | **문에.** 명령이 달라도 문은 하나다 |
## | 누가 첫째인가 | **먼저 온 순서.** 한 번 받으면 안 바뀐다. 같은 프레임이면 흐름장 비용으로 가른다 |
## | 기다리는 유닛은 어디 서 있나 | **문에서 들어온 길로 뻗은 줄 자리.** 문 앞에 뭉치면 지금과 같다 |
## | 차례를 놓치면 | **정체 시계로 잃는다.** 시간이 아니다 |
##
## **좁은 목이 없으면 이 규칙은 통째로 안 돈다.** 복도 판정이 열린 곳과 두 칸 문에서 0 칸을
## 잡으므로(§28), **지금 잘 도는 판을 건드릴 수 없다는 것이 규칙이 아니라 구조로 보장된다.**
##
## `gate_goal` 은 `yield_goal` 과 같은 구조다 - 상태로 걸고, 자리에 닿을 때까지 그쪽으로 가고,
## 조건이 풀리면 놓는다. **새 층이 아니라 그 기계를 한 번 더 쓰는 것이다.**

## 문에서 이만큼 안에 있는 유닛을 줄에 세운다(픽셀).
##
## 너무 넓으면 아직 문을 겨냥하지도 않은 유닛까지 줄을 서고, 너무 좁으면 이미 뭉친 뒤에야
## 줄이 선다.
const _GATE_REACH := 640.0

## 줄이 문에서 이만큼까지 뻗는다(픽셀).
##
## **`_GATE_REACH` 와 값이 같지만 뜻이 다르다.** 앞엣것은 「누구를 줄에 세우나」이고
## 이것은 「줄이 얼마나 기나」다. 한 값이 둘을 같이 정하고 있었고, §32 가 그것을
## **"한 값이 두 가지를 정하면 둘을 따로 못 맞춘다"** 로 적어 두었다. 갈릴 날이 오기 전에
## 갈라 둔다 - **지금은 같은 값이라 동작이 한 톨도 안 바뀐다.**
##
## **너무 짧으면 줄이 짧아져 줄 밖 무리가 서 있는 줄을 들이받는다**(`_LINE_LIMIT` 주석).
## 256 일 때 한 칸 문 40 이 25.70 초였고 640 으로 넓히니 23 초 언저리로 내려가면서
## **문 안 맞교차도 스물여덟에서 서른둘까지 늘었다** - 줄이 길수록 양쪽이 덜 부딪힌다.
const _LINE_SPAN := 640.0

## 줄 자리 사이의 간격(몸 반지름의 배수). 2.4 면 몸이 닿지 않고 이어진다.
const _LINE_STEP := 2.4

## 줄 자리에 이만큼 들면 닿은 것으로 본다(픽셀).
const _SPOT_REACHED := 6.0

## 줄을 이만큼까지 세운다. **여기를 짧게 잡은 것이 이 규칙 최대의 버그였다.**
##
## 처음에 열둘로 두고 "그 밖은 그냥 오게 둔다 - 어차피 뒤에서 밀려 온다"고 적었다.
## **정확히 반대였다.** 줄에 든 유닛은 제 자리에 **서 있고** 눌림도 정체도 안 센다.
## 줄 밖의 유닛은 자유롭게 문으로 몰린다. 그러면 **서 있는 줄을 자유로운 무리가 들이받는다** -
## 줄은 비켜 줄 수도 없고(자리로 가는 중이다) 비켜 달라고 할 수도 없다(시계가 안 돈다).
##
## 인원을 한 칸씩 훑어서야 보였다(README §33). 40 에서는 줄 밖이 작아 티가 안 났는데
## **44 와 46 에서 통째로 무너졌다** - 켜면 여덟과 열아홉이 못 넘고, 46 은 아예 끄는 편이
## 나았다. 우리가 넣은 것이 해가 된 유일한 자리였다.
##
## | 인원 | 열둘일 때 | **예순넷일 때** |
## | --- | --- | --- |
## | 40 통과 | 31.22 s (이어밀기 464) | **약 18 초 (323)** |
## | 44 통과 | **못함 (8 명)** (2936) | **약 23 초 (402)** |
## | 46 통과 | **못함 (19 명)** (3639) | **약 30 초 (556)** |
##
## **줄을 세울 거면 다 세워야 한다.** 반만 세우면 안 세운 것보다 나쁘다.
const _LINE_LIMIT := 64

## 앞에서 이만큼은 줄을 안 세우고 그냥 보낸다.
##
## **하나만 보내면 줄이 섰다 갔다 한다.** 첫째가 문을 빠져나갈 동안 둘째는 제 자리에 서서
## 기다리다가, 차례가 오면 그제서야 걷기 시작한다. 그 멈춤과 다시 걷기가 통째로 죽은 시간이라
## 문이 비어 있는 동안 아무도 안 들어간다. 앞의 몇은 이어서 흐르게 둔다 -
## **하나는 문을 지나는 중이고 하나는 문턱에 대기하는 그림**이다.
const _LEAD := 3

## 차례를 받은 유닛이 이만큼 안 나아가면 차례를 잃는다(프레임).
##
## **시간이 아니라 정체 시계다.** 문에 낀 유닛 하나가 줄 전체를 영원히 세우는 것을 막는다 -
## §20 이 겪은 그 모양이다. 2 초면 몸 하나가 문을 지나기에 넉넉하다.
const _TURN_LOST_FRAMES := 120

## 문 차례를 다시 보는 주기(프레임). 매 프레임 다시 고르는 것이 지터의 씨앗이다.
const _REVIEW := 6


## **문마다 줄을 세운다.** 좁은 목이 없으면 곧바로 돌아간다.
static func review(field: ProtoUnitField, frame: int) -> void:
	if frame % _REVIEW != 0:
		return
	var chokes := field.grid.choke_cells()
	if chokes.is_empty():
		return
	if field.tuning.get_value("gate_queue") < 0.5:
		_clear_all(field)
		return
	# **먼저 전부 놓고 다시 앉힌다.**
	#
	# 줄에서 빠진 유닛의 자리를 안 지우면 **없는 자리로 영원히 걸어간다.** 문에서 멀어져
	# 사정권 밖으로 나간 유닛이 줄에서 빠지는데, 앉히는 쪽은 줄에 든 유닛만 훑으므로
	# 그 유닛의 `gate_goal` 이 그대로 남았다. 게다가 줄에 선 유닛은 눌림과 정체 시계를
	# 안 세므로 **어느 그물에도 안 걸린 채 300 픽셀 뒤에서 맴돌았다** - 한 칸 문에서
	# 셋이 그렇게 남았다. 상태를 들고 있는 규칙은 놓는 자리를 반드시 한곳에 모아야 한다.
	for agent in field.agents:
		if agent.gate_id != 0:
			_release(agent)
	for index in chokes:
		_review_gate(field, index)


## 이 문 하나의 줄을 손본다.
static func _review_gate(field: ProtoUnitField, cell_index: int) -> void:
	var grid := field.grid
	var cell := Vector2i(cell_index % grid.cols, cell_index / grid.cols)
	var gate_pos := grid.cell_to_world(cell)
	var gate_id := cell_index + 1

	# **아직 문을 지나야 하는 유닛만 줄에 선다.** 이미 넘은 유닛은 흐름장 비용이 문보다 낮다.
	var waiting: Array[ProtoUnitAgent] = []
	for agent in field.agents:
		if not _wants_gate(field, agent, gate_pos, cell):
			continue
		waiting.append(agent)

	var queue: PackedInt32Array = field.gate_queues.get(gate_id, PackedInt32Array())
	var still := PackedInt32Array()
	var present := {}
	for agent in waiting:
		present[agent.id] = agent
	# **이미 줄에 선 순서를 지킨다.** 먼저 온 순서가 곧 차례이고 한 번 받으면 안 바뀐다.
	for id in queue:
		if present.has(id):
			still.append(id)
			present.erase(id)
	# 새로 온 유닛은 뒤에 붙인다. 같은 프레임에 여럿이면 흐름장 비용으로 가른다 - 난수는 안 쓴다.
	var newcomers: Array[ProtoUnitAgent] = []
	for id: int in present:
		newcomers.append(present[id])
	newcomers.sort_custom(
		func(a: ProtoUnitAgent, b: ProtoUnitAgent) -> bool:
			return a.rank < b.rank if a.rank != b.rank else a.id < b.id
	)
	for agent in newcomers:
		still.append(agent.id)

	# **차례를 잃는다.** 앞선 유닛이 안 나아가면 뒤로 보낸다.
	if still.size() > 1:
		var head: ProtoUnitAgent = field.agent_of(still[0])
		if head != null and head.creep_frames >= _TURN_LOST_FRAMES:
			var rotated := PackedInt32Array()
			for i in range(1, still.size()):
				rotated.append(still[i])
			rotated.append(still[0])
			still = rotated
			field.gate_turns_lost += 1

	field.gate_queues[gate_id] = still
	_place(field, still, gate_pos, cell, gate_id)


## 줄에 선 유닛들을 자리에 앉힌다. **첫째는 그냥 간다.**
static func _place(
	field: ProtoUnitField, queue: PackedInt32Array, gate_pos: Vector2, cell: Vector2i, gate_id: int
) -> void:
	var back := _approach_dir(field, queue, gate_pos, cell)
	for position_index in queue.size():
		var agent: ProtoUnitAgent = field.agent_of(queue[position_index])
		if agent == null:
			continue
		if position_index < _LEAD or position_index >= _LINE_LIMIT or back == Vector2.ZERO:
			_release(agent)
			continue
		# **줄이 판 밖으로 뻗으면 안 된다.**
		#
		# 상한을 예순넷으로 올리자 스물여덟 번째 자리가 문에서 700 픽셀이 됐고, 맞교차판에서
		# 그 자리가 격자 밖으로 나가 **엔진이 죽었다**(signal 11). 상한을 고친 것이 만든
		# 새 길이다 - **값 하나를 키우면 그 값에 기대던 다른 것이 드러난다.**
		#
		# 줄은 사정권 안에서만 뻗는다. 그보다 뒤는 어차피 줄에 설 유닛이 아니다.
		var offset := agent.radius * _LINE_STEP * float(position_index)
		if offset > _LINE_SPAN:
			_release(agent)
			continue
		var spot := gate_pos + back * offset
		if not field.grid.is_inside(field.grid.world_to_cell(spot)):
			_release(agent)
			continue
		if not field.grid.is_circle_free(spot, agent.radius):
			_release(agent)
			continue
		agent.gate_id = gate_id
		agent.gate_goal = spot


## 문으로 들어오는 길의 **반대** 방향. 줄은 그쪽으로 뻗는다.
##
## 흐름장 방향을 뒤집어 쓴다 - 그것이 곧 "유닛들이 들어온 길"이다. 명령이 여럿이면
## 줄에 선 첫 유닛의 명령을 따른다.
static func _approach_dir(
	field: ProtoUnitField, queue: PackedInt32Array, gate_pos: Vector2, cell: Vector2i
) -> Vector2:
	for id in queue:
		var agent: ProtoUnitAgent = field.agent_of(id)
		if agent == null:
			continue
		var order: ProtoUnitField.MoveOrder = field.order_by_id(agent.order_id)
		if order == null:
			continue
		var forward := order.flow.direction_at(gate_pos, agent.radius)
		if forward != Vector2.ZERO:
			return -forward.normalized()
		# 흐름장이 답을 안 주면 몸이 서 있는 쪽으로 뻗는다.
		var away := agent.position - field.grid.cell_to_world(cell)
		if away.length_squared() > 1.0:
			return away.normalized()
	return Vector2.ZERO


## 이 유닛이 이 문을 아직 지나야 하는가.
static func _wants_gate(
	field: ProtoUnitField, agent: ProtoUnitAgent, gate_pos: Vector2, cell: Vector2i
) -> bool:
	if agent.state != ProtoUnitAgent.State.MOVING and agent.state != ProtoUnitAgent.State.HOLDING:
		return false
	if agent.is_yielding():
		return false
	if agent.position.distance_to(gate_pos) > _GATE_REACH:
		return false
	var order: ProtoUnitField.MoveOrder = field.order_by_id(agent.order_id)
	if order == null:
		return false
	# 문보다 비싼 자리에 서 있으면 아직 문 이쪽이다. 넘은 유닛은 문보다 싸다.
	var mine := order.flow.cost_at(field.grid.world_to_cell(agent.position))
	var gate_cost := order.flow.cost_at(cell)
	if mine >= FlowField.UNREACHABLE * 0.5:
		return false
	return mine > gate_cost


## 줄에서 놓는다. 자기 목적지로 다시 간다.
static func _release(agent: ProtoUnitAgent) -> void:
	agent.gate_id = 0
	agent.gate_goal = Vector2.ZERO


static func _clear_all(field: ProtoUnitField) -> void:
	field.gate_queues.clear()
	for agent in field.agents:
		_release(agent)


## 줄 자리에 닿았는가. 닿았으면 그 자리에 선다.
static func at_spot(agent: ProtoUnitAgent) -> bool:
	return agent.position.distance_to(agent.gate_goal) <= _SPOT_REACHED
