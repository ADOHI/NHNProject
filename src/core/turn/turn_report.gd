class_name TurnReport
extends RefCounted
## 한 턴을 푼 결과 전부. 해결기가 쓰고, 화면과 렉카 피드가 읽는다.
##
## ## 왜 사건 로그와 따로 있는가
##
## 세는 것이 다르다. `EventLog` 는 **판이 시작된 뒤 지금까지**를 쌓고,
## 이쪽은 **방금 그 한 턴**만 담는다. 화면이 "이번 턴에 무엇이 달라졌는가"를
## 그리려면 매번 로그를 뒤져 턴으로 걸러야 하는데, 그러면 걸러는 방식이
## 화면마다 갈린다.
##
## ## 그리고 사건이 아닌 것도 담는다
##
## 로그에 넣을 수 없는 것이 둘 있다.
##
## | 담기는 것 | 왜 로그가 아닌가 |
## | --- | --- |
## | 목격(`TurnSighting`) | E2 는 **아무 일도 없다**. 사건이 아닌데 정보는 남는다 |
## | 거절된 의도 | 성사되지 않은 이동은 판을 바꾸지 않았다 |
##
## **거절된 의도를 남기는 이유**는 동시 해결의 성질 때문이다. 의도는 약속이지
## 결과가 아니고(`TurnIntent` 주석), 낼 때 갈 수 있었어도 성사되지 않을 수 있다.
## 그 차이를 화면이 알아야 "왜 안 갔지"를 설명할 수 있다.

## 몇 번째 턴인가.
var turn: int

## 이번 턴에 기록된 사건들. `EventLog` 에 들어간 것과 같은 것들이다.
var events: Array[GameEvent] = []

## 이번 턴에 성립한 조우들 (E1).
var encounters: Array[Encounter] = []

## 이번 턴에 생긴 목격들 (E1 · E2).
var sightings: Array[TurnSighting] = []

## 실제로 방을 옮긴 주체들.
var moved_actor_ids: Array[String] = []

## 의도를 냈으나 **해결 시점에** 갈 수 없었던 주체들.
var refused_actor_ids: Array[String] = []

## 이번 턴에 탈출을 완료한 주체들 (§5.9).
var escaped_actor_ids: Array[String] = []

## 이번 턴에 푼 조우들의 결말 (docs/design/35-encounter.md §35.2).
##
## `encounters` 와 나란하지 않을 수 있다 — 방이 사라진 조우는 결말이 없다.
var outcomes: Array[EncounterOutcome] = []

## 이번 턴에 제압된 **사람들**. 죽지 않는다 (docs/design/28-combat.md §28.10).
var subdued_actor_ids: Array[String] = []

## 이번 턴에 죽은 **몬스터들**.
var slain_actor_ids: Array[String] = []

## actor_id -> [떠난 방, 도착한 방]. 걸음 기록과 화면 연출이 읽는다.
var _moves: Dictionary = {}


func _init(report_turn: int) -> void:
	turn = report_turn


## 이동이 성사된 것으로 적는다. 해결기만 부른다.
func note_move(actor_id: String, from_id: String, to_id: String) -> void:
	moved_actor_ids.append(actor_id)
	_moves[actor_id] = [from_id, to_id]


func did_move(actor_id: String) -> bool:
	return moved_actor_ids.has(actor_id)


func moved_from(actor_id: String) -> String:
	var pair: Array = _moves.get(actor_id, [])
	return str(pair[0]) if pair.size() == 2 else ""


func moved_to(actor_id: String) -> String:
	var pair: Array = _moves.get(actor_id, [])
	return str(pair[1]) if pair.size() == 2 else ""


## 그 방에서 난 조우. 없으면 `null`.
##
## 상호작용 단계가 이것으로 "여기는 건드리지 마라"를 판단한다.
func encounter_in(room_id: String) -> Encounter:
	for encounter in encounters:
		if encounter.room_id == room_id:
			return encounter
	return null


## 그 방에서 난 조우의 결말. 없으면 `null`.
func outcome_in(room_id: String) -> EncounterOutcome:
	for outcome in outcomes:
		if outcome.room_id == room_id:
			return outcome
	return null


func encounter_of(actor_id: String) -> Encounter:
	for encounter in encounters:
		if encounter.involves(actor_id):
			return encounter
	return null


## 그 주체가 이번 턴에 본 것들. **E2 의 정보가 실제로 남는지는 이것으로 확인된다.**
func sightings_by(observer_id: String) -> Array[TurnSighting]:
	var found: Array[TurnSighting] = []
	for sighting in sightings:
		if sighting.observer_id == observer_id:
			found.append(sighting)
	return found


func saw(observer_id: String, seen_id: String) -> bool:
	for sighting in sightings:
		if sighting.observer_id == observer_id and sighting.seen_id == seen_id:
			return true
	return false


## 아무 일도 없었던 턴인가.
##
## **조용한 턴에도 기사는 나간다** (docs/design/32-rekka-feed.md §32.1).
## 부재도 정보이므로 이 값은 기사를 거르는 데 쓰지 않고, 무엇을 쓸지 고르는 데 쓴다.
func is_quiet() -> bool:
	return events.is_empty() and sightings.is_empty()
