extends GutTest
## 성향 6축의 정의를 덮는다.
##
## 축의 개수와 순서가 §24.4 의 내적을 지탱한다. 사건 벡터와 인물 성향이 같은 순서를
## 쓰지 않으면 내적이 조용히 틀리고, 틀린 것이 수치라서 화면에서 눈치챌 수 없다.

## 테마 폰트에 없는 글자들. 웹 빌드에서만 두부가 된다 (docs/conventions.md §5.1).
const _MISSING_GLYPHS := ["↔", "→", "←", "·", "▲", "▼"]


func test_axis_count_is_six() -> void:
	assert_eq(NpcAxis.count(), 6, "docs/design/24-npc-relations.md §24.3 이 여섯으로 확정했다")


func test_enum_matches_axis_count() -> void:
	assert_eq(int(NpcAxis.Kind.SHOWY), NpcAxis.count() - 1, "enum 마지막 값이 개수의 근거다")


func test_every_axis_has_both_poles_named() -> void:
	var seen := {}
	for axis in NpcAxis.count():
		var kind := axis as NpcAxis.Kind
		assert_false(NpcAxis.positive_label(kind).is_empty())
		assert_false(NpcAxis.negative_label(kind).is_empty())
		assert_false(seen.has(NpcAxis.label(kind)), "축 이름이 겹치면 화면에서 구분되지 않는다")
		seen[NpcAxis.label(kind)] = true


func test_labels_avoid_missing_glyphs() -> void:
	for axis in NpcAxis.count():
		var label := NpcAxis.label(axis as NpcAxis.Kind)
		for forbidden in _MISSING_GLYPHS:
			assert_false(label.contains(forbidden), "%s 에 %s 가 있다" % [label, forbidden])


func test_pole_label_follows_sign() -> void:
	var kind := NpcAxis.Kind.LOYAL
	assert_eq(NpcAxis.pole_label(kind, 80), NpcAxis.positive_label(kind))
	assert_eq(NpcAxis.pole_label(kind, -80), NpcAxis.negative_label(kind))


func test_clamp_keeps_values_in_range() -> void:
	assert_eq(NpcAxis.clamp_value(500), NpcAxis.MAX_VALUE)
	assert_eq(NpcAxis.clamp_value(-500), NpcAxis.MIN_VALUE)
	assert_eq(NpcAxis.clamp_value(7), 7)


func test_range_is_symmetric_around_zero() -> void:
	# 대칭이 아니면 사건 하나가 한쪽으로 치우쳐 세계가 기운다.
	assert_eq(NpcAxis.MIN_VALUE, -NpcAxis.MAX_VALUE)
