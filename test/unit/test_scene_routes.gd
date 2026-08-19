extends GutTest
## 경로 장부. **여기서 잡아야 할 것은 「씬을 옮기고 장부를 안 고친 것」이다.**
##
## 그것은 실행해도 오류가 안 난다 — `change_scene_to_file` 이 경고 한 줄만 찍고
## 화면이 그냥 안 바뀐다. 그래서 장부의 경로가 실제로 사는지를 여기서 판정한다.


func test_every_screen_has_a_real_scene_file() -> void:
	for screen in SceneRoutes.all():
		var path := SceneRoutes.path_of(screen)
		assert_true(
			ResourceLoader.exists(path), "%s 의 씬이 없다: %s" % [SceneRoutes.label(screen), path]
		)


func test_every_route_loads_as_a_packed_scene() -> void:
	for screen in SceneRoutes.all():
		var scene: Resource = load(SceneRoutes.path_of(screen))
		assert_true(scene is PackedScene, "%s 가 씬이 아니다" % SceneRoutes.label(screen))


func test_the_table_and_the_labels_have_the_same_length() -> void:
	assert_eq(SceneRoutes.count(), SceneRoutes.all().size())
	for screen in SceneRoutes.all():
		assert_ne(SceneRoutes.label(screen), "모르는 화면")


func test_no_two_screens_share_a_path() -> void:
	var seen := {}
	for screen in SceneRoutes.all():
		var path := SceneRoutes.path_of(screen)
		assert_false(seen.has(path), "두 화면이 같은 경로다: %s" % path)
		seen[path] = true


func test_an_unknown_screen_has_no_path() -> void:
	assert_false(SceneRoutes.is_known(-1))
	assert_false(SceneRoutes.is_known(SceneRoutes.count()))
	assert_eq(SceneRoutes.path_of(-1), "")
	assert_eq(SceneRoutes.path_of(SceneRoutes.count()), "")
	assert_eq(SceneRoutes.label(999), "모르는 화면")


func test_a_path_maps_back_to_its_screen() -> void:
	for screen in SceneRoutes.all():
		assert_eq(SceneRoutes.screen_at(SceneRoutes.path_of(screen)), screen)
	assert_eq(SceneRoutes.screen_at("res://없는/화면.tscn"), -1)


func test_the_title_is_the_first_screen() -> void:
	# 부팅이 여기로 간다 (docs/design/08-ui-ux.md §8.1).
	assert_eq(int(SceneRoutes.Screen.TITLE), 0)
