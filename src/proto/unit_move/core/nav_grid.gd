class_name ProtoNavGrid
extends RefCounted
## 방 하나의 바닥을 칸으로 나눈 통행 격자. 흐름장의 바탕이 되고, 몸통이 벽에 박히는 것을 막는다.
##
## 노드에 의존하지 않는다. 화면에 무엇으로 그리든(도형이든 나중에 붙을 배경 스프라이트든)
## 이동 판정은 이 격자만 본다.

## 8방향 이웃. 대각선은 비용이 더 든다.
const _NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, 1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(-1, -1),
]

const _DIAGONAL_COST := 1.41421356

## 가로 칸 수.
var cols: int

## 세로 칸 수.
var rows: int

## 칸 한 변의 길이(픽셀).
var cell_size: float

var _blocked: PackedByteArray


func _init(grid_cols: int, grid_rows: int, size: float) -> void:
	cols = maxi(1, grid_cols)
	rows = maxi(1, grid_rows)
	cell_size = maxf(1.0, size)
	_blocked = PackedByteArray()
	_blocked.resize(cols * rows)


## 필드 전체 크기(픽셀).
func field_size() -> Vector2:
	return Vector2(cols * cell_size, rows * cell_size)


func field_center() -> Vector2:
	return field_size() * 0.5


func cell_index(cell: Vector2i) -> int:
	return cell.y * cols + cell.x


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cols and cell.y < rows


func is_walkable(cell: Vector2i) -> bool:
	return is_inside(cell) and _blocked[cell_index(cell)] == 0


func set_blocked(cell: Vector2i, value: bool) -> void:
	if is_inside(cell):
		_blocked[cell_index(cell)] = 1 if value else 0


func clear_blocked() -> void:
	for i in _blocked.size():
		_blocked[i] = 0


func world_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / cell_size), floori(point.y / cell_size))


## 칸의 중심 좌표. 대형 자리를 칸 위에 놓을 때 쓴다.
func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * cell_size, (cell.y + 0.5) * cell_size)


func is_point_walkable(point: Vector2) -> bool:
	return is_walkable(world_to_cell(point))


## 이 위치에 반지름만큼의 몸통이 들어가는가. 칸 중심만 보면 모서리에 몸이 낀다.
func is_circle_free(point: Vector2, radius: float) -> bool:
	var lo := world_to_cell(point - Vector2(radius, radius))
	var hi := world_to_cell(point + Vector2(radius, radius))
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			if not is_walkable(Vector2i(x, y)):
				return false
	return true


## 가장 가까운 통행 가능 지점. 벽을 찍었을 때 명령을 버리지 않고 가까운 곳으로 돌린다.
##
## 명령이 조용히 무시되는 것이 조작감을 가장 크게 해친다. 벽을 찍어도 유닛은 움직여야 한다.
func nearest_walkable(point: Vector2) -> Vector2:
	if is_point_walkable(point):
		return point
	var origin := world_to_cell(point)
	for ring in range(1, maxi(cols, rows)):
		var best := Vector2.INF
		var best_distance := INF
		for y in range(origin.y - ring, origin.y + ring + 1):
			for x in range(origin.x - ring, origin.x + ring + 1):
				var cell := Vector2i(x, y)
				if not is_walkable(cell):
					continue
				var center := cell_to_world(cell)
				var distance := center.distance_squared_to(point)
				if distance < best_distance:
					best_distance = distance
					best = center
		if best_distance < INF:
			return best
	return field_center()


## 벽에 몸이 박힌 유닛을 가장 가까운 빈 곳으로 밀어낸다.
##
## 밀치기와 격자 보정이 겹치면 드물게 몸이 벽 안으로 들어간다. 그대로 두면 그 유닛은
## 영원히 나오지 못한다. 매 프레임 확인하고 빼내는 쪽이 예방 조건을 늘리는 것보다 확실하다.
func push_out(point: Vector2, radius: float) -> Vector2:
	if is_circle_free(point, radius):
		return point
	var step := cell_size * 0.5
	for ring in range(1, 8):
		for i in 8:
			var angle := TAU * float(i) / 8.0
			var candidate := point + Vector2.from_angle(angle) * step * ring
			if is_circle_free(candidate, radius):
				return candidate
	return nearest_walkable(point)


## 두 점 사이가 몸통 굵기로 뚫려 있는가. 흐름장을 무시하고 직선으로 갈지 판단한다.
func has_line_of_sight(from: Vector2, to: Vector2, clearance: float) -> bool:
	var delta := to - from
	var length := delta.length()
	if length < 0.001:
		return true
	var direction := delta / length
	var step := maxf(cell_size * 0.5, 1.0)
	var travelled := 0.0
	while travelled < length:
		if not is_circle_free(from + direction * travelled, clearance):
			return false
		travelled += step
	return is_circle_free(to, clearance)


## 목적지를 향한 흐름장을 만든다.
##
## 다익스트라를 완전한 우선순위 큐로 짜지 않고 큐 기반 완화(SPFA)로 둔 이유는
## 칸이 이천 개 수준이라 상수 차이가 의미 없고, 힙보다 코드가 짧아 틀릴 여지가 적어서다.
func build_flow_field(target: Vector2) -> ProtoFlowField:
	var field := ProtoFlowField.new(self, target)
	var count := cols * rows
	field.costs.resize(count)
	field.dirs.resize(count)
	for i in count:
		field.costs[i] = ProtoFlowField.UNREACHABLE
		field.dirs[i] = Vector2.ZERO
	if not is_walkable(field.goal_cell):
		return field
	_integrate(field)
	_derive_directions(field)
	return field


## 목적지에서 바깥으로 비용을 퍼뜨린다.
func _integrate(field: ProtoFlowField) -> void:
	var start := cell_index(field.goal_cell)
	field.costs[start] = 0.0
	var queue: Array[int] = [start]
	var queued := PackedByteArray()
	queued.resize(cols * rows)
	queued[start] = 1
	var head := 0
	while head < queue.size():
		var index := queue[head]
		head += 1
		queued[index] = 0
		var cell := Vector2i(index % cols, index / cols)
		var base := field.costs[index]
		for offset in _NEIGHBORS:
			var next := cell + offset
			if not is_walkable(next):
				continue
			if offset.x != 0 and offset.y != 0 and not _diagonal_open(cell, offset):
				continue
			var step := _DIAGONAL_COST if offset.x != 0 and offset.y != 0 else 1.0
			var next_index := cell_index(next)
			if base + step >= field.costs[next_index] - 0.0001:
				continue
			field.costs[next_index] = base + step
			if queued[next_index] == 0:
				queued[next_index] = 1
				queue.append(next_index)


## 대각선으로 벽 모서리를 뚫고 지나가지 못하게 한다. 양옆이 모두 막혀 있으면 그 대각선은 없다.
func _diagonal_open(cell: Vector2i, offset: Vector2i) -> bool:
	var side_a := is_walkable(cell + Vector2i(offset.x, 0))
	var side_b := is_walkable(cell + Vector2i(0, offset.y))
	return side_a and side_b


## 각 칸에서 비용이 가장 낮은 이웃 쪽으로 방향을 정한다.
func _derive_directions(field: ProtoFlowField) -> void:
	for index in field.costs.size():
		if field.costs[index] >= ProtoFlowField.UNREACHABLE:
			continue
		var cell := Vector2i(index % cols, index / cols)
		var best := field.costs[index]
		var best_offset := Vector2i.ZERO
		for offset in _NEIGHBORS:
			var next := cell + offset
			if not is_walkable(next):
				continue
			if offset.x != 0 and offset.y != 0 and not _diagonal_open(cell, offset):
				continue
			var value := field.costs[cell_index(next)]
			if value < best:
				best = value
				best_offset = offset
		if best_offset != Vector2i.ZERO:
			field.dirs[index] = Vector2(best_offset).normalized()
