class_name AnimTuningPanel
extends PanelContainer
## 지연 · 호 · 배율 · 비대칭 · 앞뒤 · 디딤을 실시간으로 끄는 조절판.
##
## **결과물의 일부다.** 다 끄면 "위아래로 뻣뻣하게 진동하는 도형 여섯" 이 되고,
## 그 상태와의 차이가 이 작업의 전부다. 사람이 직접 갈라 보게 하는 것이 목적이다.
##
## `디딤` 은 walk 부터 쓴다 — idle 은 두 발이 둘 다 디딘 발이라 끄고 켤 것이 없다.
##
## 글리프 주의: 화면에 뿌리는 문자열은 SongMyung 에 있는 글자만 쓴다.
## 화살표 · 삼각형 · 가운뎃점은 폰트에 없어서 웹 빌드에서 두부가 된다
## (`docs/conventions.md` §5.1). 여기서는 한글과 ASCII 와 `•` 만 쓴다.

signal features_changed(features: AnimFeatures)
signal speed_changed(speed: float)

const ROWS: Array[Array] = [
	["delay", "지연", "파츠가 몸을 늦게 따라오는 정도"],
	["arc", "호", "경로의 좌우 성분 - 머리의 8 자"],
	["squash", "배율", "눌림과 늘어남 (면적 보존)"],
	["asymmetry", "비대칭", "무게가 앞뒤로 옮겨 다니는 것"],
	["depth", "앞뒤", "뒷손이 작고 느려 보이는 것"],
	["plant", "디딤", "디딘 발이 땅에 붙어 등속으로 흐르는 것 (walk)"],
]

const SPEED_MIN := 0.1
const SPEED_MAX := 2.0

var _features := AnimFeatures.all_on()
var _sliders: Dictionary[String, HSlider] = {}
var _values: Dictionary[String, Label] = {}
var _speed_slider: HSlider
var _speed_value: Label


func _init() -> void:
	custom_minimum_size = Vector2(300.0, 0.0)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	var title := Label.new()
	title.text = "조절판"
	column.add_child(title)

	for row: Array in ROWS:
		_add_feature_row(column, row[0] as String, row[1] as String, row[2] as String)

	column.add_child(HSeparator.new())
	_add_speed_row(column)

	var note := Label.new()
	note.text = "다 0 으로 내리면 관절 없는 인형이 된다"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)


## 지금 조절판이 들고 있는 값. 사본을 준다 — 밖에서 고쳐도 조절판이 안 흔들린다.
func features() -> AnimFeatures:
	return _features.copy()


## 키로 값을 바꿨을 때 슬라이더를 따라오게 한다. 조절판과 키가 어긋나면 조절판이 거짓말한다.
func sync_from(features: AnimFeatures) -> void:
	_features = features.copy()
	for field: String in _sliders:
		_sliders[field].set_value_no_signal(_features.get(field))
		_values[field].text = _format(_features.get(field))


func set_speed_display(speed: float) -> void:
	if _speed_slider != null:
		_speed_slider.set_value_no_signal(speed)
		_speed_value.text = "%.2f 배" % speed


func _add_feature_row(column: VBoxContainer, field: String, label: String, hint: String) -> void:
	var head := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = label
	name_label.custom_minimum_size = Vector2(64.0, 0.0)
	head.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = _features.get(field)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 초점을 안 받는다. 받으면 Tab 이 슬라이더 사이를 오가는 데 쓰여
	# **조절판 접기(Tab)가 안 먹는다.** 키보드 조절은 Q W E A 가 대신한다.
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(_on_feature_changed.bind(field))
	head.add_child(slider)

	var value := Label.new()
	value.text = _format(slider.value)
	value.custom_minimum_size = Vector2(48.0, 0.0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(value)

	column.add_child(head)

	var hint_label := Label.new()
	hint_label.text = "  " + hint
	column.add_child(hint_label)

	_sliders[field] = slider
	_values[field] = value


func _add_speed_row(column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = "속도"
	name_label.custom_minimum_size = Vector2(64.0, 0.0)
	row.add_child(name_label)

	_speed_slider = HSlider.new()
	_speed_slider.min_value = SPEED_MIN
	_speed_slider.max_value = SPEED_MAX
	_speed_slider.step = 0.05
	_speed_slider.value = 1.0
	_speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speed_slider.focus_mode = Control.FOCUS_NONE
	_speed_slider.value_changed.connect(func(v: float) -> void: speed_changed.emit(v))
	row.add_child(_speed_slider)

	_speed_value = Label.new()
	_speed_value.text = "1.00 배"
	_speed_value.custom_minimum_size = Vector2(48.0, 0.0)
	_speed_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_speed_value)

	column.add_child(row)


func _on_feature_changed(value: float, field: String) -> void:
	_features.set(field, value)
	_values[field].text = _format(value)
	features_changed.emit(_features.copy())


func _format(value: float) -> String:
	if is_zero_approx(value):
		return "끔"
	return "%.2f" % value
