extends GutTest
## 후보를 **실제로 데려오는가.** 관계도가 처음으로 보상을 주는 자리다.
##
## docs/design/37-meta-loop.md §37.8, docs/design/14-squad.md §14.5.
##
## 이 시험이 지키는 것 둘 —
##
## 1. **판정을 우회할 수 없다.** 못 데려올 사람을 데려오면 관계를 쌓을 이유가 사라진다
## 2. **데려온 사람이 세계의 인물로 남는다.** 인물 번호를 놓치면 그 사람에게서
##    가족과 원수가 사라지고, 다음 판부터 남남이 된다 (설계 24.29)

const _SEED := 20260819


func _guild() -> Guild:
	# 세계 없이 만든다. 판정은 `standing` 을 손으로 세워 흔들리지 않게 한다.
	return Guild.create_starting(_SEED, "시험 길드")


## 데려올 수 있는 후보. **판정을 손으로 세운다** — 인구에서 뽑으면 시드에 따라
## 되기도 하고 안 되기도 해서 시험이 기계마다 달라진다.
func _open_prospect(prospect_id: String = "p_open") -> RecruitProspect:
	var prospect := RecruitProspect.new(prospect_id, "닿은 사람", MemberDiscipline.Kind.SCOUT, 2)
	prospect.person = 41
	var standing := RecruitStanding.new()
	standing.affinity = 99
	standing.bond = RecruitStanding.BOND_REQUIRED
	standing.required_affinity = 30
	standing.hierarchy_gap = 0
	standing.is_stranger = false
	prospect.standing = standing
	return prospect


## 못 데려오는 후보. 서로 모르는 사이다.
func _blocked_prospect(prospect_id: String = "p_shut") -> RecruitProspect:
	var prospect := RecruitProspect.new(prospect_id, "모르는 사람", MemberDiscipline.Kind.COMBAT, 2)
	prospect.person = 42
	var standing := RecruitStanding.new()
	standing.is_stranger = true
	prospect.standing = standing
	return prospect


# ---------------------------------------------------------------- 데려온다


func test_an_open_prospect_becomes_a_member() -> void:
	var guild := _guild()
	var before := guild.members.size()
	guild.add_prospect(_open_prospect())
	var hired := GuildRecruit.hire(guild, "p_open")
	assert_not_null(hired)
	assert_eq(guild.members.size(), before + 1)
	assert_eq(hired.display_name, "닿은 사람")
	assert_eq(int(hired.discipline), int(MemberDiscipline.Kind.SCOUT))


func test_the_hired_keeps_their_person_number() -> void:
	# 놓치면 그 사람에게서 가족과 원수가 사라진다 (설계 24.29).
	var guild := _guild()
	guild.add_prospect(_open_prospect())
	var hired := GuildRecruit.hire(guild, "p_open")
	assert_eq(hired.person, 41)
	assert_true(hired.is_in_world())


func test_the_prospect_leaves_the_shortlist() -> void:
	var guild := _guild()
	guild.add_prospect(_open_prospect())
	GuildRecruit.hire(guild, "p_open")
	assert_null(GuildRecruit.find(guild, "p_open"))
	assert_eq(guild.prospects.size(), 0)


func test_the_same_prospect_cannot_come_twice() -> void:
	var guild := _guild()
	guild.add_prospect(_open_prospect())
	var count := guild.members.size()
	assert_not_null(GuildRecruit.hire(guild, "p_open"))
	assert_null(GuildRecruit.hire(guild, "p_open"))
	assert_eq(guild.members.size(), count + 1)


func test_hired_ids_do_not_collide() -> void:
	# **식별자가 겹치면 배치표와 편성이 엉뚱한 사람을 가리킨다** (FacilityAssignment).
	var guild := _guild()
	var ids := {}
	for index in 4:
		guild.add_prospect(_open_prospect("p_%d" % index))
		var hired := GuildRecruit.hire(guild, "p_%d" % index)
		assert_not_null(hired, "%d 번째를 못 데려왔다" % index)
		assert_false(ids.has(hired.id), "식별자가 겹쳤다: %s" % hired.id)
		ids[hired.id] = true
	assert_eq(guild.members.size(), 5 + 4)


func test_the_hired_can_be_deployed_and_assigned() -> void:
	# 데려온 사람이 **쓸 수 있는 대원**이 아니면 영입이 뜻이 없다.
	var guild := _guild()
	guild.add_prospect(_open_prospect())
	var hired := GuildRecruit.hire(guild, "p_open")
	guild.assignment.assign(hired.id, Facility.Kind.WORKSHOP)
	assert_eq(guild.staff_at(Facility.Kind.WORKSHOP), 1)
	assert_not_null(guild.form_squad([hired.id] as Array[String]))


# ---------------------------------------------------------------- 못 데려온다


func test_a_blocked_prospect_stays_out() -> void:
	var guild := _guild()
	var before := guild.members.size()
	guild.add_prospect(_blocked_prospect())
	assert_null(GuildRecruit.hire(guild, "p_shut"))
	assert_eq(guild.members.size(), before)
	assert_not_null(GuildRecruit.find(guild, "p_shut"))


func test_a_prospect_without_a_world_stays_out() -> void:
	# 지어낸 후보는 관계가 없어서 영원히 안 열린다 (GuildSettlement 주석).
	var guild := _guild()
	guild.add_prospect(RecruitProspect.new("p_flat", "이름뿐인 사람", MemberDiscipline.Kind.COMBAT, 0))
	assert_null(GuildRecruit.hire(guild, "p_flat"))
	assert_ne(GuildRecruit.blocked_reason(guild, "p_flat"), "")


func test_the_reason_comes_from_the_standing() -> void:
	# 사유를 두 곳에 적으면 갈라진다. 후보에게 묻는다.
	var guild := _guild()
	var prospect := _blocked_prospect()
	guild.add_prospect(prospect)
	assert_eq(GuildRecruit.blocked_reason(guild, "p_shut"), prospect.blocked_reason())
	guild.add_prospect(_open_prospect())
	assert_eq(GuildRecruit.blocked_reason(guild, "p_open"), "")


func test_an_unknown_id_is_refused_without_dying() -> void:
	var guild := _guild()
	assert_null(GuildRecruit.hire(guild, "없는 후보"))
	assert_null(GuildRecruit.hire(guild, ""))
	assert_null(GuildRecruit.hire(null, "p_open"))
	assert_null(GuildRecruit.find(null, "p_open"))
	assert_ne(GuildRecruit.blocked_reason(guild, "없는 후보"), "")


# ---------------------------------------------------------------- 저장


func test_the_hired_survive_a_save() -> void:
	# 데려온 사람이 세이브를 못 건너면 **영입이 한 판짜리**가 된다.
	var guild := _guild()
	guild.add_prospect(_open_prospect())
	var hired := GuildRecruit.hire(guild, "p_open")
	var back := Guild.from_dict(guild.to_dict())
	var same := back.member_by_id(hired.id)
	assert_not_null(same)
	assert_eq(same.person, 41)
	assert_eq(same.display_name, "닿은 사람")
	assert_eq(back.prospects.size(), 0)
