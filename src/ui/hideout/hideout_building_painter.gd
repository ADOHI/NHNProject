class_name HideoutBuildingPainter
extends RefCounted
## 건물 한 채를 그린다. **노드가 아니라 화가다.**
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
## ## 그림이 있으면 스프라이트, 없으면 도형
##
## fit 산출물(`docs/design/samples/hideout_art/fitted/<slug>_<n>l.png`)이 있으면
## 발자국 아래꼭짓점(남)에 기준점을 맞춰 찍는다 (§30.10.5).
## 없으면 예전처럼 마름모 지붕·벽 도형.

const _FITTED_DIR := "res://docs/design/samples/hideout_art/fitted/"

## path -> ImageTexture. CompressedTexture2D 는 gl_compatibility 에서
## draw_texture 가 흰 사각형으로 나오는 경우가 있어 파일에서 다시 만든다.
static var _texture_cache: Dictionary = {}


## 건물 한 채를 그린다. canvas 가 실제로 그릴 CanvasItem 이다.
static func paint(canvas: CanvasItem, iso: IsoProjection, building: HideoutBuilding) -> void:
	# 배회 그림이 draw_set_transform 을 쓰므로 건물 그리기 전에 되돌린다.
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var base := iso.rect_polygon(building.origin, building.footprint)
	var south: Vector2 = base[2]
	var texture := _fitted_texture(building)
	if texture != null:
		_paint_sprite(canvas, building, texture, south)
		return

	var lift := Vector2(0.0, -building.height_px())
	var roof := PackedVector2Array()
	for point in base:
		roof.append(point + lift)

	# 벽은 앞쪽 두 면만 보인다. base 는 위 - 오른쪽 - 아래 - 왼쪽 순서다.
	var east := base[1]
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


## fit 된 PNG 를 남쪽 꼭짓점 = 기준점에 맞춰 찍는다.
static func _paint_sprite(
	canvas: CanvasItem, building: HideoutBuilding, texture: Texture2D, south: Vector2
) -> void:
	var pivot := HideoutBuildingArt.pivot(building.footprint, building.storeys)
	var origin := south - Vector2(pivot)
	var size := texture.get_size()
	canvas.draw_texture_rect(texture, Rect2(origin, size), false)


static func _fitted_texture(building: HideoutBuilding) -> Texture2D:
	var slug := _slug(building.facility_kind)
	if slug.is_empty():
		return null
	var path := "%s%s_%dl.png" % [_FITTED_DIR, slug, building.storeys]
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D
	var abs_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return null
	var image := Image.load_from_file(abs_path)
	if image == null or image.is_empty():
		return null
	var texture := ImageTexture.create_from_image(image)
	_texture_cache[path] = texture
	return texture


static func _slug(facility_kind: int) -> String:
	match facility_kind:
		Facility.Kind.WORKSHOP:
			return "workshop"
		Facility.Kind.INTEL_ROOM:
			return "intel_room"
		Facility.Kind.CONTACT_POINT:
			return "contact_point"
		_:
			return ""


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
