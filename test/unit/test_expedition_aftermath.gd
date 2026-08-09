extends GutTest
## 원정이 관계에 남기는 것을 덮는다.
##
## docs/design/24-npc-relations.md §24.30, docs/design/02-overview.md §2.6.1.5.
##
## **「관계도가 악화된다」에 섞인 물음 셋을 따로 덮는다** —
##
## 1. **제거되면** 그 사람의 선이 사라지지 않고 **나가는 호감만** 내려간다
## 2. **같이 가면** 성패와 무관하게 유대가 오른다
## 3. **성향이 손잡이와 결과 사이에 든다** — 같은 판을 겪어도 사람마다 다르게 부서진다

const _SEED := 20260808
const _POPULATION := 400


func _world() -> NpcWorld:
	return NpcWorld.create(_SEED, _POPULATION)


func _guild(world: NpcWorld) -> Guild:
	return Guild.create_starting(_SEED, "시험 길드", world)


func _report(guild: Guild, outcome: ExpeditionReport.Outcome) -> ExpeditionReport:
	# **마지막 한 명만 남긴다.** 나간 사람만 후유증을 입으므로, 두엇만 내보내면
	# 관계가 있는 대원이 마침 집에 있어서 시험이 헛도는 일이 생긴다 (실제로 그랬다).
	var went: Array[String] = []
	var stayed: Array[String] = []
	for slot in guild.members.size():
		if slot < guild.members.size() - 1:
			went.append(guild.members[slot].id)
		else:
			stayed.append(guild.members[slot].id)
	return ExpeditionReport.new(
		"exp_0", Gate.new("gate_0", "붉은 회랑", GateRank.Kind.C, _SEED), outcome, 5, went, stayed
	)


## 후유증이 **보이는** 대원. 없으면 -1.
##
## 선이 있어야 하고 **실제로 입는 크기가 0 이 아니라야** 한다 — 무모하고 실리적인
## 사람은 아무렇지 않게 돌아온다 (`resilience_of`). 그것도 설계대로다.
func _member_with_ties(world: NpcWorld, guild: Guild) -> int:
	for slot in guild.members.size() - 1:
		var member := guild.members[slot]
		if not member.is_in_world() or world.graph.degree_of(member.person) == 0:
			continue
		if ExpeditionAftermath.shock_for(world.registry.traits_of(member.person)) > 0:
			return member.person
	return -1


func _traits(reckless: int, loyal: int) -> PackedInt32Array:
	var traits := PackedInt32Array()
	traits.resize(NpcAxis.count())
	traits[int(NpcAxis.Kind.RECKLESS)] = reckless
	traits[int(NpcAxis.Kind.LOYAL)] = loyal
	return traits


# ---------------------------------------------------------------- 같이 가면 굵어진다


func test_going_together_raises_the_bond() -> void:
	var world := _world()
	var guild := _guild(world)
	var one := guild.members[0].person
	var other := guild.members[1].person
	var before := world.graph.bond(one, other)
	ExpeditionAftermath.apply(guild, _report(guild, ExpeditionReport.Outcome.ESCAPED))
	assert_gt(world.graph.bond(one, other), before)


func test_a_failed_run_still_binds_them() -> void:
	# **실패의 대가는 유대가 아니라 후유증 쪽에 있다** (§24.12).
	var world := _world()
	var guild := _guild(world)
	var one := guild.members[0].person
	var other := guild.members[1].person
	var before := world.graph.bond(one, other)
	ExpeditionAftermath.apply(guild, _report(guild, ExpeditionReport.Outcome.DOWNED))
	assert_gt(world.graph.bond(one, other), before)


# ---------------------------------------------------------------- 제거되면


func test_being_downed_dims_the_way_they_see_others() -> void:
	# **몸은 복제된다** (설계 2.6.1.5). 사라지는 것은 그가 남을 보던 눈이다.
	var world := _world()
	var guild := _guild(world)
	var person := _member_with_ties(world, guild)
	assert_gte(person, 0, "관계가 있는 대원이 있어야 하는 시험이다")
	var others := world.graph.targets_of(person)
	var before := world.graph.affinity(person, others[0])
	ExpeditionAftermath.apply(guild, _report(guild, ExpeditionReport.Outcome.DOWNED))
	assert_lt(world.graph.affinity(person, others[0]), before)


func test_the_lines_are_not_cut() -> void:
	# 선이 사라지면 그 사람이 사라진 것이 된다. 몸은 복제되므로 안 사라진다.
	var world := _world()
	var guild := _guild(world)
	var person := guild.members[0].person
	var before := world.graph.degree_of(person)
	ExpeditionAftermath.apply(guild, _report(guild, ExpeditionReport.Outcome.DOWNED))
	assert_gte(world.graph.degree_of(person), before)


func test_the_other_side_still_likes_them() -> void:
	# **어긋난 관계가 남는다** — 상대는 여전히 좋아하는데 그가 상대를 못 믿는다.
	#
	# **세계를 둘 세워 나란히 놓는다.** 원정과 함께 세계도 한 틱 도므로(world.tick)
	# 한 세계만 보면 후유증인지 남의 사건인지 못 가른다 — 소문 문턱을 잴 때와 같은 수법이다
	# (§24.28.3). 같은 시드 · 같은 틱이라 **두 세계의 차이가 곧 후유증이다.**
	var calm := _world()
	var hurt := _world()
	var calm_guild := _guild(calm)
	var hurt_guild := _guild(hurt)
	var person := _member_with_ties(hurt, hurt_guild)
	assert_gte(person, 0, "관계가 있는 대원이 있어야 하는 시험이다")
	var others := hurt.graph.targets_of(person)

	ExpeditionAftermath.apply(calm_guild, _report(calm_guild, ExpeditionReport.Outcome.ESCAPED))
	ExpeditionAftermath.apply(hurt_guild, _report(hurt_guild, ExpeditionReport.Outcome.DOWNED))

	var shock := ExpeditionAftermath.shock_for(hurt.registry.traits_of(person))
	for other in others:
		assert_eq(
			calm.graph.affinity(person, other) - hurt.graph.affinity(person, other),
			shock,
			"나가는 선은 후유증만큼 내려간다"
		)
		assert_eq(
			calm.graph.affinity(other, person), hurt.graph.affinity(other, person), "들어오는 선은 안 움직인다"
		)


func test_escaping_shocks_nobody() -> void:
	var world := _world()
	var guild := _guild(world)
	assert_eq(ExpeditionAftermath.apply(guild, _report(guild, ExpeditionReport.Outcome.ESCAPED)), 0)


func test_a_world_less_guild_is_untouched() -> void:
	var guild := Guild.create_starting(_SEED)
	assert_eq(ExpeditionAftermath.apply(guild, _report(guild, ExpeditionReport.Outcome.DOWNED)), 0)


# ---------------------------------------------------------------- 성향이 사이에 든다


func test_the_reckless_endure_and_the_loyal_break() -> void:
	# **손잡이가 결과와 같으면 사람이 기계를 느낀다** (§24.29.3 의 원칙).
	assert_lt(
		ExpeditionAftermath.shock_for(_traits(95, -95)),
		ExpeditionAftermath.shock_for(_traits(-95, 95))
	)


func test_nobody_takes_the_knob_value_itself() -> void:
	# 손잡이 그대로를 맞는 사람이 흔하면 그 숫자가 화면에서 읽힌다.
	var world := _world()
	var same := 0
	for person in world.registry.size():
		if (
			ExpeditionAftermath.shock_for(world.registry.traits_of(person))
			== ExpeditionAftermath.SHOCK
		):
			same += 1
	assert_lt(float(same) / float(world.registry.size()), 0.02)


func test_resilience_stays_in_range() -> void:
	assert_almost_eq(ExpeditionAftermath.resilience_of(_traits(100, -100)), 1.0, 0.001)
	assert_almost_eq(ExpeditionAftermath.resilience_of(_traits(-100, 100)), 0.0, 0.001)
	assert_almost_eq(ExpeditionAftermath.resilience_of(_traits(0, 0)), 0.5, 0.001)


# ---------------------------------------------------------------- 세계가 돈다


func test_the_world_moves_while_i_am_in_the_dungeon() -> void:
	# **이것이 없으면 판을 돌려도 세계가 그대로다** (§24.30.5 의 실측).
	var world := _world()
	var guild := _guild(world)
	var before := world.ledger.size()
	ExpeditionAftermath.apply(guild, _report(guild, ExpeditionReport.Outcome.ESCAPED))
	assert_gte(world.ledger.size() - before, ExpeditionAftermath.WORLD_EVENTS)


func test_ticking_is_deterministic() -> void:
	var one := _world()
	var other := _world()
	one.tick(20)
	other.tick(20)
	assert_eq(one.graph.size(), other.graph.size())
	assert_eq(one.ledger.size(), other.ledger.size())


func test_a_tick_never_replays_old_events() -> void:
	# 굴린 사건이 대상을 못 찾으면 장부에 안 남는다. **넘치지만 않으면 된다** —
	# 넘치면 앞의 사건을 다시 굴린 것이다.
	var world := _world()
	var before := world.ledger.size()
	world.tick(7)
	assert_gt(world.ledger.size(), before)
	assert_lte(world.ledger.size(), before + 7)
