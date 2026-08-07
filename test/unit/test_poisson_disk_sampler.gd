extends GutTest
## 블루 노이즈 점 뿌리기의 단위 테스트.
##
## 이 샘플러의 두 성질이 그대로 "밀도가 고르다"의 정의다
## (docs/design/17-dungeon-generation.md §17.3).
## 판 전체에 대한 검증은 test_dungeon_layout.gd 가 하고,
## 여기서는 성질 자체가 성립하는지만 본다.

const SamplerScript := preload("res://src/core/dungeon/generation/poisson_disk_sampler.gd")

const _RADIUS := 1.0
const _SEEDS := 10

## 빈 구멍의 허용 반지름 (반지름 대비).
##
## 완전한 최대 집합이라면 1.0 이어야 한다. 후보를 유한 번(40회)만 던져 보고
## 포기하므로 드물게 한 자리가 비고, 실측 최댓값이 1.46 이었다.
## 이걸 1.0 으로 만들려면 시도 횟수를 크게 올려야 하는데,
## 생성이 느려지는 값을 판 하나에 점 한 개 차이로 치르는 것은 손해다.
const _MAX_HOLE := 1.6


func _sample(seed_value: int, region: Vector2) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return SamplerScript.new(region).generate(rng)


func test_points_are_never_closer_than_the_radius() -> void:
	for seed_value in _SEEDS:
		var points := _sample(seed_value, Vector2(12.0, 8.0))
		for i in points.size():
			for j in range(i + 1, points.size()):
				assert_gte(
					points[i].distance_to(points[j]),
					_RADIUS - 1e-6,
					"시드 %d 에서 두 점이 겹쳤다" % seed_value
				)


func test_points_stay_inside_the_region() -> void:
	var region := Vector2(10.0, 6.0)
	for point in _sample(3, region):
		assert_between(point.x, 0.0, region.x)
		assert_between(point.y, 0.0, region.y)


func test_the_region_is_filled_without_wide_holes() -> void:
	# 최대 푸아송 디스크 집합이라 영역 안 어디서든 근처에 점이 있어야 한다.
	# 이게 깨지면 판에 아무것도 없는 넓은 구역이 생긴다.
	var region := Vector2(12.0, 8.0)
	for seed_value in _SEEDS:
		var points := _sample(seed_value, region)
		assert_lte(
			_widest_hole(points, region), _RADIUS * _MAX_HOLE, "시드 %d 에 넓은 빈 구멍이 있다" % seed_value
		)


func test_the_same_seed_gives_the_same_points() -> void:
	assert_eq(_sample(99, Vector2(9.0, 6.0)), _sample(99, Vector2(9.0, 6.0)))


func test_different_seeds_give_different_points() -> void:
	assert_ne(_sample(1, Vector2(9.0, 6.0)), _sample(2, Vector2(9.0, 6.0)))


func test_the_count_lands_near_the_target() -> void:
	# 정확히 맞지는 않는다. 화면에 "방 N개 안팎"으로 적는 근거다.
	for target in [12, 22, 32]:
		var region: Vector2 = SamplerScript.region_for_count(target)
		var total := 0
		for seed_value in _SEEDS:
			total += _sample(seed_value * 7 + target, region).size()
		var average := float(total) / float(_SEEDS)
		assert_between(
			average,
			float(target) * 0.85,
			float(target) * 1.15,
			"목표 %d 인데 평균 %.1f 개가 나왔다" % [target, average]
		)


func test_an_empty_region_gives_no_points() -> void:
	assert_eq(_sample(1, Vector2.ZERO).size(), 0)


func test_a_bigger_region_holds_more_points() -> void:
	# 밀도가 크기와 무관해야 슬라이더가 판 규모만 바꾼다.
	assert_gt(_sample(5, Vector2(20.0, 14.0)).size(), _sample(5, Vector2(10.0, 7.0)).size())


func _widest_hole(points: PackedVector2Array, region: Vector2) -> float:
	var widest := 0.0
	var step := _RADIUS * 0.25
	var y := 0.0
	while y <= region.y:
		var x := 0.0
		while x <= region.x:
			var nearest := INF
			for point in points:
				nearest = minf(nearest, point.distance_to(Vector2(x, y)))
			widest = maxf(widest, nearest)
			x += step
		y += step
	return widest
