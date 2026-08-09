extends GutTest
## 세계에 사건을 굴리는 것을 덮는다.
##
## docs/design/24-npc-relations.md §24.5 · §24.11 · §24.24.
##
## 지켜야 할 것 셋 —
##
## 1. **같은 시드는 같은 세계다.** 초상 레인이 밤새 배치를 돌리는 근거가 이것이다
## 2. **나눠 돌려도 같다.** 웹은 단일 스레드라 조각으로 돌려야 한다 (§24.16.2)
## 3. **사건이 인구를 안 민다.** `PersonSeed.Field.EVENT` 가 생성 흐름과 갈려 있다

const _SEED := 20260808
const _POPULATION := 300


func _world() -> Array:
	var registry := PersonGenerator.new(_SEED, _POPULATION).generate()
	var graph := RelationGraph.new(registry.size())
	KinSeeder.new(_SEED, registry, graph).seed_all()
	return [registry, graph, RelationLedger.new()]


func _seed_all(world: Array, chunk: int = _POPULATION) -> EventSeeder:
	var seeder := EventSeeder.new(_SEED, world[0], world[1], world[2])
	while not seeder.seed_chunk(chunk):
		pass
	return seeder


## 그래프를 비교 가능한 문자열로. 슬롯 순서까지 같아야 결정론이다.
func _fingerprint(graph: RelationGraph) -> String:
	var parts := PackedStringArray()
	for slot in graph.size():
		(
			parts
			. append(
				(
					"%d>%d:%d/%d/%d"
					% [
						graph.slot_from(slot),
						graph.slot_to(slot),
						graph.slot_affinity(slot),
						graph.slot_bond(slot),
						int(graph.slot_kind(slot)),
					]
				)
			)
		)
	return "|".join(parts)


# ---------------------------------------------------------------- 사건이 실제로 난다


func test_events_add_relations() -> void:
	var world := _world()
	var before: int = (world[1] as RelationGraph).size()
	var seeder := _seed_all(world)
	assert_gt(seeder.event_count(), 0)
	assert_gt((world[1] as RelationGraph).size(), before, "사건이 관계를 더한다")
	assert_eq((world[2] as RelationLedger).size(), seeder.event_count())


func test_all_three_kinds_are_rolled() -> void:
	# 하나라도 안 나오면 그 사건은 굴려 본 적이 없는 코드가 된다.
	#
	# **후유증은 여기서 안 나온다** — 세계가 굴리는 사건이 아니라 내 원정이 남기는 것이라
	# `ExpeditionAftermath` 가 적는다. 그래서 가중치 표의 길이로 센다.
	var world := _world()
	_seed_all(world)
	var ledger: RelationLedger = world[2]
	var seen := {}
	for cause in ledger.size():
		seen[int(ledger.kind_of(cause))] = true
	assert_eq(seen.size(), EventSeeder.KIND_WEIGHTS.size())


func test_someone_ends_up_knowing_a_stranger() -> void:
	# **한쪽만 아는 관계가 사건에서만 나온다** (§24.21.2). 태생은 늘 양방향이다.
	var world := _world()
	_seed_all(world)
	var graph: RelationGraph = world[1]
	var one_way := 0
	for slot in graph.size():
		if not graph.knows(graph.slot_to(slot), graph.slot_from(slot)):
			one_way += 1
	assert_gt(one_way, 0, "비대칭이 화면에 드러나려면 여기서 나야 한다")


func test_sparsity_survives() -> void:
	# §24.2 가 인물당 2~4개로 못 박았다. 중위가 그 위로 올라가면 희소가 깨진 것이다.
	var world := _world()
	_seed_all(world)
	var graph: RelationGraph = world[1]
	var degrees := PackedInt32Array()
	for person in graph.person_count():
		degrees.append(graph.degree_of(person))
	degrees.sort()
	assert_lte(degrees[degrees.size() / 2], 4, "차수 중위가 예산 안에 있어야 한다")


# ---------------------------------------------------------------- 결정론


func test_same_seed_gives_the_same_world() -> void:
	var one := _world()
	var other := _world()
	_seed_all(one)
	_seed_all(other)
	assert_eq(_fingerprint(one[1]), _fingerprint(other[1]))


func test_chunking_does_not_change_the_result() -> void:
	# 한 번에 굴리든 열 개씩 굴리든 같아야 프레임 예산에 맞춰 나눌 수 있다.
	var whole := _world()
	var pieces := _world()
	_seed_all(whole)
	_seed_all(pieces, 7)
	assert_eq(_fingerprint(whole[1]), _fingerprint(pieces[1]))


func test_seeded_counts_up_to_the_total() -> void:
	var world := _world()
	var seeder := EventSeeder.new(_SEED, world[0], world[1], world[2])
	assert_false(seeder.seed_chunk(1))
	assert_eq(seeder.seeded(), 1)
	while not seeder.seed_chunk(50):
		pass
	assert_eq(seeder.seeded(), seeder.event_count())


func test_events_do_not_shift_the_population() -> void:
	# **초상 레인이 여기에 걸렸다** (§24.24.1) — 사건을 만들면 인구가 밀렸다.
	var before := PersonGenerator.new(_SEED, _POPULATION).generate()
	var world := _world()
	_seed_all(world)
	var after: PersonRegistry = world[0]
	for person in before.size():
		assert_eq(after.name_of(person), before.name_of(person), "인물 %d" % person)
		assert_eq(after.age_of(person), before.age_of(person), "인물 %d" % person)


func test_empty_world_rolls_nothing() -> void:
	var registry := PersonRegistry.new()
	var graph := RelationGraph.new(0)
	var seeder := EventSeeder.new(_SEED, registry, graph, RelationLedger.new())
	assert_eq(seeder.event_count(), 0)
	assert_true(seeder.seed_chunk(10))
