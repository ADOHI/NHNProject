extends GutTest
## 접선처가 세계에서 후보를 찾는 것을 덮는다.
##
## docs/design/24-npc-relations.md §24.13 · §24.27.
##
## **이것이 이 레인이 존재하는 이유다.** `RecruitProspect.can_recruit()` 이 늘 거짓이던 것을
## 풀려고 관계도를 만들었는데, **후보가 인물이 아니면 관계도를 볼 수가 없다.**
##
## 지켜야 할 것 넷 —
##
## 1. **후보가 세계의 인물이다.** 이름을 지어내면 관계가 없고 영입이 영원히 안 열린다
## 2. **연줄로 찾는다.** 3000명에서 아무나 뽑으면 판정이 늘 「모르는 사이」다
## 3. **판정이 붙어 나온다.** 화면이 왜 되는지 안 되는지 말할 수 있어야 한다
## 4. **세계가 없어도 안 깨진다.** 옛 경로가 아직 남아 있다

const _SEED := 20260808
const _POPULATION := 400


func _world() -> NpcWorld:
	return NpcWorld.create(_SEED, _POPULATION)


func _guild(world: NpcWorld) -> Guild:
	var guild := Guild.create_starting(_SEED, "시험 길드", world)
	guild.assignment.assign(guild.members[0].id, Facility.Kind.CONTACT_POINT)
	return guild


func _report(guild: Guild, number: int) -> ExpeditionReport:
	var gate := Gate.new("gate_0", "붉은 회랑", GateRank.Kind.C, _SEED)
	var garrison: Array[String] = []
	for member_id in guild.member_ids():
		garrison.append(member_id)
	return ExpeditionReport.new(
		"exp_%d" % number, gate, ExpeditionReport.Outcome.ESCAPED, 5, [] as Array[String], garrison
	)


## 원정 몇 번을 정산하고 **그동안 찾은 후보 전부**를 돌려준다.
##
## 명단(`guild.prospects`)만 보면 안 되는 이유가 있다 — 명단은 다섯 명까지고
## **오래된 것부터 밀려난다** (GuildBalance.PROSPECT_POOL_MAX). 대표가 아는 사람은
## 앞에서 먼저 나오므로, 스무 번 돌린 뒤의 명단에는 먼 사람만 남는다.
func _settle(guild: Guild, times: int) -> Array[RecruitProspect]:
	var found: Array[RecruitProspect] = []
	for number in times:
		var result := GuildSettlement.apply(guild, _report(guild, number), _SEED + number)
		if result != null:
			found.append_array(result.prospects_found)
	return found


# ---------------------------------------------------------------- 세계에 발을 딛는다


func test_guild_gets_a_leader_in_the_world() -> void:
	var world := _world()
	var guild := _guild(world)
	assert_ne(guild.leader_person, PersonRegistry.NO_PERSON)
	assert_gte(world.graph.degree_of(guild.leader_person), 2, "대표는 연줄이 있어야 한다")


func test_guild_without_a_world_has_no_leader() -> void:
	assert_eq(Guild.create_starting(_SEED).leader_person, PersonRegistry.NO_PERSON)


func test_unfinished_world_is_not_bound() -> void:
	# 세계가 다 서기 전에 물리면 관계가 반쪽인 채로 대표가 정해진다.
	var guild := Guild.create_starting(_SEED, "시험 길드", NpcWorld.new(_SEED, _POPULATION))
	assert_null(guild.world)
	assert_eq(guild.leader_person, PersonRegistry.NO_PERSON)


# ---------------------------------------------------------------- 후보가 인물이다


func test_prospects_are_real_people() -> void:
	var world := _world()
	var guild := _guild(world)
	_settle(guild, 3)
	assert_gt(guild.prospects.size(), 0)
	for prospect in guild.prospects:
		assert_true(prospect.is_in_world(), prospect.display_name)
		assert_eq(prospect.display_name, world.registry.name_of(prospect.person))
		assert_eq(prospect.discipline, world.registry.discipline_of(prospect.person))


func test_prospects_carry_a_judgement() -> void:
	var guild := _guild(_world())
	_settle(guild, 3)
	for prospect in guild.prospects:
		assert_not_null(prospect.standing, prospect.display_name)
		# 되든 안 되든 화면이 할 말이 있어야 한다.
		assert_true(prospect.can_recruit() or not prospect.blocked_reason().is_empty())


func test_the_first_prospects_are_people_the_leader_knows() -> void:
	# **접선처는 연줄로 사람을 찾는다.** 아무나 뽑으면 판정이 늘 「모르는 사이」로 막힌다.
	var world := _world()
	var guild := _guild(world)
	_settle(guild, 1)
	var first := guild.prospects[0]
	assert_true(
		world.graph.knows(guild.leader_person, first.person),
		"%s 는 대표가 아는 사람이라야 한다" % first.display_name
	)


func test_a_prospect_eventually_comes_through_someone() -> void:
	# 2홉이 이 설계의 값이다 — 후보가 누구인지가 아니라 **누구를 통해 왔는지**가 정보가 된다.
	var world := _world()
	var guild := _guild(world)
	_settle(guild, 12)
	var introduced := 0
	for prospect in guild.prospects:
		if prospect.introduced_by == PersonRegistry.NO_PERSON:
			continue
		introduced += 1
		assert_true(
			world.graph.knows(guild.leader_person, prospect.introduced_by),
			"소개한 사람은 대표가 아는 사람이라야 한다"
		)
	assert_gt(introduced, 0, "연줄로 온 후보가 하나는 있어야 한다")


func test_recruiting_actually_opens() -> void:
	# **관계도가 붙기 전에는 이 시험이 성립하지 않았다** — 늘 거짓이었다.
	var guild := _guild(_world())
	var open := 0
	for prospect in _settle(guild, 20):
		if prospect.can_recruit():
			open += 1
	assert_gt(open, 0, "연줄로 찾은 후보 중에는 데려올 수 있는 사람이 있어야 한다")


func test_the_same_person_is_not_listed_twice() -> void:
	var guild := _guild(_world())
	_settle(guild, 8)
	var seen := {}
	for prospect in guild.prospects:
		assert_false(seen.has(prospect.person), prospect.display_name)
		seen[prospect.person] = true


func test_same_seed_finds_the_same_people() -> void:
	var one := _guild(_world())
	var other := _guild(_world())
	_settle(one, 4)
	_settle(other, 4)
	for slot in one.prospects.size():
		assert_eq(one.prospects[slot].person, other.prospects[slot].person)


# ---------------------------------------------------------------- 세계가 없을 때


func test_without_a_world_prospects_are_made_up_and_blocked() -> void:
	# 옛 경로가 남아 있다. **지어낸 후보는 관계가 없어서 영원히 안 열리고,
	# 그것이 화면에 사유로 나간다** — 임시 판정을 넣는 것보다 낫다 (설계 6.1).
	var guild := Guild.create_starting(_SEED)
	guild.assignment.assign(guild.members[0].id, Facility.Kind.CONTACT_POINT)
	_settle(guild, 1)
	assert_gt(guild.prospects.size(), 0)
	for prospect in guild.prospects:
		assert_false(prospect.is_in_world())
		assert_false(prospect.can_recruit())
		assert_string_contains(prospect.blocked_reason(), "미구현")
