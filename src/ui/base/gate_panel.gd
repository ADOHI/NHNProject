class_name BaseGatePanel
extends VBoxContainer
## 아지트의 **오른쪽 위** — 지금 열려 있는 게이트 목록.
##
## ## 미리보기는 이 화면이 만들지 않는다
##
## 줄들은 전부 Gate.preview_lines(level) 이 만든 것이다. 공개 수준이 낮으면 짧아지고
## 높으면 길어진다 (docs/design/22-guild-base.md §22.5).
## 화면이 문장을 다시 조립하면 나중에 올 조형 화면과 정보량이 어긋난다.
##
## ## 목록이 흐려지는 것이 여기서 보인다
##
## 공개 수준은 **지금 데려가기로 표시한 대원을 뺀** 정보실 인원이 정한다.
## 가운데 기둥에서 정보실 대원을 켜면 이 칸의 줄이 그 자리에서 짧아진다.

## 이 자리의 게이트를 고르겠다.
signal gate_selected(index: int)


## 게이트 목록을 다시 그린다.
func refresh(gates: Array[Gate], level: GateDisclosure.Level, selected: int, locked: bool) -> void:
	BaseWidgets.clear(self)
	add_child(_header_box(gates.size(), level))
	for index in gates.size():
		add_child(_gate_box(gates[index], index, level, selected, locked))


func _header_box(count: int, level: GateDisclosure.Level) -> BaseBox:
	var box := BaseBox.new("열려 있는 게이트 %d" % count)
	box.line("지금 보이는 수준 %s" % GateDisclosure.label(level), BaseWidgets.INK_MARK)
	box.line("정보실에 남은 인원이 이 수준을 정한다", BaseWidgets.INK_DIM)
	return box


func _gate_box(
	gate: Gate, index: int, level: GateDisclosure.Level, selected: int, locked: bool
) -> BaseBox:
	var is_selected := index == selected
	var box := BaseBox.new("", is_selected)

	var head := BaseWidgets.row()
	var pick := BaseWidgets.button("고른 문" if is_selected else "고른다", not locked and not is_selected)
	pick.pressed.connect(_on_gate_pressed.bind(index))
	head.add_child(pick)
	var name_label := BaseWidgets.label(
		gate.display_name,
		BaseWidgets.SIZE_HEAD,
		BaseWidgets.INK_MARK if is_selected else BaseWidgets.INK
	)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	box.body.add_child(head)

	box.line("      ".join(gate.preview_lines(level)))
	return box


func _on_gate_pressed(index: int) -> void:
	gate_selected.emit(index)
