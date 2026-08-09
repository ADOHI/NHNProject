extends GutTest
## 아지트 화면의 배선 테스트.
##
## **화면은 규칙을 갖지 않으므로 여기서 볼 것은 규칙이 아니라 배선이다.**
## 헤드리스 테스트를 통과하고도 화면에서 파싱 에러로 터진 전례가 있어(CLAUDE.md),
## 이 파일은 씬을 실제로 띄운다.
##
## 화면 캡처는 창을 요구하고, 창은 그림 생성과 GPU 를 다툰다(LANE-RULES §3).
## 그래서 **"화면이 서 있는가" 는 여기가 잡고, "어떻게 보이는가" 만 눈으로 본다**
## (docs/design/22-guild-base.md §22.8.6 이 같은 형태다).

const HideoutScreenScene := preload("res://src/ui/hideout/hideout_screen.tscn")

var _screen: HideoutScreen


func before_each() -> void:
	_screen = HideoutScreenScene.instantiate()
	add_child_autofree(_screen)


func test_screen_stands_up_with_a_board_and_a_projection() -> void:
	assert_not_null(_screen.grid())
	assert_not_null(_screen.projection())
	assert_eq(_screen.grid().cols, HideoutGrid.DEFAULT_COLS)


## 잠정 배치가 조용히 실패하면 판이 텅 빈 채로 서 있게 된다.
func test_starting_layout_actually_landed() -> void:
	var placed := _screen.grid().buildings()
	assert_eq(placed.size(), 3, "시설 셋이 다 놓여야 한다")
	for building in placed:
		assert_true(building.is_facility(), "%s 가 시설이 아니다" % building.id)


func test_starting_buildings_do_not_overlap() -> void:
	var grid := _screen.grid()
	var covered := {}
	for building in grid.buildings():
		for cell in building.cells():
			assert_false(covered.has(cell), "%s 가 겹쳤다" % building.id)
			covered[cell] = true
	assert_eq(grid.free_cell_count(), grid.cols * grid.rows - covered.size())


## 클릭한 칸과 그려진 칸이 어긋나는 것이 아이소의 대표 버그다 (§30.2).
func test_pointing_at_a_building_finds_that_building() -> void:
	var grid := _screen.grid()
	var building := grid.buildings()[0]
	var world := _screen.projection().cell_to_world(building.origin)
	_screen.point_at_world(world)
	assert_true(_screen.is_pointing_inside())
	assert_eq(_screen.pointed_cell(), building.origin)
	assert_string_contains(_screen.status_text(), building.label())


func test_pointing_at_empty_ground_says_so() -> void:
	var grid := _screen.grid()
	var empty := Vector2i.ZERO
	assert_true(grid.is_free(empty), "(0,0) 은 잠정 배치가 비워 둔 자리다")
	_screen.point_at_world(_screen.projection().cell_to_world(empty))
	assert_string_contains(_screen.status_text(), "빈 칸")


func test_pointing_off_the_board_is_reported_not_clamped() -> void:
	var grid := _screen.grid()
	var outside := _screen.projection().cell_to_world(Vector2i(grid.cols + 4, grid.rows + 4))
	_screen.point_at_world(outside)
	assert_false(_screen.is_pointing_inside())
	assert_string_contains(_screen.status_text(), "판 밖")


func test_camera_frames_the_whole_board() -> void:
	var grid := _screen.grid()
	var camera := _screen.find_children("*", "Camera2D", true, false)[0] as Camera2D
	assert_eq(camera.position, _screen.projection().board_center(grid.cols, grid.rows))
	assert_gt(camera.zoom.x, 0.0)
