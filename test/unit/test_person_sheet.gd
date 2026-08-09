extends GutTest
## 인물 상세 내용을 덮는다.
##
## 여기서 지켜야 할 것은 셋이다 (docs/design/24-npc-relations.md §24.17) —
##
## 1. **다섯 칸이 다 있다.** 하나 빠지면 화면에 구멍이 난다
## 2. **빈칸은 왜 비었는지 말한다.** 사유가 없으면 고장으로 읽힌다
## 3. **가림은 상태를 내리기만 한다.** MISSING 을 건드리면
##    "아직 안 만들었다" 와 "당신이 모른다" 가 같은 말이 된다

const _SEED := 20260808
const _POPULATION := 200


func _world() -> PersonRegistry:
	return PersonGenerator.new(_SEED, _POPULATION).generate()


func _sheet(person: int = 0, level: int = SheetDisclosure.Level.DEV) -> Array[SheetSection]:
	var registry := _world()
	return PersonSheet.build(
		registry, person, FactionIndex.new(registry), level as SheetDisclosure.Level
	)


# ---------------------------------------------------------------- 칸이 다 있다


func test_every_declared_section_exists() -> void:
	var sections := _sheet()
	for title in PersonSheet.LEFT_TITLES + PersonSheet.RIGHT_TITLES:
		assert_not_null(PersonSheet.section_of(sections, str(title)), str(title))


func test_columns_do_not_overlap() -> void:
	# 같은 칸이 두 열에 들어가면 뷰가 두 번 그린다.
	for title in PersonSheet.LEFT_TITLES:
		assert_false(PersonSheet.RIGHT_TITLES.has(title), str(title))


func test_unknown_person_gives_nothing() -> void:
	assert_eq(_sheet(_POPULATION + 1).size(), 0)


# ---------------------------------------------------------------- 있는 자료


func test_head_carries_the_record() -> void:
	var registry := _world()
	var sections := PersonSheet.build(registry, 3, FactionIndex.new(registry))
	var head := PersonSheet.section_of(sections, "인물")
	var found := PackedStringArray()
	for field in head.fields:
		assert_true(field.is_filled(), field.label)
		found.append(field.value)
	assert_true(found.has(registry.name_of(3)), "이름이 머리에 있어야 한다")


func test_traits_show_the_tag_and_every_axis() -> void:
	var traits := PersonSheet.section_of(_sheet(), "성향")
	# 딱지 한 줄 + 축 여섯 줄.
	assert_eq(traits.fields.size(), NpcAxis.count() + 1)
	for field in traits.fields:
		assert_true(field.is_filled(), field.label)


## **막대가 차는 축과 딱지에 이름이 오르는 축이 정확히 같은 집합이어야 한다.**
##
## 생성기가 극이 아닌 축을 0~59 균등으로 뽑으므로 45 와 12 는 같은 주사위의 다른
## 눈이다. 45 에 막대를 그리면 굴림값을 신념으로 넘기게 된다 — 전체 축 칸의 29.1%가
## 그 구간이었다. 경계를 POLE_MIN 에 맞추면 두 집합이 겹친다.
func test_only_pole_axes_get_a_bar() -> void:
	var registry := _world()
	for person in [0, 1, 2, 3, 4, 5, 6, 7]:
		var traits := PersonSheet.section_of(PersonSheet.build(registry, person), "성향")
		assert_false(traits.fields[0].has_bar(), "딱지는 막대가 아니다")
		var values := registry.traits_of(person)
		for axis in NpcAxis.count():
			var field := traits.fields[axis + 1]
			assert_eq(
				field.has_bar(),
				TraitDistribution.is_pole(values[axis]),
				"%s 값 %d — 막대와 극이 갈라지면 안 된다" % [field.label, values[axis]]
			)
			if field.has_bar():
				assert_true(field.is_signed_bar, field.label)
	# **-1.0 은 정당한 축값이다.** 「없음」을 값으로 표시하면 축값 -100 인 사람의
	# 막대가 조용히 사라진다 (인구 3000 중 98 명).
	var full := SheetField.gauge("무모/신중", "-100 신중", -1.0)
	assert_true(full.has_bar(), "-1.0 이 「막대 없음」과 같은 값이면 안 된다")
	assert_almost_eq(full.bar, -1.0, 0.001, "값은 그대로 남는다")
	assert_false(SheetField.filled("딱지", "은둔").has_bar(), "막대를 안 단 줄은 없다고 나온다")


func test_fame_bar_is_unsigned() -> void:
	# 유명세는 0 부터 차오르는 값이라 왼쪽에서 자란다.
	var head := PersonSheet.section_of(_sheet(), "인물")
	for field in head.fields:
		if field.has_bar():
			assert_false(field.is_signed_bar, field.label)


func test_guild_reports_size_and_rank() -> void:
	var registry := _world()
	var factions := FactionIndex.new(registry)
	var person := _first_affiliated(registry)
	assert_gte(person, 0, "소속 있는 인물이 있어야 하는 시험이다")
	var guild := PersonSheet.section_of(PersonSheet.build(registry, person, factions), "길드")
	# 번호 · 인원 · 크기 순위 셋이 다 있어야 지프 분포가 읽힌다 (§24.17.6).
	var text: String = guild.fields[0].value
	assert_string_contains(text, "#%d" % registry.faction_of(person))
	assert_string_contains(text, "%d명" % factions.size_of(registry.faction_of(person)))
	assert_string_contains(
		text, "%d/%d" % [factions.rank_of(registry.faction_of(person)), factions.populated_count()]
	)


func test_unaffiliated_says_so() -> void:
	var registry := _world()
	var person := _first_unaffiliated(registry)
	assert_gte(person, 0, "무소속 인물이 있어야 하는 시험이다")
	var guild := PersonSheet.section_of(
		PersonSheet.build(registry, person, FactionIndex.new(registry)), "길드"
	)
	assert_eq(guild.fields[0].value, "무소속")


# ---------------------------------------------------------------- 빈칸


func test_absent_sections_explain_themselves() -> void:
	# 사유가 없으면 빈칸이 고장으로 읽힌다 (§24.17.4).
	var sections := _sheet()
	for title in ["생김새", "관계", "인물 열전"]:
		var section := PersonSheet.section_of(sections, str(title))
		assert_false(section.has_content(), str(title))
		for field in section.fields:
			assert_eq(field.state, SheetField.State.MISSING, field.label)
			assert_false(field.reason.is_empty(), "%s / %s" % [title, field.label])
			assert_eq(field.display_text(), field.reason)


func test_absent_reasons_point_at_a_design_section() -> void:
	# 그 자리를 채울 사람이 어디를 읽어야 하는지가 같이 나가야 한다.
	var sections := _sheet()
	for title in ["생김새", "관계", "인물 열전"]:
		for field in PersonSheet.section_of(sections, str(title)).fields:
			assert_string_contains(field.reason, "설계 24")


func test_relations_split_inborn_from_earned() -> void:
	# 가족은 바뀌지 않고 우호 · 원수는 변한다 (§24.18). 그 차이가 읽혀야 한다.
	var relations := PersonSheet.section_of(_sheet(), "관계")
	assert_eq(relations.fields.size(), 2)
	assert_string_contains(relations.fields[0].label, "태생")
	assert_string_contains(relations.fields[1].label, "얻은")


func test_chronicle_reserves_room_for_sentences() -> void:
	# 한 줄 라벨 자리로 잡으면 §24.20.2 의 조각 조합이 들어올 때 터진다.
	var chronicle := PersonSheet.section_of(_sheet(), "인물 열전")
	assert_eq(chronicle.shape, SheetSection.Shape.PARAGRAPHS)
	assert_gt(chronicle.expected_lines, 1)


func test_portrait_keeps_a_square_frame() -> void:
	# 채워졌을 때 배치가 움직이지 않아야 한다 (§24.20.4).
	var portrait := PersonSheet.section_of(_sheet(), "생김새")
	assert_eq(portrait.shape, SheetSection.Shape.FRAME)


func test_portrait_says_not_yet_made_not_never() -> void:
	# §24.8 의 두 계층은 폐기됐다 — 설계상 전원이 초상을 갖는다.
	var portrait := PersonSheet.section_of(_sheet(), "생김새")
	assert_string_contains(portrait.fields[0].reason, "미구현")


# ---------------------------------------------------------------- 가림


func test_dev_level_hides_nothing() -> void:
	for section in _sheet():
		for field in section.fields:
			assert_ne(field.state, SheetField.State.HIDDEN, field.label)


func test_clue_level_hides_traits() -> void:
	# 성향이 그대로 나가면 완전 공개가 되어 §5.4 가 무너진다.
	var traits := PersonSheet.section_of(_sheet(0, SheetDisclosure.Level.CLUE), "성향")
	for field in traits.fields:
		assert_eq(field.state, SheetField.State.HIDDEN, field.label)


func test_clue_level_leaves_missing_alone() -> void:
	# 없는 자료를 가리는 것은 뜻이 없고, 뭉개면 미구현을 게임 규칙으로 착각한다.
	var sections := _sheet(0, SheetDisclosure.Level.CLUE)
	for title in ["생김새", "관계", "인물 열전"]:
		for field in PersonSheet.section_of(sections, str(title)).fields:
			assert_eq(field.state, SheetField.State.MISSING, field.label)


func test_veiling_does_not_touch_the_original() -> void:
	# 개발 화면과 게임 화면이 한 판에 같이 떠 있을 수 있다.
	var section := SheetSection.new("성향", SheetSection.Shape.GAUGES, 1)
	section.add(SheetField.filled("딱지", "무모"))
	var veiled := SheetDisclosure.apply(section, SheetDisclosure.Level.CLUE)
	assert_eq(veiled.fields[0].state, SheetField.State.HIDDEN)
	assert_eq(section.fields[0].state, SheetField.State.FILLED, "원본이 바뀌면 안 된다")


func _first_affiliated(registry: PersonRegistry) -> int:
	for person in registry.size():
		if registry.faction_of(person) != PersonRegistry.NO_FACTION:
			return person
	return -1


func _first_unaffiliated(registry: PersonRegistry) -> int:
	for person in registry.size():
		if registry.faction_of(person) == PersonRegistry.NO_FACTION:
			return person
	return -1
