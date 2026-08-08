extends SceneTree
## 아지트 화면 한 바퀴를 실제로 눌러 돌리고 **한 번 띄운 김에 여러 장을 몰아 찍는다.**
##
##     godot --path . -s res://tools/capture_base_screen.gd
##
## 캡처마다 창을 새로 띄우면 GL 컨텍스트를 그때마다 새로 만들게 되고,
## 그것이 드라이버를 흔들어 세션이 끊긴 적이 있다 (CLAUDE.md — GPU 를 나눠 쓴다).
## 그래서 한 번 띄운 뒤 단계마다 화면을 떠서 .captures/ 에 남긴다.
##
## 상태를 직접 건드리지 않고 **실제 버튼을 누른다.** 그래야 화면의 배선까지 검증된다.

const _OUT_DIR := "res://.captures"

## 한 단계를 밟고 화면이 자리를 잡을 때까지 두는 프레임 수.
##
## 칸을 통째로 다시 만드는 화면이라 누른 프레임에 바로 찍으면 옛 배치가 찍힌다.
const _SETTLE_FRAMES := 4

var _screen: Control
var _step := 0
var _frames := 0
var _shot := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_OUT_DIR))
	_screen = load("res://src/ui/base/base_screen.tscn").instantiate()
	root.add_child(_screen)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < _SETTLE_FRAMES:
		return false
	_frames = 0
	var done := _run_step(_step)
	_step += 1
	return done


## 단계 하나. true 를 돌려주면 끝난다.
func _run_step(step: int) -> bool:
	match step:
		0:
			_save("01_start")
		1:
			_press_member(0, "정보실")
			_press_member(1, "정보실")
			_press_member(2, "공방")
			_press_member(3, "접선처")
		2:
			_save("02_assigned")
		3:
			_press_gate(1, "고른다")
			_press_member(0, "데려간다")
			_press_member(4, "데려간다")
		4:
			_save("03_deployed")
		5:
			_press_text("들어간다")
		6:
			_press_first_move()
		7:
			_press_first_move()
		8:
			_save("04_dungeon")
		9:
			_press_text("탈출 성공")
		10:
			_save("05_report")
		11:
			_press_text("정산한다")
		12:
			_save("06_settled")
		13:
			_press_text("다음 원정")
		14:
			_save("07_next_board")
			return true
	return false


func _save(name: String) -> void:
	_shot += 1
	var path := "%s/base_%s.png" % [_OUT_DIR, name]
	var error := root.get_texture().get_image().save_png(path)
	print("capture: %s (err=%d)" % [path, error])


# ---------------------------------------------------------------- 누르기


## 가운데 기둥의 대원 몇 번째 칸에서 이 글자가 붙은 버튼을 누른다.
##
## 같은 글자의 버튼이 대원마다 하나씩 있으므로 칸을 먼저 좁힌다.
func _press_member(index: int, text: String) -> void:
	var panel := _find_class("BaseMemberPanel")
	if panel == null or index >= panel.get_child_count():
		push_warning("대원 칸을 찾지 못했다: %d" % index)
		return
	_press_inside(panel.get_child(index), text)


## 오른쪽 기둥의 게이트 몇 번째 칸에서 버튼을 누른다. 첫 칸은 머리말이라 하나 밀린다.
func _press_gate(index: int, text: String) -> void:
	var panel := _find_class("BaseGatePanel")
	if panel == null or index + 1 >= panel.get_child_count():
		push_warning("게이트 칸을 찾지 못했다: %d" % index)
		return
	_press_inside(panel.get_child(index + 1), text)


## 화면 전체에서 이 글자의 버튼 하나를 누른다. 한 번에 하나뿐인 버튼에만 쓴다.
func _press_text(text: String) -> void:
	if not _press_inside(root, text):
		push_warning("버튼을 찾지 못했다: %s" % text)


## 던전 안에서 갈 수 있는 첫 방을 누른다. 방 이름은 판마다 달라 글자로 찾을 수 없다.
func _press_first_move() -> void:
	var panel := _find_class("BaseExpeditionPanel")
	if panel == null:
		return
	for flow in panel.find_children("*", "HFlowContainer", true, false):
		for child in flow.get_children():
			if child is Button and not (child as Button).disabled:
				(child as Button).pressed.emit()
				return
		return


func _press_inside(node: Node, text: String) -> bool:
	for child in node.find_children("*", "Button", true, false):
		var button := child as Button
		if button.text == text and not button.disabled:
			button.pressed.emit()
			return true
	return false


func _find_class(class_text: String) -> Node:
	var found := root.find_children("*", class_text, true, false)
	return null if found.is_empty() else found[0]
