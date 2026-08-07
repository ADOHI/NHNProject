class_name DungeonBlueprint
extends RefCounted
## 던전 한 판의 설계도. 방 목록 · 고도 · 종류 · 연결을 담는다.
##
## DungeonGraph 가 위상(누가 어디와 이어져 있는가)만 다루는 데 반해,
## 여기에는 화면 배치를 만들 재료가 있다. 좌표를 Room 에 넣지 않은 이유는
## 그것이 판의 규칙이 아니라 표현이기 때문이다.
## 같은 판을 다르게 그릴 수는 있어도, 같은 판이 다르게 이어질 수는 없다.
##
## **좌표는 이제 생성 단계에서 나온다.** 예전에는 연결 관계만 저장하고 좌표를
## 힘 기반 완화로 만들어 냈지만, 그 순서로는 간선 교차가 풀리지 않는다
## (docs/design/17-dungeon-generation.md §17.3).
## 자리를 먼저 정하고 그 자리에서 연결을 고르는 쪽으로 뒤집었으므로,
## 설계도는 생성기가 정한 좌표를 그대로 들고 다닌다.
##
## 좌표가 없는 설계도(손으로 짠 판, 테스트 픽스처)도 여전히 layout() 을 부를 수 있다.
## 그때만 예전의 밀고 당기기가 돌아간다.
##
## 탑뷰라 고도는 배치에 쓰지 않는다 (§17.6).
##
## build() 로 매번 새 DungeonGraph 를 만든다. 설계도는 재사용되고 판은 소모된다.

## 좌표가 정해지지 않은 방의 표시값.
##
## 별도의 has_position 필드를 두지 않는 이유는, 값과 플래그가 따로 놀면
## 한쪽만 갱신되는 사고가 나기 때문이다.
const NO_POSITION := Vector2.INF

## 배치를 다듬는 횟수. 늘리면 고르게 퍼지지만 생성이 느려진다.
const _RELAX_STEPS := 240

## 방 사이 최소 간격 (목표 간격 대비). 방 위젯 너비보다 커야 이름이 겹치지 않는다.
const _MIN_GAP_RATIO := 0.9

## 겹침을 푸는 횟수. 한 쌍을 떼면 다른 쌍이 붙을 수 있어 여러 번 돈다.
const _SEPARATE_PASSES := 40

var _rooms: Dictionary = {}
var _connections: Array[Array] = []


## 방을 설계도에 추가한다. 체인으로 이어 쓸 수 있다.
##
## position 의 단위는 **방 사이 최소 간격 1** 이다. 화면 픽셀로 옮기는 것은
## layout() 의 몫이라, 설계도는 화면 크기를 몰라도 된다.
func add_room(
	id: String,
	display_name: String,
	elevation: int = 0,
	kind: Room.Kind = Room.Kind.EMPTY,
	position: Vector2 = NO_POSITION
) -> DungeonBlueprint:
	if _rooms.has(id):
		push_error("이미 존재하는 방 id 입니다: %s" % id)
		return self
	_rooms[id] = {"name": display_name, "elevation": elevation, "kind": kind, "position": position}
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


## 생성기가 정해 둔 좌표. 없으면 NO_POSITION.
##
## 단위는 방 사이 최소 간격 1 이다. 화면 좌표가 필요하면 layout() 을 쓴다.
func position_of(id: String) -> Vector2:
	return _rooms[id]["position"] if _rooms.has(id) else NO_POSITION


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
## 생성기가 좌표를 이미 정해 두었으면 그것을 간격만큼 확대해 돌려준다.
## **그 좌표에서 간선을 골랐기 때문에 다른 좌표로 그리면 교차가 되살아난다.**
##
## 좌표가 없는 설계도에서만 예전의 밀고 당기기가 돈다. 그때는 layout_seed 가
## 배치를 가른다. 좌표가 있으면 시드는 쓰이지 않는다 — 같은 판은 이미 같은 자리다.
##
## 결과가 화면보다 커도 된다. 판은 스크롤해서 본다 ([`07`] §7.8).
func layout(layout_seed: int, spacing: float = 200.0) -> Dictionary:
	if _rooms.is_empty():
		return {}

	var ids := room_ids()
	ids.sort()
	var positions := _placed(ids, spacing)
	if positions.is_empty():
		positions = _relaxed(ids, layout_seed, spacing)
	_normalize(ids, positions, spacing)
	return positions


## 생성기가 정해 둔 좌표. 하나라도 빠져 있으면 빈 사전을 돌려준다.
##
## 일부만 좌표가 있는 상태는 섞어 쓸 수 없다. 나머지를 완화로 채우면
## 그 방들이 정해진 방들 사이를 뚫고 지나간다.
func _placed(ids: Array[String], spacing: float) -> Dictionary:
	var positions: Dictionary = {}
	for id in ids:
		var position: Vector2 = _rooms[id]["position"]
		if position == NO_POSITION:
			return {}
		positions[id] = position * spacing
	return positions


## 좌표가 없는 설계도용 대체 배치.
##
## 연결된 방은 당기고 모든 방은 서로 밀어낸다. 밀도도 교차도 보장하지 못하지만,
## 손으로 짠 작은 판을 화면에 올릴 수단은 있어야 한다.
func _relaxed(ids: Array[String], layout_seed: int, spacing: float) -> Dictionary:
	# 방이 늘어나면 틀도 넓어져야 한다. 넓이가 방 수에 비례하므로 한 변은 제곱근에 비례한다.
	var frame := spacing * sqrt(float(ids.size())) * 0.95
	var positions := _scatter(ids, layout_seed, frame)

	for step in _RELAX_STEPS:
		# 처음에는 크게 움직이고 갈수록 잠잠해진다.
		# 이 냉각이 없으면 서로 밀고 당기며 끝없이 진동한다.
		var temperature := frame * 0.1 * (1.0 - float(step) / float(_RELAX_STEPS))
		_relax(ids, positions, spacing, temperature, frame)

	_separate(ids, positions, spacing)
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
