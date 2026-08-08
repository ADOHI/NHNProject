class_name ProtoUnitYield
extends RefCounted
## **비켜주기.** 전진 중인 유닛의 진로에서 남을 옆으로 비켜서게 한다.
##
## 이동 본체(`unit_field.gd`)에서 갈라 둔 이유는 둘이다. 하나는 본체가 천 줄 한계에 닿았고,
## 다른 하나는 **이것이 언제든 통째로 꺼낼 수 있어야 하는 규칙**이기 때문이다. 밀기는 이 판에서
## 두 번 들어왔다 나갔다 했다. 한 파일에 모여 있으면 껐다 켜며 재는 데 값이 덜 든다.

## 비켜주기 - 미는 쪽이 되려면 실제로 이만큼은 나아가고 있어야 한다(최대 속도 배수).
##
## **이 한 줄이 비대칭을 지킨다.** 상태(`MOVING`)로 물으면 잼 한가운데에서 한 뼘도 못 가는
## 유닛도 미는 쪽이 되고, 그것들이 서로 밀기 시작하면 곧바로 대칭 스프링으로 되돌아간다.
## 그래서 뜻이 아니라 **실제로 옮겨 간 거리**로 묻는다.
const _YIELD_MOVER := 0.25

## 비켜주기 - 진로를 이만큼 앞까지 살핀다(몸이 닿는 거리에 더하는 픽셀).
##
## 넓게 잡으면 멀리 있는 유닛까지 미리 비켜서서 대열이 부풀고, 0 으로 잡으면 몸이 닿은
## 뒤에야 비키기 시작해 이미 늦다.
const _YIELD_REACH := 14.0

## 비켜주기 - 한 프레임에 옆으로 옮기는 최대 거리(초당 픽셀).
##
## **이 값 하나가 통과와 꺾임을 맞바꾼다.** 세 값을 재고 골랐다.
##
## | 초당 픽셀 | 좁은통로 40 통과 | 좁은통로 100 못 넘은 인원 | 꺾임 100 | 열린곳 100 꺾임 | 이동 계산 100 |
## | --- | --- | --- | --- | --- | --- |
## | 140 | 못함 (18 명) | **46 명** | **495** | **263** | **5.19 ms** |
## | 220 | 못함 (12 명) | 76 명 | 514 | 271 | 2.10 ms |
## | 300 | **33.37 s 전원** | 55 명 | 683 | 291 | 7.47 ms |
##
## 300 이 40 명 판을 유일하게 뚫지만 이동 계산이 7.47 밀리초로 웹 예산을 넘긴다. 140 은
## 성능 한도를 지키면서 꺾임이 가장 낮고 100 명 판에서 못 넘은 인원도 가장 적다.
## **어느 값도 100 명을 뚫지 못한다** - 이 값을 돌려서 될 문제가 아니라는 뜻이고,
## 그것이 이번 측정의 결론이다.
const _YIELD_RATE := 140.0

## 비켜주기 - 진로 밖으로 이만큼 더 밀어낸다(픽셀). 딱 맞게 비켜서면 곧바로 다시 걸린다.
const _YIELD_MARGIN := 1.5

## 양보가 살아남았는지 이만큼 뒤에 견준다(프레임). 3 분의 1 초다.
const _YIELD_WATCH := 20


## **비켜주기.** 전진 중인 유닛의 진로에서 남을 옆으로 비켜서게 한다.
##
## §11 에서 힘을 전부 걷어냈더니 좁은 문이 무너졌다 - 백 명 중 여든셋이 못 넘었다.
## 밀기가 좁은 통로 통과의 **수단**이었던 것이다. 그런데 밀기가 지터를 만든 것도 사실이다.
## 둘은 모순이 아니다. **미느냐 마느냐가 아니라 어떻게 미느냐**의 문제였다.
##
## 예전 것은 **대칭**이었다. A 가 B 를 밀면 B 도 A 를 밀었고, 그 되튀김이 곧 진동이다.
## 게다가 속도에 힘으로 얹어서 지나쳤다 되돌아왔다. 여기서는 넷을 바꾼다.
##
## | 규칙 | 왜 |
## | --- | --- |
## | **전진 중인 유닛만 민다** (`_is_advancing`) | 잼에 낀 유닛끼리 밀면 곧바로 대칭이다 |
## | **둘 다 전진 중이면 안 민다** | 대칭이 생길 마지막 구멍을 막는다 |
## | **위치로 민다. 속도는 안 건드린다** | 힘으로 밀면 지나쳐서 반대로 겹치고 그게 진동이다 |
## | **진행 방향의 수직으로만 민다** | 진행 방향으로 밀면 그게 "밀고 나아가기"다 |
##
## 비켜준 유닛은 **자기 목적지를 잃지 않는다.** 옆으로 물러났을 뿐이라 상태도 명령도 그대로다.
##
## **겹친 뒤 떼어 놓는 것이 아니라 닿기 전에 비켜서게 한다.** 예전 `_resolve_overlaps` 는
## 겹침이 있어야 일을 했고, 겹침이 있으려면 몸이 파고들어야 했다. 여기서는 진로 안에 들어온
## 순간 옆으로 밀어내므로 몸이 닿을 일 자체가 줄고, 그래도 안 열리면 `_room` 이 막는다 -
## **비켜주기는 길을 열어 줄 뿐이고, 안 열리면 못 간다.**
static func apply(field: ProtoUnitField, delta: float) -> void:
	if delta <= 0.0:
		return
	var reach := _YIELD_RATE * delta
	var scratch: Array[ProtoUnitAgent] = []
	# 비켜설 자리를 볼 때 쓸 목록. **한 번만 만들어 돌려 쓴다** - 쌍마다 새로 만들면
	# 잼 한가운데에서 프레임마다 배열이 수백 개씩 생겼다 사라진다.
	var bystanders: Array[ProtoUnitAgent] = []
	for agent in field.agents:
		if not _is_advancing(field, agent):
			continue
		var heading := agent.advance.normalized()
		field.collect_neighbors(agent, scratch)
		for other in scratch:
			if not _outranks(agent, other, field):
				continue
			var offset := other.position - agent.position
			var along := offset.dot(heading)
			var touch := agent.radius + other.radius
			if along <= 0.0 or along > touch + _YIELD_REACH:
				continue
			var side := offset - heading * along
			var lateral := side.length()
			if lateral >= touch:
				continue
			# 진로 한가운데 정확히 서 있으면 어느 쪽으로 비킬지 고를 수가 없다.
			# **늘 같은 손으로 고정한다** - 매번 다시 고르면 그 고름이 곧 좌우 왕복이다.
			var away := side / lateral if lateral > 0.001 else Vector2(-heading.y, heading.x)
			var want := minf(touch - lateral + _YIELD_MARGIN, reach)
			var room := yield_room(field, other, away, want, bystanders)
			if room <= 0.0:
				continue
			other.position += away * room
			other.yield_shift += away * room
			# **비켜준 거리를 튕김 계기에 넣지 않는다.** 튕김은 "뜻 없이 위치가 뛰었다"를
			# 재는 값이고, 비켜주기는 뜻이 있는 이동이다. 섞으면 지형 보정이 만든 진짜 튐이
			# 비켜준 거리에 묻혀 안 보인다.
			field.settled_push_total += room


## 내가 저쪽에게 비키라고 할 수 있는가. **전순서라 양쪽이 동시에 참일 수 없다.**
##
## 예전에는 "둘 다 전진 중이면 서로 안 민다"로 대칭을 피했다. 대칭은 확실히 없어졌지만
## **둘 다 가는 중일 때 아무도 안 비켰고**, 그래서 문 앞에서 굳었다. 비대칭을 지키면서
## 비키게 하려면 **누가 먼저인지 정하면 된다.**
##
## | 상대 | 판정 |
## | --- | --- |
## | 전진 중이 아니다 | 내가 앞선다. 서 있는 것은 길을 비켜 줘야 한다 |
## | 같은 명령을 받았다 | **흐름장 비용이 낮은 쪽이 앞선다** - 문에 가까운 쪽이 먼저 나간다 |
## | 다른 명령을 받았다 | 비용을 견줄 수 없다. **유닛 번호**로 가른다 |
##
## 다른 명령끼리 비용을 못 견주는 이유는 흐름장이 서로 다르기 때문이다. 마주 오는 두 무리는
## 각자의 목적지까지의 비용을 들고 있어서 크기를 비교해도 뜻이 없다. 그래서 번호로 가른다 -
## **난수를 쓰지 않는다.** 같은 판을 다시 굴리면 같은 결과가 나와야 재어서 고칠 수 있다.
static func _outranks(agent: ProtoUnitAgent, other: ProtoUnitAgent, field: ProtoUnitField) -> bool:
	if not _is_advancing(field, other):
		return true
	# **가는 유닛끼리는 정말 이 상대에게 막혔을 때만 순위를 따진다.**
	#
	# 처음에는 진로에 들기만 하면 순위로 밀게 했더니 옆걸음이 세 배 반으로 뛰고(17 -> 60 px)
	# 좁은 문 40 명이 전원 통과에서 열 명 낙오로 되돌아갔다. 스쳐 지나가는 상대까지 계속
	# 밀어 대면서 줄이 흐트러진 것이다. 순위는 **길을 다투는 자리에서만** 쓴다.
	if agent.blocker_id != other.id:
		return false
	if agent.order_id == other.order_id:
		return agent.rank < other.rank
	return agent.id < other.id


## 전진 중인가. **상태가 아니라 실제로 옮겨 간 거리로 묻는다.**
static func _is_advancing(field: ProtoUnitField, agent: ProtoUnitAgent) -> bool:
	if not agent.is_moving():
		return false
	var floor_speed := field.tuning.get_value("max_speed") * _YIELD_MOVER
	return agent.advance.length_squared() > floor_speed * floor_speed


## 비켜설 자리가 있는가. 벽과 다른 몸에 막히는 만큼 깎는다.
##
## **막히면 안 비킨다.** 그러면 미는 쪽이 못 가고 그 자리에 선다 - 한 칸 폭 복도에서
## 앞을 막고 선 아군을 지나갈 수 없는 것이 이 때문이고, 그것이 지켜야 할 성질이다.
static func yield_room(
	field: ProtoUnitField,
	agent: ProtoUnitAgent,
	direction: Vector2,
	want: float,
	bystanders: Array[ProtoUnitAgent]
) -> float:
	field.collect_neighbors(agent, bystanders)
	var limit := want
	for other in bystanders:
		var offset := other.position - agent.position
		var along := offset.dot(direction)
		if along <= 0.0:
			continue
		var minimum := agent.radius + other.radius
		var distance := offset.length()
		if distance < minimum:
			return 0.0
		var perpendicular := distance * distance - along * along
		if perpendicular >= minimum * minimum:
			continue
		limit = minf(limit, maxf(along - sqrt(minimum * minimum - perpendicular), 0.0))
	if limit <= 0.0:
		return 0.0
	if not field.grid.is_circle_free(agent.position + direction * limit, agent.radius):
		return 0.0
	return limit


## **양보가 살아남는지 지켜본다.** 밀린 그 순간의 자리를 적어 두고, 얼마 뒤에 견준다.
##
## 의뢰인의 물음이 출발점이다 - "비키라고 명령 가도 잠깐 비키려고 하다가 다음 스케줄에서
## 다시 목적지로 가려고 해서 병목 생길 수 있음."
##
## 맞다면 지금까지의 증상이 한 번에 설명된다. 밀어 놓아도 순수 변위가 0 에 가까우면
## 아무 일도 안 일어난 것과 같고, 계기만 "옮겼다"고 말한다.
static func watch(field: ProtoUnitField, frame: int) -> void:
	for agent in field.agents:
		if agent.yield_mark_frame >= 0 and frame - agent.yield_mark_frame >= _YIELD_WATCH:
			field.yield_push_sum += agent.yield_mark_push
			var shift := agent.position - agent.yield_mark_pos
			field.yield_net_sum += shift.dot(agent.yield_mark_dir)
			field.yield_watch_count += 1
			agent.yield_mark_frame = -1
			continue
		# 아직 지켜보는 중이 아니고 이번에 밀렸다면 그 자리를 적어 둔다.
		if agent.yield_mark_frame < 0 and agent.yield_shift.length_squared() > 0.01:
			agent.yield_mark_pos = agent.position - agent.yield_shift
			agent.yield_mark_push = agent.yield_shift.length()
			agent.yield_mark_dir = agent.yield_shift.normalized()
			agent.yield_mark_frame = frame
