class_name DungeonBlueprint
extends RefCounted
## 던전 한 판의 설계도. 방 목록 · 연결 · **화면상 배치**를 담는다.
##
## DungeonGraph 가 위상(누가 어디와 이어져 있는가)만 다루는 데 반해,
## 여기에는 화면 좌표가 들어 있다. 좌표를 Room 에 넣지 않은 이유는
## 그것이 판의 규칙이 아니라 표현이기 때문이다.
## 같은 판을 다르게 그릴 수는 있어도, 같은 판이 다르게 이어질 수는 없다.
##
## build() 로 매번 새 DungeonGraph 를 만든다. 설계도는 재사용되고 판은 소모된다.

var _rooms: Dictionary = {}
var _connections: Array[Array] = []


## 방을 설계도에 추가한다. 체인으로 이어 쓸 수 있다.
func add_room(id: String, display_name: String, position: Vector2) -> DungeonBlueprint:
	if _rooms.has(id):
		push_error("이미 존재하는 방 id 입니다: %s" % id)
		return self
	_rooms[id] = {"name": display_name, "position": position}
	return self


## 두 방을 잇는다. 연결은 언제나 양방향이다.
func connect_rooms(a_id: String, b_id: String) -> DungeonBlueprint:
	if not _rooms.has(a_id) or not _rooms.has(b_id):
		push_error("존재하지 않는 방을 연결하려 했습니다: %s <-> %s" % [a_id, b_id])
		return self
	_connections.append([a_id, b_id] as Array)
	return self


func room_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _rooms:
		ids.append(id)
	return ids


func display_name_of(id: String) -> String:
	if not _rooms.has(id):
		return ""
	return _rooms[id]["name"]


## 화면상 중심 좌표.
func position_of(id: String) -> Vector2:
	if not _rooms.has(id):
		return Vector2.ZERO
	return _rooms[id]["position"]


## 연결 목록의 복사본. 선을 그릴 때 쓴다.
func connections() -> Array[Array]:
	return _connections.duplicate()


## 설계도대로 새 판을 만든다.
func build() -> DungeonGraph:
	var graph := DungeonGraph.new()
	for id in _rooms:
		graph.add_room(Room.new(id, _rooms[id]["name"]))
	for pair in _connections:
		graph.connect_rooms(pair[0], pair[1])
	return graph
