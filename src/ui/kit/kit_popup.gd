class_name KitPopup
extends Control
## 팝업. 버튼과 같은 규칙으로 만들어진, 다만 훨씬 높은 지형이다.
##
## 화면을 어둡게 덮지 않는다. 대신 **주변 지반을 눌러 내린다.**
## 팝업 둘레의 등고선은 웅덩이 쪽으로 끌려 내려가고 색이 차가워지므로,
## 뒤가 물러났다는 사실이 밝기가 아니라 지형으로 읽힌다.
## 안에 놓인 버튼은 이 고원 위에 다시 솟는다 — 고도가 더해지는 값이라
## 층을 따로 관리할 필요가 없다.

const WIDTH := KitTokens.UNIT * 62.0
const HEIGHT := KitTokens.UNIT * 27.0
const PAD := KitTokens.UNIT * 4.0

var title_text := "":
	set = _set_title_text
var body_text := "":
	set = _set_body_text

var _relief: KitRelief
var _field: KitField
var _title: Label
var _body: Label
var _confirm: KitButton
var _cancel: KitButton


func _ready() -> void:
	_relief = KitRelief.new(KitTokens.ELEVATION_POPUP, 1.7)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_CENTER)
	size = Vector2(WIDTH, HEIGHT)
	position = -size * 0.5
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -WIDTH * 0.5
	offset_top = -HEIGHT * 0.5
	offset_right = WIDTH * 0.5
	offset_bottom = HEIGHT * 0.5
	_build_contents()
	_field = KitField.find_in(get_tree())
	if _field != null:
		_field.register(self)
	tree_exiting.connect(_on_tree_exiting)


func _process(delta: float) -> void:
	_relief.advance(delta)


## 지금 이 고원의 고도. 위에 얹힌 버튼이 여기서부터 다시 솟는다.
func current_elevation() -> float:
	return _relief.elevation()


## 열릴 때 결단 쪽에 포커스를 준다. 포커스는 켜져 있는 동안 계속 물결을 낸다.
func open_focus() -> void:
	if _confirm != null:
		_confirm.grab_focus()


## KitField 계약.
func kit_rect() -> Rect2:
	return Rect2(global_position, size)


func kit_form() -> Vector4:
	return Vector4(
		_relief.elevation(), KitTokens.CORNER, KitTokens.SKIRT_POPUP, KitTokens.MOAT_DEPTH
	)


func kit_state() -> Vector4:
	return _relief.state_vector()


func kit_pulse() -> Vector4:
	return _relief.pulse_vector()


func _build_contents() -> void:
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", KitTokens.FONT_TITLE)
	_title.add_theme_color_override("font_color", KitTokens.TEXT)
	_title.position = Vector2(PAD, PAD)
	_title.text = title_text
	add_child(_title)

	_body = Label.new()
	_body.add_theme_font_size_override("font_size", KitTokens.FONT_SUB)
	_body.add_theme_color_override("font_color", KitTokens.TEXT_DIM)
	_body.position = Vector2(PAD, PAD + KitTokens.UNIT * 6.0)
	_body.size.x = WIDTH - PAD * 2.0
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.text = body_text
	add_child(_body)

	_cancel = KitButton.new()
	_cancel.elevation = KitTokens.ELEVATION_SUB
	_cancel.text = "물러난다"
	add_child(_cancel)
	_cancel.fit_to_text()

	_confirm = KitButton.new()
	_confirm.elevation = KitTokens.ELEVATION_KEY
	_confirm.text = "그래도 간다"
	add_child(_confirm)
	_confirm.fit_to_text()

	# 두 버튼은 붙여 둔다 — 같은 물음에 대한 두 답이므로 하나의 능선이어야 한다.
	var total := _cancel.size.x + KitTokens.GAP_JOINED + _confirm.size.x
	var base_x := WIDTH - PAD - total
	var base_y := HEIGHT - PAD - KitTokens.height_for(KitTokens.ELEVATION_KEY)
	_cancel.position = Vector2(
		base_x, base_y + (KitTokens.height_for(KitTokens.ELEVATION_KEY) - _cancel.size.y) * 0.5
	)
	_confirm.position = Vector2(base_x + _cancel.size.x + KitTokens.GAP_JOINED, base_y)


func _set_title_text(value: String) -> void:
	title_text = value
	if _title != null:
		_title.text = value


func _set_body_text(value: String) -> void:
	body_text = value
	if _body != null:
		_body.text = value


func _on_tree_exiting() -> void:
	if _field != null:
		_field.unregister(self)
