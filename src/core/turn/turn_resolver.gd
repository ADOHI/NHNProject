class_name TurnResolver
extends RefCounted
## 행동 페이즈. 모두의 의도를 **한 번에** 푼다.
##
## docs/design/03-core-loop.md §3.6 이 동시 해결을 확정하고 해결 순서를 나열해 뒀다.
## docs/design/33-turn-loop.md §33.1 이 그 순서를 그대로 못 박았다.
##
##     이동 -> 조우 판정 -> 상호작용 -> 결과 -> 사건 기록
##
## ## 다섯이 각각 함수인 이유
##
## **어느 규칙이 깨졌는지 특정할 수 있어야 한다.** 한 함수가 다섯을 다 하면
## 규칙이 늘 때마다 그 함수만 길어지고, 시험은 "턴을 돌렸더니 이상하다"까지밖에
## 말하지 못한다. 이 저장소가 던전 생성기에서 이미 쓴 방식이다.
##
## ## 기록은 마지막 한 곳에서만 한다
##
## 앞 네 단계는 `TurnReport` 에 쌓기만 한다. `EventLog` 에 붓는 것은 5단계뿐이다.
## 단계마다 제각기 로그에 쓰면 **기록을 빠뜨린 경로**가 생기고,
## 그러면 렉카 기사와 세계 갱신이 판과 어긋난다
## (docs/design/16-build-order.md §16.2).
##
## ## 판 위에 누가 있는지는 판에게 묻는다
##
## 주체 목록을 밖에서 받지 않고 `DungeonGraph` 를 훑는다. 목록을 따로 들면
## 탈출·사망으로 빠진 주체가 목록에만 남아 **위험도에는 안 잡히는데 의도는 내는**
## 유령이 된다.

## 탈출 지점에서 버텨야 하는 턴 수. **잠정** (docs/design/05-rules.md §5.9).
##
## §5.9 는 *"고정 턴수로 못 박지 않는다"* 고 적었다 — 장비와 부상이 이 값을 흔들 것이다.
## 그 계산이 붙기 전까지 쓰는 기본값이고, **이 게임의 절정 구간**이므로
## 굴려 보고 정한다.
const ESCAPE_TURNS := 2

var _graph: DungeonGraph
var _loot: LootTable
var _haul: Haul
var _event_log: EventLog

## 방 id -> 직전 턴 그 방의 조우 참가자 조합.
##
## **같은 조합이 유지되는 것은 새 사건이 아니다** (§5.8 "전투 지속 → 다음 턴에도 조우").
## 이것이 없으면 몬스터방에 서 있는 동안 매 턴 같은 기사가 나간다.
var _ongoing: Dictionary = {}

## 주체 id -> 탈출 지점에서 버틴 턴 수.
var _escape_progress: Dictionary = {}


func _init(graph: DungeonGraph, loot: LootTable, haul: Haul, event_log: EventLog) -> void:
	_graph = graph
	_loot = loot
	_haul = haul
	_event_log = event_log


## 한 턴을 푼다. **이 함수의 본문이 곧 규칙의 순서다.**
func resolve(turn: int, intents: Array[TurnIntent]) -> TurnReport:
	var report := TurnReport.new(turn)
	var actors := _actors_on_board()
	var plan := _index_intents(intents)
	var before := _positions(actors)

	_resolve_moves(report, actors, plan, before)
	_detect_encounters(report, actors, before)
	_resolve_interactions(report, actors, plan)
	_settle_results(report, actors)
	_record_events(report)
	return report


## 그 주체가 탈출 지점에서 몇 턴을 버텼는가. 화면이 진행을 보여 줄 때 읽는다.
func escape_progress_of(actor_id: String) -> int:
	return int(_escape_progress.get(actor_id, 0))


## 탈출까지 남은 턴. 아직 시작하지 않았으면 전체 소요 턴이다.
func escape_turns_left(actor_id: String) -> int:
	return maxi(0, ESCAPE_TURNS - escape_progress_of(actor_id))


# ---------------------------------------------------------------- 1. 이동


## 누가 어디로 갔는가.
##
## **의도는 약속이지 결과가 아니다** (`TurnIntent` 주석). 낼 때 갈 수 있었어도
## 성사되지 않을 수 있으므로 유효성을 **여기서 다시** 본다.
##
## 이동은 남의 위치에 의존하지 않는다 — 통과 조건은 고도와 자기 민첩뿐이다.
## 그래서 순서대로 적용해도 동시성이 깨지지 않는다. 방을 막는 규칙이 생기면
## 그때는 이 함수가 **전부 판정한 뒤 한꺼번에 적용**하는 모양으로 바뀌어야 한다.
func _resolve_moves(
	report: TurnReport, actors: Array[Actor], plan: Dictionary, before: Dictionary
) -> void:
	for actor in actors:
		var intent: TurnIntent = plan.get(actor.id)
		if intent == null or not intent.is_move():
			continue
		var from_id: String = before.get(actor.id, "")
		if not _graph.move_actor(actor, intent.target_room_id):
			report.refused_actor_ids.append(actor.id)
			continue
		report.note_move(actor.id, from_id, intent.target_room_id)
		report.events.append(
			GameEvent.new(
				report.turn, GameEvent.Kind.MOVED, actor, _graph.get_room(intent.target_room_id)
			)
		)


# ---------------------------------------------------------------- 2. 조우 판정


## 같은 방에 둘 이상 모였는가(E1) · 서로 지나쳤는가(E2).
##
## 이동보다 **뒤**여야 한다 — 조우는 "어디에 있는가"의 함수이므로
## 위치가 확정돼야 판정할 수 있다. 그 순서가 그대로 E4(공격 대상이 그 턴에 도망감)의
## 답이기도 하다: 도망친 쪽은 판정 시점에 애초에 그 방에 없다.
func _detect_encounters(report: TurnReport, actors: Array[Actor], before: Dictionary) -> void:
	_note_crossings(report, actors, before)

	var seen_rooms: Dictionary = {}
	for room_id in _graph.room_ids():
		var room := _graph.get_room(room_id)
		var here := room.occupants()
		if not Encounter.is_encounter(here):
			continue
		var encounter := Encounter.new(report.turn, room, here)
		report.encounters.append(encounter)
		_note_sightings_in_room(report, here, room_id)
		seen_rooms[room_id] = encounter.signature()
		if _ongoing.get(room_id, "") != encounter.signature():
			report.events.append(_encounter_event(report.turn, encounter, here))
	_ongoing = seen_rooms


## E2 — 서로 지나쳐 갔다. **판은 그대로 두고 목격만 남긴다.**
##
## docs/design/05-rules.md §5.6 E2 — *"아무 일도 없다.
## 단 서로를 봤다는 정보는 얻는다."* 통로에는 아무것도 없으므로 조우가 아니다.
func _note_crossings(report: TurnReport, actors: Array[Actor], before: Dictionary) -> void:
	for a in actors:
		if not report.did_move(a.id):
			continue
		for b in actors:
			if a.id == b.id or not report.did_move(b.id):
				continue
			if before.get(a.id, "") != report.moved_to(b.id):
				continue
			if before.get(b.id, "") != report.moved_to(a.id):
				continue
			report.sightings.append(
				TurnSighting.new(report.turn, a, b, report.moved_to(b.id), true)
			)


## E1 에서도 목격은 난다. 같은 방에 섰으면 당연히 본 것이다.
##
## "봤다"를 두 곳에서 만들면 한쪽만 고쳐지고, 그때 아무 데도 안 빨개진다
## (docs/conventions.md §6.5).
func _note_sightings_in_room(report: TurnReport, here: Array[Actor], room_id: String) -> void:
	for observer in here:
		for seen in here:
			if observer.id != seen.id:
				report.sightings.append(TurnSighting.new(report.turn, observer, seen, room_id))


func _encounter_event(turn: int, encounter: Encounter, here: Array[Actor]) -> GameEvent:
	var lead_id := encounter.lead_actor_id()
	var lead: Actor = null
	for actor in here:
		if actor.id == lead_id:
			lead = actor
	return GameEvent.new(
		turn,
		GameEvent.Kind.ENCOUNTERED,
		lead,
		_graph.get_room(encounter.room_id),
		encounter.participant_ids.size(),
		encounter.others_than(lead_id)
	)


# ---------------------------------------------------------------- 3. 상호작용


## 탐색 · 획득 · 탈출 진행.
##
## **조우가 난 방은 건너뛴다.** 마주친 방에서 태연히 상자를 뒤지면 안 된다.
## 조우가 상호작용을 막는 관계이므로 판정이 앞서 있어야 했고, 그래서 2단계가 먼저다.
##
## 마주친 뒤에 무엇을 하는가는 §5.8 조우 절차이고 이 레인이 만들지 않는다.
## **여기서 아무것도 안 하는 것이 그 자리다** (docs/design/33-turn-loop.md §33.3).
func _resolve_interactions(report: TurnReport, actors: Array[Actor], plan: Dictionary) -> void:
	for actor in actors:
		var intent: TurnIntent = plan.get(actor.id)
		if intent == null:
			continue
		var room_id := _graph.find_actor_room(actor)
		if room_id.is_empty():
			continue
		var blocked := report.encounter_in(room_id) != null
		match intent.kind:
			TurnIntent.Kind.SEARCH:
				if not blocked:
					_search(report, actor, room_id)
			TurnIntent.Kind.ESCAPE:
				_advance_escape(report, actor, room_id, blocked)


## 방을 뒤진다. **먼저 온 사람이 가져갔으면 빈손이다.**
func _search(report: TurnReport, actor: Actor, room_id: String) -> void:
	var room := _graph.get_room(room_id)
	var value := _loot.take(room_id)
	if value <= 0:
		report.events.append(GameEvent.new(report.turn, GameEvent.Kind.SEARCHED, actor, room))
		return
	_haul.add(actor.id, value)
	report.events.append(GameEvent.new(report.turn, GameEvent.Kind.ACQUIRED, actor, room, value))


## 탈출 지점에서 한 턴 버틴다.
##
## **E7 — 탈출 중 공격받음.** §5.6 이 방향만 정해 뒀다: *"탈출은 즉시가 아니다.
## 소요 턴은 가변"*. 이 레인은 그중 하나만 잠정으로 박는다 —
## **조우가 난 턴은 진행이 오르지 않는다.** 버티지 못했다는 뜻이다.
## 되돌리지는 않는다. 되돌리면 조우가 잦은 판에서 탈출이 영영 안 끝난다.
##
## 탈출 지점이 아니면 아무 일도 없다. 의도는 약속이지 결과가 아니다.
func _advance_escape(report: TurnReport, actor: Actor, room_id: String, blocked: bool) -> void:
	var room := _graph.get_room(room_id)
	if room == null or room.kind != Room.Kind.EXIT:
		report.refused_actor_ids.append(actor.id)
		return
	if blocked:
		return
	_escape_progress[actor.id] = escape_progress_of(actor.id) + 1


# ---------------------------------------------------------------- 4. 결과


## 탈출 완료와 정산 (§5.3 · §5.9).
##
## **판에서 지우는 것은 다음 턴이 있는 주체뿐이다.** NPC 탐험가는 나가면 사라진다 —
## *"플레이어가 늦게 도착하면 NPC 는 이미 나가고 없다"* (§5.2.2). 반면 플레이어가
## 나가면 판 자체가 끝나므로 지울 다음 턴이 없고, 지우면 화면이 마지막으로 한 번 더
## 그릴 때 빈 방을 가리킨다. 판정은 `report.escaped_actor_ids` 로 이미 났다.
##
## **사망은 여기 없다.** 전투 판정(§5.5)이 미정이라 "언제 죽는가"가 없다.
## 규칙 자체는 `Haul.settle_death()` 에 서 있다.
func _settle_results(report: TurnReport, actors: Array[Actor]) -> void:
	for actor in actors:
		if escape_progress_of(actor.id) < ESCAPE_TURNS:
			continue
		var room := _graph.get_room(_graph.find_actor_room(actor))
		var value := _haul.settle_escape(actor.id)
		report.escaped_actor_ids.append(actor.id)
		report.events.append(GameEvent.new(report.turn, GameEvent.Kind.ESCAPED, actor, room, value))
		_escape_progress.erase(actor.id)
		if not actor.is_player():
			_graph.remove_actor(actor)


# ---------------------------------------------------------------- 5. 사건 기록


## 이번 턴의 진실을 로그에 붓는다. **로그에 닿는 곳은 여기 하나뿐이다.**
##
## 담기는 값은 언제나 진실이다. 과장은 기사를 만드는 단계에서만 일어난다
## (docs/design/13-information-design.md §13.3.1).
func _record_events(report: TurnReport) -> void:
	if _event_log == null:
		return
	for event in report.events:
		_event_log.record(event)


# ---------------------------------------------------------------- 훑기


## 지금 판 위에 있는 모두. 방 순서 · 방 안의 순서를 그대로 따라 **결정적**이다.
func _actors_on_board() -> Array[Actor]:
	var found: Array[Actor] = []
	for room_id in _graph.room_ids():
		var room := _graph.get_room(room_id)
		if room != null:
			found.append_array(room.occupants())
	return found


## 의도를 내지 않은 주체는 목록에 없다. 해결 단계가 `null` 을 STAY 로 읽는다.
func _index_intents(intents: Array[TurnIntent]) -> Dictionary:
	var indexed: Dictionary = {}
	for intent in intents:
		if intent != null:
			indexed[intent.actor_id] = intent
	return indexed


## 이동 **전**의 위치. 교차(E2) 판정이 이것을 본다.
func _positions(actors: Array[Actor]) -> Dictionary:
	var where: Dictionary = {}
	for actor in actors:
		where[actor.id] = _graph.find_actor_room(actor)
	return where
