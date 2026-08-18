class_name HideoutFloorView
extends Node2D
## 아지트 바닥 마름모만 그린다. 판이 바뀔 때만 다시 그린다.
##
## 사람 · 건물과 같은 노드에서 그리면 매 프레임 칸 전체(사백 칸)를 다시 훑게 된다.
## 바닥은 건물을 놓을 때 말고는 바뀌지 않는데 배회 때문에 함께 다시 그려지는 것이 낭비다.
## 웹은 단일 스레드라 이 낭비가 그대로 프레임 예산을 먹는다
## (ProtoTerrainView 가 같은 이유로 같은 형태다).

var _grid: HideoutGrid
var _iso: IsoProjection


func bind(grid: HideoutGrid, iso: IsoProjection) -> void:
	_grid = grid
	_iso = iso
	queue_redraw()


## 판을 바꾼 쪽이 불러 준다.
func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if _grid == null or _iso == null:
		return
	_draw_cells()
	_draw_board_edge()


func _draw_cells() -> void:
	for row in _grid.rows:
		for column in _grid.cols:
			var cell := Vector2i(column, row)
			var polygon := _iso.cell_polygon(cell)
			var fill := (
				HideoutPalette.FLOOR_FILL
				if (column + row) % 2 == 0
				else HideoutPalette.FLOOR_FILL_ALT
			)
			draw_colored_polygon(polygon, fill)
			draw_polyline(_closed(polygon), HideoutPalette.FLOOR_LINE, 1.0)


## 판의 바깥 테두리. 어디까지가 아지트인지가 칸 선만으로는 안 읽힌다.
func _draw_board_edge() -> void:
	var polygon := _iso.rect_polygon(Vector2i.ZERO, Vector2i(_grid.cols, _grid.rows))
	draw_polyline(_closed(polygon), HideoutPalette.BOARD_EDGE, 2.0)


## draw_polyline 은 닫지 않는다. 첫 점을 뒤에 붙여 닫는다.
static func _closed(polygon: PackedVector2Array) -> PackedVector2Array:
	var line := PackedVector2Array(polygon)
	if line.size() > 0:
		line.append(line[0])
	return line
