class_name GuildSettlement
extends RefCounted
## 원정 하나를 아지트에 반영한다. **이 시스템의 심장이다.**
##
##     ExpeditionReport + Guild  ->  SettlementResult
##
## 여기서 배치가 값이 된다. 공방에 남긴 사람은 진척이 되고, 접선처에 남긴 사람은
## 후보가 되고, 정보실에 남긴 사람은 다음 게이트 목록을 밝힌다
## (docs/design/22-guild-base.md §22.6).
##
## ## 두 번 적용되지 않는다
##
## 길드가 **처리한 원정 번호를 기억한다** (Guild.mark_settled).
## 보고서 쪽 플래그만 쓰면 보고서를 복제해 오는 순간 뚫린다.
## 장부가 더 강한 보증이므로 판단의 근거를 그쪽에 두었고,
## 보고서의 is_settled 는 화면용 표시일 뿐이다.
##
## ## 정산은 던전을 모른다
##
## 입력은 ExpeditionReport 뿐이다. 여기서 DungeonRun 을 읽기 시작하면
## 아웃게임이 인게임 구조에 묶이고, 인게임이 바뀔 때마다 정산을 다시 짜게 된다.


## 정산한다. 이미 정산된 원정이면 null 을 돌려준다.
##
## 예외를 던지지 않고 null 로 돌려주는 이유는, 두 번 누르는 것이
## 오류가 아니라 흔한 조작이기 때문이다. 화면은 null 을 보고 그냥 아무것도 안 하면 된다.
static func apply(
	guild: Guild, report: ExpeditionReport, prospect_seed: int = 0
) -> SettlementResult:
	if guild == null or report == null:
		return null
	if not guild.mark_settled(report.id):
		return null

	var absent := report.deployed_ids
	var result := SettlementResult.new()
	result.workshop_staff = guild.staff_at(Facility.Kind.WORKSHOP, absent)
	result.contact_staff = guild.staff_at(Facility.Kind.CONTACT_POINT, absent)

	result.funds_gained = report.loot_funds
	guild.add_funds(result.funds_gained)

	result.base_progress_gained = GuildBalance.base_progress_for(result.workshop_staff)
	result.levels_gained = guild.add_base_progress(result.base_progress_gained)

	result.prospects_found = _find_prospects(guild, result.contact_staff, prospect_seed)
	for prospect in result.prospects_found:
		guild.add_prospect(prospect)

	report.is_settled = true
	return result


## 접선처가 이번에 찾아낸 후보들.
##
## **여기까지가 접선처의 일이다.** 영입 실행은 없다
## (RecruitProspect 참고, docs/design/06-progression.md §6.1).
##
## 세계가 물려 있으면 **인구에서 뽑고**, 없으면 예전처럼 이름을 지어낸다.
## 두 길을 남긴 이유는 세계 없이 도는 시험과 화면이 아직 있기 때문이다 —
## **지어낸 후보는 관계가 없어서 영입이 영원히 안 열린다.** 그것이 화면에 사유로 나간다.
static func _find_prospects(
	guild: Guild, contact_staff: int, prospect_seed: int
) -> Array[RecruitProspect]:
	var found: Array[RecruitProspect] = []
	var wanted := GuildBalance.prospects_for(contact_staff)
	if wanted <= 0:
		return found

	var rng := RandomNumberGenerator.new()
	rng.seed = prospect_seed
	if guild.world != null and guild.world.is_ready():
		return _find_in_world(guild, wanted, rng)

	var used := _taken_names(guild)
	for index in wanted:
		var discipline := rng.randi() % MemberDiscipline.count()
		found.append(
			RecruitProspect.new(
				"prospect_%d_%d" % [guild.expeditions_settled, index],
				MemberNames.pick(rng, used),
				discipline as MemberDiscipline.Kind,
				guild.expeditions_settled
			)
		)
	return found


## 인구에서 후보를 찾는다. **접선처는 연줄로 사람을 찾는다.**
##
## 3000명에서 아무나 뽑으면 관계가 없어 판정이 늘 「모르는 사이」로 막히고,
## 그러면 관계도를 붙인 값이 없다. 그래서 **대표를 중심으로 밖으로 퍼진다** —
##
## | 차례 | 누구 | 무엇이 되나 |
## | --- | --- | --- |
## | 1 | 대표가 아는 사람 | 이미 호감과 유대가 있다. **여기서 영입이 열린다** |
## | 2 | 그 사람들이 아는 사람 | *"내 대원의 형"*, *"내가 아는 사람의 원수"* — 연줄이 기록된다 |
## | 3 | 대표와 같은 소속 | 얼굴은 아는 사이 |
## | 4 | 아무나 | 세상에는 낯선 사람도 있다 |
##
## **2번이 이 설계의 값이다.** 관계도가 여기서 처음으로 게임에 쓰인다 —
## 후보가 누구인지가 아니라 **누구를 통해 왔는지**가 정보가 된다 (설계 24.8).
static func _find_in_world(
	guild: Guild, wanted: int, rng: RandomNumberGenerator
) -> Array[RecruitProspect]:
	var found: Array[RecruitProspect] = []
	var world := guild.world
	var taken := _taken_people(guild)
	var leader := guild.leader_person
	if leader != PersonRegistry.NO_PERSON:
		taken[leader] = true

	for index in wanted:
		var pick := _reach(world, leader, taken, rng)
		var person: int = pick[0]
		if person == PersonRegistry.NO_PERSON:
			break
		taken[person] = true
		var prospect := RecruitProspect.new(
			"prospect_%d_%d" % [guild.expeditions_settled, index],
			world.registry.name_of(person),
			world.registry.discipline_of(person),
			guild.expeditions_settled
		)
		prospect.person = person
		prospect.introduced_by = pick[1]
		prospect.standing = RecruitStanding.of(world.registry, world.graph, person, leader)
		found.append(prospect)
	return found


## 한 사람에게 닿는다. `[인물, 소개한 사람]` 을 돌려주고 못 닿으면 NO_PERSON 이다.
static func _reach(
	world: NpcWorld, leader: int, taken: Dictionary, rng: RandomNumberGenerator
) -> Array:
	if world.registry.size() == 0:
		return [PersonRegistry.NO_PERSON, PersonRegistry.NO_PERSON]

	if leader != PersonRegistry.NO_PERSON:
		# **나를 아는 사람을 먼저 본다.** 영입은 저쪽이 나를 어떻게 보느냐의 문제라
		# (RecruitStanding) 내가 일방적으로 아는 사람은 후보로서 「모르는 사이」로 막힌다.
		# 한쪽만 아는 관계가 전체의 12%나 되므로(설계 24.26.4) 안 가르면 그만큼 헛돈다.
		var mutual := _pick_unused(world.graph.mutuals_of(leader), taken, rng)
		if mutual != PersonRegistry.NO_PERSON:
			return [mutual, PersonRegistry.NO_PERSON]

		var direct := _pick_unused(world.graph.targets_of(leader), taken, rng)
		if direct != PersonRegistry.NO_PERSON:
			return [direct, PersonRegistry.NO_PERSON]

		# 2홉. 소개한 사람을 같이 돌려줘야 화면이 "누구를 통해" 를 말할 수 있다.
		for friend in world.graph.targets_of(leader):
			var referred := _pick_unused(world.graph.targets_of(friend), taken, rng)
			if referred != PersonRegistry.NO_PERSON:
				return [referred, friend]

		var mate := _pick_faction_mate(world, leader, taken, rng)
		if mate != PersonRegistry.NO_PERSON:
			return [mate, PersonRegistry.NO_PERSON]

	# 마지막 수단. **전수 조사를 안 한다** — 인구가 늘 때 비용이 따라 늘면 안 된다.
	for _try in 16:
		var stranger := rng.randi() % world.registry.size()
		if not taken.has(stranger):
			return [stranger, PersonRegistry.NO_PERSON]
	return [PersonRegistry.NO_PERSON, PersonRegistry.NO_PERSON]


## 대표와 같은 소속에서 하나. 무소속이면 없다.
static func _pick_faction_mate(
	world: NpcWorld, leader: int, taken: Dictionary, rng: RandomNumberGenerator
) -> int:
	var faction := world.registry.faction_of(leader)
	if faction == PersonRegistry.NO_FACTION:
		return PersonRegistry.NO_PERSON
	for _try in 24:
		var other := rng.randi() % world.registry.size()
		if world.registry.faction_of(other) == faction and not taken.has(other):
			return other
	return PersonRegistry.NO_PERSON


## 아직 안 쓴 사람 하나. 순서가 결정론적이라 같은 원정이면 같은 후보가 나온다.
static func _pick_unused(
	people: PackedInt32Array, taken: Dictionary, rng: RandomNumberGenerator
) -> int:
	var free := PackedInt32Array()
	for person in people:
		if not taken.has(person):
			free.append(person)
	if free.is_empty():
		return PersonRegistry.NO_PERSON
	return free[rng.randi() % free.size()]


## 이미 후보로 잡힌 세계의 인물들. 같은 사람이 두 번 명단에 오르면 안 된다.
static func _taken_people(guild: Guild) -> Dictionary:
	var taken := {}
	for prospect in guild.prospects:
		if prospect.is_in_world():
			taken[prospect.person] = true
	return taken


## 이미 쓰이고 있는 이름들. 후보가 대원과 같은 이름으로 나오면 기사에서 구분되지 않는다.
##
## **세계에서 뽑을 때는 안 쓴다** — 인구는 이름이 이미 안 겹치고(§24.16.4),
## 3000명 중 하나가 우연히 대원과 같은 이름이라고 그 사람을 없는 사람으로 만들 수는 없다.
static func _taken_names(guild: Guild) -> Dictionary:
	var used := {}
	for member in guild.members:
		used[member.display_name] = true
	for prospect in guild.prospects:
		used[prospect.display_name] = true
	return used
