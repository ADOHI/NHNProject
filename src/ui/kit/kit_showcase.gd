class_name KitShowcase
extends Control
## 나전 키트 견본. **버튼만 있다.**
##
## 화면을 만들지 않는다. 방도 위험도도 던전도 나오지 않는다 —
## 앞의 두 판본은 아직 없는 게임에 UI 를 재단하다 조형을 잃었다.
##
## 배치는 격자가 아니다. 세 줄로 늘어놓고 회색 소제목을 붙이면 그것은 화면이 아니라
## **디자인 시스템 명세서**이고, 명세서는 아름다울 수 없다. 대신 왼쪽으로 흘러내리는
## 계단 하나와 오른쪽 아래에 떨어진 판 하나를 두고, 화면의 절반은 비워 둔다.
##
## 상태 다섯은 서로 다른 판이 하나씩 맡는다. 어느 것이 어느 상태인지는 화면에
## 적지 않는다 — 이름표가 붙는 순간 다시 명세서가 된다. §20.8 에 적어 둔다.

const LACQUER_SHADER := preload("res://src/ui/kit/kit_lacquer.gdshader")
const LACQUER_TEX := preload("res://assets/ui/kit/lacquer_ground.webp")
const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")

var _ground: ColorRect
var _guide: Label
var _buttons: Array[KitButton] = []
var _time: float = 0.0
var _all_disabled: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ground()
	_build_buttons()
	_build_guide()
	if not _buttons.is_empty():
		_buttons[0].grab_focus()


func _process(delta: float) -> void:
	_time += delta
	var mat := _ground.material as ShaderMaterial
	# 바탕도 죽어 있으면 안 된다. 판보다 훨씬 느리게 흐른다.
	mat.set_shader_parameter("phase", _time * 6.0)
	mat.set_shader_parameter("rect_size", size)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	match key.keycode:
		KEY_D:
			_all_disabled = not _all_disabled
			for button in _buttons:
				button.disabled = _all_disabled
		KEY_H:
			_guide.visible = not _guide.visible
		KEY_ESCAPE:
			get_tree().quit()


## 심사 캡처가 조작 안내를 끈다. 안내 글자가 그림에 남으면 조형이 아니라
## 스크린샷을 심사하게 된다.
func set_guide_visible(shown: bool) -> void:
	if _guide != null:
		_guide.visible = shown


func _build_ground() -> void:
	_ground = ColorRect.new()
	_ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = LACQUER_SHADER
	mat.set_shader_parameter("ground", LACQUER_TEX)
	# 바탕은 무광이고 판보다 어둡다. 판과 같은 값이면 판이 판으로 보이지 않는다.
	mat.set_shader_parameter("ink", KitPalette.GROUND)
	mat.set_shader_parameter("depth_tint", KitPalette.COOL)
	mat.set_shader_parameter("chamfer", 0.0)
	mat.set_shader_parameter("dust", 0.10)
	mat.set_shader_parameter("depth_gain", 0.09)
	mat.set_shader_parameter("sheen", 0.010)
	_ground.material = mat
	add_child(_ground)


## 왼쪽으로 흘러내리는 계단. 단마다 조금씩 더 들여쓰기해서 오른쪽 가장자리가
## 사선이 된다. 반듯하게 맞추면 표가 되고, 표는 조형이 아니다.
func _build_buttons() -> void:
	# 단마다 24px 씩 더 들여쓰고, 세로 간격은 96 → 80 → 72 로 좁아진다.
	# 등간격으로 두면 표가 되고, 좁아지면 아래로 흘러내리는 박자가 생긴다.
	_place("탐사 개시", KitMetrics.Grade.GRAVE, Vector2(296.0, 206.0))

	var tend := _place("장비 정비", KitMetrics.Grade.MAIN, Vector2(320.0, 302.0))
	tend.demo_hover = 1.0
	# **한 몸** — 4px. 자개 띠가 두 판을 가로질러 그대로 이어진다.
	_place(
		"보급", KitMetrics.Grade.MAIN, Vector2(320.0 + tend.size.x + KitMetrics.GAP_ONE_BODY, 302.0)
	)

	var record := _place("탐사 기록", KitMetrics.Grade.MINOR, Vector2(344.0, 382.0))
	record.demo_focus = 1.0
	# **한 묶음** — 16px. 띠는 끊기고 황동 실선만 이어진다.
	_place(
		"설정", KitMetrics.Grade.MINOR, Vector2(344.0 + record.size.x + KitMetrics.GAP_GROUP, 382.0)
	)

	var locked := _place("회수 불가", KitMetrics.Grade.MINOR, Vector2(368.0, 454.0))
	locked.disabled = true

	# **남남** — 계단에서 떨어져 나와 혼자 서 있다. 아무것도 이어지지 않는다.
	var launch := _place("출격", KitMetrics.Grade.MAIN, Vector2(752.0, 486.0))
	launch.demo_press = 1.0


func _place(label: String, grade: KitMetrics.Grade, at: Vector2) -> KitButton:
	var button := KitButton.new()
	button.grade = grade
	button.text = label
	button.position = at
	add_child(button)
	button.fit_to_text()
	_buttons.append(button)
	return button


func _build_guide() -> void:
	_guide = Label.new()
	var variation := FontVariation.new()
	variation.base_font = FONT
	variation.spacing_glyph = 1
	_guide.add_theme_font_override("font", variation)
	_guide.add_theme_font_size_override("font_size", 12)
	_guide.add_theme_color_override("font_color", Color(0.55, 0.55, 0.52, 0.72))
	_guide.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_guide.add_theme_constant_override("outline_size", 4)
	_guide.text = "Tab 포커스   D 비활성   H 안내 숨김   Esc 닫기"
	_guide.position = Vector2(28.0, 664.0)
	_guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_guide)
