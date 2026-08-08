extends GutTest
## 정산의 단위 테스트.
##
## 가장 중요한 것은 **두 번 적용되지 않는 것**이다.
## 정산이 두 번 들어가면 아지트가 조용히 두 배로 자라고, 그 버그는 화면에 드러나지 않는다
## (docs/design/22-guild-base.md §22.6).

const GuildScript := preload("res://src/core/guild/guild.gd")
const GateScript := preload("res://src/core/gate/gate.gd")
const ReportScript := preload("res://src/core/guild/expedition_report.gd")
const SettlementScript := preload("res://src/core/guild/guild_settlement.gd")

const _SEED := 11


func _guild() -> Guild:
	return GuildScript.create_starting(_SEED)


func _gate(rank: GateRank.Kind = GateRank.Kind.C) -> Gate:
	return GateScript.new("gate_0", "붉은 회랑", rank, _SEED)


func _report(
	guild: Guild,
	deployed: Array[String],
	outcome: ExpeditionReport.Outcome = ExpeditionReport.Outcome.ESCAPED,
	turns: int = 5,
	report_id: String = "exp_1"
) -> ExpeditionReport:
	var garrison: Array[String] = []
	for member_id in guild.member_ids():
		if not deployed.has(member_id):
			garrison.append(member_id)
	return ReportScript.new(report_id, _gate(), outcome, turns, deployed, garrison)


# ---------------------------------------------------------------- 두 번 적용되지 않는다


func test_settlement_applies_once() -> void:
	var guild := _guild()
	var report := _report(guild, [guild.members[0].id] as Array[String])
	var first := SettlementScript.apply(guild, report)
	assert_not_null(first)

	var funds := guild.funds
	var level := guild.base_level
	var progress := guild.base_progress

	var second := SettlementScript.apply(guild, report)
	assert_null(second, "같은 원정은 두 번 정산되지 않는다")
	assert_eq(guild.funds, funds)
	assert_eq(guild.base_level, level)
	assert_eq(guild.base_progress, progress)


## 보고서를 복제해 와도 뚫리지 않아야 한다. 판단의 근거는 길드 장부다.
func test_duplicate_report_object_cannot_settle_again() -> void:
	var guild := _guild()
	var deployed: Array[String] = [guild.members[0].id]
	SettlementScript.apply(guild, _report(guild, deployed))
	var funds := guild.funds
	assert_null(SettlementScript.apply(guild, _report(guild, deployed)), "같은 번호의 새 보고서도 막힌다")
	assert_eq(guild.funds, funds)


func test_settled_count_rises_once_per_expedition() -> void:
	var guild := _guild()
	var deployed: Array[String] = [guild.members[0].id]
	SettlementScript.apply(
		guild, _report(guild, deployed, ExpeditionReport.Outcome.ESCAPED, 5, "a")
	)
	SettlementScript.apply(
		guild, _report(guild, deployed, ExpeditionReport.Outcome.ESCAPED, 5, "a")
	)
	assert_eq(guild.expeditions_settled, 1)
	SettlementScript.apply(
		guild, _report(guild, deployed, ExpeditionReport.Outcome.ESCAPED, 5, "b")
	)
	assert_eq(guild.expeditions_settled, 2)


# ---------------------------------------------------------------- 배치가 값이 된다


func test_workshop_staff_speeds_up_the_base() -> void:
	var bare := _guild()
	var bare_result := SettlementScript.apply(bare, _report(bare, [] as Array[String]))

	var staffed := _guild()
	staffed.assignment.assign(staffed.members[0].id, Facility.Kind.WORKSHOP)
	var staffed_result := SettlementScript.apply(staffed, _report(staffed, [] as Array[String]))

	assert_true(
		staffed_result.base_progress_gained > bare_result.base_progress_gained,
		"공방에 사람을 두면 아지트가 빨리 자란다"
	)


## 데려가면 그 사람의 시설 효과를 잃는다 — 편성과 배치가 같은 인원을 놓고 다툰다.
func test_deployed_worker_stops_contributing() -> void:
	var guild := _guild()
	var worker := guild.members[0].id
	guild.assignment.assign(worker, Facility.Kind.WORKSHOP)
	var result := SettlementScript.apply(guild, _report(guild, [worker] as Array[String]))
	assert_eq(result.workshop_staff, 0, "출전한 공방 인원은 일하지 않는다")
	assert_eq(result.base_progress_gained, GuildBalance.BASE_PROGRESS_PER_RUN)


func test_contact_point_finds_prospects() -> void:
	var guild := _guild()
	guild.assignment.assign(guild.members[0].id, Facility.Kind.CONTACT_POINT)
	var result := SettlementScript.apply(guild, _report(guild, [] as Array[String]))
	assert_eq(result.prospects_found.size(), GuildBalance.PROSPECTS_PER_CONTACT_STAFF)
	assert_eq(guild.prospects.size(), result.prospects_found.size())


func test_prospects_cannot_be_recruited_yet() -> void:
	var guild := _guild()
	guild.assignment.assign(guild.members[0].id, Facility.Kind.CONTACT_POINT)
	var result := SettlementScript.apply(guild, _report(guild, [] as Array[String]))
	for prospect in result.prospects_found:
		assert_false(prospect.can_recruit(), "영입은 관계도가 붙어야 열린다 (§22.7)")
		assert_false(prospect.blocked_reason().is_empty())


func test_prospect_names_do_not_collide_with_members() -> void:
	var guild := _guild()
	guild.assignment.assign(guild.members[0].id, Facility.Kind.CONTACT_POINT)
	guild.assignment.assign(guild.members[1].id, Facility.Kind.CONTACT_POINT)
	var result := SettlementScript.apply(guild, _report(guild, [] as Array[String]))
	var taken := {}
	for member in guild.members:
		taken[member.display_name] = true
	for prospect in result.prospects_found:
		assert_false(taken.has(prospect.display_name))
		taken[prospect.display_name] = true


func test_prospects_are_reproducible() -> void:
	var first := _guild()
	first.assignment.assign(first.members[0].id, Facility.Kind.CONTACT_POINT)
	var one := SettlementScript.apply(first, _report(first, [] as Array[String]), 99)

	var second := _guild()
	second.assignment.assign(second.members[0].id, Facility.Kind.CONTACT_POINT)
	var other := SettlementScript.apply(second, _report(second, [] as Array[String]), 99)

	assert_eq(one.prospects_found[0].display_name, other.prospects_found[0].display_name)


# ---------------------------------------------------------------- 성공과 실패


func test_failure_returns_empty_handed() -> void:
	var guild := _guild()
	var report := _report(guild, [] as Array[String], ExpeditionReport.Outcome.DOWNED, 8)
	assert_eq(report.loot_funds, 0, "빈손 귀환 (docs/design/14-squad.md §14.6)")
	var result := SettlementScript.apply(guild, report)
	assert_eq(result.funds_gained, 0)


## 실패해도 주둔지는 잃지 않는다 (docs/design/06-progression.md §6.1).
func test_failure_still_advances_the_base() -> void:
	var guild := _guild()
	guild.assignment.assign(guild.members[0].id, Facility.Kind.WORKSHOP)
	var report := _report(guild, [] as Array[String], ExpeditionReport.Outcome.DOWNED, 8)
	var result := SettlementScript.apply(guild, report)
	assert_true(result.base_progress_gained > 0, "남은 사람은 계속 일했다")


func test_higher_rank_pays_more_for_the_same_run() -> void:
	var low := GuildBalance.loot_for(GateRank.Kind.E, 6, true)
	var high := GuildBalance.loot_for(GateRank.Kind.A, 6, true)
	assert_true(high > low)


func test_longer_stay_pays_more() -> void:
	assert_true(
		(
			GuildBalance.loot_for(GateRank.Kind.C, 10, true)
			> GuildBalance.loot_for(GateRank.Kind.C, 2, true)
		)
	)


func test_settlement_lines_are_readable() -> void:
	var guild := _guild()
	var result := SettlementScript.apply(guild, _report(guild, [] as Array[String]))
	assert_true(result.lines().size() >= 2)
	for line in result.lines():
		assert_false(line.is_empty())
