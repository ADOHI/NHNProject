extends GutTest
## 알파에서 가림 폴리곤을 뽑는 것의 단위 테스트.
##
## **여기서 제일 무서운 실패는 「그럴듯한 폴리곤이 나오는데 틀린 것」이다.**
## 점이 몇 개 나오면 눈으로는 다 그럴듯해 보인다. 그래서 숫자로 못 박는 것 넷 —
## 모양이 남는가(면적) · **줄인 만큼만 벗어나는가**(`epsilon` 이 약속을 지키는가) ·
## 덩어리를 세는가 · 고리가 반드시 닫히고 **끝나는가**(무한 반복이 없다).
##
## 마지막 것이 특히 중요하다. 경계 추적이 안 닫히면 헤드리스에서 「멈춘 것처럼」
## 보이고, 그 증상은 「느리다」와 구분이 안 된다.


## 가운데에 꽉 찬 네모가 하나 있는 알파 그림.
func _rect_image(size: int, inset: int) -> Image:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	for y in range(inset, size - inset):
		for x in range(inset, size - inset):
			image.set_pixel(x, y, Color(1, 1, 1, 1))
	return image


## 서로 떨어진 네모 둘. **덩어리를 세는지** 보는 그림이다.
func _two_blobs() -> Image:
	var image := Image.create_empty(64, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	for y in range(8, 24):
		for x in range(4, 20):
			image.set_pixel(x, y, Color(1, 1, 1, 1))
		for x in range(44, 60):
			image.set_pixel(x, y, Color(1, 1, 1, 1))
	return image


func _blank() -> Image:
	var image := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	return image


func test_solid_rect_gives_a_closed_polygon() -> void:
	var points := ProtoAlphaOccluder.build(_rect_image(64, 16), 0.5, 64, 1.0)
	assert_gte(points.size(), ProtoAlphaOccluder.MIN_POINTS, "폴리곤이 되려면 세 점은 있어야 한다")


## **네모는 네 점이면 된다.** 알파 그대로 따면 128 점이고, 그것이 줄일 이유다.
func test_rect_reduces_to_about_four_corners() -> void:
	var dense := ProtoAlphaOccluder.trace_all(_rect_image(64, 16), 0.5, 64)
	assert_eq(dense.size(), 1, "덩어리는 하나다")
	var simple := ProtoAlphaOccluder.simplify(dense[0], 2.0)
	assert_gt(dense[0].size(), 60, "따는 단계에서는 둘레만큼 점이 나온다")
	assert_lte(simple.size(), 8, "줄이면 모서리 넷 언저리로 내려와야 한다")


## `epsilon` 은 **약속**이다. 「이만큼까지만 벗어난다」를 안 지키면 손잡이가 아니다.
func test_epsilon_bounds_the_error() -> void:
	var dense := ProtoAlphaOccluder.trace_all(_rect_image(96, 20), 0.5, 96)[0]
	for epsilon in [1.0, 3.0, 6.0]:
		var simple := ProtoAlphaOccluder.simplify(dense, epsilon)
		var off := ProtoAlphaOccluder.max_deviation(dense, simple)
		assert_lte(off, epsilon + 0.001, "epsilon %.1f 인데 %.2f 벗어났다" % [epsilon, off])


## 점을 줄여도 **덮는 넓이가 남아야** 그림자가 남는다.
func test_simplify_keeps_the_area() -> void:
	var dense := ProtoAlphaOccluder.trace_all(_rect_image(96, 20), 0.5, 96)[0]
	var before := ProtoAlphaOccluder.polygon_area(dense)
	var after := ProtoAlphaOccluder.polygon_area(ProtoAlphaOccluder.simplify(dense, 4.0))
	assert_almost_eq(after / before, 1.0, 0.05, "면적이 5% 넘게 달라지면 모양을 버린 것이다")


func test_bigger_epsilon_never_adds_points() -> void:
	var dense := ProtoAlphaOccluder.trace_all(_rect_image(96, 20), 0.5, 96)[0]
	var coarse := ProtoAlphaOccluder.simplify(dense, 8.0)
	var fine := ProtoAlphaOccluder.simplify(dense, 1.0)
	assert_lte(coarse.size(), fine.size(), "epsilon 이 크면 점이 늘 수 없다")


## 떨어진 덩어리를 **각각** 딴다. `p_shards` 처럼 흩어진 소품이 실제로 있다.
func test_counts_separate_blobs() -> void:
	assert_eq(ProtoAlphaOccluder.trace_all(_two_blobs(), 0.5, 64).size(), 2)


## 여럿이면 **제일 큰 것**을 쓴다.
func test_build_picks_the_largest_blob() -> void:
	var image := Image.create_empty(64, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	for y in range(4, 28):
		for x in range(4, 40):
			image.set_pixel(x, y, Color(1, 1, 1, 1))
	for y in range(12, 18):
		for x in range(50, 56):
			image.set_pixel(x, y, Color(1, 1, 1, 1))
	var points := ProtoAlphaOccluder.build(image, 0.5, 64, 1.0)
	var area := ProtoAlphaOccluder.polygon_area(points)
	assert_gt(area, 500.0, "작은 조각이 아니라 큰 덩어리를 골라야 한다")


## **아무것도 없는 그림은 빈 폴리곤이다.** 여기서 한 점짜리라도 돌려주면
## `OccluderPolygon2D` 가 조용히 이상한 그림자를 만든다.
func test_blank_image_gives_nothing() -> void:
	assert_eq(ProtoAlphaOccluder.trace_all(_blank(), 0.5, 32).size(), 0)
	assert_eq(ProtoAlphaOccluder.build(_blank(), 0.5, 32, 1.0).size(), 0)


## 알파 문턱이 실제로 문턱 노릇을 하는가. 반투명만 있는 그림은 문턱에 따라 갈린다.
func test_alpha_threshold_decides() -> void:
	var image := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	for y in range(8, 24):
		for x in range(8, 24):
			image.set_pixel(x, y, Color(1, 1, 1, 0.3))
	assert_eq(ProtoAlphaOccluder.trace_all(image, 0.5, 32).size(), 0, "0.3 은 0.5 를 못 넘는다")
	assert_eq(ProtoAlphaOccluder.trace_all(image, 0.2, 32).size(), 1, "0.3 은 0.2 를 넘는다")


## 원본 화소 좌표로 돌려준다. 줄여서 딴 뒤 되돌리는 계산이 틀리면 여기서 걸린다.
func test_returns_source_pixel_coordinates() -> void:
	var points := ProtoAlphaOccluder.build(_rect_image(256, 64), 0.5, 64, 2.0)
	var max_x := 0.0
	for p in points:
		max_x = maxf(max_x, p.x)
	assert_gt(max_x, 128.0, "256 짜리 그림인데 좌표가 작업 격자(64)에 머물러 있다")
	assert_lte(max_x, 256.0)


func test_centered_moves_origin_to_the_middle() -> void:
	var points := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 50)])
	var moved := ProtoAlphaOccluder.centered(points, Vector2(100, 50))
	assert_eq(moved[0], Vector2(-50, -25))
	assert_eq(moved[1], Vector2(50, -25))


func test_polygon_area_of_a_known_square() -> void:
	var square := PackedVector2Array(
		[Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)]
	)
	assert_almost_eq(ProtoAlphaOccluder.polygon_area(square), 100.0, 0.001)


## 감김 방향이 반대여도 면적은 같다. 마칭 스퀘어의 방향은 덩어리마다 뒤집힐 수 있다.
func test_polygon_area_ignores_winding() -> void:
	var reversed := PackedVector2Array(
		[Vector2(0, 10), Vector2(10, 10), Vector2(10, 0), Vector2(0, 0)]
	)
	assert_almost_eq(ProtoAlphaOccluder.polygon_area(reversed), 100.0, 0.001)


func test_work_dimensions_shrinks_only_when_bigger() -> void:
	var small := Image.create_empty(40, 20, false, Image.FORMAT_RGBA8)
	assert_eq(ProtoAlphaOccluder.work_dimensions(small, 256), Vector2i(40, 20), "작으면 그대로")
	var big := Image.create_empty(1000, 500, false, Image.FORMAT_RGBA8)
	assert_eq(ProtoAlphaOccluder.work_dimensions(big, 100), Vector2i(100, 50), "비율을 지킨다")


## 세 점 이하는 줄일 것이 없다. 여기서 점을 더 빼면 폴리곤이 아니게 된다.
func test_simplify_leaves_tiny_polygons_alone() -> void:
	var tri := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(5, 8)])
	assert_eq(ProtoAlphaOccluder.simplify(tri, 100.0).size(), 3)
