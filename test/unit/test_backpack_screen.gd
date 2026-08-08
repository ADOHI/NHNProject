extends GutTest
## 백팩 확인 화면의 **배선** 테스트.
##
## `docs/design/28-combat.md` §28.20.9.
##
## 화면은 규칙을 갖지 않는다. 규칙은 전부 `src/core/combat/` 에 있고 그쪽에
## 테스트가 따로 있다. 여기서 볼 것은 하나다 — **배치를 만지면 화면의 글자가
## 그 자리에서 따라오는가.**
##
## 헤드리스 테스트를 통과하고도 화면에서 터진 전례가 있어(CLAUDE.md) 씬을 실제로 띄운다.

const ScreenScene := preload("res://src/ui/backpack/backpack_screen.tscn")

var _screen: Control
var _board: BackpackBoard
var _chain_label: Label


func before_each() -> void:
	_screen = ScreenScene.instantiate()
	add_child_autofree(_screen)
	_board = _screen.get_node("%Board")
	_chain_label = _screen.get_node("%ChainLabel")


func _grid() -> BackpackGrid:
	return _screen._grid


# ---------------------------------------------------------------- 세워지는가


func test_screen_opens_with_the_sample_backpack() -> void:
	assert_not_null(_board)
	assert_eq(_grid().width, SampleBackpack.GRID_WIDTH)
	assert_eq(
		_grid().placements().size(), SampleBackpack.default_layout().size(), "표본 배치가 그대로 서 있어야 한다"
	)
	assert_false(_board.tray_items().is_empty(), "대기줄에 만져 볼 것이 남아 있어야 한다")


func test_help_text_names_every_key_it_listens_for() -> void:
	# 조작 키를 화면에 적어 놓고 실제로는 안 듣는 일이 없게 한다.
	var help: Label = _screen.get_node("%HelpLabel")
	for token in ["오른쪽 클릭", "R", "C", "Space"]:
		assert_true(help.text.contains(token), "조작 안내에 %s 가 없다" % token)


# ---------------------------------------------------------------- 배선


func test_chain_panel_lists_the_sample_chain_in_order() -> void:
	var text := _chain_label.text
	assert_true(text.contains("단검"), "시작 아이템이 적혀야 한다")
	assert_true(text.contains("원석"), "마지막 아이템이 적혀야 한다")
	assert_true(text.contains("완주"), "표본은 전리품에 닿아 완주한다")
	assert_true(text.find("단검") < text.find("철퇴"), "글자 목록이 발동 순서대로여야 한다")


func test_moving_an_item_rewrites_the_panel_immediately() -> void:
	# **이 화면의 존재 이유다** — 배치를 바꾸면 체인이 바뀌는 것이 즉시 보여야 한다.
	var before := _chain_label.text
	assert_true(before.contains("철퇴"))

	var mace := _grid().placement_at(SampleBackpack.default_layout()["mace"])
	assert_not_null(mace, "표본에 철퇴가 놓여 있어야 한다")
	assert_true(_grid().move(mace, Vector2i(4, 4)), "빈 자리로 옮긴다")
	_screen._refresh()

	var after := _chain_label.text
	assert_ne(after, before, "배치가 바뀌었는데 글자가 그대로면 배선이 끊긴 것이다")
	assert_false(after.contains("철퇴"), "체인에서 빠진 아이템은 목록에도 없어야 한다")
	assert_true(after.contains("끊김"), "루트가 끊겼다고 말해야 한다")


func test_emptying_the_start_node_says_so() -> void:
	var dagger := _grid().placement_at(Vector2i(0, 0))
	_grid().remove(dagger)
	_screen._refresh()
	assert_true(_chain_label.text.contains("시작 노드에 아이템을 놓아라"), "시작 노드가 비면 그렇게 말해야 한다")


func test_board_signal_drives_the_refresh() -> void:
	# 화면이 직접 부르는 것 말고 판이 알리는 길도 살아 있어야 한다.
	var dagger := _grid().placement_at(Vector2i(0, 0))
	_grid().remove(dagger)
	_board.layout_changed.emit()
	assert_true(_chain_label.text.contains("비어 있다"))


func test_every_start_node_gets_its_own_block_of_text() -> void:
	assert_eq(_chain_label.text.count("체인 "), _grid().start_nodes.size(), "시작 노드마다 한 덩어리씩 적힌다")
