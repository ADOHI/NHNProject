extends GutTest
## `PlateShape` — 버튼 판의 윤곽 기하.
##
## 여기서 잡고 싶은 것은 **안쪽 윤곽이 바깥 윤곽과 어긋나는 것**이다.
## 45도 모따기를 안쪽으로 밀 때 모따기 크기를 같이 줄이지 않으면 모서리에
## 틈이 벌어지는데, 1~2px 라 화면에서는 「좀 지저분하네」로 넘어간다.

const BOX := Rect2(0.0, 0.0, 200.0, 56.0)


func test_octagon_has_eight_corners() -> void:
	assert_eq(PlateShape.octagon(BOX, 9.0).size(), 8, "모따기한 사각형은 꼭짓점이 여덟이다")


func test_octagon_stays_inside_its_rect() -> void:
	for point in PlateShape.octagon(BOX, 9.0):
		assert_between(point.x, BOX.position.x, BOX.end.x, "판이 자기 칸 밖으로 나가면 안 된다")
		assert_between(point.y, BOX.position.y, BOX.end.y, "적중 영역과 실루엣이 같아야 한다")


func test_chamfer_cannot_eat_the_whole_plate() -> void:
	var shape := PlateShape.octagon(BOX, 400.0)
	for point in shape:
		assert_between(point.y, BOX.position.y, BOX.end.y, "터무니없는 모따기도 판을 넘지 않는다")


## 모따기를 줄이지 않고 사각형만 줄이면 여기서 어긋난다.
func test_inset_keeps_the_same_forty_five_degree_facet() -> void:
	var outer := PlateShape.octagon(BOX, 9.0)
	var inner := PlateShape.inset(BOX, 9.0, 4.0)
	for i in 4:
		var a := outer[i * 2 + 1].direction_to(outer[(i * 2 + 2) % 8])
		var b := inner[i * 2 + 1].direction_to(inner[(i * 2 + 2) % 8])
		assert_almost_eq(a.dot(b), 1.0, 0.0005, "안쪽 모따기가 바깥과 나란해야 틈이 안 벌어진다")


func test_inset_moves_every_edge_by_the_same_distance() -> void:
	var inner := PlateShape.inset(BOX, 9.0, 4.0)
	assert_almost_eq(inner[0].y, BOX.position.y + 4.0, 0.001, "위 변이 4 만큼 내려온다")
	assert_almost_eq(inner[3].x, BOX.end.x - 4.0, 0.001, "오른 변이 4 만큼 들어온다")
	assert_almost_eq(inner[5].y, BOX.end.y - 4.0, 0.001, "아래 변이 4 만큼 올라온다")
	assert_almost_eq(inner[7].x, BOX.position.x + 4.0, 0.001, "왼 변이 4 만큼 들어온다")


func test_perimeter_matches_the_cut_rectangle() -> void:
	var chamfer := 9.0
	var straight := 2.0 * (BOX.size.x + BOX.size.y) - 8.0 * chamfer
	var expected := straight + 4.0 * chamfer * sqrt(2.0)
	assert_almost_eq(PlateShape.perimeter(PlateShape.octagon(BOX, chamfer)), expected, 0.01)


## 변마다 같은 시간을 주면 8px 짜리 모따기에서 빛이 거의 멈춰 보인다.
## 둘레 길이로 나눠야 등속으로 돈다.
func test_along_runs_at_constant_speed() -> void:
	var shape := PlateShape.octagon(BOX, 9.0)
	var step := PlateShape.perimeter(shape) / 200.0
	for i in 200:
		var a := PlateShape.along(shape, float(i) / 200.0)
		var b := PlateShape.along(shape, float(i + 1) / 200.0)
		assert_almost_eq(a.distance_to(b), step, 0.35, "빛이 모서리에서 멈추면 안 된다")


func test_along_wraps_around() -> void:
	var shape := PlateShape.octagon(BOX, 9.0)
	assert_almost_eq(
		PlateShape.along(shape, 1.25).distance_to(PlateShape.along(shape, 0.25)),
		0.0,
		0.001,
		"둘레를 한 바퀴 돌면 제자리다"
	)


func test_sweep_band_starts_and_ends_outside_the_plate() -> void:
	var start := PlateShape.sweep_band(BOX, 0.0, 26.0, 14.0)
	var finish := PlateShape.sweep_band(BOX, 1.0, 26.0, 14.0)
	for point in start:
		assert_lte(point.x, BOX.position.x, "광택은 판 왼쪽 밖에서 들어와야 한다")
	for point in finish:
		assert_gte(point.x, BOX.end.x, "광택은 판 오른쪽 밖으로 나가야 한다")


func test_sweep_band_covers_the_full_height() -> void:
	var band := PlateShape.sweep_band(BOX, 0.5, 26.0, 14.0)
	var top := 9999.0
	var bottom := -9999.0
	for point in band:
		top = minf(top, point.y)
		bottom = maxf(bottom, point.y)
	assert_lt(top, BOX.position.y, "띠가 판 위 끝을 덮어야 잘린 자국이 안 보인다")
	assert_gt(bottom, BOX.end.y, "띠가 판 아래 끝을 덮어야 한다")
