extends GutTest
## 정산이 **무엇을 말하는가**의 단위 테스트.
##
## 화면 없이 판정된다 — 그것이 이 판단을 코어에 둔 이유다
## (docs/design/36-settlement.md §36.3.1).
##
## 여기서 지키는 것은 조형이 아니라 **규칙이 화면에 나가는가**이다.
## docs/design/05-rules.md §5.3 의 표와 §14.6 의 확정(영구 사망 없음)이
## 실패한 판에서도 실제로 한 줄씩 서는지 본다.

const GuildScript := preload("res://src/core/guild/guild.gd")
const GateScript := preload("res://src/core/gate/gate.gd")
const ExpeditionScript := preload("res://src/core/guild/expedition.gd")
const ReportScript := preload("res://src/core/guild/expedition_report.gd")
const SheetScript := preload("res://src/core/guild/settlement_sheet.gd")

const _SEED := 31

## 칸의 자리 번호. `build()` 가 내는 순서다.
const _RUN := 0
const _STAKE := 1
const _GUILD := 2
const _SQUAD := 3


func _guild() -> Guild:
	return GuildScript.create_starting(_SEED)


func _gate() -> Gate:
	return GateScript.new("gate_0", "무너진 지하도", GateRank.Kind.E, _SEED)


## 이 게이트를 끝낼 수 있는 한 명. 0 번 대원은 민첩이 모자라 못 들어간다
## (test_expedition.gd 와 같은 사정).
func _able(guild: Guild) -> Array[String]:
	return [guild.members[1].id] as Array[String]


## 원정 하나를 결말까지 끌고 가서 정산한다.
func _settled(guild: Guild, outcome: ExpeditionReport.Outcome) -> Array[SettlementSheet]:
	var expedition: Expedition = ExpeditionScript.new(guild, _gate())
	expedition.deploy(_able(guild))
	expedition.enter()
	var report := expedition.finish(outcome)
	var result := expedition.settle()
	return SheetScript.build(report, result, guild)


## 정산 없이 보고서만. 「이미 정산됨」 자리를 재는 데 쓴다.
func _report_only(guild: Guild) -> ExpeditionReport:
	var expedition: Expedition = ExpeditionScript.new(guild, _gate())
	expedition.deploy(_able(guild))
	expedition.enter()
	return expedition.finish(ExpeditionReport.Outcome.ESCAPED)


func _joined(sheet: SettlementSheet) -> String:
	return "\n".join(sheet.texts())


# ---------------------------------------------------------------- 칸의 모양


func test_builds_four_sheets() -> void:
	var sheets := _settled(_guild(), ExpeditionReport.Outcome.ESCAPED)
	assert_eq(sheets.size(), 4, "이번 판 • 남은 것과 잃은 것 • 길드 • 대원")


func test_every_sheet_has_a_title_and_lines() -> void:
	for sheet in _settled(_guild(), ExpeditionReport.Outcome.DOWNED):
		assert_false(sheet.title.is_empty(), "제목 없는 칸은 무엇을 말하는지 알 수 없다")
		assert_gt(sheet.lines.size(), 0, "빈 칸을 세우지 않는다")


func test_no_report_makes_no_sheets() -> void:
	assert_eq(SheetScript.build(null, null, _guild()).size(), 0)


# ---------------------------------------------------------------- 이번 판


func test_run_sheet_names_the_gate_and_turns() -> void:
	var sheets := _settled(_guild(), ExpeditionReport.Outcome.ESCAPED)
	var text := _joined(sheets[_RUN])
	assert_true(text.contains("무너진 지하도"), "어느 문으로 들어갔는지가 첫 칸이다")
	assert_true(text.contains("턴"), "몇 턴을 보냈는지가 전리품의 근거다")


func test_success_shows_loot_and_failure_does_not() -> void:
	var won := _joined(_settled(_guild(), ExpeditionReport.Outcome.ESCAPED)[_RUN])
	var lost := _joined(_settled(_guild(), ExpeditionReport.Outcome.DOWNED)[_RUN])
	assert_true(won.contains("전리품"), "탈출하면 전리품이 확정된다")
	assert_true(lost.contains("빈손"), "실패는 빈손 귀환이다 (14-squad §14.6)")


func test_recall_reads_as_failure() -> void:
	var text := _joined(_settled(_guild(), ExpeditionReport.Outcome.RECALLED)[_RUN])
	assert_true(text.contains("빈손"), "중도 회수의 결과는 빈손과 같다")


# ---------------------------------------------------------------- 남은 것과 잃은 것


## §5.3 의 표는 **성공한 판에도** 통째로 선다. 무엇이 걸려 있었는지를
## 성공했을 때 못 보면 다음 판의 판단이 안 선다.
func test_stake_sheet_covers_all_four_rows_either_way() -> void:
	for outcome in [ExpeditionReport.Outcome.ESCAPED, ExpeditionReport.Outcome.DOWNED]:
		var text := _joined(_settled(_guild(), outcome as ExpeditionReport.Outcome)[_STAKE])
		assert_true(text.contains("전리품"), "전리품 줄")
		assert_true(text.contains("장비"), "장비 줄")
		assert_true(text.contains("대원"), "대원 줄")
		assert_true(text.contains("주둔지"), "주둔지 줄")


## **사람은 잃지 않는다.** 영구 사망 배제(Q27)가 화면에서 사라지면
## 실패한 사람은 자기 대원이 죽은 줄 안다.
func test_members_are_never_lost_even_when_downed() -> void:
	var sheet := _settled(_guild(), ExpeditionReport.Outcome.DOWNED)[_STAKE]
	assert_true(_joined(sheet).contains("무손실"), "쓰러져도 대원은 무손실이다")


func test_failure_loses_loot_and_gear() -> void:
	var sheet := _settled(_guild(), ExpeditionReport.Outcome.DOWNED)[_STAKE]
	assert_true(_joined(sheet).contains("전부 상실"))
	assert_true(sheet.has_loss(), "실패한 판의 이 칸에는 손실이 있다")


func test_success_keeps_gear() -> void:
	var sheet := _settled(_guild(), ExpeditionReport.Outcome.ESCAPED)[_STAKE]
	assert_false(sheet.has_loss(), "탈출한 판에서는 잃은 것이 없다")


## 실패의 대가는 페널티가 아니라 시간이다 (§14.6 — 세계 갱신).
func test_failure_notes_that_the_world_moved_on() -> void:
	var lost := _joined(_settled(_guild(), ExpeditionReport.Outcome.RECALLED)[_STAKE])
	var won := _joined(_settled(_guild(), ExpeditionReport.Outcome.ESCAPED)[_STAKE])
	assert_true(lost.contains("세계"), "빈손으로 나온 사이에도 세계는 갔다")
	assert_false(won.contains("세계"), "성공한 판에는 그 줄이 없다")


# ---------------------------------------------------------------- 길드


func test_guild_sheet_shows_funds_before_and_after() -> void:
	var guild := _guild()
	var before := guild.funds
	var sheets := _settled(guild, ExpeditionReport.Outcome.ESCAPED)
	var text := _joined(sheets[_GUILD])
	assert_true(text.contains("자금 %d 에서 %d 로" % [before, guild.funds]), text)
	assert_gt(guild.funds, before, "탈출했으므로 자금이 늘어야 한다")


## 실패해도 아지트 진척은 들어온다 — 공방에 남은 사람은 계속 일했다
## (GuildBalance.base_progress_for).
func test_base_progress_arrives_even_on_failure() -> void:
	var text := _joined(_settled(_guild(), ExpeditionReport.Outcome.DOWNED)[_GUILD])
	assert_true(text.contains("아지트 진척"), text)


func test_already_settled_run_says_so_instead_of_lying() -> void:
	var guild := _guild()
	var report := _report_only(guild)
	var sheets: Array[SettlementSheet] = SheetScript.build(report, null, guild)
	assert_eq(sheets.size(), 4, "정산이 안 걸려도 나머지 칸은 그대로 편다")
	assert_true(_joined(sheets[_GUILD]).contains("이미 정산"), "두 번째로 들어온 사람에게 거짓말하지 않는다")


# ---------------------------------------------------------------- 대원


func test_squad_sheet_names_who_went_and_who_stayed() -> void:
	var guild := _guild()
	var sheets := _settled(guild, ExpeditionReport.Outcome.ESCAPED)
	var text := _joined(sheets[_SQUAD])
	assert_true(text.contains(guild.members[1].display_name), "데려간 자의 이름")
	assert_true(text.contains(guild.members[0].display_name), "남긴 자의 이름")


func test_squad_sheet_explains_where_the_progress_came_from() -> void:
	var text := _joined(_settled(_guild(), ExpeditionReport.Outcome.ESCAPED)[_SQUAD])
	assert_true(text.contains("공방"), "남긴 자가 왜 그만큼 벌었는지가 여기서 설명된다")


## 길드를 모르면 번호라도 적는다. 빈칸이면 누가 빠졌는지 알 수 없다.
func test_unknown_guild_falls_back_to_ids() -> void:
	var guild := _guild()
	var report := _report_only(guild)
	var sheets: Array[SettlementSheet] = SheetScript.build(report, null, null)
	assert_true(_joined(sheets[_SQUAD]).contains(guild.members[1].id))


# ---------------------------------------------------------------- 줄의 성격


func test_lines_carry_tone_not_color() -> void:
	var sheets := _settled(_guild(), ExpeditionReport.Outcome.DOWNED)
	var found := false
	for entry in sheets[_STAKE].lines:
		if entry.tone == SettlementLine.Tone.LOSS:
			found = true
	assert_true(found, "손실 줄은 성격으로 표시된다 — 색은 화면이 고른다")
