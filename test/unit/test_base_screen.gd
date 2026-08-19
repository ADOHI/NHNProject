extends GutTest
## 아지트 화면의 배선 테스트.
##
## **화면은 규칙을 갖지 않으므로 여기서 볼 것은 규칙이 아니라 배선이다** —
## 버튼이 코어에 닿는가, 코어가 바뀐 것이 화면에 돌아오는가.
##
## 헤드리스 테스트를 통과하고도 화면에서 파싱 에러로 터진 전례가 있어(CLAUDE.md),
## 이 파일은 씬을 실제로 띄우고 **실제 버튼을 눌러서** 한 바퀴를 돌린다.

const BaseScreenScene := preload("res://src/ui/base/base_screen.tscn")

## **시험 전용 세이브 자리.** 진짜 세이브를 읽으면 그 파일의 내용에 따라
## 초록과 빨강이 갈린다 — 기계마다 다른 결과가 나오는 시험은 시험이 아니다.
const SAVE_PATH := "user://test_save/base_screen_test.json"

var _screen: BaseScreen


func before_each() -> void:
	_erase_save()
	_screen = _open()


func after_each() -> void:
	_erase_save()


## 화면 하나를 연다. **`add_child()` 전에 저장 자리를 정한다** — `_ready()` 가 그때 돈다.
func _open() -> BaseScreen:
	var screen: BaseScreen = BaseScreenScene.instantiate()
	screen.save_path = SAVE_PATH
	add_child_autofree(screen)
	return screen


func _erase_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


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

	# 0 번 대원은 민첩 1 이라 이 게이트에 못 들어간다 (Gate.can_enter). 한 바퀴를 재는 자라 통과하는 편성으로 간다
	_press_member(1, "데려간다")
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
	# 0 번 대원은 민첩 1 이라 이 게이트에 못 들어간다 (Gate.can_enter). 한 바퀴를 재는 자라 통과하는 편성으로 간다
	_press_member(1, "데려간다")

	var funds := _screen._guild.funds
	# 이름은 무작위라 우연히 겹칠 수 있다. 목록이 갈렸다는 증거는 씨앗이다.
	var seed_before: int = _screen._gates[0].dungeon_seed

	assert_true(_press_inside(_screen, "들어간다"))
	assert_eq(int(_screen._expedition.stage), int(Expedition.Stage.DEPLOYED))
	assert_true(_press_first_move(), "갈 수 있는 방이 버튼으로 떠 있다")
	assert_true(_screen._expedition.run.turn > 1, "방을 누르면 턴이 오른다")

	assert_true(_press_inside(_screen, "탈출 성공"))
	assert_eq(int(_screen._expedition.stage), int(Expedition.Stage.RETURNED))

	var lines := _screen._log.size()
	assert_true(_press_inside(_screen, "정산한다"))
	assert_true(_screen._guild.funds > funds, "갔다 오니 자금이 늘어 있다")
	# 정산 한 줄 + 저장 한 줄. 저장은 정산 뒤 이 한 자리에서만 돈다 (설계 34.4.5).
	assert_eq(_screen._log.size(), lines + 2, "정산과 저장이 각각 한 줄씩 쌓인다")

	assert_true(_press_inside(_screen, "다음 원정"))
	assert_null(_screen._expedition)
	assert_true(_screen._deployed.is_empty())
	assert_ne(_screen._gates[0].dungeon_seed, seed_before, "다녀오면 열린 문이 갈린다")


func test_cannot_enter_without_choosing_anyone() -> void:
	assert_false(_press_inside(_screen, "들어간다"), "아무도 안 고르면 잠겨 있다")
	assert_null(_screen._expedition)


# ---------------------------------------------------------------- 진행이 남는가


func test_a_fresh_screen_says_there_was_nothing_to_load() -> void:
	# 조용히 새로 시작하면 사용자는 자기 진행이 어디로 갔는지 모른다 (설계 34.4.4).
	assert_eq(_screen._log.size(), 1)
	assert_string_contains(_screen._log[0], "새로 시작")


func test_settling_writes_a_save_that_comes_back() -> void:
	_press_member(2, "공방")
	assert_true(_press_gate(1, "고른다"))
	_press_member(1, "데려간다")
	assert_true(_press_inside(_screen, "들어간다"))
	assert_true(_press_inside(_screen, "탈출 성공"))
	assert_true(_press_inside(_screen, "정산한다"))

	var loaded := SaveStore.new(SAVE_PATH).read(false)
	assert_true(loaded.is_ok(), loaded.message())
	assert_eq(loaded.guild.funds, _screen._guild.funds)
	assert_eq(loaded.guild.expeditions_settled, _screen._guild.expeditions_settled)


func test_a_saved_guild_is_picked_up_on_open() -> void:
	_screen._guild.add_funds(4321)
	_screen._guild.display_name = "이어받은 길드"
	assert_eq(SaveStore.new(SAVE_PATH).write(_screen._guild, _screen._campaign_seed), OK)

	var again := _open()
	assert_eq(again._guild.display_name, "이어받은 길드")
	assert_eq(again._guild.funds, _screen._guild.funds)
	assert_string_contains(again._log[0], "이어서 한다")


func test_a_broken_save_starts_a_new_game_and_says_why() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_PATH.get_base_dir()))
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("이건 세이브가 아니다 {{{")
	file.close()

	var again := _open()
	assert_not_null(again._guild, "깨진 세이브가 게임을 죽이면 안 된다")
	assert_false(again._guild.members.is_empty())
	assert_string_contains(again._log[0], "깨졌다")
	assert_true(FileAccess.file_exists(SAVE_PATH), "깨진 파일을 지우지 않는다")
