class_name TurnSighting
extends RefCounted
## 누가 누구를 봤는가. **E2 가 남기는 유일한 것이다.**
##
## docs/design/05-rules.md §5.6 E2 — 서로 지나쳐 가면
## *"아무 일도 없다. 단 서로를 봤다는 정보는 얻는다"*.
## **뒷문장이 본체다.** 아무 일도 없게 만드는 것은 쉽고, 그러면서 정보만 남기는 것이 어렵다.
##
## ## 왜 조우(`Encounter`)와 따로 두는가
##
## 성질이 반대다 — 조우는 **판을 바꾸고**(그 방의 상호작용이 막힌다),
## 목격은 **아무것도 바꾸지 않는다.** 하나로 묶으면 교차한 두 사람이
## 서로 다른 방에 서 있는데 조우 상태가 되고, 그 순간 E2 가 E1 이 된다.
##
## **조우에서도 목격은 난다.** 같은 방에 섰으면 당연히 본 것이다.
## "봤다"가 두 곳에서 만들어지면 한쪽만 고쳐지고 그때 아무 데도 안 빨개진다
## (docs/conventions.md §6.5).

## 몇 턴에 봤는가.
var turn: int

## 본 쪽.
var observer_id: String

## 보인 쪽.
var seen_id: String

## 보인 쪽의 표시명. 기사가 사건보다 오래 살기 때문에 이름을 함께 남긴다
## (GameEvent 가 같은 이유로 같은 것을 한다).
var seen_name: String

## 어디서 봤는가. 보인 쪽이 **이 턴을 끝낸** 방이다.
##
## 교차(E2)라면 이것이 곧 본 쪽이 방금 떠나온 방이다 —
## "저쪽이 내가 나온 곳으로 들어갔다"가 그대로 정보가 된다.
var room_id: String

## 통로에서 엇갈렸는가. `false` 면 같은 방에 섰다(E1).
##
## 둘을 갈라 두는 이유는 **얻는 정보의 값이 다르기** 때문이다. 교차는 상대가
## 어디로 갔는지까지 알려 주고, 같은 방은 지금 눈앞에 있다는 뜻이다.
var crossed: bool


func _init(
	sighting_turn: int,
	observer: Actor,
	seen: Actor,
	seen_room_id: String,
	was_crossing: bool = false
) -> void:
	turn = sighting_turn
	observer_id = observer.id if observer != null else ""
	seen_id = seen.id if seen != null else ""
	seen_name = seen.display_name if seen != null else ""
	room_id = seen_room_id
	crossed = was_crossing


## 이 목격에 그 주체가 끼어 있는가. 본 쪽이든 보인 쪽이든.
func involves(actor_id: String) -> bool:
	return observer_id == actor_id or seen_id == actor_id
