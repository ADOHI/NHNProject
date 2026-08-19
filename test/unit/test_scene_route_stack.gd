extends GutTest
## 되돌아갈 곳과 넘기는 값. **노드가 아니라 여기가 규칙을 든다.**

const TITLE := SceneRoutes.Screen.TITLE
const BASE := SceneRoutes.Screen.BASE
const DUNGEON := SceneRoutes.Screen.DUNGEON
const HIDEOUT := SceneRoutes.Screen.HIDEOUT

var _stack: SceneRouteStack


func before_each() -> void:
	_stack = SceneRouteStack.new()


func test_a_fresh_stack_has_been_nowhere() -> void:
	assert_eq(_stack.current(), -1)
	assert_eq(_stack.previous(), -1)
	assert_eq(_stack.depth(), 0)
	assert_false(_stack.can_go_back())


func test_screens_stack_one_by_one() -> void:
	assert_true(_stack.push(TITLE))
	assert_true(_stack.push(BASE))
	assert_eq(_stack.current(), int(BASE))
	assert_eq(_stack.previous(), int(TITLE))
	assert_eq(_stack.depth(), 2)
	assert_true(_stack.can_go_back())


func test_an_unknown_screen_is_refused() -> void:
	assert_false(_stack.push(-1))
	assert_false(_stack.push(SceneRoutes.count()))
	assert_eq(_stack.depth(), 0)


func test_going_back_yields_the_previous_screen() -> void:
	_stack.push(TITLE)
	_stack.push(BASE)
	assert_eq(_stack.pop(), int(TITLE))
	assert_eq(_stack.current(), int(TITLE))
	assert_eq(_stack.depth(), 1)


func test_going_back_from_the_root_changes_nothing() -> void:
	_stack.push(TITLE)
	assert_eq(_stack.pop(), -1)
	assert_eq(_stack.current(), int(TITLE))
	assert_eq(_stack.depth(), 1)


func test_revisiting_a_screen_unwinds_instead_of_stacking() -> void:
	# 던전에서 주둔지로 가는 것은 더 깊이 들어가는 것이 아니라 돌아오는 것이다.
	_stack.push(TITLE)
	_stack.push(BASE)
	_stack.push(DUNGEON)
	_stack.push(BASE)
	assert_eq(_stack.depth(), 2)
	assert_eq(_stack.current(), int(BASE))
	assert_eq(_stack.previous(), int(TITLE))


func test_asking_for_the_current_screen_does_not_grow_the_stack() -> void:
	_stack.push(BASE)
	_stack.push(BASE)
	assert_eq(_stack.depth(), 1)


func test_depth_never_exceeds_the_screen_count() -> void:
	# 되감기의 덤이다 — 같은 화면이 두 번 들어가지 않는다.
	for _round in 4:
		for screen in SceneRoutes.all():
			_stack.push(screen)
	assert_lte(_stack.depth(), SceneRoutes.count())


func test_the_payload_is_handed_over_only_once() -> void:
	_stack.push(DUNGEON, {"dungeon_seed": 77})
	var first := _stack.take_payload()
	assert_eq(int(first["dungeon_seed"]), 77)
	assert_true(_stack.take_payload().is_empty(), "두 번째에도 값이 나오면 다음 화면이 지난 값을 먹는다")


func test_the_payload_is_copied_not_shared() -> void:
	var payload := {"dungeon_seed": 1}
	_stack.push(DUNGEON, payload)
	payload["dungeon_seed"] = 2
	assert_eq(int(_stack.take_payload()["dungeon_seed"]), 1)


func test_going_back_restores_the_payload_that_screen_had() -> void:
	_stack.push(BASE, {"note": "아지트"})
	_stack.take_payload()
	_stack.push(DUNGEON, {"dungeon_seed": 5})
	_stack.take_payload()
	assert_eq(_stack.pop(), int(BASE))
	assert_eq(String(_stack.take_payload()["note"]), "아지트")


func test_peeking_does_not_consume_the_payload() -> void:
	_stack.push(HIDEOUT, {"a": 1})
	assert_eq(int(_stack.peek_payload()["a"]), 1)
	assert_eq(int(_stack.take_payload()["a"]), 1)


func test_the_trail_can_be_read() -> void:
	_stack.push(TITLE)
	_stack.push(BASE)
	assert_eq(_stack.history(), [int(TITLE), int(BASE)] as Array[int])


func test_clearing_returns_to_the_start() -> void:
	_stack.push(TITLE)
	_stack.push(BASE, {"a": 1})
	_stack.clear()
	assert_eq(_stack.depth(), 0)
	assert_eq(_stack.current(), -1)
	assert_true(_stack.take_payload().is_empty())
