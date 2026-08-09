extends GutTest
## 세계 하나를 세우는 순서를 덮는다.
##
## docs/design/24-npc-relations.md §24.18 · §24.16.2.
##
## 지켜야 할 것 셋 —
##
## 1. **순서가 지켜진다.** 인구 -> 태생 관계 -> 사건. 사건이 먼저 오면
##    유대가 0 이라 목격자 가중이 0 이고 첫 사건이 아무에게도 안 닿는다
## 2. **한 번에 세우든 조각으로 세우든 같다.** 웹은 단일 스레드라 나눠 돌려야 한다
## 3. **연줄이 있는 사람을 고를 수 있다** — 길드 대표가 그 사람이라야 접선처가 일한다

const _SEED := 20260808
const _POPULATION := 400


func _fingerprint(graph: RelationGraph) -> String:
	var parts := PackedStringArray()
	for slot in graph.size():
		var edge := (
			"%d>%d:%d/%d"
			% [
				graph.slot_from(slot),
				graph.slot_to(slot),
				graph.slot_affinity(slot),
				graph.slot_bond(slot),
			]
		)
		parts.append(edge)
	return "|".join(parts)


# ---------------------------------------------------------------- 순서


func test_stages_run_in_order() -> void:
	var world := NpcWorld.new(_SEED, _POPULATION)
	assert_eq(world.stage(), NpcWorld.Stage.POPULATION)
	var seen: Array[int] = []
	while not world.build_chunk():
		if not seen.has(int(world.stage())):
			seen.append(int(world.stage()))
	assert_eq(
		seen, [int(NpcWorld.Stage.POPULATION), int(NpcWorld.Stage.KIN), int(NpcWorld.Stage.EVENTS)]
	)
	assert_eq(world.stage(), NpcWorld.Stage.READY)


func test_nothing_is_ready_until_it_is() -> void:
	# 도구와 화면이 is_ready() 하나만 보고 기다린다. 중간에 참이 되면 빈 화면을 찍는다.
	var world := NpcWorld.new(_SEED, _POPULATION)
	while not world.build_chunk():
		assert_false(world.is_ready())
		assert_null(world.factions, "소속 색인은 마지막에 선다")
	assert_true(world.is_ready())
	assert_not_null(world.factions)


func test_relations_exist_before_events_are_rolled() -> void:
	# **태생 관계가 세계의 씨앗이다** (§24.18). 사건 단계에 들어설 때 이미 있어야 한다.
	var world := NpcWorld.new(_SEED, _POPULATION)
	while world.stage() != NpcWorld.Stage.EVENTS:
		world.build_chunk()
	assert_gt(world.graph.size(), 0, "사건이 굴러가기 전에 유대가 있어야 한다")
	assert_eq(world.ledger.size(), 0, "아직 사건은 없다")


func test_finished_world_has_everything() -> void:
	var world := NpcWorld.create(_SEED, _POPULATION)
	assert_eq(world.registry.size(), _POPULATION)
	assert_gt(world.graph.size(), 0)
	assert_gt(world.ledger.size(), 0)
	assert_eq(world.ledger.size(), world.event_count())


# ---------------------------------------------------------------- 나눠 돌려도 같다


func test_chunked_and_whole_agree() -> void:
	var whole := NpcWorld.create(_SEED, _POPULATION)
	var pieces := NpcWorld.new(_SEED, _POPULATION)
	while not pieces.build_chunk():
		pass
	assert_eq(_fingerprint(whole.graph), _fingerprint(pieces.graph))
	assert_eq(whole.ledger.size(), pieces.ledger.size())


func test_same_seed_gives_the_same_world() -> void:
	assert_eq(
		_fingerprint(NpcWorld.create(_SEED, _POPULATION).graph),
		_fingerprint(NpcWorld.create(_SEED, _POPULATION).graph)
	)


func test_another_seed_gives_another_world() -> void:
	assert_ne(
		_fingerprint(NpcWorld.create(_SEED, _POPULATION).graph),
		_fingerprint(NpcWorld.create(_SEED + 1, _POPULATION).graph)
	)


func test_building_past_the_end_is_harmless() -> void:
	var world := NpcWorld.create(_SEED, _POPULATION)
	var before := world.graph.size()
	assert_true(world.build_chunk())
	assert_eq(world.graph.size(), before)


func test_empty_world_does_not_crash() -> void:
	var world := NpcWorld.create(_SEED, 0)
	assert_true(world.is_ready())
	assert_eq(world.registry.size(), 0)
	assert_eq(world.pick_connected(RandomNumberGenerator.new()), PersonRegistry.NO_PERSON)


# ---------------------------------------------------------------- 연줄이 있는 사람


func test_picked_person_has_connections() -> void:
	# **관계 없는 사람을 길드 대표로 세우면 접선처가 아무도 못 찾는다.**
	# 인구의 4분의 1이 관계가 없으므로 그냥 뽑으면 넷 중 하나가 그렇게 된다.
	var world := NpcWorld.create(_SEED, _POPULATION)
	var rng := RandomNumberGenerator.new()
	for attempt in 20:
		rng.seed = attempt
		var person := world.pick_connected(rng)
		# **차수가 아니라 서로 아는 수다.** 차수만 크고 아무도 그를 모르는 사람이 있다 —
		# 전멸을 낸 인솔자가 죽은 사람들에게 한쪽 관계를 쌓는다.
		assert_gte(world.graph.mutuals_of(person).size(), 2, "시도 %d" % attempt)


func test_picking_is_deterministic() -> void:
	var world := NpcWorld.create(_SEED, _POPULATION)
	var one := RandomNumberGenerator.new()
	var other := RandomNumberGenerator.new()
	one.seed = _SEED
	other.seed = _SEED
	assert_eq(world.pick_connected(one), world.pick_connected(other))
