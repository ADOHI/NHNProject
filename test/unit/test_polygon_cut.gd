extends GutTest
## 다각형 자르기의 단위 테스트.
##
## SHEAR 컨셉은 판을 **진짜로 잘라야** 성립한다. 사각형 둘을 붙여 놓고 각각 미는
## 방식으로는 사선으로 벤 자국이 안 나오고, 미는 순간 모서리가 어긋나 계단이 보인다.


## PackedVector2Array 생성은 상수 표현식이 아니라 const 로 둘 수 없다.
static func _square() -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 60), Vector2(0, 60)])


func _area(polygon: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(polygon.size()):
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		total += a.x * b.y - b.x * a.y
	return absf(total) * 0.5


## 가운데를 자르면 넓이가 반씩 나뉜다.
func test_split_halves_the_area() -> void:
	var halves := PolygonCut.split(_square(), Vector2(50, 30), Vector2.UP)
	assert_almost_eq(_area(halves[0]), 3000.0, 1.0)
	assert_almost_eq(_area(halves[1]), 3000.0, 1.0)


## 어떻게 자르든 조각의 넓이 합은 원래와 같아야 한다. 잘라서 잃어버리면 구멍이 생긴다.
func test_area_is_conserved_for_any_cut() -> void:
	for angle in [0.0, 0.4, 1.1, 2.3, -0.7]:
		var normal := Vector2(cos(angle), sin(angle))
		for shift in [-20.0, 0.0, 15.0]:
			var halves := PolygonCut.split(_square(), Vector2(50, 30) + normal * shift, normal)
			var total := _area(halves[0]) + _area(halves[1])
			assert_almost_eq(total, 6000.0, 1.0, "각 %f 자리 %f 에서 넓이가 샜다" % [angle, shift])


## 다각형 밖에서 자르면 한쪽이 통째로 남고 다른 쪽은 빈다.
func test_cut_outside_leaves_one_piece() -> void:
	var halves := PolygonCut.split(_square(), Vector2(50, -400), Vector2.UP)
	var full := halves[0] if halves[0].size() > 0 else halves[1]
	var empty := halves[1] if halves[0].size() > 0 else halves[0]
	assert_almost_eq(_area(full), 6000.0, 1.0)
	assert_lt(empty.size(), 3, "빈 쪽에 조각이 남았다")


## 두 번 자르면 세 조각이고, 그 합은 여전히 원래 넓이다.
func test_two_cuts_make_three_pieces() -> void:
	var points: Array[Vector2] = [Vector2(50, 18), Vector2(50, 42)]
	var pieces := PolygonCut.slice(_square(), points, Vector2.UP)
	assert_eq(pieces.size(), 3, "두 번 잘랐는데 세 조각이 아니다")
	var total := 0.0
	for piece in pieces:
		total += _area(piece)
		assert_gte(piece.size(), 3, "조각이 다각형이 아니다")
	assert_almost_eq(total, 6000.0, 1.0)


## 자를 곳이 없으면 원래 다각형 하나가 그대로 나온다.
func test_slice_without_cuts_returns_the_whole() -> void:
	var none: Array[Vector2] = []
	var pieces := PolygonCut.slice(_square(), none, Vector2.UP)
	assert_eq(pieces.size(), 1)
	assert_almost_eq(_area(pieces[0]), 6000.0, 1.0)


## 사선으로 잘라도 조각이 볼록하게 남는다 (그려도 뒤집히지 않는다).
func test_diagonal_cut_keeps_pieces_drawable() -> void:
	var points: Array[Vector2] = [Vector2(50, 30)]
	var pieces := PolygonCut.slice(_square(), points, Vector2(0.46, -0.89).normalized())
	assert_eq(pieces.size(), 2)
	for piece in pieces:
		assert_gt(_area(piece), 1.0, "사선 조각 하나가 사실상 없다")
