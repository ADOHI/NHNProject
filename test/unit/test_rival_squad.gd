extends GutTest
## 조우에 서는 상대 스쿼드를 덮는다.
##
## docs/design/24-npc-relations.md §24.29.
##
## 지켜야 할 것 넷 —
##
## 1. **여섯이 전부 세계의 인물이다.** 자리표시자면 관계도가 조우 앞에서 아무 일도 안 한다
## 2. **저쪽도 한 팀이다** — 한 소속에서 나온다. 서로 남남인 여섯은 스쿼드가 아니다
## 3. **아는 얼굴이 가끔 섞인다** — 무작위로 뽑으면 1% 도 안 섞인다 (§24.29.3)
## 4. **관계를 만들지 않는다.** 관계는 사건의 찌꺼기다 (§24.5)

const _SEED := 20260808
const _POPULATION := 600


func _world() -> NpcWorld:
	return NpcWorld.create(_SEED, _POPULATION)


func _rng(offset: int = 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _SEED + offset
	return rng


func _ours(world: NpcWorld) -> PackedInt32Array:
	var found := PackedInt32Array()
	for member in Guild.create_starting(_SEED, "시험 길드", world).members:
		found.append(member.person)
	return found


# ---------------------------------------------------------------- 자리가 찬다


func test_every_seat_is_a_real_person() -> void:
	var world := _world()
	var squad := RivalSquad.draw(world, _rng(), _ours(world))
	assert_eq(squad.size(), RivalSquad.SIZE)
	for member in squad.members:
		assert_true(world.registry.has(member), str(member))


func test_nobody_stands_twice() -> void:
	var world := _world()
	var seen := {}
	for member in RivalSquad.draw(world, _rng(), _ours(world)).members:
		assert_false(seen.has(member))
		seen[member] = true


func test_our_own_people_are_not_on_the_other_side() -> void:
	var world := _world()
	var ours := _ours(world)
	var squad := RivalSquad.draw(world, _rng(), ours)
	for member in squad.members:
		assert_false(Array(ours).has(member), "우리 대원이 상대 스쿼드에 설 수 없다")


func test_they_come_from_one_faction() -> void:
	# 저쪽도 한 길드다. 소속이 흩어지면 그냥 여섯 사람이다.
	var world := _world()
	var squad := RivalSquad.draw(world, _rng(), _ours(world))
	assert_ne(squad.faction, PersonRegistry.NO_FACTION)
	for member in squad.members:
		assert_eq(world.registry.faction_of(member), squad.faction, str(member))


func test_drawing_is_deterministic() -> void:
	var world := _world()
	var ours := _ours(world)
	assert_eq(
		Array(RivalSquad.draw(world, _rng(), ours).members),
		Array(RivalSquad.draw(world, _rng(), ours).members)
	)


func test_an_empty_world_gives_an_empty_squad() -> void:
	var squad := RivalSquad.draw(NpcWorld.create(_SEED, 0), _rng(), PackedInt32Array())
	assert_eq(squad.size(), 0)
	assert_eq(squad.faction, PersonRegistry.NO_FACTION)


# ---------------------------------------------------------------- 아는 얼굴


func test_familiar_faces_show_up_sometimes() -> void:
	# **가끔이라야 한다.** 매번이면 우연이 아니고, 한 번도 없으면 시스템이 안 보인다.
	var world := _world()
	var ours := _ours(world)
	var rng := _rng()
	var met := 0
	for trial in 200:
		if not RivalSquad.draw(world, rng, ours).familiar_to(ours).is_empty():
			met += 1
	assert_gt(met, 0, "아는 얼굴이 한 번은 섞여야 한다")
	assert_lt(met, 200, "매번 섞이면 우연이 아니다")


func test_familiar_counts_both_directions() -> void:
	# 내가 저 사람을 아는 것도, 저 사람이 나를 아는 것도 조우에서 뜻이 있다 (§24.8).
	var world := _world()
	var one_way := -1
	for slot in world.graph.size():
		var from := world.graph.slot_from(slot)
		if not world.graph.knows(world.graph.slot_to(slot), from):
			one_way = slot
			break
	assert_gte(one_way, 0, "한쪽만 아는 관계가 있어야 하는 시험이다")
	var knower := world.graph.slot_from(one_way)
	var known := world.graph.slot_to(one_way)
	assert_true(SocialReach.familiar(world.graph, knower, known))
	assert_true(SocialReach.familiar(world.graph, known, knower), "반대로 물어도 참이다")


func test_nobody_to_look_with_still_draws() -> void:
	# 플레이어와 무관한 두 무리가 만나는 경우다 (§24.11).
	var world := _world()
	var squad := RivalSquad.draw(world, _rng(), PackedInt32Array())
	assert_eq(squad.size(), RivalSquad.SIZE)
	assert_true(squad.familiar_to(PackedInt32Array()).is_empty())


# ---------------------------------------------------------------- 관계는 안 만든다


func test_meeting_creates_no_relation() -> void:
	# 조우는 사건이 아니다. 싸우거나 배신한 뒤에 RelationResolver 가 만든다.
	var world := _world()
	var before := world.graph.size()
	var rng := _rng()
	for trial in 20:
		RivalSquad.draw(world, rng, _ours(world))
	assert_eq(world.graph.size(), before)


# ------------------------------------------------- 이름을 들어 본 얼굴 (§24.42)


func test_a_famous_stranger_is_recognised() -> void:
	# 설계 24.7 — *"관계가 없어도 유명하면 상대가 나를 안다."*
	var world := NpcWorld.create(_SEED, _POPULATION)
	var squad := RivalSquad.new(world)
	squad.members = PackedInt32Array([0, 1])
	world.registry.gain_fame(1, PersonGenerator.FAME_MAX)
	assert_eq(Array(squad.famous_faces()), [1])
	assert_true(squad.familiar_to(PackedInt32Array([2])).is_empty(), "관계는 여전히 없다")


func test_fame_and_acquaintance_are_counted_apart() -> void:
	# **합치면 화면의 줄이 하나가 된다** — 겪어서 아는 사람에게는 관계 한 줄이 붙고
	# 유명해서 아는 사람에게는 「이름은 들어 봤다」밖에 못 쓴다 (§24.32.2).
	var world := NpcWorld.create(_SEED, _POPULATION)
	var squad := RivalSquad.new(world)
	squad.members = PackedInt32Array([0])
	world.graph.link(1, 0, RelationKind.Kind.COMRADESHIP, 40, 40)
	assert_eq(Array(squad.familiar_to(PackedInt32Array([1]))), [0], "겪어서 안다")
	assert_true(squad.famous_faces().is_empty(), "그렇다고 유명한 것은 아니다")


func test_the_threshold_has_one_source() -> void:
	# 도구들이 50 을 베껴 쓰고 있었다. 원본은 `PersonGenerator.FAME_KNOWN` 하나다.
	var world := NpcWorld.create(_SEED, _POPULATION)
	var squad := RivalSquad.new(world)
	squad.members = PackedInt32Array([0])
	world.registry.gain_fame(0, PersonGenerator.FAME_KNOWN - 1)
	assert_true(squad.famous_faces().is_empty())
	world.registry.gain_fame(0, 1)
	assert_eq(Array(squad.famous_faces()), [0])


func test_the_tier_is_a_pure_function() -> void:
	# **화면이 프레임마다 묻는다** (UI 킷). 난수도 시간도 안 쓰므로 답이 안 흔들려야 한다 —
	# 흔들리면 부품이 맑아졌다 흐려졌다 하고, 그건 노이즈가 아니라 고장이다.
	var world := NpcWorld.create(_SEED, _POPULATION)
	world.registry.gain_fame(1, PersonGenerator.FAME_MAX)
	var first := SocialReach.tier_of(world, 0, 1)
	for _try in 20:
		assert_eq(SocialReach.tier_of(world, 0, 1), first)
	assert_eq(first, SocialReach.Tier.HEARD_OF)


func test_being_known_beats_being_famous() -> void:
	# **부를 말이 있는 쪽이 이긴다.** *"이름은 들어 봤다"* 는 그 말이 없을 때 쓰는 말이다.
	var world := NpcWorld.create(_SEED, _POPULATION)
	world.registry.gain_fame(1, PersonGenerator.FAME_MAX)
	world.graph.link(0, 1, RelationKind.Kind.COMRADESHIP, 40, 40)
	assert_eq(SocialReach.tier_of(world, 0, 1), SocialReach.Tier.KNOWN)


func test_a_nobody_is_a_stranger() -> void:
	var world := NpcWorld.create(_SEED, _POPULATION)
	var quiet := -1
	for person in world.registry.size():
		if (
			world.graph.degree_of(person) == 0
			and not SocialReach.is_heard_of(world.registry, person)
		):
			quiet = person
			break
	assert_gt(quiet, -1, "관계도 이름값도 없는 사람이 있어야 하는 시험이다")
	assert_eq(SocialReach.tier_of(world, 0, quiet), SocialReach.Tier.STRANGER)


func test_nobody_sees_themselves() -> void:
	var world := NpcWorld.create(_SEED, _POPULATION)
	world.registry.gain_fame(0, PersonGenerator.FAME_MAX)
	assert_eq(SocialReach.tier_of(world, 0, 0), SocialReach.Tier.STRANGER)
