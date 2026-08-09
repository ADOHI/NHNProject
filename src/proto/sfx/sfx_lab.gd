extends Control
## 효과음을 **만져 보는 화면** (docs/design/29-sound.md §29.7).
##
## 파일(tools/render_sfx_demo.gd)은 한 번 듣는 것이고, 이 화면은 만져 보는 것이다.
## 무게를 바꿔 가며 눌러 보고, 축이 실제로 세 값을 같이 미는지 숫자로 확인한다.
##
##     godot --path . res://src/proto/sfx/sfx_lab.tscn

const CHAIN_INTERVAL := 0.35
const CHAIN_HITS := 5

var _weight_slider: HSlider
var _material_picker: OptionButton
var _kind_picker: OptionButton
var _bend_picker: OptionButton
var _readout: RichTextLabel
var _wave: SfxWaveformView
var _player: Node
var _current_event := SfxEvent.Kind.HIT_LANDED
var _use_event := true
var _source_button: Button


func _ready() -> void:
	_player = get_node_or_null("/root/Sfx")
	if _player == null:
		_player = SfxPlayer.new()
		add_child(_player)
	_build()
	_refresh()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 12)
	add_child(row)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)

	_build_axis(left)
	_build_actions(left)

	_wave = SfxWaveformView.new()
	_wave.custom_minimum_size = Vector2(0, 190)
	_wave.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_wave)

	_readout = RichTextLabel.new()
	_readout.bbcode_enabled = true
	_readout.custom_minimum_size = Vector2(0, 210)
	_readout.add_theme_font_size_override("normal_font_size", 13)
	left.add_child(_readout)

	var list := SfxEventList.new()
	list.custom_minimum_size = Vector2(250, 0)
	list.event_chosen.connect(_on_event_chosen)
	row.add_child(list)


func _build_axis(parent: VBoxContainer) -> void:
	var title := Label.new()
	title.text = "무게 축 (무기 칸 수 1 부터 4)"
	title.add_theme_font_size_override("font_size", 15)
	parent.add_child(title)

	_weight_slider = HSlider.new()
	_weight_slider.min_value = 1.0
	_weight_slider.max_value = 4.0
	_weight_slider.step = 0.1
	_weight_slider.value = 2.0
	_weight_slider.value_changed.connect(func(_v: float) -> void: _refresh())
	parent.add_child(_weight_slider)

	var pickers := HBoxContainer.new()
	pickers.add_theme_constant_override("separation", 8)
	parent.add_child(pickers)

	_material_picker = _add_picker(pickers, "재질")
	for kind in SfxMaterial.Kind.values():
		_material_picker.add_item(SfxMaterial.label(kind), kind)
	_material_picker.selected = SfxMaterial.Kind.METAL

	_kind_picker = _add_picker(pickers, "종류")
	for name in SfxRequest.Kind.keys():
		_kind_picker.add_item(String(name))

	_bend_picker = _add_picker(pickers, "음정 방향")
	for name in SfxRequest.Bend.keys():
		_bend_picker.add_item(String(name))


func _add_picker(parent: HBoxContainer, label_text: String) -> OptionButton:
	var column := VBoxContainer.new()
	parent.add_child(column)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 12)
	column.add_child(label)
	var picker := OptionButton.new()
	picker.item_selected.connect(func(_i: int) -> void: _on_axis_changed())
	column.add_child(picker)
	return picker


func _build_actions(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	_add_button(row, "들어보기", _play_current)
	_add_button(row, "5타 체인 (변주 있이)", func() -> void: _play_chain(true))
	_add_button(row, "5타 체인 (변주 없이)", func() -> void: _play_chain(false))
	_add_button(row, "무게 1 부터 4", _play_weight_sweep)
	_source_button = Button.new()
	_source_button.toggle_mode = true
	_source_button.pressed.connect(_on_source_toggled)
	row.add_child(_source_button)
	_refresh_source_button()


func _add_button(parent: HBoxContainer, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)


func _on_event_chosen(event: SfxEvent.Kind) -> void:
	_current_event = event
	_use_event = true
	var request := SfxCatalog.request_for(event)
	_material_picker.selected = request.material
	_kind_picker.selected = request.kind
	_bend_picker.selected = request.bend
	if SfxCatalog.is_weight_driven(event):
		_weight_slider.value = request.weight
	_refresh()
	_play_current()


## 축을 직접 만지면 사건 표를 벗어난다. 그때부터는 슬라이더가 진짜다.
func _on_axis_changed() -> void:
	_use_event = false
	_refresh()


func _current_request() -> SfxRequest:
	if _use_event:
		var from_table := SfxCatalog.request_for(_current_event)
		if SfxCatalog.is_weight_driven(_current_event):
			return from_table.with_weight(_weight_slider.value)
		return from_table
	return SfxRequest.new(
		_kind_picker.selected as SfxRequest.Kind,
		_material_picker.selected as SfxMaterial.Kind,
		_weight_slider.value,
		_bend_picker.selected as SfxRequest.Bend
	)


func _play_current() -> void:
	_player.play_request(_current_request())
	_refresh()


func _play_chain(varied: bool) -> void:
	var base := _current_request()
	for hit in CHAIN_HITS:
		_player.play_request(base.with_seed((hit + 1) if varied else 7))
		await get_tree().create_timer(CHAIN_INTERVAL).timeout


func _play_weight_sweep() -> void:
	var base := _current_request()
	for cells in [1, 2, 3, 4]:
		_weight_slider.value = float(cells)
		_player.play_request(base.with_weight(float(cells)))
		_refresh()
		await get_tree().create_timer(0.75).timeout


func _refresh() -> void:
	var request := _current_request()
	var voice := SfxVoice.resolve(request)
	var clip := SfxRender.render(request)
	_wave.show_clip(clip)
	var used := SfxRender.source_for(request)
	var source_text := "CC0 파일" if used == SfxRender.Source.FILE else "합성 (재료 없음)"

	var overlap := clip.seconds() - CHAIN_INTERVAL
	var overlap_text := (
		"[color=#8fce7f]안 겹침[/color]"
		if overlap <= 0.0
		else "[color=#e08a72]겹침 %.0f ms[/color]" % (overlap * 1000.0)
	)
	_readout.text = (
		(
			"[b]%s[/b]   무게 %.1f   배수 %.3f\n\n"
			% [
				SfxMaterial.label(request.material),
				request.weight,
				SfxVoice.weight_scale(request.weight)
			]
		)
		+ "기본 주파수   %7.1f Hz\n" % voice.hz
		+ "감쇠 시간     %7.1f ms\n" % (voice.tau * 1000.0)
		+ "저역 차단     %7.1f Hz\n" % voice.cutoff_hz
		+ "소리 길이     %7.1f ms\n" % (voice.duration * 1000.0)
		+ "음 대 잡음    %7.2f\n" % voice.tone_ratio
		+ "[b]울림 진동 횟수  %5.2f[/b]  (무게가 변해도 안 변해야 한다)\n\n" % voice.ring_cycles()
		+ "체인 타 간격 %.2f 초 대비  %s\n" % [CHAIN_INTERVAL, overlap_text]
		+ "지금 울리는 소리 %d 개" % _player.active_count()
	)


## 원천을 바꾼다. **앞 판(합성)과 이번 판(CC0 파일)을 나란히 들어 보는 자리다.**
func _on_source_toggled() -> void:
	SfxRender.mode = (
		SfxRender.Source.SYNTH if _source_button.button_pressed else SfxRender.Source.FILE
	)
	_refresh_source_button()
	_refresh()
	_play_current()


func _refresh_source_button() -> void:
	var is_synth := SfxRender.mode == SfxRender.Source.SYNTH
	_source_button.button_pressed = is_synth
	_source_button.text = "원천: 합성" if is_synth else "원천: CC0 파일"


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			_weight_slider.value = float(key.keycode - KEY_1 + 1)
			_play_current()
		KEY_SPACE:
			_play_current()
		KEY_C:
			_play_chain(true)
