extends GutTest
## 사건 카탈로그 — **설계 24.5 의 표와 코드가 같은가.**
##
## `test_relation_event.gd` 에서 갈라 나왔다 (gdlint 공개 메서드 20개, §24.35.3).
## **저쪽은 공식과 부호를 덮고 이쪽은 값과 계열의 성질을 덮는다** —
## 사건을 붙일 때마다 느는 것은 이쪽이므로 여기가 계속 자란다.
##
## docs/design/24-npc-relations.md §24.21.4 · §24.34.1 · §24.36.1 · §24.38.1.


func _traits(values: Array) -> PackedInt32Array:
	var traits := PackedInt32Array()
	traits.resize(NpcAxis.count())
	for slot in values.size() / 2:
		traits[int(values[slot * 2])] = int(values[slot * 2 + 1])
	return traits


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


func test_the_solo_family_needs_no_target() -> void:
	# 설계 24.5 D · B 의 「한 일 그 자체」들은 **누구에게 한 일이 아니다** (§24.38.1).
	# 대상을 억지로 붙이면 설계 표에 없는 관계가 생긴다 (§24.34.2 가 지나침에서 막은 것).
	#
	# **이 목록을 늘릴 때는 설계 24.5 의 표에 「남기는 관계」 칸이 있는지부터 봐라.**
	# 칸이 없으면 대상이 없는 것이고, 있으면 대상이 있는 것이다.
	var solo := [
		RelationEvent.Kind.DEFECT,
		RelationEvent.Kind.BREAK_PACT,
		RelationEvent.Kind.FOUND_GUILD,
		RelationEvent.Kind.HEADLINE,
		RelationEvent.Kind.HAUL,
		RelationEvent.Kind.DELVE,
	]
	for kind in RelationEvent.count():
		var event := RelationEvent.of(kind as RelationEvent.Kind)
		var label := RelationEvent.label(kind as RelationEvent.Kind)
		assert_eq(event.needs_target, not solo.has(kind), label)
		if not event.needs_target:
			assert_eq(event.target_kind, RelationKind.Kind.NONE, label)
			assert_eq(event.actor_kind, RelationKind.Kind.NONE, label)
			assert_eq(event.target_affinity, 0, label)


func test_the_showy_family_matches_the_design_table() -> void:
	# 설계 24.5 B · D. **눈금 규칙(§24.21.4)이 수치를 낸다.**
	var pact := RelationEvent.of(RelationEvent.Kind.BREAK_PACT)
	assert_eq(pact.axis(NpcAxis.Kind.HIERARCHY), -RelationEvent.NOTCH_TWO)
	assert_eq(pact.axis(NpcAxis.Kind.HONEST), -RelationEvent.NOTCH_THREE)
	var founding := RelationEvent.of(RelationEvent.Kind.FOUND_GUILD)
	assert_eq(founding.axis(NpcAxis.Kind.HIERARCHY), -RelationEvent.NOTCH_ONE)
	assert_eq(founding.axis(NpcAxis.Kind.SHOWY), RelationEvent.NOTCH_TWO)
	assert_eq(RelationEvent.of(RelationEvent.Kind.HAUL).axis(NpcAxis.Kind.SHOWY), 33)
	assert_eq(RelationEvent.of(RelationEvent.Kind.DELVE).axis(NpcAxis.Kind.RECKLESS), 100)


func test_the_headline_is_showy_and_nothing_else() -> void:
	# 설계 24.5 가 공식을 설명할 때 든 예다 — *"벡터가 과시 하나뿐이라 과시형에게는 상,
	# 은둔형에게는 벌이 자동으로 나온다"*. **축이 하나 더 붙으면 그 예가 깨진다.**
	var event := RelationEvent.of(RelationEvent.Kind.HEADLINE)
	assert_eq(event.axis(NpcAxis.Kind.SHOWY), RelationEvent.NOTCH_THREE)
	assert_eq(event.magnitude(), RelationEvent.NOTCH_THREE, "과시 말고는 아무 축도 안 밟는다")
	assert_gt(event.alignment(_traits([NpcAxis.Kind.SHOWY, 90])), 0.0)
	assert_lt(event.alignment(_traits([NpcAxis.Kind.SHOWY, -90])), 0.0, "은둔형에게는 벌이다")


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
