extends GutTest
## 절차적 형태 생성기(src/ui/style/shape.gd) 검증.
##
## 화면 코드는 대개 테스트하기 어렵지만, 이 파일은 **점 목록만 돌려주는 순수 함수**라
## 씬 없이 검증된다. 형태를 노드에서 떼어 둔 이유가 여기에 있다.
##
## 여기서 잡고 싶은 것은 "예쁜가"가 아니라 **가장자리가 실제로 찢겼는가**,
## **통로가 실제로 끊겼는가** 같은 구조적 사실이다. 캡처로는 확인해도 회귀를 못 막는다.

const _RECT := Rect2(Vector2.ZERO, Vector2(100.0, 60.0))


func test_rect_polygon_has_four_corners() -> void:
	var polygon := UiShape.rect_polygon(_RECT)
	assert_eq(polygon.size(), 4, "지면의 상자는 네 귀퉁이 그대로다. 굴리지도 자르지도 않는다")
	assert_true(polygon.has(Vector2.ZERO))
	assert_true(polygon.has(Vector2(100.0, 60.0)))


func test_closed_outline_returns_to_the_first_point() -> void:
	var outline := UiShape.closed_outline(UiShape.rect_polygon(_RECT))
	assert_eq(outline.size(), 5)
	assert_eq(outline[outline.size() - 1], outline[0], "윤곽선은 첫 점으로 돌아온다")


func test_deckle_edge_wobbles_around_the_rect() -> void:
	var torn := UiShape.deckle_edge(_RECT, 6.0, 20.0, 1.0)
	assert_gt(torn.size(), 8, "찢긴 가장자리는 꼭짓점이 훨씬 많다")
	var bounds := _RECT.grow(6.5)
	var off_axis := 0
	for point in torn:
		assert_true(bounds.has_point(point), "떨림은 진폭 안에 머문다")
		if not is_equal_approx(point.x, 0.0) and not is_equal_approx(point.y, 0.0):
			off_axis += 1
	assert_gt(off_axis, 4, "실제로 자 밖으로 나간 점이 있어야 찢긴 것이다")


func test_deckle_edge_is_stable_for_the_same_seed() -> void:
	# 프레임마다 값이 달라지면 가만히 있어야 할 종이가 떨린다.
	assert_eq(
		UiShape.deckle_edge(_RECT, 6.0, 20.0, 2.0), UiShape.deckle_edge(_RECT, 6.0, 20.0, 2.0)
	)
	assert_ne(
		UiShape.deckle_edge(_RECT, 6.0, 20.0, 2.0), UiShape.deckle_edge(_RECT, 6.0, 20.0, 9.0)
	)


func test_wiggle_stays_in_half_unit_range() -> void:
	for step in 40:
		var value := UiShape.wiggle(float(step) * 3.7)
		assert_between(value, -0.5, 0.5)


func test_register_mark_has_four_arms_leaving_a_gap() -> void:
	var strokes := UiShape.register_mark(Vector2(50.0, 50.0), 15.0, 4.0)
	assert_eq(strokes.size(), 4, "맞춤표는 십자다")
	for stroke in strokes:
		assert_eq(stroke.size(), 2)
		# 가운데가 비어 있어야 눈금이 아니라 표적으로 읽힌다.
		assert_almost_eq(stroke[0].distance_to(Vector2(50.0, 50.0)), 4.0, 0.001)
		assert_almost_eq(stroke[1].distance_to(Vector2(50.0, 50.0)), 15.0, 0.001)


func test_register_ring_closes_on_itself() -> void:
	var ring := UiShape.register_ring(Vector2(10.0, 10.0), 8.0, 12)
	assert_eq(ring.size(), 13, "마지막 점이 첫 점으로 돌아온다")
	assert_almost_eq(ring[0].distance_to(ring[ring.size() - 1]), 0.0, 0.001)


func test_rule_stack_lays_bands_top_down_without_overlap() -> void:
	var weights := PackedFloat32Array([8.0, 1.0, 2.0])
	var bands := UiShape.rule_stack(Vector2(4.0, 10.0), 200.0, weights, 3.0)
	assert_eq(bands.size(), 3)
	for index in bands.size():
		assert_eq(bands[index].size.x, 200.0)
		assert_eq(bands[index].size.y, weights[index])
	assert_gte(bands[1].position.y, bands[0].end.y, "괘선끼리 겹치지 않는다")
	assert_gte(bands[2].position.y, bands[1].end.y)


func test_rule_stack_skips_zero_weight_but_keeps_the_gap() -> void:
	var bands := UiShape.rule_stack(Vector2.ZERO, 10.0, PackedFloat32Array([0.0, 2.0]), 5.0)
	assert_eq(bands.size(), 1, "굵기 0 은 선이 아니라 빈자리다")
	assert_almost_eq(bands[0].position.y, 5.0, 0.001)


func test_pennant_notches_the_right_edge() -> void:
	var flag := UiShape.pennant(Rect2(0.0, 0.0, 100.0, 40.0), 12.0)
	assert_eq(flag.size(), 5, "깃발은 오른쪽이 파여 꼭짓점이 다섯이다")
	assert_true(flag.has(Vector2(88.0, 20.0)), "파인 자리가 세로 가운데에 있다")


func test_pennant_clamps_an_oversized_notch() -> void:
	# 파임이 깃발 폭의 절반을 넘으면 도형이 뒤집힌다. 파인 꼭짓점은 가운데까지만 온다.
	var flag := UiShape.pennant(Rect2(0.0, 0.0, 40.0, 20.0), 999.0)
	assert_almost_eq(flag[2].x, 20.0, 0.001, "파임이 깃발을 관통하지 않는다")
	assert_almost_eq(flag[2].y, 10.0, 0.001, "파인 자리는 세로 가운데다")


func test_dash_segments_break_the_line() -> void:
	var segments := UiShape.dash_segments(Vector2.ZERO, Vector2(100.0, 0.0), 10.0, 10.0)
	assert_eq(segments.size(), 5, "20 픽셀마다 한 토막이면 100 픽셀에 다섯 토막")
	for segment in segments:
		assert_eq(segment.size(), 2, "각 토막은 점 두 개다")
		assert_almost_eq(segment[0].distance_to(segment[1]), 10.0, 0.001)


func test_dash_segments_ignore_zero_length_lines() -> void:
	assert_eq(UiShape.dash_segments(Vector2.ZERO, Vector2.ZERO, 10.0, 10.0).size(), 0)


func test_hazard_stripes_stay_inside_the_shape() -> void:
	var polygon := UiShape.rect_polygon(_RECT)
	var stripes := UiShape.hazard_stripes(_RECT, 13.0, 4.0, polygon)
	assert_gt(stripes.size(), 3, "겹쳐찍기 사선이 여러 줄 나온다")
	var bounds := _RECT.grow(0.5)
	for stripe in stripes:
		for point in stripe:
			assert_true(bounds.has_point(point), "사선은 도형 밖으로 새지 않는다")


func test_hazard_stripes_work_away_from_the_origin() -> void:
	# 사선의 길이를 사각형 크기로만 잡으면 화면 한가운데 놓인 상자에서 통째로 사라진다.
	# 실제로 그렇게 만들었다가 견본쇄에서 겹쳐찍기가 안 나온 적이 있어 회귀로 남긴다.
	var far := Rect2(Vector2(646.0, 262.0), Vector2(130.0, 54.0))
	var stripes := UiShape.hazard_stripes(far, 12.0, 5.0, UiShape.rect_polygon(far))
	assert_gt(stripes.size(), 3, "멀리 있는 상자에도 사선이 그어진다")
	var bounds := far.grow(0.5)
	for stripe in stripes:
		for point in stripe:
			assert_true(bounds.has_point(point))


func test_gauge_bars_grow_to_the_right() -> void:
	var bars := UiShape.gauge_bars(Vector2.ZERO, 3, Vector2(4.0, 12.0), 2.0)
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
