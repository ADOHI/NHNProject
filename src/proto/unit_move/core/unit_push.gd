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

## 뒤로 물러나라를 물려줄 깊이 상한.
##
## 줄이 길수록 여유는 줄 끝에 있다. 여섯이면 몸 여섯 너비 남짓이라 좁은 문 앞 줄의
## 상당 부분을 훑는다. 더 길게 잡으면 한 프레임에 옮겨지는 유닛이 그만큼 늘어난다.
const _RECOIL_DEPTH := 6

## 한 번에 뒤로 물러나는 최대 거리(몸 반지름의 배수).
##
## 옆걸음을 몸 반지름의 0.6 배로 키운 뒤에야 사람 눈에 보였다(0.6 px -> 4.6 px).
## 물러나기도 같은 크기여야 보인다.
const _RECOIL_STEP := 0.6

## 물러난 자리가 이만큼은 트여 있어야 물러날 값이 있다(벽 거리, 칸).
##
## **조건이 정확히 반대로 걸려 있었다.** 처음에는 "옆이 막혔으니 뒤로"였는데,
## **옆이 막힌 곳이야말로 뒤로 가도 길에서 못 빠지는 곳**이다. 한 칸 폭 복도에서 물러나면
## 줄 전체가 문에서 멀어질 뿐 길은 그대로 막혀 있다. 한 칸 문에서 못 넘는 인원이
## 14 명에서 28 명으로 두 배가 된 것이 그 대가였다.
##
## **방향이 아니라 결과로 판정한다** - "뒤로 가면 길에서 빠지는가". 벽 거리는 지형당 한 번
## 구워 둔 값이라(`nav_grid.gd`) 조회가 배열 읽기 한 번이고, 두 칸이면 몸이 옆으로 빠질
## 폭이 실제로 있다는 뜻이다.
const _RECOIL_MIN_CLEAR := 2

## 한 번의 전파가 건드릴 수 있는 유닛 수의 상한. **옆 사슬과 뒤 사슬을 합쳐서 센다.**
##
## 깊이 상한을 간선마다 따로 두었더니 곱해졌다 - 앞으로 8, 옆으로 3, 뒤로 6 이면 한 번에
## 백 명 넘게 훑을 수 있다. 좁은 통로 100 에서 평균 깊이가 4.1 로 뛰고 최악 프레임이
## 22 밀리초가 된 것이 그 결과다. **예산은 하나로 두고 둘이 나눠 쓴다.**
const _CHAIN_BUDGET := 10

## 마주 오는 상대로 볼 각도의 코사인. -0.5 는 대략 120 도보다 더 마주 본 것이다.
##
## **맞교차에서 물러나기가 한 번도 안 걸렸다.** 물러나기가 "옆으로 비켜서기가 실패했을 때"만
## 불렸는데, 열린 곳에서는 옆이 늘 트여 비켜서기가 성공하고 그러면 물러나기까지 오지 않는다.
## 그런데 **마주 오는 둘에게는 물러나기가 유일한 해법이다** - 하나가 넓은 곳까지 물러나
## 길을 내주는 것 말고 방법이 없다. 그래서 마주 보고 있으면 옆과 함께 뒤도 본다.
const _FACING_COS := -0.5


## **뒤로 물러나라를 뒤에 선 유닛들에게 물려준다.**
##
## 의뢰인의 지적이 출발점이다 - "전파받으면 뒤로 물러나야 하는데 안 물러나잖아."
##
## 지금까지 전파는 **옆으로만** 비키게 했다. 그런데 **좁은 통로에서 옆은 벽이다.**
## 비킬 자리가 구조적으로 없어서 시도의 28 퍼센트가 그대로 실패했고, 한 칸 문에서
## 스무 명이 못 넘었다. 남은 실패가 전부 여기서 나왔다.
##
## **물러나는 것은 밀치기가 아니다.** 금지된 것은 남을 밀쳐서 **전진하는** 것이고,
## 물러남은 전진의 반대다. 계약은 그대로 성립한다 - 미는 쪽은 뒤의 유닛이 물러나 준
## 만큼만 앞이 트이므로 밀어서 나아가는 것이 아니고, 되밀지도 않는다.
##
## 간선은 `blocker_id` 의 **반대 방향**이다. "나를 막은 놈"이 아니라 **"내가 막고 있는 놈"**을
## 찾는다. 이웃을 훑으며 `blocker_id` 가 나를 가리키는 유닛을 고르면 되므로 추가 훑기가 없다.
##
## 그림은 이렇다 - 앞이 못 간다 → 뒤에 붙은 유닛에게 물러나라가 간다 → 그 유닛도 뒤가
## 막혔으면 다시 뒤로 → **줄 끝에서 누군가 물러날 자리가 있으면 그 여유가 앞으로 전달된다.**
## 줄 전체가 한 걸음씩 뒤로 숨을 쉬고, 그 틈으로 앞이 움직인다.
static func recoil(
	field: ProtoUnitField,
	agent: ProtoUnitAgent,
	scratch: Array[ProtoUnitAgent],
	chain: Array[int],
	depth: int
) -> float:
	if depth >= _RECOIL_DEPTH or chain.size() >= _CHAIN_BUDGET:
		return 0.0
	var follower := _follower(field, agent, scratch, chain)
	if follower == null:
		return 0.0
	chain.append(follower.id)
	# 물러나는 방향은 **그 유닛이 가려던 쪽의 반대**다. 남이 정해 준 방향이 아니라
	# 자기가 온 길로 되돌아가는 것이라, 몸이 이미 지나온 자리라서 대개 비어 있다.
	var back := -follower.steer_dir
	if back == Vector2.ZERO:
		return 0.0
	var want := follower.radius * _RECOIL_STEP
	# **물러나서 길에서 빠질 수 있는 곳인가.** 아니면 물러나 봐야 줄만 뒤로 밀린다.
	var landing := field.grid.world_to_cell(follower.position + back * want)
	if field.grid.clearance_at(landing) < _RECOIL_MIN_CLEAR:
		field.propagate_recoil_skips += 1
		return 0.0
	# **물러남도 상태로 건다.** 한 프레임짜리 변위로 두면 잼에서 절반이 지워진다는 것을
	# 이미 쟀다. 지속이 먼저 들어가 있어야 물러나기가 제 효과를 낸다.
	ProtoUnitYield.begin(field, follower, follower.position + back * want, agent.id)
	var room := ProtoUnitYield.yield_room(field, follower, back, want, scratch)
	if room < want:
		# 나도 뒤가 막혔다. **더 뒤에 물러나라고 전한다.**
		if recoil(field, follower, scratch, chain, depth + 1) > 0.0:
			room = ProtoUnitYield.yield_room(field, follower, back, want, scratch)
	if room <= 0.0:
		return 0.0
	follower.position += back * room
	follower.yield_shift += back * room
	follower.pushed_ago = 0
	agent.chain_to = follower.id
	agent.chain_ago = 0
	agent.chain_kind = 2
	field.settled_push_total += room
	field.propagate_distance += room
	field.propagate_recoils += 1
	return room


## 나를 막힌 것으로 지목한 뒤의 유닛. **`blocker_id` 의 반대 간선이다.**
static func _follower(
	field: ProtoUnitField, agent: ProtoUnitAgent, scratch: Array[ProtoUnitAgent], chain: Array[int]
) -> ProtoUnitAgent:
	field.collect_neighbors(agent, scratch)
	var nearest: ProtoUnitAgent = null
	var closest := INF
	for other in scratch:
		if other.blocker_id != agent.id or chain.has(other.id):
			continue
		var distance := other.position.distance_squared_to(agent.position)
		if distance < closest:
			closest = distance
			nearest = other
	return nearest


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
	while depth < _MAX_DEPTH and chain.size() < _CHAIN_BUDGET:
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
		# **옆이 막혔다. 그러면 뒤로 물러나라고 전한다.**
		#
		# 좁은 통로에서 옆은 벽이라 여기까지 오는 경우가 시도의 28 퍼센트였다. 옆이
		# 열려 있으면 옆이 낫다 - 진행 방향을 잃지 않기 때문이다. 그래서 **옆을 먼저 보고
		# 막혔을 때만 뒤를 본다.**
		field.propagate_blocked += 1
		return recoil(field, blocker, scratch, chain, 0) > 0.0
	if heading.dot(blocker.steer_dir) <= _FACING_COS:
		# **마주 오는 상대는 옆으로 비켜도 다시 온다.** 옆과 함께 뒤도 본다.
		recoil(field, blocker, scratch, chain, 0)
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
	if room < want and depth < _RELAY_DEPTH and chain.size() < _CHAIN_BUDGET:
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
