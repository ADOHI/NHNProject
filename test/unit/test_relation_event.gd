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


func test_information_events_match_the_design_table() -> void:
	# 설계 24.5 C 의 넷 + 24.5 A 의 시체 털이. **눈금 규칙(§24.21.4)이 수치를 낸다.**
	var false_lead := RelationEvent.of(RelationEvent.Kind.FALSE_LEAD)
	assert_eq(false_lead.axis(NpcAxis.Kind.HONEST), -RelationEvent.NOTCH_THREE)
	assert_eq(false_lead.axis(NpcAxis.Kind.GOOD), -RelationEvent.NOTCH_TWO)
	var sell := RelationEvent.of(RelationEvent.Kind.SELL_INFO)
	assert_eq(sell.axis(NpcAxis.Kind.LOYAL), -RelationEvent.NOTCH_ONE)
	var snitch := RelationEvent.of(RelationEvent.Kind.SNITCH)
	assert_eq(snitch.axis(NpcAxis.Kind.HONEST), -RelationEvent.NOTCH_TWO)
	assert_eq(snitch.axis(NpcAxis.Kind.LOYAL), -RelationEvent.NOTCH_THREE)
	var loot := RelationEvent.of(RelationEvent.Kind.LOOT_BODY)
	assert_eq(loot.axis(NpcAxis.Kind.GOOD), -RelationEvent.NOTCH_TWO)
	assert_eq(loot.axis(NpcAxis.Kind.LOYAL), -RelationEvent.NOTCH_ONE)
	var defect := RelationEvent.of(RelationEvent.Kind.DEFECT)
	assert_eq(defect.axis(NpcAxis.Kind.HIERARCHY), -RelationEvent.NOTCH_THREE)


func test_the_same_notch_total_gives_the_same_size() -> void:
	# **밀고와 유기는 벡터 합이 같다** (Σ166). 규칙이 수치를 내는 것이지 사람이 짓는 것이
	# 아니므로 강도와 대상 호감도 같아야 한다 (§24.21.4).
	var snitch := RelationEvent.of(RelationEvent.Kind.SNITCH)
	var desert := RelationEvent.of(RelationEvent.Kind.DESERT)
	assert_eq(snitch.magnitude(), desert.magnitude())
	assert_eq(snitch.strength, desert.strength)
	assert_eq(snitch.target_affinity, desert.target_affinity)


func test_selling_information_pays_the_person_you_dealt_with() -> void:
	# **음수 벡터인데 대상 호감이 양수인 첫 사건이다** (§24.36.3).
	# 손해를 본 사람은 거래에 없다 — 그래서 이 사건은 세계를 어둡게 안 만든다.
	var event := RelationEvent.of(RelationEvent.Kind.SELL_INFO)
	assert_lt(event.axis(NpcAxis.Kind.LOYAL), 0, "의리를 밟는다")
	assert_gt(event.target_affinity, 0, "산 사람은 원하던 것을 받았다")


func test_looting_a_corpse_leaves_nothing_on_the_pair() -> void:
	# 대상이 죽어 있으므로 양쪽 슬롯이 다 안 생기고 **유족만 반응한다** (§24.36.1).
	var event := RelationEvent.of(RelationEvent.Kind.LOOT_BODY)
	assert_eq(event.actor_kind, RelationKind.Kind.NONE)
	assert_eq(event.target_kind, RelationKind.Kind.NONE)
	assert_eq(event.target_affinity, 0, "사망은 관계를 동결한다")
	assert_true(event.sweeps_bonded, "유족을 유대로 훑는다")


func test_only_defection_needs_no_target() -> void:
	# 설계 24.5 D 의 사건들은 **누구에게 한 일이 아니다.** 지금은 길드 이탈 하나뿐이고,
	# 대상을 억지로 붙이면 설계 표에 없는 관계가 생긴다 (§24.34.2 가 지나침에서 막은 것).
	for kind in RelationEvent.count():
		var event := RelationEvent.of(kind as RelationEvent.Kind)
		var label := RelationEvent.label(kind as RelationEvent.Kind)
		assert_eq(event.needs_target, kind != RelationEvent.Kind.DEFECT, label)


func test_every_axis_is_touched_by_some_event() -> void:
	# **축이 인물 화면에는 나오는데 아무 사건도 안 밟으면 그 축은 세계에서 죽어 있다.**
	# 사건 열 종까지 위계가 정확히 그랬다 (§24.36.2) — 이 시험이 그때 있었다면 잡혔다.
	var touched := {}
	for kind in RelationEvent.count():
		var event := RelationEvent.of(kind as RelationEvent.Kind)
		for axis in NpcAxis.count():
			if event.axis(axis as NpcAxis.Kind) != 0:
				touched[axis] = true
	for axis in NpcAxis.count():
		assert_true(touched.has(axis), NpcAxis.label(axis as NpcAxis.Kind))


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
