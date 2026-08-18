class_name HideoutCursorView
extends Node2D
## 마우스가 올라간 칸 하나를 강조한다. **매 프레임 다시 그려지는 유일한 층이다.**
##
## 바닥·건물과 노드를 나눈 이유가 이것이다 — 커서는 마우스를 따라 계속 바뀌는데
## 같은 노드에 두면 바닥 사백 칸이 함께 다시 그려진다 (HideoutFloorView 참고).
##
## ## 이 층이 하는 진짜 일은 검증이다
##
## 아이소에서 가장 흔한 버그는 **클릭한 칸과 그려진 칸이 한 칸 어긋나는 것**이다.
## 커서가 마우스 밑에 정확히 붙어 있는 것이 IsoProjection 왕복이 맞다는 눈에 보이는 증거다.
## (숫자로는 test/unit/test_iso_projection.gd 가 같은 것을 지킨다.)

var _iso: IsoProjection

## 지금 가리키는 칸. 판 밖이면 _valid 가 false 다.
var _cell: Vector2i = Vector2i.ZERO
var _valid := false
var _blocked := false


func bind(iso: IsoProjection) -> void:
	_iso = iso
	queue_redraw()


## 가리키는 칸을 바꾼다. 값이 그대로면 다시 그리지 않는다.
func point_at(cell: Vector2i, is_valid: bool, is_blocked: bool) -> void:
	if _cell == cell and _valid == is_valid and _blocked == is_blocked:
		return
	_cell = cell
	_valid = is_valid
	_blocked = is_blocked
	queue_redraw()


func cell() -> Vector2i:
	return _cell


func has_cell() -> bool:
	return _valid


func _draw() -> void:
	if _iso == null or not _valid:
		return
	var polygon := _iso.cell_polygon(_cell)
	var fill := HideoutPalette.BLOCKED_FILL if _blocked else HideoutPalette.HOVER_FILL
	var line := HideoutPalette.BLOCKED_LINE if _blocked else HideoutPalette.HOVER_LINE
	draw_colored_polygon(polygon, fill)
	var closed := PackedVector2Array(polygon)
	closed.append(closed[0])
	draw_polyline(closed, line, 2.0)
