class_name DungeonGenerator
extends RefCounted
## 던전 절차 생성기. 설계는 docs/design/17-dungeon-generation.md 참고.
##
## **순서가 이 생성기의 전부다.**
##
##     자리(블루 노이즈) -> 삼각분할 -> **구역** -> 간선 선택 -> 고도 -> 방 종류
##
## 예전에는 반대였다. 층을 나눠 그래프를 먼저 만들고 나중에 힘 기반 완화로 펼쳤다.
## 그 순서에서는 평면에 그릴 수 없는 그래프가 나올 수 있고, 그러면 레이아웃이
## 아무리 애써도 교차가 풀리지 않는다. 밀도가 고르지 않은 것도 같은 뿌리다 —
## 배치가 그래프를 따라가느라 밀도를 직접 통제할 수 없었다.
##
## 순서를 뒤집으면 둘 다 사라진다. 자리를 먼저 정하니 밀도를 직접 정하고,
## 후보 간선이 전부 삼각분할에서 나오니 무엇을 골라도 교차하지 않는다.
##
## ## 재시도 루프가 없다
##
## 예전 생성기는 판을 만들고 검증해서 실패하면 통째로 버리고 다시 만들었다.
## 지금은 각 규칙을 **구조로** 보장한다.
##
## | 규칙 | 어떻게 보장하는가 |
## | --- | --- |
## | 간선이 교차하지 않는다 | 후보가 들로네 부분집합이다 (DelaunayTriangulation) |
## | 밀도가 고르다 | 푸아송 디스크 샘플링 (PoissonDiskSampler) |
## | 축척이 둘이다 | 구역 안은 촘촘, 구역 사이는 관문 하나 (DungeonZones) |
## | 모든 방에 도달 가능 | 뼈대가 갈라지면 가장 짧고 읽히는 들로네 간선으로 붙인다 (DungeonEdgeSelector) |
## | 민첩 0 탈출구가 있다 | 입구에서 탈출구까지 지형을 깎는다 (DungeonTerrain) |
## | 입구에 갈림길이 있다 | 차수가 모자라면 들로네 간선을 붙인다 (DungeonEdgeSelector) |
##
## 단계마다 파일이 다르다 (src/core/dungeon/generation/).
## 한 파일에 몰아넣으면 어느 단계가 어느 규칙을 책임지는지 알 수 없게 된다.
##
## 생성은 시드를 받는다. 같은 시드는 같은 판을 만든다 (§17.7).


## 생성 파라미터. 전부 잠정 수치이며 굴려 보고 정한다 (§17.8).
class Params:
	extends RefCounted

	## 목표 방 개수. 실제로는 이 값 안팎으로 나온다 (PoissonDiskSampler.expected_count).
	var room_count := 19

	## 뼈대 위에 더할 곁가지 간선 수 (방 개수 대비). 난이도 손잡이다 (§17.2).
	var extra_edge_ratio := 0.24

	## 막다른 방(차수 1) 비율의 허용 범위. 없애는 것이 아니라 관리한다 (§17.2).
	var dead_end_ratio_min := 0.14
	var dead_end_ratio_max := 0.30

	## **구역 등급 하나가 오를 때의 단차.**
	##
	## 예전에는 "입구에서 방 하나 거리만큼 멀어질 때 오르는 고도"였다. 거리 원뿔은
	## 어디를 봐도 기울기가 같아 절벽이 생기지 않았다 (DungeonTerrain 주석 참고).
	##
	## **기본값이 2 인 것은 스쿼드 기본 민첩으로 넘을 수 있는 크기이기 때문이다.**
	## 지형으로 판 전체를 막지 않는다 — 벽은 보상 봉우리와 지름길에만 세운다.
	var elevation_gain := 2.0

	## 층 안의 잔 기복. 0 이면 구역마다 칼같이 평평해진다.
	##
	## 단차(2)보다 작아야 층이 읽힌다. 크면 노이즈가 층을 덮어 구역 경계가 사라진다.
	var elevation_amplitude := 1.0

	## 기복의 잔 정도. 크면 옆방끼리 고도가 널뛴다.
	##
	## 이 값은 **던전 성격으로 흔들지 않는다.** 실측에서 신호대잡음이 0.12 였고
	## 단조롭지도 않았다 (§17.16.3).
	var elevation_frequency := 0.22

	## 탈출구로 삼을 방을 고를 때의 최소 거리 (최대 거리 대비).
	##
	## 민첩으로 막을 수 없는 대신 거리로 막는다 (RoomKindPlanner 참고).
	var exit_distance_ratio := 0.65

	## 고가치 방의 비율.
	var treasure_ratio := 0.14

	## 위험방의 비율.
	var hazard_ratio := 0.16


var _rng := RandomNumberGenerator.new()
var _params: Params
var _seed: int


func _init(seed_value: int = 0, params: Params = null) -> void:
	_seed = seed_value
	_rng.seed = seed_value
	_params = params if params != null else Params.new()


## 판 하나를 만든다. 실패하지 않는다 — 규칙은 전부 구조로 보장된다.
func generate() -> DungeonBlueprint:
	var region := PoissonDiskSampler.region_for_count(_params.room_count)
	var points := PoissonDiskSampler.new(region).generate(_rng)
	if points.size() < 3:
		return _tiny(points)

	var delaunay := DelaunayTriangulation.edges(points)
	var entrance := _pick_entrance(points, region)

	# 구역을 먼저 나눈다. 간선 선택이 이 위에 서고, 고도와 경로 시공도 그럴 것이다
	# (docs/design/17-dungeon-generation.md §17.17).
	var zone_count := DungeonZones.count_for(points.size())
	var zones := DungeonZones.assign(points, entrance, zone_count)
	var zone_links := DungeonZones.ring(
		points,
		zones,
		DungeonZones.readable_boundaries(points, delaunay, zones),
		zone_count,
		zones[entrance]
	)
	var ranks := DungeonZones.ranks(zone_links, zones[entrance], zone_count)

	# 고도는 구역 등급에서 나온다. 구역 안은 평탄하고 경계에서만 층이 진다.
	var elevations := DungeonTerrain.assign(
		points,
		zones,
		ranks,
		entrance,
		_seed,
		_params.elevation_gain,
		_params.elevation_amplitude,
		_params.elevation_frequency
	)

	var selector := DungeonEdgeSelector.new(
		points, delaunay, elevations, entrance, zones, zone_links
	)
	selector.extra_ratio = _params.extra_edge_ratio
	selector.dead_end_ratio_min = _params.dead_end_ratio_min
	selector.dead_end_ratio_max = _params.dead_end_ratio_max
	var edges := selector.select(_rng)

	var parents := _breadth_first(points.size(), edges, entrance)
	var exit_index := _pick_exit(parents, entrance)
	var route := _route_to(parents, exit_index)
	elevations = DungeonTerrain.carve_route(elevations, route)
	elevations = DungeonTerrain.ensure_a_climb_exists(elevations, _farthest_off(parents, route), 2)

	return _assemble(points, edges, elevations, entrance, exit_index)


# ---------------------------------------------------------------- 자리 고르기


## 입구는 판 가장자리에 놓는다.
##
## 한가운데에서 시작하면 사방이 똑같이 열려 있어 "어느 쪽이 깊은가"가 읽히지 않는다.
## 모서리에서 시작하면 판 전체가 한 방향으로 뻗어 나가는 그림이 되고,
## 고도가 거리에 비례하므로 그 방향이 그대로 깊이가 된다.
func _pick_entrance(points: PackedVector2Array, region: Vector2) -> int:
	var corners: Array[Vector2] = [
		Vector2.ZERO, Vector2(region.x, 0.0), Vector2(0.0, region.y), region
	]
	var corner := corners[_rng.randi() % corners.size()]
	var best := 0
	var best_distance := INF
	for index in points.size():
		var distance := corner.distance_squared_to(points[index])
		if distance < best_distance:
			best_distance = distance
			best = index
	return best


## 탈출구는 입구에서 충분히 먼 방들 중에서 고른다.
##
## 코앞에 있으면 "언제 나갈까"가 판단이 아니라 반사 신경이 된다
## (docs/design/02-overview.md §2.3-A).
func _pick_exit(parents: Dictionary, entrance: int) -> int:
	var depths: Dictionary = parents["depth"]
	var deepest := 0
	for index in depths:
		deepest = maxi(deepest, int(depths[index]))
	var threshold := int(ceil(float(deepest) * _params.exit_distance_ratio))

	var candidates: Array[int] = []
	for index in depths:
		if index != entrance and int(depths[index]) >= threshold:
			candidates.append(int(index))
	if candidates.is_empty():
		return entrance
	candidates.sort()
	return candidates[_rng.randi() % candidates.size()]


## 탈출 경로 위에 있지 않으면서 입구에서 가장 먼 방.
##
## 오르막이 하나도 없는 판이 나왔을 때 여기를 올린다. 경로 위를 올리면
## 방금 깎아 놓은 민첩 0 탈출로가 다시 막힌다.
func _farthest_off(parents: Dictionary, route: PackedInt32Array) -> int:
	var depths: Dictionary = parents["depth"]
	var best := -1
	var best_depth := -1
	for index in depths:
		if route.has(int(index)):
			continue
		if int(depths[index]) > best_depth:
			best_depth = int(depths[index])
			best = int(index)
	return best


# ---------------------------------------------------------------- 그래프 훑기


## 입구에서의 너비 우선 탐색. 깊이와 부모를 함께 돌려준다.
func _breadth_first(count: int, edges: Array[Vector2i], start: int) -> Dictionary:
	var neighbors := {}
	for edge in edges:
		if not neighbors.has(edge.x):
			neighbors[edge.x] = [] as Array[int]
		if not neighbors.has(edge.y):
			neighbors[edge.y] = [] as Array[int]
		(neighbors[edge.x] as Array[int]).append(edge.y)
		(neighbors[edge.y] as Array[int]).append(edge.x)

	var depth := {start: 0}
	var parent := {start: -1}
	var frontier: Array[int] = [start]
	while not frontier.is_empty():
		var current: int = frontier.pop_front()
		for neighbor in neighbors.get(current, [] as Array[int]) as Array[int]:
			if depth.has(neighbor):
				continue
			depth[neighbor] = int(depth[current]) + 1
			parent[neighbor] = current
			frontier.append(neighbor)
	# count 는 도달하지 못한 방이 없는지 확인하는 용도로만 쓴다.
	if depth.size() != count:
		push_error("연결되지 않은 방이 있습니다: %d / %d" % [depth.size(), count])
	return {"depth": depth, "parent": parent}


## 입구에서 target 까지의 경로 (방 인덱스 목록).
func _route_to(parents: Dictionary, target: int) -> PackedInt32Array:
	var parent: Dictionary = parents["parent"]
	var route := PackedInt32Array()
	var current := target
	while current >= 0 and parent.has(current):
		route.append(current)
		current = int(parent[current])
	return route


# ---------------------------------------------------------------- 조립


## 뼈대를 세우고, 그 위에서 방 종류를 정한 **새 설계도**를 만든다.
##
## 기존 설계도를 고치지 않고 새로 만드는 이유는, DungeonBlueprint 에
## "나중에 방을 수정하는" 경로를 열지 않기 위해서다.
## 그 경로가 생기면 어떤 값이 언제 확정되는지가 흐려진다.
func _assemble(
	points: PackedVector2Array,
	edges: Array[Vector2i],
	elevations: PackedInt32Array,
	entrance: int,
	exit_index: int
) -> DungeonBlueprint:
	var skeleton := DungeonBlueprint.new()
	for index in points.size():
		skeleton.add_room(
			_id_of(index), _id_of(index), elevations[index], Room.Kind.EMPTY, points[index]
		)
	for edge in edges:
		skeleton.connect_rooms(_id_of(edge.x), _id_of(edge.y))

	var kinds := RoomKindPlanner.plan(
		skeleton.build(),
		_id_of(entrance),
		_id_of(exit_index),
		_rng,
		_params.treasure_ratio,
		_params.hazard_ratio
	)

	var result := DungeonBlueprint.new()
	var used_names := {}
	for index in points.size():
		var id := _id_of(index)
		var kind: Room.Kind = kinds.get(id, Room.Kind.EMPTY)
		result.add_room(
			id,
			RoomKindPlanner.pick_name(kind, used_names, _rng),
			elevations[index],
			kind,
			points[index]
		)
	for edge in edges:
		result.connect_rooms(_id_of(edge.x), _id_of(edge.y))
	return result


## 삼각분할이 성립하지 않는 아주 작은 판. 실제로는 나오지 않지만 계약을 지킨다.
func _tiny(points: PackedVector2Array) -> DungeonBlueprint:
	var result := DungeonBlueprint.new()
	var kinds: Array[int] = [Room.Kind.ENTRANCE, Room.Kind.EXIT]
	for index in points.size():
		var kind: Room.Kind = kinds[index] if index < kinds.size() else Room.Kind.EMPTY
		result.add_room(_id_of(index), _id_of(index), 0, kind, points[index])
	for index in range(1, points.size()):
		result.connect_rooms(_id_of(index - 1), _id_of(index))
	return result


func _id_of(index: int) -> String:
	return "r%d" % index
