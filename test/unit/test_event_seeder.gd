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

## 「가중치 있는 사건이 다 굴려졌나」만 큰 세계를 쓴다.
##
## **표본이 가장 드문 사건보다 커야 한다.** 300명이면 사건이 50건이고 가중치 2% 짜리는
## 기댓값이 1 이라 **사건을 하나 붙일 때마다 이 시험이 동전 던지기가 된다.**
## 실제로 사건이 열다섯이 되자 전멸과 선제공격이 안 나와서 떨어졌다.
## 1500명이면 250건이고 2% 가 기댓값 5 다.
const _ROLL_POPULATION := 1500


func _world(population: int = _POPULATION) -> Array:
	var registry := PersonGenerator.new(_SEED, population).generate()
	var graph := RelationGraph.new(registry.size())
	KinSeeder.new(_SEED, registry, graph).seed_all()
	return [registry, graph, RelationLedger.new()]


func _seed_all(world: Array, chunk: int = _ROLL_POPULATION) -> EventSeeder:
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


func test_every_weighted_kind_is_rolled() -> void:
	# 하나라도 안 나오면 그 사건은 굴려 본 적이 없는 코드가 된다.
	#
	# **가중치 0 은 세지 않는다.** 후유증이 그렇다 — 세계가 굴리는 사건이 아니라
	# 내 원정이 남기는 것이라 `ExpeditionAftermath` 가 적는다.
	var world := _world(_ROLL_POPULATION)
	_seed_all(world)
	var ledger: RelationLedger = world[2]
	var seen := {}
	for cause in ledger.size():
		seen[int(ledger.kind_of(cause))] = true

	var wanted := 0
	for slot in EventSeeder.KIND_WEIGHTS.size():
		if int(EventSeeder.KIND_WEIGHTS[slot]) <= 0:
			assert_false(seen.has(slot), RelationEvent.label(slot as RelationEvent.Kind))
			continue
		wanted += 1
		assert_true(seen.has(slot), RelationEvent.label(slot as RelationEvent.Kind))
	assert_eq(seen.size(), wanted)


func test_weights_line_up_with_the_kinds() -> void:
	# **가중치 배열이 enum 과 나란하다.** 짧으면 뒤의 사건이 영영 안 굴려지고,
	# 가운데에 끼워 넣으면 모든 가중치가 조용히 다른 사건으로 옮겨 간다 —
	# 둘 다 화면에서는 안 보이고 세계가 달라진 것으로만 나타난다.
	assert_eq(EventSeeder.KIND_WEIGHTS.size(), RelationEvent.count())


func test_an_event_without_a_target_still_gets_rolled() -> void:
	# 길드 이탈은 대상이 없다 (§24.36.1). `_pick_targets` 가 빈 배열을 내는데
	# 그것을 「대상을 못 구했다」로 읽으면 이 사건은 한 번도 안 일어난다.
	var world := _world(_ROLL_POPULATION)
	_seed_all(world)
	var ledger: RelationLedger = world[2]
	var solo := 0
	for cause in ledger.size():
		if ledger.kind_of(cause) != RelationEvent.Kind.DEFECT:
			continue
		solo += 1
		assert_eq(ledger.targets_of(cause).size(), 0, "대상이 붙으면 안 된다")
	assert_gt(solo, 0, "길드 이탈이 한 번은 나야 한다")


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
