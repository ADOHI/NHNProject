class_name KitButton
extends BaseButton
## 버튼 — 검은 옻칠 판에 자개를 박은 물건.
##
## **겹 일곱 장으로 되어 있고, 겹마다 다른 속도로 움직인다.** 그 속도 차이가 깊이다.
## 평면 하나에 셰이더를 먹이는 것과 근본적으로 다르다.
##
##   0 잔광     판 아래로 새어 나오는 자개색. 호버에서 벌어진다
##   1 옻칠     기준. 움직이지 않는다
##   2 속반사   바닥 위를 반대 방향으로 미끄러진다  (겹 1·2 는 한 셰이더가 만든다)
##   3 자개 띠  자리는 고정, 조각마다 편광 위상이 다르다
##   4 조각     틀 밖으로 넘어간다. 개별 표류
##   5 황동     모서리를 지나쳐 뻗는다. 닫히지 않는다
##   6 글자
##   7 광택     가장 빠르다. 판 위를 지나간다
##
## 상태는 밝기가 아니라 **재료**로 말한다. 눌리면 광택이 밝아지는 것이 아니라
## **꺼진다** — 광택은 각도의 함수이고 판이 눌렸기 때문이다.
## 비활성은 흐려지는 것이 아니라 **편광이 죽어** 그냥 조개껍질이 된다.

const NACRE_SHADER := preload("res://src/ui/kit/kit_nacre.gdshader")
const LACQUER_SHADER := preload("res://src/ui/kit/kit_lacquer.gdshader")
const GLOSS_SHADER := preload("res://src/ui/kit/kit_gloss.gdshader")
const GLOW_SHADER := preload("res://src/ui/kit/kit_glow.gdshader")

const LACQUER_TEX := preload("res://assets/ui/kit/lacquer_ground.webp")
const BAND_TEX := preload("res://assets/ui/kit/inlay_band.webp")
const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")

## 잔광이 판 둘레로 번지는 여백.
const GLOW_MARGIN: float = 22.0

## 호버에서 판이 떠오르는 높이.
const HOVER_RISE: float = 2.0

## 광택이 판을 한 번 훑는 데 걸리는 시간. idle 에서는 아주 느려야 한다 —
## 빨라지는 순간 「훑는 조명」이라는 장르 기성품이 된다.
const GLOSS_IDLE_PERIOD: float = 40.0

## 호버 중에 자개 띠를 훑는 빛이 도는 주기.
const SWEEP_PERIOD: float = 2.4

@export var text: String = "":
	set = _set_text

@export var grade: KitMetrics.Grade = KitMetrics.Grade.MAIN:
	set = _set_grade

## 심사 캡처용 상태 고정. 음수면 실제 입력을 따른다.
##
## 상태 다섯을 한 화면에 나란히 세우려면 마우스가 다섯 자리에 동시에 있어야 하는데
## 그럴 수 없다. 캡처 도구가 아니라 화면 쪽에 두는 이유는, 심사에 나가는 그림과
## 사람이 띄워 보는 그림이 **같은 씬**이어야 하기 때문이다.
var demo_hover: float = -1.0
var demo_press: float = -1.0
var demo_focus: float = -1.0

var _glow: ColorRect
var _plate: ColorRect
var _band: TextureRect
var _shards: KitShards
var _brass: KitBrass
var _label: Label
var _gloss: ColorRect

var _hover: float = 0.0
var _press: float = 0.0
var _focus: float = 0.0
var _dead: float = 0.0
var _kick: float = 0.0

## 겹마다 다른 속도로 누적한다. TIME 을 직접 쓰면 호버로 속도가 바뀌는 순간 튄다.
var _phase: float = 0.0
var _time: float = 0.0
var _seed: int = 0


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# 판마다 조각과 위상이 달라야 한다. 자리에서 뽑으므로 캡처마다 같은 그림이 나온다.
	_seed = int(absf(position.x) * 0.5 + absf(position.y) * 1.7) + get_index() * 3
	_build_layers()
	_apply_metrics()
	resized.connect(_on_resized)
	mouse_entered.connect(func() -> void: pass)
	set_process(true)


func _process(delta: float) -> void:
	_dead = KitMetrics.approach(_dead, 1.0 if disabled else 0.0, delta, 0.22)
	var want_hover := 1.0 if (is_hovered() and not disabled) else 0.0
	var want_press := 1.0 if (button_pressed and not disabled) else 0.0
	var want_focus := 1.0 if (has_focus() and not disabled) else 0.0
	if demo_hover >= 0.0:
		want_hover = demo_hover
	if demo_press >= 0.0:
		want_press = demo_press
	if demo_focus >= 0.0:
		want_focus = demo_focus
	var was_press := _press
	_hover = KitMetrics.approach_state(
		_hover, want_hover, delta, KitMetrics.HOVER_IN, KitMetrics.HOVER_OUT
	)
	_press = KitMetrics.approach_state(
		_press, want_press, delta, KitMetrics.PRESS_IN, KitMetrics.PRESS_OUT
	)
	_focus = KitMetrics.approach_state(
		_focus, want_focus, delta, KitMetrics.FOCUS_IN, KitMetrics.FOCUS_OUT
	)

	# 눌린 순간 조각이 실제로 튀어 나간다. 되돌아오는 것은 감쇠에 맡긴다.
	if _press - was_press > 0.25:
		_kick = 1.0
	_kick = maxf(0.0, _kick - delta * 3.4)

	# 편광은 늘 돈다. 호버에서 빨라지되 멈추지는 않는다 —
	# 자개는 아무도 안 볼 때도 색이 변하는 재료다.
	var alive := 1.0 - _dead
	_phase += delta * (0.028 + 0.055 * _hover) * alive
	_time += delta * alive

	_update_plate()
	_update_band()
	_update_shards()
	_update_brass()
	_update_label()
	_update_gloss()
	_update_glow()


## 글자 너비에 맞추되 원자의 정수배로 올림한다.
func fit_to_text() -> void:
	var font_size := KitMetrics.font_size_for(grade)
	var variation := _make_font(font_size)
	var width := variation.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	custom_minimum_size = Vector2(KitMetrics.fit_width(width, grade), KitMetrics.height_for(grade))
	size = custom_minimum_size


func _build_layers() -> void:
	_glow = ColorRect.new()
	_glow.material = _shader_material(GLOW_SHADER)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.color = Color(0, 0, 0, 0)
	add_child(_glow)

	_plate = ColorRect.new()
	var plate_mat := _shader_material(LACQUER_SHADER)
	plate_mat.set_shader_parameter("ground", LACQUER_TEX)
	_plate.material = plate_mat
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)

	# 띠는 원판을 **잘라서** 쓴다 (`uv_offset`/`uv_scale`). 통째로 늘이면 판이 넓어질수록
	# 조각이 굵어지는데, 실제 나전에서 조각 크기는 판 크기와 무관하다. 게다가 1024px 을
	# 14px 로 짓눌러 넣으면 조각이 뭉개져 얼룩이 된다 (1차 렌더에서 실제로 그랬다).
	_band = TextureRect.new()
	_band.texture = BAND_TEX
	_band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_band.stretch_mode = TextureRect.STRETCH_SCALE
	var band_mat := _shader_material(NACRE_SHADER)
	band_mat.set_shader_parameter("src", BAND_TEX)
	_band.material = band_mat
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_band)

	_shards = KitShards.new()
	add_child(_shards)
	_shards.build(_seed, NACRE_SHADER)

	_brass = KitBrass.new()
	add_child(_brass)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)

	_gloss = ColorRect.new()
	_gloss.material = _shader_material(GLOSS_SHADER)
	_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gloss.color = Color(0, 0, 0, 0)
	add_child(_gloss)

	_layout()


func _layout() -> void:
	if _plate == null:
		return
	var rise := HOVER_RISE * _hover - HOVER_RISE * _press
	_plate.position = Vector2(0.0, -rise)
	_plate.size = size
	_gloss.position = _plate.position
	_gloss.size = size
	_glow.position = Vector2(-GLOW_MARGIN, -GLOW_MARGIN - rise)
	_glow.size = size + Vector2(GLOW_MARGIN, GLOW_MARGIN) * 2.0

	# 자개 이음매는 왼쪽 모서리를 따라 세로로 서고 아래로 판을 넘어간다.
	# 위아래를 판에 맞추면 그 순간 테두리가 되고, 테두리는 어느 UI 에나 있다.
	_band.position = Vector2(0.0, -rise)
	_band.size = Vector2(KitMetrics.SEAM_WIDTH, size.y + KitMetrics.SEAM_OVERSHOOT_BOTTOM)

	_shards.position = Vector2(0.0, -rise)
	_shards.plate_size = size
	_brass.position = Vector2(0.0, -rise)
	_brass.size = size

	# 이음매가 왼쪽을 차지하므로 글자는 그만큼 오른쪽으로 밀린 공간의 가운데에 앉는다.
	_label.position = Vector2(KitMetrics.SEAM_WIDTH, -rise)
	_label.size = Vector2(size.x - KitMetrics.SEAM_WIDTH, size.y)


func _update_plate() -> void:
	_layout()
	var mat := _plate.material as ShaderMaterial
	mat.set_shader_parameter("rect_size", size)
	mat.set_shader_parameter("chamfer", KitMetrics.CHAMFER)
	mat.set_shader_parameter("phase", _phase * 34.0)
	mat.set_shader_parameter("lift", _hover)
	mat.set_shader_parameter("press", _press)
	mat.set_shader_parameter("dead", _dead)
	mat.set_shader_parameter("ink", KitPalette.INK)
	mat.set_shader_parameter("depth_tint", KitPalette.COOL)


func _update_band() -> void:
	var mat := _band.material as ShaderMaterial
	# 원판에서 잘라 올 구간. 폭은 판이 정하고(조각 크기는 고정), 세로는 가운데 띠만 쓴다.
	# 판마다 시작 자리가 달라 같은 조각 배열이 두 번 나오지 않는다.
	mat.set_shader_parameter("vertical", true)
	# 원판에서 잘라 올 구간. 이음매가 길수록 원판의 더 긴 구간을 가져가므로
	# 조각 하나의 크기는 판이 커져도 그대로다 — 실제 나전이 그렇다.
	var pieces := _band.size.y / KitMetrics.BAND_PIECE_WIDTH
	var window := clampf(pieces / 24.0, 0.10, 1.0)
	var start := fposmod(NacrePhase.shard_phase(_seed), 1.0 - window)
	mat.set_shader_parameter("uv_offset", Vector2(start, 0.24))
	mat.set_shader_parameter("uv_scale", Vector2(window, 0.52))
	# 아래로 갈수록 상감이 흩어져 사라진다. 끝을 맞추면 테두리가 된다.
	mat.set_shader_parameter("dissolve_from", 0.74)
	mat.set_shader_parameter("phase", _phase)
	mat.set_shader_parameter("glow", _hover)
	mat.set_shader_parameter("dead", _dead)
	mat.set_shader_parameter("gain", 1.0 - _press * 0.35)
	# 호버 중에만 빛이 띠를 훑는다. 띠의 조각이 애초에 낱개라
	# 지나가는 빛만으로 **조각이 차례로 켜진다.**
	if _hover > 0.02:
		var t := fposmod(_time, SWEEP_PERIOD) / SWEEP_PERIOD
		mat.set_shader_parameter("sweep", -0.25 + t * 1.5)
		mat.set_shader_parameter("sweep_width", 0.22)
	else:
		mat.set_shader_parameter("sweep", -1.0)


func _update_shards() -> void:
	_shards.phase = _phase
	_shards.glow = _hover
	_shards.dead = _dead
	_shards.kick = _kick
	_shards.advance(_time)


func _update_brass() -> void:
	_brass.lift = _hover
	_brass.focus_amount = _focus
	_brass.dead = _dead
	# 마디가 판 둘레를 도는 속도. 한 바퀴에 2.4초.
	_brass.runner = fposmod(_time / 2.4, 1.0)
	_brass.queue_redraw()


func _update_label() -> void:
	var col := KitPalette.TEXT.lerp(KitPalette.TEXT_DEAD, _dead)
	# 눌리면 글자만 1px 내려간다. 판과 함께 움직이면 아무 일도 없었던 것이 된다.
	_label.position.y += _press
	_label.add_theme_color_override("font_color", col)


func _update_gloss() -> void:
	var mat := _gloss.material as ShaderMaterial
	mat.set_shader_parameter("rect_size", size)
	mat.set_shader_parameter("chamfer", KitMetrics.CHAMFER)
	# idle 에서는 40초에 한 번, 호버에서는 판 위에 머무르며 조금씩 흔들린다.
	var idle_travel := fposmod(_time / GLOSS_IDLE_PERIOD, 1.0) * 1.6 - 0.3
	var hover_travel := 0.34 + sin(_time * 0.9) * 0.12
	mat.set_shader_parameter("travel", lerpf(idle_travel, hover_travel, _hover))
	mat.set_shader_parameter("width", lerpf(0.10, 0.13, _hover))
	# 광택은 각도의 함수다. 판이 눌리면 밝아지지 않고 **꺼진다.**
	mat.set_shader_parameter("strength", (1.0 + _hover * 1.0) * (1.0 - _press) * (1.0 - _dead))


func _update_glow() -> void:
	var mat := _glow.material as ShaderMaterial
	mat.set_shader_parameter("field_size", _glow.size)
	mat.set_shader_parameter("plate_size", size)
	mat.set_shader_parameter("margin", GLOW_MARGIN)
	mat.set_shader_parameter("spread", _hover * (1.0 - _press * 0.7))
	mat.set_shader_parameter("dead", _dead)
	mat.set_shader_parameter("tint", KitPalette.COOL)


func _apply_metrics() -> void:
	if _label == null:
		return
	var font_size := KitMetrics.font_size_for(grade)
	_label.add_theme_font_override("font", _make_font(font_size))
	_label.add_theme_font_size_override("font_size", font_size)
	_label.text = text
	custom_minimum_size.y = KitMetrics.height_for(grade)


## 자간을 벌린 SongMyung. 명조는 자간을 벌리면 격이 올라가고,
## 굵기 대비가 없는 폰트에서 위계를 만들 수 있는 거의 유일한 수단이다.
func _make_font(font_size: int) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = FONT
	variation.spacing_glyph = int(round(KitMetrics.tracking_for(grade)))
	# 자간을 벌리면 마지막 글자 뒤에도 여백이 붙어 가운데가 왼쪽으로 밀린다.
	variation.spacing_space = 0
	if font_size <= 0:
		variation.spacing_glyph = 0
	return variation


func _shader_material(shader: Shader) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


func _set_text(value: String) -> void:
	text = value
	if _label != null:
		_label.text = value


func _set_grade(value: KitMetrics.Grade) -> void:
	grade = value
	if is_inside_tree():
		_apply_metrics()


func _on_resized() -> void:
	_layout()
