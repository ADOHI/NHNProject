extends GutTest
## 인물 상세의 **탭 셋**을 덮는다. docs/design/20-ui-kit.md §20.25.4.
##
## ## 여기서 지켜야 할 것
##
## 1. **처음 서는 탭이 「조우」다** — 3초 안에 읽을 것이 먼저 서야 한다 (§20.25.2)
## 2. **탭도 클릭으로 된다** ([`04`](../../docs/design/04-controls.md) §4.1).
##    손은 이미 있는 `tap()` 하나다
## 3. **빈 탭이 없다** — 빈 탭은 고장으로 읽힌다
## 4. **육각형은 조우에만 선다.** 같은 「성향」 칸이 조우에서는 모양, 수치에서는 숫자다.
##    그것이 §5.4 의 *"단서는 보이지만 확신은 못 한다"* 를 탭 하나로 만드는 방법이다
## 5. **캡처 대본이 진짜 자리를 겨눈다** — 창 없이 잰다

const _SCREEN := preload("res://src/ui/npc_sheet/npc_sheet_screen.tscn")

const _WAIT := 400

var _screen: NpcSheetScreen


func before_each() -> void:
	_screen = _SCREEN.instantiate()
	add_child_autofree(_screen)


func _ready_screen() -> bool:
	for _i in _WAIT:
		if _screen.is_ready():
			return true
		await wait_process_frames(1)
	return _screen.is_ready()


func _view() -> PersonSheetView:
	return _screen.get_node("%SheetView") as PersonSheetView


## 캡처 도구를 **상수째로 읽는다.** 대본을 여기에 베껴 두면 한쪽만 고쳐진다.
func _hand_script() -> Array:
	var capture: GDScript = load("res://tools/capture_npc_sheet.gd")
	return capture.get_script_constant_map()["_HAND"]


# --------------------------------------------------------- 탭이 나뉘어 있나


func test_every_section_lands_in_some_tab() -> void:
	# 탭 어디에도 안 실린 칸은 **만들어 놓고 아무도 못 보는 칸**이다.
	var registry := PersonGenerator.new(20260808, 60).generate()
	var sections := PersonSheet.build(registry, 0, FactionIndex.new(registry))
	var placed: Array[String] = []
	for tab in SheetTab.count():
		var kind := tab as SheetTab.Kind
		for title in PersonSheet.left_titles(kind) + PersonSheet.right_titles(kind):
			if not placed.has(str(title)):
				placed.append(str(title))
	for section in sections:
		assert_true(placed.has(section.title), "%s 가 어느 탭에도 안 실렸다" % section.title)


func test_no_tab_repeats_a_section_in_both_columns() -> void:
	for tab in SheetTab.count():
		var kind := tab as SheetTab.Kind
		for title in PersonSheet.left_titles(kind):
			assert_false(
				PersonSheet.right_titles(kind).has(title), "%s 가 한 탭의 두 열에 다 있다" % str(title)
			)


func test_only_the_numbers_tab_is_dev_only() -> void:
	# 가림의 단위가 탭이다 (§24.17.2 · §20.25.4). 잠글 것이 하나여야 실수가 하나다.
	var locked := 0
	for tab in SheetTab.count():
		if SheetTab.is_dev_only(tab as SheetTab.Kind):
			locked += 1
	assert_eq(locked, 1, "잠그는 탭이 하나가 아니면 잊을 자리가 늘어난다")


# ------------------------------------------------------------- 눌러서 도나


func test_the_encounter_tab_is_the_one_that_opens() -> void:
	assert_true(await _ready_screen(), "인구가 안 만들어졌다")
	assert_eq(_screen.tab(), SheetTab.Kind.ENCOUNTER)


func test_clicking_a_tab_switches_it() -> void:
	assert_true(await _ready_screen(), "인구가 안 만들어졌다")
	var tabs := _view().layout().tabs
	assert_eq(tabs.size(), SheetTab.count(), "탭 띠가 안 섰다")
	_screen.tap(tabs[int(SheetTab.Kind.HISTORY)].get_center() + _view().position)
	assert_eq(_screen.tab(), SheetTab.Kind.HISTORY, "탭을 눌렀는데 안 바뀐다")


func test_every_tab_stands_something_up() -> void:
	assert_true(await _ready_screen(), "인구가 안 만들어졌다")
	for tab in SheetTab.count():
		var kind := tab as SheetTab.Kind
		_screen.show_tab(kind)
		assert_true(_view().layout().panels.size() > 0, "%s 탭이 비었다" % SheetTab.label(kind))


func test_tabs_never_overlap_the_panels() -> void:
	# 탭 띠 위에 칸이 겹치면 **탭이 안 눌리는 자리**가 생긴다.
	assert_true(await _ready_screen(), "인구가 안 만들어졌다")
	for tab in SheetTab.count():
		_screen.show_tab(tab as SheetTab.Kind)
		var placed := _view().layout()
		for strip in placed.tabs:
			for panel in placed.panels:
				assert_false(strip.intersects(panel), "탭 띠와 칸이 겹쳤다")


# ------------------------------------------------------------- 육각형의 자리


func test_the_wheel_stands_only_in_the_encounter_tab() -> void:
	assert_true(await _ready_screen(), "인구가 안 만들어졌다")
	_screen.show_tab(SheetTab.Kind.ENCOUNTER)
	assert_eq(_view().layout().wheels.size(), 1, "조우 탭에 육각형이 없다")
	_screen.show_tab(SheetTab.Kind.NUMBERS)
	assert_eq(_view().layout().wheels.size(), 0, "수치 탭이 숫자가 아니라 육각형을 냈다")


func test_the_wheel_panel_has_no_rows_to_click() -> void:
	# 육각형은 통째로 그림이다. 낱줄이 있으면 **눌러 봤자 아무 일도 안 나는 자리**가 생긴다.
	assert_true(await _ready_screen(), "인구가 안 만들어졌다")
	_screen.show_tab(SheetTab.Kind.ENCOUNTER)
	var placed := _view().layout()
	for i in placed.rows.size():
		assert_false(placed.is_wheel(placed.row_section[i]), "육각형 칸이 줄을 냈다")


# --------------------------------------------------- 캡처 대본을 검사가 읽는다


func test_the_capture_script_names_only_real_gestures() -> void:
	# 손짓 이름을 오타 내면 `match` 가 조용히 아무것도 안 하고 **같은 그림이 여러 장** 나온다.
	var known := ["", "hover", "tap", "inspect", "wheel", "tab"]
	for step in _hand_script():
		assert_true(known.has(str(step[1])), "%s 가 모르는 손짓이다" % str(step[1]))


func test_the_capture_script_names_real_tabs() -> void:
	for step in _hand_script():
		if str(step[1]) != "tab":
			continue
		var index := int(step[3])
		assert_true(index >= 0 and index < SheetTab.count(), "%s 가 없는 탭이다" % str(step[0]))


func test_the_capture_script_visits_every_tab() -> void:
	# 탭 셋을 만들어 놓고 **한 탭만 찍으면** 나머지 둘은 판정을 못 받는다.
	var seen: Array[int] = [int(SheetTab.Kind.ENCOUNTER)]
	for step in _hand_script():
		if str(step[1]) == "tab" and not seen.has(int(step[3])):
			seen.append(int(step[3]))
	assert_eq(seen.size(), SheetTab.count(), "대본이 안 들르는 탭이 있다")


func test_the_capture_script_aims_at_real_rows() -> void:
	# **대본이 좌표를 안 박는 대신 칸 이름으로 겨눈다.** 칸 이름이 바뀌면 겨눌 데가
	# 없어지는데, 그래도 그림은 나온다 — 그래서 창 없이 여기서 먼저 깨져야 한다.
	assert_true(await _ready_screen(), "인구가 안 만들어졌다")
	var tab := SheetTab.Kind.ENCOUNTER
	for step in _hand_script():
		if str(step[1]) == "tab":
			tab = int(step[3]) as SheetTab.Kind
			_screen.show_tab(tab)
			continue
		var title := str(step[2])
		if title.is_empty():
			continue
		var field := int(step[3])
		if field < 0:
			_seek_kin()
			assert_ne(_screen.linked_point(), NpcSheetScreen.NOWHERE, str(step[0]))
			continue
		assert_ne(_screen.point_of(title, field), NpcSheetScreen.NOWHERE, str(step[0]))


func _seek_kin() -> void:
	for person in 300:
		_screen.show_person(person)
		if _screen.linked_point() != NpcSheetScreen.NOWHERE:
			return
