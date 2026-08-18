class_name SfxEventList
extends ScrollContainer
## 사건 목록 (docs/design/29-sound.md §29.3). 누르면 그 사건의 소리가 난다.
##
## 묶음으로 접어 둔다 — 소리는 직렬이라 50개를 한 번에 늘어놓으면
## 어디까지 들었는지 알 수 없게 된다.

signal event_chosen(event: SfxEvent.Kind)

const GROUP_COLOR := Color(0.62, 0.70, 0.84)


func _ready() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	add_child(column)
	for group in SfxEvent.Group.values():
		_add_group(column, group)


func _add_group(column: VBoxContainer, group: SfxEvent.Group) -> void:
	var events := SfxEvent.of_group(group)
	if events.is_empty():
		return

	var heading := Label.new()
	heading.text = SfxEvent.GROUP_LABELS[group]
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", GROUP_COLOR)
	column.add_child(heading)

	for event in events:
		var button := Button.new()
		# 무게가 게임 숫자에서 오는 사건은 표시해 둔다. 슬라이더가 먹히는 것들이다.
		var mark := "  [무게]" if SfxCatalog.is_weight_driven(event) else ""
		button.text = SfxEvent.label(event) + mark
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(_on_pressed.bind(event))
		column.add_child(button)

	column.add_child(HSeparator.new())


func _on_pressed(event: SfxEvent.Kind) -> void:
	event_chosen.emit(event)
