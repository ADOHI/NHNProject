class_name DungeonBlueprint
extends RefCounted
## 던전 한 판의 설계도. 방 목록 · 고도 · 종류 · 연결을 담는다.
##
## DungeonGraph 가 위상(누가 어디와 이어져 있는가)만 다루는 데 반해,
## 여기에는 화면 배치를 만들 재료가 있다. 좌표를 Room 에 넣지 않은 이유는
## 그것이 판의 규칙이 아니라 표현이기 때문이다.
## 같은 판을 다르게 그릴 수는 있어도, 같은 판이 다르게 이어질 수는 없다.
##
## **좌표는 저장하지 않고 고도에서 만들어 낸다** (§layout).
## 고도가 게임 규칙이면서 동시에 레이아웃 축이라
## 절차 생성에서 배치를 따로 설계하지 않아도 된다
## (docs/design/17-dungeon-generation.md §17.6).
##
## build() 로 매번 새 DungeonGraph 를 만든다. 설계도는 재사용되고 판은 소모된다.

var _rooms: Dictionary = {}
var _connections: Array[Array] = []


## 방을 설계도에 추가한다. 체인으로 이어 쓸 수 있다.
func add_room(
	id: String, display_name: String, elevation: int = 0, kind: Room.Kind = Room.Kind.EMPTY
) -> DungeonBlueprint:
	if _rooms.has(id):
		push_error("이미 존재하는 방 id 입니다: %s" % id)
		return self
	_rooms[id] = {"name": display_name, "elevation": elevation, "kind": kind}
	return self


## 두 방을 잇는다. 연결은 언제나 양방향이다.
func connect_rooms(a_id: String, b_id: String) -> DungeonBlueprint:
	if not _rooms.has(a_id) or not _rooms.has(b_id):
		push_error("존재하지 않는 방을 연결하려 했습니다: %s <-> %s" % [a_id, b_id])
		return self
	if a_id == b_id:
		push_error("방을 자기 자신과 연결할 수 없습니다: %s" % a_id)
		return self
	for pair in _connections:
		if (pair[0] == a_id and pair[1] == b_id) or (pair[0] == b_id and pair[1] == a_id):
			return self
	_connections.append([a_id, b_id] as Array)
	return self


func has_room(id: String) -> bool:
	return _rooms.has(id)


func room_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _rooms:
		ids.append(id)
	return ids


func display_name_of(id: String) -> String:
	return _rooms[id]["name"] if _rooms.has(id) else ""


func elevation_of(id: String) -> int:
	return _rooms[id]["elevation"] if _rooms.has(id) else 0


func kind_of(id: String) -> Room.Kind:
	return _rooms[id]["kind"] if _rooms.has(id) else Room.Kind.EMPTY


## 해당 종류의 방 id 들.
func rooms_of_kind(kind: Room.Kind) -> Array[String]:
	var result: Array[String] = []
	for id in _rooms:
		if _rooms[id]["kind"] == kind:
			result.append(id)
	return result


## 연결 목록의 복사본. 선을 그릴 때 쓴다.
func connections() -> Array[Array]:
	return _connections.duplicate()


## 설계도대로 새 판을 만든다.
func build() -> DungeonGraph:
	var graph := DungeonGraph.new()
	for id in _rooms:
		var data: Dictionary = _rooms[id]
		graph.add_room(Room.new(id, data["name"], data["elevation"], data["kind"]))
	for pair in _connections:
		graph.connect_rooms(pair[0], pair[1])
	return graph


# ---------------------------------------------------------------- 배치


## 방들의 화면 좌표를 계산한다. 방 id -> Vector2.
##
## Y 는 고도다. **높은 방이 위로 간다.** 그래서 플레이어는 설명 없이
## "위로 갈수록 어렵다"와 "아래는 도주로"를 읽는다
## (docs/design/07-level-design.md §7.2.6.2).
##
## X 는 같은 고도 안에서 균등 분산한다. 연결 관계까지 반영한 최적 배치는
## 하지 않는다 — 판이 수십 개 방 규모라 얻는 것에 비해 비용이 크다.
func layout(area: Rect2) -> Dictionary:
	if _rooms.is_empty():
		return {}

	var by_elevation: Dictionary = {}
	for id in _rooms:
		var elevation: int = _rooms[id]["elevation"]
		if not by_elevation.has(elevation):
			by_elevation[elevation] = [] as Array[String]
		(by_elevation[elevation] as Array[String]).append(id)

	# 고도가 높은 층부터 위에서 아래로.
	var elevations: Array = by_elevation.keys()
	elevations.sort()
	elevations.reverse()

	# 고도 실값이 아니라 층 순서로 배분한다. 실값에 비례시키면 고도차가 큰 판에서
	# 방들이 한쪽에 뭉쳐 읽기 어려워진다. 상승폭은 막힌 방에 숫자로 따로 보여 준다.
	#
	# 가장자리에 정확히 걸치지 않도록 X 와 같은 방식으로 나눈다.
	# 방 위젯은 이 좌표를 중심으로 그려지므로 경계에 놓이면 화면 밖으로 삐져나간다.
	var positions: Dictionary = {}
	var row_step := area.size.y / float(elevations.size() + 1)
	for row_index in elevations.size():
		var row: Array[String] = by_elevation[elevations[row_index]]
		row.sort()
		var y := area.position.y + row_step * float(row_index + 1)
		var column_step := area.size.x / float(row.size() + 1)
		# 층마다 좌우로 살짝 엇갈리게 둔다. 층별 방 개수가 같으면 방들이 격자처럼
		# 줄을 맞춰 서서 판이 표처럼 보인다. 엇갈리면 지도처럼 읽힌다.
		var stagger := column_step * (0.15 if row_index % 2 == 0 else -0.15)
		for i in row.size():
			var x := area.position.x + column_step * float(i + 1) + stagger
			positions[row[i]] = Vector2(x, y)
	return positions
