extends GutTest
## 나이와 태생 관계를 덮는다.
##
## 여기서 지켜야 할 것 (docs/design/24-npc-relations.md §24.22) —
##
## 1. **나이차가 말이 된다.** 부모는 위고 형제는 비슷하고 스승은 위다.
##    말이 안 되면 가족이 설계 24.5 가 경계한 「이유 없는 수치」가 된다
## 2. **혈연은 성이 같다.** 사용자가 지적한 자리다
## 3. **성이 같다고 가족은 아니다.** 확정되면 정보가 공짜가 된다 (§5.7)
## 4. **태생 관계는 사건이 유대를 못 깎는다** (§24.18)

const _SEED := 20260808
const _POPULATION := 1200


func _world() -> Array:
	var registry := PersonGenerator.new(_SEED, _POPULATION).generate()
	var graph := RelationGraph.new(registry.size())
	KinSeeder.new(_SEED, registry, graph).seed_all()
	return [registry, graph]


# ---------------------------------------------------------------- 나이


func test_age_stays_in_range() -> void:
	var registry: PersonRegistry = _world()[0]
	for person in registry.size():
		assert_between(registry.age_of(person), PersonGenerator.AGE_MIN, PersonGenerator.AGE_MAX)


func test_population_leans_young() -> void:
	# 위험한 직업이라 살아서 늙는 사람이 드물다 (§24.22.2).
	var registry: PersonRegistry = _world()[0]
	var older := 0
	for person in registry.size():
		if registry.age_of(person) >= 40:
			older += 1
	assert_lt(float(older) / float(registry.size()), 0.35, "마흔 넘은 탐험가가 흔하면 안 된다")


func test_the_young_are_rarely_famous() -> void:
	# 유명세는 누적이라 시간이 든다 (§24.7 · §24.22.4).
	var registry: PersonRegistry = _world()[0]
	var young := 0.0
	var young_known := 0.0
	var old := 0.0
	var old_known := 0.0
	for person in registry.size():
		var known := 1.0 if registry.fame_of(person) >= 50 else 0.0
		if registry.age_of(person) < 22:
			young += 1.0
			young_known += known
		elif registry.age_of(person) >= PersonGenerator.FAME_PRIME_AGE:
			old += 1.0
			old_known += known
	assert_gt(young, 0.0)
	assert_lt(young_known / young, old_known / maxf(old, 1.0), "어린 유명인이 더 드물어야 한다")


func test_the_young_are_not_barred_from_fame() -> void:
	# 어리다고 반드시 무명인 것이 아니라 드문 것이다. 계수의 아래끝이 0 이 아니다.
	assert_gt(PersonGenerator.FAME_YOUNG_FACTOR, 0.0)


# ---------------------------------------------------------------- 성


func test_blood_relatives_share_a_surname() -> void:
	# 사용자가 지적한 자리다 — 이름을 따로 뽑으면 가족이 성이 다르다.
	var pair := _world()
	var registry: PersonRegistry = pair[0]
	var graph: RelationGraph = pair[1]
	var checked := 0
	for slot in graph.size():
		if not RelationKind.shares_surname(graph.slot_kind(slot)):
			continue
		checked += 1
		assert_eq(
			registry.surname_of(graph.slot_from(slot)),
			registry.surname_of(graph.slot_to(slot)),
			RelationKind.label(graph.slot_kind(slot))
		)
	assert_gt(checked, 0, "혈연이 하나는 있어야 하는 시험이다")


func test_a_shared_surname_does_not_prove_kinship() -> void:
	# 확정되면 정보가 공짜가 된다 (§5.7 · §24.22.7).
	var pair := _world()
	var registry: PersonRegistry = pair[0]
	var graph: RelationGraph = pair[1]
	var strangers := 0
	for person in registry.size():
		if strangers > 0:
			break
		for other in range(person + 1, registry.size()):
			if registry.surname_of(person) != registry.surname_of(other):
				continue
			if not graph.knows(person, other):
				strangers += 1
				break
	assert_gt(strangers, 0, "성이 같은데 남인 사람이 있어야 한다")


func test_surnames_are_uneven() -> void:
	var registry: PersonRegistry = _world()[0]
	var sizes := {}
	for person in registry.size():
		var surname := registry.surname_of(person)
		sizes[surname] = int(sizes.get(surname, 0)) + 1
	var largest := 0
	var smallest := registry.size()
	for surname in sizes:
		largest = maxi(largest, int(sizes[surname]))
		smallest = mini(smallest, int(sizes[surname]))
	assert_gt(largest, smallest * 3, "흔한 성과 드문 성이 갈려야 한다")


func test_the_commonest_surname_fits_the_given_name_pool() -> void:
	# 성이 치우치면 이름 용량의 분모가 성 단위가 된다 (§24.22.7).
	var registry: PersonRegistry = _world()[0]
	var sizes := {}
	for person in registry.size():
		sizes[registry.surname_of(person)] = int(sizes.get(registry.surname_of(person), 0)) + 1
	var largest := 0
	for surname in sizes:
		largest = maxi(largest, int(sizes[surname]))
	assert_lt(largest * 2, MemberNames.given_capacity(), "가장 흔한 성이 이름 풀을 절반 넘게 쓰면 위험하다")


func test_names_still_never_repeat() -> void:
	var registry: PersonRegistry = _world()[0]
	var seen := {}
	for person in registry.size():
		seen[registry.name_of(person)] = true
	assert_eq(seen.size(), registry.size())


# ---------------------------------------------------------------- 나이차


func test_parents_are_older_by_a_generation() -> void:
	_assert_gap(RelationKind.Kind.PARENT, KinSeeder.PARENT_GAP_MIN, KinSeeder.PARENT_GAP_MAX)


func test_siblings_are_close_in_age() -> void:
	_assert_gap(RelationKind.Kind.SIBLING, 0, KinSeeder.SIBLING_GAP_MAX)


func test_masters_are_older_than_students() -> void:
	_assert_gap(RelationKind.Kind.MASTER, KinSeeder.MASTER_GAP_MIN, KinSeeder.MASTER_GAP_MAX)


func test_masters_share_a_discipline() -> void:
	# 기술을 물려받는 관계라 계열이 다르면 성립하지 않는다.
	var pair := _world()
	var registry: PersonRegistry = pair[0]
	var graph: RelationGraph = pair[1]
	for slot in graph.size():
		if graph.slot_kind(slot) != RelationKind.Kind.MASTER:
			continue
		assert_eq(
			registry.discipline_of(graph.slot_from(slot)),
			registry.discipline_of(graph.slot_to(slot))
		)


func _assert_gap(kind: RelationKind.Kind, low: int, high: int) -> void:
	var pair := _world()
	var registry: PersonRegistry = pair[0]
	var graph: RelationGraph = pair[1]
	var checked := 0
	for slot in graph.size():
		if graph.slot_kind(slot) != kind:
			continue
		checked += 1
		var gap := absi(
			registry.age_of(graph.slot_to(slot)) - registry.age_of(graph.slot_from(slot))
		)
		assert_between(gap, low, high, RelationKind.label(kind))
	assert_gt(checked, 0, "%s 가 하나는 있어야 하는 시험이다" % RelationKind.label(kind))


# ---------------------------------------------------------------- 씨앗과 희소


func test_kin_seeds_the_world_with_bond() -> void:
	# 유대가 전부 0 이면 §24.6 의 목격자 가중이 0 이라 첫 사건이 아무에게도 안 닿는다.
	var pair := _world()
	var registry: PersonRegistry = pair[0]
	var graph: RelationGraph = pair[1]
	var bonded := 0
	for person in registry.size():
		for other in graph.targets_of(person):
			if graph.bond(person, other) > 0:
				bonded += 1
				break
	assert_gt(float(bonded) / float(registry.size()), 0.4, "씨앗이 너무 적다")
	assert_lt(float(bonded) / float(registry.size()), 0.95, "전원이 가족이면 사건이 채울 자리가 없다")


func test_relations_stay_sparse() -> void:
	# §24.2 가 인물당 2~4개로 못 박았고 태생이 그 예산을 다 쓰면 안 된다.
	var pair := _world()
	var registry: PersonRegistry = pair[0]
	var graph: RelationGraph = pair[1]
	var total := 0
	for person in registry.size():
		total += graph.degree_of(person)
	assert_lt(float(total) / float(registry.size()), 2.0, "태생만으로 예산을 다 쓰면 안 된다")


func test_family_crosses_factions() -> void:
	# 형제가 다른 길드에 있어야 영입 전쟁에 쓸 것이 생긴다 (§24.22.5).
	var pair := _world()
	var registry: PersonRegistry = pair[0]
	var graph: RelationGraph = pair[1]
	var crossing := 0
	for slot in graph.size():
		if not RelationKind.shares_surname(graph.slot_kind(slot)):
			continue
		if registry.faction_of(graph.slot_from(slot)) != registry.faction_of(graph.slot_to(slot)):
			crossing += 1
	assert_gt(crossing, 0, "가족이 소속을 가로질러야 한다")


# ---------------------------------------------------------------- 결정론


func test_same_seed_gives_the_same_families() -> void:
	var one: RelationGraph = _world()[1]
	var other: RelationGraph = _world()[1]
	assert_eq(one.size(), other.size())
	for slot in one.size():
		assert_eq(one.slot_to(slot), other.slot_to(slot))
		assert_eq(one.slot_bond(slot), other.slot_bond(slot))
