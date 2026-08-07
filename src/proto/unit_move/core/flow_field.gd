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


## 이 지점에서 나아갈 방향.
##
## 목적지가 그대로 보일 때는 부르는 쪽이 직선으로 처리한다. 흐름장은 8방향이라
## 그대로 따르면 열린 방에서 유닛이 계단처럼 꺾여 걷는다. 장애물이 낀 구간에서만
## 흐름장이 필요하고, 방 대부분은 열려 있다.
func direction_at(from: Vector2, clearance: float) -> Vector2:
	var cell := _grid.world_to_cell(from)
	if not _grid.is_inside(cell):
		var back := _grid.field_center() - from
		return back.normalized() if back.length_squared() > 0.01 else Vector2.ZERO
	var dir := dirs[_grid.cell_index(cell)]
	if dir == Vector2.ZERO:
		# 닿을 수 없는 칸에 서 있다. 목적지 쪽으로 밀어 두면 통행 가능 구역으로 빠져나온다.
		var fallback := goal - from
		return fallback.normalized() if fallback.length_squared() > 0.01 else Vector2.ZERO
	return _avoid_wall(from, dir, clearance)


## 이 칸의 누적 비용. 개발 표시용이며 범위를 벗어나면 도달 불가로 답한다.
func cost_at(cell: Vector2i) -> float:
	if not _grid.is_inside(cell):
		return UNREACHABLE
	return costs[_grid.cell_index(cell)]


## 흐름장 방향이 벽을 스칠 때 반지름만큼 비껴 준다.
##
## 흐름장은 칸 중심 기준이라 몸통이 벽에 걸리는 것을 모른다. 이 보정이 없으면
## 유닛이 모서리에 붙어 비비면서 속도를 잃는다.
func _avoid_wall(from: Vector2, dir: Vector2, clearance: float) -> Vector2:
	if _grid.is_circle_free(from + dir * clearance, clearance):
		return dir
	var side := Vector2(-dir.y, dir.x)
	var right := dir.rotated(PI * 0.25)
	var left := dir.rotated(-PI * 0.25)
	if _grid.is_circle_free(from + right * clearance, clearance):
		return right
	if _grid.is_circle_free(from + left * clearance, clearance):
		return left
	return side if _grid.is_circle_free(from + side * clearance, clearance) else dir
