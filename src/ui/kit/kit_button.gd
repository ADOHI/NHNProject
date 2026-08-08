class_name KitButton
extends Button
## 버튼. **아무것도 그리지 않는다.**
##
## 배경도 테두리도 포커스 테도 없다. 이 노드가 하는 일은 자기 사각형과 고도를
## 장(KitField)에 알리는 것뿐이고, 보이는 것은 전부 그 지형의 결과다.
## 그래서 버튼의 "생김새"는 이 파일에 없다 — 고도 한 숫자에 있다.
##
## 상태는 밝기가 아니라 지형으로 말한다.
##   평상   봉우리. 정상은 평평하고 비탈에 등고선 고리가 깔린다
##   호버   봉우리가 솟는다. 정상에서 새 고리가 밀려 나온다
##   눌림   0 아래로 꺼져 **구덩이**가 된다. 등고선이 사각형 안으로 말려 들어가고
##          지도의 해칭(안쪽을 향한 짧은 빗금)이 붙는다
##   포커스 비탈에서 물결이 끊임없이 밀려 나간다. 강세색이 그 마루를 타고 흐른다
##   비활성 거의 평지로 내려앉는다. 흐려지는 것이 아니라 **밀어 올려지지 않은 자리**가
##          되어 바탕의 결이 글자 위를 그대로 지나간다

## 이 버튼의 급. 고도가 크기와 글자 크기를 함께 정한다.
@export var elevation: float = KitTokens.ELEVATION_MAIN:
	set = _set_elevation

var _relief: KitRelief
var _field: KitField

## 이 버튼이 얹혀 있는 지형. 팝업 안에 들어가면 그 고원 위에서 다시 솟아야 한다.
var _stack: KitPopup


func _ready() -> void:
	_relief = KitRelief.new(elevation)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_blank_theme()
	_apply_metrics()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	_stack = _find_stack()
	_field = KitField.find_in(get_tree())
	if _field != null:
		_field.register(self)
	tree_exiting.connect(_on_tree_exiting)


func _process(delta: float) -> void:
	_relief.set_dim(disabled)
	_relief.stack_base = 0.0 if _stack == null else _stack.current_elevation()
	# 숨의 위상을 자리에서 뽑는다. 난수로 주면 캡처마다 화면이 달라져 심사가 흔들리고,
	# 이웃끼리 우연히 같은 박자가 되면 세 봉우리가 한 몸으로 부푼다.
	# 이 계수면 100px 떨어진 이웃의 위상이 거의 반대가 된다.
	_relief.phase = global_position.x * 0.037 + global_position.y * 0.021
	_relief.advance(delta)
	# 더 높은 지형에 묻히면 글자까지 사라진다. 안 그러면 팝업이 떴을 때
	# 고원 아래 깔린 버튼의 글자만 허공에 떠 있다.
	if _field != null:
		visible = not _field.is_buried(self, Rect2(global_position, size), _relief.rest_elevation())


## KitField 계약.
func kit_rect() -> Rect2:
	return Rect2(global_position, size)


func kit_form() -> Vector4:
	return Vector4(_relief.elevation(), KitTokens.CORNER, KitTokens.SKIRT_BUTTON, 0.0)


func kit_state() -> Vector4:
	return _relief.state_vector()


func kit_pulse() -> Vector4:
	return _relief.pulse_vector()


## 위로 거슬러 올라가며 자기가 올라탄 고원을 찾는다.
## 부모를 직접 알 필요는 없다 — 얹힐 지형이 있는지만 알면 된다.
func _find_stack() -> KitPopup:
	var node := get_parent()
	while node != null:
		var popup := node as KitPopup
		if popup != null:
			return popup
		node = node.get_parent()
	return null


## 글자 너비에 맞추되 **규격의 정수배로 올림한다.**
##
## 자동 크기에 맡기면 버튼마다 폭이 제각각이 되어, 화면에 이미 깔린 등고선 간격과
## 아무 관계가 없는 치수가 생긴다. 규격이 보이려면 셀 수 있어야 한다.
func fit_to_text() -> void:
	var font := get_theme_font("font")
	var font_size := KitTokens.font_size_for(elevation)
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var padded := text_width + KitTokens.UNIT * 5.0
	custom_minimum_size.x = ceilf(padded / KitTokens.UNIT) * KitTokens.UNIT
	size = custom_minimum_size


func _set_elevation(value: float) -> void:
	elevation = value
	if _relief != null:
		_relief.base_elevation = value
	if is_inside_tree():
		_apply_metrics()


## 크기는 고도에서 나온다. 폭만 내용이 정하고, 그것도 규격의 정수배로 올림한다.
func _apply_metrics() -> void:
	custom_minimum_size.y = KitTokens.height_for(elevation)
	add_theme_font_size_override("font_size", KitTokens.font_size_for(elevation))
	add_theme_constant_override("h_separation", int(KitTokens.UNIT))
	add_theme_color_override("font_color", KitTokens.TEXT)
	add_theme_color_override("font_hover_color", KitTokens.TEXT)
	add_theme_color_override("font_pressed_color", KitTokens.ACCENT)
	add_theme_color_override("font_focus_color", KitTokens.TEXT)
	add_theme_color_override("font_disabled_color", KitTokens.TEXT_DIM)


## Godot 기본 버튼 그림을 전부 없앤다. 한 픽셀이라도 남으면
## "지형이 전부"라는 규칙이 깨진다.
func _apply_blank_theme() -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxEmpty.new()
		box.content_margin_left = KitTokens.UNIT * 2.5
		box.content_margin_right = KitTokens.UNIT * 2.5
		add_theme_stylebox_override(state, box)


func _on_mouse_entered() -> void:
	_relief.set_hover(true)


func _on_mouse_exited() -> void:
	_relief.set_hover(false)


func _on_button_down() -> void:
	_relief.set_press(true)


func _on_button_up() -> void:
	_relief.set_press(false)


func _on_focus_entered() -> void:
	_relief.set_focus(true)


func _on_focus_exited() -> void:
	_relief.set_focus(false)


func _on_tree_exiting() -> void:
	if _field != null:
		_field.unregister(self)
