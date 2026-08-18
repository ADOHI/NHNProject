extends Node2D
## **2D 라이팅이 웹에서 얼마인지 재는 장면.** 두 번째 관문이다
## (`docs/design/26-2d-lighting.md` §3).
##
## 내보낸 웹 빌드는 `run/main_scene` 하나만 띄우고 `-s` 로 스크립트를 못 돌린다.
## 그래서 **장면**으로 만들었다 — 이동 레인이 `tools/web_frame_bench.tscn` 에서
## 쓴 절차 그대로다 (`src/proto/unit_move/README.md` §22).
##
## **네이티브에서도 같은 장면을 돌려야 배수가 뜻을 가진다.** 같은 코드로 두 곳을 재야
## 렌더 경로와 스레드 차이만 남는다.
##
## 라이팅은 픽셀마다 도는 일이라 **우리 계산(GDScript)이 아니라 렌더 시간**이 늘어난다.
## 이동 레인의 「우리 탓」 구분을 그대로 쓸 수 없으므로 뷰포트 렌더 시간을 따로 잰다.

const _FRAMES := 240
## 웹은 데워지기 전 몇 프레임이 통째로 다르다. 판마다 다시 데운다.
const _WARMUP := 90
const _BUDGET := 16.7
const _TEX_SIZE := 192
## 한 물건에 닿을 수 있는 빛의 상한 (`drivers/gles3/rasterizer_canvas_gles3.h`)
const _MAX_LIGHTS_PER_ITEM := 16

var _stats := ProtoLightBenchStats.new()
var _lights: Array[PointLight2D] = []
var _props: Array[Sprite2D] = []
var _layers: Array[Sprite2D] = []
var _label: Label
var _lit_texture: CanvasTexture
var _flat_texture: ImageTexture
var _index := -1
var _warmup := 0
var _time := 0.0
var _lines := PackedStringArray()
var _viewport_rid: RID
## `-- shot` 을 주면 판마다 화면을 그대로 저장한다.
##
## **캡처 경로에 후처리를 넣지 않는다.** 방 시각화 레인은 검사 도구가 구워 넣은
## 비네트를 「파노라마 이음선」으로 착각해 없는 결함을 쫓았다
## (`room-studio/docs/REVIEW-LOG.md`). 라이팅은 눈으로 판정하는 일이라
## **캡처가 화면과 다르면 그 순간부터 전부 헛일이다.**
var _shot := false


func _ready() -> void:
	# **수직 동기를 끈다.** 켜 두면 네이티브 프레임 시간이 화면 주기에 못 박혀
	# (이 기계에서 4.17 밀리초 = 240Hz) 비용이 늘어도 숫자가 안 움직인다.
	# 웹은 브라우저가 rAF 로 60 에 묶으므로 애초에 이 설정이 안 먹는다 —
	# 그래서 **네이티브는 렌더 시간으로, 웹은 넘친 프레임 수로** 판정한다.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_shot = OS.get_cmdline_user_args().has("shot")

	var diffuse := _make_stone(_TEX_SIZE)
	var normal := ProtoNormalFromLuminance.build(diffuse, 6.0)
	_flat_texture = ImageTexture.create_from_image(diffuse)
	_lit_texture = CanvasTexture.new()
	_lit_texture.diffuse_texture = _flat_texture
	_lit_texture.normal_texture = ImageTexture.create_from_image(normal)
	_lit_texture.specular_shininess = 0.4

	# 노멀맵이 정말 방향을 담고 있는지 먼저 찍는다. 0 이면 평평한 것이고,
	# 그 상태로 "노멀을 켰다" 고 재면 **아무것도 확인하지 않는 검사**가 된다.
	_emit("노멀맵 기울기 RMS = %.4f (0 이면 평평하다)" % ProtoNormalFromLuminance.tilt_rms(normal))

	var modulate_node := CanvasModulate.new()
	modulate_node.color = Color(0.30, 0.32, 0.38)
	add_child(modulate_node)

	_build_layers()
	_build_props()
	_build_lights()

	var layer := CanvasLayer.new()
	layer.layer = 100
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.add_theme_font_size_override("font_size", 14)
	layer.add_child(_label)
	add_child(layer)

	_viewport_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_viewport_rid, true)

	_emit("| 판 | 프레임 중앙 | 95 | 99 | 최악 | 렌더CPU 중앙 | 95 | 렌더GPU 95 | 넘침 |")
	_next()


func _process(delta: float) -> void:
	_time += delta
	# 빛을 움직인다. 라이팅은 **빛이 움직일 때** 일하고, 정지 화면으로는 비용도
	# 최악이 안 나온다 (그림자 갱신이 안 걸린다).
	for i in _lights.size():
		var light := _lights[i]
		var phase := _time * 0.7 + float(i) * TAU / float(maxi(1, _lights.size()))
		light.position = Vector2(640.0 + cos(phase) * 460.0, 380.0 + sin(phase * 0.8) * 190.0)

	if _index >= ProtoLightBenchPlan.STAGES.size():
		return
	if _warmup > 0:
		_warmup -= 1
		return

	_stats.add(delta * 1000.0, RenderingServer.viewport_get_measured_render_time_cpu(_viewport_rid))
	if _stats.count() >= _FRAMES:
		_record()
		_save_shot()
		_next()
	else:
		_show()


func _next() -> void:
	_index += 1
	_show()
	if _index >= ProtoLightBenchPlan.STAGES.size():
		_emit("측정 끝")
		return
	var stage: Dictionary = ProtoLightBenchPlan.STAGES[_index]
	_apply(stage)
	_stats.reset()
	_warmup = _WARMUP


func _apply(stage: Dictionary) -> void:
	var wanted: int = stage["lights"]
	var radius: float = stage["radius"]
	var shadow: int = stage["shadow"]
	var occluders: int = ProtoLightBenchPlan.value(stage, "occluders")
	var layers: int = ProtoLightBenchPlan.value(stage, "layers")
	for i in _lights.size():
		var light := _lights[i]
		light.visible = i < wanted
		light.texture_scale = radius / 256.0
		light.shadow_enabled = shadow >= 0
		if shadow >= 0:
			light.shadow_filter = shadow as Light2D.ShadowFilter
	for i in _props.size():
		_props[i].visible = i < occluders
	var texture: Texture2D = _lit_texture if stage["normal"] else _flat_texture
	for i in _layers.size():
		_layers[i].visible = i < layers
		_layers[i].texture = texture


## 판이 끝나는 대로 즉시 낸다. 마지막에 몰아서 내면 웹에서 마지막 판이 안 끝날 때
## 앞의 결과도 못 본다 — 이동 레인이 실제로 그렇게 막혔다 (§22).
func _record() -> void:
	var stage: Dictionary = ProtoLightBenchPlan.STAGES[_index]
	_emit(
		(
			"| %s | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %d / %d |"
			% [
				stage["name"],
				_stats.frame_at(0.50),
				_stats.frame_at(0.95),
				_stats.frame_at(0.99),
				_stats.frame_at(1.0),
				_stats.render_at(0.50),
				_stats.render_at(0.95),
				RenderingServer.viewport_get_measured_render_time_gpu(_viewport_rid),
				_stats.over_budget(),
				_stats.count(),
			]
		)
	)


## 판이 끝난 화면을 그대로 저장한다. 손대지 않는다 — 보정을 걸면 「검사 도구가
## 만든 결함」을 쫓게 된다. 글자 표시는 남겨 둔다: 어느 판인지 그림에 적혀 있어야
## 나중에 그림만 보고도 무엇인지 안다.
func _save_shot() -> void:
	if not _shot:
		return
	var image := get_viewport().get_texture().get_image()
	var path := "res://.renders-lighting/stage_%d.png" % _index
	DirAccess.make_dir_recursive_absolute("res://.renders-lighting")
	var err := image.save_png(path)
	_emit("캡처: %s (err=%d)" % [path, err])


func _emit(line: String) -> void:
	_lines.append(line)
	print(line)
	_report(line)


## **웹에서는 콘솔을 밖에서 읽을 수 없는 경우가 있다.** 브라우저 창이 안 보이면
## `requestAnimationFrame` 이 멈춰 측정 자체가 진행되지 않고, 창을 띄우면 이번에는
## 콘솔을 붙잡을 도구가 없었다. 그래서 **한 줄이 끝날 때마다 서버로 되돌려 보낸다** —
## 서버의 접근 기록이 곧 측정 기록이 된다 (`tools/serve_web_bench.py`).
func _report(line: String) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(
		"fetch('/bench?line=' + encodeURIComponent(%s))" % JSON.stringify(line), true
	)


func _show() -> void:
	var head := "2D 라이팅 비용 측정 (예산 %.1f ms)\n" % _BUDGET
	if _index < ProtoLightBenchPlan.STAGES.size():
		var stage: Dictionary = ProtoLightBenchPlan.STAGES[_index]
		head += ("지금: %s  (%d / %d, 데우기 %d)\n" % [stage["name"], _stats.count(), _FRAMES, _warmup])
	else:
		head += "끝났다\n"
	for line in _lines:
		head += line + "\n"
	_label.text = head


## 빛을 받는 바탕 겹. 방 그림이 벽·바닥·소품으로 갈리면 겹이 늘고, **한 화소가
## 여러 번 그려지면 빛도 여러 번 돈다** (overdraw). 겹은 자리를 조금씩 물려 둔다.
func _build_layers() -> void:
	for i in ProtoLightBenchPlan.LAYER_POOL:
		var layer := Sprite2D.new()
		layer.texture = _flat_texture
		layer.centered = false
		layer.scale = Vector2(1280.0 / float(_TEX_SIZE), 720.0 / float(_TEX_SIZE))
		layer.position = Vector2(float(i) * 2.0, float(i) * 2.0)
		if i > 0:
			layer.modulate = Color(1.0, 1.0, 1.0, 0.5)
		layer.visible = i == 0
		add_child(layer)
		_layers.append(layer)


func _build_props() -> void:
	var blob := _make_blob(128)
	var texture := ImageTexture.create_from_image(blob)
	var polygon := PackedVector2Array()
	for i in 8:
		var a := float(i) / 8.0 * TAU
		polygon.append(Vector2(cos(a), sin(a)) * 52.0)
	var occluder_polygon := OccluderPolygon2D.new()
	occluder_polygon.polygon = polygon
	var columns := 8
	for i in ProtoLightBenchPlan.OCCLUDER_POOL:
		var prop := Sprite2D.new()
		prop.texture = texture
		prop.scale = Vector2(0.7, 0.7)
		prop.position = Vector2(
			90.0 + float(i % columns) * 150.0, 110.0 + float(i / columns) * 88.0
		)
		prop.visible = false
		add_child(prop)
		var occluder := LightOccluder2D.new()
		occluder.occluder = occluder_polygon
		prop.add_child(occluder)
		_props.append(prop)


func _build_lights() -> void:
	var texture := ImageTexture.create_from_image(_make_falloff(256))
	for _i in _MAX_LIGHTS_PER_ITEM:
		var light := PointLight2D.new()
		light.texture = texture
		light.energy = 1.1
		# 노멀맵이 일하려면 빛이 면에서 떠 있어야 한다. 0 이면 노멀을 켜도 거의 안 보인다
		# (Godot 문서: "increase the Height property").
		# **단위는 픽셀이다** (`0,1024,1,or_greater,suffix:px`). 여기 적혀 있던 `0.35` 는
		# 0~1 로 착각한 값이라 사실상 0 이었다 — **비용 표(§26.3.2)는 그대로 유효하다**
		# (height 는 채우는 화소 수를 안 바꾼다). 그림 판정만 영향을 받는다.
		light.height = 128.0
		light.visible = false
		add_child(light)
		_lights.append(light)


## 돌벽 비슷한 무늬. **내용은 비용에 거의 영향이 없다** — 라이팅은 화면 화소마다
## 도는 일이고 텍스처 내용이 아니라 덮는 면적이 값을 정한다. 그래도 노멀맵이
## 기울기를 가지려면 무늬가 있어야 한다.
func _make_stone(size: int) -> Image:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.045
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var v := 0.5 + 0.5 * noise.get_noise_2d(float(x), float(y))
			# 가로 줄눈. 벽의 켜를 흉내 낸다
			if y % 32 < 2:
				v *= 0.55
			image.set_pixel(x, y, Color(v * 0.72, v * 0.74, v * 0.70))
	return image


func _make_blob(size: int) -> Image:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var half := float(size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(float(x) - half, float(y) - half).length() / half
			var a := 1.0 if d < 0.82 else 0.0
			image.set_pixel(x, y, Color(0.42, 0.38, 0.34, a))
	return image


func _make_falloff(size: int) -> Image:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var half := float(size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(float(x) - half, float(y) - half).length() / half
			# 역제곱 낙하. 방 시각화 레인이 쓰는 식과 같은 모양이다
			# (`room-studio/docs/LIGHTING.md` §1-c): k(d) = 1 / (1 + (d/r)^2)
			var k := 1.0 / (1.0 + pow(d * 2.4, 2.0))
			if d > 1.0:
				k = 0.0
			image.set_pixel(x, y, Color(1.0, 0.72, 0.38, k))
	return image
