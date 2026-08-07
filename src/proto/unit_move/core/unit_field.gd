class_name ProtoUnitField
extends RefCounted
## 방 하나 안의 유닛 전부와 그들의 이동. **이 레인의 본체다.**
##
## 조작감이 갈리는 네 지점을 여기서 처리한다.
##
## | 지점 | 여기서의 처리 |
## | --- | --- |
## | 뭉침 | 대형 자리 배정(각자 다른 목표) + 분리력 + 옆으로 비껴가기 + 위치 겹침 해소 |
## | 도착 | 감속 반경 · 도착 반경 · 겹침 해소 사각지대 · 못 들어가면 포기 |
## | 반응 | 가속과 회전 제한만으로 지연을 만든다. 명령 처리 자체는 그 프레임에 끝낸다 |
## | 대형 | 명령마다 남은 거리를 비교해 앞선 유닛의 속도를 깎는다 |
##
## 노드에 의존하지 않는다. 화면은 이 상태를 읽어 그리기만 한다.


## 이동 명령 한 건. 흐름장과 대형 자리를 명령 단위로 들고 있다가 소속 유닛이 모두 멎으면 사라진다.
class MoveOrder:
	var id: int
	var target: Vector2
	var flow: ProtoFlowField
	var slots := PackedVector2Array()
	var member_ids := PackedInt32Array()

	## 명령 지점 표시를 언제까지 그릴지. 화면 전용이라 시뮬레이션은 보지 않는다.
	var age := 0.0


## 이동 명령이 나갔다. 화면이 명령 지점 표시를 띄운다.
signal order_issued(target: Vector2)

## 목적지가 보이는지 다시 확인하는 주기(초). 매 프레임 확인하면 유닛 수만큼 광선을 쏘게 된다.
##
## 유닛마다 첫 확인 시점을 어긋나게 두는 것이 주기 자체보다 중요하다. 전원이 같은 프레임에
## 확인하면 평균은 싸도 그 프레임만 몇 배로 튀고, 사람은 평균이 아니라 그 튐을 느낀다.
const _SIGHT_INTERVAL := 0.2

## 대형 유지가 최대로 걸렸을 때 앞선 유닛이 낼 수 있는 최소 속도 배수.
## 0 으로 두면 선두가 완전히 멈춰 서서 대열이 굳는다.
const _MIN_PACE := 0.3

## 포기 시간의 몇 배까지 버티다 완전히 그만두는가.
const _GIVE_UP_MULTIPLIER := 3.0

## 위치 겹침 해소에서 무시할 겹침(픽셀). 미세한 겹침까지 떼어 놓으면 도착한 유닛이 계속 떤다.
const _OVERLAP_DEADZONE := 0.5

## 최대 속도의 이 비율보다 느리면 "기어가는 중"으로 본다. 도착 판정에 함께 쓴다.
const _CRAWL_RATIO := 0.15

## 몸 반지름의 이 배수 안에서 못 나아가면 그냥 그 자리를 자기 자리로 친다.
##
## 크게 잡으면 대열이 헐거워지고, 작게 잡으면 마지막 몇 명이 오래 비빈다. 이 값은 그 사이다.
const _SETTLE_REACH := 2.5

var grid: ProtoNavGrid
var tuning: ProtoMoveTuning
var agents: Array[ProtoUnitAgent] = []
var orders: Array[MoveOrder] = []

## 직전 step 에 걸린 시간(마이크로초). 개발 표시가 그대로 보여 준다.
var last_step_usec: int = 0

var _by_id: Dictionary = {}
var _next_id := 1
var _next_order_id := 1
var _buckets: Dictionary = {}
var _bucket_size := 40.0
var _scratch: Array[ProtoUnitAgent] = []


func _init(nav_grid: ProtoNavGrid, move_tuning: ProtoMoveTuning) -> void:
	grid = nav_grid
	tuning = move_tuning


# ----------------------------------------------------------------- 유닛 관리


func spawn(kind: int, at: Vector2) -> ProtoUnitAgent:
	var agent := ProtoUnitAgent.new(_next_id, kind, at)
	_next_id += 1
	agents.append(agent)
	_by_id[agent.id] = agent
	return agent


## 뒤에서부터 지운다. 성능 한계를 재려고 인원을 늘렸다 줄이는 데 쓴다.
func despawn(count: int) -> void:
	for i in mini(count, agents.size()):
		var agent: ProtoUnitAgent = agents.pop_back()
		_by_id.erase(agent.id)


func clear_units() -> void:
	agents.clear()
	_by_id.clear()
	orders.clear()


func agent_of(id: int) -> ProtoUnitAgent:
	return _by_id.get(id, null)


func all_ids() -> PackedInt32Array:
	var result := PackedInt32Array()
	for agent in agents:
		result.append(agent.id)
	return result


func ids_of_kind(kind: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	for agent in agents:
		if agent.kind == kind:
			result.append(agent.id)
	return result


## 드래그 박스에 걸린 유닛. 중심이 아니라 몸을 기준으로 잡아야 스치듯 그은 박스도 잡힌다.
func ids_in_rect(rect: Rect2) -> PackedInt32Array:
	var normalized := rect.abs()
	var result := PackedInt32Array()
	for agent in agents:
		if normalized.grow(agent.radius * 0.6).has_point(agent.position):
			result.append(agent.id)
	return result


## 이 점을 클릭했을 때 잡히는 유닛. 겹쳐 있으면 중심이 더 가까운 쪽이다.
func agent_at_point(point: Vector2, slack: float = 4.0) -> ProtoUnitAgent:
	var best: ProtoUnitAgent = null
	var best_distance := INF
	for agent in agents:
		var distance := agent.position.distance_to(point)
		if distance <= agent.radius + slack and distance < best_distance:
			best_distance = distance
			best = agent
	return best


# ----------------------------------------------------------------- 명령


## 이동 명령. 대형 자리를 만들고 나눠 준 뒤 흐름장을 한 번 계산한다.
func issue_move(ids: PackedInt32Array, target: Vector2) -> MoveOrder:
	var members: Array[ProtoUnitAgent] = []
	for id in ids:
		var agent: ProtoUnitAgent = _by_id.get(id, null)
		if agent != null:
			members.append(agent)
	if members.is_empty():
		return null

	# 벽을 찍어도 명령은 살아 있어야 한다. 조용히 무시되는 명령이 조작감을 가장 크게 해친다.
	var safe_target := grid.nearest_walkable(target)
	var order := MoveOrder.new()
	order.id = _next_order_id
	_next_order_id += 1
	order.target = safe_target
	order.flow = grid.build_flow_field(safe_target)

	var clearance := _largest_radius(members)
	var spacing := tuning.get_value("formation_spacing") * clearance * 2.0
	var walkable := func(point: Vector2) -> bool: return grid.is_circle_free(point, clearance)
	order.slots = ProtoFormation.build_slots(members.size(), safe_target, spacing, walkable)

	var positions := PackedVector2Array()
	for agent in members:
		positions.append(agent.position)
	var assignment := ProtoFormation.assign(positions, order.slots)
	for index in members.size():
		var slot_index := assignment[index]
		var slot := order.slots[slot_index] if slot_index >= 0 else safe_target
		members[index].accept_order(order.id, slot, _SIGHT_INTERVAL)
		order.member_ids.append(members[index].id)

	orders.append(order)
	order_issued.emit(safe_target)
	return order


## 제자리에 세운다.
func stop(ids: PackedInt32Array) -> void:
	for id in ids:
		var agent: ProtoUnitAgent = _by_id.get(id, null)
		if agent != null:
			agent.settle(ProtoUnitAgent.State.IDLE)


func order_by_id(id: int) -> MoveOrder:
	for order in orders:
		if order.id == id:
			return order
	return null


func moving_count() -> int:
	var count := 0
	for agent in agents:
		if agent.is_moving():
			count += 1
	return count


# ----------------------------------------------------------------- 시뮬레이션


func step(delta: float) -> void:
	var started := Time.get_ticks_usec()
	_rebuild_buckets()
	_update_pace()
	for agent in agents:
		_steer(agent, delta)
	for agent in agents:
		agent.position += agent.velocity * delta
	_resolve_overlaps()
	_clamp_positions()
	_update_states(delta)
	for order in orders:
		order.age += delta
	_drop_finished_orders()
	last_step_usec = Time.get_ticks_usec() - started


## 이웃 조회를 위한 격자 해시. 유닛이 늘어도 전수 비교로 떨어지지 않게 한다.
##
## 웹은 단일 스레드라 전수 비교(인원의 제곱)가 그대로 프레임 예산을 먹는다.
## 인원을 늘려 한계를 재려면 이 구조가 먼저 있어야 한다.
func _rebuild_buckets() -> void:
	_bucket_size = maxf(tuning.get_value("separation_radius"), 16.0)
	_buckets.clear()
	for agent in agents:
		var key := Vector2i(
			floori(agent.position.x / _bucket_size), floori(agent.position.y / _bucket_size)
		)
		if not _buckets.has(key):
			_buckets[key] = [] as Array[ProtoUnitAgent]
		(_buckets[key] as Array[ProtoUnitAgent]).append(agent)


func _collect_neighbors(agent: ProtoUnitAgent, into: Array[ProtoUnitAgent]) -> void:
	into.clear()
	var origin := Vector2i(
		floori(agent.position.x / _bucket_size), floori(agent.position.y / _bucket_size)
	)
	for y in range(origin.y - 1, origin.y + 2):
		for x in range(origin.x - 1, origin.x + 2):
			var bucket: Array = _buckets.get(Vector2i(x, y), [])
			for other: ProtoUnitAgent in bucket:
				if other.id != agent.id:
					into.append(other)


## 대형 유지. 명령마다 가장 뒤처진 유닛을 기준 삼아 앞선 유닛의 속도를 깎는다.
##
## 속도가 다른 유닛을 섞어 두면 이것이 없을 때 정찰병만 먼저 도착해 대열이 늘어진다.
## 반대로 1.0 으로 두면 전체가 가장 느린 유닛에 묶여 굼떠 보인다. 그래서 슬라이더로 뺐다.
func _update_pace() -> void:
	var sync := tuning.get_value("group_sync")
	for order in orders:
		var furthest := 0.0
		for id in order.member_ids:
			var agent: ProtoUnitAgent = _by_id.get(id, null)
			if agent != null and agent.is_moving():
				furthest = maxf(furthest, agent.remaining())
		if furthest <= 0.001:
			continue
		for id in order.member_ids:
			var agent: ProtoUnitAgent = _by_id.get(id, null)
			if agent == null or not agent.is_moving():
				continue
			var share := clampf(agent.remaining() / furthest, _MIN_PACE, 1.0)
			agent.pace = lerpf(1.0, share, sync)


func _steer(agent: ProtoUnitAgent, delta: float) -> void:
	var speed_cap := tuning.get_value("max_speed") * agent.speed_scale
	var acceleration := tuning.get_value("acceleration") * delta
	if not agent.is_moving():
		# 서 있는 유닛은 속도로 밀지 않는다. 밀면 자리를 못 잡고 계속 떤다.
		agent.velocity = agent.velocity.move_toward(Vector2.ZERO, acceleration)
		agent.debug_seek = Vector2.ZERO
		agent.debug_separation = Vector2.ZERO
		return

	var distance := agent.position.distance_to(agent.goal)
	var seek := _seek(agent, speed_cap, delta, distance)
	var forward := seek.normalized()
	# 자기 자리에 다 와서는 밀치기를 줄인다. 끝까지 같은 세기로 밀면 마지막 몇 명이
	# 서로를 밀어내느라 자리에 못 들어가고 몇 초씩 기어간다.
	var closing := clampf(distance / maxf(tuning.get_value("slow_radius"), 1.0), 0.35, 1.0)
	var separation := _separation(agent, forward, speed_cap) * closing
	agent.debug_seek = seek
	agent.debug_separation = separation

	var combined := seek + separation
	var target_speed := minf(combined.length(), speed_cap)
	if target_speed <= 0.001:
		agent.velocity = agent.velocity.move_toward(Vector2.ZERO, acceleration)
		return

	var current := agent.velocity.angle() if agent.velocity.length_squared() > 4.0 else agent.facing
	var max_turn := deg_to_rad(tuning.get_value("turn_rate")) * delta
	var difference := wrapf(combined.angle() - current, -PI, PI)
	agent.facing = current + clampf(difference, -max_turn, max_turn)
	var desired := Vector2.from_angle(agent.facing) * target_speed
	agent.velocity = agent.velocity.move_toward(desired, acceleration)


## 자기 자리를 향한 힘. 감속 반경 안에서는 남은 거리에 비례해 속도를 줄인다.
##
## 감속이 없으면 유닛이 목적지를 지나쳤다가 되돌아오고, 그 왕복이 진동으로 보인다.
func _seek(agent: ProtoUnitAgent, speed_cap: float, delta: float, distance: float) -> Vector2:
	agent.sight_timer -= delta
	if agent.sight_timer <= 0.0:
		agent.sight_timer = _SIGHT_INTERVAL
		agent.has_sight = grid.has_line_of_sight(agent.position, agent.goal, agent.radius)

	var to_goal := agent.goal - agent.position
	var direction := to_goal / distance if distance > 0.001 else Vector2.ZERO
	if not agent.has_sight:
		var order := order_by_id(agent.order_id)
		if order != null:
			direction = order.flow.direction_at(agent.position, agent.radius)

	var speed := speed_cap * agent.pace
	var slow := tuning.get_value("slow_radius")
	if distance < slow:
		speed *= clampf(distance / maxf(slow, 0.001), 0.05, 1.0)
	return direction * speed


## 이웃을 밀어내는 힘. 정면으로 막고 선 상대는 옆으로 돌아간다.
##
## 밀어내기만 두면 마주 오는 둘이 서로를 정확히 반대로 밀어 그 자리에 굳는다.
## 옆으로 비껴가는 성분이 있어야 서로 스쳐 지나가고, 그것이 뭉침 처리의 핵심이다.
func _separation(agent: ProtoUnitAgent, forward: Vector2, speed_cap: float) -> Vector2:
	var weight := tuning.get_value("separation_weight")
	if weight <= 0.0:
		return Vector2.ZERO
	var reach := tuning.get_value("separation_radius")
	var bias := tuning.get_value("side_bias")
	_collect_neighbors(agent, _scratch)
	var total := Vector2.ZERO
	for other in _scratch:
		var offset := agent.position - other.position
		var distance := offset.length()
		if distance >= reach:
			continue
		var away := (
			offset / distance if distance > 0.001 else Vector2.from_angle(float(agent.id) * 2.4)
		)
		var strength := 1.0 - distance / reach
		# 이미 자리에 선 유닛은 덜 버틴다. 지나가는 쪽이 길을 얻어야 대열이 흐른다.
		if not other.is_moving():
			strength *= 0.55
		total += away * strength
		if bias > 0.0 and forward != Vector2.ZERO and forward.dot(-away) > 0.6:
			var side := Vector2(-forward.y, forward.x)
			var cross := forward.cross(-away)
			var turn := -signf(cross)
			if is_zero_approx(cross):
				turn = 1.0 if agent.id % 2 == 0 else -1.0
			total += side * turn * strength * bias
	return total.limit_length(1.6) * weight * speed_cap


## 몸이 겹친 쌍을 위치로 직접 떼어 놓는다.
##
## 속도로만 밀면 가속 한계 때문에 겹침이 몇 프레임 남고, 그 사이 유닛이 서로를 파고든다.
## 서 있는 쪽이 더 많이 밀려나게 해서 지나가는 유닛이 길을 얻는다.
func _resolve_overlaps() -> void:
	var strength := tuning.get_value("push_resolve")
	if strength <= 0.0:
		return
	for agent in agents:
		_collect_neighbors(agent, _scratch)
		for other in _scratch:
			if other.id <= agent.id:
				continue
			var offset := agent.position - other.position
			var distance := offset.length()
			var minimum := agent.radius + other.radius
			if distance >= minimum:
				continue
			var overlap := minimum - distance
			if overlap < _OVERLAP_DEADZONE:
				continue
			var away := (
				offset / distance if distance > 0.001 else Vector2.from_angle(float(agent.id) * 2.4)
			)
			var share := _push_share(agent, other)
			var correction := away * overlap * strength
			agent.position += correction * share
			other.position -= correction * (1.0 - share)


## 겹침을 나눠 지는 비율. 움직이는 쪽이 덜 밀리고 서 있는 쪽이 더 밀린다.
func _push_share(agent: ProtoUnitAgent, other: ProtoUnitAgent) -> float:
	if agent.is_moving() == other.is_moving():
		return 0.5
	return 0.25 if agent.is_moving() else 0.75


func _clamp_positions() -> void:
	var bounds := grid.field_size()
	for agent in agents:
		agent.position.x = clampf(agent.position.x, agent.radius, bounds.x - agent.radius)
		agent.position.y = clampf(agent.position.y, agent.radius, bounds.y - agent.radius)
		if not grid.is_circle_free(agent.position, agent.radius):
			agent.position = grid.push_out(agent.position, agent.radius)


## 도착과 포기를 판정한다.
##
## 못 들어가는 자리를 두고 영원히 밀어대지 않게 하는 것이 여기의 목적이다.
## 자리 근처까지 왔는데 더 나아가지 못하면 그냥 거기 선다 — 어차피 사람 눈에는 도착이다.
func _update_states(delta: float) -> void:
	var arrive := tuning.get_value("arrive_radius")
	var timeout := tuning.get_value("stuck_timeout")
	var crawl := tuning.get_value("max_speed") * _CRAWL_RATIO
	for agent in agents:
		if not agent.is_moving():
			continue
		var distance := agent.position.distance_to(agent.goal)
		if distance <= arrive:
			agent.settle(ProtoUnitAgent.State.ARRIVED)
			continue
		# 거리만 보면 막힌 유닛이 프레임당 0.1 픽셀씩 파고들며 영원히 "나아가는 중"이 된다.
		# 눈에는 멈춘 것으로 보이는데 상태만 이동이면 마지막 몇 명이 몇 초씩 기어간다.
		# 그래서 속도도 함께 본다.
		if distance < agent.best_distance - 0.5 and agent.velocity.length() > crawl:
			agent.best_distance = distance
			agent.stuck_time = 0.0
		else:
			agent.stuck_time += delta
		if agent.stuck_time <= timeout:
			continue
		if distance < agent.radius * _SETTLE_REACH:
			agent.settle(ProtoUnitAgent.State.ARRIVED)
		elif agent.stuck_time > timeout * _GIVE_UP_MULTIPLIER:
			agent.settle(ProtoUnitAgent.State.BLOCKED)


## 소속 유닛이 모두 멎은 명령을 버린다. 명령 지점 표시는 조금 더 남겨 둔다.
func _drop_finished_orders() -> void:
	var kept: Array[MoveOrder] = []
	for order in orders:
		var alive := false
		for id in order.member_ids:
			var agent: ProtoUnitAgent = _by_id.get(id, null)
			if agent != null and agent.order_id == order.id:
				alive = true
				break
		if alive or order.age < 1.2:
			kept.append(order)
	orders = kept


func _largest_radius(members: Array[ProtoUnitAgent]) -> float:
	var largest := 1.0
	for agent in members:
		largest = maxf(largest, agent.radius)
	return largest
