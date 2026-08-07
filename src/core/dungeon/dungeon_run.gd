class_name DungeonRun
extends RefCounted
## 진행 중인 던전 잠입 한 판. 설계도 · 판 · 플레이어 · 사건 기록을 한데 묶는다.
##
## 화면(DungeonBoard)이 게임 상태를 직접 들고 있으면 씬을 바꿀 때마다 상태가 날아가고
## 테스트도 불가능해진다. 상태는 전부 여기 있고, 화면은 이것을 읽어 그리기만 한다
## (conventions.md §3.1).
##
## **아직 턴 구조가 없다.** 계획/행동 페이즈와 동시 해결은 구현 2단계에서 붙는다
## (docs/design/16-build-order.md §16.4). 지금은 플레이어만 움직이고
## 몬스터와 NPC 는 제자리를 지킨다.

## 플레이어가 방을 옮겼을 때. 화면 갱신의 신호다.
signal player_moved(from_id: String, to_id: String)

var blueprint: DungeonBlueprint
var graph: DungeonGraph
var player: Actor
var event_log: EventLog

## 현재 턴. 지금은 플레이어가 움직일 때마다 오른다.
var turn: int = 1


func _init(dungeon_blueprint: DungeonBlueprint, dungeon_graph: DungeonGraph, squad: Actor) -> void:
	blueprint = dungeon_blueprint
	graph = dungeon_graph
	player = squad
	event_log = EventLog.new()


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


## 이번에 갈 수 있는 방들.
func reachable_room_ids() -> Array[String]:
	var id := player_room_id()
	return graph.neighbors_of(id) if not id.is_empty() else [] as Array[String]


func can_move_to(room_id: String) -> bool:
	return reachable_room_ids().has(room_id)


## 인접한 방으로 이동한다. 이동이 성사되면 사건으로 기록하고 턴을 넘긴다.
##
## 기록을 이동과 같은 함수에 묶는 이유는, 기록되지 않은 이동이 생기면
## 렉카 기사와 세계 갱신이 판과 어긋나기 때문이다
## (docs/design/16-build-order.md §16.2).
func move_player(room_id: String) -> bool:
	var from_id := player_room_id()
	if not graph.move_actor(player, room_id):
		return false
	event_log.record(GameEvent.new(turn, GameEvent.Kind.MOVED, player, graph.get_room(room_id)))
	turn += 1
	player_moved.emit(from_id, room_id)
	return true
