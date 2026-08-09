class_name ProtoUnitJam
extends RefCounted
## **막힘을 기억하고, 기억이 바뀌면 길을 다시 찾는다.**
##
## 이동 본체(`unit_field.gd`)에서 갈라 둔 이유는 `unit_yield.gd` 와 같다. 본체가 천 줄
## 한계에 닿았고, **이것도 통째로 껐다 켜며 재야 하는 규칙**이기 때문이다.

## 막힘 기억을 다시 보는 주기(프레임).
##
## 매 프레임 보면 그대로 비용이고, 너무 뜸하면 비킨 뒤에도 한참 돌아간다. 3 분의 1 초다.
const _JAM_REVIEW := 20

## 흐름장을 다시 굽는 사이에 두는 최소 간격(프레임).
##
## **막힘이 잦으면 굽기도 잦다.** 한 번이 8 밀리초라도 초당 여러 번이면 그게 다시 프레임
## 문제다. 명령이 여럿이어도 이 간격 안에서는 하나만 굽는다 - 판 전체에 거는 상한이다.
const _REBAKE_GAP := 60

## 막혔다고 표시한 칸을 몇 번의 확인 동안 더 믿어 줄지.
##
## **시간이 아니라 확인 횟수다.** 시간으로 풀면 그 칸이 아직 막혀 있어도 때가 되면 풀리고,
## 그러면 흐름장이 도로 그리로 당긴다 - 의뢰인이 본 "살짝 돌았다가 바로 다시 막힌 길로"가
## 정확히 그 모양이다. 여기서는 **비었는지를 실제로 보고** 비었을 때만 하나씩 깎는다.
## 그래도 한 번에 지우지 않는 이유는 한 프레임 스쳐 비는 것에 속지 않기 위해서다.
const _JAM_FORGET := 3

## 자기 자리에서 이만큼은 떨어져 있어야 "길을 막고 있다"로 친다(감속 반경의 배수).
##
## **도착한 자리에서 기다리는 것은 막힘이 아니다.** 이 조건이 없을 때 열린 방에서도
## 흐름장을 다시 구웠다 - 대형 바깥에 선 유닛이 기다림 상태라는 이유로 막힘으로 잡혔고,
## 돌아갈 곳도 없는 판에서 8 밀리초짜리 굽기가 계속 돌았다. 굽기는 프레임을 먹으므로
## **얻을 것이 없으면 굽지 않는 것이 이득이다.**
const _JAM_AWAY := 1.5

## 멎지는 않았는데 목적지가 안 가까워진 채 이만큼 지나면 **정체**로 친다(프레임).
##
## 사용자가 세 번 짚은 요구다 - **"막히면 막혔다는 걸 직접 안 가보고도 알 수 있는 거 아니야?"**
## 여기가 `HOLDING` 과 `BLOCKED` 만 세고 있었다. 그래서 「안 가보고 안다」가 절반이었다 -
## **정체 유닛(느리게 가는 중)이 선 칸은 기억에 안 남는데, 실제로 가장 오래 걸리는 칸이 거기다.**
##
## 한 번의 확인 주기(`_JAM_REVIEW` 20 프레임)보다 넉넉해야 한 프레임 스친 것에 안 속는다.
## 1.5 초면 줄이 나아가는 판에서는 거의 안 걸리고(앞이 빠질 때마다 시계가 0 으로 돌아간다)
## 정말 맴도는 유닛만 걸린다.
const _JAM_CREEP := 90


## **막힘을 기억하고, 기억이 바뀌면 길을 다시 찾는다.**
##
## 의뢰인이 본 증상이 출발점이다 - "살짝 돌았다가 바로 다시 막힌 길을 탐색하려 한다."
## 걸음 고르기는 몸 하나를 돌아 나가는 국소 판단이라, 돌아 나가는 순간 흐름장이 도로
## 원래 길로 당긴다. **흐름장이 막힘을 모르기 때문이다.** 그래서 알려 준다.
##
## | 무엇 | 어떻게 |
## | --- | --- |
## | 무엇이 막힘인가 | 기다리거나 포기한 유닛이 선 칸 |
## | 기억의 주인 | **명령을 받은 무리.** 유닛마다 구우면 8 밀리초 곱하기 인원이다 |
## | 어떻게 피하나 | 못 가게 막지 않고 **값을 물린다**(§`_JAM_PENALTY`). 길이 하나뿐이면 그리로 간다 |
## | 언제 푸나 | **그 칸이 실제로 비었는지 보고** 비었을 때만. 시간으로 풀면 도로 당겨진다 |
## | 얼마나 자주 굽나 | 판 전체에 상한. `_REBAKE_GAP` 안에는 한 번만 |
static func review(field: ProtoUnitField, frame: int) -> void:
	if frame % _JAM_REVIEW != 0:
		return
	if field.tuning.get_value("repath") < 0.5:
		return
	# **아무도 안 움직이면 길을 다시 찾을 이유가 없다.**
	#
	# 전원이 멎은 뒤에도 굽고 있었고, 그것이 계약 위반을 만들었다. 새 흐름장은 칸마다 방향을
	# 바꾸고, 기다리던 유닛은 그 바뀐 방향으로 조향을 다시 잡아 깨어난다. 깨어난 유닛이
	# 조금 가다 다시 서면 그것이 또 막힘으로 잡혀 다음 굽기를 부른다 - 되먹임이다.
	# 열린 방 40 명에서 멎은 뒤 3 초 동안 9.8 픽셀이 움직였고, **전파와 재계산을 둘 다 켰을
	# 때만** 났다. 어느 한쪽만 켜면 0 이다.
	#
	# 움직이는 유닛이 없으면 잼도 안 바뀐다. 굽는 값을 치를 이유가 없다.
	if field.moving_count() == 0:
		return
	var grid := field.grid
	var count := grid.cols * grid.rows
	var away := field.tuning.get_value("slow_radius") * _JAM_AWAY
	for order in field.orders:
		if order.jam.size() != count:
			order.jam = PackedByteArray()
			order.jam.resize(count)
		# 지금 막혀 선 유닛이 어느 칸에 있는가.
		#
		# **멎은 유닛만 세면 절반이다.** 기다림과 포기에 더해 **정체**도 센다 - 목적지가
		# 안 가까워진 채 `_JAM_CREEP` 프레임을 흘려보낸 유닛이다. 그냥 가는 중인 유닛은
		# 지나가는 중이라 길을 막았다고 할 수 없으므로 그대로 안 센다.
		var stuck := PackedByteArray()
		stuck.resize(count)
		for id in order.member_ids:
			var agent: ProtoUnitAgent = field.agent_of(id)
			if agent == null:
				continue
			var halted := (
				agent.state == ProtoUnitAgent.State.HOLDING
				or agent.state == ProtoUnitAgent.State.BLOCKED
			)
			var creeping := agent.is_moving() and agent.creep_frames >= _JAM_CREEP
			if not halted and not creeping:
				continue
			if agent.position.distance_to(agent.goal) < away:
				continue
			var cell := grid.world_to_cell(agent.position)
			if grid.is_inside(cell):
				stuck[grid.cell_index(cell)] = 1
		var changed := false
		for index in count:
			var before := order.jam[index]
			if stuck[index] == 1:
				order.jam[index] = _JAM_FORGET
			elif before > 0:
				# **비었으니 하나 깎는다.** 시간이 아니라 확인이다.
				order.jam[index] = before - 1
			if (before > 0) != (order.jam[index] > 0):
				changed = true
		if not changed:
			continue
		if frame - order.baked_frame < _REBAKE_GAP:
			continue
		order.baked_frame = frame
		var started := Time.get_ticks_usec()
		order.flow = grid.build_flow_field(
			order.target, order.jam, field.tuning.get_value("jam_cost")
		)
		field.flow_build_usec = Time.get_ticks_usec() - started
		field.flow_build_peak = maxi(field.flow_build_peak, field.flow_build_usec)
		field.rebake_count += 1
		# 한 프레임에 하나만 굽는다. 명령이 여럿이어도 여기서 끊는다.
		return
