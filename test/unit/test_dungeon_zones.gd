extends GutTest
## 구역 분할의 단위 테스트.
##
## 구역은 간선 선택 · 고도 · 경로 시공이 **전부 그 위에 서는** 밑바탕이다
## (docs/design/17-dungeon-generation.md §17.17). 여기가 틀리면 뒤의 셋이 다 틀린다.
## 그래서 아직 아무도 부르지 않는 단계에서 성질을 못 박아 둔다.
##
## | 성질 | 왜 중요한가 |
## | --- | --- |
## | 모든 방이 정확히 한 구역에 속한다 | 빠진 방이 있으면 그 방은 어느 관문에도 안 걸린다 |
## | 입구 구역의 등급이 0 | 고도가 등급에서 나오므로 입구가 판에서 가장 낮아야 한다 (§17.3.6) |
## | 고리가 모든 구역을 잇는다 | 갈라진 판이 나오면 V1 이 깨진다 |
## | 구역이 셋 이상이면 고리가 순환이다 | 순환이 없으면 「돌아가는 길」이 원리적으로 없다 (§17.12.4-B) |
## | 관문은 들로네 간선이다 | 아니면 교차가 되살아난다 (V8) |
## | 같은 입력 -> 같은 구역 | 시드 고정이 깨지면 버그를 재현할 수 없다 (§17.7) |

const DelaunayScript := preload("res://src/core/dungeon/generation/delaunay_triangulation.gd")
const SamplerScript := preload("res://src/core/dungeon/generation/poisson_disk_sampler.gd")
const ZonesScript := preload("res://src/core/dungeon/generation/dungeon_zones.gd")

const _SEEDS := 8


func _points(seed_value: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return SamplerScript.new(Vector2(11.0, 8.0)).generate(rng)


func test_every_room_belongs_to_exactly_one_zone() -> void:
	for seed_value in _SEEDS:
		var points := _points(seed_value)
		var wanted := ZonesScript.count_for(points.size())
		var zones := ZonesScript.assign(points, 0, wanted)

		assert_eq(zones.size(), points.size(), "구역 배정이 방 개수와 다릅니다")
		for zone in zones:
			assert_between(zone, 0, wanted - 1, "구역 번호가 범위를 벗어났습니다")


func test_no_zone_is_empty() -> void:
	# 빈 구역이 있으면 그 구역의 관문과 등급이 허수가 된다.
	for seed_value in _SEEDS:
		var points := _points(seed_value)
		var wanted := ZonesScript.count_for(points.size())
		var zones := ZonesScript.assign(points, 0, wanted)

		var seen := {}
		for zone in zones:
			seen[zone] = true
		assert_eq(seen.size(), wanted, "빈 구역이 있습니다")


func test_only_the_entrance_zone_ranks_zero() -> void:
	# ranks() 는 시작 구역을 0 으로 두므로 그것만 확인하면 아무것도 확인하지 않는 셈이다.
	# **다른 구역이 전부 1 이상**이어야 고도가 등급에서 나올 때 입구가 판의 바닥이 된다.
	for seed_value in _SEEDS:
		var points := _points(seed_value)
		var entrance := seed_value % points.size()
		var wanted := ZonesScript.count_for(points.size())
		var zones := ZonesScript.assign(points, entrance, wanted)
		var delaunay := DelaunayScript.edges(points)
		var boundaries := ZonesScript.boundaries(delaunay, zones)
		var links := ZonesScript.ring(points, zones, boundaries, wanted, zones[entrance])
		var ranks := ZonesScript.ranks(links, zones[entrance], wanted)

		assert_eq(ranks[zones[entrance]], 0, "입구 구역의 등급이 0 이 아닙니다")
		for zone in wanted:
			if zone == zones[entrance]:
				continue
			assert_gte(ranks[zone], 1, "입구가 아닌 구역의 등급이 0 입니다")

		# 이웃한 구역끼리 등급이 1 을 넘게 벌어지면 BFS 가 아니라 다른 것이 된다.
		for link in links:
			assert_lte(absi(ranks[link.x] - ranks[link.y]), 1, "관문을 넘는데 등급이 2 이상 벌어집니다")


func test_the_ring_connects_every_zone() -> void:
	for seed_value in _SEEDS:
		var points := _points(seed_value)
		var wanted := ZonesScript.count_for(points.size())
		var zones := ZonesScript.assign(points, 0, wanted)
		var delaunay := DelaunayScript.edges(points)
		var boundaries := ZonesScript.boundaries(delaunay, zones)
		var links := ZonesScript.ring(points, zones, boundaries, wanted, zones[0])
		var ranks := ZonesScript.ranks(links, zones[0], wanted)

		var reached := _reachable_zones(links, zones[0], wanted)
		assert_eq(reached, wanted, "고리가 모든 구역을 잇지 못했습니다")
		for zone in wanted:
			assert_between(ranks[zone], 0, wanted, "구역 등급이 이상합니다")


func test_the_entrance_zone_sits_on_a_cycle() -> void:
	# 순환이 어딘가 있는 것으로는 모자라다. **입구가 그 위에 있어야** 두 경로가
	# 앞부분을 공유하지 않는다 (§17.12.4-B). 각도 고리만으로는 보장되지 않아서
	# 구역 8개에서 나무가 나왔고, 그래서 _close_cycle 을 넣었다.
	for seed_value in _SEEDS:
		var points := _points(seed_value)
		var wanted := ZonesScript.count_for(points.size())
		if wanted < 3:
			continue
		var entrance := seed_value % points.size()
		var zones := ZonesScript.assign(points, entrance, wanted)
		var delaunay := DelaunayScript.edges(points)
		var boundaries := ZonesScript.boundaries(delaunay, zones)
		var links := ZonesScript.ring(points, zones, boundaries, wanted, zones[entrance])

		assert_gt(links.size(), wanted - 1, "구역 연결이 나무입니다 (순환이 없습니다)")
		assert_true(_zone_on_cycle(links, wanted, zones[entrance]), "입구 구역이 순환 위에 없습니다")


func test_boundaries_only_hold_cross_zone_edges() -> void:
	for seed_value in _SEEDS:
		var points := _points(seed_value)
		var wanted := ZonesScript.count_for(points.size())
		var zones := ZonesScript.assign(points, 0, wanted)
		var delaunay := DelaunayScript.edges(points)
		var boundaries := ZonesScript.boundaries(delaunay, zones)

		for key in boundaries:
			for edge in boundaries[key] as Array[Vector2i]:
				assert_ne(zones[edge.x], zones[edge.y], "같은 구역 간선이 경계에 들어갔습니다")
				var pair := Vector2i(
					mini(zones[edge.x], zones[edge.y]), maxi(zones[edge.x], zones[edge.y])
				)
				assert_eq(pair, key, "경계 키가 구역 쌍과 다릅니다")


func test_every_gate_is_a_delaunay_edge() -> void:
	# 관문이 들로네 간선이 아니면 교차가 되살아난다 (V8).
	for seed_value in _SEEDS:
		var points := _points(seed_value)
		var wanted := ZonesScript.count_for(points.size())
		var zones := ZonesScript.assign(points, 0, wanted)
		var delaunay := DelaunayScript.edges(points)
		var boundaries := ZonesScript.boundaries(delaunay, zones)
		var links := ZonesScript.ring(points, zones, boundaries, wanted, zones[0])

		for link in links:
			var found := ZonesScript.gate(points, boundaries, link)
			assert_ne(found, Vector2i(-1, -1), "관문을 찾지 못했습니다: %s" % link)
			assert_true(_holds(delaunay, found), "관문이 들로네 간선이 아닙니다: %s" % found)


func test_the_gate_keeps_its_distance_from_other_rooms() -> void:
	# 최단 간선을 관문으로 잡았더니 통로가 방을 20 px 앞까지 스쳤다 (§17.17.6).
	# 여유가 되는 후보가 하나라도 있으면 관문은 반드시 그중에서 골라야 한다.
	for seed_value in _SEEDS:
		var points := _points(seed_value)
		var wanted := ZonesScript.count_for(points.size())
		var zones := ZonesScript.assign(points, 0, wanted)
		var delaunay := DelaunayScript.edges(points)
		var boundaries := ZonesScript.boundaries(delaunay, zones)

		for key in boundaries:
			var roomy := false
			for edge in boundaries[key] as Array[Vector2i]:
				if ZonesScript.clearance(points, edge) >= ZonesScript.CLEARANCE_MIN:
					roomy = true
					break
			if not roomy:
				continue
			var found := ZonesScript.gate(points, boundaries, key)
			assert_gte(
				ZonesScript.clearance(points, found),
				ZonesScript.CLEARANCE_MIN,
				"여유가 되는 후보가 있는데 관문이 방을 스친다"
			)


func test_the_gate_is_the_shortest_crossing_that_has_room() -> void:
	for seed_value in _SEEDS:
		var points := _points(seed_value)
		var wanted := ZonesScript.count_for(points.size())
		var zones := ZonesScript.assign(points, 0, wanted)
		var delaunay := DelaunayScript.edges(points)
		var boundaries := ZonesScript.boundaries(delaunay, zones)

		for key in boundaries:
			var found := ZonesScript.gate(points, boundaries, key)
			if ZonesScript.clearance(points, found) < ZonesScript.CLEARANCE_MIN:
				continue
			var span := points[found.x].distance_squared_to(points[found.y])
			for edge in boundaries[key] as Array[Vector2i]:
				if ZonesScript.clearance(points, edge) < ZonesScript.CLEARANCE_MIN:
					continue
				assert_lte(
					span,
					points[edge.x].distance_squared_to(points[edge.y]) + 1e-9,
					"여유가 되는 더 짧은 경계 간선이 있습니다"
				)


func test_the_same_input_gives_the_same_zones() -> void:
	for seed_value in _SEEDS:
		var points := _points(seed_value)
		var wanted := ZonesScript.count_for(points.size())
		var first := ZonesScript.assign(points, 0, wanted)
		var second := ZonesScript.assign(points, 0, wanted)
		assert_eq(first, second, "같은 입력이 다른 구역을 만들었습니다")


func test_zone_count_stays_in_range() -> void:
	for rooms in [1, 6, 12, 22, 32, 50, 64, 200]:
		var found := ZonesScript.count_for(rooms)
		assert_between(found, ZonesScript.ZONE_MIN, ZonesScript.ZONE_MAX, "구역 수가 범위를 벗어났습니다")


func test_zones_survive_a_board_too_small_to_split() -> void:
	# 방이 구역 수보다 적으면 나눌 수 없다. 죽지 않고 있는 만큼만 나눠야 한다.
	var points := PackedVector2Array([Vector2.ZERO, Vector2(1.0, 0.0)])
	var zones := ZonesScript.assign(points, 0, 5)
	assert_eq(zones.size(), 2, "작은 판에서 구역 배정이 깨졌습니다")
	assert_eq(ZonesScript.assign(PackedVector2Array(), 0, 3).size(), 0, "빈 판을 처리하지 못했습니다")


## 그 구역이 순환 위에 있는가. 이웃 둘이 그 구역을 지우고도 이어져 있으면 순환 위다.
func _zone_on_cycle(links: Array[Vector2i], count: int, zone: int) -> bool:
	var neighbours: Array[int] = []
	for link in links:
		if link.x == zone:
			neighbours.append(link.y)
		elif link.y == zone:
			neighbours.append(link.x)
	for slot in neighbours.size():
		for other in range(slot + 1, neighbours.size()):
			if _joined_without(links, count, zone, neighbours[slot], neighbours[other]):
				return true
	return false


## zone 을 지운 그래프에서 a 와 b 가 이어져 있는가.
func _joined_without(links: Array[Vector2i], count: int, zone: int, a: int, b: int) -> bool:
	if a == zone or b == zone:
		return false
	if a == b:
		return true
	var seen := {a: true}
	var frontier: Array[int] = [a]
	while not frontier.is_empty():
		var current: int = frontier.pop_front()
		for link in links:
			var other := -1
			if link.x == current:
				other = link.y
			elif link.y == current:
				other = link.x
			if other < 0 or other == zone or other >= count or seen.has(other):
				continue
			if other == b:
				return true
			seen[other] = true
			frontier.append(other)
	return false


## 구역 연결을 따라 입구 구역에서 닿을 수 있는 구역의 수.
func _reachable_zones(links: Array[Vector2i], start: int, count: int) -> int:
	var seen := {start: true}
	var frontier: Array[int] = [start]
	while not frontier.is_empty():
		var current: int = frontier.pop_front()
		for link in links:
			var other := -1
			if link.x == current:
				other = link.y
			elif link.y == current:
				other = link.x
			if other >= 0 and other < count and not seen.has(other):
				seen[other] = true
				frontier.append(other)
	return seen.size()


func _holds(edges: Array[Vector2i], edge: Vector2i) -> bool:
	for other in edges:
		if other == edge or other == Vector2i(edge.y, edge.x):
			return true
	return false
