class_name DungeonGraph
extends RefCounted
## 방들의 연결 그래프. 이 게임의 판이다.
##
## 타일 그리드가 아니라 노드 그래프인 이유는 조우 · 협상 · 경쟁이 방 단위로 전부 성립하는
## 반면, 타일 그리드는 경로탐색 · 시야 · 타일맵 UI 를 전부 요구하기 때문이다
## (docs/design/07-level-design.md §7.1).
##
## 이 클래스의 핵심은 adjacent_threat() 하나다.
## 플레이어는 인접한 방들의 위험도 "합"만 볼 수 있고 그 구성은 볼 수 없다.
## 합이 6 일 때 그것이 보스 하나인지 잡몹 넷인지 모른다는 모호함이 곧 게임이다.

## 방 id -> Room
var _rooms: Dictionary = {}

## 방 id -> 인접한 방 id 배열
var _neighbors: Dictionary = {}


## 방을 판에 추가한다. 같은 id 를 두 번 넣으면 두 번째는 무시된다.
func add_room(room: Room) -> void:
	if _rooms.has(room.id):
		push_error("이미 존재하는 방 id 입니다: %s" % room.id)
		return
	_rooms[room.id] = room
	_neighbors[room.id] = [] as Array[String]


## 두 방을 잇는다. 연결은 언제나 양방향이다.
##
## 한쪽만 이어지는 통로는 이 게임에 없다. 일방통행을 넣게 되면
## "서로 지나쳐 간다"(§5.6 E2)는 규칙부터 다시 정의해야 한다.
func connect_rooms(a_id: String, b_id: String) -> void:
	if not _rooms.has(a_id) or not _rooms.has(b_id):
		push_error("존재하지 않는 방을 연결하려 했습니다: %s <-> %s" % [a_id, b_id])
		return
	if a_id == b_id:
		push_error("방을 자기 자신과 연결할 수 없습니다: %s" % a_id)
		return
	_link(a_id, b_id)
	_link(b_id, a_id)


func has_room(room_id: String) -> bool:
	return _rooms.has(room_id)


func get_room(room_id: String) -> Room:
	return _rooms.get(room_id)


func room_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _rooms:
		ids.append(id)
	return ids


func neighbors_of(room_id: String) -> Array[String]:
	if not _neighbors.has(room_id):
		push_error("존재하지 않는 방입니다: %s" % room_id)
		return [] as Array[String]
	return (_neighbors[room_id] as Array[String]).duplicate()


func are_connected(a_id: String, b_id: String) -> bool:
	if not _neighbors.has(a_id):
		return false
	return (_neighbors[a_id] as Array[String]).has(b_id)


## 특정 방 자체의 위험도.
##
## 플레이어에게 직접 공개되는 값이 아니다. 공개되는 것은 adjacent_threat() 다.
func threat_at(room_id: String) -> int:
	var room := get_room(room_id)
	if room == null:
		push_error("존재하지 않는 방입니다: %s" % room_id)
		return 0
	return room.threat()


## 인접한 방들의 위험도 합. **플레이어가 보는 숫자다.**
##
## 이 값은 정확하지만 모호하다. 합은 참이되 그 합이 어떻게 구성되어 있는지는 알려 주지
## 않는다. 그래서 렉카 기사(구체적이지만 못 믿는다)와 성질이 정반대이고,
## 둘을 겹쳐야 진실이 보인다 (docs/design/13-information-design.md §13.6).
##
## 기준이 되는 방 자신은 포함하지 않는다. 이미 그 방에 있으므로 안에 무엇이 있는지
## 직접 보고 있고, 합에 섞으면 "내가 강할수록 주변이 위험해 보이는" 거짓말이 된다.
func adjacent_threat(room_id: String) -> int:
	if not _neighbors.has(room_id):
		push_error("존재하지 않는 방입니다: %s" % room_id)
		return 0
	var total := 0
	for neighbor_id in _neighbors[room_id] as Array[String]:
		total += threat_at(neighbor_id)
	return total


## 인접한 방들에 있는 존재의 총 개수.
##
## 합과 짝을 이루는 두 번째 단서다. 합만으로는 좁혀지지 않는 것이
## 개체 수를 알면 확정된다 — 합 6, 개체 1 이면 보스다.
## 이 정보를 볼 수 있는지는 스쿼드에 누구를 넣었느냐에 달려 있다
## (docs/design/14-squad.md §14.4).
func adjacent_occupant_count(room_id: String) -> int:
	if not _neighbors.has(room_id):
		push_error("존재하지 않는 방입니다: %s" % room_id)
		return 0
	var total := 0
	for neighbor_id in _neighbors[room_id] as Array[String]:
		total += (_rooms[neighbor_id] as Room).occupant_count()
	return total


## 인접한 방들 중 가장 높은 방 하나의 위험도.
##
## 개체 수와는 다른 각도의 단서다. 합 6 · 최댓값 2 라면 한 방에 몰려 있지 않다는 뜻이다.
## 계열마다 다른 각도의 눈을 하나씩 준다는 원칙(docs/design/14-squad.md §14.4.2)이
## 코드에서 서로 다른 조회 함수로 나타난다.
func adjacent_max_threat(room_id: String) -> int:
	if not _neighbors.has(room_id):
		push_error("존재하지 않는 방입니다: %s" % room_id)
		return 0
	var highest := 0
	for neighbor_id in _neighbors[room_id] as Array[String]:
		highest = maxi(highest, threat_at(neighbor_id))
	return highest


## 어느 방에 있든 상관없이 해당 주체를 찾아 그 방의 id 를 돌려준다. 없으면 빈 문자열.
func find_actor_room(actor: Actor) -> String:
	for id in _rooms:
		if (_rooms[id] as Room).has_occupant(actor):
			return id
	return ""


## 주체를 방에 놓는다. 이미 다른 방에 있었다면 그곳에서 뺀다.
##
## 한 주체가 두 방에 동시에 존재하면 위험도가 이중으로 계산되어 판이 거짓말을 한다.
## 이동을 "빼고 넣기" 두 호출로 나누면 그 사이에 상태가 깨지므로 하나로 묶는다.
func place_actor(actor: Actor, room_id: String) -> bool:
	var room := get_room(room_id)
	if room == null:
		push_error("존재하지 않는 방입니다: %s" % room_id)
		return false
	var current := find_actor_room(actor)
	if current == room_id:
		return true
	if not current.is_empty():
		(_rooms[current] as Room).remove_occupant(actor)
	room.add_occupant(actor)
	return true


## 인접한 방으로 이동한다. 이어져 있지 않으면 이동하지 않고 false 를 돌려준다.
func move_actor(actor: Actor, to_room_id: String) -> bool:
	var current := find_actor_room(actor)
	if current.is_empty():
		push_error("판 위에 없는 주체를 이동시키려 했습니다: %s" % actor.id)
		return false
	if not are_connected(current, to_room_id):
		return false
	return place_actor(actor, to_room_id)


func remove_actor(actor: Actor) -> void:
	var current := find_actor_room(actor)
	if not current.is_empty():
		(_rooms[current] as Room).remove_occupant(actor)


func _link(from_id: String, to_id: String) -> void:
	var list: Array[String] = _neighbors[from_id]
	if not list.has(to_id):
		list.append(to_id)
