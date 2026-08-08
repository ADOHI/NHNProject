extends GutTest
## 인물 저장소를 덮는다.
##
## 성향 6축이 배열 하나에 stride 로 눕혀져 있어서(§24.16.1) **인덱스 계산이 틀리면
## 인물 A 의 성향을 B 가 갖는다.** 그런 오류는 수치라서 화면에 드러나지 않는다.
## 그래서 stride 접근을 여기서 못 박는다.

const _AXES := NpcAxis.Kind


func _traits(values: Array) -> PackedInt32Array:
	var packed := PackedInt32Array()
	for value in values:
		packed.append(int(value))
	return packed


func _person(registry: PersonRegistry, values: Array, fame: int = 0, faction: int = 0) -> int:
	return registry.add(
		"김지호", MemberDiscipline.Kind.COMBAT, 4, 1, faction, fame, 30, _traits(values)
	)


func test_registry_starts_empty() -> void:
	assert_eq(PersonRegistry.new().size(), 0, "관계도 성향도 명시적으로 만든 것만 있다")


func test_add_returns_running_index() -> void:
	var registry := PersonRegistry.new()
	assert_eq(_person(registry, [0, 0, 0, 0, 0, 0]), 0)
	assert_eq(_person(registry, [0, 0, 0, 0, 0, 0]), 1)
	assert_eq(registry.size(), 2)


func test_traits_do_not_bleed_between_people() -> void:
	# stride 계산이 틀리면 여기서만 잡힌다.
	var registry := PersonRegistry.new()
	_person(registry, [1, 2, 3, 4, 5, 6])
	_person(registry, [-1, -2, -3, -4, -5, -6])
	for axis in NpcAxis.count():
		assert_eq(registry.trait_of(0, axis as NpcAxis.Kind), axis + 1)
		assert_eq(registry.trait_of(1, axis as NpcAxis.Kind), -(axis + 1))


func test_traits_of_returns_only_that_person() -> void:
	var registry := PersonRegistry.new()
	_person(registry, [1, 2, 3, 4, 5, 6])
	_person(registry, [9, 9, 9, 9, 9, 9])
	assert_eq(Array(registry.traits_of(0)), [1, 2, 3, 4, 5, 6])
	assert_eq(registry.traits_of(1).size(), NpcAxis.count())


func test_wrong_axis_count_is_refused() -> void:
	# 성향이 반쪽이면 세계가 조용히 반쪽 성향을 갖는다. 조용한 실패가 가장 나쁘다.
	# 그래서 소리를 내는지까지 본다 — push_error 가 없으면 이 테스트가 실패한다.
	var registry := PersonRegistry.new()
	assert_eq(_person(registry, [1, 2, 3]), PersonRegistry.NO_PERSON)
	assert_eq(registry.size(), 0)
	assert_push_error("성향은 축")


func test_has_marks_registered_people_only() -> void:
	var registry := PersonRegistry.new()
	_person(registry, [0, 0, 0, 0, 0, 0])
	assert_true(registry.has(0))
	assert_false(registry.has(1))
	assert_false(registry.has(PersonRegistry.NO_PERSON))


func test_record_fields_survive_round_trip() -> void:
	var registry := PersonRegistry.new()
	var person := registry.add(
		"윤태산", MemberDiscipline.Kind.SCOUT, 2, 5, 7, 93, 41, _traits([0, 0, 0, 0, 0, 0])
	)
	assert_eq(registry.name_of(person), "윤태산")
	assert_eq(registry.discipline_of(person), MemberDiscipline.Kind.SCOUT)
	assert_eq(registry.threat_of(person), 2)
	assert_eq(registry.agility_of(person), 5)
	assert_eq(registry.faction_of(person), 7)
	assert_eq(registry.fame_of(person), 93)


func test_no_faction_is_distinct_from_faction_zero() -> void:
	# 소속 0 은 실재하는 소속이다. 없음과 섞이면 무소속이 한 소속으로 뭉친다.
	var registry := PersonRegistry.new()
	_person(registry, [0, 0, 0, 0, 0, 0], 0, PersonRegistry.NO_FACTION)
	_person(registry, [0, 0, 0, 0, 0, 0], 0, 0)
	assert_ne(registry.faction_of(0), registry.faction_of(1))


func test_pole_count_uses_the_shared_boundary() -> void:
	var registry := PersonRegistry.new()
	var edge := TraitDistribution.POLE_MIN
	_person(registry, [edge, -edge, edge - 1, 0, 0, 0])
	assert_eq(registry.pole_count_of(0), 2)


func test_summary_names_the_poles() -> void:
	var registry := PersonRegistry.new()
	_person(registry, [TraitDistribution.POLE_MIN, 0, 0, 0, 0, 0])
	var summary := registry.summary_of(0)
	assert_string_contains(summary, "김지호")
	assert_string_contains(summary, NpcAxis.positive_label(_AXES.RECKLESS))


func test_summary_marks_colorless_people() -> void:
	# 극이 없는 인물이 빈칸으로 나오면 화면에서 자료 누락처럼 보인다.
	var registry := PersonRegistry.new()
	_person(registry, [0, 0, 0, 0, 0, 0])
	assert_string_contains(registry.summary_of(0), "무색")
