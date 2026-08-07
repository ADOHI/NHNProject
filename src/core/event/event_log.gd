class_name EventLog
extends RefCounted
## 사건의 시간순 기록. 행동 페이즈가 쓰고, 기사 생성기와 세계 갱신이 읽는다.
##
## 로그는 **판의 진실**이다. 플레이어에게 보이는 것은 이 로그가 아니라
## 여기서 만들어진 기사이며, 그 기사는 과장된다
## (docs/design/13-information-design.md §13.3).
## 두 계층을 분리해 두어야 "숫자는 못 속이고 기사는 부풀린다"가 성립한다.

## 사건이 기록될 때마다 발신한다. 기사 생성기가 여기에 붙는다.
signal event_recorded(event: GameEvent)

var _events: Array[GameEvent] = []


## 사건을 기록한다.
func record(event: GameEvent) -> void:
	_events.append(event)
	event_recorded.emit(event)


func count() -> int:
	return _events.size()


func is_empty() -> bool:
	return _events.is_empty()


## 전체 기록의 복사본.
func all() -> Array[GameEvent]:
	return _events.duplicate()


## 특정 턴에 일어난 사건들.
##
## 렉카 피드는 매 행동 페이즈 직후 그 턴의 사건에서 기사를 고른다
## (docs/design/08-ui-ux.md §8.3.5).
func events_in_turn(turn: int) -> Array[GameEvent]:
	var result: Array[GameEvent] = []
	for event in _events:
		if event.turn == turn:
			result.append(event)
	return result


## 특정 종류의 사건들.
func events_of_kind(kind: GameEvent.Kind) -> Array[GameEvent]:
	var result: Array[GameEvent] = []
	for event in _events:
		if event.kind == kind:
			result.append(event)
	return result


## 특정 주체가 주인공이거나 얽혀 있는 사건들.
##
## 주목도 계산과 인물별 기사 조회에 쓴다
## (docs/design/13-information-design.md §13.4).
func events_involving(actor_id: String) -> Array[GameEvent]:
	var result: Array[GameEvent] = []
	for event in _events:
		if event.actor_id == actor_id or event.related_actor_ids.has(actor_id):
			result.append(event)
	return result


## 특정 방에서 일어난 사건들.
func events_in_room(room_id: String) -> Array[GameEvent]:
	var result: Array[GameEvent] = []
	for event in _events:
		if event.room_id == room_id:
			result.append(event)
	return result


## 최근 사건부터 최대 limit 개. 피드는 최신순으로 읽힌다.
func recent(limit: int) -> Array[GameEvent]:
	if limit <= 0:
		return [] as Array[GameEvent]
	var result: Array[GameEvent] = []
	var start := maxi(0, _events.size() - limit)
	for i in range(_events.size() - 1, start - 1, -1):
		result.append(_events[i])
	return result


func clear() -> void:
	_events.clear()
