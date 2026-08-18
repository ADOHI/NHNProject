class_name Encounter
extends RefCounted
## 같은 방에 둘 이상이 모였다는 **사실**. 결말은 비어 있다.
##
## docs/design/05-rules.md §5.6 E1 — 둘이 같은 방에 동시 진입하면 조우가 발생한다.
## 그 **뒤**에 무엇을 하는가(전투 · 협상 · 도주)는 §5.8 의 조우 절차이고,
## 이 레인이 만들지 않는다 (docs/design/33-turn-loop.md §33.3).
##
## **그래서 이 클래스는 판단을 하지 않는다.** 누가 · 어디서 까지만 들고 있고,
## 절차가 붙을 때 그것이 읽을 것을 미리 갈라 둔다.
##
## | 미리 갈라 둔 것 | 누가 쓰나 |
## | --- | --- |
## | `room_kind` | E5(특수방 조우) — **보류**. 자리만 낸다 |
## | `monster_ids` / `explorer_ids` | E9(몬스터방에서 탐험가끼리) |
## | `participant_ids` | E8(협력과 배신) → 관계도 §5.10 |
##
## **몬스터끼리는 조우가 아니다.** 함정방에 사냥개 셋이 같이 있는 것은 배치이지
## 사건이 아니다. 탐험가가 하나도 없으면 조우를 만들지 않는다 — 안 그러면
## 판을 만들자마자 조우가 여럿 서 있고 매 턴 같은 기사가 나간다.

## 몇 턴에 났는가.
var turn: int

var room_id: String
var room_name: String

## 방의 성격. **E5 가 보류라 이 레인은 읽지 않는다.** 절차가 붙을 때 쓸 자리다.
var room_kind: Room.Kind = Room.Kind.EMPTY

## 이 방에 있는 모두. 몬스터도 들어간다.
var participant_ids: Array[String] = []

## 표시명. 기사가 사건보다 오래 살기 때문에 함께 남긴다.
var participant_names: Array[String] = []

## 플레이어 스쿼드와 NPC 탐험가. **같은 규칙 아래 같은 목표로 움직이는 것들**이다
## (docs/design/05-rules.md §5.2).
var explorer_ids: Array[String] = []

## 몬스터. E9 가 "협력해서 몬스터와 싸울지, 각자 싸울지"를 물을 때 읽는다.
var monster_ids: Array[String] = []


func _init(encounter_turn: int, room: Room, actors: Array[Actor]) -> void:
	turn = encounter_turn
	if room != null:
		room_id = room.id
		room_name = room.display_name
		room_kind = room.kind
	for actor in actors:
		participant_ids.append(actor.id)
		participant_names.append(actor.display_name)
		if actor.kind == Actor.Kind.MONSTER:
			monster_ids.append(actor.id)
		else:
			explorer_ids.append(actor.id)


## 조우로 성립하는 모임인가.
##
## 둘 이상이어야 하고, **탐험가가 하나는 있어야** 한다.
## 판정을 여기 한 곳에 두어야 "무엇이 조우인가"가 갈리지 않는다.
static func is_encounter(actors: Array[Actor]) -> bool:
	if actors.size() < 2:
		return false
	for actor in actors:
		if actor.kind != Actor.Kind.MONSTER:
			return true
	return false


## 참가자 조합을 나타내는 한 줄.
##
## **같은 조합이 유지되는 것은 새 사건이 아니다** — §5.8 의
## *"전투 지속 → 다음 턴에도 조우 상태"* 가 그것이다. 해결기가 직전 턴의 이 값과
## 견줘서, 달라졌을 때만 사건으로 남긴다. 안 그러면 몬스터방에 서 있는 동안
## 매 턴 같은 기사가 나간다.
func signature() -> String:
	var sorted := participant_ids.duplicate()
	sorted.sort()
	return "|".join(sorted)


func has_monsters() -> bool:
	return not monster_ids.is_empty()


## 탐험가끼리 마주쳤는가. E9 가 몬스터방에서 이 상황을 묻는다.
func is_between_explorers() -> bool:
	return explorer_ids.size() >= 2


func involves(actor_id: String) -> bool:
	return participant_ids.has(actor_id)


## 기사에서 이 사건의 주인공이 될 주체. 탐험가를 앞세운다.
##
## 몬스터를 주인공으로 세우면 *"먼지 망령이 스쿼드와 마주쳤다"* 가 되어
## 기사가 사람 이야기가 아니게 된다 (docs/design/08-ui-ux.md §8.3.6).
func lead_actor_id() -> String:
	if not explorer_ids.is_empty():
		return explorer_ids[0]
	return participant_ids[0] if not participant_ids.is_empty() else ""


## 주인공을 뺀 나머지. `GameEvent.related_actor_ids` 에 그대로 들어간다.
func others_than(actor_id: String) -> Array[String]:
	var others: Array[String] = []
	for id in participant_ids:
		if id != actor_id:
			others.append(id)
	return others
