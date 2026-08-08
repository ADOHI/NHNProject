class_name ProtoUnitPush
extends RefCounted
## **비켜라를 물려준다.** 막힌 유닛이 앞을 막은 유닛에게, 그 유닛이 또 앞의 유닛에게.
##
## 의뢰인의 발상이 그대로 출발점이다 - "막히면 해당 사람만 비키려고 하는 게 아니라,
## 비키다가 또 막혀 있으면 계속 비키라고 전파하면 결국 교착이 풀리지 않을까."
##
## `unit_yield.gd` 의 비켜주기는 **바로 앞의 한 쌍만 본다.** 문 앞에서 굳는 것은 비킬 자리가
## 없어서인데, 그 자리를 만들어 줄 수 있는 것은 **뒤가 아니라 앞의 유닛**이고 아무도 걔한테
## 말을 안 걸었다. 여기서 건다.
##
## PIBT(Okumura 외, IJCAI 2019)의 **우선순위 상속**이 같은 발상이다. 다만 그쪽의 완전성
## 보장은 우리에게 무효다 - 격자 점유 · 같은 몸집 · 동기 이산 시간 · 한 걸음 이동이라는
## 전제가 우리 판에서 넷 다 깨진다. **발상만 가져오고 보장은 쫓지 않는다.**
##
## | 지킨 것 | 왜 |
## | --- | --- |
## | **깊이 상한** | 사슬이 길면 한 프레임에 판 전체를 훑게 된다 |
## | **방문 표시** | 고리에 걸리면 영원히 돈다. 걸리면 억지로 풀지 않고 세기만 한다 |
## | **`HOLDING` 이 확정된 순간에만** | 매 프레임 다시 고르는 것이 지터의 씨앗이다(§7 · §10) |
##
## 간선은 `blocker_id` 를 그대로 쓴다. 빈 거리를 재는 훑기가 이미 "나를 가장 늦추는 이웃"을
## 고르고 있어서 **추가 훑기가 0 이다.**

## 사슬을 이만큼까지만 따라간다.
##
## 여덟이면 몸 지름으로 200 픽셀 남짓이라 좁은 문 앞 인파를 가로지르기에 넉넉하다.
## 열여섯까지 늘려도 되지만 그만큼 한 번의 값이 커진다.
const _MAX_DEPTH := 8

## 비켜설 자리를 만들 때 진로 밖으로 이만큼 더 밀어낸다(픽셀).
const _MARGIN := 1.5

## 한 번에 옆으로 옮기는 최대 거리(픽셀).
const _NUDGE := 14.0

## 한 번 비킬 때 **최소한 이만큼은** 옮긴다(몸 반지름의 배수).
##
## **이 한 줄이 「성공 한 번에 0.6 픽셀」의 정체였다.** 예전에는 "뒤에 선 유닛의 중심선에서
## 벗어날 만큼"만 밀었는데(`touch - lateral`), 빽빽한 잼에서는 두 몸이 이미 거의 나란해서
## 그 값이 1 픽셀 언저리다. 계기는 "옮겼다"고 하는데 사람 눈에는 아무 일도 안 일어난다.
##
## 몸이 실제로 길에서 빠져나가려면 중심선을 스치는 것으로는 모자라고 **몸 반지름 정도는**
## 움직여야 한다. 0.35 · 0.6 · 1.0 을 재고 골랐다 - 크게 잡을수록 문은 빨리 뚫리지만
## 옆걸음이 커져 걸음꺾임이 오른다(§15 에서 D 를 잘못 걸었을 때 겪은 것과 같은 저울이다).
const _MIN_NUDGE := 0.6

## 옆자리를 막은 상대로 사슬을 이어 갈 때의 깊이 상한.
##
## 진로 사슬(`_MAX_DEPTH`)과 따로 둔다. 이쪽은 **한 자리를 비우려고 옆으로 줄줄이 미는 것**이라
## 깊어지면 그만큼 여러 유닛이 한 프레임에 옮겨진다. 셋이면 몸 셋 너비다.
const _RELAY_DEPTH := 3


## 막힌 유닛에서 시작해 사슬을 따라가며 비키라고 말한다. 옮긴 유닛 수를 돌려준다.
static func propagate(field: ProtoUnitField, agent: ProtoUnitAgent) -> int:
	if field.tuning.get_value("propagate") < 0.5:
		return 0
	# **자기 자리 근처에서 기다리는 것은 전파할 일이 아니다.**
	#
	# 이 조건이 없을 때 열린 방 100 명이 아예 안 멎었다. 대형 바깥에서 기다리던 유닛이
	# 앞줄에 비키라고 말하고, 밀린 유닛이 깨어나고, 다시 기다리고를 끝없이 되풀이했다.
	# 돌아갈 곳도 없는 판에서 밀어 봐야 얻을 것이 없다 - 막힘 기억이 같은 이유로 같은
	# 조건을 쓴다().
	if agent.position.distance_to(agent.goal) < field.tuning.get_value("slow_radius") * 1.5:
		return 0
	var scratch: Array[ProtoUnitAgent] = []
	var chain: Array[int] = [agent.id]
	var current := agent
	var moved := 0
	var depth := 0
	while depth < _MAX_DEPTH:
		var heading := current.steer_dir
		if heading == Vector2.ZERO:
			break
		var blocker := field.agent_of(current.blocker_id)
		if blocker == null:
			break
		var seen_at := chain.find(blocker.id)
		if seen_at >= 0:
			var length := chain.size() - seen_at
			field.propagate_cycles += 1
			field.propagate_cycle_len_total += length
			if length == 2:
				field.propagate_cycle_len_two += 1
			break
		if blocker.rank < current.rank:
			field.propagate_forward += 1
		else:
			field.propagate_backward += 1
		chain.append(blocker.id)
		if _step_aside(field, current, blocker, scratch, chain):
			moved += 1
		current = blocker
		depth += 1
	if depth >= _MAX_DEPTH:
		field.propagate_cap_hits += 1
	field.propagate_depth_total += depth
	return moved


## 앞선 유닛을 진로 밖으로 밀어낸다. 자리가 없으면 **그 자리를 막은 놈에게 이어 말한다.**
##
## 미는 방향은 앞선 유닛의 뜻이 아니라 **뒤에 선 유닛의 진로**다. 뒤가 가려는 길에서
## 비켜서게 하는 것이지 앞을 어디론가 보내는 것이 아니다. 그래서 **진행 방향 성분이 0 이고**,
## 밀린 유닛은 목적지도 명령도 그대로 들고 있다.
static func _step_aside(
	field: ProtoUnitField,
	behind: ProtoUnitAgent,
	blocker: ProtoUnitAgent,
	scratch: Array[ProtoUnitAgent],
	chain: Array[int]
) -> bool:
	var heading := behind.steer_dir
	var offset := blocker.position - behind.position
	var along := offset.dot(heading)
	if along <= 0.0:
		return false
	var side := offset - heading * along
	var lateral := side.length()
	var touch := behind.radius + blocker.radius
	if lateral >= touch:
		return false
	var away := side / lateral if lateral > 0.001 else Vector2(-heading.y, heading.x)
	# **몸이 실제로 빠져나갈 만큼 민다.** 중심선을 스치는 것으로는 눈에 안 보인다.
	var want := maxf(touch - lateral + _MARGIN, blocker.radius * _MIN_NUDGE)
	# **자리를 상태로 건다.** 한 프레임 밀어 놓는 것만으로는 다음 프레임에 지워진다.
	ProtoUnitYield.begin(field, blocker, blocker.position + away * minf(want, _NUDGE), behind.id)
	var moved := _shove(field, blocker, away, minf(want, _NUDGE), scratch, chain, 0)
	if moved <= 0.0:
		field.propagate_blocked += 1
		return false
	behind.chain_to = blocker.id
	behind.chain_ago = 0
	behind.chain_kind = 0
	return true


## 이 유닛을 그 방향으로 민다. **자리가 없으면 그 자리를 막은 놈을 먼저 민다.**
##
## 진단에서 가장 큰 숫자가 이것이었다 - **시도의 54 퍼센트가 자리가 없어 실패**했다.
## 비켜라는 전해졌는데 그 유닛도 갇혀 있었고, **그 유닛의 옆자리를 차지한 놈에게는 아무도
## 말을 안 걸었다.** `blocker_id` 는 "내 진로를 막은 놈"만 알고 "내가 비켜설 자리를 막은 놈"은
## 모른다 - 그 둘은 다른 유닛이다.
##
## 여기서 그 둘째 간선을 탄다. 방문 표시(`chain`)를 **두 간선이 함께 쓴다** - 섞어 타면
## 고리가 늘 수 있어서, 한쪽에서 이미 본 유닛은 다른 쪽에서도 안 본다.
static func _shove(
	field: ProtoUnitField,
	agent: ProtoUnitAgent,
	away: Vector2,
	want: float,
	scratch: Array[ProtoUnitAgent],
	chain: Array[int],
	depth: int
) -> float:
	var room := ProtoUnitYield.yield_room(field, agent, away, want, scratch)
	if room < want and depth < _RELAY_DEPTH:
		var crowder := _crowder(field, agent, away, want, scratch, chain)
		if crowder != null:
			chain.append(crowder.id)
			field.propagate_relays += 1
			if _shove(field, crowder, away, want - room, scratch, chain, depth + 1) > 0.0:
				agent.chain_to = crowder.id
				agent.chain_ago = 0
				agent.chain_kind = 1
				# 앞의 유닛이 비켰으니 자리가 늘었다. 다시 재서 그만큼 간다.
				room = ProtoUnitYield.yield_room(field, agent, away, want, scratch)
	if room <= 0.0:
		return 0.0
	agent.position += away * room
	agent.yield_shift += away * room
	agent.pushed_ago = 0
	field.settled_push_total += room
	field.propagate_distance += room
	# **자기 자리에 다 온 유닛은 깨우지 않는다.**
	#
	# 깨우면 조금 가다 다시 서고, 그 되풀이가 도착 후 진동으로 남는다. 실제로 이 줄이
	# 없을 때 열린 방에서 전원이 멎은 뒤에도 7 픽셀이 움직였다 - 지켜야 할 성질이 0 이다.
	# 길에서 비켜서는 것은 그대로 하되, 다시 갈 이유는 자기 자리가 먼 유닛에게만 있다.
	if (
		agent.state == ProtoUnitAgent.State.HOLDING
		and agent.position.distance_to(agent.goal) > field.tuning.get_value("slow_radius")
	):
		agent.resume()
	return room


## 그 방향에서 내 자리를 막고 있는 유닛. 이미 사슬에 든 유닛은 고르지 않는다.
static func _crowder(
	field: ProtoUnitField,
	agent: ProtoUnitAgent,
	away: Vector2,
	want: float,
	scratch: Array[ProtoUnitAgent],
	chain: Array[int]
) -> ProtoUnitAgent:
	field.collect_neighbors(agent, scratch)
	var nearest: ProtoUnitAgent = null
	var closest := INF
	for other in scratch:
		if chain.has(other.id):
			continue
		var offset := other.position - agent.position
		var along := offset.dot(away)
		if along <= 0.0:
			continue
		var minimum := agent.radius + other.radius
		var distance := offset.length()
		var perpendicular := distance * distance - along * along
		if perpendicular >= minimum * minimum:
			continue
		var reach := maxf(along - sqrt(minimum * minimum - perpendicular), 0.0)
		if reach > want or reach >= closest:
			continue
		closest = reach
		nearest = other
	return nearest
