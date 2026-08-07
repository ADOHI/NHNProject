class_name DungeonBlueprint
extends RefCounted
## 던전 한 판의 설계도. 방 목록 · 고도 · 종류 · 연결을 담는다.
##
## DungeonGraph 가 위상(누가 어디와 이어져 있는가)만 다루는 데 반해,
## 여기에는 화면 배치를 만들 재료가 있다. 좌표를 Room 에 넣지 않은 이유는
## 그것이 판의 규칙이 아니라 표현이기 때문이다.
## 같은 판을 다르게 그릴 수는 있어도, 같은 판이 다르게 이어질 수는 없다.
##
## **좌표는 저장하지 않고 연결 관계에서 만들어 낸다** (layout()).
## 탑뷰라 고도는 배치에 쓰지 않는다
## (docs/design/17-dungeon-generation.md §17.6).
##
## build() 로 매번 새 DungeonGraph 를 만든다. 설계도는 재사용되고 판은 소모된다.

## 배치를 다듬는 횟수. 늘리면 고르게 퍼지지만 생성이 느려진다.
const _RELAX_STEPS := 240

## 방 사이 최소 간격 (목표 간격 대비). 방 위젯 너비보다 커야 이름이 겹치지 않는다.
const _MIN_GAP_RATIO := 0.9

## 겹침을 푸는 횟수. 한 쌍을 떼면 다른 쌍이 붙을 수 있어 여러 번 돈다.
const _SEPARATE_PASSES := 40

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


## 방들의 지도 좌표를 계산한다. 방 id -> Vector2.
##
## **탑뷰다. 고도는 배치에 쓰지 않는다.**
## 위에서 내려다보는 시점에서 높이는 평면 위치와 무관하다.
## 고도를 눈으로 보여 주는 것은 나중에 측면뷰가 생기면 그쪽이 맡는다
## (docs/design/17-dungeon-generation.md §17.6).
##
## 연결된 방은 당기고 모든 방은 서로 밀어내는 방식으로 자리를 잡는다.
## 결과가 화면보다 커도 된다 — 판은 스크롤해서 본다.
##
## 같은 시드는 같은 배치를 만든다. 배치가 매번 달라지면
## "아까 그 판"을 다시 볼 수 없다.
func layout(layout_seed: int, spacing: float = 200.0) -> Dictionary:
	if _rooms.is_empty():
		return {}

	var ids := room_ids()
	ids.sort()
	# 방이 늘어나면 틀도 넓어져야 한다. 넓이가 방 수에 비례하므로 한 변은 제곱근에 비례한다.
	var frame := spacing * sqrt(float(ids.size())) * 0.95
	var positions := _scatter(ids, layout_seed, frame)

	for step in _RELAX_STEPS:
		# 처음에는 크게 움직이고 갈수록 잠잠해진다.
		# 이 냉각이 없으면 서로 밀고 당기며 끝없이 진동한다.
		var temperature := frame * 0.1 * (1.0 - float(step) / float(_RELAX_STEPS))
		_relax(ids, positions, spacing, temperature, frame)

	_separate(ids, positions, spacing)
	_normalize(ids, positions, spacing)
	return positions


## 너무 붙은 방들을 떼어 놓는다.
##
## 밀고 당기는 힘만으로는 최소 간격이 보장되지 않는다. 멀리 있는 방까지
## 균형을 맞추다 보면 어떤 쌍은 겹칠 만큼 가까워진다.
## **방이 겹치면 이름도 숫자도 못 읽으므로** 마지막에 강제로 떼어 놓는다.
func _separate(ids: Array[String], positions: Dictionary, spacing: float) -> void:
	var minimum := spacing * _MIN_GAP_RATIO
	for pass_index in _SEPARATE_PASSES:
		var overlapped := false
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				var a: String = ids[i]
				var b: String = ids[j]
				var delta: Vector2 = positions[a] - positions[b]
				var distance := delta.length()
				if distance >= minimum:
					continue
				overlapped = true
				# 완전히 겹쳐 방향이 없으면 임의의 축으로 민다.
				var axis := delta.normalized() if distance > 0.01 else Vector2.RIGHT
				var half := axis * (minimum - distance) * 0.5
				positions[a] += half
				positions[b] -= half
		if not overlapped:
			return


## 틀 안에 고르게 흩뿌린다. 전부 한 점에서 시작하면 밀어내는 힘의 방향이
## 정해지지 않아 배치가 무너진다.
func _scatter(ids: Array[String], layout_seed: int, frame: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	var positions: Dictionary = {}
	for id in ids:
		positions[id] = Vector2(rng.randf_range(0.0, frame), rng.randf_range(0.0, frame))
	return positions


## 한 번 다듬는다. 연결된 방은 당기고, 모든 방끼리는 밀어낸다.
##
## **틀 밖으로 나가지 못하게 가두는 것이 중요하다.** 모든 방이 서로 밀어내는데
## 가둘 틀이 없으면 판이 풍선처럼 계속 부푼다.
func _relax(
	ids: Array[String], positions: Dictionary, spacing: float, temperature: float, frame: float
) -> void:
	var shifts: Dictionary = {}
	for id in ids:
		shifts[id] = Vector2.ZERO

	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: String = ids[i]
			var b: String = ids[j]
			var delta: Vector2 = positions[a] - positions[b]
			var distance := maxf(delta.length(), 1.0)
			var push := delta.normalized() * (spacing * spacing / distance)
			shifts[a] += push
			shifts[b] -= push

	for pair in _connections:
		var delta: Vector2 = positions[pair[0]] - positions[pair[1]]
		var distance := maxf(delta.length(), 1.0)
		var pull := delta.normalized() * (distance * distance / spacing)
		shifts[pair[0]] -= pull
		shifts[pair[1]] += pull

	for id in ids:
		var shift: Vector2 = shifts[id]
		var moved: Vector2 = positions[id] + shift.limit_length(temperature)
		positions[id] = moved.clamp(Vector2.ZERO, Vector2(frame, frame))


## 좌상단이 여백만큼 떨어진 곳에 오도록 통째로 옮긴다.
func _normalize(ids: Array[String], positions: Dictionary, spacing: float) -> void:
	var lowest: Vector2 = positions[ids[0]]
	for id in ids:
		lowest.x = minf(lowest.x, positions[id].x)
		lowest.y = minf(lowest.y, positions[id].y)
	var margin := Vector2(spacing, spacing) * 0.5
	for id in ids:
		positions[id] = positions[id] - lowest + margin
