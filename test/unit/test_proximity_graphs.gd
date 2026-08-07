extends GutTest
## 근접 그래프들의 단위 테스트.
##
## 확인하는 것은 두 가지다.
##
## | 성질 | 왜 중요한가 |
## | --- | --- |
## | MST ⊆ RNG ⊆ 가브리엘 ⊆ 들로네 | 어느 것을 골라도 평면성이 유지된다 |
## | MST 가 모든 점을 잇는다 | 도달 못 하는 방이 구조적으로 없다 (V1) |

const DelaunayScript := preload("res://src/core/dungeon/generation/delaunay_triangulation.gd")
const GraphsScript := preload("res://src/core/dungeon/generation/proximity_graphs.gd")
const SamplerScript := preload("res://src/core/dungeon/generation/poisson_disk_sampler.gd")

const _SEEDS := 8


func _blue_noise(seed_value: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return SamplerScript.new(Vector2(11.0, 8.0)).generate(rng)


func test_the_nesting_order_holds() -> void:
	for seed_value in _SEEDS:
		var points := _blue_noise(seed_value)
		var delaunay := DelaunayScript.edges(points)
		var gabriel := GraphsScript.gabriel(points, delaunay)
		var relative := GraphsScript.relative_neighborhood(points, delaunay)
		var spanning := GraphsScript.minimum_spanning_tree(points, delaunay)

		_assert_subset(spanning, relative, "MST 가 RNG 에 들어 있지 않다")
		_assert_subset(relative, gabriel, "RNG 가 가브리엘에 들어 있지 않다")
		_assert_subset(gabriel, delaunay, "가브리엘이 들로네에 들어 있지 않다")


func test_each_step_is_sparser_than_the_next() -> void:
	# 포함 관계만 보면 전부 같은 그래프여도 통과한다. 실제로 성겨지는지 확인한다.
	var points := _blue_noise(5)
	var delaunay := DelaunayScript.edges(points)
	assert_lt(
		GraphsScript.relative_neighborhood(points, delaunay).size(),
		GraphsScript.gabriel(points, delaunay).size(),
		"RNG 가 가브리엘보다 성기지 않다"
	)
	assert_lt(GraphsScript.gabriel(points, delaunay).size(), delaunay.size(), "가브리엘이 들로네보다 성기지 않다")


func test_the_spanning_tree_connects_every_point() -> void:
	# V1 — 고립된 방은 존재하지 않는 것과 같다.
	for seed_value in _SEEDS:
		var points := _blue_noise(seed_value)
		var spanning := GraphsScript.minimum_spanning_tree(points, DelaunayScript.edges(points))
		assert_eq(spanning.size(), points.size() - 1, "신장 트리의 간선 수가 맞지 않다")
		assert_eq(
			_reachable_from(points.size(), spanning, 0).size(),
			points.size(),
			"시드 %d 의 신장 트리가 판을 다 잇지 못했다" % seed_value
		)


func test_the_relative_neighborhood_graph_is_connected() -> void:
	# 뼈대를 RNG 로 삼는 근거다. EMST 를 포함하므로 연결성이 공짜로 따라온다.
	for seed_value in _SEEDS:
		var points := _blue_noise(seed_value)
		var relative := GraphsScript.relative_neighborhood(points, DelaunayScript.edges(points))
		assert_eq(
			_reachable_from(points.size(), relative, 0).size(),
			points.size(),
			"시드 %d 의 RNG 가 끊겨 있다" % seed_value
		)


func test_the_relative_neighborhood_graph_keeps_cycles() -> void:
	# 순환이 없으면 나무이고, 나무면 판의 절반이 막다른 길이 된다 (§17.2).
	var points := _blue_noise(3)
	var relative := GraphsScript.relative_neighborhood(points, DelaunayScript.edges(points))
	assert_gt(relative.size(), points.size() - 1, "RNG 에 순환이 하나도 없다")


func test_merge_drops_duplicates() -> void:
	var first: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 2)]
	var second: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 3)]
	assert_eq(GraphsScript.merge(first, second).size(), 3, "방향만 뒤집힌 간선을 새것으로 봤다")


func test_a_point_in_the_middle_blocks_a_gabriel_edge() -> void:
	# 손으로 답을 아는 최소 사례. 가운데 점이 지름 원 안에 들어간다.
	var points := PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(2, 0.5)])
	var candidates: Array[Vector2i] = [Vector2i(0, 1)]
	assert_eq(GraphsScript.gabriel(points, candidates).size(), 0)
	assert_eq(GraphsScript.relative_neighborhood(points, candidates).size(), 0)


func _assert_subset(inner: Array[Vector2i], outer: Array[Vector2i], message: String) -> void:
	var lookup := {}
	for edge in outer:
		lookup[edge] = true
	for edge in inner:
		if not lookup.has(edge):
			fail_test(message)
			return
	assert_true(true)


func _reachable_from(count: int, edges: Array[Vector2i], start: int) -> Dictionary:
	var neighbors := {}
	for edge in edges:
		neighbors.get_or_add(edge.x, [] as Array[int]).append(edge.y)
		neighbors.get_or_add(edge.y, [] as Array[int]).append(edge.x)
	var seen := {start: true}
	var frontier: Array[int] = [start]
	while not frontier.is_empty():
		var current: int = frontier.pop_front()
		for neighbor in neighbors.get(current, [] as Array[int]) as Array[int]:
			if seen.has(neighbor):
				continue
			seen[neighbor] = true
			frontier.append(neighbor)
	assert_lte(seen.size(), count)
	return seen
