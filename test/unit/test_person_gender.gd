extends GutTest
## 성별과 성별을 아는 관계 라벨을 덮는다.
##
## docs/design/24-npc-relations.md §24.23.
##
## **초상 생성 모델이 계열마다 성별을 쏠리게 만들고 있었다** —
## 전투 7장 전부 남자, 감식 3장 전부 여자. 레코드가 그 쏠림을 굳히면
## 그 순간 **모델의 버릇이 우리 기획이 된다.**

const _SEED := 20260808
const _POPULATION := 1200


func _world() -> Array:
	var registry := PersonGenerator.new(_SEED, _POPULATION).generate()
	var graph := RelationGraph.new(registry.size())
	KinSeeder.new(_SEED, registry, graph).seed_all()
	return [registry, graph]


func test_gender_does_not_lean_by_discipline() -> void:
	# 초상 모델이 계열마다 쏠렸다. **레코드가 그 쏠림을 굳히면 안 된다** (§24.23.1).
	var registry: PersonRegistry = _world()[0]
	for kind in MemberDiscipline.count():
		var seen := 0.0
		var female := 0.0
		for person in registry.size():
			if int(registry.discipline_of(person)) != kind:
				continue
			seen += 1.0
			if registry.gender_of(person) == PersonGender.Kind.FEMALE:
				female += 1.0
		assert_gt(seen, 0.0)
		assert_almost_eq(
			female / seen, 0.5, 0.08, MemberDiscipline.label(kind as MemberDiscipline.Kind)
		)


func test_both_genders_exist() -> void:
	var registry: PersonRegistry = _world()[0]
	var seen := {}
	for person in registry.size():
		seen[int(registry.gender_of(person))] = true
	assert_eq(seen.size(), PersonGender.count())


func test_parents_are_male_because_surnames_are_paternal() -> void:
	# 성이 부계라 어머니는 성이 다르다. 성이 다른 부모를 만들면 혈연이 성으로 안 묶인다.
	var pair := _world()
	var registry: PersonRegistry = pair[0]
	var graph: RelationGraph = pair[1]
	var checked := 0
	for slot in graph.size():
		if graph.slot_kind(slot) != RelationKind.Kind.PARENT:
			continue
		checked += 1
		assert_eq(registry.gender_of(graph.slot_to(slot)), PersonGender.Kind.MALE)
	assert_gt(checked, 0, "부모가 하나는 있어야 하는 시험이다")


func test_sibling_label_follows_gender() -> void:
	var male := PersonGender.Kind.MALE
	var female := PersonGender.Kind.FEMALE
	var kind := RelationKind.Kind.SIBLING
	assert_eq(RelationKind.label_for(kind, male, male), "형제")
	assert_eq(RelationKind.label_for(kind, female, female), "자매")
	assert_eq(RelationKind.label_for(kind, male, female), "남매")
	assert_eq(RelationKind.label_for(kind, female, male), "남매")


func test_parent_and_child_labels_follow_gender() -> void:
	var male := PersonGender.Kind.MALE
	var female := PersonGender.Kind.FEMALE
	assert_eq(RelationKind.label_for(RelationKind.Kind.PARENT, female, male), "아버지")
	assert_eq(RelationKind.label_for(RelationKind.Kind.CHILD, male, female), "딸")
	assert_eq(RelationKind.label_for(RelationKind.Kind.MASTER, male, female), "스승")
