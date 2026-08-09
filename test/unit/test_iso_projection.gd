extends GutTest
## 아이소 투영의 단위 테스트.
##
## **아이소에서 가장 흔한 버그는 클릭한 칸과 그려진 칸이 한 칸 어긋나는 것이다.**
## 눈으로는 잘 안 잡히고 조용히 회귀한다. 왕복(칸 -> 화면 -> 칸)을 여기서 지킨다
## (docs/design/30-hideout.md §30.2).

const IsoScript := preload("res://src/core/hideout/iso_projection.gd")


func _iso() -> IsoProjection:
	return IsoScript.new()


func test_origin_sits_at_zero() -> void:
	assert_eq(_iso().cell_to_world(Vector2i.ZERO), Vector2.ZERO)


func test_x_axis_goes_right_and_down() -> void:
	var iso := _iso()
	assert_eq(iso.cell_to_world(Vector2i(1, 0)), Vector2(48.0, 16.0))


func test_y_axis_goes_left_and_down() -> void:
	var iso := _iso()
	assert_eq(iso.cell_to_world(Vector2i(0, 1)), Vector2(-48.0, 16.0))


func test_round_trip_returns_the_same_cell() -> void:
	var iso := _iso()
	for y in 20:
		for x in 20:
			var cell := Vector2i(x, y)
			assert_eq(iso.world_to_cell(iso.cell_to_world(cell)), cell)


## 칸 안 어디를 찍어도 같은 칸이 나와야 한다. 중심만 맞는 것은 맞는 것이 아니다.
func test_points_inside_a_cell_all_map_to_it() -> void:
	var iso := _iso()
	var cell := Vector2i(4, 7)
	var center := iso.cell_to_world(cell)
	var nudges := [
		Vector2(0.0, -15.0),
		Vector2(46.0, 0.0),
		Vector2(0.0, 15.0),
		Vector2(-46.0, 0.0),
		Vector2(20.0, 7.0),
	]
	for nudge in nudges:
		assert_eq(iso.world_to_cell(center + nudge), cell, "칸 안의 %s" % nudge)


func test_neighbouring_cells_do_not_overlap() -> void:
	var iso := _iso()
	var seen := {}
	for y in 8:
		for x in 8:
			var world := iso.cell_to_world(Vector2i(x, y))
			assert_false(seen.has(world), "칸 두 개가 같은 자리에 놓였다")
			seen[world] = true


## 마름모는 위 - 오른쪽 - 아래 - 왼쪽 네 점이고, 이웃한 칸과 변을 공유해야 빈틈이 안 생긴다.
func test_cell_polygon_shares_edges_with_neighbour() -> void:
	var iso := _iso()
	var here := iso.cell_polygon(Vector2i(3, 3))
	var right := iso.cell_polygon(Vector2i(4, 3))
	assert_eq(here[1], right[0], "오른쪽 이웃의 위 꼭짓점은 내 오른쪽 꼭짓점이다")
	assert_eq(here[2], right[3], "아래 꼭짓점도 공유한다")


func test_rect_polygon_covers_the_whole_footprint() -> void:
	var iso := _iso()
	var single := iso.cell_polygon(Vector2i(2, 2))
	var span := iso.rect_polygon(Vector2i(2, 2), Vector2i(2, 2))
	assert_eq(span[0], single[0], "위 꼭짓점은 원점 칸의 것과 같다")
	assert_eq(span[2].y, single[2].y + 32.0, "2x2 는 세로로 한 칸 더 내려간다")


func test_depth_grows_towards_the_viewer() -> void:
	assert_lt(IsoScript.depth_of(Vector2i(0, 0)), IsoScript.depth_of(Vector2i(1, 0)))
	assert_eq(IsoScript.depth_of(Vector2i(3, 1)), IsoScript.depth_of(Vector2i(1, 3)))


## 발자국이 큰 건물은 앞선 모서리로 정렬한다 — 원점으로 정렬하면 앞뒤가 뒤집힌다.
func test_rect_depth_uses_the_front_corner() -> void:
	var big := IsoScript.rect_depth(Vector2i(0, 0), Vector2i(3, 3))
	var small := IsoScript.rect_depth(Vector2i(2, 2), Vector2i(1, 1))
	assert_eq(big, small, "3x3 의 앞 모서리는 (2,2) 다")
	assert_gt(big, IsoScript.rect_depth(Vector2i(0, 0), Vector2i(1, 1)))


## 시점은 캐릭터 그림에 맞춘 것이지 고른 것이 아니다 (§30.9 ★1 — 확정).
##
## 이 비율이 조용히 바뀌면 인물이 바닥과 어긋난 채로 서 있게 되고, 그것은
## 눈으로 봐야만 잡힌다. 값을 여기서 못 박아 둔다.
func test_default_view_is_the_quarter_view_matched_to_the_characters() -> void:
	var iso := _iso()
	assert_eq(iso.tile_width(), 96.0)
	assert_eq(iso.tile_height(), 32.0)
	assert_almost_eq(iso.tile_height() / iso.tile_width(), 1.0 / 3.0, 0.001, "3:1 쿼터뷰")


## 시점을 바꾸는 지점은 이 두 값뿐이다.
func test_tile_size_is_the_only_knob() -> void:
	var flat := IsoScript.new(80.0, 20.0)
	assert_eq(flat.cell_to_world(Vector2i(1, 0)), Vector2(40.0, 10.0))
	assert_eq(flat.world_to_cell(Vector2(40.0, 10.0)), Vector2i(1, 0))


func test_board_size_grows_with_both_axes() -> void:
	var iso := _iso()
	assert_eq(iso.board_size(20, 20), Vector2(1920.0, 640.0))
