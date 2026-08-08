class_name ProtoUnitField
extends RefCounted
## 방 하나 안의 유닛 전부와 그들의 이동. **이 레인의 본체다.**
##
## 조작감이 갈리는 네 지점을 여기서 처리한다.
##
## | 지점 | 여기서의 처리 |
## | --- | --- |
## | 뭉침 | 대형 자리 배정(각자 다른 목표) + **빈 자리로만 걷기** |
## | 도착 | 감속 반경 · 도착 반경 · **상태로 묻는 정지 판정** (`_update_states`) |
## | 반응 | 가속과 회전 제한만으로 지연을 만든다. 명령 처리 자체는 그 프레임에 끝낸다 |
## | 대형 | 명령마다 남은 거리를 비교해 앞선 유닛의 속도를 깎는다 |
## | 지터 | 조향 평활 + **싸울 힘 자체를 없앤 것** (아래) |
##
## **이 게임은 물리력 게임이 아니다. 유닛은 남을 밀 수도, 남에게 밀릴 수도 없다.**
##
## 그래서 여기에는 **이웃이 서로에게 주는 힘이 하나도 없다.** 분리력 · 옆으로 비껴가기 ·
## 양보 · 겹침 해소 · 접촉 제약을 전부 걷어냈다. 조금씩 줄이는 방향으로 두 번 시도했고
## 두 번 다 지터가 남았다. 남은 힘이 늘 조향과 싸웠기 때문이다 — 조향이 한쪽을 가리키는데
## 힘이 몸을 다른 쪽으로 옮기면, 다음 프레임 조향은 옮겨진 자리에서 방향을 다시 잡는다.
## 그 되먹임이 지터의 정체다. **싸울 힘이 없으면 안 싸운다.**
##
## 힘이 없으면 남는 질문은 하나뿐이다 — **"저기로 갈 수 있는가 없는가."**
##
## | 차례 | 하는 일 | 어디 |
## | --- | --- | --- |
## | 1 | 가고 싶은 방향을 정한다 (자리가 보이면 직선, 아니면 흐름장) | `_plan` `_seek` |
## | 2 | 그 방향의 **빈 거리**를 잰다 (이웃의 몸과 벽까지) | `_room` |
## | 3 | 앞이 막혔으면 좌우로 벌린 후보를 같이 재고 하나 **고른다** | `_choose_step` |
## | 4 | 빈 거리 안에 멈출 수 있는 속력으로 줄인다 (내 브레이크다) | `_walk` |
## | 5 | 고른 방향으로도 못 가면 **그 자리에 선다** | `_walk` · `_update_states` |
##
## **남을 움직이는 코드가 한 줄도 없다.** 유닛은 자기 위치만 바꾸고 그 위치는 반드시 비어
## 있는 자리다. 그래서 몸이 겹칠 수 없고, 겹친 뒤에 떼어 놓을 일도 없다. 유닛 번호 순으로
## 처리해 앞선 유닛의 **새 위치**를 보므로 둘이 같은 자리를 동시에 차지하지도 못한다.
##
## 노드에 의존하지 않는다. 화면은 이 상태를 읽어 그리기만 한다.


## 이동 명령 한 건. 흐름장과 대형 자리를 명령 단위로 들고 있다가 소속 유닛이 모두 멎으면 사라진다.
class MoveOrder:
	var id: int
	var target: Vector2
	var flow: ProtoFlowField
	var slots := PackedVector2Array()
	var member_ids := PackedInt32Array()

	## 칸마다 "여기 막혀 있다"를 몇 번 더 믿어 줄지. 0 이면 안 막혔다.
	##
	## **기억의 주인은 유닛이 아니라 명령을 받은 무리다.** 유닛마다 들면 흐름장을 유닛마다
	## 구워야 하고 그건 8 밀리초 곱하기 인원이다. 무리가 공유하면 한 번으로 끝난다.
	## 대가는 한 명이 막힌 것을 전원이 피하는 것인데, 같은 목적지로 같이 가는 무리라
	## 실제로 같은 곳에서 막힌다.
	var jam := PackedByteArray()

	## 이 명령의 흐름장을 마지막으로 다시 구운 프레임.
	var baked_frame := 0

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

## 앞의 빈 거리를 이만큼까지만 잰다(픽셀).
##
## 여기까지 트여 있으면 후보를 재지 않고 그냥 간다. **잼에 낀 유닛만 후보 값을 치른다.**
## 최대 속도 230 에서 제동 거리가 10 픽셀 남짓이므로 32 는 브레이크를 밟기에 넉넉하고,
## 이웃 조회 칸 크기를 여기에 맞추므로 크게 잡으면 그대로 유닛당 이웃 수가 된다.
const _LOOKAHEAD := 32.0

## 앞이 막혔을 때 재어 보는 좌우 후보의 각도(도). 0 은 늘 함께 잰다.
##
## **90 도가 반드시 있어야 한다.** 처음에 55 도까지만 두었더니 좁은 문 앞에서 마흔 명이
## 전원 속력 0 으로 얼어붙었다. 벽에 몸을 붙인 유닛은 벽면을 따라 **정확히 옆으로** 미끄러지는
## 것 말고 나갈 길이 없는데, 조금이라도 벽 쪽 성분이 남으면 몸이 벽에 걸려 빈 거리가 0 이 된다.
##
## 90 도를 넘기지는 않는다. 뒤로 물러나는 후보를 주면 잼에서 유닛이 뒷걸음질하고, 그러면
## 뒤에 선 유닛이 또 밀려 나는 연쇄가 생긴다 — 밀치기를 힘 없이 되살리는 셈이다.
## 전부 막히면 **선다.**
const _DETOUR_ANGLES: Array[float] = [35.0, -35.0, 65.0, -65.0, 90.0, -90.0]

## 옆걸음에 주는 최소 점수 비율.
##
## 점수를 코사인만으로 매기면 90 도는 0 이라 아무리 트여 있어도 뽑히지 않는다. 그런데
## **벽을 따라 문으로 미끄러지는 걸음이 정확히 90 도다.** 작은 값을 얹어 두면, 앞이 완전히
## 막혔을 때만 옆걸음이 이기고 정면이 조금이라도 트이면 언제나 정면이 이긴다.
const _SIDE_CREDIT := 0.15

## 앞으로도 옆으로도 못 갈 때 마지막으로 재어 보는 **물러나는** 후보의 각도(도).
##
## 벽면에 몸을 붙인 채 문 옆에 선 유닛은 어느 쪽으로 가도 몸이 벽에 걸린다. 실제로 열두 명
## 판에서 유닛 하나가 문 5 픽셀 옆에 그렇게 끼었고, **그 하나가 문을 막아 뒤의 넷을 통째로
## 세웠다.** 물러나기는 힘이 아니라 선택이고, 물러나야 다른 길이 생긴다.
const _BACKOFF_ANGLES: Array[float] = [120.0, -120.0, 155.0, -155.0, 180.0]

## 한 걸음도 못 간 채 이만큼 지나야 물러나는 후보를 연다(프레임).
##
## 늘 열어 두면 조금만 막혀도 뒷걸음질하고, 그 뒷걸음질이 뒤에 선 유닛에게는 밀치기와
## 똑같이 보인다. 3 분의 1 초는 사람이 "얘가 끼었네" 하고 알아볼 만한 시간이기도 하다.
const _BACKOFF_FRAMES := 20

## 이보다 좁으면 "이번 걸음을 못 걷는다"로 보고 우회 후보를 잰다(픽셀).
##
## 최대 속도 230 이면 한 프레임에 3.8 픽셀 간다. 그보다 조금 넉넉한 값이라, **정말 걸을 수
## 없을 때만** 우회가 켜진다.
const _DETOUR_ENTER := 10.0

## 우회를 풀려면 정면이 이만큼은 트여야 한다(픽셀).
##
## 드는 문턱과 같게 두면 경계에서 켜졌다 꺼졌다 하고, 그 깜빡임이 그대로 방향의 왕복이 된다.
const _DETOUR_RELEASE := 24.0

## 벽까지의 빈 거리를 잴 때 훑는 걸음(픽셀)과 그 걸음으로 훑을 최대 거리(픽셀).
##
## 벽을 안 보면 후보 고르기가 유닛을 벽으로 몰아넣고, 그러면 `push_out` 이 몸을 통째로
## 옮긴다. 그 옮김이 예전에 앞을 막은 아군 여섯을 통과시킨 바로 그 경로다.
##
## **걸음이 굵으면 문 앞에서 통째로 굳는다.** 처음에 몸 반지름만큼(11 픽셀) 훑었더니
## 문에 몸을 맞추려고 비스듬히 가려는 유닛이 첫 표본에서 벽에 걸려 빈 거리 0 을 받았다.
## 실제로는 5 픽셀쯤 갈 수 있었는데 못 간 것이고, 그 5 픽셀이 문에 몸을 맞추는 거리였다.
## 마흔 명이 문 앞에서 전원 속력 0 으로 얼어붙은 것이 이 한 줄 때문이었다.
##
## 벽은 움직이지 않으므로 멀리까지 볼 필요가 없다. 가까운 곳만 촘촘히 보고, 그 너머는
## 몸이 정하는 빈 거리를 그대로 쓴다 - 표본 수를 다섯으로 묶는 방법이기도 하다.
const _WALL_STEP := 3.0

## 벽 거리가 이 칸 이상이면 벽이 없는 것으로 본다.
##
## 세 칸이면 96 픽셀이라 몸 반지름 12 에 내다보는 거리 32 를 더해도 벽에 닿을 수 없다.
const _WALL_CLEAR := 3

## 벽까지의 빈 거리를 이 거리까지만 촘촘히 훑는다(픽셀). 그 너머는 몸이 정하는 값을 쓴다.
const _WALL_NEAR := 15.0

## 최단 거리가 줄지 않은 채 이만큼 지나면 지형에 낀 것으로 본다(프레임).
##
## **이것은 포기 시간이 아니다.** 아군이 막은 경우는 상태로 걸러지고 목적지가 갈린 경우는
## 흐름장이 즉시 답하므로, 여기까지 오는 것은 아군도 벽도 아닌 지형에 몸이 낀 경우뿐이다.
## 그 경우엔 시간 말고 볼 것이 없다. 손맛을 위해 만지는 값이 아니라 무한 루프를 막는
## 안전장치이므로 슬라이더로 내보내지 않는다. 평상시에는 걸리지 않아야 정상이다.
const _GRIND_FRAMES := 240

## 지형에 낀 것으로 보고 기다림으로 떨어뜨려 볼 횟수. 이만큼 해 보고도 안 되면 정말 그만둔다.
##
## 0 으로 두면 곧바로 포기하고, 그 몸이 벽이 되어 뒤를 막는다. 무한히 두면 아무도 안 멎는다.
const _HOLD_RETRIES := 3

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

## 지형 보정(`push_out`)이 위치를 강제로 옮긴 누적 거리(픽셀).
##
## **겹침 해소가 없어진 지금 위치를 직접 옮기는 것은 이것 하나뿐이다.** 평상시에는 0 이어야
## 하고, 0 이 아니면 몸이 벽 안에 들어간 것이다. 재는 쪽에서 0 으로 되돌린다.
var overlap_push_total: float = 0.0

## 한 프레임에 위치가 순간이동한 최댓값(픽셀). **눈에 튕김으로 보이는 것이 이것이다.**
##
## 속도 적분을 거치지 않고 위치가 뛰면 사람은 그것을 튕김으로 본다. 걸음 고르기는 위치를
## 뛰게 만들지 않으므로 여기 잡히는 것은 지형 보정뿐이다.
var overlap_push_peak: float = 0.0

## **서 있는 유닛이 제 뜻과 무관하게 옮겨진 누적 거리(픽셀). 밀치기의 직접 계기다.**
##
## "밀치기를 없앴다"는 말은 증명할 수 있어야 한다. 이 값이 0 이 아니면 없애지 못한 것이다.
## 이제 유닛끼리 미는 코드가 아예 없으므로 여기 잡힐 수 있는 것은 지형 보정뿐이고,
## 그것도 서 있는 유닛에게 일어나면 안 된다.
var settled_push_total: float = 0.0

## 몸이 서로 파고든 최대 깊이(픽셀). **통과가 일어났는지 보는 계기다.**
##
## 한 유닛이 다른 유닛을 통과하려면 그 전에 반드시 겹침이 몸 지름까지 자라야 한다.
## 빈 자리로만 걸으면 겹침은 애초에 자랄 수 없고, 이 값이 그것을 보여 준다.
var max_penetration: float = 0.0

## 가고 싶었으나 앞이 막혀 가지 못한 누적 거리(픽셀). **막힘의 크기다.**
##
## 예전에는 이 거리가 남의 몸을 밀어내는 데 쓰였다. 지금은 어디에도 쓰이지 않고 그냥
## 사라진다 — 그것이 "밀고 갈 수 없다"의 실체다.
var blocked_move_total: float = 0.0

## 마지막 명령에서 흐름장을 만드는 데 걸린 시간(마이크로초).
##
## **이것이 지금까지 지표에 안 잡히던 값이다.** 지표 도구는 명령 한 번 주고 40 초를 굴리므로
## 명령 한 번의 비용은 평균에 묻힌다. `last_step_usec` 은 매 프레임 조향 비용이라 이것을
## 아예 안 센다. 그런데 이 계산은 **우클릭을 처리하는 그 프레임 안에서 동기로 돈다** -
## 크면 클릭할 때마다 화면이 멎는다. 안 보이던 값이라 따로 낸다.
var flow_build_usec: int = 0

## 명령마다 잰 흐름장 생성 시간의 최댓값(마이크로초). 사람은 평균이 아니라 최악을 느낀다.
var flow_build_peak: int = 0

## 막힘을 알고 흐름장을 다시 구운 횟수. **굽는 빈도가 곧 프레임 위험이다.**
var rebake_count: int = 0

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
	var flow_started := Time.get_ticks_usec()
	order.flow = grid.build_flow_field(safe_target)
	flow_build_usec = Time.get_ticks_usec() - flow_started
	flow_build_peak = maxi(flow_build_peak, flow_build_usec)

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

	order.baked_frame = _frame
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
		# 벽이 내다보는 거리 밖에 있는가. 한 번 물어 두고 이 프레임 내내 쓴다.
		agent.wall_far = grid.clearance_at(grid.world_to_cell(agent.position)) >= _WALL_CLEAR
	_update_pace()
	# **뜻과 결과를 두 벌로 나눈다.** 먼저 전원이 이웃을 보지 않고 가고 싶은 방향을 정하고,
	# 그다음에 순서대로 실제로 걷는다. 걷는 쪽만 이웃을 보므로 "가고 싶었던 것"이 남의
	# 사정에 오염되지 않는다.
	for agent in agents:
		_plan(agent, delta)
	ProtoUnitYield.apply(self, delta)
	_walk(delta)
	_clamp_positions()
	_update_states(delta)
	ProtoUnitJam.review(self, _frame)
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
## 칸 크기는 **몸이 닿는 거리와 내다보는 거리 중 큰 쪽**이다. 3x3 을 훑으면 칸 크기만큼
## 떨어진 이웃까지 반드시 잡히는데, 칸이 몸 지름 + 한 프레임 이동 거리보다 작으면 부딪힐
## 이웃을 놓쳐 몸끼리 통과한다. 통과 금지는 슬라이더가 어디에 있든 지켜져야 한다.
##
## 분리 반경이 없어져 칸이 40 에서 32 로 작아졌다. 유닛당 이웃 수가 그대로 줄어든다.
func _rebuild_buckets() -> void:
	var body := 1.0
	for agent in agents:
		body = maxf(body, agent.radius)
	var contact := body * 2.0 + tuning.get_value("max_speed") / 60.0 + 1.0
	_bucket_size = maxf(_LOOKAHEAD, contact)
	_buckets.clear()
	for agent in agents:
		var key := Vector2i(
			floori(agent.position.x / _bucket_size), floori(agent.position.y / _bucket_size)
		)
		if not _buckets.has(key):
			_buckets[key] = [] as Array[ProtoUnitAgent]
		(_buckets[key] as Array[ProtoUnitAgent]).append(agent)


func collect_neighbors(agent: ProtoUnitAgent, into: Array[ProtoUnitAgent]) -> void:
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
		# **기다리는 유닛도 무리에 넣는다.** is_moving 만 보면 앞이 막혀 선 유닛이 셈에서
		# 빠지고, 그러면 선두가 기다릴 이유가 없어져 그대로 달아난다. 힘을 걷어내면서 기다리는
		# 유닛이 크게 늘어 이 구멍이 대열 폭을 두 배 너머로 벌렸다.
		var furthest := 0.0
		for id in order.member_ids:
			var agent: ProtoUnitAgent = _by_id.get(id, null)
			if agent == null:
				continue
			if agent.is_moving() or agent.state == ProtoUnitAgent.State.HOLDING:
				furthest = maxf(furthest, agent.position.distance_to(agent.goal))
		if furthest <= 0.001:
			continue
		for id in order.member_ids:
			var agent: ProtoUnitAgent = _by_id.get(id, null)
			if agent == null or not agent.is_moving():
				continue
			var share := clampf(agent.remaining() / furthest, _MIN_PACE, 1.0)
			agent.pace = lerpf(1.0, share, sync)


## 이번 프레임에 **가고 싶은 방향과 속력**을 정한다. 이웃은 보지 않는다.
##
## 이웃을 보는 것은 다음 단계(`_walk`)의 일이고, 여기서는 순수하게 "나는 어디로 가려는가"만
## 답한다. 예전에는 이 함수 안에서 분리력을 더하고 접촉 제약을 걸어 **뜻과 사정이 뒤섞였다.**
## 갈라 두면 지표에서도 갈라 볼 수 있다 - `debug_seek` 이 뜻이고 `velocity` 가 결과다.
func _plan(agent: ProtoUnitAgent, delta: float) -> void:
	# 비켜주기는 이 뒤에 돈다. 여기서 비워 두면 그 프레임에 옮겨진 만큼만 담긴다.
	agent.yield_shift = Vector2.ZERO
	if not agent.is_moving():
		agent.speed = maxf(agent.speed - tuning.get_value("acceleration") * delta, 0.0)
		agent.velocity = Vector2.ZERO
		agent.debug_seek = Vector2.ZERO
		return

	var wanted := _seek(agent, delta)
	var target_speed := tuning.get_value("max_speed") * agent.speed_scale * agent.pace
	var slow := tuning.get_value("slow_radius")
	if agent.goal_distance < slow:
		target_speed *= clampf(agent.goal_distance / maxf(slow, 0.001), 0.05, 1.0)
	agent.debug_seek = wanted * target_speed


## 자기 자리를 향한 방향. 보이면 직선, 안 보이면 흐름장. **여기까지는 예전과 같다.**
func _seek(agent: ProtoUnitAgent, delta: float) -> Vector2:
	agent.sight_timer -= delta
	if agent.sight_timer <= 0.0:
		agent.sight_timer = _SIGHT_INTERVAL
		agent.has_sight = grid.has_line_of_sight(agent.position, agent.goal, agent.radius)

	var to_goal := agent.goal - agent.position
	var direction := to_goal / agent.goal_distance if agent.goal_distance > 0.001 else Vector2.ZERO
	if not agent.has_sight:
		var order: MoveOrder = _order_cache.get(agent.order_id, null)
		if order != null:
			direction = order.flow.direction_at(agent.position, agent.radius)
	agent.steer_dir = _smoothed(agent.steer_dir, direction, delta)
	return agent.steer_dir


## 조향 방향을 평활한다. **힘이 아니라 목표를 다듬는 장치다.**
##
## 흐름장을 칸 사이로 섞어 읽어도 남는 뜀이 있다. 목적지가 보이는지 아닌지가 뒤집히는 순간
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


## 걷는다. **빈 자리로만 간다. 남을 옮기는 코드는 여기에 없다.**
##
## 유닛 번호 순으로 처리해 앞선 유닛의 **새 위치**를 본다. 전원의 옛 위치로 한꺼번에 판단하면
## 둘이 같은 빈 자리로 동시에 들어가고, 그러면 겹침을 사후에 풀어야 한다 - 그것이 바로
## 걷어낸 장치다. 처리 순서가 번호 순이라 프레임마다 뒤바뀌지도 않는다.
func _walk(delta: float) -> void:
	if delta <= 0.0:
		return
	var acceleration := tuning.get_value("acceleration")
	for agent in agents:
		if not agent.is_moving():
			agent.advance = Vector2.ZERO
			continue
		collect_neighbors(agent, _scratch)
		var target_speed := agent.debug_seek.length()
		if target_speed <= 0.001:
			agent.speed = maxf(agent.speed - acceleration * delta, 0.0)
			agent.velocity = Vector2.ZERO
			agent.advance = Vector2.ZERO
			continue

		var want_dir := agent.debug_seek / target_speed
		var room := _choose_step(agent, want_dir)
		var heading := _turn_toward(agent, want_dir.rotated(agent.detour), delta)
		# 고른 방향과 회전 제한을 거친 방향이 다르므로 빈 거리를 실제로 갈 방향으로 다시 잰다.
		room = minf(room, _room(agent, heading, false))

		# **부딪히기 전에 선다.** 빈 거리 안에서 멈출 수 있는 속력이 상한이다. 이웃이 나에게
		# 주는 힘이 아니라 내가 내 브레이크를 밟는 것이고, 앞선 유닛이 천천히 가면 나도
		# 천천히 따라가는 줄서기가 여기서 저절로 나온다.
		var brake := sqrt(2.0 * maxf(acceleration, 1.0) * maxf(room, 0.0))
		agent.speed = move_toward(agent.speed, minf(target_speed, brake), acceleration * delta)
		var travel := minf(agent.speed * delta, maxf(room, 0.0))
		blocked_move_total += maxf(target_speed * delta - travel, 0.0)
		var moved := heading * travel
		agent.position += moved
		agent.velocity = moved / delta
		agent.advance = agent.velocity
		# 실제로 못 간 만큼 속력도 줄인다. 남겨 두면 다음 프레임에 있지도 않은 관성으로
		# 몸이 튀어 나가고, 그 튐이 곧 통과의 씨앗이다.
		agent.speed = minf(agent.speed, travel / delta)
		agent.stall_frames = 0 if travel > 0.01 else agent.stall_frames + 1


## 갈 방향을 **고른다.** 앞이 트여 있으면 고를 것이 없다.
##
## 이것은 옆으로 미는 힘이 아니다. 힘은 이웃이 있기만 하면 늘 걸리고 합쳐져 방향을 정하지만,
## 여기서는 **앞이 막혔을 때만** 후보를 재고 그중 하나를 고른다. 고른 것에는 다음 프레임에
## 가산점이 붙어 갈팡질팡하지 않는다.
##
## 점수는 "가고 싶던 방향으로 얼마나 나아가는가"다. 옆으로 크게 도는 후보는 코사인이 작아
## 웬만큼 트여 있지 않으면 뽑히지 않고, 정면이 트이는 순간 반드시 정면이 이긴다.
##
## 후보가 전부 막히면 0 을 돌려준다. 그러면 유닛은 **그 자리에 선다.** 서 있는 것은 실패가
## 아니라 올바른 결과다.
##
## **드는 문턱과 푸는 문턱을 따로 둔다.** 하나로 두었더니 열린 방에서 꺾임이 33 에서 217 로
## 뛰었다. 대형 간격이 30 픽셀이라 이웃이 늘 앞에 있고, 문턱 하나면 매 프레임 우회가 켜졌다
## 꺼졌다 하면서 방향이 30 도씩 널뛰었다. **켜짐 자체가 지터였다** — 힘으로 만들던 것과
## 똑같은 왕복을 고르기로 되풀이한 것이다. 드는 문턱을 "이번 걸음을 못 걷는다"로 좁히고,
## 푸는 문턱을 그보다 훨씬 넓게 잡아 한번 돌기 시작하면 정면이 확실히 트일 때까지 돈다.
func _choose_step(agent: ProtoUnitAgent, want_dir: Vector2) -> float:
	var straight := _room(agent, want_dir, true)
	if agent.detour != 0.0:
		if straight >= _DETOUR_RELEASE:
			agent.detour = 0.0
			return straight
		var keep := _room(agent, want_dir.rotated(agent.detour), false)
		if keep >= _DETOUR_ENTER:
			return keep
	elif straight >= _DETOUR_ENTER:
		return straight

	var best_score := straight * (1.0 + _SIDE_CREDIT)
	var best_angle := 0.0
	var best_room := straight
	for degrees in _DETOUR_ANGLES:
		var angle := deg_to_rad(degrees)
		var room := _room(agent, want_dir.rotated(angle), false)
		var score := room * (cos(angle) + _SIDE_CREDIT)
		if score > best_score:
			best_score = score
			best_angle = angle
			best_room = room
	# 굳었는지를 **두 가지로 묻는다.** 한 걸음도 못 걸었거나 `stall_frames`, 걷기는 걷는데
	# 목적지가 가까워지지 않거나 `grind_frames`. 앞엣것만 보았더니 벽에 몸을 비비며
	# 프레임당 0.5 픽셀씩 흔들리는 유닛이 영원히 굳은 것으로 세이지 않았다.
	if (
		best_room < _DETOUR_ENTER
		and maxi(agent.stall_frames, agent.grind_frames) >= _BACKOFF_FRAMES
	):
		# 앞도 옆도 전부 막힌 채 오래 굳었다. **물러나는 것도 길이다.**
		for degrees in _BACKOFF_ANGLES:
			var angle := deg_to_rad(degrees)
			var room := _room(agent, want_dir.rotated(angle), false)
			if room > best_room:
				best_room = room
				best_angle = angle
	agent.detour = best_angle
	return best_room


## 회전 속도 제한. **자기 몸의 한계이지 이웃이 주는 힘이 아니다.**
func _turn_toward(agent: ProtoUnitAgent, wanted: Vector2, delta: float) -> Vector2:
	var max_turn := deg_to_rad(tuning.get_value("turn_rate")) * delta
	var difference := wrapf(wanted.angle() - agent.facing, -PI, PI)
	agent.facing += clampf(difference, -max_turn, max_turn)
	return Vector2.from_angle(agent.facing)


## 이 방향으로 **얼마나 갈 수 있는가**(픽셀). 이웃의 몸과 벽까지의 빈 거리다.
##
## 이 한 함수가 예전의 분리력 · 접촉 제약 · 위치 자르기 · 겹침 해소를 통째로 대신한다.
## 넷 다 "얼마나 세게 밀까"를 물었고, 이것은 "갈 수 있는가"를 묻는다.
##
## 이웃마다 광선과 원의 교차를 푼다. 지나쳐 가는 이웃(수직 거리가 몸 지름보다 먼)은 걸리지
## 않으므로, 스쳐 지나가는 데에 아무 값도 치르지 않는다.
##
## **이미 겹쳐 있으면 다가가는 방향은 0 이고 멀어지는 방향은 막지 않는다.** 스폰이나 지형
## 보정이 만든 겹침이 여기 걸리는데, 겹침을 힘으로 푸는 대신 **더 겹치는 걸음을 금지**하면
## 유닛이 스스로 빠져나오는 걸음만 고르게 된다.
##
## `note_block` 이 참이면 나를 세운 것이 **이미 자리를 잡은 아군**인지도 함께 표시한다.
## 그 판정 하나를 위해 이웃을 또 훑으면 유닛이 늘 때 비용이 배로 든다.
func _room(agent: ProtoUnitAgent, direction: Vector2, note_block: bool) -> float:
	var limit := _LOOKAHEAD
	if note_block:
		agent.blocked_by_settled = false
		agent.pressed = false
		agent.blocker_id = 0
	for other in _scratch:
		var offset := other.position - agent.position
		var distance := offset.length()
		var minimum := agent.radius + other.radius
		var along := offset.dot(direction)
		if distance < minimum:
			max_penetration = maxf(max_penetration, minimum - distance)
			if along <= 0.0:
				continue
			limit = 0.0
			if note_block:
				agent.pressed = true
				agent.blocker_id = other.id
				if not other.is_moving():
					agent.blocked_by_settled = true
			continue
		if along <= 0.0 or along - minimum > limit:
			continue
		var perpendicular := distance * distance - along * along
		if perpendicular >= minimum * minimum:
			continue
		var reach := maxf(along - sqrt(minimum * minimum - perpendicular), 0.0)
		if reach >= limit:
			continue
		limit = reach
		var head_on := along / maxf(distance, 0.001) >= _AHEAD_CONE
		if not note_block or not head_on:
			continue
		if reach < _DETOUR_ENTER:
			agent.pressed = true
			agent.blocker_id = other.id
		if not other.is_moving() and distance <= minimum + _HOLD_RELEASE:
			agent.blocked_by_settled = true
	return minf(limit, _wall_room(agent, direction, limit))


## 벽까지의 빈 거리. 몸이 들어가는지를 걸음마다 확인한다.
##
## 후보 고르기가 벽을 못 보면 유닛을 벽으로 몰아넣고, 그러면 `push_out` 이 몸을 통째로
## 옮긴다. 그 옮김이 예전에 한 칸 복도에서 앞을 막은 아군 여섯을 통과시킨 경로다.
func _wall_room(agent: ProtoUnitAgent, direction: Vector2, limit: float) -> float:
	if limit <= 0.0:
		return 0.0
	# **둘레에 벽이 아예 없으면 표본을 하나도 안 뜬다.** 걸음 고르기는 잼에 낀 유닛마다
	# 후보를 열둘까지 재고 후보마다 벽 표본이 다섯이라, 열린 방에서는 이 검사 하나가
	# 유닛당 예순 번의 `is_circle_free` 를 통째로 걷어낸다. 벽 거리는 지형이 만들어질 때
	# 한 번 구워 둔 값이라 조회가 배열 읽기 한 번이다.
	if agent.wall_far:
		return limit
	var near := minf(limit, _WALL_NEAR)
	var travelled := _WALL_STEP
	var free := 0.0
	while travelled <= near:
		if not grid.is_circle_free(agent.position + direction * travelled, agent.radius):
			return free
		free = travelled
		travelled += _WALL_STEP
	if not grid.is_circle_free(agent.position + direction * near, agent.radius):
		return free
	return limit


## 몸이 벽 안에 들어갔으면 빼낸다. **이것은 유닛 사이의 힘이 아니라 지형 보정이다.**
##
## 걸음 고르기가 벽까지의 빈 거리를 보므로 이동으로는 벽에 들어갈 수 없다. 여기 걸리는 것은
## 스폰이 벽 위에 놓았거나 격자가 바뀐 경우뿐이고, **평상시에는 한 번도 불리지 않아야 정상이다.**
## 그래서 얼마나 옮겼는지를 계기에 남긴다 - 값이 올라가면 어딘가에서 몸이 벽에 들어간 것이다.
func _clamp_positions() -> void:
	var bounds := grid.field_size()
	for agent in agents:
		var before := agent.position
		agent.position.x = clampf(agent.position.x, agent.radius, bounds.x - agent.radius)
		agent.position.y = clampf(agent.position.y, agent.radius, bounds.y - agent.radius)
		if not grid.is_circle_free(agent.position, agent.radius):
			agent.position = grid.push_out(agent.position, agent.radius)
		var warped := before.distance_to(agent.position)
		if warped <= 0.0:
			continue
		overlap_push_total += warped
		overlap_push_peak = maxf(overlap_push_peak, warped)
		if not agent.is_moving():
			settled_push_total += warped


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
	# **막은 것이 서 있는 아군이든 가던 아군이든 똑같이 센다.** 예전에는 서 있는 아군만 셌는데,
	# 힘을 걷어내고 나니 그 조건이 줄서기를 통째로 막았다 — 앞선 유닛도 막혀 서 있을 뿐 상태는
	# `이동`이라, 뒤에 선 유닛은 영원히 "곧 갈 것"이라 믿고 그 자리로 계속 파고들었다.
	# 그렇게 문 앞에 빽빽하게 뭉치고 나면 힘이 없는 판에서는 아무도 자리를 바꿀 수 없다.
	#
	# 지금은 **뭉치기 전에** 선다. 문에 가장 가까운 유닛부터 바깥으로 기다림이 번져 나가
	# 줄이 서고, 앞이 비면 `_review_hold` 가 앞에서부터 하나씩 풀어 준다.
	var progress := agent.goal_distance - distance
	if agent.pressed and progress < crawl:
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
	collect_neighbors(agent, _scratch)
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
##
## **아군의 몸에 눌려 있는 동안은 세지 않는다.** 줄을 서서 못 가는 것과 지형에 낀 것은
## 완전히 다른 일이다. 둘을 "안 나아간다" 하나로 묶었더니 좁은 문에서 백 명 중 일흔이
## 4 초 만에 포기해 버렸고, 포기한 몸이 그대로 벽이 되어 뒤를 통째로 막았다.
## 아군이 막은 경우는 `HOLDING` 이 맡는다 — 그쪽은 비키면 스스로 풀린다.
func _watch_grinding(agent: ProtoUnitAgent, distance: float) -> void:
	if agent.pressed:
		agent.grind_frames = 0
		return
	if distance < agent.best_distance - 0.5:
		agent.best_distance = distance
		agent.grind_frames = 0
		return
	agent.grind_frames += 1
	if agent.grind_frames < _GRIND_FRAMES:
		return
	# **바로 포기시키지 않는다.** 힘을 걷어낸 판에서 그렇게 그만둔 몸은 벽이 되어 문을 통째로
	# 막았다 - 문 옆 5 픽셀에 낀 유닛 하나가 뒤의 넷을 40 초 동안 세웠다. 그래서 몇 번은
	# 기다림으로 떨어뜨려 다시 해 보게 한다.
	#
	# **다만 예산이 있어야 한다.** 무한히 다시 시도하게 두었더니 잼 한가운데의 유닛이
	# 기다림과 이동을 영원히 오가며 멎지 않았고, "전원이 유한 시간에 멎는다"가 무너졌다.
	if distance < agent.radius * _SETTLE_REACH:
		agent.settle(ProtoUnitAgent.State.ARRIVED)
	elif agent.hold_retries < _HOLD_RETRIES:
		agent.hold_retries += 1
		agent.hold()
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
