class_name DebugOverlay
extends PressPanel
## **교정쇄.** 아직 인쇄기에 걸리지 않은 지면이고, 판의 진실이 그대로 적혀 있다.
##
## PressPanel 의 PROOF 판으로 그린다 — 별색이 하나도 없다.
## 별색은 렉카가 붙이는 것이고, 이 지면은 아직 렉카의 손에 가지 않았다.
## 그래서 여기 적힌 것은 부풀려지지 않은 값이다
## (docs/design/18-visual-identity.md §18.7).
##
## 플레이 화면은 정보를 숨기는 것이 곧 재미다(docs/design/13-information-design.md).
## 그래서 개발 중에 "지금 판이 실제로 어떤 상태인가"를 확인할 방법이 없다.
## 인접 합이 6 으로 보일 때 그게 의도한 모호함인지 생성기 버그인지 구분할 수 없다.
##
## 이 패널은 그 구분을 위해 존재한다. **숨김을 전부 걷어낸 화면**이다.
##
## 이벤트 로그를 함께 띄우는 이유는, 이것이 나중에 렉카 피드가 읽을 바로 그 자료이기
## 때문이다(docs/design/08-ui-ux.md §8.3). 여기서 사실을 보고, 기사에서 과장된 것을 본다.

## 로그에 보여 줄 최근 사건 수.
const _LOG_LIMIT := 14

const _KIND_LABELS := {
	Room.Kind.ENTRANCE: "입구",
	Room.Kind.EMPTY: "빈방",
	Room.Kind.TREASURE: "귀중품",
	Room.Kind.HAZARD: "위험",
	Room.Kind.BOSS: "보스",
	Room.Kind.EXIT: "탈출",
}

const _EVENT_LABELS := {
	GameEvent.Kind.MOVED: "이동",
	GameEvent.Kind.SEARCHED: "탐색",
	GameEvent.Kind.ACQUIRED: "획득",
	GameEvent.Kind.ENCOUNTERED: "조우",
	GameEvent.Kind.FOUGHT: "전투",
	GameEvent.Kind.NEGOTIATED: "협상",
	GameEvent.Kind.FLED: "도주",
	GameEvent.Kind.DOWNED: "쓰러짐",
	GameEvent.Kind.ESCAPED: "탈출",
}

var _run: DungeonRun
var _seed := 0

@onready var _summary_label: Label = %SummaryLabel
@onready var _rooms_label: Label = %RoomsLabel
@onready var _log_label: Label = %LogLabel


func bind(run: DungeonRun, seed_value: int) -> void:
	_run = run
	_seed = seed_value
	refresh()


func refresh() -> void:
	if _run == null or not visible:
		return
	_summary_label.text = _build_summary()
	_rooms_label.text = _build_rooms()
	_log_label.text = _build_log()


func _build_summary() -> String:
	var current := _run.player_room_id()
	var name := _run.blueprint.display_name_of(current)
	var elevation := _run.blueprint.elevation_of(current)
	var lines: Array[String] = []
	lines.append("시드 %d   •   %d 턴" % [_seed, _run.turn])
	lines.append("스쿼드   전투력 %d   민첩 %d" % [_run.player.threat, _run.player.agility])
	lines.append("현재   %s (고도 %d)" % [name, elevation])
	lines.append(_adjacent_line(current))
	return "\n".join(lines)


## 인접 정보 한 줄. 합•개체 수•최댓값을 나란히 둔다.
##
## 셋을 함께 보여 주는 이유는, 합만으로는 생성기가 의도한 모호함이 실제로 생겼는지
## 알 수 없기 때문이다 (docs/design/17-dungeon-generation.md §17.5 V6).
func _adjacent_line(current: String) -> String:
	var total := _run.adjacent_threat()
	var count := _run.graph.adjacent_occupant_count(current)
	var highest := _run.graph.adjacent_max_threat(current)
	return "인접   합 %d   개체 %d   최대 %d" % [total, count, highest]


## 방 목록. 고도가 높은 순으로 늘어놓아 화면의 위아래와 순서를 맞춘다.
##
## 위험도의 **구성**을 함께 보여 주는 것이 이 표의 핵심이다.
## 합만 보면 생성기가 의도대로 모호함을 만들었는지 알 수 없다
## (docs/design/17-dungeon-generation.md §17.5 V6).
func _build_rooms() -> String:
	var entrance := _entrance_id()
	var costs := _run.graph.required_agility_from(entrance)
	var current := _run.player_room_id()

	var ids := _run.blueprint.room_ids()
	ids.sort_custom(
		func(a: String, b: String) -> bool:
			return _run.blueprint.elevation_of(a) > _run.blueprint.elevation_of(b)
	)

	var lines: Array[String] = ["방                 고도 종류   위험 개체 필요"]
	for id in ids:
		lines.append(_room_line(id, current, costs))
	return "\n".join(lines)


func _room_line(id: String, current: String, costs: Dictionary) -> String:
	var room := _run.graph.get_room(id)
	var marker := "> " if id == current else "  "
	var name := _run.blueprint.display_name_of(id)
	var kind: String = _KIND_LABELS[_run.blueprint.kind_of(id)]
	var stats := "%4d %4d %4d" % [room.threat(), room.occupant_count(), costs.get(id, -1)]
	return "%s%-14s %3d %-6s %s" % [marker, name, _run.blueprint.elevation_of(id), kind, stats]


## 사건 기록. 이것이 나중에 렉카 기사의 재료가 된다.
func _build_log() -> String:
	if _run.event_log.is_empty():
		return "(아직 사건 없음)"
	var lines: Array[String] = []
	for event in _run.event_log.recent(_LOG_LIMIT):
		lines.append(_event_line(event))
	return "\n".join(lines)


func _event_line(event: GameEvent) -> String:
	var kind: String = _EVENT_LABELS[event.kind]
	return "%2d턴  %-4s  %s  /  %s" % [event.turn, kind, event.actor_name, event.room_name]


func _entrance_id() -> String:
	var entrances := _run.blueprint.rooms_of_kind(Room.Kind.ENTRANCE)
	return entrances[0] if not entrances.is_empty() else _run.player_room_id()
