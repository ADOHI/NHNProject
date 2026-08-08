class_name ProtoNavGrid
extends RefCounted
## 방 하나의 바닥을 칸으로 나눈 통행 격자. 흐름장의 바탕이 되고, 몸통이 벽에 박히는 것을 막는다.
##
## 노드에 의존하지 않는다. 화면에 무엇으로 그리든(도형이든 나중에 붙을 배경 스프라이트든)
## 이동 판정은 이 격자만 본다.

const _DIAGONAL_COST := 1.41421356

## 벽까지의 거리를 잴 때 쓰는 상하좌우. **대각선을 안 쓴다** - "벽이 몸에 닿는가"는
## 상하좌우 거리로 결정되고, 대각선을 넣으면 모서리에서 실제보다 멀다고 답한다.
const _SIDES: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

## 벽에서 이만큼 칸 떨어지면 그 이상은 이득이 없다(칸).
##
## **포화가 없으면 좁은 문을 아예 안 지나간다.** 두 칸짜리 문은 모든 칸이 벽에 붙어 있어서
## 상한 없는 페널티를 물리면 우회로가 조금이라도 있을 때 통째로 돌아가 버린다.
## 이 판의 문이 정확히 두 칸이라 직격이다. 몸 반지름 12 픽셀에 칸이 32 픽셀이니
## 두 칸(64 픽셀) 떨어지면 벽이 몸에 닿을 일이 없다 - 거기서 끊는다.
const _WALL_COST_SPAN := 2

## 벽 거리를 이 칸까지만 재고 그 너머는 뭉뚱그린다.
##
## 값을 매기는 데는 두 칸이면 되는데 **한 칸 더 재는 이유는 성능이다** - 걸음 고르기가
## "내 둘레에 벽이 아예 없다"를 이 값 하나로 알아채고 벽 표본을 통째로 건너뛴다.
## 세 칸(96 픽셀)이면 몸 반지름 12 에 내다보는 거리 32 를 더해도 벽에 닿을 수 없다.
const _WALL_CLEAR_TARGET := 3

## 벽에 바싹 붙은 칸이 무는 추가 비용의 비율.
##
## 크게 잡으면 문 앞에서 줄이 서는 대신 멀리 돌아가고, 0 이면 벽을 스치듯 지나며 몸이
## 벽에 걸린다. 이 값은 **길이 여럿일 때 가운데를 고르게 하는 정도**이지 우회를 시키는
## 값이 아니다. 0.6 이면 벽에 붙은 칸이 한 칸 반의 값을 치른다.
const _WALL_PENALTY := 0.6

## 막힌 칸이 무는 추가 비용의 비율.
##
## **이 값이 곧 "얼마나 멀면 돌아갈 만한가"다.** 3.0 이면 막힌 칸 하나가 네 칸 값을 하므로,
## 막힌 곳 세 칸을 피하려고 아홉 칸까지 돌아간다. 무한대로 두면(아예 막으면) 길이 하나뿐일 때
## 갈 곳이 없어지고, 0 이면 기억이 없는 것과 같다.
const _JAM_PENALTY := 1.2

## 벽에서 밀어낼 때 훑는 방향 수와 고리 수. 걸음 크기는 `push_out` 이 몸 크기에서 정한다.
const _PUSH_OUT_DIRECTIONS := 12
const _PUSH_OUT_RINGS := 12

## 가로 칸 수.
var cols: int

## 세로 칸 수.
var rows: int

## 칸 한 변의 길이(픽셀).
var cell_size: float

var _blocked: PackedByteArray

## 칸마다 벽까지의 거리(칸). **지형이 바뀔 때만 굽는다.**
##
## 이 값이 목적지와 무관하다는 것이 전부다. 흐름장은 명령마다 새로 만들어야 하지만
## 벽은 안 움직이므로 여기 담아 두고 계속 쓴다. 명령당 추가 비용은 배열 조회 한 번이다.
var _clearance: PackedInt32Array

## 위 값이 지금 지형과 맞는가. 벽이 바뀌면 내려간다.
var _clearance_ready := false

## 흐름장을 만드는 동안만 들고 있는 막힘 표. 만들고 나면 비운다.
var _jam: PackedByteArray = PackedByteArray()


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
		_clearance_ready = false


func clear_blocked() -> void:
	for i in _blocked.size():
		_blocked[i] = 0
	_clearance_ready = false


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
	# **걸음이 굵으면 바로 옆의 빈자리를 건너뛴다.** 한 칸 폭 통로에서 몸이 들어갈 수 있는 띠는
	# 칸 폭에서 지름을 뺀 만큼뿐이다(32 픽셀 통로에 지름 24 면 8 픽셀). 걸음이 16 픽셀이면
	# 그 띠를 매번 뛰어넘어 어느 고리에서도 답을 못 찾고, 결국 통로 밖 넓은 곳까지 밀려나
	# **유닛이 100 픽셀 너머로 순간이동한다.** 그 순간이동으로 앞을 막은 아군 여섯을 통째로
	# 통과하는 것을 보고 찾았다. 걸음을 몸 크기에 묶고, 같은 고리에서는 가장 가까운 곳을 고른다.
	var step := minf(cell_size * 0.25, maxf(radius * 0.5, 1.0))
	for ring in range(1, _PUSH_OUT_RINGS + 1):
		var best := Vector2.INF
		var best_distance := INF
		for i in _PUSH_OUT_DIRECTIONS:
			var angle := TAU * float(i) / float(_PUSH_OUT_DIRECTIONS)
			var candidate := point + Vector2.from_angle(angle) * step * ring
			if not is_circle_free(candidate, radius):
				continue
			var distance := candidate.distance_squared_to(point)
			if distance < best_distance:
				best_distance = distance
				best = candidate
		if best_distance < INF:
			return best
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


## 이 칸이 벽에서 몇 칸 떨어져 있는가. 벽 자체는 0 이다.
##
## 처음 물을 때 한 번 굽고, 벽이 바뀔 때까지 다시 굽지 않는다.
func clearance_at(cell: Vector2i) -> int:
	if not is_inside(cell):
		return 0
	_ensure_clearance()
	return _clearance[cell_index(cell)]


## 벽에서 바깥으로 퍼지는 너비 우선 탐색. 모든 벽 칸에서 동시에 출발한다.
##
## 벽마다 따로 재면 칸 수 곱하기 벽 수가 되는데, 전부 한 큐에 넣고 한 번만 퍼뜨리면
## 칸 수만큼만 든다. 대각선을 안 쓰는 이유는 **"벽이 몸에 닿는가"가 상하좌우 거리로
## 결정되기 때문**이다 - 대각선을 넣으면 모서리에서 실제보다 멀다고 답한다.
func _ensure_clearance() -> void:
	if _clearance_ready:
		return
	_clearance_ready = true
	var count := cols * rows
	_clearance = PackedInt32Array()
	_clearance.resize(count)
	var queue := PackedInt32Array()
	for index in count:
		if _blocked[index] == 1:
			_clearance[index] = 0
			queue.append(index)
		else:
			_clearance[index] = -1
	var head := 0
	while head < queue.size():
		var index := queue[head]
		head += 1
		var cell := Vector2i(index % cols, index / cols)
		var next_distance := _clearance[index] + 1
		if next_distance > _WALL_CLEAR_TARGET:
			continue
		for offset in _SIDES:
			var next := cell + offset
			if not is_inside(next):
				continue
			var next_index := cell_index(next)
			if _clearance[next_index] >= 0:
				continue
			_clearance[next_index] = next_distance
			queue.append(next_index)
	# 목표 거리 너머는 굳이 정확히 알 필요가 없다. 포화 지점 값을 그대로 준다.
	for index in count:
		if _clearance[index] < 0:
			_clearance[index] = _WALL_CLEAR_TARGET


## 벽을 피하는 것이 곧 지터를 피하는 것이다.
##
## **참고:** 벽에 몸이 걸리면 걸음 고르기가 후보를
## 갈아 끼우고, 그 갈아 끼움이 방향의 왕복이 된다. 흐름장이 처음부터 통로 가운데를
## 가리키면 그 일이 안 생긴다. 경로를 펴는 것이 아니라 **조향 목표를 안 튀게 하는 것**이다.
## 목적지를 향한 흐름장을 만든다.
##
## 다익스트라를 완전한 우선순위 큐로 짜지 않고 큐 기반 완화(SPFA)로 둔 이유는
## 칸이 이천 개 수준이라 상수 차이가 의미 없고, 힙보다 코드가 짧아 틀릴 여지가 적어서다.
## `jam` 은 칸마다 "여기 막혀 있다"를 담은 표다(칸 수와 같은 길이, 1 이면 막힘).
## 비어 있으면 지형만 보고 만든다.
func build_flow_field(target: Vector2, jam: PackedByteArray = PackedByteArray()) -> ProtoFlowField:
	_jam = jam
	var field := ProtoFlowField.new(self, target)
	var count := cols * rows
	field.costs.resize(count)
	field.dirs.resize(count)
	for i in count:
		field.costs[i] = ProtoFlowField.UNREACHABLE
		field.dirs[i] = Vector2.ZERO
	if not is_walkable(field.goal_cell):
		return field
	_ensure_clearance()
	_integrate(field)
	_derive_directions(field)
	_jam = PackedByteArray()
	return field


## 목적지에서 바깥으로 비용을 퍼뜨린다.
##
## **여기서 함수를 부르지 않는다.** 이 반복문은 칸 수 곱하기 여덟 번 도는데, 예전에는 한 번
## 돌 때마다 `is_walkable` · `cell_index` · `_diagonal_open`(그 안에서 또 두 번)을 불렀다.
## 2040 칸이면 GDScript 함수 호출만 오만 번이고, **그 호출 비용이 계산 비용보다 컸다.**
## 60 × 34 판에서 흐름장 한 번이 44 밀리초, 우클릭한 프레임이 세 프레임어치 멎었다.
##
## 알고리즘은 그대로다. 이웃을 좌표가 아니라 **평평한 번호의 덧셈**으로 짚고, 벽 판정을
## 배열에서 바로 읽는다. 경계 검사는 x · y 를 지역 변수로 들고 직접 한다.
func _integrate(field: ProtoFlowField) -> void:
	var start := cell_index(field.goal_cell)
	var costs := field.costs
	costs[start] = 0.0
	var count := cols * rows
	var queue := PackedInt32Array()
	queue.append(start)
	var queued := PackedByteArray()
	queued.resize(count)
	queued[start] = 1
	var head := 0
	while head < queue.size():
		var index := queue[head]
		head += 1
		queued[index] = 0
		var x := index % cols
		var y := index / cols
		var base := costs[index]
		# 상하좌우가 뚫려 있는지 먼저 알아 둔다. 대각선 판정이 이 값을 그대로 쓴다.
		var west := x > 0 and _blocked[index - 1] == 0
		var east := x < cols - 1 and _blocked[index + 1] == 0
		var north := y > 0 and _blocked[index - cols] == 0
		var south := y < rows - 1 and _blocked[index + cols] == 0
		if west:
			_relax(field, queue, queued, index - 1, base + _cell_step(index - 1, 1.0))
		if east:
			_relax(field, queue, queued, index + 1, base + _cell_step(index + 1, 1.0))
		if north:
			_relax(field, queue, queued, index - cols, base + _cell_step(index - cols, 1.0))
		if south:
			_relax(field, queue, queued, index + cols, base + _cell_step(index + cols, 1.0))
		# 대각선은 양옆이 다 뚫려 있어야 간다. 벽 모서리를 뚫고 지나가지 못하게 하는 규칙이다.
		if north and west and _blocked[index - cols - 1] == 0:
			var i := index - cols - 1
			_relax(field, queue, queued, i, base + _cell_step(i, _DIAGONAL_COST))
		if north and east and _blocked[index - cols + 1] == 0:
			var i := index - cols + 1
			_relax(field, queue, queued, i, base + _cell_step(i, _DIAGONAL_COST))
		if south and west and _blocked[index + cols - 1] == 0:
			var i := index + cols - 1
			_relax(field, queue, queued, i, base + _cell_step(i, _DIAGONAL_COST))
		if south and east and _blocked[index + cols + 1] == 0:
			var i := index + cols + 1
			_relax(field, queue, queued, i, base + _cell_step(i, _DIAGONAL_COST))


## 이 칸에 들어가는 값. 벽에 붙을수록 비싸다.
func _cell_step(index: int, step: float) -> float:
	# **막힌 곳은 비싸게 만든다. 못 가게 하는 것이 아니다.**
	#
	# 아예 못 가게 막으면 길이 하나뿐일 때 갈 곳이 없어진다. 값을 물리면 돌아갈 길이 있을
	# 때만 돌아가고, 없으면 비싸도 그리로 간다 - 판단이 저절로 난다.
	if index < _jam.size() and _jam[index] == 1:
		step *= 1.0 + _JAM_PENALTY
	var clear := _clearance[index]
	if clear >= _WALL_COST_SPAN:
		return step
	return step * (1.0 + _WALL_PENALTY * (1.0 - float(clear) / float(_WALL_COST_SPAN)))


## 더 싼 길을 찾았으면 갈아 끼우고 다시 퍼뜨릴 목록에 넣는다.
func _relax(
	field: ProtoFlowField,
	queue: PackedInt32Array,
	queued: PackedByteArray,
	index: int,
	value: float
) -> void:
	if value >= field.costs[index] - 0.0001:
		return
	field.costs[index] = value
	if queued[index] == 0:
		queued[index] = 1
		queue.append(index)


## 각 칸에서 비용이 가장 낮은 이웃 쪽으로 방향을 정한다.
##
## **흐름장 생성 시간의 44 퍼센트가 여기였다**(2040 칸에서 19.2 밀리초). 원인은 알고리즘이
## 아니라 호출 횟수다 - 칸마다 이웃 여덟을 보면서 `is_walkable` · `cell_index` ·
## `_diagonal_open` 을 불렀고, 그것만 오만 번이 넘었다. `_integrate` 와 같은 방식으로
## 평평한 번호와 배열 직접 읽기로 바꿨다. 나오는 값은 한 글자도 다르지 않다.
func _derive_directions(field: ProtoFlowField) -> void:
	var costs := field.costs
	var dirs := field.dirs
	var count := cols * rows
	for index in count:
		var best := costs[index]
		if best >= ProtoFlowField.UNREACHABLE:
			continue
		var x := index % cols
		var y := index / cols
		var west := x > 0 and _blocked[index - 1] == 0
		var east := x < cols - 1 and _blocked[index + 1] == 0
		var north := y > 0 and _blocked[index - cols] == 0
		var south := y < rows - 1 and _blocked[index + cols] == 0
		var best_index := -1
		if west and costs[index - 1] < best:
			best = costs[index - 1]
			best_index = index - 1
		if east and costs[index + 1] < best:
			best = costs[index + 1]
			best_index = index + 1
		if north and costs[index - cols] < best:
			best = costs[index - cols]
			best_index = index - cols
		if south and costs[index + cols] < best:
			best = costs[index + cols]
			best_index = index + cols
		if north and west and _blocked[index - cols - 1] == 0 and costs[index - cols - 1] < best:
			best = costs[index - cols - 1]
			best_index = index - cols - 1
		if north and east and _blocked[index - cols + 1] == 0 and costs[index - cols + 1] < best:
			best = costs[index - cols + 1]
			best_index = index - cols + 1
		if south and west and _blocked[index + cols - 1] == 0 and costs[index + cols - 1] < best:
			best = costs[index + cols - 1]
			best_index = index + cols - 1
		if south and east and _blocked[index + cols + 1] == 0 and costs[index + cols + 1] < best:
			best = costs[index + cols + 1]
			best_index = index + cols + 1
		if best_index < 0:
			continue
		var step := Vector2(best_index % cols - x, best_index / cols - y)
		dirs[index] = step.normalized()
