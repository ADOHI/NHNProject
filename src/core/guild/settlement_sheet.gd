class_name SettlementSheet
extends RefCounted
## 정산 화면이 말하는 **칸 하나.** 제목과 줄들이다.
##
##     ExpeditionReport + SettlementResult + Guild  ->  Array[SettlementSheet]
##
## ## 왜 이것이 코어에 있는가
##
## 「무엇을 어떤 순서로 말할 것인가」는 화면의 취향이 아니라 **규칙의 요약**이다.
## 무엇을 잃고 무엇이 남는지는 docs/design/05-rules.md §5.3 이 표로 확정했고,
## 무엇이 영구인지는 §6.1 이 정했다. 그것을 화면이 각자 적으면
## **화면마다 다른 말을 하게 된다** (SettlementResult.lines() 주석과 같은 사정).
##
## 순수 클래스이므로 칸 넷의 내용이 전부 헤드리스 시험으로 덮인다.
## 화면은 이것을 받아 사각형에 붙이기만 한다 (docs/conventions.md §3.1).
##
## ## 칸 수를 화면이 알지 않는다
##
## `build()` 가 몇 칸을 내든 화면은 그만큼 세운다. 「넷」을 화면에 박으면
## 규칙이 두 곳에 살게 되고, 칸을 늘릴 때 한쪽만 고치게 된다.
##
## docs/design/36-settlement.md §36.4.

## 이 칸의 제목.
var title: String

var lines: Array[SettlementLine] = []


func _init(sheet_title: String = "") -> void:
	title = sheet_title


## 이번 원정 하나를 칸 넷으로 편다.
##
## `result` 가 `null` 이면 **이미 정산된 원정이다** — 그때도 나머지 칸은 그대로 편다.
## 판이 어땠는지는 정산 여부와 무관하게 보고서가 알고 있고, 두 번째로 들어온
## 사람에게 빈 화면을 보여 줄 이유가 없다 (GuildSettlement — *"두 번 누르는 것은
## 오류가 아니라 흔한 조작이다"*).
static func build(
	report: ExpeditionReport, result: SettlementResult, guild: Guild
) -> Array[SettlementSheet]:
	var sheets: Array[SettlementSheet] = []
	if report == null:
		return sheets
	sheets.append(_run_sheet(report))
	sheets.append(_stake_sheet(report))
	sheets.append(_guild_sheet(result, guild))
	sheets.append(_squad_sheet(report, result, guild))
	return sheets


## 한 줄 적는다.
func line(text: String, tone: SettlementLine.Tone = SettlementLine.Tone.PLAIN) -> SettlementLine:
	var made := SettlementLine.new(text, tone)
	lines.append(made)
	return made


## 줄의 글자들만. 시험과 기록이 훑는다.
func texts() -> Array[String]:
	var found: Array[String] = []
	for entry in lines:
		found.append(entry.text)
	return found


## 손실을 말하는 줄이 몇인가. 화면이 자리를 물릴 때와 시험이 셀 때 쓴다.
func loss_count() -> int:
	var found := 0
	for entry in lines:
		if entry.is_loss():
			found += 1
	return found


# ---------------------------------------------------------------- 칸 넷


## ① 이번 판 — **판이 끝난 방식이 나머지 셋을 전부 정한다.**
static func _run_sheet(report: ExpeditionReport) -> SettlementSheet:
	var sheet := SettlementSheet.new("이번 판")
	sheet.line("%s [%s] 로 들어갔다" % [report.gate_name, GateRank.label(report.gate_rank)])
	sheet.line("%d 턴을 보냈다" % report.turns)
	if report.is_success():
		sheet.line("탈출했다 — 들고 나온 것을 지켰다", SettlementLine.Tone.GAIN)
		sheet.line("전리품 %d" % report.loot_funds, SettlementLine.Tone.GAIN)
	else:
		sheet.line(
			"%s — 빈손으로 돌아왔다" % ExpeditionReport.outcome_label(report.outcome),
			SettlementLine.Tone.LOSS
		)
	return sheet


## ② 남은 것과 잃은 것 — **docs/design/05-rules.md §5.3 의 표를 그대로 화면에 놓는다.**
##
## 성공했을 때도 네 줄을 다 놓는다. 실패했을 때만 보여 주면
## **무엇이 걸려 있었는지**가 성공한 판에서는 영영 안 보인다 —
## 익스트랙션에서 그것을 아는 것이 다음 판의 판단이다.
static func _stake_sheet(report: ExpeditionReport) -> SettlementSheet:
	var sheet := SettlementSheet.new("남은 것과 잃은 것")
	var kept := report.is_success()
	if kept:
		sheet.line("던전에서 주운 전리품 — 획득 확정", SettlementLine.Tone.GAIN)
		sheet.line("들고 들어간 장비 — 유지")
	else:
		sheet.line("던전에서 주운 전리품 — 전부 상실", SettlementLine.Tone.LOSS)
		sheet.line("들고 들어간 장비 — 상실", SettlementLine.Tone.LOSS)
	# **사람은 잃지 않는다.** 영구 사망은 배제됐다 (docs/design/14-squad.md §14.6 · Q27).
	sheet.line("스쿼드 대원 — 무손실. 아무도 잃지 않는다")
	sheet.line("주둔지 강화 — 유지. 영구다")
	if not kept:
		# 실패의 대가는 페널티가 아니라 **시간**이다 (§14.6).
		# 이 줄이 없으면 빈손 귀환이 「아무 일도 아닌 것」으로 읽힌다.
		sheet.line("빈손으로 나온 사이에도 세계는 한 틱 갔다", SettlementLine.Tone.DIM)
	return sheet


## ③ 길드 — **남는 것.** docs/design/06-progression.md §6.1 이 영구라고 정한 축이다.
static func _guild_sheet(result: SettlementResult, guild: Guild) -> SettlementSheet:
	var sheet := SettlementSheet.new("길드")
	if result == null:
		sheet.line("이미 정산된 원정이다 — 아지트는 그때 이미 바뀌었다", SettlementLine.Tone.DIM)
		return sheet
	if guild != null:
		# **되돌리기이지 계산이 아니다** — GuildSettlement 가 정확히 이만큼만 더한다
		# (docs/design/36-settlement.md §36.4.2).
		var before := guild.funds - result.funds_gained
		sheet.line(
			"자금 %d 에서 %d 로" % [before, guild.funds],
			SettlementLine.Tone.GAIN if result.funds_gained > 0 else SettlementLine.Tone.PLAIN
		)
	sheet.line(
		"아지트 진척 %d (공방 잔류 %d명)" % [result.base_progress_gained, result.workshop_staff],
		SettlementLine.Tone.GAIN
	)
	if result.levels_gained > 0:
		var level: int = guild.base_level if guild != null else result.levels_gained
		sheet.line(
			"아지트 레벨이 %d 올랐다 — 지금 %d" % [result.levels_gained, level], SettlementLine.Tone.GAIN
		)
	if result.prospects_found.is_empty():
		sheet.line("영입 후보 없음 (접선처 잔류 %d명)" % result.contact_staff, SettlementLine.Tone.DIM)
	else:
		for prospect in result.prospects_found:
			sheet.line("영입 후보 — %s" % prospect.summary(), SettlementLine.Tone.GAIN)
	return sheet


## ④ 대원 — **남긴 자가 왜 그만큼 벌었는지가 여기서 설명된다.**
##
## 데려간 자와 남긴 자를 나란히 놓는 이유는 그 둘이 **한 번의 결정**이기 때문이다
## (Expedition.deploy — *"데려갈 자를 고르는 것이 곧 남길 자를 고르는 것"*).
static func _squad_sheet(
	report: ExpeditionReport, result: SettlementResult, guild: Guild
) -> SettlementSheet:
	var sheet := SettlementSheet.new("대원")
	sheet.line("데려간 자      %s" % _names_of(guild, report.deployed_ids))
	sheet.line("남긴 자      %s" % _names_of(guild, report.garrison_ids))
	if result != null:
		sheet.line(
			"시설을 돌린 것은 남긴 자다 — 공방 %d명 • 접선처 %d명" % [result.workshop_staff, result.contact_staff],
			SettlementLine.Tone.DIM
		)
		if result.shocked > 0:
			# 몸은 복제되어 돌아온다. 상하는 것은 **남을 보던 눈**이다
			# (ExpeditionAftermath — docs/design/24-npc-relations.md §24.30).
			sheet.line("후유증 %d명 — 죽지는 않았지만 사람을 못 믿게 됐다" % result.shocked, SettlementLine.Tone.LOSS)
		else:
			sheet.line("후유증 없음", SettlementLine.Tone.DIM)
	return sheet


## 이름으로 편다. 길드가 없거나 모르는 대원이면 **번호를 그대로 적는다** —
## 빈칸으로 두면 누가 빠졌는지 화면에서 알 수 없다.
static func _names_of(guild: Guild, member_ids: Array[String]) -> String:
	if member_ids.is_empty():
		return "없음"
	var names := PackedStringArray()
	for member_id in member_ids:
		var member: GuildMember = null if guild == null else guild.member_by_id(member_id)
		names.append(member_id if member == null else member.display_name)
	return "      ".join(names)
