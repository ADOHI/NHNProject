extends GutTest
## 라우터의 얇은 층. **`go_to()` 는 여기서 부르지 않는다** —
## `change_scene_to_file()` 이 지금 떠 있는 씬(= GUT 러너)을 갈아 끼우기 때문이다.
##
## 그래서 여기서는 **갈아 끼우지 않는 부분**만 본다. 실제 전환은
## `tools/capture_flow.gd` 가 창을 띄워 눌러 돌며 덮는다
## (docs/design/34-systems.md §34.6).

var _router: SceneRouter


func before_each() -> void:
	_router = SceneRouter.new()
	add_child_autofree(_router)


func test_every_screen_resolves_to_a_destination() -> void:
	for screen in SceneRoutes.all():
		assert_ne(_router.resolve(screen), "", "%s 로 갈 수 없다" % SceneRoutes.label(screen))


func test_an_unknown_screen_resolves_to_nothing() -> void:
	assert_eq(_router.resolve(-1), "")
	assert_eq(_router.resolve(SceneRoutes.count()), "")


func test_a_fresh_router_has_nowhere_to_go_back_to() -> void:
	assert_eq(_router.current(), -1)
	assert_false(_router.can_go_back())
	assert_eq(_router.trail(), "")


func test_forgetting_clears_the_trail() -> void:
	_router.forget()
	assert_eq(_router.history(), [] as Array[int])


func test_no_payload_yields_an_empty_dictionary() -> void:
	assert_true(_router.take_payload().is_empty())
