class_name ProtoUnitField
extends RefCounted
## 방 하나 안의 유닛 전부와 그들의 이동. **이 레인의 본체다.**
##
## 조작감이 갈리는 네 지점을 여기서 처리한다.
##
## | 지점 | 여기서의 처리 |
## | --- | --- |
## | 뭉침 | 대형 자리 배정(각자 다른 목표) + 분리력 + 양보 + **이동 막기** |
## | 도착 | 감속 반경 · 도착 반경 · **상태로 묻는 정지 판정** (`_update_states`) |
## | 반응 | 가속과 회전 제한만으로 지연을 만든다. 명령 처리 자체는 그 프레임에 끝낸다 |
## | 대형 | 명령마다 남은 거리를 비교해 앞선 유닛의 속도를 깎는다 |
## | 지터 | 조향 평활 + 한쪽 손 비껴가기 + **접촉 제약** (아래) |
##
## **이 게임은 물리력 게임이 아니다. 유닛은 다른 유닛을 밀쳐서 갈 수 없다.**
##
## 예전에는 겹친 몸을 위치로 떼어 놓아 겹침을 풀었고, 서 있는 쪽이 더 많이 밀려나도록
## 되어 있어서(0.75) 지나가려는 유닛이 남을 밀쳐 내고 그 자리를 차지했다. 그것이 물리
## 시뮬레이션 같은 모습을 만들었고 지터의 큰 몫이기도 했다 — 조향이 몸을 밀어 넣고 겹침
## 해소가 그만큼 도로 밀어내는 왕복이 매 프레임 벌어졌다. **그 왕복은 속도계에 잡히지 않고
## 위치에만 나타나서** 예전 지표(속도의 꺾임)로는 보이지도 않았다.
##
## 지금은 세 겹으로 막는다.
##
## | 겹 | 어디 | 하는 일 |
## | --- | --- | --- |
## | 속도 | `_steer` 접촉 제약 | 앞선 유닛보다 빨리 그쪽으로 갈 수 없다. 부딪히기 전에 맞춘다 |
## | 위치 | `_advance` `_clip_move` | 그래도 남는 다가감을 잘라 낸다. **통과는 여기서 불가능해진다** |
## | 뒤처리 | `_resolve_overlaps` | 벽 보정 따위가 만든 겹침만 푼다. 서 있는 유닛은 안 움직인다 |
##
## **지터의 원인은 조향이 가리키는 방향 자체가 튀는 것이었다.** 재어 보니 좁은 통로에서
## 조향 방향의 꺾임이 열린 곳의 다섯 배였고, 흐름장을 읽는 프레임 비율과 그대로 맞물렸다.
## 분리력이 조향을 압도하는 프레임은 좁은 곳과 열린 곳이 3 대 6 퍼센트로 비슷해 원인이
## 아니었다. 그래서 흐름장을 칸 사이로 섞어 읽고(`flow_field.gd`), 그 위에 조향 평활을 걸고,
## 매 프레임 부호가 뒤집히던 비껴가기를 한쪽 손으로 고정했다.
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

## 분리력이 낼 수 있는 최대 크기(최대 속도 배수 적용 전).
## 조향보다 커지면 유닛이 목적지가 아니라 이웃 배치를 따라가고, 그 배치는 매 프레임 바뀐다.
const _SEPARATION_LIMIT := 1.2

## "내 앞"으로 치는 각도의 코사인. 0.55 는 대략 좌우 57 도다.
const _AHEAD_CONE := 0.55

## 기다림에서 풀려나려면 막은 아군이 이만큼은 떨어져 있어야 한다(픽셀).
##
## 들어갈 때보다 나올 때의 문턱을 넓게 둔다. **시간이 아니라 거리로 준 여유다.**
## 같은 문턱을 쓰면 경계에 걸친 유닛이 섰다 갔다를 반복한다.
const _HOLD_RELEASE := 10.0

## 앞이 막힌 채 이만큼 이어져야 기다림으로 넘긴다(프레임).
##
## **포기 시간이 아니다.** 4 분의 1 초짜리 떨림 제거이고, 넘어간 상태는 막은 쪽이 비키는
## 순간 저절로 풀린다. 늘린다고 더 참는 것도, 줄인다고 일찍 포기하는 것도 아니라 손맛의
## 손잡이가 되지 못하므로 슬라이더로 내보내지 않는다.
const _HOLD_CONFIRM_FRAMES := 15

## 기다리는 유닛이 이웃을 다시 훑는 주기(프레임). 유닛마다 어긋나게 돌린다.
##
## 기다림은 오래 갈 수 있어 매 프레임 훑으면 그대로 비용이 된다. 여섯 프레임이면
## 늦어야 0.1 초 안에 풀리므로 눈에 보이지 않는다.
const _HOLD_REVIEW_FRAMES := 6

## 몸이 이 비율보다 깊이 겹치면 한 프레임 상한을 풀고 통째로 떼어 놓는다.
##
## 상한만 믿으면 안 된다는 것을 뚫고 지나가는 유닛을 보고 알았다. 상한은 **살짝 닿은 것을
## 여러 프레임에 나눠 푸는 장치**이지 깊이 박힌 것을 방치하는 장치가 아니다.
const _DEEP_OVERLAP := 0.5

## 겹침 해소 상한이 아무리 낮아도 이 속도만큼은 떼어 놓는다(초당 픽셀).
##
## **상한을 너무 낮게 잡으면 유닛이 서로를 통과한다.** 겹침은 달려드는 속도만큼 매 프레임
## 깊어지는데, 떼어 놓는 양이 그보다 작으면 겹침이 계속 자라 결국 중심이 반대편으로 넘어간다.
## 한 칸 복도에서는 그 과정에서 몸이 벽 쪽으로 밀리고 `push_out` 이 100 픽셀 너머로
## 옮겨 버려, 앞을 막은 유닛 여섯을 그대로 뚫고 지나갔다.
##
## 그래서 상한의 바닥을 최대 속도에 묶는다. 한 프레임에 다가오는 거리보다 조금 더 떼어 놓으면
## 겹침은 자랄 수 없다. 슬라이더를 어디로 돌려도 통과는 일어나지 않는다.
const _MIN_PUSH_RATE := 1.2

## 양보할 때 옆으로 비키는 힘의 배수. 뒤에 선 쪽만 쓴다.
##
## 1.5 로 두었다가 0.4 로 낮췄다. 재어 보니 이 항 하나가 남은 꺾임의 3 분의 1 을 만들고 있었고
## (초당 100 도 대 66 도), 그 대가로 얻는 것은 정지 시간 3 퍼센트뿐이었다. **비키라고 밀어 준
## 힘이 그대로 흔들림이 된다.** 밀지 않는 것만으로 교착은 이미 풀리므로 옆걸음은 거들기만 하면 된다.
const _YIELD_SIDE := 0.4

## 앞을 막은 **서 있는** 아군을 돌아 나갈 때 옆으로 비껴가기에 얹는 배수.
##
## 밀치기를 걷어내면서 필요해졌다. 밀 수 있을 때는 반경 방향 힘이 곧 전진이었지만, 밀 수 없는
## 몸에게 반경 방향 힘은 **서게 만들 뿐이다.** 앞으로 나아가게 하는 것은 몸을 타고 도는 접선
## 힘이고, 그래서 서 있는 상대에게만 이 배수를 얹는다.
##
## 움직이는 상대에게는 쓰지 않는다. 그쪽은 양보 규칙이 맡는다 — 스쳐 지나갈 뿐인 상대에게
## 같은 세기를 주면 크게 휘어 도리어 꺾임이 는다.
const _ROUND_SETTLED := 1.4

## 이 거리 안에 앞선 유닛이 있으면 그 유닛보다 빨리 그쪽으로 가지 않는다(픽셀, 몸 사이 간격).
##
## **줄 세우기의 전부다.** 넓게 잡으면 멀리서부터 굼떠지고, 0 으로 잡으면 몸이 닿은 다음에야
## 알아채서 위치 자르기가 대신 일하게 된다 — 그것이 그대로 지터다.
##
## 재어 보고 골랐다(좁은 통로 100 명 꺾임 / 열린 곳 100 명 정지).
##
## | 간격 | 5 | 8 | 10 | 14 |
## | --- | --- | --- | --- | --- |
## | 좁은 통로 100 꺾임 | 246 | **211** | 223 | 281 |
## | 열린 곳 100 정지 | 11.50 s | **9.02 s** | 11.63 s | 10.28 s |
const _FOLLOW_GAP := 8.0

## 따라가기가 "앞"으로 치는 각도의 코사인. 0.2 는 대략 좌우 78 도다.
##
## 막힘 판정(`_AHEAD_CONE`, 57 도)보다 넓게 잡는다. 둘은 묻는 것이 다르다 — 막힘은 "이 유닛
## 때문에 내가 멈춰야 하는가"라 좁아야 하고, 따라가기는 "이쪽으로 더 빨리 가면 부딪히는가"라
## 비스듬한 상대도 봐야 한다. 좁게 잡았더니 잼 한가운데에서 비스듬히 낀 유닛들을 못 보고
## 그 사이로 빠르게 비집으려 들었고, 그 옆걸음이 그대로 꺾임이 됐다.
const _FOLLOW_CONE := 0.2

## 최단 거리가 줄지 않은 채 이만큼 지나면 지형에 낀 것으로 본다(프레임).
##
## **이것은 포기 시간이 아니다.** 아군이 막은 경우는 상태로 걸러지고 목적지가 갈린 경우는
## 흐름장이 즉시 답하므로, 여기까지 오는 것은 아군도 벽도 아닌 지형에 몸이 낀 경우뿐이다.
## 그 경우엔 시간 말고 볼 것이 없다. 손맛을 위해 만지는 값이 아니라 무한 루프를 막는
## 안전장치이므로 슬라이더로 내보내지 않는다. 평상시에는 걸리지 않아야 정상이다.
const _GRIND_FRAMES := 240

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

## 겹침 해소가 위치를 강제로 옮긴 누적 거리(픽셀). **튕김의 크기를 재는 계기다.**
##
## 눈으로 "튕긴다"고 말하는 것과 얼마나 튕기는지를 아는 것은 다르다. 속도 적분과 싸우는
## 위치 보정이 얼마나 일하고 있는지 이 값 하나로 드러난다. 재는 쪽에서 0 으로 되돌린다.
var overlap_push_total: float = 0.0

## 한 번에 밀어낸 거리의 최댓값(픽셀). **눈에 튕김으로 보이는 것은 총량이 아니라 이 값이다.**
##
## 총량은 붙어서 지나가는 시간이 길수록 커져서, 줄을 잘 서서 오래 붙어 있는 쪽이
## 도리어 나쁘게 나온다. 한 프레임에 몸이 얼마나 순간이동했는가가 튕김의 정체다.
var overlap_push_peak: float = 0.0

## **움직이는 유닛이 서 있는 유닛을 밀어낸 누적 거리(픽셀). 밀치기의 직접 계기다.**
##
## "밀치기를 없앴다"는 말은 증명할 수 있어야 한다. 이 값이 0 이 아니면 없애지 못한 것이다.
## `overlap_push_total` 은 누가 누구를 밀었는지 가리지 않아 이 질문에 답하지 못한다.
var settled_push_total: float = 0.0

## 몸이 서로 파고든 최대 깊이(픽셀). **통과가 일어났는지 보는 계기다.**
##
## 한 유닛이 다른 유닛을 통과하려면 그 전에 반드시 겹침이 몸 지름까지 자라야 한다.
## 이동을 몸에 막히는 만큼 깎으면 겹침은 애초에 자랄 수 없고, 이 값이 그것을 보여 준다.
var max_penetration: float = 0.0

## 이동이 이웃의 몸에 막혀 깎여 나간 누적 거리(픽셀). **막힘의 크기다.**
##
## 밀치기를 걷어내면 이 거리가 그만큼 생긴다. 예전에는 이 거리가 남의 몸을 밀어내는 데
## 쓰였다. 지금은 어디에도 쓰이지 않고 그냥 사라진다 — 그것이 "밀고 갈 수 없다"의 실체다.
##
## 접촉 제약이 잘 듣고 있으면 이 값은 작아야 한다. 크다는 것은 **속도 단계에서 못 막아
## 위치 단계까지 왔다**는 뜻이고, 그 차이가 곧 지터다.
var blocked_move_total: float = 0.0

var _by_id: Dictionary = {}
var _next_id := 1
var _next_order_id := 1
var _buckets: Dictionary = {}
var _bucket_size := 40.0
var _scratch: Array[ProtoUnitAgent] = []
var _order_cache: Dictionary = {}
var _frame := 0


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
	_frame += 1
	_rebuild_buckets()
	_cache_orders()
	for agent in agents:
		agent.goal_distance = agent.position.distance_to(agent.goal)
	_update_pace()
	for agent in agents:
		_steer(agent, delta)
	_advance(delta)
	_clamp_positions()
	_update_states(delta)
	for order in orders:
		order.age += delta
	_drop_finished_orders()
	last_step_usec = Time.get_ticks_usec() - started


## 명령을 번호로 바로 찾을 수 있게 해 둔다. 유닛마다 목록을 훑으면 인원 곱하기 명령 수가 된다.
func _cache_orders() -> void:
	_order_cache.clear()
	for order in orders:
		_order_cache[order.id] = order


## 이웃 조회를 위한 격자 해시. 유닛이 늘어도 전수 비교로 떨어지지 않게 한다.
##
## 웹은 단일 스레드라 전수 비교(인원의 제곱)가 그대로 프레임 예산을 먹는다.
## 인원을 늘려 한계를 재려면 이 구조가 먼저 있어야 한다.
##
## 칸 크기는 **분리 반경이 아니라 몸이 닿는 거리로 바닥을 잡는다.** 3x3 을 훑으면 칸 크기만큼
## 떨어진 이웃까지 반드시 잡히는데, 칸이 몸 지름 + 한 프레임 이동 거리보다 작으면 부딪힐 이웃을
## 놓친다. 분리 반경을 슬라이더로 최소까지 내려도 몸끼리 통과하지 않아야 하므로 여기서 막는다.
func _rebuild_buckets() -> void:
	var body := 1.0
	for agent in agents:
		body = maxf(body, agent.radius)
	var contact := body * 2.0 + tuning.get_value("max_speed") / 60.0 + 1.0
	_bucket_size = maxf(tuning.get_value("separation_radius"), contact)
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
		agent.contact_normal = Vector2.ZERO
		return

	var distance := agent.goal_distance
	var seek := _seek(agent, speed_cap, delta, distance)
	var forward := agent.steer_dir
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
	var desired := _follow(agent, Vector2.from_angle(agent.facing) * target_speed)
	agent.velocity = agent.velocity.move_toward(desired, acceleration)


## **앞선 유닛보다 그쪽으로 빨리 갈 수 없다.** 줄 세우기이자 지터를 잡는 마지막 장치다.
##
## 밀치기를 걷어내고 나서 좁은 통로의 꺾임이 도리어 두 배가 됐다. 항을 하나씩 꺼 보아도
## 범인이 없었다 — 조향 평활 · 양보 · 비껴가기 · 겹침 상한 어느 것을 꺼도 초당 215 도 언저리로
## 같았다. 원인은 힘이 아니라 **아무도 기다리지 않는다는 것**이었다. 밀 수 있을 때는 앞이
## 막혀도 밀고 나가면 됐지만, 밀 수 없게 되자 전원이 같은 자리로 계속 파고들었고 위치
## 자르기가 매 프레임 다른 접선으로 튕겨 냈다. 그 접선의 뒤바뀜이 그대로 꺾임이었다.
##
## 그래서 **부딪히기 전에 속도를 맞춘다.** 앞선 유닛이 실제로 나아가는 만큼만 그쪽으로 간다.
## 앞선 유닛이 서 있으면 0 이 되어 그 자리에 선다 — 막혔으면 막힌 티가 난다.
## 옆으로 도는 성분은 건드리지 않으므로 돌아갈 길이 있으면 돌아간다.
##
## 위치 자르기(`_clip_move`)를 대신하지는 않는다. 이웃 하나만 보고 거는 제약이라 셋에
## 둘러싸이면 새는데, 그 새는 몫을 위치 단계가 막는다. 순서가 중요하다 — **속도로 먼저 막을수록
## 위치로 자를 일이 줄고, 자를 일이 줄수록 조용하다.**
##
## **방향은 건드리지 않고 크기만 줄인다.** 다가가는 성분을 잘라 내는 방식으로 먼저 만들었다가
## 걷어냈다. 앞을 막은 이웃이 프레임마다 바뀌면 잘라 내는 축도 같이 바뀌어 속도 방향이
## 널뛰었고, 좁은 통로 100 명에서 꺾임이 423 에서 619 로 도리어 늘었다. **자르는 축이 곧
## 지터의 씨앗이다** — 위치 자르기에서 배운 것과 같은 교훈인데 한 층 위에서 되풀이했다.
##
## 그다음엔 다가가는 성분의 비율만큼 속도를 통째로 줄여 봤다. 지터는 없어졌는데(꺾임 91)
## **아무도 못 갔다** — 좁은 통로 100 명 중 86 명이 문을 못 넘었다. 앞이 0 이면 비스듬히
## 가려는 속도까지 0 이 되어, 정확히 직각으로만 움직일 수 있었기 때문이다.
##
## 그래서 **얼마나 정면으로 가려는지에 따라 제약을 걷어 준다.** 앞선 유닛을 똑바로 향하면
## 그 유닛의 속도에 맞춰지고, 방향을 옆으로 틀수록 제 속도를 되찾는다. 돌아갈 뜻이 있는
## 유닛은 붙잡지 않고 파고들 뜻만 있는 유닛을 붙잡는다. 축이 아니라 세기를 다루므로
## 이웃이 바뀌어도 방향이 튀지 않는다.
func _follow(agent: ProtoUnitAgent, desired: Vector2) -> Vector2:
	if agent.contact_normal == Vector2.ZERO:
		return desired
	var speed := desired.length()
	if speed <= 0.001:
		return desired
	var ahead := desired.dot(agent.contact_normal) / speed
	var head_on := (ahead - _FOLLOW_CONE) / (1.0 - _FOLLOW_CONE)
	var blend := clampf(head_on, 0.0, 1.0) * agent.contact_near
	if blend <= 0.0:
		return desired
	var allowed := lerpf(speed, maxf(agent.contact_speed, 0.0), blend)
	return desired * (minf(speed, allowed) / speed)


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
		var order: MoveOrder = _order_cache.get(agent.order_id, null)
		if order != null:
			direction = order.flow.direction_at(agent.position, agent.radius)

	agent.steer_dir = _smoothed(agent.steer_dir, direction, delta)
	var speed := speed_cap * agent.pace
	var slow := tuning.get_value("slow_radius")
	if distance < slow:
		speed *= clampf(distance / maxf(slow, 0.001), 0.05, 1.0)
	return agent.steer_dir * speed


## 조향 방향을 평활한다. **지터를 잡는 두 번째 장치다.**
##
## 격자를 섞어 읽어도 남는 뜀이 있다. 목적지가 보이는지 아닌지가 뒤집히는 순간
## 직선 방향과 흐름장 방향 사이를 오가고, 그 둘은 꽤 다를 수 있다. 지수 평활을 걸면
## 그런 왕복이 서로 상쇄된다.
##
## 회전 속도 제한과 하는 일이 다르다. 그쪽은 **결과**를 늦추므로 튀는 목표를 계속 쫓게 되지만,
## 이쪽은 **목표 자체**를 다듬는다. 명령을 새로 받을 때는 곧바로 그 방향에서 시작하므로
## 클릭 반응은 늦어지지 않는다.
func _smoothed(current: Vector2, wanted: Vector2, delta: float) -> Vector2:
	if current == Vector2.ZERO or wanted == Vector2.ZERO:
		return wanted
	var window := tuning.get_value("steer_smooth")
	if window <= 0.0:
		return wanted
	var blended := current.lerp(wanted, clampf(delta / window, 0.0, 1.0))
	# 정확히 반대 방향이면 섞은 값이 영벡터가 된다. 그때는 새 방향을 그대로 쓴다.
	return blended.normalized() if blended.length_squared() > 0.0001 else wanted


## 이웃을 밀어내는 힘. 정면으로 막고 선 상대는 **늘 같은 쪽으로** 돌아간다.
##
## 밀어내기만 두면 마주 오는 둘이 서로를 정확히 반대로 밀어 그 자리에 굳는다.
## 옆으로 비껴가는 성분이 있어야 서로 스쳐 지나간다.
##
## 예전에는 어느 쪽으로 돌지를 상대와의 각도로 매 프레임 다시 골랐다. 정면에 가까울수록
## 그 부호가 뒤집히기 쉬워 **비껴가기 자체가 좌우 진동을 만들었다.** 지금은 자기 진행 방향
## 기준으로 늘 같은 손 쪽으로 돈다. 마주 오는 둘은 각자의 기준에서 같은 쪽으로 돌므로
## 세상 좌표에서는 반대쪽으로 갈라져 스쳐 지나간다 — 우측통행과 같은 규칙이고, 고를 것이
## 없으니 뒤집힐 것도 없다.
##
## 이웃을 훑는 김에 **자리를 잡은 아군이 앞을 막고 있는지**도 함께 표시한다.
## 그 판정 하나를 위해 이웃을 또 훑으면 비용이 배로 든다.
##
## 여기에 **좁은 통로에서 한 줄로 세우는 규칙**을 넣었다가 걷어냈다. 두 가지로 만들어 봤는데
## 둘 다 한 칸짜리 문에서 도리어 나빠졌다(정지 9.35 초 대 10.08 초, 통과 6.53 초 대 7.02 초).
## 좌우로 비집는 힘을 걷어내면 유닛이 문 입구에 자기를 맞추지 못해 그대로 벽에 붙어 막힌다.
## 줄을 세우려면 밀치기를 깎을 게 아니라 **통로 한가운데로 끌어당겨야** 한다 — 그건 벽까지의
## 거리를 재는 별도의 조회가 필요해서 이번에는 손대지 않았다.
## 이웃을 훑는 김에 **앞을 막은 가장 가까운 몸**도 함께 잡아 둔다(`contact_normal`).
## 그 제약 하나를 위해 이웃을 또 훑으면 유닛이 늘 때 비용이 배로 든다.
func _separation(agent: ProtoUnitAgent, forward: Vector2, speed_cap: float) -> Vector2:
	agent.blocked_by_settled = false
	agent.contact_normal = Vector2.ZERO
	agent.contact_speed = 0.0
	var weight := tuning.get_value("separation_weight")
	if weight <= 0.0:
		return Vector2.ZERO
	var reach := tuning.get_value("separation_radius")
	var bias := tuning.get_value("side_bias")
	var yielding := tuning.get_value("yield_strength")
	var hand := Vector2(-forward.y, forward.x)
	_collect_neighbors(agent, _scratch)
	var total := Vector2.ZERO
	var tightest := INF
	for other in _scratch:
		var offset := agent.position - other.position
		var distance := offset.length()
		if distance >= reach:
			continue
		var away := (
			offset / distance if distance > 0.001 else Vector2.from_angle(float(agent.id) * 2.4)
		)
		var strength := 1.0 - distance / reach
		var ahead := forward.dot(-away)
		var blocking := ahead > _AHEAD_CONE
		var touch := agent.radius + other.radius
		if ahead > _FOLLOW_CONE and distance <= touch + _FOLLOW_GAP:
			# 앞선 유닛이 **실제로** 나아가는 만큼만 따라간다. 뜻이 아니라 결과를 본다 —
			# 막혀 있는 유닛은 속도계가 살아 있어도 한 뼘도 못 간다.
			#
			# 여럿이 앞을 막으면 **가장 가까운 쪽이 아니라 나를 가장 늦추는 쪽**을 고른다.
			# 가까운 쪽으로 골랐더니 잼 한가운데에서 정작 나를 세우는 유닛을 놓쳤고,
			# 그 몫이 위치 자르기로 넘어가 그대로 꺾임이 됐다.
			var limit := other.advance.dot(-away)
			# 간격 끝에서 0, 몸이 닿으면 1. 제약이 켜졌다 꺼졌다 하지 않고 서서히 든다.
			var near := clampf((touch + _FOLLOW_GAP - distance) / _FOLLOW_GAP, 0.0, 1.0)
			var head_on := clampf((ahead - _FOLLOW_CONE) / (1.0 - _FOLLOW_CONE), 0.0, 1.0)
			var cap := lerpf(speed_cap, maxf(limit, 0.0), near * head_on)
			if cap < tightest:
				tightest = cap
				agent.contact_normal = -away
				agent.contact_speed = limit
				agent.contact_near = near
		if not other.is_moving():
			# **서 있는 유닛은 벽이다.** 예전에는 여기서 버티는 힘을 절반으로 깎았다 —
			# 밀고 지나갈 수 있었으니 가까이 붙어도 됐기 때문이다. 이제는 통과할 수 없으므로
			# 깎지 않고, 대신 앞을 막았을 때 몸을 타고 도는 힘을 크게 준다.
			total += away * strength
			if blocking:
				if distance <= touch + _HOLD_RELEASE:
					agent.blocked_by_settled = true
				total += hand * strength * bias * _ROUND_SETTLED
			continue
		if blocking:
			# 양보 규칙. 목적지에 더 가까운 쪽에 우선권을 주고, 뒤에 있는 쪽은 밀지 말고 비킨다.
			# 서로 반대로 미는 순간 둘 다 제자리에서 떤다 — 미는 힘을 줄이는 것이 핵심이다.
			total += away * strength * (1.0 - yielding)
			if other.goal_distance < agent.goal_distance:
				total += hand * strength * yielding * _YIELD_SIDE
			continue
		total += away * strength
	return total.limit_length(_SEPARATION_LIMIT) * weight * speed_cap


## 속도를 위치로 옮긴다. **이웃의 몸에 막히는 만큼 깎아서 옮긴다.**
##
## 예전에는 속도를 그대로 더한 뒤 겹친 몸을 위치로 떼어 놓았다. 그러면 유닛이 남의 몸 안으로
## 걸어 들어가고 겹침 해소가 **양쪽을 다 옮겨** 그 겹침을 풀었다. 서 있는 쪽이 더 많이 밀리도록
## 되어 있어서, 지나가려는 유닛은 남을 밀쳐 내고 그 자리를 차지했다. **밀쳐서 가는 길이 거기
## 있었다.** 이 게임은 물리력 게임이 아니므로 그렇게 갈 수 있으면 안 된다.
##
## 지금은 겹침을 사후에 푸는 대신 **애초에 만들지 않는다.**
##
## 순서대로 처리해 앞선 유닛의 **새 위치**에 맞춘다. 전원의 옛 위치로 한꺼번에 맞추면 둘이
## 같은 빈 자리로 동시에 들어가 겹침이 남고, 그 겹침을 다시 위치로 풀어야 한다 — 그것이 바로
## 걷어내려는 장치다. 처리 순서는 유닛 번호 순이라 프레임마다 뒤바뀌지 않는다.
##
## **속도는 건드리지 않는다.** 막혔다고 속도를 0 으로 눌러 쓰면 다음 프레임 조향이 그 눌린
## 속도에서 방향을 다시 잡아 매 프레임 다른 쪽을 가리킨다. 재어 보니 좁은 통로 100 명에서
## 눌러 쓰는 쪽이 꺾임 507, 그냥 두는 쪽이 423 이었다. 속도는 조향의 **뜻**이고 위치는
## 그 뜻이 몸에 막히고 남은 **결과**다. 둘을 섞으면 뜻이 결과에 오염된다.
## 어차피 속도는 최대 속도로 묶여 있어 눌러 두지 않아도 쌓였다 터지지 않는다.
##
## 뒤처리인 겹침 해소를 **같은 훑기 안에서** 끝낸다. 둘 다 유닛마다 이웃을 훑는 일이라
## 따로 돌면 격자 조회가 한 벌 더 든다. 붙여 놓으니 100 명에서 이동 계산이 평균 3.96 에서
## 2.90 밀리초로 내려갔다.
func _advance(delta: float) -> void:
	if delta <= 0.0:
		return
	var strength := tuning.get_value("push_resolve")
	var floor_push := tuning.get_value("max_speed") * _MIN_PUSH_RATE / 60.0
	var cap := tuning.get_value("push_cap")
	for agent in agents:
		_collect_neighbors(agent, _scratch)
		var wanted := agent.velocity * delta
		if wanted == Vector2.ZERO:
			agent.advance = Vector2.ZERO
		else:
			var allowed := _clip_move(agent, wanted)
			blocked_move_total += (wanted - allowed).length()
			agent.position += allowed
			agent.advance = allowed / delta
		_resolve_overlaps(agent, strength, cap, floor_push)


## 한 프레임의 이동을 이웃의 몸에 막히는 만큼 깎는다. **통과가 여기서 불가능해진다.**
##
## 이웃마다 "지금 거리 - 몸이 닿는 거리"가 다가갈 수 있는 여유다. 그 여유를 넘어서는 성분만
## 덜어 낸다. 덜어 낸 뒤에도 접선 성분은 그대로라 몸을 타고 미끄러진다.
##
## 이미 겹쳐 있으면 여유가 0 이라 다가가는 성분이 통째로 사라진다 — **더 깊이 파고들 수 없다.**
## 빠져나오는 방향은 성분 부호가 반대라 깎이지 않으므로 겹침이 풀리는 것은 막지 않는다.
##
## 한 프레임에 몸을 뛰어넘는 통과도 여기서 막힌다. 여유를 **이동 전 거리**로 재므로 아무리
## 빨라도 닿는 순간까지만 갈 수 있다. 격자 해시가 그 거리 안의 이웃을 반드시 준다는 것은
## `_rebuild_buckets` 가 칸 크기로 보장한다.
func _clip_move(agent: ProtoUnitAgent, motion: Vector2) -> Vector2:
	var result := motion
	for other in _scratch:
		var offset := agent.position - other.position
		var distance := offset.length()
		var minimum := agent.radius + other.radius
		if distance > minimum + result.length():
			continue
		var away := (
			offset / distance if distance > 0.001 else Vector2.from_angle(float(agent.id) * 2.4)
		)
		var into := -result.dot(away)
		if into <= 0.0:
			continue
		var room := maxf(distance - minimum, 0.0)
		if into <= room:
			continue
		result += away * (into - room)
	return result


## 남은 겹침을 떼어 놓는다. **이동을 위한 장치가 아니라 뒤처리다.**
##
## 예전에는 이것이 이동의 일부였다. 유닛이 남의 몸 안으로 걸어 들어가면 여기서 양쪽을 떼어
## 놓았고, 서 있는 쪽이 더 많이 밀려나서(0.75) 지나가려는 유닛이 그 자리를 차지했다.
## 지금은 `_advance` 가 애초에 파고들지 못하게 하므로 여기까지 오는 겹침은 이동이 만든 것이
## 아니다 — 스폰이 겹쳐 놓았거나, 벽 보정(`push_out`)이 몸을 옮겼거나, 대형 자리가 붙어 있는
## 경우뿐이고 전부 한두 프레임이면 풀린다.
##
## 그래서 **서 있는 유닛은 여기서도 움직이지 않는다**(`_push_share`). 서 있는 쪽을 조금이라도
## 옮기면 그것이 곧 밀치기이고, 밀 수 있는 만큼 비집고 갈 수 있다.
##
## 한 프레임에 미는 양의 상한(`push_cap`)은 그대로 둔다. 위치를 직접 옮기는 처리는 속도 적분과
## 싸우므로, 깊은 겹침을 한 프레임에 통째로 풀면 몸이 튕겨 나갔다가 조향에 다시 빨려 들어온다.
##
## 미는 방향을 진행 방향의 접선 쪽으로 돌려 스쳐 지나가게 하는 것도 해 봤는데 걷어냈다.
## 한 칸 폭 복도에서는 접선이 곧 벽 쪽이라 몸이 벽으로 밀리고, `push_out` 이 그 몸을
## 100 픽셀 너머 빈 곳으로 옮겨 버린다. 결과는 앞을 막은 유닛 여섯을 그대로 통과하는 것이었다.
##
## **자기 몸만 옮긴다.** 예전에는 겹친 쌍을 한 번에 잡아 양쪽을 갈랐다. 지금은 유닛마다
## 자기가 빠져나올 몫만 옮기고, 상대는 상대의 차례에 자기 몫을 옮긴다. 결과는 같은데
## "남을 옮기는 코드"가 아예 없어져서, 밀치기가 되살아날 자리가 남지 않는다.
func _resolve_overlaps(
	agent: ProtoUnitAgent, strength: float, cap: float, floor_push: float
) -> void:
	for other in _scratch:
		var offset := agent.position - other.position
		var distance := offset.length()
		var minimum := agent.radius + other.radius
		if distance >= minimum:
			continue
		var overlap := minimum - distance
		max_penetration = maxf(max_penetration, overlap)
		if overlap < _OVERLAP_DEADZONE or strength <= 0.0:
			continue
		var share := _push_share(agent, other)
		if share <= 0.0:
			continue
		var away := (
			offset / distance if distance > 0.001 else Vector2.from_angle(float(agent.id) * 2.4)
		)
		var amount := overlap * strength
		if overlap < minimum * _DEEP_OVERLAP:
			amount = minf(amount, maxf(cap * minf(agent.radius, other.radius), floor_push))
		var moved := amount * share
		agent.position += away * moved
		overlap_push_total += moved
		overlap_push_peak = maxf(overlap_push_peak, moved)
		if not agent.is_moving() and other.is_moving():
			# 여기 걸리면 서 있는 유닛이 움직이는 유닛 때문에 옮겨졌다는 뜻이다.
			# `_push_share` 가 0 을 주므로 위에서 걸러져 이 줄에는 오지 않아야 한다.
			settled_push_total += moved


## 겹침에서 **자기가 빠져나올 몫.** 서 있는 유닛의 몫은 0 이다 — 밀려나지 않는다.
##
## 예전에는 서 있는 쪽이 0.75 를 졌다. "지나가는 쪽이 길을 얻어야 대열이 흐른다"는 이유였는데,
## 그것이 곧 **남을 밀쳐서 가는 길**이었다. 서 있는 유닛은 이제 벽과 같다 — 돌아가야 한다.
##
## 둘 다 서 있으면 반씩 나눈다. 이건 밀치기가 아니라 겹친 채로 굳는 것을 푸는 일이고,
## 어느 쪽도 그렇게 해서 앞으로 나아가지 않는다.
func _push_share(agent: ProtoUnitAgent, other: ProtoUnitAgent) -> float:
	if agent.is_moving() == other.is_moving():
		return 0.5
	return 1.0 if agent.is_moving() else 0.0


func _clamp_positions() -> void:
	var bounds := grid.field_size()
	for agent in agents:
		agent.position.x = clampf(agent.position.x, agent.radius, bounds.x - agent.radius)
		agent.position.y = clampf(agent.position.y, agent.radius, bounds.y - agent.radius)
		if not grid.is_circle_free(agent.position, agent.radius):
			agent.position = grid.push_out(agent.position, agent.radius)


## 멈출지 계속 갈지 판정한다. **시간이 아니라 상태로 묻는다.**
##
## 예전에는 "이만큼 못 나아가면 포기"였다. 그런데 포기한 유닛에게 다시 명령하면 가는 일이
## 있었다. 실제로는 막히지 않았는데 알고리즘이 막혔다고 잘못 결론 낸 것이고, 포기 시간은
## 그 오판을 시간으로 덮는 장치였다. 늘리면 굼떠지고 줄이면 일찍 포기하니 어느 쪽도 답이 아니다.
##
## 지금은 셋 중 하나에 걸릴 때만 멈춘다.
##
## | 무엇 | 어떻게 아는가 | 되돌아오는가 |
## | --- | --- | --- |
## | 도착 | 자기 자리에 들었다 | 아니다 |
## | 정말 갈 수 없다 | 흐름장이 내가 선 칸까지 못 닿았다 | 아니다 |
## | 앞이 막혔다 | 나를 막은 것이 **이미 자리를 잡은 아군**이다 | **그렇다** |
##
## 셋째가 포기 시간을 대신한다. 안쪽에 도착한 유닛부터 바깥으로 자리 잡음이 번져 나가고,
## 막고 있던 유닛이 비키면 조건이 저절로 풀려 다시 간다. 재명령이 필요 없어진다.
func _update_states(delta: float) -> void:
	var arrive := tuning.get_value("arrive_radius")
	var crawl := tuning.get_value("max_speed") * _CRAWL_RATIO * delta
	for agent in agents:
		if agent.state == ProtoUnitAgent.State.HOLDING:
			_review_hold(agent, arrive)
		elif agent.is_moving():
			_review_moving(agent, arrive, crawl)


func _review_moving(agent: ProtoUnitAgent, arrive: float, crawl: float) -> void:
	var distance := agent.position.distance_to(agent.goal)
	if distance <= arrive:
		agent.settle(ProtoUnitAgent.State.ARRIVED)
		return
	if _unreachable(agent):
		agent.settle(ProtoUnitAgent.State.BLOCKED)
		return
	# **속도가 아니라 실제로 줄어든 거리로 본다.** 앞이 막힌 유닛은 속도가 살아 있다 —
	# 매 프레임 조향이 밀어 넣고 겹침 해소가 그만큼 도로 밀어내서, 속도계는 초당 160 픽셀을
	# 가리키는데 목적지까지의 거리는 한 뼘도 줄지 않는다. 속도로 물었을 때 이 유닛이
	# 영원히 "나아가는 중"으로 남아 결국 막힘으로 떨어지는 것을 보고 고쳤다.
	var progress := agent.goal_distance - distance
	if agent.blocked_by_settled and progress < crawl:
		agent.press_frames += 1
	else:
		agent.press_frames = 0
	if agent.press_frames >= _HOLD_CONFIRM_FRAMES:
		# 자기 자리 코앞이면 거기가 자기 자리다. 어차피 사람 눈에는 도착이다.
		if distance < agent.radius * _SETTLE_REACH:
			agent.settle(ProtoUnitAgent.State.ARRIVED)
		else:
			agent.hold()
		return
	_watch_grinding(agent, distance)


## 기다리는 유닛을 다시 본다. **막은 쪽이 비켰으면 스스로 간다.**
func _review_hold(agent: ProtoUnitAgent, arrive: float) -> void:
	if not _order_cache.has(agent.order_id):
		agent.settle(ProtoUnitAgent.State.ARRIVED)
		return
	if agent.position.distance_to(agent.goal) <= arrive:
		agent.settle(ProtoUnitAgent.State.ARRIVED)
		return
	# 훑는 시점을 유닛마다 어긋나게 둔다. 기다리는 유닛이 많을 때 전원이 같은 프레임에
	# 이웃을 훑으면 평균은 싸도 그 프레임만 몇 배로 튄다.
	if (agent.id + _frame) % _HOLD_REVIEW_FRAMES != 0:
		return
	_collect_neighbors(agent, _scratch)
	if _slot_taken(agent, arrive):
		# 내 자리에 이미 다른 아군이 서 있다. 그러면 여기가 내 자리다 — 영원히 기다릴 이유가 없다.
		agent.settle(ProtoUnitAgent.State.ARRIVED)
		return
	if not _settled_ahead(agent):
		agent.resume()


## 자리를 잡은 아군이 아직 앞을 막고 있는가. 기다리는 유닛만 이 길로 온다.
##
## 이동 중인 유닛은 분리력을 구하며 이미 알아낸다. 기다리는 유닛은 조향을 돌리지 않으므로
## 여기서 따로 훑되, 부르는 쪽이 이웃 목록을 미리 모아 준다.
func _settled_ahead(agent: ProtoUnitAgent) -> bool:
	if agent.steer_dir == Vector2.ZERO:
		return false
	for other in _scratch:
		if other.is_moving():
			continue
		var offset := other.position - agent.position
		var gap := offset.length()
		if gap > agent.radius + other.radius + _HOLD_RELEASE:
			continue
		if gap > 0.001 and offset.dot(agent.steer_dir) / gap >= _AHEAD_CONE:
			return true
	return false


## 내가 가려던 자리를 다른 아군이 이미 차지했는가.
func _slot_taken(agent: ProtoUnitAgent, arrive: float) -> bool:
	var reach := arrive + agent.radius
	for other in _scratch:
		if not other.is_moving() and other.position.distance_to(agent.goal) <= reach:
			return true
	return false


## 목적지가 나와 벽으로 갈려 있는가. **시간을 들여 확인할 일이 아니다.**
##
## 흐름장은 목적지에서 바깥으로 비용을 퍼뜨려 만든다. 내가 선 칸까지 비용이 닿지 않았다면
## 그 칸에서 목적지로 가는 길이 아예 없다는 뜻이다. 벽 안이나 완전히 둘러싸인 자리를
## 찍었을 때가 여기 걸린다.
func _unreachable(agent: ProtoUnitAgent) -> bool:
	var order: MoveOrder = _order_cache.get(agent.order_id, null)
	if order == null:
		return false
	var cell := grid.world_to_cell(agent.position)
	# 벽에 끼어 있는 순간은 판단하지 않는다. 다음 프레임에 빠져나온다.
	if not grid.is_walkable(cell):
		return false
	return not order.flow.is_reachable(cell)


## 지형에 몸이 낀 것을 알아채는 마지막 그물. 평상시에는 걸리지 않는다.
func _watch_grinding(agent: ProtoUnitAgent, distance: float) -> void:
	if distance < agent.best_distance - 0.5:
		agent.best_distance = distance
		agent.grind_frames = 0
		return
	agent.grind_frames += 1
	if agent.grind_frames < _GRIND_FRAMES:
		return
	if distance < agent.radius * _SETTLE_REACH:
		agent.settle(ProtoUnitAgent.State.ARRIVED)
	else:
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
