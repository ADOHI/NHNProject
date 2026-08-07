class_name ProtoTerrainView
extends Node2D
## 바닥과 벽만 그린다. 장애물이 바뀔 때만 다시 그린다.
##
## 유닛과 같은 노드에서 그리면 매 프레임 격자 전체(이천 칸)를 다시 훑게 된다.
## 지형은 명령 한 번에도 바뀌지 않는데 유닛 때문에 함께 다시 그려지는 것이 낭비다.
## 웹은 단일 스레드라 이런 낭비가 그대로 프레임 예산을 먹는다.

const _FLOOR_COLOR := Color(0.13, 0.14, 0.18)
const _GRID_COLOR := Color(0.18, 0.19, 0.24)
const _WALL_COLOR := Color(0.30, 0.26, 0.30)
const _WALL_EDGE := Color(0.42, 0.37, 0.42)

var grid: ProtoNavGrid


func bind(nav_grid: ProtoNavGrid) -> void:
	grid = nav_grid
	queue_redraw()


## 장애물을 바꾼 쪽이 불러 준다.
func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if grid == null:
		return
	var size := grid.field_size()
	draw_rect(Rect2(Vector2.ZERO, size), _FLOOR_COLOR, true)
	var step := grid.cell_size * 4.0
	var x := step
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), _GRID_COLOR, 1.0)
		x += step
	var y := step
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), _GRID_COLOR, 1.0)
		y += step
	_draw_walls()
	draw_rect(Rect2(Vector2.ZERO, size), _WALL_EDGE, false, 2.0)


func _draw_walls() -> void:
	var cell := grid.cell_size
	for row in grid.rows:
		for column in grid.cols:
			if grid.is_walkable(Vector2i(column, row)):
				continue
			var rect := Rect2(Vector2(column * cell, row * cell), Vector2(cell, cell))
			draw_rect(rect, _WALL_COLOR, true)
			draw_rect(rect, _WALL_EDGE, false, 1.0)
