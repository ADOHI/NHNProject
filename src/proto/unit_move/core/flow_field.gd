class_name ProtoFlowField
extends RefCounted
## 목적지 하나로 향하는 격자 흐름장. 이동 명령 하나당 한 번 계산해 그 명령을 받은 전원이 공유한다.
##
## 유닛마다 경로를 따로 찾지 않는 이유는 둘이다.
##
## 1. 같은 곳으로 가는 스무 명은 같은 경로를 쓴다. 스무 번 계산할 이유가 없다.
## 2. 칸마다 방향이 미리 놓여 있으면, 남에게 밀려 경로를 벗어난 유닛도
##    다시 계산하지 않고 **지금 서 있는 칸의 방향**을 그대로 읽으면 된다.
##    경로를 들고 다니는 방식은 밀려날 때마다 재탐색이 필요하고, 그 재탐색이
##    여럿에게 동시에 걸리면 웹 단일 스레드에서 그대로 프레임 끊김이 된다.

## 닿을 수 없는 칸의 비용. 실수 무한대를 쓰면 비교식이 NaN 을 만들 수 있어 큰 유한값을 쓴다.
const UNREACHABLE := 1.0e18

## 흐름장이 향하는 지점(월드 좌표).
var goal: Vector2

## 목적지 칸. 도달 불가 지점을 찍었을 때는 가장 가까운 통행 가능 칸으로 옮겨져 있다.
var goal_cell: Vector2i

## 칸별 목적지까지의 누적 비용. 개발 표시에서 그대로 그린다.
var costs: PackedFloat32Array

## 칸별 진행 방향(단위 벡터). 도달 불가 칸은 영벡터다.
var dirs: PackedVector2Array

var _grid: ProtoNavGrid


func _init(grid: ProtoNavGrid, target: Vector2) -> void:
	_grid = grid
	goal = target
	goal_cell = grid.world_to_cell(grid.nearest_walkable(target))
	costs = PackedFloat32Array()
	dirs = PackedVector2Array()


## 이 지점에서 나아갈 방향. **칸 사이를 섞어 읽는다.**
##
## 목적지가 그대로 보일 때는 부르는 쪽이 직선으로 처리한다. 흐름장은 8방향이라
## 그대로 따르면 열린 방에서 유닛이 계단처럼 꺾여 걷는다. 장애물이 낀 구간에서만
## 흐름장이 필요하고, 방 대부분은 열려 있다.
##
## **칸 하나만 읽으면 그것이 그대로 지터가 된다.** 칸마다 방향은 8 방향 중 하나로
## 고정되어 있어, 유닛이 칸 경계를 넘는 순간 조향 방향이 45 도씩 통째로 뛴다.
## 회전 속도 제한은 그 뜀을 부드럽게 만들어 주지 않는다 — 튀는 목표를 쫓아가게 만들 뿐이라
## 좌우 왕복으로 바뀐다. 재어 보니 좁은 통로에서 조향 방향의 꺾임이 열린 곳의 다섯 배였고,
## 흐름장을 쓰는 프레임 비율과 그대로 맞물렸다.
##
## 그래서 둘레 네 칸의 방향을 위치로 가중 평균한다. 격자를 연속적인 장으로 읽는 셈이고,
## 칸 경계에서의 뜀이 사라진다. 값을 읽는 비용은 네 배지만 흐름장을 쓰는 프레임 자체가
## 열린 곳에서는 백에 하나라 전체 비용은 거의 그대로다.
func direction_at(from: Vector2, clearance: float) -> Vector2:
	var cell := _grid.world_to_cell(from)
	if not _grid.is_inside(cell):
		var back := _grid.field_center() - from
		return back.normalized() if back.length_squared() > 0.01 else Vector2.ZERO
	var dir := _blended_direction(from)
	if dir == Vector2.ZERO:
		# 닿을 수 없는 칸에 서 있다. 목적지 쪽으로 밀어 두면 통행 가능 구역으로 빠져나온다.
		var fallback := goal - from
		return fallback.normalized() if fallback.length_squared() > 0.01 else Vector2.ZERO
	return _avoid_wall(from, dir, clearance)


## 둘레 네 칸의 방향을 칸 안에서의 위치로 가중 평균한다. 닿을 수 없는 칸은 셈에서 뺀다.
func _blended_direction(from: Vector2) -> Vector2:
	var size := _grid.cell_size
	# 칸 중심을 격자점으로 삼는다. 그래야 중심에서 가중치가 온전히 그 칸에 실린다.
	var base := from / size - Vector2(0.5, 0.5)
	var corner := Vector2i(floori(base.x), floori(base.y))
	var frac := base - Vector2(corner)
	var total := Vector2.ZERO
	for offset_y in 2:
		var weight_y := frac.y if offset_y == 1 else 1.0 - frac.y
		for offset_x in 2:
			var neighbor := corner + Vector2i(offset_x, offset_y)
			if not _grid.is_walkable(neighbor):
				continue
			var index := _grid.cell_index(neighbor)
			if costs[index] >= UNREACHABLE:
				continue
			var weight_x := frac.x if offset_x == 1 else 1.0 - frac.x
			total += dirs[index] * weight_x * weight_y
	if total.length_squared() > 0.0001:
		return total.normalized()
	# 네 칸이 모두 벽이거나 닿을 수 없다. 서 있는 칸의 값을 그대로 쓴다.
	return dirs[_grid.cell_index(_grid.world_to_cell(from))]


## 이 칸의 누적 비용. 개발 표시용이며 범위를 벗어나면 도달 불가로 답한다.
func cost_at(cell: Vector2i) -> float:
	if not _grid.is_inside(cell):
		return UNREACHABLE
	return costs[_grid.cell_index(cell)]


## 이 칸에서 목적지로 가는 길이 있는가.
##
## `cost_at(cell) < UNREACHABLE` 로 물으면 **안 된다.** 비용은 float32 에 담기는데
## 1.0e18 은 float32 로 정확히 떨어지지 않아 넣은 값과 읽은 값이 달라진다. 그래서
## 같은지 묻지 않고 자릿수만 본다. 이 실수 때문에 닿을 수 없는 자리를 두고
## 유닛 전원이 계속 움직인 적이 있다.
func is_reachable(cell: Vector2i) -> bool:
	return cost_at(cell) < UNREACHABLE * 0.5


## 흐름장 방향이 벽을 스칠 때 반지름만큼 비껴 준다.
##
## 흐름장은 칸 중심 기준이라 몸통이 벽에 걸리는 것을 모른다. 이 보정이 없으면
## 유닛이 모서리에 붙어 비비면서 속도를 잃는다.
##
## 예전에는 막혔을 때 90 도까지 통째로 꺾었다. 그 꺾임이 칸 경계에서 켜졌다 꺼졌다 하면
## 조향 방향이 그만큼 널뛰어 **보정이 곧 지터가 되었다.** 지금은 45 도까지만 기울이고,
## 양쪽이 다 열려 있으면 아예 건드리지 않는다 — 어느 쪽으로 돌지 매 프레임 다시 고르는 것이
## 좌우 진동의 씨앗이기 때문이다.
func _avoid_wall(from: Vector2, dir: Vector2, clearance: float) -> Vector2:
	if _grid.is_circle_free(from + dir * clearance, clearance):
		return dir
	var side := Vector2(-dir.y, dir.x)
	var right := (dir + side).normalized()
	var left := (dir - side).normalized()
	var right_open := _grid.is_circle_free(from + right * clearance, clearance)
	var left_open := _grid.is_circle_free(from + left * clearance, clearance)
	if right_open == left_open:
		return dir
	return right if right_open else left
