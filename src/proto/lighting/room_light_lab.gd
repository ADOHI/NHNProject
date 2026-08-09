extends Node2D
## **진짜 방 판 위에서 라이팅을 켰다 껐다 하는 실험대.** 사람이 직접 띄워 만지는 화면이다.
##
##     godot --path . res://src/proto/lighting/room_light_lab.tscn
##     godot --path . res://src/proto/lighting/room_light_lab.tscn -- shot   # 판마다 저장
##
## `docs/design/26-2d-lighting.md` §26.6 의 두 항목을 한 장면이 같이 답한다 —
## 소품 알파에서 뽑은 가림 폴리곤이 **화면에서 그림자를 지우는가**, 그리고
## **판에 구운 그림자와 실시간 그림자가 겹치는가.**
##
## # 왜 「눈으로 본다」가 여기서 특히 중요한가
##
## 이 레인이 답해야 하는 물음은 **비용이 아니라 겹침**이다. 겹침은 숫자로 안 나온다 —
## 프레임 시간은 그림자가 하나든 둘이든 똑같다. 그림자가 두 개로 보이는 것은
## **화면에서만 보인다.** 그래서 판정 도구가 아니라 실험대를 만들었다.
##
## # 조작
##
## | 키 | 무엇 |
## | --- | --- |
## | `1` | 어둠 (`CanvasModulate`) — 켜면 구운 판이 눌리고 실시간 빛이 일할 자리가 생긴다 |
## | `2` | **램프 자리의 실시간 빛** — 이걸 켜는 것이 §26.2.1 이 금지한 그 선택이다 |
## | `3` | **대원 빛** (마우스를 따라온다) — 경계가 허락한 유일한 실시간 빛 |
## | `4` | 가림 폴리곤 on/off |
## | `5` | 폴리곤 외곽선 보기 |
## | `6` | 그림자 필터 순환 (없음 → PCF5 → PCF13) |
## | `[` `]` | 폴리곤 `epsilon` (화면 픽셀). 점 수가 즉시 바뀐다 |
## | `←` `→` | 카메라 |
## | `Tab` | 방 바꾸기 |
##
## # 그림은 저장소에 안 들어온다
##
## 방 판은 방 시각화 레인의 산출물이고 다시 그려진다. 여기 복사해 두면 **낡은 판을
## 붙들고 있는 두 번째 진실**이 된다. 그래서 절대 경로로 읽고, 없으면 화면에 대놓고
## 적는다 (조용히 검은 화면이 되면 원인을 찾는 데 한나절이 든다).

## 방 시각화 레인의 산출물. 저장소 밖이고, 그것이 의도다.
const _ROOM_ROOT := "C:/Users/adohi/2dAnim/room-studio/out/the_sunken_keep"
const _ROOMS: Array[String] = ["gallery_of_the_warden", "cistern_of_the_tithe"]
## `tools/pull_room_lights.py` 가 적어 둔 사이드카. 매니페스트가 광원을 실으면 없어진다.
const _LIGHTS_DIR := "res://.renders-lighting/room"
const _SHOT_DIR := "res://.renders-lighting/room_lab"

## 이 방들은 1920×1080 으로 그려졌고 게임 뷰포트는 1280×720 이다.
const _AUTHORED_WIDTH := 1920.0
## 대원 빛의 반지름. §26.3.3 의 예산표가 정한 값이다 (국소 빛 ≤ 320px).
const _SQUAD_REACH := 320.0
const _FILTERS: Array[int] = [
	Light2D.SHADOW_FILTER_NONE, Light2D.SHADOW_FILTER_PCF5, Light2D.SHADOW_FILTER_PCF13
]
const _FILTER_NAMES: Array[String] = ["없음", "PCF5", "PCF13"]

var _room := 0
var _epsilon := 1.0
var _dark := false
var _lamp_on := false
var _squad_on := true
var _occluders_on := true
var _outlines_on := true
var _filter := 1
var _camera_x := 0.0
var _camera_max := 0.0

var _world: Node2D
var _plate: Sprite2D
var _occluder_root: Node2D
var _lamp: PointLight2D
var _squad: PointLight2D
var _dark_node: CanvasModulate
var _outline_layer: CanvasLayer
var _outline_node: Node2D
var _label: Label
var _note := ""

var _manifest := {}
var _lights := {}
var _cutouts: Dictionary = {}
var _polygons: Dictionary = {}
var _point_total := 0
var _shot := false


func _ready() -> void:
	_shot = OS.get_cmdline_user_args().has("shot")
	_build_nodes()
	_load_room(_ROOMS[_room])
	if _shot:
		_run_shots()


func _build_nodes() -> void:
	_dark_node = CanvasModulate.new()
	# 완전한 검정으로 누르지 않는다. 방 시각화가 구운 형태가 남아 있어야
	# **무엇이 구운 것이고 무엇이 실시간인지** 사람이 가를 수 있다.
	_dark_node.color = Color(0.30, 0.32, 0.42)
	_dark_node.visible = false
	add_child(_dark_node)

	_world = Node2D.new()
	add_child(_world)

	_plate = Sprite2D.new()
	_plate.centered = false
	_world.add_child(_plate)

	_occluder_root = Node2D.new()
	_world.add_child(_occluder_root)

	var falloff := _radial_texture()
	_lamp = PointLight2D.new()
	_lamp.texture = falloff
	_lamp.visible = false
	_world.add_child(_lamp)

	_squad = PointLight2D.new()
	_squad.texture = falloff
	_squad.color = Color(0.78, 0.86, 1.0)
	_squad.energy = 1.1
	_squad.shadow_enabled = true
	# 그림자가 잘리지 않게 넉넉히. 이 값이 작으면 먼 그림자가 뚝 끊긴다.
	_squad.texture_scale = _SQUAD_REACH * 2.0 / 256.0
	_world.add_child(_squad)

	# 외곽선은 **어둠에 눌리면 안 된다.** `CanvasModulate` 는 자기 캔버스 층만
	# 곱하므로 층을 따로 얹어 피한다.
	_outline_layer = CanvasLayer.new()
	add_child(_outline_layer)
	_outline_node = Node2D.new()
	_outline_node.draw.connect(_draw_outlines)
	_outline_layer.add_child(_outline_node)

	var hud := CanvasLayer.new()
	hud.layer = 2
	add_child(hud)
	_label = Label.new()
	_label.position = Vector2(12, 8)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 6)
	hud.add_child(_label)


func _load_room(room_id: String) -> void:
	var dir := "%s/%s" % [_ROOM_ROOT, room_id]
	_note = ""
	_manifest = _read_json("%s/%s.manifest.json" % [dir, room_id])
	_lights = _read_json("%s/%s.lights.json" % [_LIGHTS_DIR, room_id])
	if _manifest.is_empty():
		_note = "매니페스트를 못 읽었다: %s" % dir
		return
	if _lights.is_empty():
		_note = (
			"광원 사이드카가 없다. 먼저:\n"
			+ (
				"  python tools/pull_room_lights.py <room-studio> %s %s/%s.lights.json"
				% [dir, _LIGHTS_DIR, room_id]
			)
		)

	var plate := Image.load_from_file("%s/%s.panorama.jpg" % [dir, room_id])
	if plate == null:
		_note = "파노라마를 못 읽었다: %s" % dir
		return
	_plate.texture = ImageTexture.create_from_image(plate)

	var authored: Array = _manifest.get("screen", [_AUTHORED_WIDTH, 1080])
	var scale := get_viewport_rect().size.x / float(authored[0])
	_world.scale = Vector2(scale, scale)
	_camera_max = float(_manifest.get("camera_max", 0))
	_camera_x = 0.0

	_cutouts.clear()
	for entry in _manifest.get("props", []):
		var asset: String = entry.get("asset", "")
		var image := Image.load_from_file("%s/cutout/%s.png" % [dir, asset])
		if image != null:
			_cutouts[asset] = image
	_rebuild_occluders()
	_place_lamp()


## **폴리곤을 장면에서 그때그때 뽑는다.** 미리 구워 두지 않는 이유는 `epsilon` 을
## 손으로 돌려 가며 점 수와 그림자 모양을 **같이** 보기 위해서다. 실제 게임에서는
## 구워서 넣는다 (한 방에 0.4 초쯤 걸린다 — 웹 단일 스레드에서 그건 눈에 보이는 멈춤이다).
func _rebuild_occluders() -> void:
	for child in _occluder_root.get_children():
		child.queue_free()
	_polygons.clear()
	_point_total = 0
	var actor_h := float(_manifest.get("actor_h", 330))
	var depth_scale := float(_lights.get("depth_scale", 0.0))
	var emitting := _emitting_props()
	for entry in _manifest.get("props", []):
		var asset: String = entry.get("asset", "")
		if not _cutouts.has(asset):
			continue
		# **켜져 있는 소품에는 가림 폴리곤을 달지 않는다.** 빛이 폴리곤 **안**에 있으면
		# 그 빛은 자기 자신에게 통째로 막힌다 — 화면에서 램프 둘레만 밝고 나머지 벽이
		# 새까맣게 되는 것으로 나타난다 (`.renders-lighting/room_lab/c_*.png` 로 확인했다).
		# 방 시각화 레인의 사고 2 「램프가 자기 발밑 그림자를 지웠다」와 같은 자리다.
		if emitting.has(asset):
			continue
		var image: Image = _cutouts[asset]
		var box := _prop_box(entry, image, actor_h, depth_scale)
		var per_screen_px := float(image.get_height()) / maxf(1.0, box.size.y)
		var polygon := ProtoAlphaOccluder.build(image, 0.5, 256, _epsilon * per_screen_px)
		if polygon.size() < ProtoAlphaOccluder.MIN_POINTS:
			continue
		_point_total += polygon.size()

		var scaled := PackedVector2Array()
		var k := box.size.y / float(image.get_height())
		for p in polygon:
			scaled.append(box.position + p * k)
		_polygons[asset] = scaled

		var shape := OccluderPolygon2D.new()
		shape.polygon = scaled
		shape.closed = true
		# **컬링을 끈다.** 마칭 스퀘어의 감김 방향은 덩어리에 따라 뒤집힐 수 있고,
		# 컬링을 켜면 그때 그림자가 **조용히 사라진다.**
		shape.cull_mode = OccluderPolygon2D.CULL_DISABLED
		var node := LightOccluder2D.new()
		node.occluder = shape
		_occluder_root.add_child(node)


## 소품의 화면 상자. 방 시각화 `stage.prop_box` 와 같은 식이다 —
## `h = actor_h × height × (1 − depth_scale × (1 − v))`, 밑변이 접지선에 온다.
func _prop_box(entry: Dictionary, image: Image, actor_h: float, depth_scale: float) -> Rect2:
	var v := float(entry.get("v", 0.5))
	var h := actor_h * float(entry.get("height", 1.0)) * (1.0 - depth_scale * (1.0 - v))
	var w := float(image.get_width()) * h / float(image.get_height())
	var foot: Array = entry.get("screen_at_camera_0", [0, 0])
	return Rect2(Vector2(float(foot[0]) - w * 0.5, float(foot[1]) - h), Vector2(w, h))


## 켜져 있는(불을 가진) 소품의 이름. 광원 사이드카에서 나온다.
func _emitting_props() -> Dictionary:
	var out := {}
	for emitter in _lights.get("emitters", []):
		out[(emitter as Dictionary).get("prop", "")] = true
	return out


func _place_lamp() -> void:
	var emitters: Array = _lights.get("emitters", [])
	if emitters.is_empty():
		_lamp.visible = false
		return
	var first: Dictionary = emitters[0]
	var at: Array = first.get("screen", [0, 0])
	_lamp.position = Vector2(float(at[0]), float(at[1]))
	var rgb: Array = first.get("color", [255, 172, 84])
	_lamp.color = Color8(int(rgb[0]), int(rgb[1]), int(rgb[2]))
	_lamp.energy = float(first.get("strength", 1.0)) * 0.5
	_lamp.texture_scale = float(first.get("reach_px", 320.0)) * 2.4 / 256.0
	_lamp.shadow_enabled = true


func _process(_delta: float) -> void:
	var speed := 480.0 * _delta
	if Input.is_key_pressed(KEY_LEFT):
		_camera_x = maxf(0.0, _camera_x - speed)
	if Input.is_key_pressed(KEY_RIGHT):
		_camera_x = minf(_camera_max, _camera_x + speed)
	_world.position.x = -_camera_x * _world.scale.x

	# **화면 저장 중에는 마우스를 안 읽는다.** 처음엔 무조건 읽었고, 그 결과 저장된
	# 판에서 대원 빛이 화면 밖에 있었다 — 「대원 빛이 안 보인다」가 아니라
	# 「대원 빛을 화면 밖에 두고 찍었다」였다. 판정이 통째로 뒤집힐 뻔했다.
	if not _shot:
		var mouse := get_viewport().get_mouse_position()
		_squad.position = (mouse - _world.position) / _world.scale
	_squad.visible = _squad_on
	_lamp.visible = _lamp_on
	_dark_node.visible = _dark
	_occluder_root.visible = _occluders_on
	for node in _occluder_root.get_children():
		(node as LightOccluder2D).set_deferred("visible", _occluders_on)
	_lamp.shadow_filter = _FILTERS[_filter]
	_squad.shadow_filter = _FILTERS[_filter]
	_outline_node.visible = _outlines_on
	_outline_node.queue_redraw()
	_label.text = _status()


func _status() -> String:
	var lines := PackedStringArray()
	lines.append("%s  (Tab 으로 바꾼다)" % _ROOMS[_room])
	lines.append(
		"1 어둠 %s   2 램프 실시간빛 %s   3 대원 빛 %s" % [_mark(_dark), _mark(_lamp_on), _mark(_squad_on)]
	)
	lines.append(
		(
			"4 가림 %s   5 외곽선 %s   6 그림자필터 %s"
			% [_mark(_occluders_on), _mark(_outlines_on), _FILTER_NAMES[_filter]]
		)
	)
	lines.append(
		"[ ] epsilon %.1f 화면px  ->  점 %d 개 (소품 %d)" % [_epsilon, _point_total, _polygons.size()]
	)
	lines.append("fps %d" % Engine.get_frames_per_second())
	if _lamp_on and _occluders_on:
		lines.append("경고: 구운 그림자 위에 실시간 그림자가 겹친다. 램프 발밑을 봐라")
	if not _note.is_empty():
		lines.append(_note)
	return "\n".join(lines)


func _mark(on: bool) -> String:
	return "[켬]" if on else "[끔]"


func _draw_outlines() -> void:
	if not _outlines_on:
		return
	var offset := _world.position
	var scale := _world.scale
	for asset in _polygons:
		var points: PackedVector2Array = _polygons[asset]
		var screen := PackedVector2Array()
		for p in points:
			screen.append(offset + p * scale)
		screen.append(screen[0])
		_outline_node.draw_polyline(screen, Color(0.35, 1.0, 0.55, 0.9), 1.5)
	# 램프 자리를 십자로 찍는다. **이 자리가 사람이 적은 값이 아님을 화면에서 보이는 것**이
	# 이 표시의 목적이다 — 소품 그림에서 나온 값이다.
	if not _lights.get("emitters", []).is_empty():
		var at := offset + _lamp.position * scale
		_outline_node.draw_line(at - Vector2(10, 0), at + Vector2(10, 0), Color(1, 0.6, 0.2), 2.0)
		_outline_node.draw_line(at - Vector2(0, 10), at + Vector2(0, 10), Color(1, 0.6, 0.2), 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_1:
			_dark = not _dark
		KEY_2:
			_lamp_on = not _lamp_on
		KEY_3:
			_squad_on = not _squad_on
		KEY_4:
			_occluders_on = not _occluders_on
		KEY_5:
			_outlines_on = not _outlines_on
		KEY_6:
			_filter = (_filter + 1) % _FILTERS.size()
		KEY_BRACKETLEFT:
			_epsilon = maxf(0.25, _epsilon - 0.25)
			_rebuild_occluders()
		KEY_BRACKETRIGHT:
			_epsilon = minf(8.0, _epsilon + 0.25)
			_rebuild_occluders()
		KEY_TAB:
			_room = (_room + 1) % _ROOMS.size()
			_load_room(_ROOMS[_room])
		KEY_ESCAPE:
			get_tree().quit()


func _radial_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	return texture


func _read_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


## `-- shot` 일 때 판마다 화면을 저장한다. **후처리를 넣지 않는다** —
## 캡처가 화면과 다르면 그 순간부터 판정이 전부 헛일이다 (§26.3.2).
func _run_shots() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_SHOT_DIR))
	# **대원 빛을 소품 옆에 세워 둔다.** 빈 벽 앞에 두면 가림 폴리곤이 일하는지
	# 화면에 안 나타나고, 그 그림을 보고 「그림자가 안 진다」로 결론지을 뻔한다.
	var beside_prop := Vector2(300, 30)
	var plans := [
		# 이름, 어둠, 램프, 대원, 가림, 외곽선
		["a_baked", false, false, false, true, false],
		["b_dark_only", true, false, false, true, false],
		["c_lamp_occluders", true, true, false, true, false],
		["d_lamp_no_occluders", true, true, false, false, false],
		["e_squad_over_baked", false, false, true, true, false],
		["f_squad_dark_occluders", true, false, true, true, false],
		["g_squad_dark_no_occluders", true, false, true, false, false],
		["h_outlines", false, false, false, true, true],
	]
	for plan in plans:
		_dark = plan[1]
		_lamp_on = plan[2]
		_squad_on = plan[3]
		_occluders_on = plan[4]
		_outlines_on = plan[5]
		_squad.position = _anchor_prop() + beside_prop
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png("%s/%s.png" % [ProjectSettings.globalize_path(_SHOT_DIR), plan[0]])
		print("찍었다: %s" % plan[0])
	get_tree().quit()


## 화면 저장 때 대원 빛을 세울 기준 소품 — **가림 폴리곤이 있는 것 중 첫째**다.
func _anchor_prop() -> Vector2:
	for entry in _manifest.get("props", []):
		var asset: String = entry.get("asset", "")
		if _polygons.has(asset):
			var points: PackedVector2Array = _polygons[asset]
			var lowest := points[0]
			for p in points:
				if p.y > lowest.y:
					lowest = p
			return lowest
	return _lamp.position
