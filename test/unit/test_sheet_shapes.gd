extends GutTest
## 인물 상세가 쓰는 **도형 셋**을 덮는다 — 성향 육각형 · 계열 도형 · 인구 눈금.
##
## docs/design/20-ui-kit.md §20.25.3 · §20.25.7.
##
## ## 왜 순수 계산으로 뗐나
##
## 「리소스가 없으니 도형과 선과 면으로만」이라는 제약 아래에서는 **도형이 곧 정보다.**
## 도형이 틀리면 글이 틀린 것과 같은데, **도형은 틀려도 여전히 그려진다** —
## 창을 띄워 눈으로 보기 전에는 아무도 모른다.
##
## 그래서 꼭짓점 계산을 `src/core/ui/` 로 떼어 **창 없이 잰다.**

const _SEED := 20260808
const _POPULATION := 300

const _CENTER := Vector2(200.0, 200.0)
const _RADIUS := 90.0


func _traits(values: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for value in values:
		out.append(int(value))
	return out


# ------------------------------------------------------- 성향 육각형


func test_the_wheel_has_one_point_per_axis() -> void:
	var points := TraitWheel.points(_traits([0, 0, 0, 0, 0, 0]), _CENTER, _RADIUS)
	assert_eq(points.size(), NpcAxis.count(), "꼭짓점이 축 수와 다르면 육각형이 아니다")


func test_the_sign_never_changes_the_radius() -> void:
	# §20.25.3 규칙 1 — 부호는 반지름이 아니라 **꼭짓점 이름**이 말한다.
	# 부호를 반지름에 섞으면 축 하나에 두 방향이 필요해지고 여섯 축이 열두 방향이 된다.
	for value in [100, 72, 60, 5]:
		assert_almost_eq(
			TraitWheel.ratio_of(value), TraitWheel.ratio_of(-value), 0.0001, "부호가 반지름을 바꿨다"
		)


func test_the_vertex_label_is_what_carries_the_sign() -> void:
	for axis in NpcAxis.count():
		var kind := axis as NpcAxis.Kind
		assert_eq(TraitWheel.vertex_label(axis, 80), NpcAxis.positive_label(kind))
		assert_eq(TraitWheel.vertex_label(axis, -80), NpcAxis.negative_label(kind))


func test_a_colourless_person_still_has_a_face() -> void:
	# 값이 전부 0 이면 꼭짓점 여섯이 한 점에 모여 **면이 사라지고 고장으로 읽힌다**
	# (§24.17.4 의 빈칸 규율과 같다).
	var points := TraitWheel.points(_traits([0, 0, 0, 0, 0, 0]), _CENTER, _RADIUS)
	for point in points:
		assert_true(point.distance_to(_CENTER) > 1.0, "무색한 사람의 육각형이 점이 됐다")


func test_the_pole_ring_sits_where_the_tag_boundary_is() -> void:
	# §20.25.3 규칙 2 — 점선 밖으로 나간 꼭짓점이 곧 딱지에 이름이 적히는 축이다.
	var ratio := TraitWheel.pole_ratio()
	assert_true(TraitWheel.ratio_of(TraitDistribution.POLE_MIN) >= ratio - 0.0001, "극인데 선 안이다")
	assert_true(TraitWheel.ratio_of(TraitDistribution.POLE_MIN - 1) < ratio, "극이 아닌데 선 밖이다")


func test_fullness_grows_with_how_pronounced_a_person_is() -> void:
	# §20.25.3 규칙 3 — 면적이 곧 「얼마나 뚜렷한가」다.
	var blank := TraitWheel.fullness(_traits([0, 0, 0, 0, 0, 0]))
	var some := TraitWheel.fullness(_traits([80, 0, 70, 0, 0, 0]))
	var full := TraitWheel.fullness(_traits([100, 100, 100, 100, 100, 100]))
	assert_true(blank < some, "뚜렷한 사람이 무색한 사람보다 안 크다")
	assert_true(some < full, "여섯 다 극인 사람이 가장 크지 않다")
	assert_almost_eq(full, 1.0, 0.001, "꽉 찬 육각형이 1 이 아니다")


func test_the_first_axis_stands_straight_up() -> void:
	# 기울어 있으면 「도형」이 아니라 「무늬」로 읽힌다.
	var top := TraitWheel.label_point(0, _CENTER, _RADIUS, 0.0)
	assert_almost_eq(top.x, _CENTER.x, 0.001)
	assert_true(top.y < _CENTER.y, "첫 축이 위를 안 본다")


func test_the_wheel_reads_the_numbers_the_section_carries() -> void:
	# **글과 도형이 같은 자료에서 나온다.** 칸이 원자료를 안 들고 있으면 뷰가
	# 화면에 적힌 글에서 숫자를 도로 파내게 되고, 서식이 바뀌면 조용히 틀린다.
	var registry := PersonGenerator.new(_SEED, _POPULATION).generate()
	var sections := PersonSheet.build(registry, 7, FactionIndex.new(registry))
	var traits := PersonSheet.section_of(sections, "성향").numbers
	assert_eq(traits.size(), NpcAxis.count(), "성향 칸이 원자료를 안 들고 있다")
	assert_eq(traits, registry.traits_of(7), "칸이 든 값이 인구의 값과 다르다")


# ------------------------------------------------------- 계열 도형


func test_every_discipline_gets_a_different_shape() -> void:
	# 변 수가 다르면 **색을 못 봐도** 갈린다. 실측에서 계열이 여섯을 가장 잘 갈랐다.
	var seen: Array[int] = []
	for kind in MemberDiscipline.count():
		var sides := DisciplineMark.sides(kind as MemberDiscipline.Kind)
		assert_true(sides >= 3, "변이 셋보다 적으면 면이 아니다")
		assert_false(seen.has(sides), "계열 둘이 같은 변 수를 쓴다")
		seen.append(sides)


func test_every_discipline_shape_has_the_sides_it_claims() -> void:
	for kind in MemberDiscipline.count():
		var discipline := kind as MemberDiscipline.Kind
		var points := DisciplineMark.points(discipline, _CENTER, _RADIUS)
		assert_eq(
			points.size(), DisciplineMark.sides(discipline), MemberDiscipline.label(discipline)
		)


func test_discipline_colours_differ_in_brightness_too() -> void:
	# 색맹이어도 밝기로 갈려야 한다.
	var lumas: Array[float] = []
	for kind in MemberDiscipline.count():
		lumas.append(DisciplineMark.fill(kind as MemberDiscipline.Kind).get_luminance())
	lumas.sort()
	for i in lumas.size() - 1:
		assert_true(lumas[i + 1] - lumas[i] > 0.04, "명도가 너무 가까운 계열 둘이 있다")


func test_the_unknown_do_not_stand_out_at_all() -> void:
	# 실측 — 유명세는 여섯을 **가르지 않는다.** 대부분 0 이고 한둘만 튄다.
	# 모두에게 조금씩 주면 「여섯이 다 좀 유명하다」가 된다.
	assert_eq(DisciplineMark.standout(0, 100), 0.0)
	assert_true(DisciplineMark.standout(20, 100) < 0.05, "무명에 가까운 사람이 눈에 띈다")
	assert_true(DisciplineMark.standout(100, 100) > 0.9, "가장 유명한 사람이 안 튄다")


# ------------------------------------------------------- 인구 눈금


func test_the_median_sits_inside_the_population() -> void:
	var registry := PersonGenerator.new(_SEED, _POPULATION).generate()
	var norms := PersonNorms.new(registry)
	assert_true(norms.has_marks(), "인구가 있는데 눈금이 없다")
	var below := 0
	for person in registry.size():
		if registry.threat_of(person) < norms.threat():
			below += 1
	assert_true(below < registry.size(), "중앙값이 인구 전체보다 위에 있다")


func test_an_empty_population_draws_no_marks() -> void:
	# **없는 눈금을 0 에 그으면 「인구 전체가 0 이다」라는 거짓말이 된다.**
	assert_false(PersonNorms.new(PersonRegistry.new()).has_marks())
	assert_false(PersonNorms.new(null).has_marks())


func test_the_threat_bars_carry_a_mark_when_norms_exist() -> void:
	var registry := PersonGenerator.new(_SEED, _POPULATION).generate()
	var sections := PersonSheet.build(
		registry,
		0,
		FactionIndex.new(registry),
		SheetDisclosure.Level.DEV,
		null,
		PersonNorms.new(registry)
	)
	var threat := PersonSheet.section_of(sections, "위협")
	assert_not_null(threat, "위협 칸이 없다")
	for field in threat.fields:
		assert_true(field.has_mark(), "%s 막대에 인구 눈금이 없다" % field.label)


func test_without_norms_the_bars_have_no_mark() -> void:
	var registry := PersonGenerator.new(_SEED, _POPULATION).generate()
	var sections := PersonSheet.build(registry, 0, FactionIndex.new(registry))
	for field in PersonSheet.section_of(sections, "위협").fields:
		assert_false(field.has_mark(), "인구를 안 줬는데 눈금이 생겼다")
