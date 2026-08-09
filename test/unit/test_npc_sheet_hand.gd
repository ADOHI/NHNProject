extends GutTest
## 인물 상세 화면의 **손**을 덮는다. docs/design/20-ui-kit.md §20.23.
##
## ## 왜 이 파일이 있나
##
## §20.22 가 이름 붙인 **「대역이 낀 검사」** 때문이다 — 캡처 도구가 사적 함수를 직접
## 부르는 동안에는 **손이 안 붙어 있어도 그림이 나온다.** 이 화면이 정확히 그랬다:
## §4.1 이 *「클릭(터치)만으로 전부 조작 가능해야 한다」* 인데 **키보드 전용**이었고,
## 캡처는 통과했다.
##
## 그래서 이 파일은 **사람이 만지는 것과 같은 문으로 들어간다** —
## 진짜 `Button` 을 누르고, `wheel` · `tap` · `inspect` 를 부른다.
## 이 문이 막히면 여기가 먼저 깨진다. 그게 검사가 할 일이다.
##
## ## 지켜야 할 것
##
## 1. **조작 여덟이 전부 버튼으로 있다.** 하나라도 키에만 있으면 §4.1 위반이다
## 2. **버튼과 키가 같은 것을 한다.** 표가 하나라 어긋날 수 없어야 한다
## 3. **관계 줄을 누르면 그 사람으로 간다**
## 4. **빈칸에서도 정보 확인이 할 말이 있다** (§24.17.4)

const _SCREEN := preload("res://src/ui/npc_sheet/npc_sheet_screen.tscn")

## 인구 3000명과 가족 심기가 끝나기를 기다리는 최대 프레임.
const _WAIT := 400

## 길게 누르기가 일어나기를 기다리는 프레임. 0.5초를 넉넉히 넘긴다.
const _HOLD_FRAMES := 120

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


func _buttons() -> Array[Button]:
	var out: Array[Button] = []
	for child in _screen.find_children("*", "Button", true, false):
		out.append(child as Button)
	return out


func _press(text: String) -> bool:
	for button in _buttons():
		if button.text == text:
			button.pressed.emit()
			return true
	return false


# ------------------------------------------------- 조작 여덟이 전부 눌리는가


func test_every_action_has_a_button() -> void:
	# §4.1 — 클릭만으로 전부 조작 가능해야 한다. **키에만 있는 조작이 하나도 없어야 한다.**
	var texts: Array[String] = []
	for button in _buttons():
		texts.append(button.text)
	for action in NpcSheetScreen.ACTIONS:
		assert_true(texts.has(str(action[1])), "%s 에 버튼이 없다" % str(action[0]))


func test_every_action_also_has_a_key() -> void:
	# 키보드는 보조지만 **표가 하나라** 빠질 수가 없어야 한다.
	for action in NpcSheetScreen.ACTIONS:
		assert_true(int(action[2]) != 0, "%s 에 키가 없다" % str(action[0]))


func test_action_ids_are_unique() -> void:
	var seen: Array[String] = []
	for action in NpcSheetScreen.ACTIONS:
		assert_false(seen.has(str(action[0])), "%s 가 두 번 있다" % str(action[0]))
		seen.append(str(action[0]))


# ------------------------------------------------------------ 눌러서 도는가


func test_next_button_moves_one_person() -> void:
	assert_true(await _ready_screen(), "인구가 안 만들어졌다")
	var before := _screen.person()
	assert_true(_press("다음"), "다음 버튼이 없다")
	assert_eq(_screen.person(), before + 1)


func test_previous_button_wraps_at_the_start() -> void:
	assert_true(await _ready_screen(), "인구가 안 만들어졌다")
	_screen.act("home")
	assert_true(_press("이전"), "이전 버튼이 없다")
	assert_eq(_screen.person(), _screen.registry().size() - 1, "처음에서 뒤로 가면 끝으로 감긴다")


func test_page_buttons_jump_by_a_hundred() -> void:
	assert_true(await _ready_screen(), "인구가 안 만들어졌다")
	_screen.act("home")
	assert_true(_press("+100"), "+100 버튼이 없다")
	assert_eq(_screen.person(), NpcSheetScreen.PAGE)


func test_random_button_does_not_stay_put() -> void:
	# §24.17.8 — 주 조작이 무작위 뽑기다. 인덱스 순으로 훑으면 앞의 스무 명만 보고 판정한다.
	assert_true(await _ready_screen(), "인구가 안 만들어졌다")
	_screen.act("home")
	var moved := false
	for _i in 8:
		assert_true(_press("무작위"), "무작위 버튼이 없다")
		if _screen.person() != 0:
			moved = true
			break
	assert_true(moved, "무작위가 여덟 번을 0 번에 머물렀다")


func test_reseed_button_rebuilds_the_population() -> void:
	assert_true(await _ready_screen(), "인구가 안 만들어졌다")
	assert_true(_press("새 시드"), "새 시드 버튼이 없다")
	assert_false(_screen.is_ready(), "새 시드를 눌렀는데 인구가 그대로다")
	assert_true(await _ready_screen(), "새 인구가 안 만들어졌다")


# ---------------------------------------------------------------- 휠과 클릭


func test_wheel_moves_one_person_each_way() -> void:
	assert_true(await _ready_screen(), "인구가 안 만들어졌다")
	_screen.act("home")
	_screen.wheel(-1)
	assert_eq(_screen.person(), 1, "휠을 내리면 다음 사람이다")
	_screen.wheel(1)
	assert_eq(_screen.person(), 0, "휠을 올리면 앞 사람이다")


func _first_linked_row() -> Vector2:
	# 관계 줄이 있는 사람을 찾는다. 그 줄의 한복판이 **눌러야 할 자리**다.
	var view: PersonSheetView = _screen.get_node("%SheetView")
	for person in 300:
		_screen.show_person(person)
		var placed := view.layout()
		for i in placed.rows.size():
			var field := view.sections()[placed.row_section[i]].fields[placed.row_field[i]]
			if field.has_link():
				return placed.rows[i].get_center() + view.position
	return Vector2.ZERO


func test_tapping_a_kin_row_goes_to_that_person() -> void:
	assert_true(await _ready_screen(), "인구가 안 만들어졌다")
	var where := _first_linked_row()
	assert_ne(where, Vector2.ZERO, "300명 안에 가족이 있는 사람이 하나도 없다")

	var view: PersonSheetView = _screen.get_node("%SheetView")
	var at := view.layout().field_at(where - view.position)
	var target := view.sections()[at.x].fields[at.y].link
	_screen.tap(where)
	assert_eq(_screen.person(), target, "누른 줄이 가리키는 사람으로 안 갔다")


func test_tapping_empty_space_changes_nothing() -> void:
	assert_true(await _ready_screen(), "인구가 안 만들어졌다")
	_screen.act("home")
	_screen.tap(Vector2(-50.0, -50.0))
	assert_eq(_screen.person(), 0, "빈 데를 눌렀는데 사람이 바뀌었다")


# ------------------------------------------------------------- 정보 확인


func test_inspect_on_a_row_says_something() -> void:
	# §4.2 우클릭 · 롱프레스. **프로토에만 있고 실제 화면에 없던 조작이다**(§20.22.4).
	assert_true(await _ready_screen(), "인구가 안 만들어졌다")
	var view: PersonSheetView = _screen.get_node("%SheetView")
	_screen.act("home")
	var placed := view.layout()
	assert_true(placed.rows.size() > 0, "줄이 하나도 안 놓였다")
	for i in placed.rows.size():
		_screen.inspect(placed.rows[i].get_center() + view.position)
		assert_false(view.note().is_empty(), "줄 %d 에서 할 말이 없다" % i)


func test_inspect_outside_says_nothing() -> void:
	assert_true(await _ready_screen(), "인구가 안 만들어졌다")
	var view: PersonSheetView = _screen.get_node("%SheetView")
	_screen.inspect(Vector2(-40.0, -40.0))
	assert_true(view.note().is_empty(), "화면 밖을 눌렀는데 쪽지가 떴다")


func _click(button: int, where: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button as MouseButton
	event.position = where
	event.pressed = pressed
	return event


func _row_point() -> Vector2:
	var view: PersonSheetView = _screen.get_node("%SheetView")
	return view.layout().rows[0].get_center() + view.position


func test_right_click_opens_information() -> void:
	assert_true(await _ready_screen(), "인구가 안 만들어졌다")
	var view: PersonSheetView = _screen.get_node("%SheetView")
	_screen.act("home")
	# 엔진이 부르는 것과 **같은 함수**로 들어간다. 손짓 전용 입구를 따로 두면
	# 진짜 마우스가 끊겨도 검사가 통과한다 — 그게 §20.22 의 병이다.
	_screen._gui_input(_click(MOUSE_BUTTON_RIGHT, _row_point(), true))
	assert_false(view.note().is_empty(), "우클릭이 정보를 안 띄운다")


func test_long_press_opens_the_same_information() -> void:
	# **터치에는 오른쪽 버튼이 없다** — §4.2 가 둘을 한 줄에 적은 이유다.
	assert_true(await _ready_screen(), "인구가 안 만들어졌다")
	var view: PersonSheetView = _screen.get_node("%SheetView")
	_screen.act("home")
	var where := _row_point()

	_screen._gui_input(_click(MOUSE_BUTTON_RIGHT, where, true))
	var by_right := view.note()

	view.show_note(Vector2.ZERO, "")
	_screen._gui_input(_click(MOUSE_BUTTON_LEFT, where, true))
	var frames := 0
	while frames < _HOLD_FRAMES and view.note().is_empty():
		await wait_process_frames(1)
		frames += 1
	assert_eq(view.note(), by_right, "길게 눌러도 우클릭과 같은 것이 나와야 한다")


func test_dragging_cancels_the_long_press() -> void:
	# 안 그러면 **끌기가 전부 정보 확인이 된다.**
	assert_true(await _ready_screen(), "인구가 안 만들어졌다")
	var view: PersonSheetView = _screen.get_node("%SheetView")
	_screen.act("home")
	var where := _row_point()
	_screen._gui_input(_click(MOUSE_BUTTON_LEFT, where, true))
	var moved := InputEventMouseMotion.new()
	moved.position = where + Vector2(NpcSheetScreen.LONG_PRESS_SLACK * 3.0, 0.0)
	_screen._gui_input(moved)
	await wait_process_frames(_HOLD_FRAMES)
	assert_true(view.note().is_empty(), "끌었는데 정보가 떴다")
