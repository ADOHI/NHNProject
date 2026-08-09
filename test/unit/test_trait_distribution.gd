extends GutTest
## 성향 분포를 덮는다.
##
## **여기가 이 덩어리의 핵심이다.** 분포가 전원을 어중간하게 만들면
## §24.4 의 내적이 사람을 가르지 못하고, 그러면 관계도 사건도 뜻이 없다.
## 그래서 "인구가 뚜렷함으로 갈리는가" 를 수치로 못 박는다.

## 분포를 재려면 표본이 이만큼은 필요하다. 적으면 편차에 속는다.
const _SAMPLES := 4000

const _SEED := 20260808


func _rng(seed_value: int = _SEED) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _sampled_pole_counts() -> PackedInt32Array:
	var rng := _rng()
	var found := PackedInt32Array()
	found.resize(NpcAxis.count() + 1)
	for _person in _SAMPLES:
		var traits := TraitDistribution.sample_person(rng)
		var poles := 0
		for value in traits:
			if TraitDistribution.is_pole(value):
				poles += 1
		found[poles] += 1
	return found


# ---------------------------------------------------------------- 모양


func test_sample_returns_one_value_per_axis() -> void:
	assert_eq(TraitDistribution.sample_person(_rng()).size(), NpcAxis.count())


func test_values_stay_in_axis_range() -> void:
	var rng := _rng()
	for _person in 500:
		for value in TraitDistribution.sample_person(rng):
			assert_between(value, NpcAxis.MIN_VALUE, NpcAxis.MAX_VALUE)


func test_pole_boundary_matches_sampling_boundary() -> void:
	# 극의 경계가 표집 경계와 같아야 "저 사람은 무모한 사람이다" 가 레코드의 사실이 된다.
	assert_true(TraitDistribution.is_pole(TraitDistribution.POLE_MIN))
	assert_false(TraitDistribution.is_pole(TraitDistribution.POLE_MIN - 1))
	assert_true(TraitDistribution.is_pole(-TraitDistribution.POLE_MIN))


# ---------------------------------------------------------------- 뚜렷함


func test_population_splits_by_vividness() -> void:
	# 균등 난수의 진짜 문제는 "모든 인물이 통계적으로 똑같아진다" 는 것이었다 (§24.16.3).
	# 무색한 사람과 극단적인 사람이 **둘 다** 있어야 이 분포가 값을 한 것이다.
	var found := _sampled_pole_counts()
	assert_gt(found[0], 0, "극이 하나도 없는 사람이 있어야 한다")
	assert_gt(found[NpcAxis.count()], 0, "축 전부가 극인 사람도 있어야 한다")


func test_vivid_and_colorless_are_both_minorities() -> void:
	var found := _sampled_pole_counts()
	var colorless := float(found[0]) / float(_SAMPLES)
	var extreme := float(found[NpcAxis.count()]) / float(_SAMPLES)
	assert_lt(colorless, 0.15, "무색한 사람이 흔하면 세계가 무덤덤해진다")
	assert_lt(extreme, 0.15, "전 축이 극인 사람이 흔하면 극단이 특별하지 않다")


func test_pole_count_matches_declared_weights() -> void:
	# 가중치를 고치면 이 테스트가 따라온다 — 상수를 베껴 적지 않았으므로.
	var found := _sampled_pole_counts()
	for count in found.size():
		var measured := float(found[count]) / float(_SAMPLES)
		assert_almost_eq(measured, TraitDistribution.expected_ratio(count), 0.03)


func test_expected_pole_count_is_within_range() -> void:
	var expected := TraitDistribution.expected_pole_count()
	assert_between(expected, 1.0, float(NpcAxis.count()) - 1.0, "기대값이 끝에 붙으면 뚜렷함이 안 갈린다")


func test_measured_pole_count_matches_expectation() -> void:
	var found := _sampled_pole_counts()
	var total := 0.0
	for count in found.size():
		total += float(found[count]) * float(count)
	assert_almost_eq(total / float(_SAMPLES), TraitDistribution.expected_pole_count(), 0.1)


# ---------------------------------------------------------------- 방향의 독립


func test_axes_are_not_biased_toward_one_pole() -> void:
	# 축이 한쪽으로 기울면 세계 전체가 그 방향으로 쏠린다.
	var rng := _rng()
	var totals := PackedFloat32Array()
	totals.resize(NpcAxis.count())
	for _person in _SAMPLES:
		var traits := TraitDistribution.sample_person(rng)
		for axis in NpcAxis.count():
			totals[axis] += float(traits[axis])
	for axis in NpcAxis.count():
		assert_almost_eq(
			totals[axis] / float(_SAMPLES), 0.0, 6.0, NpcAxis.label(axis as NpcAxis.Kind)
		)


func test_no_axis_is_favoured_as_pole() -> void:
	# 어느 축이 극이 되는지 편향이 있으면 늘 같은 축에서만 사건이 갈린다.
	var rng := _rng()
	var poles := PackedFloat32Array()
	poles.resize(NpcAxis.count())
	for _person in _SAMPLES:
		var traits := TraitDistribution.sample_person(rng)
		for axis in NpcAxis.count():
			if TraitDistribution.is_pole(traits[axis]):
				poles[axis] += 1.0
	var share := TraitDistribution.expected_pole_count() / float(NpcAxis.count())
	for axis in NpcAxis.count():
		assert_almost_eq(poles[axis] / float(_SAMPLES), share, 0.03)


func test_opposing_axes_can_disagree() -> void:
	# §24.3 의 「내 팀을 살리려고 다른 팀을 털었다」 — 의리 + 이면서 선 − 인 인물.
	# 방향에 상관을 넣으면 이 조합이 사라지고 세계가 선인·악인 두 부류가 된다.
	var rng := _rng()
	var found := 0
	for _person in _SAMPLES:
		var traits := TraitDistribution.sample_person(rng)
		var loyal := traits[int(NpcAxis.Kind.LOYAL)]
		var good := traits[int(NpcAxis.Kind.GOOD)]
		if not TraitDistribution.is_pole(loyal) or not TraitDistribution.is_pole(good):
			continue
		if loyal > 0 and good < 0:
			found += 1
	assert_gt(found, 0, "의리는 강하고 선은 낮은 인물이 나와야 한다")


# ---------------------------------------------------------------- 결정론


func test_same_seed_gives_same_traits() -> void:
	# Packed 배열을 그대로 비교하지 않고 Array 로 옮긴다 — GUT 의 깊은 비교가 실패 지점을 알려 준다.
	var one := Array(TraitDistribution.sample_person(_rng()))
	var two := Array(TraitDistribution.sample_person(_rng()))
	assert_eq(one, two)


func test_different_seed_gives_different_traits() -> void:
	var one := Array(TraitDistribution.sample_person(_rng()))
	var other := Array(TraitDistribution.sample_person(_rng(_SEED + 1)))
	assert_ne(one, other)
