extends Node2D
## **노멀맵을 만드는 네 방식을 같은 빛 아래 나란히 놓는다.**
##
## 판정 기준은 하나다 — **빛이 움직일 때 화면에서 차이가 보이는가.**
## 안 보이면 비싼 쪽을 안 쓰는 것이 맞다 (90 시간 잼이다).
##
## 네 판은 **각자 자기 빛만 받는다.** `light_mask` 로 갈라 두지 않으면 옆 판의 빛이
## 새어 들어와 「같은 조건」이 깨진다. 빛은 네 개가 **자기 판의 같은 자리**를 같은
## 속도로 돈다 — 그래야 같은 순간의 네 그림이 비교 가능하다.
##
##     godot --path . res://src/proto/lighting/normal_compare.tscn
##     godot --path . res://src/proto/lighting/normal_compare.tscn -- shot
##
## | 키 | 하는 일 |
## | --- | --- |
## | 1~4 | 그 판만 크게 보기 · 되돌리기 |
## | N | 노멀 끄기 · 켜기 (**전부 같은 그림이 되는지 확인용**) |
## | Space | 빛 멈추기 · 돌리기 |
## | ←→ | 빛을 손으로 돌리기 (멈춘 상태에서) |

const _DIR := "res://.renders-lighting/src/"
const _PANEL := 260.0
## **빛은 판 안에서 돈다.** 판 밖에서 돌면 빛이 판에 닿지 않아 네 판이 다 같은
## 어둠이 되고, 그 그림을 보고 "차이가 없다" 고 결론지을 뻔했다.
const _ORBIT := 95.0

## 판마다: 이름 · 노멀맵 파일 · 한 줄 설명
const _PANELS: Array[Dictionary] = [
	{"name": "노멀 없음", "file": "", "note": "대조군"},
	{"name": "휘도 기울기 2.0", "file": "wall_luma_2.0.png", "note": "RMS 0.457"},
	{"name": "AI BAE x4", "file": "wall_bae_x4.png", "note": "RMS 0.144 -> 0.386"},
	{"name": "BAE x4 + 휘도 0.8", "file": "wall_hybrid.png", "note": "큰 형태 + 잔결"},
]

var _sprites: Array[Sprite2D] = []
var _lights: Array[PointLight2D] = []
var _lit: Array[CanvasTexture] = []
var _flat: ImageTexture
var _label: Label
var _angle := 0.0
var _spin := true
var _normals := true
var _focus := -1
var _shot := false
var _shot_taken := 0
var _shot_frames := 0
var _solo := false
var _clock := 0.0


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_shot = OS.get_cmdline_user_args().has("shot")
	# **판을 작게 늘어놓고 판정하면 안 된다.** 게임에서 벽은 화면을 채우고, 축소하면
	# 휘도 근사가 만드는 잔결이 평균되어 사라진다. `solo` 는 판마다 원본 크기(1:1)로
	# 한 장씩 찍는다 - 그것이 실제로 사람이 보게 될 크기다.
	_solo = OS.get_cmdline_user_args().has("solo")

	var diffuse := Image.load_from_file(_DIR + "wall_crop.png")
	if diffuse == null:
		push_error("바탕 그림이 없다: %swall_crop.png" % _DIR)
		return
	_flat = ImageTexture.create_from_image(diffuse)

	var modulate_node := CanvasModulate.new()
	modulate_node.color = Color(0.22, 0.23, 0.28)
	add_child(modulate_node)

	var falloff := ImageTexture.create_from_image(_make_falloff(256))
	for i in _PANELS.size():
		var panel: Dictionary = _PANELS[i]
		var texture: Texture2D = _flat
		if panel["file"] != "":
			var normal := Image.load_from_file(_DIR + panel["file"])
			if normal == null:
				push_warning("노멀맵이 없다: %s" % panel["file"])
			else:
				var canvas := CanvasTexture.new()
				canvas.diffuse_texture = _flat
				canvas.normal_texture = ImageTexture.create_from_image(normal)
				texture = canvas
		_lit.append(texture as CanvasTexture)

		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = true
		sprite.scale = Vector2.ONE * (_PANEL / float(diffuse.get_width()))
		sprite.position = _home(i)
		# **자기 빛만 받는다.** 이것이 없으면 옆 판의 빛이 새어 비교가 깨진다.
		sprite.light_mask = 1 << i
		add_child(sprite)
		_sprites.append(sprite)

		var light := PointLight2D.new()
		light.texture = falloff
		light.texture_scale = 1.5
		light.energy = 2.2
		# 노멀이 일하려면 빛이 면에서 떠 있어야 한다 (Godot 문서의 Height).
		# **단위는 픽셀이다.** 엔진에 직접 물어보면 `0,1024,1,or_greater,suffix:px` 라고
		# 답한다 — 여기 오래 적혀 있던 `0.30` 은 0~1 로 착각한 값이라 **사실상 0** 이었고,
		# 그 상태에서는 빛이 판에 누워 화면을 보는 법선(`N ≈ [0,0,1]`)의 `N·L` 이 0 이 된다.
		# §26.4 의 그림 판정이 전부 그 아래에서 났다 (`26-2d-lighting.md` §26.4.12).
		light.height = 128.0
		light.range_item_cull_mask = 1 << i
		add_child(light)
		_lights.append(light)

	var layer := CanvasLayer.new()
	layer.layer = 100
	_label = Label.new()
	_label.position = Vector2(14, 12)
	_label.add_theme_font_size_override("font_size", 15)
	layer.add_child(_label)
	add_child(layer)


func _process(delta: float) -> void:
	_clock += delta
	if _spin:
		_angle += delta * 1.1
	for i in _lights.size():
		_lights[i].position = _home(i) + Vector2(cos(_angle), sin(_angle) * 0.6) * _ORBIT
	_show()
	if _shot:
		_take_shots()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := (event as InputEventKey).keycode
	match key:
		KEY_SPACE:
			_spin = not _spin
		KEY_N:
			_normals = not _normals
			for i in _sprites.size():
				_sprites[i].texture = _lit[i] if _normals else _flat
		KEY_LEFT:
			_angle -= 0.12
		KEY_RIGHT:
			_angle += 0.12
		KEY_1, KEY_2, KEY_3, KEY_4:
			var wanted := key - KEY_1
			_focus = -1 if _focus == wanted else wanted
			_relayout()


## 판 자리. 하나만 볼 때는 화면 가운데로 키운다.
func _home(index: int) -> Vector2:
	if _focus == index:
		return Vector2(640, 380)
	return Vector2(190.0 + float(index) * 300.0, 400.0)


func _relayout() -> void:
	for i in _sprites.size():
		_sprites[i].visible = _focus < 0 or _focus == i
		_sprites[i].position = _home(i)
		_sprites[i].scale = Vector2.ONE * ((512.0 if _focus == i else _PANEL) / 512.0)


func _show() -> void:
	var text := "노멀맵 비교 - 같은 벽, 같은 빛. 빛 각도 %.0f도\n" % rad_to_deg(fmod(_angle, TAU))
	text += (
		"노멀 %s / 빛 %s   [N] 노멀  [Space] 멈춤  [1~4] 하나만  [좌우키] 손으로\n\n"
		% ["켬" if _normals else "끔", "돎" if _spin else "멈춤"]
	)
	for i in _PANELS.size():
		var panel: Dictionary = _PANELS[i]
		text += "%d. %s - %s\n" % [i + 1, panel["name"], panel["note"]]
	_label.text = text


## 빛을 네 방향에 세워 놓고 찍는다. **한 각도만 찍으면 노멀의 값을 못 본다** —
## 노멀은 빛이 옮겨 다닐 때 일하는 것이라 각도가 여럿이어야 증거가 된다.
func _take_shots() -> void:
	var wanted := [0.0, PI * 0.5, PI, PI * 1.5]
	var total: int = _PANELS.size() if _solo else wanted.size()
	if _shot_taken >= total:
		get_tree().quit()
		return
	# **각도를 세운 프레임과 찍는 프레임을 가른다.** 같은 프레임에서 하면 아직 그려지지
	# 않은 화면을 뜬다. `await` 로 붙이는 방법은 `_process` 안에서 한 번밖에 안 돌았다.
	_shot_frames += 1
	var phase := _shot_frames % 8
	_spin = false
	if phase == 1:
		if _solo:
			# 스치는 각도로 고정한다. 정면에서 오는 빛은 어떤 노멀이든 비슷하게 만든다.
			_angle = PI * 0.75
			_focus = _shot_taken
			_relayout()
		else:
			_angle = wanted[_shot_taken]
	elif phase == 5:
		var image := get_viewport().get_texture().get_image()
		var name := ("solo_%d" % _shot_taken) if _solo else ("compare_%d" % _shot_taken)
		var err := image.save_png("res://.renders-lighting/%s.png" % name)
		print("캡처: %s.png (각도 %.0f도, err=%d)" % [name, rad_to_deg(_angle), err])
		_shot_taken += 1


func _make_falloff(size: int) -> Image:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var half := float(size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(float(x) - half, float(y) - half).length() / half
			var k := 1.0 / (1.0 + pow(d * 2.4, 2.0))
			if d > 1.0:
				k = 0.0
			image.set_pixel(x, y, Color(1.0, 0.78, 0.52, k))
	return image
