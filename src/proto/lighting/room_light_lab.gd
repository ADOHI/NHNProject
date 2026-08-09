extends Node2D
## **진짜 방 판 위에서 라이팅을 켰다 껐다 하는 실험대.** 사람이 직접 띄워 만지는 화면이다.
##
##     godot --path . res://src/proto/lighting/room_light_lab.tscn
##     godot --path . res://src/proto/lighting/room_light_lab.tscn -- shot     # 판마다 저장
##     godot --path . res://src/proto/lighting/room_light_lab.tscn -- ladder   # 어둠 단계
##     godot --path . res://src/proto/lighting/room_light_lab.tscn -- normal   # 판 노멀맵
##     godot --path . res://src/proto/lighting/room_light_lab.tscn -- height   # 빛의 높이
##
## **`-- shot` 에는 노멀 축이 없다.** 어둠과 노멀을 같이 켠 화면을 찾는다면
## `-- normal` 이다 — 그쪽이 어둠 0.55 · 대원 빛 켬으로 고정하고 노멀 넷을 돌린다.
## 문서에 `-- shot` 이라고 적혀 있던 적이 있고, 그래서 「그 화면은 아직 못 봤다」가
## 넉 달치 결론처럼 남아 있었다 (`26-2d-lighting.md` §26.4.11).
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
## | `1` | **어둠 여섯 단계를 돈다.** 색조는 방이 정하고 사람은 세기만 고른다 (§26.10) |
## | `2` | **램프 자리의 실시간 빛** — 이걸 켜는 것이 §26.2.1 이 금지한 그 선택이다 |
## | `3` | **대원 빛** (마우스를 따라온다) — 경계가 허락한 유일한 실시간 빛 |
## | `4` | 가림 폴리곤 on/off |
## | `5` | 폴리곤 외곽선 보기 |
## | `6` | 그림자 필터 순환 (없음 → PCF5 → PCF13) |
## | `7` | **판 노멀맵** 순환 (없음 → 휘도 → DSINE). §26.4.5 |
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
const _SHOT_DIR := "res://.renders-lighting/room_lab"

## 이 방들은 1920×1080 으로 그려졌고 게임 뷰포트는 1280×720 이다.
const _AUTHORED_WIDTH := 1920.0
## 대원 빛의 반지름. §26.3.3 의 예산표가 정한 값이다 (국소 빛 ≤ 320px).
const _SQUAD_REACH := 320.0
const _FILTERS: Array[int] = [
	Light2D.SHADOW_FILTER_NONE, Light2D.SHADOW_FILTER_PCF5, Light2D.SHADOW_FILTER_PCF13
]
const _FILTER_NAMES: Array[String] = ["없음", "PCF5", "PCF13"]

## **어둠의 단계.** 숫자는 방 자신의 채움광 색조에 곱하는 배수다 (§26.10 참고).
## 값 자체를 여기 적지 않는 것이 요점이다 — 색조는 매니페스트에서 읽는다.
const _DARK_STEPS: Array[float] = [1.0, 0.85, 0.70, 0.55, 0.42, 0.30]
const _DARK_NAMES: Array[String] = ["없음", "0.85", "0.70", "0.55", "0.42", "0.30"]

## 판에 씌울 노멀맵. `없음` → `휘도` → `DSINE` 순으로 돈다 (§26.4.5).
const _NORMAL_NAMES: Array[String] = ["없음", "휘도", "DSINE", "DSINE 바닥고침"]
## 모드별 파일 꼬리. 휘도는 파일이 아니라 엔진이 그 자리에서 만든다.
const _NORMAL_SUFFIX: Array[String] = ["", "", ".normal", ".normal_fixed"]
## `tools/make_plate_normal.py` 가 적어 둔 판 노멀. 판이 다시 그려지면 **같이 다시 만들어야 한다.**
const _NORMAL_DIR := "res://.renders-lighting/plate_normal"

var _room := 0
var _epsilon := 1.0
var _dark_step := 0
var _normal_mode := 0
var _plate_image: Image
var _normal_cache: Dictionary = {}
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
var _cutouts: Dictionary = {}
var _polygons: Dictionary = {}
var _point_total := 0
var _shot := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_shot = args.has("shot") or args.has("ladder") or args.has("normal") or args.has("height")
	_build_nodes()
	_load_room(_ROOMS[_room])
	if args.has("height"):
		_run_height()
	elif args.has("normal"):
		_run_normal()
	elif args.has("ladder"):
		_run_ladder()
	elif _shot:
		_run_shots()


func _build_nodes() -> void:
	_dark_node = CanvasModulate.new()
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
	# **노멀이 일하려면 빛이 면에서 떠 있어야 한다.** `height` 가 0 이면 빛 벡터가
	# 판과 같은 평면에 눕고, 화면을 보는 법선(`N ≈ [0,0,1]`)과의 `N·L` 이 0 이 된다 —
	# **노멀을 켜는 순간 소품이 통째로 어두워진다.** 이 장면은 이 줄이 없어서
	# 2026-08-09 16:25 의 `normal_*.png` 넷을 그 상태로 찍었고, 그 그림이
	# §26.4.5 의 "얻는 것이 작다" 판정의 근거였다 (`height0/` 에 남겨 뒀다).
	# **단위는 픽셀이다** (`0,1024,1,or_greater,suffix:px` — 엔진에 직접 물어봤다).
	# 같은 레인의 `normal_compare.gd`(0.30)·`lighting_bench.gd`(0.35) 는 이 값을
	# 0~1 로 착각하고 적은 것이라 **둘 다 사실상 0 이다.** 반지름의 절반쯤을 준다.
	_squad.height = _SQUAD_REACH * 0.5
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
	if _manifest.is_empty():
		_note = "매니페스트를 못 읽었다: %s" % dir
		return
	# **광원은 매니페스트에서 읽는다.** 한동안 `tools/pull_room_lights.py` 가 적은
	# 사이드카를 읽었는데, 그건 매니페스트가 `emitters`·`sun.strength`·`depth_scale`
	# 셋을 안 실을 때의 임시였다 (§26.8). `schema: room-studio/3` 이 셋을 전부
	# 실으면서 그 임시가 끝났다 — **사이드카를 계속 읽으면 그게 두 번째 진실이 된다.**
	if not _manifest.has("emitters"):
		_note = (
			"매니페스트에 emitters 가 없다 (schema=%s). room-studio/3 이상이 필요하다."
			% str(_manifest.get("schema", "?"))
		)

	var plate := Image.load_from_file("%s/%s.panorama.jpg" % [dir, room_id])
	if plate == null:
		_note = "파노라마를 못 읽었다: %s" % dir
		return
	_plate_image = plate
	_normal_cache.clear()
	_apply_normal()

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
	# **`depth_scale` 이 없으면 조용히 틀린다.** 기본값 0 으로 계산이 그냥 되고 소품이
	# 최대 24% 어긋난 크기로 놓인다 — 오류는 안 나고 그림자만 틀린다 (§26.8).
	var geometry: Dictionary = _manifest.get("geometry", {})
	var depth_scale := float(geometry.get("depth_scale", 0.0))
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


## 이 방에서 **켜져 있는 불.** 자리는 사람이 적은 값이 아니라 컷아웃에서 찾은
## 불꽃이고, 매니페스트가 `screen_at_camera_0` 으로 싣는다.
func _emitters() -> Array:
	return _manifest.get("emitters", [])


## 켜져 있는(불을 가진) 소품의 이름.
func _emitting_props() -> Dictionary:
	var out := {}
	for emitter in _emitters():
		out[(emitter as Dictionary).get("prop", "")] = true
	return out


## **판에 노멀맵을 씌운다.** `CanvasTexture` 로 감싸야 `PointLight2D` 가 법선을 읽는다 —
## `Sprite2D.texture` 에 그냥 `ImageTexture` 를 넣으면 노멀 슬롯 자체가 없다.
##
## 여기가 §26.4 가 못 본 자리다. 그쪽은 **벽 타일** 한 장을 재료로 봤는데, 실제로 대원
## 빛이 닿는 것은 **구워진 파노라마**다. 소품도 그림자도 램프 불빛도 이미 그 안에 있다.
func _apply_normal() -> void:
	if _plate_image == null:
		return
	var texture := CanvasTexture.new()
	texture.diffuse_texture = ImageTexture.create_from_image(_plate_image)
	if _normal_mode > 0:
		var key := _NORMAL_NAMES[_normal_mode]
		if not _normal_cache.has(key):
			_normal_cache[key] = _build_normal(_normal_mode)
		if _normal_cache[key] != null:
			texture.normal_texture = ImageTexture.create_from_image(_normal_cache[key])
	_plate.texture = texture


func _build_normal(mode: int) -> Image:
	if mode == 1:
		return ProtoNormalFromLuminance.build(_plate_image, 2.0)
	# DSINE 은 GPU 로 만들어 파일에 있다. 없으면 조용히 넘어가지 않고 화면에 적는다.
	var path := "%s/%s%s.png" % [_NORMAL_DIR, _ROOMS[_room], _NORMAL_SUFFIX[mode]]
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null:
		_note = "DSINE 노멀이 없다: %s\n  python tools/make_plate_normal.py <방 폴더>" % path
	return image


## **어둠의 색조는 방이 가지고 있다.** 매니페스트 `lights[0].color` 가 그 방의
## 채움광이고 (두 방 모두 `[146, 172, 200]`, 차가운 푸른빛이다), 어둠은 그 채움광이
## 약해진 것이지 다른 색이 아니다.
##
## **이렇게 하는 이유는 값을 못 정해서가 아니라, 정한 값이 근거를 갖게 하려는 것이다.**
## 앞 판에서 `(0.30, 0.32, 0.42)` 를 눈대중으로 적어 놓고 문서에 「근거 없는 값」이라고
## 스스로 적어 뒀었다. 색조를 방에서 읽으면 **방마다 자동으로 맞고, 방 시각화가 색을
## 바꾸면 따라온다.** 사람이 정할 것은 색이 아니라 **얼마나 누르는가** 하나로 준다.
func _dark_hue() -> Color:
	var rgb: Array = [146, 172, 200]
	var room_lights: Array = _manifest.get("lights", [])
	if not room_lights.is_empty():
		rgb = (room_lights[0] as Dictionary).get("color", rgb)
	var top := maxf(1.0, maxf(float(rgb[0]), maxf(float(rgb[1]), float(rgb[2]))))
	return Color(float(rgb[0]) / top, float(rgb[1]) / top, float(rgb[2]) / top)


func _apply_dark() -> void:
	if _dark_step <= 0:
		_dark_node.visible = false
		return
	_dark_node.visible = true
	_dark_node.color = _dark_hue() * _DARK_STEPS[_dark_step]


func _place_lamp() -> void:
	var emitters := _emitters()
	if emitters.is_empty():
		_lamp.visible = false
		return
	var first: Dictionary = emitters[0]
	var at: Array = first.get("screen_at_camera_0", [0, 0])
	_lamp.position = Vector2(float(at[0]), float(at[1]))
	var rgb: Array = first.get("color", [255, 172, 84])
	_lamp.color = Color8(int(rgb[0]), int(rgb[1]), int(rgb[2]))
	_lamp.energy = float(first.get("strength", 1.0)) * 0.5
	# 매니페스트의 `reach` 는 **화면 폭에 대한 비율**이다 (0.26 -> 499.2px @1920).
	# 픽셀로 적힌 값이 아니므로 여기서 환산한다 — 두 벌로 적지 않는다.
	var authored: Array = _manifest.get("screen", [_AUTHORED_WIDTH, 1080])
	var reach_px := float(first.get("reach", 0.17)) * float(authored[0])
	_lamp.texture_scale = reach_px * 2.4 / 256.0
	# 대원 빛과 같은 이유로 띄운다 (`_build_nodes` 의 주석). 이 빛은 §26.2.1 이 금지한
	# 선택을 **보여 주기 위해** 있는 것이라, 노멀이 안 먹으면 보여 주는 것도 틀린다.
	_lamp.height = 0.30
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
	_apply_dark()
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
		(
			"1 어둠 %s   2 램프 실시간빛 %s   3 대원 빛 %s"
			% [_DARK_NAMES[_dark_step], _mark(_lamp_on), _mark(_squad_on)]
		)
	)
	(
		lines
		. append(
			(
				"4 가림 %s   5 외곽선 %s   6 그림자필터 %s   7 노멀 %s"
				% [
					_mark(_occluders_on),
					_mark(_outlines_on),
					_FILTER_NAMES[_filter],
					_NORMAL_NAMES[_normal_mode],
				]
			)
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
	if not _emitters().is_empty():
		var at := offset + _lamp.position * scale
		_outline_node.draw_line(at - Vector2(10, 0), at + Vector2(10, 0), Color(1, 0.6, 0.2), 2.0)
		_outline_node.draw_line(at - Vector2(0, 10), at + Vector2(0, 10), Color(1, 0.6, 0.2), 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_1:
			_dark_step = (_dark_step + 1) % _DARK_STEPS.size()
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
		KEY_7:
			_normal_mode = (_normal_mode + 1) % _NORMAL_NAMES.size()
			_apply_normal()
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
		# 이름, 어둠 단계, 램프, 대원, 가림, 외곽선
		["a_baked", 0, false, false, true, false],
		["b_dark_only", 4, false, false, true, false],
		["c_lamp_occluders", 4, true, false, true, false],
		["d_lamp_no_occluders", 4, true, false, false, false],
		["e_squad_over_baked", 0, false, true, true, false],
		["f_squad_dark_occluders", 4, false, true, true, false],
		["g_squad_dark_no_occluders", 4, false, true, false, false],
		["h_outlines", 0, false, false, true, true],
	]
	for plan in plans:
		_dark_step = plan[1]
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


## **어둠 단계를 나란히 찍는다. 사람이 고르라고 만든 것이다.**
##
## 판마다 두 장을 찍는다 — 대원 빛이 **꺼진** 것과 **켜진** 것. 한 장만 찍으면
## 「방이 예쁜가」만 보이고 **「대원 빛이 일할 자리가 있는가」가 안 보인다.**
## 이 손잡이의 목적이 후자이므로 둘을 같이 봐야 고를 수 있다.
##
## 그림 옆에 숫자도 같이 낸다 — 램프 둘레와 먼 구석의 평균 밝기다.
## 방 시각화가 램프 자리 벽을 **164/255** 로 구웠으므로 (LIGHTING.md §2-A),
## 그 값이 단계마다 얼마로 눌리는지가 **저쪽과 맞추는 자**가 된다.
func _run_ladder() -> void:
	var out := ProjectSettings.globalize_path(_SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(out)
	_lamp_on = false
	_occluders_on = true
	_outlines_on = false
	_squad.position = _anchor_prop() + Vector2(300, 30)
	print("| 단계 | 배수 | 램프 둘레 | 먼 구석 | 대비 |")
	print("| --- | ---: | ---: | ---: | ---: |")
	for step in _DARK_STEPS.size():
		_dark_step = step
		for squad in [false, true]:
			_squad_on = squad
			await get_tree().process_frame
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			var tag := "squad" if squad else "plain"
			image.save_png("%s/dark_%d_%s_%s.png" % [out, step, _DARK_NAMES[step], tag])
			if not squad:
				var near := _mean_luma(image, _to_screen(_lamp.position), 90)
				var far := _mean_luma(image, Vector2(120, 300), 90)
				print(
					(
						"| %s | %.2f | **%.1f** | %.1f | %.2f |"
						% [
							_DARK_NAMES[step],
							_DARK_STEPS[step],
							near * 255.0,
							far * 255.0,
							near / maxf(0.001, far),
						]
					)
				)
	get_tree().quit()


## **판 노멀맵 세 가지를 대원 빛 아래에서 나란히 찍는다.**
##
## 판정 기준은 §26.4 와 같다 — **빛이 닿을 때 화면에서 차이가 보이는가.** 다만 재료가
## 다르다. §26.4 는 벽 타일이었고 여기는 **구워진 파노라마**다. 소품도 그림자도 램프
## 불빛도 이미 그 안에 들어 있다.
func _run_normal() -> void:
	var out := ProjectSettings.globalize_path(_SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(out)
	_lamp_on = false
	_squad_on = true
	_occluders_on = true
	_outlines_on = false
	_dark_step = 3
	# 소품 위에 빛을 세운다 — **노멀이 뜻이 있다면 소품에서 먼저 보인다.**
	_squad.position = _anchor_prop() + Vector2(60, -110)
	print("| 노멀 | 빛 안 밝기 표준편차 | 평균 |")
	print("| --- | ---: | ---: |")
	for mode in _NORMAL_NAMES.size():
		_normal_mode = mode
		_apply_normal()
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png("%s/normal_%d_%s.png" % [out, mode, _NORMAL_NAMES[mode]])
		var stats := _luma_stats(image, _to_screen(_squad.position), 150)
		print("| %s | **%.2f** | %.1f |" % [_NORMAL_NAMES[mode], stats.y * 255.0, stats.x * 255.0])
	get_tree().quit()


## **`Light2D.height` 를 훑는다.** 이 손잡이는 이 레인에서 세 번 잘못 적혔다 —
## `normal_compare.gd` 는 0.30, `lighting_bench.gd` 는 0.35 을 넣었는데 **단위가
## 픽셀이다** (엔진에 물어보면 `0,1024,1,or_greater,suffix:px` 라고 답한다).
## 즉 셋 다 사실상 0 이었고, **노멀맵을 켠 판정이 전부 「판에 누운 빛」 아래에서 났다.**
##
## 그래서 값을 찍어 두는 대신 훑는다. 노멀은 `DSINE 바닥고침` 하나로 고정하고
## height 만 바꾼다 — **한 판에 한 축만 바꾼다**(§26.3.2 의 규율).
func _run_height() -> void:
	var out := ProjectSettings.globalize_path(_SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(out)
	_lamp_on = false
	_squad_on = true
	_occluders_on = true
	_outlines_on = false
	_dark_step = 3
	_normal_mode = 3
	_apply_normal()
	_squad.position = _anchor_prop() + Vector2(60, -110)
	print("| height(px) | 빛 안 밝기 표준편차 | 평균 |")
	print("| --- | ---: | ---: |")
	for height in [0.0, 20.0, 60.0, 160.0, 320.0, 640.0, 1024.0]:
		_squad.height = height
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png("%s/height_%04d.png" % [out, int(height)])
		var stats := _luma_stats(image, _to_screen(_squad.position), 150)
		print("| %.0f | **%.2f** | %.1f |" % [height, stats.y * 255.0, stats.x * 255.0])
	get_tree().quit()


## 상자 안 휘도의 평균(x)과 표준편차(y). **표준편차가 노멀의 몫이다** —
## 노멀이 일하면 같은 빛 아래에서도 면마다 밝기가 갈리고, 안 하면 고르게 밝아진다.
func _luma_stats(image: Image, at: Vector2, half: int) -> Vector2:
	var values := PackedFloat32Array()
	var x0 := clampi(int(at.x) - half, 0, image.get_width() - 1)
	var x1 := clampi(int(at.x) + half, 0, image.get_width() - 1)
	var y0 := clampi(int(at.y) - half, 0, image.get_height() - 1)
	var y1 := clampi(int(at.y) + half, 0, image.get_height() - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var c := image.get_pixel(x, y)
			values.append(0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b)
	if values.is_empty():
		return Vector2.ZERO
	var mean := 0.0
	for v in values:
		mean += v
	mean /= float(values.size())
	var variance := 0.0
	for v in values:
		variance += (v - mean) * (v - mean)
	return Vector2(mean, sqrt(variance / float(values.size())))


func _to_screen(world: Vector2) -> Vector2:
	return _world.position + world * _world.scale


## 한 상자 안의 평균 휘도 (0~1). **눈으로 고르는 일에도 자를 하나 붙여 둔다** —
## 「어두워 보인다」와 「얼마나 어둡다」는 다른 말이고, 뒤엣것만 다음 사람에게 넘어간다.
func _mean_luma(image: Image, at: Vector2, half: int) -> float:
	var total := 0.0
	var count := 0
	var x0 := clampi(int(at.x) - half, 0, image.get_width() - 1)
	var x1 := clampi(int(at.x) + half, 0, image.get_width() - 1)
	var y0 := clampi(int(at.y) - half, 0, image.get_height() - 1)
	var y1 := clampi(int(at.y) + half, 0, image.get_height() - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var c := image.get_pixel(x, y)
			total += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			count += 1
	return total / float(maxi(1, count))


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
