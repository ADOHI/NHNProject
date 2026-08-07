extends GutTest
## 들로네 삼각분할의 단위 테스트.
##
## **여기가 판의 평면성을 떠받친다.** 삼각분할이 진짜 삼각분할이 아니면
## "부분집합을 고르면 교차하지 않는다"는 논증이 통째로 무너진다
## (docs/design/17-dungeon-generation.md §17.3).

const DelaunayScript := preload("res://src/core/dungeon/generation/delaunay_triangulation.gd")
const SamplerScript := preload("res://src/core/dungeon/generation/poisson_disk_sampler.gd")
const Crossing := preload("res://test/support/segment_crossing.gd")

const _SEEDS := 8


func _blue_noise(seed_value: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return SamplerScript.new(Vector2(11.0, 8.0)).generate(rng)


func test_no_point_lies_inside_a_circumcircle() -> void:
	# 들로네의 정의 그 자체다. 이게 성립하면 결과는 유효한 삼각분할이다.
	for seed_value in _SEEDS:
		var points := _blue_noise(seed_value)
		var triangles := DelaunayScript.triangulate(points)
		assert_gt(triangles.size(), 0, "시드 %d 에서 삼각형이 하나도 안 나왔다" % seed_value)
		_assert_empty_circumcircles(points, triangles, seed_value)


func _assert_empty_circumcircles(
	points: PackedVector2Array, triangles: PackedInt32Array, seed_value: int
) -> void:
	var index := 0
	while index + 2 < triangles.size():
		var a := points[triangles[index]]
		var b := points[triangles[index + 1]]
		var c := points[triangles[index + 2]]
		var center := _circumcenter(a, b, c)
		var radius := center.distance_to(a)
		for other in points.size():
			if triangles.slice(index, index + 3).has(other):
				continue
			if center.distance_to(points[other]) < radius - 1e-4:
				fail_test("시드 %d: 외접원 안에 다른 점이 있다" % seed_value)
				return
		index += 3


func test_triangulation_edges_never_cross() -> void:
	# 삼각분할 전체가 평면이면 그 부분집합도 평면이다. 이 테스트가 그 전제를 확인한다.
	for seed_value in _SEEDS:
		var points := _blue_noise(seed_value)
		var edges := DelaunayScript.edges(points)
		for i in edges.size():
			for j in range(i + 1, edges.size()):
				var a: Vector2i = edges[i]
				var b: Vector2i = edges[j]
				if Crossing.crosses(points[a.x], points[a.y], points[b.x], points[b.y]):
					fail_test("시드 %d: 삼각분할 간선이 교차한다" % seed_value)
					return
		assert_gt(edges.size(), 0)


func test_every_point_gets_at_least_one_edge() -> void:
	# 삼각분할에서 빠진 점이 있으면 그 방은 어디와도 이어질 수 없다.
	for seed_value in _SEEDS:
		var points := _blue_noise(seed_value)
		var touched := {}
		for edge in DelaunayScript.edges(points):
			touched[edge.x] = true
			touched[edge.y] = true
		assert_eq(touched.size(), points.size(), "시드 %d 에 삼각분할에서 빠진 점이 있다" % seed_value)


func test_a_square_becomes_two_triangles() -> void:
	# 손으로 답을 아는 최소 사례. 정사각형은 대각선 하나로 갈라진다.
	var points := PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(4, 3), Vector2(0, 3)])
	assert_eq(DelaunayScript.triangulate(points).size(), 6)
	assert_eq(DelaunayScript.edges(points).size(), 5, "정사각형 네 변 + 대각선 하나여야 한다")


func test_too_few_points_give_nothing() -> void:
	assert_eq(DelaunayScript.triangulate(PackedVector2Array()).size(), 0)
	assert_eq(DelaunayScript.triangulate(PackedVector2Array([Vector2.ZERO])).size(), 0)
	assert_eq(DelaunayScript.edges(PackedVector2Array([Vector2.ZERO, Vector2.RIGHT])).size(), 0)


func test_edges_are_normalised_and_unique() -> void:
	var points := _blue_noise(4)
	var seen := {}
	for edge in DelaunayScript.edges(points):
		assert_lt(edge.x, edge.y, "간선이 정규화되지 않았다")
		assert_false(seen.has(edge), "같은 간선이 두 번 나왔다")
		seen[edge] = true


## 세 점의 외접원 중심. 테스트가 생성기와 다른 식으로 계산해야 검증이 된다.
func _circumcenter(a: Vector2, b: Vector2, c: Vector2) -> Vector2:
	var d := 2.0 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
	if absf(d) < 1e-12:
		return Vector2.INF
	var a2 := a.length_squared()
	var b2 := b.length_squared()
	var c2 := c.length_squared()
	return Vector2(
		(a2 * (b.y - c.y) + b2 * (c.y - a.y) + c2 * (a.y - b.y)) / d,
		(a2 * (c.x - b.x) + b2 * (a.x - c.x) + c2 * (b.x - a.x)) / d
	)
