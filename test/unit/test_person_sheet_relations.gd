extends GutTest
## 관계도가 붙은 뒤의 인물 상세를 덮는다.
##
## `test_person_sheet.gd` 는 **관계도를 안 넘겼을 때**(빈칸)를 덮는다.
## 여기부터는 **세계가 다 선 뒤**다 — 인구 -> 태생 관계 -> 사건
## (docs/design/24-npc-relations.md §24.18 의 순서).
##
## 지켜야 할 것 넷 —
##
## 1. **관계 칸이 왼쪽 열을 안 넘긴다.** 실제로 넘겨 본 적이 있고 `--import` 은 0에러였다
## 2. **가까운 사람 · 척진 사람이 나온다**
## 3. **한쪽만 아는 관계가 표시된다** — 비대칭이 화면에 드러나는 유일한 자리다 (§24.21.2)
## 4. **왜 그런지가 열전으로 이어진다** — 관계 줄의 번호가 열전 줄을 가리킨다

const _SEED := 20260808
const _POPULATION := 200


## 인구 · 가족 · 사건까지 세운 세계. **세우는 순서는 NpcWorld 가 안다.**
func _live_world() -> NpcWorld:
	return NpcWorld.create(_SEED, _POPULATION)


func _live_sheet(world: NpcWorld, person: int) -> Array[SheetSection]:
	return PersonSheet.build(
		world.registry, person, world.factions, SheetDisclosure.Level.DEV, world.graph, world.ledger
	)


func test_relation_section_never_outgrows_its_column() -> void:
	# **화면 밖으로 밀려 본 적이 있다.** 왼쪽 열은 초상 액자가 340 을 먹어서
	# 관계 칸에 일곱 줄밖에 안 남는다 (§24.20.4). 자료가 늘어도 이 수를 넘으면 안 된다.
	var world := _live_world()
	for person in world.registry.size():
		var section := PersonSheet.section_of(_live_sheet(world, person), "관계")
		assert_lte(section.fields.size(), PersonSheet.RELATION_ROWS, "인물 %d" % person)


func test_earned_relations_show_up_somewhere() -> void:
	# 사건을 굴렸는데 화면에 우호 · 원수가 하나도 안 나오면 이어진 데가 끊긴 것이다.
	var world := _live_world()
	var found := false
	for person in world.registry.size():
		for field in PersonSheet.section_of(_live_sheet(world, person), "관계").fields:
			if field.label == "가까운 사람" or field.label == "척진 사람":
				found = true
				break
	assert_true(found, "가까운 사람 · 척진 사람이 나와야 한다")


func test_one_sided_relations_are_marked() -> void:
	# **A 가 B 를 아는데 B 는 A 를 모르는 일**이 화면에 드러나야 한다 (§24.21.2).
	var world := _live_world()
	var graph := world.graph
	var person := -1
	for slot in graph.size():
		if not graph.knows(graph.slot_to(slot), graph.slot_from(slot)):
			person = graph.slot_from(slot)
			break
	assert_gte(person, 0, "한쪽만 아는 관계가 있어야 하는 시험이다")
	var marked := false
	for field in PersonSheet.section_of(_live_sheet(world, person), "관계").fields:
		if field.label.contains("한쪽만"):
			marked = true
	assert_true(marked, "%s 의 화면에 한쪽만 아는 관계가 적혀야 한다" % world.registry.name_of(person))


func test_relation_lines_carry_both_axes() -> void:
	# 호감과 유대를 같이 내야 "깊이 엮인 채로 증오하는 사이" 가 읽힌다 (§24.2).
	var world := _live_world()
	for person in world.registry.size():
		for field in PersonSheet.section_of(_live_sheet(world, person), "관계").fields:
			if not field.is_filled() or field.value.ends_with("명"):
				continue
			assert_string_contains(field.value, "호감")
			assert_string_contains(field.value, "유대")


func test_chronicle_tells_the_story_behind_the_numbers() -> void:
	# **왜 그런지가 보여야 한다** (§24.2). 관계 줄의 대괄호 번호가 열전 줄을 가리킨다.
	var world := _live_world()
	var ledger := world.ledger
	var graph := world.graph
	var person := -1
	for slot in graph.size():
		var from := graph.slot_from(slot)
		if (
			not RelationKind.is_inborn(graph.slot_kind(slot))
			and ledger.has(graph.cause_of(from, graph.slot_to(slot)))
		):
			person = from
			break
	assert_gte(person, 0, "사건이 만든 관계가 있어야 하는 시험이다")

	var sections := _live_sheet(world, person)
	var marks := PackedStringArray()
	for field in PersonSheet.section_of(sections, "관계").fields:
		if field.value.contains("["):
			marks.append(field.value.get_slice("[", 1).get_slice("]", 0))
	var told := PackedStringArray()
	for field in PersonSheet.section_of(sections, "인물 열전").fields:
		if field.label.begins_with("["):
			told.append(field.label.trim_prefix("[").trim_suffix("]"))
	for mark in marks:
		assert_true(Array(told).has(mark), "관계가 가리킨 사건 %s 가 열전에 있어야 한다" % mark)


func test_chronicle_says_what_i_was() -> void:
	var world := _live_world()
	var ledger := world.ledger
	var graph := world.graph
	var person := ledger.actor_of(0)
	assert_gt(ledger.causes_of(graph, person).size(), 0)
	var found := false
	for field in PersonSheet.section_of(_live_sheet(world, person), "인물 열전").fields:
		if field.is_filled():
			assert_string_contains(field.value, "나는")
			found = true
	assert_true(found)


func test_narration_stays_missing() -> void:
	# 사건이 생겨도 **문장 조각은 여전히 빌드 타임 자산을 기다린다** (§24.20.2).
	var world := _live_world()
	var chronicle := PersonSheet.section_of(_live_sheet(world, 0), "인물 열전")
	var last := chronicle.fields[chronicle.fields.size() - 1]
	assert_eq(last.state, SheetField.State.MISSING)
	assert_string_contains(last.reason, "문장 조각")
