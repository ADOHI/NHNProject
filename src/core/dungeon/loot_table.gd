class_name LootTable
extends RefCounted
## 방에 남은 귀중품. **유한하다.**
##
## docs/design/05-rules.md §5.2 — *"던전의 귀중품은 유한하고, 늦으면 이미 털려 있다."*
## 이 한 줄이 NPC 탐험가를 장애물이 아니라 **경쟁자**로 만든다. 무한하면
## 남이 먼저 가든 말든 상관없고, 그러면 판에 사람이 여럿 있을 이유가 없다.
##
## ## 왜 `Room` 에 넣지 않았나
##
## 방은 **위치**이고 귀중품은 **판의 진행 상태**다. 같은 설계도로 다시 판을 짜면
## 방은 그대로지만 귀중품은 처음부터 다시 놓여야 한다. 방에 넣어 두면
## 그 둘이 한 수명을 갖게 되어, 판을 다시 세울 때 무엇을 비워야 하는지가 흐려진다.
##
## 값은 전부 잠정이다. 굴려 보고 정한다
## (docs/design/17-dungeon-generation.md §17.8 과 같은 태도).

## 귀중품방의 값 범위.
const TREASURE_MIN := 3
const TREASURE_MAX := 6

## 보스방. **고위험 고보상**이므로 한 자리에 크게 놓는다 (§5.2).
const BOSS_MIN := 8
const BOSS_MAX := 12

## 방 id -> 남은 가치.
var _values: Dictionary = {}


## 판 위에 귀중품을 놓는다.
##
## **설계도가 아니라 판(`DungeonGraph`)을 읽는다.** 설계도가 없는 판이 있기 때문이다
## (렉카 시험이 손으로 세운 그래프를 쓴다). 방 종류는 `Room` 이 이미 들고 있으므로
## 설계도를 거칠 이유가 없다.
static func for_graph(graph: DungeonGraph, rng: RandomNumberGenerator) -> LootTable:
	var table := LootTable.new()
	if graph == null:
		return table
	for room_id in graph.room_ids():
		var room := graph.get_room(room_id)
		if room == null:
			continue
		match room.kind:
			Room.Kind.TREASURE:
				table.put(room_id, rng.randi_range(TREASURE_MIN, TREASURE_MAX))
			Room.Kind.BOSS:
				table.put(room_id, rng.randi_range(BOSS_MIN, BOSS_MAX))
	return table


func put(room_id: String, value: int) -> void:
	if value <= 0:
		_values.erase(room_id)
		return
	_values[room_id] = value


func value_at(room_id: String) -> int:
	return int(_values.get(room_id, 0))


func has_loot(room_id: String) -> bool:
	return value_at(room_id) > 0


## 그 방의 귀중품을 통째로 가져간다. 없으면 0 이고, **두 번째 사람은 빈손이다.**
func take(room_id: String) -> int:
	var value := value_at(room_id)
	_values.erase(room_id)
	return value


## 아직 남아 있는 방들. NPC 가 어디로 갈지 고를 때 읽는다.
func remaining_room_ids() -> Array[String]:
	var ids: Array[String] = []
	for room_id in _values:
		ids.append(str(room_id))
	return ids


func total_remaining() -> int:
	var total := 0
	for room_id in _values:
		total += int(_values[room_id])
	return total


func is_empty() -> bool:
	return _values.is_empty()
