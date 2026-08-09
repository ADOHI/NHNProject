extends GutTest
## 사건 정의를 덮는다.
##
## 여기서 지켜야 할 것은 셋이다 (docs/design/24-npc-relations.md §24.21.4 · §24.25) —
##
## 1. **수치가 설계 표와 같다.** 사건 벡터는 기획이 확정한 값이라 코드가 원본이면서도
##    표와 어긋나면 안 된다
## 2. **부호가 안 뒤집힌다.** 축 순서를 바꾸면 조용히 반대가 되고 화면에는 안 보인다 —
##    실제로 그 사고가 났다 (§24.25)
## 3. **정규화가 축 개수를 지운다.** 축 셋짜리와 축 하나짜리가 같은 강도에서
##    같은 크기로 움직여야 강도가 뜻을 갖는다


func _traits(values: Array) -> PackedInt32Array:
	var traits := PackedInt32Array()
	traits.resize(NpcAxis.count())
	for slot in values.size() / 2:
		traits[int(values[slot * 2])] = int(values[slot * 2 + 1])
	return traits


# ---------------------------------------------------------------- 설계 표와 같은가


func test_betrayal_matches_the_design_table() -> void:
	# 설계 24.21.4 — 선 −66 · 의리 −100 · 정직 −100, 강도 55, 대상 호감 −70, 유대 +8.
	var event := RelationEvent.of(RelationEvent.Kind.BETRAYAL)
	assert_eq(event.axis(NpcAxis.Kind.GOOD), -RelationEvent.NOTCH_TWO)
	assert_eq(event.axis(NpcAxis.Kind.LOYAL), -RelationEvent.NOTCH_THREE)
	assert_eq(event.axis(NpcAxis.Kind.HONEST), -RelationEvent.NOTCH_THREE)
	assert_eq(event.strength, 55)
	assert_eq(event.target_affinity, -70)
	assert_eq(event.bond_gain, 8)


func test_cooperation_matches_the_design_table() -> void:
	var event := RelationEvent.of(RelationEvent.Kind.COOPERATION)
	assert_eq(event.axis(NpcAxis.Kind.LOYAL), RelationEvent.NOTCH_TWO)
	assert_eq(event.axis(NpcAxis.Kind.GOOD), RelationEvent.NOTCH_ONE)
	assert_eq(event.strength, 25)
	assert_eq(event.target_affinity, 18)
	assert_eq(event.bond_gain, 20)


func test_betrayal_raises_the_bond() -> void:
	# **이 설계의 전부다** — 호감은 무너지는데 유대는 오른다 (§24.21.4).
	var event := RelationEvent.of(RelationEvent.Kind.BETRAYAL)
	assert_lt(event.target_affinity, 0)
	assert_gt(event.bond_gain, 0, "배신은 관계를 더 무겁게 만든다")


func test_untouched_axes_are_zero() -> void:
	# 표에 없는 축은 0 이다 (§24.5). 0 이 아니면 정규화의 분모가 커져 반응이 옅어진다.
	var event := RelationEvent.of(RelationEvent.Kind.COOPERATION)
	assert_eq(event.axis(NpcAxis.Kind.RECKLESS), 0)
	assert_eq(event.axis(NpcAxis.Kind.HIERARCHY), 0)
	assert_eq(event.axis(NpcAxis.Kind.SHOWY), 0)


func test_every_kind_has_a_definition() -> void:
	for kind in RelationEvent.count():
		var event := RelationEvent.of(kind as RelationEvent.Kind)
		# **후유증만 벡터도 강도도 없다.** 모양이 다른 사건이라 크기를 성향에서 뽑는다
		# (ExpeditionAftermath). 사건으로 두는 이유는 열전이 사건 기록을 먹기 때문이다.
		if kind == RelationEvent.Kind.AFTERMATH:
			assert_eq(event.magnitude(), 0, "후유증은 벡터를 안 쓴다")
			continue
		assert_gt(event.magnitude(), 0, RelationEvent.label(kind as RelationEvent.Kind))
		assert_gt(event.strength, 0, RelationEvent.label(kind as RelationEvent.Kind))


# ---------------------------------------------------------------- 부호가 안 뒤집힌다


func test_vector_text_names_the_pole_not_the_sign() -> void:
	# **`-100` 을 그대로 내보내면 읽는 쪽이 NpcAxis 배열 순서를 알아야 한다** (§24.25).
	var text := RelationEvent.of(RelationEvent.Kind.BETRAYAL).vector_text()
	assert_string_contains(text, "실리")
	assert_string_contains(text, "기만")
	assert_string_contains(text, "악")
	assert_false(text.contains("-"), "부호가 나가면 해석을 요구하는 형식이다")


func test_cooperation_text_names_the_positive_poles() -> void:
	var text := RelationEvent.of(RelationEvent.Kind.COOPERATION).vector_text()
	assert_string_contains(text, "의리")
	assert_string_contains(text, "선")


func test_loyal_person_hates_a_betrayal() -> void:
	# 부호가 뒤집히면 여기가 먼저 깨진다 — 의리형이 배신을 반긴다고 나온다.
	var event := RelationEvent.of(RelationEvent.Kind.BETRAYAL)
	assert_lt(event.alignment(_traits([NpcAxis.Kind.LOYAL, 90])), 0.0)
	assert_gt(event.alignment(_traits([NpcAxis.Kind.LOYAL, -90])), 0.0)


# ---------------------------------------------------------------- 정규화


func test_alignment_is_bounded() -> void:
	var event := RelationEvent.of(RelationEvent.Kind.BETRAYAL)
	var extreme := _traits(
		[NpcAxis.Kind.GOOD, -100, NpcAxis.Kind.LOYAL, -100, NpcAxis.Kind.HONEST, -100]
	)
	assert_almost_eq(event.alignment(extreme), 1.0, 0.001)


func test_axis_count_does_not_change_the_scale() -> void:
	# 축 셋짜리(배신)와 축 하나짜리(전멸)가 같은 크기로 움직여야 강도가 뜻을 갖는다.
	var betrayal := RelationEvent.of(RelationEvent.Kind.BETRAYAL)
	var wipeout := RelationEvent.of(RelationEvent.Kind.WIPEOUT)
	var against_betrayal := _traits(
		[NpcAxis.Kind.GOOD, -100, NpcAxis.Kind.LOYAL, -100, NpcAxis.Kind.HONEST, -100]
	)
	var with_wipeout := _traits([NpcAxis.Kind.RECKLESS, 100])
	assert_almost_eq(betrayal.alignment(against_betrayal), wipeout.alignment(with_wipeout), 0.001)


func test_colourless_person_barely_moves() -> void:
	# 극이 없는 인물은 내적이 0 에 가깝다 (§24.21.6). 결함이 아니라 노린 것이다.
	var event := RelationEvent.of(RelationEvent.Kind.BETRAYAL)
	assert_eq(event.alignment(_traits([])), 0.0)


func test_wipeout_sweeps_and_others_do_not() -> void:
	# 전멸만 유대로 이웃을 훑는다 (§24.5 B).
	assert_true(RelationEvent.of(RelationEvent.Kind.WIPEOUT).sweeps_bonded)
	assert_false(RelationEvent.of(RelationEvent.Kind.BETRAYAL).sweeps_bonded)
	assert_false(RelationEvent.of(RelationEvent.Kind.COOPERATION).sweeps_bonded)


func test_wipeout_does_not_touch_the_dead() -> void:
	# 사망은 관계를 동결한다 (§24.5 D). 대상 유형이 NONE 인 것이 그 신호다.
	var event := RelationEvent.of(RelationEvent.Kind.WIPEOUT)
	assert_eq(event.target_kind, RelationKind.Kind.NONE)
	assert_eq(event.target_affinity, 0)
