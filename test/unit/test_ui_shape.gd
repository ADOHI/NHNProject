extends GutTest
## 절차적 형태 생성기(src/ui/style/shape.gd) 검증.
##
## 화면 코드는 대개 테스트하기 어렵지만, 이 파일은 **점 목록만 돌려주는 순수 함수**라
## 씬 없이 검증된다. 형태를 노드에서 떼어 둔 이유가 여기에 있다.
##
## 여기서 잡고 싶은 것은 "예쁜가"가 아니라 **모서리가 실제로 잘렸는가**,
## **통로가 실제로 끊겼는가** 같은 구조적 사실이다. 캡처로는 확인해도 회귀를 못 막는다.

const _RECT := Rect2(Vector2.ZERO, Vector2(100.0, 60.0))


func test_chamfer_polygon_cuts_only_requested_corners() -> void:
	var cuts := PackedFloat32Array([16.0, 0.0, 0.0, 0.0])
	var polygon := UiShape.chamfer_polygon(_RECT, cuts)
	# 한 모서리만 자르면 꼭짓점이 넷에서 다섯으로 는다.
	assert_eq(polygon.size(), 5, "좌상단 하나만 자르면 꼭짓점은 5개다")
	assert_true(polygon.has(Vector2(16.0, 0.0)), "잘린 면의 시작점")
	assert_true(polygon.has(Vector2(0.0, 16.0)), "잘린 면의 끝점")
	assert_false(polygon.has(Vector2.ZERO), "잘린 모서리의 직각 꼭짓점은 사라진다")


func test_chamfer_polygon_without_cuts_is_a_plain_rect() -> void:
	var polygon := UiShape.chamfer_polygon(_RECT, PackedFloat32Array([0.0, 0.0, 0.0, 0.0]))
	assert_eq(polygon.size(), 4, "자르지 않으면 그냥 사각형이다")


func test_chamfer_polygon_clamps_oversized_cuts() -> void:
	var cuts := PackedFloat32Array([999.0, 999.0, 999.0, 999.0])
	var polygon := UiShape.chamfer_polygon(_RECT, cuts)
	# 짧은 변의 절반을 넘겨 자르면 도형이 뒤집힌다. 그 전에 막아야 한다.
	for point in polygon:
		assert_true(_RECT.has_point(point) or _RECT.abs().grow(0.001).has_point(point))


func test_closed_outline_returns_to_the_first_point() -> void:
	var polygon := UiShape.chamfer_polygon(_RECT, PackedFloat32Array([0.0, 0.0, 0.0, 0.0]))
	var outline := UiShape.closed_outline(polygon)
	assert_eq(outline.size(), polygon.size() + 1)
	assert_eq(outline[outline.size() - 1], outline[0], "윤곽선은 첫 점으로 돌아온다")


func test_bracket_has_two_arms_from_one_corner() -> void:
	var bracket := UiShape.bracket(_RECT, UiShape.Corner.TOP_LEFT, 12.0)
	assert_eq(bracket.size(), 3, "브래킷은 점 세 개짜리 꺾인 선이다")
	assert_eq(bracket[1], Vector2.ZERO, "가운데 점이 모서리다")


func test_dash_segments_break_the_line() -> void:
	var segments := UiShape.dash_segments(Vector2.ZERO, Vector2(100.0, 0.0), 10.0, 10.0)
	assert_eq(segments.size(), 5, "20 픽셀마다 한 토막이면 100 픽셀에 다섯 토막")
	for segment in segments:
		assert_eq(segment.size(), 2, "각 토막은 점 두 개다")
		assert_almost_eq(segment[0].distance_to(segment[1]), 10.0, 0.001)


func test_dash_segments_ignore_zero_length_lines() -> void:
	assert_eq(UiShape.dash_segments(Vector2.ZERO, Vector2.ZERO, 10.0, 10.0).size(), 0)


func test_hazard_stripes_stay_inside_the_shape() -> void:
	var polygon := UiShape.chamfer_polygon(_RECT, UiTokens.tile_cuts())
	var stripes := UiShape.hazard_stripes(_RECT, 13.0, 4.0, polygon)
	assert_gt(stripes.size(), 3, "사선이 여러 줄 나온다")
	var bounds := _RECT.grow(0.5)
	for stripe in stripes:
		for point in stripe:
			assert_true(bounds.has_point(point), "사선은 도형 밖으로 새지 않는다")


func test_signal_bars_grow_to_the_right() -> void:
	var bars := UiShape.signal_bars(Vector2.ZERO, 3, Vector2(4.0, 12.0), 2.0)
	assert_eq(bars.size(), 3)
	assert_lt(bars[0].size.y, bars[2].size.y, "오른쪽으로 갈수록 높아진다")
	assert_lt(bars[0].position.x, bars[1].position.x)


func test_chevron_points_the_right_way() -> void:
	var up := UiShape.chevron(Vector2.ZERO, 5.0, 6.0, true)
	var down := UiShape.chevron(Vector2.ZERO, 5.0, 6.0, false)
	assert_lt(up[1].y, up[0].y, "위를 가리키면 꼭짓점이 위에 있다")
	assert_gt(down[1].y, down[0].y, "아래를 가리키면 꼭짓점이 아래에 있다")


func test_tick_ruler_places_every_tick_on_the_line() -> void:
	var ticks := UiShape.tick_ruler(Vector2.ZERO, Vector2(100.0, 0.0), 5, 6.0)
	assert_eq(ticks.size(), 5)
	assert_eq(ticks[0][0], Vector2.ZERO)
	assert_eq(ticks[4][0], Vector2(100.0, 0.0))
	for tick in ticks:
		assert_almost_eq(tick[0].y, 0.0, 0.001, "눈금의 뿌리는 선 위에 있다")
