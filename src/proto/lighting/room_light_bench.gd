extends Node2D
## **진짜 방 판 위에서 광원 개수를 올려 가며 재는 장면.** 웹에서 돌리려고 만든 것이다.
##
##     godot --path . res://src/proto/lighting/room_light_bench.tscn
##
## `lighting_bench.tscn` 과 무엇이 다른가 — **그쪽은 합성 판으로 쟀다.**
## 절차적으로 만든 돌 텍스처에 네모난 가림 물체를 늘어놓고 쟀고, 그래서 나온 값이
## 「빛 하나에 0.17ms」 같은 **기울기**였다. 이 장면은 **실제로 내보낼 구성**을 잰다 —
## 방 시각화의 파노라마 한 장, 그 방의 소품 여섯에서 알파로 뽑은 가림 폴리곤,
## 대원 크기(반지름 320px)의 빛. **그래서 이 숫자는 기울기가 아니라 답이다.**
##
## # 재는 규칙 — 앞 레인들이 값비싸게 배운 것을 그대로 쓴다
##
## - **95 분위로 판정한다.** 중앙값이 아니다. 이 저장소 실측에서 웹의 배수가 부하와
##   백분위에 따라 1.00 → 1.38 → 2.21 → 3.76 으로 올랐다. **웹은 느린 게 아니라
##   꼬리가 나쁘다** (`src/proto/unit_move/README.md` §21)
## - **빛을 매 프레임 움직인다.** 정지 화면으로는 최악이 안 나온다 — 그림자 갱신이
##   안 걸린다 (§26.3.2)
## - **판마다 다시 데운다.** 웹은 데워지기 전 몇 프레임이 통째로 다르다
## - **한 판에 한 축만 바꾼다.** 그래야 빛과 가림의 값이 갈린다
##
## # 웹에서 결과를 어떻게 받나
##
## 웹 빌드는 `-s` 로 스크립트를 못 돌리고, 이 판에서는 결과를 되돌려 보낼 서버도
## 없다 (정적 서버 하나만 떠 있다). 그래서 **결과를 화면에 크게 쓴다.**
## 브라우저 화면을 그대로 읽으면 그것이 측정 기록이다.

const _FRAMES := 240
## 웹은 데워지기 전 몇 프레임이 통째로 다르다. 판마다 다시 데운다.
const _WARMUP := 90
## 대원 빛의 반지름. §26.3.3 의 예산표가 정한 국소 빛 상한이다.
const _REACH := 320.0
## 폴리곤을 줄이는 자. §26.6.2 의 권고값(화면 2px)으로 잰다 — **내보낼 값으로 잰다.**
const _EPSILON := 2.0
const _ROOM := "res://src/proto/lighting/room_web"

## 판: [이름, 빛 개수, 가림 켬]
const _PLAN: Array = [
	["0. 판만 (조명 없음)", 0, false],
	["1. 빛 1 + 가림", 1, true],
	["2. 빛 2 + 가림", 2, true],
	["3. 빛 4 + 가림", 4, true],
	["4. 빛 8 + 가림", 8, true],
	["5. 빛 16 + 가림", 16, true],
	["6. 빛 16, 가림 끔", 16, false],
	["7. 빛 4, 가림 끔", 4, false],
]

var _stats := ProtoLightBenchStats.new()
var _lights: Array[PointLight2D] = []
var _occluders: Array[LightOccluder2D] = []
var _world: Node2D
var _label: Label
var _dark: CanvasModulate
var _index := -1
var _warmup := 0
var _time := 0.0
var _rows := PackedStringArray()
var _point_total := 0
var _done := false


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	var hud := CanvasLayer.new()
	hud.layer = 2
	add_child(hud)
	_label = Label.new()
	_label.position = Vector2(10, 8)
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 6)
	hud.add_child(_label)

	_dark = CanvasModulate.new()
	add_child(_dark)
	_world = Node2D.new()
	add_child(_world)
	_build_room()
	_next_stage()


func _build_room() -> void:
	var manifest := _read_json("%s/manifest.json" % _ROOM)
	var lights := _read_json("%s/lights.json" % _ROOM)

	var plate := Sprite2D.new()
	plate.centered = false
	plate.texture = load("%s/plate.jpg" % _ROOM)
	_world.add_child(plate)

	var authored: Array = manifest.get("screen", [1920, 1080])
	var scale := get_viewport_rect().size.x / float(authored[0])
	_world.scale = Vector2(scale, scale)

	# 어둠의 색조는 방이 정한다 (§26.10). 세기는 실측이 끝난 뒤 사람이 고른다.
	var rgb: Array = [146, 172, 200]
	var fill: Array = manifest.get("lights", [])
	if not fill.is_empty():
		rgb = (fill[0] as Dictionary).get("color", rgb)
	var top := maxf(1.0, maxf(float(rgb[0]), maxf(float(rgb[1]), float(rgb[2]))))
	_dark.color = Color(float(rgb[0]) / top, float(rgb[1]) / top, float(rgb[2]) / top) * 0.55

	var emitting := {}
	for emitter in lights.get("emitters", []):
		emitting[(emitter as Dictionary).get("prop", "")] = true
	var actor_h := float(manifest.get("actor_h", 330))
	var depth_scale := float(lights.get("depth_scale", 0.0))
	for entry in manifest.get("props", []):
		var asset: String = entry.get("asset", "")
		if emitting.has(asset):
			continue
		var texture: Texture2D = load("%s/%s.png" % [_ROOM, asset])
		if texture == null:
			continue
		var image := texture.get_image()
		var v := float(entry.get("v", 0.5))
		var h := actor_h * float(entry.get("height", 1.0)) * (1.0 - depth_scale * (1.0 - v))
		var w := float(image.get_width()) * h / float(image.get_height())
		var foot: Array = entry.get("screen_at_camera_0", [0, 0])
		var origin := Vector2(float(foot[0]) - w * 0.5, float(foot[1]) - h)
		var per_screen_px := float(image.get_height()) / maxf(1.0, h)
		var polygon := ProtoAlphaOccluder.build(image, 0.5, 256, _EPSILON * per_screen_px)
		if polygon.size() < ProtoAlphaOccluder.MIN_POINTS:
			continue
		_point_total += polygon.size()
		var k := h / float(image.get_height())
		var scaled := PackedVector2Array()
		for p in polygon:
			scaled.append(origin + p * k)
		var shape := OccluderPolygon2D.new()
		shape.polygon = scaled
		shape.closed = true
		shape.cull_mode = OccluderPolygon2D.CULL_DISABLED
		var node := LightOccluder2D.new()
		node.occluder = shape
		_world.add_child(node)
		_occluders.append(node)

	var falloff := _radial_texture()
	for i in 16:
		var light := PointLight2D.new()
		light.texture = falloff
		light.color = Color(0.78, 0.86, 1.0)
		light.energy = 1.0
		light.shadow_enabled = true
		# PCF5 가 기본이다. PCF13 은 픽셀당 2.6 배인데 눈에 남는 값이 그만큼은 아니다
		light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		light.texture_scale = _REACH * 2.0 / 256.0
		light.visible = false
		_world.add_child(light)
		_lights.append(light)


func _process(delta: float) -> void:
	if _done:
		return
	_time += delta
	# **빛을 계속 움직인다.** 멈춰 있으면 그림자를 다시 안 그리고, 그러면 최악이 안 나온다.
	for i in _lights.size():
		if not _lights[i].visible:
			continue
		var phase := _time * 0.7 + float(i) * TAU / 16.0
		_lights[i].position = Vector2(1000.0 + cos(phase) * 420.0, 820.0 + sin(phase) * 120.0)

	if _warmup > 0:
		_warmup -= 1
		return
	_stats.add(delta * 1000.0, _render_ms())
	if _stats.count() >= _FRAMES:
		_finish_stage()
	_label.text = _text()


## 뷰포트 렌더 시간. **브라우저는 GPU 타이머를 안 주므로 0 이 나온다** —
## 0 을 「우리 탓 아님」으로 읽으면 안 된다 (`ProtoLightBenchStats` 의 같은 주의).
func _render_ms() -> float:
	return RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid())


func _finish_stage() -> void:
	var plan: Array = _PLAN[_index]
	(
		_rows
		. append(
			(
				"%-20s  중앙 %5.2f   **95분위 %5.2f**   99 %5.2f   넘침 %d/%d"
				% [
					plan[0],
					_stats.frame_at(0.5),
					_stats.frame_at(0.95),
					_stats.frame_at(0.99),
					_stats.over_budget(),
					_stats.count(),
				]
			)
		)
	)
	_report(_rows[_rows.size() - 1])
	_next_stage()


## **콘솔로는 못 받는다.** 브라우저 창이 화면에 안 보이면 `requestAnimationFrame` 이
## 멈춰서 **측정이 한 줄도 진행되지 않고**, 창을 띄우면 이번에는 그 창의 콘솔을 밖에서
## 붙잡을 수단이 없다. 이 판에서 실제로 그 순서로 두 번 막혔다.
##
## 그래서 앞 레인이 만든 길을 그대로 쓴다 — **한 줄이 끝날 때마다 서버로 되돌려 보낸다.**
## 서버의 기록이 곧 측정 기록이다 (`tools/serve_web_bench.py`).
func _report(line: String) -> void:
	print(line)
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(
		"fetch('/bench?line=' + encodeURIComponent(%s))" % JSON.stringify(line), true
	)


func _next_stage() -> void:
	_index += 1
	if _index >= _PLAN.size():
		_done = true
		_label.text = _text()
		_report("== 끝 ==")
		return
	var plan: Array = _PLAN[_index]
	var count: int = plan[1]
	var occluders_on: bool = plan[2]
	for i in _lights.size():
		_lights[i].visible = i < count
	for node in _occluders:
		node.visible = occluders_on
	_dark.visible = count > 0
	_stats.reset()
	_warmup = _WARMUP


func _text() -> String:
	var out := PackedStringArray()
	out.append(
		(
			"방 라이팅 웹 실측 — 소품 6 • 폴리곤 %d점 (eps %.1f 화면px) • 빛 반지름 %d • PCF5"
			% [_point_total, _EPSILON, int(_REACH)]
		)
	)
	out.append("예산 16.7ms • 판마다 %d 프레임 (데우기 %d)" % [_FRAMES, _WARMUP])
	out.append("")
	for row in _rows:
		out.append(row)
	if not _done:
		var plan: Array = _PLAN[_index]
		out.append("... %s  (%d/%d)" % [plan[0], _stats.count(), _FRAMES])
	else:
		out.append("")
		out.append("== 끝났다 ==")
	return "\n".join(out)


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
		var resource := load(path)
		if resource is JSON:
			var data = (resource as JSON).data
			return data if data is Dictionary else {}
		return {}
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}
