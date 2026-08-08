extends GutTest
## 아지트 화면의 배선 테스트.
##
## **화면은 규칙을 갖지 않으므로 여기서 볼 것은 규칙이 아니라 배선이다** —
## 버튼이 코어에 닿는가, 코어가 바뀐 것이 화면에 돌아오는가.
##
## 헤드리스 테스트를 통과하고도 화면에서 파싱 에러로 터진 전례가 있어(CLAUDE.md),
## 이 파일은 씬을 실제로 띄우고 **실제 버튼을 눌러서** 한 바퀴를 돌린다.

const BaseScreenScene := preload("res://src/ui/base/base_screen.tscn")

var _screen: BaseScreen


func before_each() -> void:
	_screen = BaseScreenScene.instantiate()
	add_child_autofree(_screen)


# ---------------------------------------------------------------- 눌러 주는 손


func _press_inside(node: Node, text: String) -> bool:
	for child in node.find_children("*", "Button", true, false):
		var button := child as Button
		if button.text == text and not button.disabled:
			button.pressed.emit()
			return true
	return false


func _panel(class_text: String) -> Node:
	var found := _screen.find_children("*", class_text, true, false)
	return null if found.is_empty() else found[0]


func _press_member(index: int, text: String) -> bool:
	var panel := _panel("BaseMemberPanel")
	return _press_inside(panel.get_child(index), text)


func _press_gate(index: int, text: String) -> bool:
	var panel := _panel("BaseGatePanel")
	return _press_inside(panel.get_child(index + 1), text)


## 던전 안에서 갈 수 있는 첫 방. 방 이름은 판마다 달라 글자로 찾을 수 없다.
func _press_first_move() -> bool:
	var panel := _panel("BaseExpeditionPanel")
	for flow in panel.find_children("*", "HFlowContainer", true, false):
		for child in flow.get_children():
			if child is Button and not (child as Button).disabled:
				(child as Button).pressed.emit()
				return true
		return false
	return false


# ---------------------------------------------------------------- 뜨는가


func test_screen_builds_every_column() -> void:
	assert_not_null(_panel("BaseGuildPanel"))
	assert_not_null(_panel("BaseMemberPanel"))
	assert_not_null(_panel("BaseGatePanel"))
	assert_not_null(_panel("BaseExpeditionPanel"))


func test_board_shows_the_open_gates() -> void:
	assert_eq(_screen._gates.size(), GuildBalance.GATE_BOARD_SIZE)
	# 머리말 칸 하나 + 게이트 칸들.
	assert_eq(_panel("BaseGatePanel").get_child_count(), GuildBalance.GATE_BOARD_SIZE + 1)


func test_roster_shows_every_member_and_the_squad_summary() -> void:
	assert_eq(_panel("BaseMemberPanel").get_child_count(), _screen._guild.members.size() + 1)


# ---------------------------------------------------------------- 배치와 편성이 다툰다


func test_assigning_from_the_screen_reaches_the_guild() -> void:
	assert_true(_press_member(0, "공방"))
	assert_eq(
		_screen._guild.assignment.facility_of(_screen._guild.members[0].id),
		int(Facility.Kind.WORKSHOP)
	)


## 정보실 대원을 데려가기로 표시하면 **출발 전에** 이미 목록이 흐려진다.
func test_marking_the_intel_staff_dims_the_board_before_leaving() -> void:
	_press_member(0, "정보실")
	_press_member(1, "정보실")
	assert_eq(_screen._guild.gate_disclosure(_screen._deployed), GateDisclosure.Level.MAPPED)

	_press_member(0, "데려간다")
	assert_eq(
		_screen._guild.gate_disclosure(_screen._deployed),
		GateDisclosure.Level.SURVEYED,
		"데려갈 사람을 고른 순간 정보실이 빈다"
	)


func test_deploy_button_locks_at_capacity() -> void:
	for index in _screen._guild.squad_capacity():
		assert_true(_press_member(index, "데려간다"))
	assert_false(_press_member(_screen._guild.squad_capacity(), "데려간다"), "정원을 넘길 수 없다")


# ---------------------------------------------------------------- 한 바퀴


func test_full_lap_runs_on_the_screen() -> void:
	_press_member(2, "공방")
	_press_member(3, "접선처")
	assert_true(_press_gate(1, "고른다"))
	_press_member(0, "데려간다")

	var funds := _screen._guild.funds
	# 이름은 무작위라 우연히 겹칠 수 있다. 목록이 갈렸다는 증거는 씨앗이다.
	var seed_before: int = _screen._gates[0].dungeon_seed

	assert_true(_press_inside(_screen, "들어간다"))
	assert_eq(int(_screen._expedition.stage), int(Expedition.Stage.DEPLOYED))
	assert_true(_press_first_move(), "갈 수 있는 방이 버튼으로 떠 있다")
	assert_true(_screen._expedition.run.turn > 1, "방을 누르면 턴이 오른다")

	assert_true(_press_inside(_screen, "탈출 성공"))
	assert_eq(int(_screen._expedition.stage), int(Expedition.Stage.RETURNED))

	assert_true(_press_inside(_screen, "정산한다"))
	assert_true(_screen._guild.funds > funds, "갔다 오니 자금이 늘어 있다")
	assert_eq(_screen._log.size(), 1, "기록이 한 줄 쌓인다")

	assert_true(_press_inside(_screen, "다음 원정"))
	assert_null(_screen._expedition)
	assert_true(_screen._deployed.is_empty())
	assert_ne(_screen._gates[0].dungeon_seed, seed_before, "다녀오면 열린 문이 갈린다")


func test_cannot_enter_without_choosing_anyone() -> void:
	assert_false(_press_inside(_screen, "들어간다"), "아무도 안 고르면 잠겨 있다")
	assert_null(_screen._expedition)
