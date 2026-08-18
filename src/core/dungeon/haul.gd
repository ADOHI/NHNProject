class_name Haul
extends RefCounted
## 주체가 지금 들고 있는 것과, 판이 끝났을 때 남은 것.
##
## docs/design/05-rules.md §5.3 이 익스트랙션의 핵심 규칙을 확정했다.
##
## | 구분 | 사망 시 | 탈출 시 |
## | --- | --- | --- |
## | 던전에서 주운 전리품 | **상실** | 획득 확정 |
##
## **잃는 것은 물건뿐이다. 사람은 잃지 않는다** (docs/design/14-squad.md §14.6).
## 그래서 이 클래스는 대원이 아니라 **값**만 센다.
##
## ## 사망 정산이 있는데 부르는 곳이 없다 — 의도된 것이다
##
## §5.3 은 확정이고 §5.5(전투 판정)는 미정이다. 규칙은 이미 있고 없는 것은
## *"언제 죽는가"* 뿐이다. 규칙을 시험까지 걸어 두면 전투가 붙을 때
## 정산을 다시 설계하지 않아도 된다 (docs/design/33-turn-loop.md §33.3).
##
## ## 플레이어만의 것이 아니다
##
## NPC 탐험가도 같은 규칙 아래 줍고 나간다 (§5.2.2). 그래서 주체 id 로 센다 —
## 플레이어만 특별히 세는 순간 "늦게 가면 이미 털려 있다"가 코드에서 성립하지 않는다.

## 주체 id -> 지금 들고 있는 값. **아직 내 것이 아니다.**
var _carried: Dictionary = {}

## 주체 id -> 확정된 값. 탈출로 지켜 낸 것이다.
var _banked: Dictionary = {}


func add(actor_id: String, value: int) -> void:
	if value <= 0:
		return
	_carried[actor_id] = carried_by(actor_id) + value


func carried_by(actor_id: String) -> int:
	return int(_carried.get(actor_id, 0))


func banked_by(actor_id: String) -> int:
	return int(_banked.get(actor_id, 0))


func is_carrying(actor_id: String) -> bool:
	return carried_by(actor_id) > 0


## 탈출했다. 들고 있던 것이 **확정 획득**이 된다. 확정된 값을 돌려준다.
func settle_escape(actor_id: String) -> int:
	var value := carried_by(actor_id)
	_carried.erase(actor_id)
	if value > 0:
		_banked[actor_id] = banked_by(actor_id) + value
	return value


## 쓰러졌다. 들고 있던 것을 **전부 잃는다.** 잃은 값을 돌려준다.
##
## 이미 확정된 것(`_banked`)은 건드리지 않는다 — 그건 지난 판에 지켜 낸 것이다.
func settle_death(actor_id: String) -> int:
	var value := carried_by(actor_id)
	_carried.erase(actor_id)
	return value


## 판 위에서 아직 누군가의 손에 들려 있는 값의 합.
##
## **아직 아무의 것도 아니다.** 이 값이 크면 그만큼 판에 걸린 것이 많다는 뜻이고,
## 그것이 곧 렉카가 달려들 이유다.
func total_carried() -> int:
	var total := 0
	for actor_id in _carried:
		total += int(_carried[actor_id])
	return total
