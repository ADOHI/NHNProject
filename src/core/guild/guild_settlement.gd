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


## 인구에서 후보를 찾는다. **접선처는 연줄로 사람을 찾는다** (SocialReach).
##
## 3000명에서 아무나 뽑으면 관계가 없어 판정이 늘 「모르는 사이」로 막히고,
## 그러면 관계도를 붙인 값이 없다. 그래서 **대표를 중심으로 밖으로 퍼진다.**
##
## 관계도가 여기서 처음으로 게임에 쓰였다 — 후보가 누구인지가 아니라
## **누구를 통해 왔는지**가 정보가 된다 (설계 24.8).
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
		var pick := SocialReach.near(world, leader, taken, rng)
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
