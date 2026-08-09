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

## 이 판을 어떻게 걸었나. **판정이 아니라 기록이다**
## (docs/design/17-dungeon-generation.md §17.28.1).
##
## 판에 붙여 두는 이유는 **판이 바뀌면 새 기록**이어야 하기 때문이다. 화면에 두면
## 교정쇄를 닫았다 열 때 지워지고, 그러면 "걸은 뒤에 확인한다"가 성립하지 않는다.
##
## 사건 기록(`event_log`)과 따로 두는 이유는 세는 것이 다르기 때문이다 — 로그는
## **무슨 일이 있었나**를 남기고, 이쪽은 **어떻게 돌아다녔나**를 센다.
var walk: WalkRecord

## 현재 턴. 지금은 플레이어가 움직일 때마다 오른다.
var turn: int = 1


func _init(dungeon_blueprint: DungeonBlueprint, dungeon_graph: DungeonGraph, squad: Actor) -> void:
	blueprint = dungeon_blueprint
	graph = dungeon_graph
	player = squad
	event_log = EventLog.new()
	walk = WalkRecord.new()
	# 스쿼드가 아직 안 놓인 판도 있다(테스트 픽스처). 그때는 첫 이동이 시작 방을 메운다.
	walk.begin_at(player_room_id())


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
	# 기록도 이동과 같은 함수에 묶는다. 신호를 듣는 쪽에 맡기면 아무도 안 듣는 판이 생긴다.
	walk.note_move(from_id, room_id)
	turn += 1
	player_moved.emit(from_id, room_id)
	return true
