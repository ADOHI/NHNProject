class_name HideoutBuildingPainter
extends RefCounted
## 건물 한 채를 도형 셋으로 그린다. **노드가 아니라 화가다.**
##
## ## 왜 노드에서 뺐나
##
## 배회하는 대원이 생기면서 **사람과 건물이 같은 자로 정렬돼야** 했다.
## 건물 뒤로 걸어 들어가면 가려야 하고 앞으로 나오면 보여야 하는데,
## 노드를 나누면 사람이 **항상** 건물 위이거나 **항상** 아래가 된다.
##
## 그리는 것은 HideoutSceneView 한 노드가 맡고, 이 파일은 **어떻게 생겼는가**만 든다.
## 정렬 규칙은 그대로 코어에 있다 (IsoProjection.rect_depth).
##
## ## 그림은 없다
##
## 건물 한 채는 도형 셋이다: 바닥 마름모를 위로 올린 **지붕**, 그리고 앞으로 보이는 **벽 둘**.
## 그림이 오면 이 파일이 통째로 스프라이트로 갈린다
## (docs/design/30-hideout.md §30.2).


## 건물 한 채를 그린다. canvas 가 실제로 그릴 CanvasItem 이다.
static func paint(canvas: CanvasItem, iso: IsoProjection, building: HideoutBuilding) -> void:
	var base := iso.rect_polygon(building.origin, building.footprint)
	var lift := Vector2(0.0, -building.height_px())
	var roof := PackedVector2Array()
	for point in base:
		roof.append(point + lift)

	# 벽은 앞쪽 두 면만 보인다. base 는 위 - 오른쪽 - 아래 - 왼쪽 순서다.
	var east := base[1]
	var south := base[2]
	var west := base[3]
	canvas.draw_colored_polygon(
		PackedVector2Array([west, south, south + lift, west + lift]), HideoutPalette.WALL_LEFT
	)
	canvas.draw_colored_polygon(
		PackedVector2Array([south, east, east + lift, south + lift]), HideoutPalette.WALL_RIGHT
	)
	canvas.draw_colored_polygon(roof, HideoutPalette.roof_of(building.facility_kind))
	canvas.draw_polyline(_closed(roof), HideoutPalette.BUILDING_EDGE, 1.5)
	canvas.draw_line(west, west + lift, HideoutPalette.BUILDING_EDGE, 1.5)
	canvas.draw_line(south, south + lift, HideoutPalette.BUILDING_EDGE, 1.5)
	canvas.draw_line(east, east + lift, HideoutPalette.BUILDING_EDGE, 1.5)
	_paint_label(canvas, building, roof)


## 이름은 지붕 한가운데에 놓는다. 문장은 코어가 만든 것을 그대로 쓴다 (conventions.md §3.1).
static func _paint_label(
	canvas: CanvasItem, building: HideoutBuilding, roof: PackedVector2Array
) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var center := (roof[0] + roof[2]) * 0.5
	var text := building.label()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13).x
	canvas.draw_string(
		font,
		center + Vector2(-width * 0.5, 4.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		13,
		HideoutPalette.TEXT
	)


static func _closed(polygon: PackedVector2Array) -> PackedVector2Array:
	var line := PackedVector2Array(polygon)
	if line.size() > 0:
		line.append(line[0])
	return line
