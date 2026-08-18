class_name DungeonRun
extends RefCounted
## 진행 중인 던전 잠입 한 판. 설계도 · 판 · 플레이어 · 사건 기록 · **턴**을 한데 묶는다.
##
## 화면(DungeonBoard)이 게임 상태를 직접 들고 있으면 씬을 바꿀 때마다 상태가 날아가고
## 테스트도 불가능해진다. 상태는 전부 여기 있고, 화면은 이것을 읽어 그리기만 한다
## (conventions.md §3.1).
##
## ## 턴은 두 국면이다
##
##     계획 페이즈 — 읽고 정한다. 조작을 받는 유일한 국면이다
##       submit_intent() 로 의도를 낸다. 확정 전에는 몇 번이든 바꿀 수 있다 (§4.3)
##
##     행동 페이즈 — resolve_turn() 안에서 **동시에** 풀린다. 조작을 받지 않는다
##       플레이어 · NPC 탐험가 · 몬스터가 같은 순간에 움직인다 (§3.6)
##
## 규칙 자체는 여기 없다. `TurnResolver` 가 다섯 단계로 푼다
## (docs/design/33-turn-loop.md §33.1). 이 클래스는 **누가 무엇을 들고 있는지**만 안다.

## 플레이어가 방을 옮겼을 때. 화면 갱신의 신호다.
signal player_moved(from_id: String, to_id: String)

## 한 턴이 풀렸을 때. 사건이 없는 턴에도 반드시 나간다 —
## **조용한 턴에도 기사는 나가고**(docs/design/32-rekka-feed.md §32.1),
## 부재도 정보이기 때문이다.
signal turn_resolved(report: TurnReport)

var blueprint: DungeonBlueprint
var graph: DungeonGraph
var player: Actor
var event_log: EventLog

## 이 판을 어떻게 걸었나. **판정이 아니라 기록이다**
## (docs/design/17-dungeon-generation.md §17.28.1).
##
## 판에 붙여 두는 이유는 **판이 바뀌면 새 기록**이어야 하기 때문이다. 화면에 두면
## 교정쇄를 닫았다 열 때 지워지고, 그러면 "걸은 뒤에 확인한다"가 성립하지 않는다.
##
## 사건 기록(`event_log`)과 따로 두는 이유는 세는 것이 다르기 때문이다 — 로그는
## **무슨 일이 있었나**를 남기고, 이쪽은 **어떻게 돌아다녔나**를 센다.
var walk: WalkRecord

## 방에 남은 귀중품. **유한하다** — 늦으면 이미 털려 있다 (§5.2).
var loot: LootTable

## 누가 무엇을 들고 있나. 사망 시 상실 · 탈출 시 확정 (§5.3).
var haul: Haul

## 플레이어가 기억하는 것. 변화량 추론이 여기서 성립한다 (§13.5 · §13.7).
var memory: BoardMemory

## NPC 탐험가와 몬스터의 의도를 정한다 (M4).
var planner: NpcPlanner

## 행동 페이즈. 다섯 단계를 순서대로 푼다.
var resolver: TurnResolver

## 방금 푼 턴의 결과. 화면과 렉카 피드가 읽는다.
var last_report: TurnReport = null

## 현재 턴. **사건을 기록한 뒤에** 오른다.
##
## 순서를 뒤집으면 `main.gd` 의 `_publish_turn()` 이 빈 턴을 낸다 —
## 그쪽은 `turn - 1` 을 읽고 있다.
var turn: int = 1

## 지금 국면. 화면은 `TurnPhase.accepts_input()` 하나만 보고 입력을 막는다.
var phase: TurnPhase.Kind = TurnPhase.Kind.PLANNING

## 판이 끝났는가. 플레이어가 탈출하면 선다 (§5.3 정산).
var finished := false

## 이번 턴에 도착해서 읽은 인접 위험도의 변화량. **화면이 그대로 띄운다.**
##
## 판이 이것을 대신 재는 이유는 §13.7 이 *"매 턴 암산을 강요하면 재미가 아니라
## 노동이 된다"* 고 적었기 때문이다.
var threat_change := 0

## 위 변화량을 글자로. 변화가 없으면 빈 문자열이다.
## `▲ ▼` 는 테마 폰트에 없다 (conventions.md §5.1).
var threat_change_text := ""

## 주체 id -> 이번 계획 페이즈에 제출된 의도.
var _intents: Dictionary = {}


func _init(
	dungeon_blueprint: DungeonBlueprint,
	dungeon_graph: DungeonGraph,
	squad: Actor,
	run_seed: int = 0
) -> void:
	blueprint = dungeon_blueprint
	graph = dungeon_graph
	player = squad
	event_log = EventLog.new()
	walk = WalkRecord.new()
	# 시드를 받는다. **전역 난수를 쓰지 않는다** — 같은 시드가 같은 판을 내야
	# 이상한 판이 나왔을 때 다시 볼 수 있다 (§17.7).
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	loot = LootTable.for_graph(dungeon_graph, rng)
	haul = Haul.new()
	memory = BoardMemory.new()
	resolver = TurnResolver.new(graph, loot, haul, event_log)
	planner = NpcPlanner.new(graph, loot, haul)
	# 스쿼드가 아직 안 놓인 판도 있다(테스트 픽스처). 그때는 첫 이동이 시작 방을 메운다.
	walk.begin_at(player_room_id())
	memory.note(player_room_id(), adjacent_threat())


func player_room_id() -> String:
	return graph.find_actor_room(player)


func player_room() -> Room:
	var id := player_room_id()
	return graph.get_room(id) if not id.is_empty() else null


## 플레이어가 지금 보고 있는 숫자. 인접한 방들의 위험도 합이다.
##
## 정확하지만 모호하다 — 합은 참이되 구성은 알려 주지 않는다
## (docs/design/07-level-design.md §7.2).
func adjacent_threat() -> int:
	var id := player_room_id()
	return graph.adjacent_threat(id) if not id.is_empty() else 0


## 이번에 **실제로 갈 수 있는** 방들. 민첩으로 오를 수 없는 방은 빠진다.
##
## adjacent_threat() 과 대상이 다르다 — 위험도 합에는 못 가는 방도 들어간다.
## 그 차이가 고도의 공포다 (docs/design/07-level-design.md §7.2.7).
func reachable_room_ids() -> Array[String]:
	var id := player_room_id()
	if id.is_empty():
		return [] as Array[String]
	return graph.traversable_neighbors(id, player.agility)


## 인접해 있지만 민첩이 모자라 오를 수 없는 방들.
##
## 화면에서 "보이지만 못 가는 곳"으로 구분해 보여 주기 위해 쓴다.
func blocked_room_ids() -> Array[String]:
	var id := player_room_id()
	if id.is_empty():
		return [] as Array[String]
	var result: Array[String] = []
	for neighbor_id in graph.neighbors_of(id):
		if not graph.can_traverse(id, neighbor_id, player.agility):
			result.append(neighbor_id)
	return result


func can_move_to(room_id: String) -> bool:
	return reachable_room_ids().has(room_id)


## 지금 서 있는 방이 탈출 지점인가.
func is_at_exit() -> bool:
	var room := player_room()
	return room != null and room.kind == Room.Kind.EXIT


## 탈출까지 몇 턴 더 버텨야 하는가 (§5.9).
func escape_turns_left() -> int:
	return resolver.escape_turns_left(player.id)


func escape_progress() -> int:
	return resolver.escape_progress_of(player.id)


## 지금 조작을 받는가. 화면은 이 함수 하나만 본다.
func accepts_input() -> bool:
	return not finished and TurnPhase.accepts_input(phase)


# ---------------------------------------------------------------- 계획 페이즈


## 이번 턴의 의도를 낸다. **계획 페이즈에만 받는다.**
##
## 같은 주체가 두 번 내면 나중 것이 이긴다 — §4.3 이 *"확정 전 계획 변경 가능"* 을
## 정해 뒀다. 확정은 `resolve_turn()` 이고, 그 전까지는 몇 번이든 바꿀 수 있다.
func submit_intent(intent: TurnIntent) -> bool:
	if intent == null or not accepts_input():
		return false
	_intents[intent.actor_id] = intent
	return true


func clear_intent(actor_id: String) -> void:
	_intents.erase(actor_id)


## 지금 제출돼 있는 플레이어의 의도. 없으면 `null`.
func player_intent() -> TurnIntent:
	return _intents.get(player.id)


# ---------------------------------------------------------------- 행동 페이즈


## 한 턴을 푼다. **제출된 의도와 NPC 의 의도가 한 번에 풀린다** (§3.6).
##
## 의도를 안 낸 주체는 STAY 로 읽힌다. 빠진 주체를 따로 처리하는 분기는
## 반드시 빠뜨리는 곳이 생긴다 (`TurnIntent.stay()` 주석).
func resolve_turn() -> TurnReport:
	if finished:
		return null
	phase = TurnPhase.Kind.ACTION
	var report := resolver.resolve(turn, _gather_intents())
	last_report = report
	_note_walk(report)
	# **사건을 기록한 뒤에 턴을 올린다.** 뒤집으면 피드가 빈 턴을 낸다.
	turn += 1
	_intents.clear()
	_note_memory()
	phase = TurnPhase.Kind.PLANNING
	if report.escaped_actor_ids.has(player.id):
		finished = true
	turn_resolved.emit(report)
	if report.did_move(player.id):
		player_moved.emit(report.moved_from(player.id), report.moved_to(player.id))
	return report


## 인접한 방으로 이동한다. 한 턴이 통째로 풀린다.
##
## **시그니처를 그대로 둔다.** `base_screen.gd` · `dungeon_board.gd` ·
## `capture_rekka_feed.gd` 가 이미 이것을 부르고 있고, 부르는 쪽을 다 고치는 것은
## 턴 루프의 일이 아니다. 달라진 것은 안쪽뿐이다 — 이제 NPC 도 같이 움직인다.
func move_player(room_id: String) -> bool:
	if finished or not can_move_to(room_id):
		return false
	submit_intent(TurnIntent.move(player.id, room_id))
	var report := resolve_turn()
	return report != null and report.did_move(player.id)


## 지금 방을 뒤진다. 한 턴이 통째로 풀린다.
func search_here() -> bool:
	if finished:
		return false
	submit_intent(TurnIntent.search(player.id))
	return resolve_turn() != null


## 탈출 지점에서 한 턴 버틴다. **즉시 나가지지 않는다** (§5.9).
func hold_at_exit() -> bool:
	if finished or not is_at_exit():
		return false
	submit_intent(TurnIntent.escape(player.id))
	return resolve_turn() != null


# ---------------------------------------------------------------- 뒷정리


## 플레이어가 낸 것이 NPC 의 것을 이긴다.
##
## 시험이 NPC 의 의도를 손으로 박아 경계 상황을 세울 수 있어야 하기 때문이다.
## E1·E2 는 두 주체가 **정확히 어떤 수를 냈는가**로 갈리므로,
## 그것을 박을 수 없으면 시험이 무작위 대기가 된다.
func _gather_intents() -> Array[TurnIntent]:
	var intents := planner.plan_all()
	for actor_id in _intents:
		intents.append(_intents[actor_id])
	return intents


func _note_walk(report: TurnReport) -> void:
	if report.did_move(player.id):
		walk.note_move(report.moved_from(player.id), report.moved_to(player.id))


## 도착해서 읽은 숫자를 기억과 견주고, 그 결과를 기억에 덮는다.
##
## **견주는 것이 먼저다.** 덮고 나서 견주면 변화량이 언제나 0 이 된다.
func _note_memory() -> void:
	var room_id := player_room_id()
	var threat := adjacent_threat()
	threat_change = memory.delta(room_id, threat)
	threat_change_text = memory.delta_text(room_id, threat)
	memory.note(room_id, threat)
