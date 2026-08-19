extends GutTest
## 코어가 자기를 사전으로 내고 받는가. **저장 형식이 게임 규칙을 오염시키지 않게 하려는 것**이고
## (docs/design/34-systems.md §34.4.2), 그래서 이 시험에는 파일이 한 번도 안 나온다.

const SEED := 20260819


func _make_guild() -> Guild:
	# 세계 없이 만든다. 인구 3000명은 여기서 볼 것이 아니다.
	var guild := Guild.create_starting(SEED, "저장 시험 길드")
	guild.add_funds(777)
	guild.add_base_progress(3)
	var ids := guild.member_ids()
	guild.assignment.assign(ids[0], Facility.Kind.WORKSHOP)
	guild.assignment.assign(ids[1], Facility.Kind.INTEL_ROOM)
	guild.add_prospect(RecruitProspect.new("p_1", "밝은 사람", MemberDiscipline.Kind.COMBAT, 2))
	guild.mark_settled("exp_9")
	return guild


func test_a_member_round_trips() -> void:
	var member := GuildMember.new("m_7", "가는 자", MemberDiscipline.Kind.SCOUT, 11, 4)
	member.person = 123
	var back := GuildMember.from_dict(member.to_dict())
	assert_eq(back.id, member.id)
	assert_eq(back.display_name, member.display_name)
	assert_eq(int(back.discipline), int(member.discipline))
	assert_eq(back.threat, 11)
	assert_eq(back.agility, 4)
	assert_eq(back.person, 123)


func test_a_member_without_an_id_is_refused() -> void:
	assert_null(GuildMember.from_dict({}))
	assert_null(GuildMember.from_dict({"display_name": "이름만 있다"}))


func test_the_assignment_table_round_trips() -> void:
	var assignment := FacilityAssignment.new()
	assignment.assign("a", Facility.Kind.WORKSHOP)
	assignment.assign("b", Facility.Kind.CONTACT_POINT)
	var back := FacilityAssignment.from_dict(assignment.to_dict())
	assert_eq(back.facility_of("a"), int(Facility.Kind.WORKSHOP))
	assert_eq(back.facility_of("b"), int(Facility.Kind.CONTACT_POINT))
	assert_eq(back.facility_of("없는 대원"), -1)


func test_a_facility_outside_the_enum_is_dropped() -> void:
	# 손으로 고친 파일이 게임을 깨지 않아야 한다.
	var back := FacilityAssignment.from_dict({"a": 99, "b": -3, "c": 0})
	assert_false(back.is_assigned("a"))
	assert_false(back.is_assigned("b"))
	assert_true(back.is_assigned("c"))


func test_a_prospect_round_trips_without_its_standing() -> void:
	var prospect := RecruitProspect.new("p_2", "닿은 사람", MemberDiscipline.Kind.ENGINEER, 5)
	prospect.person = 42
	prospect.introduced_by = 7
	var back := RecruitProspect.from_dict(prospect.to_dict())
	assert_eq(back.id, "p_2")
	assert_eq(back.person, 42)
	assert_eq(back.introduced_by, 7)
	assert_eq(back.found_at_expedition, 5)
	assert_null(back.standing, "판정은 세계에서 다시 재는 파생값이다")


func test_the_whole_guild_round_trips() -> void:
	var guild := _make_guild()
	var back := Guild.from_dict(guild.to_dict())
	assert_not_null(back)
	assert_eq(back.display_name, guild.display_name)
	assert_eq(back.funds, guild.funds)
	assert_eq(back.base_level, guild.base_level)
	assert_eq(back.base_progress, guild.base_progress)
	assert_eq(back.expeditions_settled, guild.expeditions_settled)
	assert_eq(back.member_ids(), guild.member_ids())
	assert_eq(back.prospects.size(), guild.prospects.size())


func test_the_assignment_and_the_settled_ledger_come_back() -> void:
	var guild := _make_guild()
	var back := Guild.from_dict(guild.to_dict())
	var ids := guild.member_ids()
	assert_eq(back.assignment.facility_of(ids[0]), int(Facility.Kind.WORKSHOP))
	assert_eq(back.assignment.facility_of(ids[1]), int(Facility.Kind.INTEL_ROOM))
	assert_true(back.has_settled("exp_9"), "장부를 잃으면 같은 원정이 두 번 정산된다")
	assert_false(back.has_settled("exp_1"))


func test_two_round_trips_produce_the_same_dictionary() -> void:
	var guild := _make_guild()
	var once := guild.to_dict()
	var twice := Guild.from_dict(once).to_dict()
	assert_eq(JSON.stringify(twice), JSON.stringify(once))


func test_a_json_trip_keeps_every_number() -> void:
	# 파일에 나가는 순간 숫자는 전부 실수가 된다. 그것이 돌아와도 같아야 한다.
	var guild := _make_guild()
	var text := JSON.stringify(guild.to_dict())
	var back := Guild.from_dict(JSON.parse_string(text) as Dictionary)
	assert_not_null(back)
	assert_eq(back.funds, guild.funds)
	assert_eq(back.base_level, guild.base_level)
	assert_eq(back.member_ids(), guild.member_ids())
	assert_eq(back.members[0].threat, guild.members[0].threat)


func test_a_dictionary_without_members_is_not_a_guild() -> void:
	assert_null(Guild.from_dict({}))
	assert_null(Guild.from_dict({"funds": 100}))
	assert_null(Guild.from_dict({"members": "배열이 아니다"}))


func test_missing_fields_fall_back_to_defaults() -> void:
	# 옛 세이브에 없던 항목이 생겼다고 파일 전체를 못 읽으면 안 된다.
	var back := Guild.from_dict({"members": []})
	assert_not_null(back)
	assert_eq(back.funds, GuildBalance.STARTING_FUNDS)
	assert_eq(back.base_level, GuildBalance.STARTING_BASE_LEVEL)


func test_an_assignment_for_a_stranger_is_cleaned_up() -> void:
	var back := Guild.from_dict({"members": [], "assignment": {"유령": int(Facility.Kind.WORKSHOP)}})
	assert_false(back.assignment.is_assigned("유령"))
