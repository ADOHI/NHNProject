class_name HideoutBuildingView
extends Node2D
## 놓인 건물 전부를 **차례대로** 그린다. 건물 하나에 노드 하나를 두지 않는다.
##
## 노드를 나누면 겹침 차례를 노드 순서로 지켜야 하고, 건물을 옮길 때마다 트리를 다시 짜게 된다.
## 그 정렬 규칙은 HideoutGrid.buildings_by_depth 가 이미 들고 있고 테스트가 지킨다 —
## 화면은 나온 순서대로 그리기만 한다.
##
## ## 그림은 없다
##
## 건물 한 채는 도형 셋이다: 바닥 마름모를 위로 올린 **지붕**, 그리고 앞으로 보이는 **벽 둘**.
## 그림이 오면 이 파일이 통째로 스프라이트로 갈린다
## (docs/design/30-hideout.md §30.2).

## 건물 높이(픽셀). 잠정값 — 칸 세로 폭의 두 배 남짓이면 층이 있어 보인다.
const BUILDING_HEIGHT := 44.0

var _grid: HideoutGrid
var _iso: IsoProjection
var _font: Font


func bind(grid: HideoutGrid, iso: IsoProjection) -> void:
	_grid = grid
	_iso = iso
	_font = ThemeDB.fallback_font
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if _grid == null or _iso == null:
		return
	for building in _grid.buildings_by_depth():
		_draw_building(building)


func _draw_building(building: HideoutBuilding) -> void:
	var base := _iso.rect_polygon(building.origin, building.footprint)
	var lift := Vector2(0.0, -BUILDING_HEIGHT)
	var roof := PackedVector2Array()
	for point in base:
		roof.append(point + lift)

	# 벽은 앞쪽 두 면만 보인다. base 는 위 - 오른쪽 - 아래 - 왼쪽 순서다.
	var east := base[1]
	var south := base[2]
	var west := base[3]
	draw_colored_polygon(
		PackedVector2Array([west, south, south + lift, west + lift]), HideoutPalette.WALL_LEFT
	)
	draw_colored_polygon(
		PackedVector2Array([south, east, east + lift, south + lift]), HideoutPalette.WALL_RIGHT
	)
	draw_colored_polygon(roof, HideoutPalette.roof_of(building.facility_kind))
	draw_polyline(_closed(roof), HideoutPalette.BUILDING_EDGE, 1.5)
	draw_line(west, west + lift, HideoutPalette.BUILDING_EDGE, 1.5)
	draw_line(south, south + lift, HideoutPalette.BUILDING_EDGE, 1.5)
	draw_line(east, east + lift, HideoutPalette.BUILDING_EDGE, 1.5)
	_draw_label(building, roof)


## 이름은 지붕 한가운데에 놓는다. 문장은 코어가 만든 것을 그대로 쓴다 (conventions.md §3.1).
func _draw_label(building: HideoutBuilding, roof: PackedVector2Array) -> void:
	if _font == null:
		return
	var center := (roof[0] + roof[2]) * 0.5
	var text := building.label()
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13).x
	draw_string(
		_font,
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
