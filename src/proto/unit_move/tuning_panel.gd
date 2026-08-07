class_name ProtoTuningPanel
extends PanelContainer
## 손맛 수치를 화면에서 직접 돌리는 조절판. 목록은 ProtoMoveTuning.DEFS 에서 그대로 만들어진다.
##
## 슬라이더를 코드가 아니라 정의에서 만드는 이유는, 수치를 하나 추가할 때 화면을 고치는 일을
## 없애기 위해서다. 고칠 곳이 둘이면 둘 중 하나는 반드시 뒤처진다.

## 유닛 수를 바꿔 달라. 성능 한계를 재는 데도 쓴다.
signal units_requested(delta: int)

## 유닛을 처음 자리로 되돌려 달라.
signal respawn_requested

## 장애물을 새로 만들어 달라.
signal obstacles_requested

## 개발 표시 항목이 켜지거나 꺼졌다.
signal debug_toggled(key: String, value: bool)

const _HINT_COLOR := Color(0.62, 0.65, 0.72)
const _TITLE_COLOR := Color(0.92, 0.94, 0.98)

var _tuning: ProtoMoveTuning
var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}


func bind(tuning: ProtoMoveTuning) -> void:
	_tuning = tuning
	_build()
	_tuning.value_changed.connect(_on_tuning_changed)


func _on_tuning_changed(_key: String) -> void:
	_sync_from_tuning()


## 조절판 전체를 만든다. 위쪽은 버튼, 아래쪽은 스크롤되는 슬라이더 목록이다.
func _build() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 10)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	column.add_child(_title("이동 조절판"))
	column.add_child(_hint("값을 돌려 보고 자기 취향을 찾으세요. 기본값 복원으로 언제든 되돌립니다."))
	column.add_child(_buttons())
	column.add_child(_toggles())
	column.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for definition in ProtoMoveTuning.DEFS:
		list.add_child(_slider_row(definition))
	_sync_from_tuning()


func _buttons() -> Control:
	var box := VBoxContainer.new()
	var top := HBoxContainer.new()
	box.add_child(top)
	top.add_child(_button("기본값 복원", func() -> void: _tuning.reset()))
	top.add_child(_button("유닛 재배치", func() -> void: respawn_requested.emit()))
	var bottom := HBoxContainer.new()
	box.add_child(bottom)
	bottom.add_child(_button("유닛 +10", func() -> void: units_requested.emit(10)))
	bottom.add_child(_button("유닛 -10", func() -> void: units_requested.emit(-10)))
	bottom.add_child(_button("장애물 변경", func() -> void: obstacles_requested.emit()))
	return box


func _toggles() -> Control:
	var box := HBoxContainer.new()
	box.add_child(_check("흐름장", "flow", true))
	box.add_child(_check("힘", "forces", true))
	box.add_child(_check("자리", "slots", true))
	return box


func _check(text: String, key: String, pressed: bool) -> CheckBox:
	var check := CheckBox.new()
	check.text = text
	check.button_pressed = pressed
	check.focus_mode = Control.FOCUS_NONE
	check.toggled.connect(func(value: bool) -> void: debug_toggled.emit(key, value))
	return check


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	return button


func _title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", _TITLE_COLOR)
	return label


func _hint(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", _HINT_COLOR)
	return label


func _slider_row(definition: Dictionary) -> Control:
	var key := String(definition["key"])
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var header := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = String(definition["label"])
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 13)
	header.add_child(name_label)
	var value_label := Label.new()
	value_label.add_theme_font_size_override("font_size", 13)
	header.add_child(value_label)
	row.add_child(header)

	var slider := HSlider.new()
	slider.min_value = float(definition["min"])
	slider.max_value = float(definition["max"])
	slider.step = float(definition["step"])
	# 슬라이더가 키 입력을 먹으면 부대 숫자키와 화면 이동이 씹힌다.
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(value: float) -> void: _tuning.set_value(key, value))
	row.add_child(slider)
	row.add_child(_hint(String(definition["hint"])))

	_sliders[key] = slider
	_value_labels[key] = value_label
	return row


## 슬라이더와 숫자를 현재 값에 맞춘다. 기본값 복원 뒤에도 화면이 따라와야 한다.
func _sync_from_tuning() -> void:
	if _tuning == null:
		return
	for key: String in _sliders:
		var slider: HSlider = _sliders[key]
		var value := _tuning.get_value(key)
		if not is_equal_approx(slider.value, value):
			slider.set_value_no_signal(value)
		var label: Label = _value_labels[key]
		var changed := not is_equal_approx(value, _tuning.default_of(key))
		label.text = "%.2f" % value
		label.add_theme_color_override(
			"font_color", Color(0.98, 0.80, 0.40) if changed else _TITLE_COLOR
		)
