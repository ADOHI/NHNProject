extends GutTest
## 성향 딱지를 덮는다.
##
## 딱지가 상세 화면의 요약이고 나중에 서술 조각을 고르는 색인이 된다
## (docs/design/24-npc-relations.md §24.20.2). **부를 때마다 달라지면 둘 다 무너진다.**


func _traits(values: Array) -> PackedInt32Array:
	var packed := PackedInt32Array()
	for value in values:
		packed.append(int(value))
	return packed


func _pole(scale: int = 0) -> int:
	return TraitDistribution.POLE_MIN + scale


func test_no_poles_reads_as_colorless() -> void:
	# 빈칸으로 두면 화면에서 자료 누락으로 읽힌다.
	assert_eq(PersonTag.of(_traits([0, 10, -20, 30, -40, 50])), PersonTag.COLORLESS)


func test_single_pole_is_named() -> void:
	var traits := _traits([_pole(20), 0, 0, 0, 0, 0])
	assert_eq(PersonTag.of(traits), NpcAxis.positive_label(NpcAxis.Kind.RECKLESS))


func test_negative_pole_uses_the_other_name() -> void:
	var traits := _traits([-_pole(20), 0, 0, 0, 0, 0])
	assert_eq(PersonTag.of(traits), NpcAxis.negative_label(NpcAxis.Kind.RECKLESS))


func test_strongest_pole_comes_first() -> void:
	# 가장 센 성향이 그 사람을 부르는 말이 되어야 한다.
	var traits := _traits([_pole(5), 0, _pole(35), 0, 0, 0])
	var expected := NpcAxis.positive_label(NpcAxis.Kind.LOYAL)
	assert_true(PersonTag.of(traits).begins_with(expected), PersonTag.of(traits))


func test_extra_poles_are_counted_not_dropped() -> void:
	# 여섯 다 극인 인물이 1.8% 있다. 딱지가 화면을 밀어내지 않아야 한다.
	var traits := PackedInt32Array()
	for axis in NpcAxis.count():
		traits.append(_pole(axis))
	var tag := PersonTag.of(traits)
	var extra := NpcAxis.count() - PersonTag.MAX_NAMED
	assert_true(tag.ends_with("+%d" % extra), tag)


func test_named_count_never_exceeds_the_limit() -> void:
	var traits := PackedInt32Array()
	for _axis in NpcAxis.count():
		traits.append(_pole(10))
	var tag := PersonTag.of(traits)
	var named := tag.split(" ")
	# 마지막 토큰이 `+n` 이라 이름 개수는 그만큼 빠진다.
	assert_eq(named.size() - 1, PersonTag.MAX_NAMED)


func test_exactly_the_limit_has_no_counter() -> void:
	var traits := _traits([_pole(3), _pole(2), _pole(1), 0, 0, 0])
	assert_false(PersonTag.of(traits).contains("+"), PersonTag.of(traits))


func test_tag_is_stable_for_the_same_traits() -> void:
	# 같은 절댓값이 섞여 있어도 순서가 흔들리면 화면이 깜빡이고 서술 조각도 바뀐다.
	var traits := _traits([_pole(), _pole(), -_pole(), 0, 0, 0])
	assert_eq(PersonTag.of(traits), PersonTag.of(traits))
	assert_eq(Array(PersonTag.poles_of(traits)), Array(PersonTag.poles_of(traits)))


func test_ties_fall_back_to_axis_order() -> void:
	var traits := _traits([_pole(), _pole(), 0, 0, 0, 0])
	assert_eq(Array(PersonTag.poles_of(traits)), [0, 1])


func test_poles_only_reports_poles() -> void:
	var traits := _traits([_pole(), TraitDistribution.POLE_MIN - 1, 0, 0, 0, 0])
	assert_eq(Array(PersonTag.poles_of(traits)), [0])


func test_tag_avoids_missing_glyphs() -> void:
	# 폰트에 없는 글자는 웹에서만 두부가 된다 (docs/conventions.md §5.1).
	var traits := PackedInt32Array()
	for axis in NpcAxis.count():
		traits.append(_pole(axis))
	for forbidden in ["↔", "→", "·", "▲"]:
		assert_false(PersonTag.of(traits).contains(forbidden))
