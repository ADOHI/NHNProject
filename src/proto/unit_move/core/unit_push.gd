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
##
## 비켜주기(초당 140 픽셀)와 달리 이것은 **사건이 있을 때 한 번** 도는 것이라 프레임당이
## 아니다. 몸 반지름 남짓이면 진로에서 벗어나기에 충분하다.
const _NUDGE := 14.0


## 막힌 유닛에서 시작해 사슬을 따라가며 비키라고 말한다. 옮긴 유닛 수를 돌려준다.
static func propagate(field: ProtoUnitField, agent: ProtoUnitAgent) -> int:
	if field.tuning.get_value("propagate") < 0.5:
		return 0
	var scratch: Array[ProtoUnitAgent] = []
	var seen := {}
	var current := agent
	var moved := 0
	seen[current.id] = true
	for _depth in _MAX_DEPTH:
		var heading := current.steer_dir
		if heading == Vector2.ZERO:
			return moved
		var blocker := field.agent_of(current.blocker_id)
		if blocker == null:
			return moved
		if seen.has(blocker.id):
			# 고리다. **억지로 풀지 않는다** - 풀려고 밀면 그것이 대칭이 되고 진동이 된다.
			# 재는 쪽이 볼 수 있게 세어 두기만 한다.
			field.propagate_cycles += 1
			return moved
		seen[blocker.id] = true
		if _step_aside(field, current, blocker, scratch):
			moved += 1
		current = blocker
	return moved


## 앞선 유닛을 진로 밖으로 밀어낸다. 자리가 없으면 안 움직이고 거짓을 돌려준다.
##
## **미는 방향은 앞선 유닛의 뜻이 아니라 뒤에 선 유닛의 진로다.** 뒤가 가려는 길에서
## 비켜서게 하는 것이지 앞을 어디론가 보내는 것이 아니다.
static func _step_aside(
	field: ProtoUnitField,
	behind: ProtoUnitAgent,
	blocker: ProtoUnitAgent,
	scratch: Array[ProtoUnitAgent]
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
	var want := minf(touch - lateral + _MARGIN, _NUDGE)
	var room := ProtoUnitYield.yield_room(field, blocker, away, want, scratch)
	if room <= 0.0:
		return false
	blocker.position += away * room
	blocker.yield_shift += away * room
	blocker.pushed_ago = 0
	field.settled_push_total += room
	# 비켜선 유닛은 다시 가 볼 만하다. 기다리는 중이었으면 깨운다.
	if blocker.state == ProtoUnitAgent.State.HOLDING:
		blocker.resume()
	return true
