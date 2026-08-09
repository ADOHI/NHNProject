class_name ProtoUnitStep
extends RefCounted
## **걸음 고르기.** 이 방향으로 얼마나 갈 수 있는지 재고, 막혔으면 후보를 재어 하나 고른다.
##
## 이동 본체(`unit_field.gd`)에서 갈라 둔 이유는 `unit_yield.gd`, `unit_push.gd`, `unit_jam.gd`
## 와 같다. 본체가 천 줄 한계에 닿았다. 그리고 이 묶음은 **한 가지 물음만 답한다** —
## 힘이 없어진 판에서 남는 유일한 물음, **"저기로 갈 수 있는가 없는가."**
##
## 이 한 묶음이 예전의 분리력 · 접촉 제약 · 위치 자르기 · 겹침 해소를 통째로 대신한다.
## 넷 다 "얼마나 세게 밀까"를 물었고, 이것은 "갈 수 있는가"를 묻는다.
##
## **이웃 목록은 부르는 쪽이 채워 준다.** 여기서 다시 훑으면 후보마다 이웃 훑기가 붙어
## 유닛당 열두 벌이 된다. `_walk` 이 이미 한 번 모아 둔 것을 그대로 돌려 쓴다.

## "내 앞"으로 치는 각도의 코사인. 0.55 는 대략 좌우 57 도다.
const AHEAD_CONE := 0.55

## 기다림에서 풀려나려면 막은 아군이 이만큼은 떨어져 있어야 한다(픽셀).
##
## 들어갈 때보다 나올 때의 문턱을 넓게 둔다. **시간이 아니라 거리로 준 여유다.**
## 같은 문턱을 쓰면 경계에 걸친 유닛이 섰다 갔다를 반복한다.
const HOLD_RELEASE := 10.0

## 앞의 빈 거리를 이만큼까지만 잰다(픽셀).
##
## 여기까지 트여 있으면 후보를 재지 않고 그냥 간다. **잼에 낀 유닛만 후보 값을 치른다.**
## 최대 속도 230 에서 제동 거리가 10 픽셀 남짓이므로 32 는 브레이크를 밟기에 넉넉하고,
## 이웃 조회 칸 크기를 여기에 맞추므로 크게 잡으면 그대로 유닛당 이웃 수가 된다.
const LOOKAHEAD := 32.0

## 벽 거리가 이 칸 이상이면 벽이 없는 것으로 본다.
##
## 세 칸이면 96 픽셀이라 몸 반지름 12 에 내다보는 거리 32 를 더해도 벽에 닿을 수 없다.
const WALL_CLEAR := 3

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

## 벽까지의 빈 거리를 잴 때 훑는 걸음(픽셀).
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

## 벽까지의 빈 거리를 이 거리까지만 촘촘히 훑는다(픽셀). 그 너머는 몸이 정하는 값을 쓴다.
const _WALL_NEAR := 15.0


## 갈 방향을 **고른다.** 앞이 트여 있으면 고를 것이 없다.
##
## 힘이 아니다 - 힘은 이웃이 있기만 하면 늘 걸리지만 여기서는 **앞이 막혔을 때만** 후보를
## 재고 하나를 고른다. 점수는 "가고 싶던 방향으로 얼마나 나아가는가"라, 정면이 트이는 순간
## 반드시 정면이 이긴다. 전부 막히면 **그 자리에 선다** - 서는 것은 올바른 결과다.
##
## **드는 문턱과 푸는 문턱을 따로 둔다.** 하나로 두었더니 열린 방 꺾임이 33 에서 217 로
## 뛰었다. 문턱 하나면 매 프레임 우회가 켜졌다 꺼졌다 하고 **그 켜짐 자체가 지터였다** -
## 힘으로 만들던 왕복을 고르기로 되풀이한 셈이다.
static func choose(
	field: ProtoUnitField,
	agent: ProtoUnitAgent,
	want_dir: Vector2,
	neighbors: Array[ProtoUnitAgent]
) -> float:
	var straight := room(field, agent, want_dir, true, neighbors)
	if agent.detour != 0.0:
		if straight >= _DETOUR_RELEASE:
			agent.detour = 0.0
			return straight
		var keep := room(field, agent, want_dir.rotated(agent.detour), false, neighbors)
		if keep >= _DETOUR_ENTER:
			return keep
	elif straight >= _DETOUR_ENTER:
		return straight

	var best_score := straight * (1.0 + _SIDE_CREDIT)
	var best_angle := 0.0
	var best_room := straight
	for degrees in _DETOUR_ANGLES:
		var angle := deg_to_rad(degrees)
		var reach := room(field, agent, want_dir.rotated(angle), false, neighbors)
		var score := reach * (cos(angle) + _SIDE_CREDIT)
		if score > best_score:
			best_score = score
			best_angle = angle
			best_room = reach
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
			var reach := room(field, agent, want_dir.rotated(angle), false, neighbors)
			if reach > best_room:
				best_room = reach
				best_angle = angle
	agent.detour = best_angle
	return best_room


## 회전 속도 제한. **자기 몸의 한계이지 이웃이 주는 힘이 아니다.**
static func turn_toward(
	field: ProtoUnitField, agent: ProtoUnitAgent, wanted: Vector2, delta: float
) -> Vector2:
	var max_turn := deg_to_rad(field.tuning.get_value("turn_rate")) * delta
	var difference := wrapf(wanted.angle() - agent.facing, -PI, PI)
	agent.facing += clampf(difference, -max_turn, max_turn)
	return Vector2.from_angle(agent.facing)


## 이 방향으로 **얼마나 갈 수 있는가**(픽셀). 이웃의 몸과 벽까지의 빈 거리다.
##
## 이미 겹쳐 있으면 다가가는 방향만 0 이라 **더 겹치는 걸음만 금지**되고 빠져나오는 걸음은
## 열려 있다. `note_block` 이 참이면 나를 세운 것이 누구인지도 함께 적는다(훑기 한 벌을 아낀다).
static func room(
	field: ProtoUnitField,
	agent: ProtoUnitAgent,
	direction: Vector2,
	note_block: bool,
	neighbors: Array[ProtoUnitAgent]
) -> float:
	var limit := LOOKAHEAD
	# 직전에 지목한 놈을 기억해 둔다. 그놈만은 더 벌어질 때까지 계속 지목한다.
	var held := agent.blocker_id if note_block else 0
	if note_block:
		agent.blocked_by_settled = false
		agent.pressed = false
		agent.blocker_id = 0
	for other in neighbors:
		var offset := other.position - agent.position
		var distance := offset.length()
		var minimum := agent.radius + other.radius
		var along := offset.dot(direction)
		if distance < minimum:
			field.max_penetration = maxf(field.max_penetration, minimum - distance)
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
		var head_on := along / maxf(distance, 0.001) >= AHEAD_CONE
		if not note_block or not head_on:
			continue
		var enter := _DETOUR_ENTER + ProtoUnitPush.BLOCK_KEEP if other.id == held else _DETOUR_ENTER
		if reach < enter:
			agent.pressed = true
			agent.blocker_id = other.id
		if not other.is_moving() and distance <= minimum + HOLD_RELEASE:
			agent.blocked_by_settled = true
	return minf(limit, _wall_room(field, agent, direction, limit))


## 벽까지의 빈 거리. 몸이 들어가는지를 걸음마다 확인한다.
static func _wall_room(
	field: ProtoUnitField, agent: ProtoUnitAgent, direction: Vector2, limit: float
) -> float:
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
		if not field.grid.is_circle_free(agent.position + direction * travelled, agent.radius):
			return free
		free = travelled
		travelled += _WALL_STEP
	if not field.grid.is_circle_free(agent.position + direction * near, agent.radius):
		return free
	return limit
