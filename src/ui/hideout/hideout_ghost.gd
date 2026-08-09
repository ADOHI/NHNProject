class_name HideoutGhostView
extends Node2D
## 놓는 중인 건물의 미리보기. 커서를 따라다니므로 **매 프레임 다시 그려진다.**
##
## 바닥·건물과 노드를 나눈 이유가 이것이다 (HideoutFloorView 참고).
##
## ## 놓을 수 있는지를 색 하나로 말한다
##
## 못 놓는 이유가 둘이다 — **판 밖**과 **겹침**. §22.8.5 가 같은 문제를 만났을 때
## 내린 판단(둘 다 흐리게 두면 왜 안 되는지 구분이 안 된다)을 따라, 이유 문장은
## 화면 위 글자로 따로 내보내고 여기서는 **된다/안 된다**만 색으로 말한다.

## 미리보기는 실제 건물보다 낮게 그린다. 같은 높이면 놓기 전인지 놓은 뒤인지 안 갈린다.
const _GHOST_HEIGHT := 40.0

var _iso: IsoProjection
var _plan: HideoutPlacement


func bind(iso: IsoProjection, plan: HideoutPlacement) -> void:
	_iso = iso
	_plan = plan
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if _iso == null or _plan == null or not _plan.is_active() or not _plan.is_aimed():
		return
	var origin := _plan.origin()
	var footprint := _plan.footprint()
	var allowed := _plan.reason().is_empty()
	var base := _iso.rect_polygon(origin, footprint)
	var edge := HideoutPalette.HOVER_LINE if allowed else HideoutPalette.BLOCKED_LINE
	var fill := HideoutPalette.HOVER_FILL if allowed else HideoutPalette.BLOCKED_FILL

	draw_colored_polygon(base, fill)
	_draw_outline(base, edge)
	_draw_box(base, edge, allowed)
	_draw_cell_marks(origin, footprint)


## 발자국 위로 상자를 세운다. 바닥 마름모만 그리면 **얼마나 자리를 먹는지**는 보여도
## 무엇이 서는지는 안 보인다.
func _draw_box(base: PackedVector2Array, edge: Color, allowed: bool) -> void:
	var lift := Vector2(0.0, -_GHOST_HEIGHT)
	var roof := PackedVector2Array()
	for point in base:
		roof.append(point + lift)
	var roof_fill := HideoutPalette.roof_of(_plan.facility_kind())
	roof_fill.a = 0.55 if allowed else 0.30
	draw_colored_polygon(roof, roof_fill)
	_draw_outline(roof, edge)
	for index in [1, 2, 3]:
		draw_line(base[index], base[index] + lift, edge, 1.5)


## 발자국이 몇 칸인지를 칸 선으로 보여 준다. 마름모 하나만 그리면
## 2x3 인지 3x2 인지가 각도 때문에 헷갈린다.
func _draw_cell_marks(origin: Vector2i, footprint: Vector2i) -> void:
	var faint := HideoutPalette.HOVER_LINE
	faint.a = 0.35
	for offset_y in footprint.y:
		for offset_x in footprint.x:
			_draw_outline(_iso.cell_polygon(origin + Vector2i(offset_x, offset_y)), faint)


func _draw_outline(polygon: PackedVector2Array, color: Color) -> void:
	var line := PackedVector2Array(polygon)
	line.append(line[0])
	draw_polyline(line, color, 2.0)
