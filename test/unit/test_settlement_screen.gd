extends GutTest
## 정산 화면의 **배선** 테스트.
##
## 화면은 규칙을 갖지 않으므로 여기서 볼 것은 규칙이 아니라 배선이다 —
## 넘어온 원정이 실제로 정산되는가, **두 번 걸리지 않는가**, 저장이 되는가,
## 그리고 **혼자 뜨면 저장을 안 하는가** (docs/design/36-settlement.md §36.7).
##
## 헤드리스를 통과하고도 화면에서 파싱 에러로 터진 전례가 있어(CLAUDE.md)
## 이 파일은 씬을 실제로 띄운다. 전환 자체는 여기서 안 본다 —
## `Router.go_to()` 를 부르면 GUT 러너가 선 씬이 사라진다 (§34.7.4).
## 그것은 `tools/capture_flow.gd` 가 실제 창에서 덮는다.

const SettlementScene := preload("res://src/ui/settlement/settlement_screen.tscn")
const GuildScript := preload("res://src/core/guild/guild.gd")
const GateScript := preload("res://src/core/gate/gate.gd")
const ExpeditionScript := preload("res://src/core/guild/expedition.gd")

## **시험 전용 세이브 자리.** 진짜 세이브를 읽으면 기계마다 결과가 갈린다
## (test_base_screen.gd 와 같은 사정).
const SAVE_PATH := "user://test_save/settlement_test.json"

const _SEED := 31


func before_each() -> void:
	_erase_save()


func after_each() -> void:
	_erase_save()


func _erase_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# ---------------------------------------------------------------- 붙이는 손


func _guild() -> Guild:
	return GuildScript.create_starting(_SEED)


## 결말까지 끌고 온 원정 하나. **정산은 아직 안 걸렸다** — 그것이 화면의 일이다.
func _returned(guild: Guild, outcome: ExpeditionReport.Outcome) -> Expedition:
	var expedition: Expedition = ExpeditionScript.new(
		guild, GateScript.new("gate_0", "무너진 지하도", GateRank.Kind.E, _SEED)
	)
	# 0 번 대원은 민첩이 모자라 이 게이트에 못 들어간다 (test_expedition.gd).
	expedition.deploy([guild.members[1].id] as Array[String])
	expedition.enter()
	expedition.finish(outcome)
	return expedition


## 화면 하나를 연다. **`add_child()` 전에 값을 꽂는다** — `_ready()` 가 그때 돈다.
func _open(payload: Dictionary) -> SettlementScreen:
	var screen: SettlementScreen = SettlementScene.instantiate()
	screen.save_path = SAVE_PATH
	screen.entry = payload
	add_child_autofree(screen)
	return screen


func _entry_for(expedition: Expedition) -> Dictionary:
	return {
		SettlementScreen.ENTRY_EXPEDITION: expedition,
		SettlementScreen.ENTRY_CAMPAIGN_SEED: _SEED,
		SettlementScreen.ENTRY_SAVE_PATH: SAVE_PATH,
	}


func _panels(screen: SettlementScreen) -> Array[Node]:
	return screen.find_children("*", "PressPanel", true, false)


## 화면에 실제로 찍힌 글자 전부. 무엇이 보이는지는 라벨로만 판정한다.
func _text_of(screen: SettlementScreen) -> String:
	var parts := PackedStringArray()
	for child in screen.find_children("*", "Label", true, false):
		parts.append((child as Label).text)
	return "\n".join(parts)


func _button(screen: SettlementScreen, label: String) -> Button:
	for child in screen.find_children("*", "Button", true, false):
		if (child as Button).text == label:
			return child as Button
	return null


# ---------------------------------------------------------------- 뜨는가


func test_screen_opens_with_an_expedition() -> void:
	var screen := _open(_entry_for(_returned(_guild(), ExpeditionReport.Outcome.ESCAPED)))
	assert_gt(_panels(screen).size(), 0, "칸이 한 장도 안 섰다")


## 칸 수를 화면이 알지 않는다 — 코어가 내는 만큼 선다.
func test_one_panel_per_sheet() -> void:
	var guild := _guild()
	var expedition := _returned(guild, ExpeditionReport.Outcome.ESCAPED)
	var screen := _open(_entry_for(expedition))
	var sheets := SettlementSheet.build(expedition.report, expedition.result, guild)
	assert_eq(_panels(screen).size(), sheets.size())


func test_headline_repeats_what_the_report_says() -> void:
	var expedition := _returned(_guild(), ExpeditionReport.Outcome.ESCAPED)
	var screen := _open(_entry_for(expedition))
	assert_true(_text_of(screen).contains("무너진 지하도"), "어느 문으로 갔는지가 화면에 있다")


func test_leaving_door_is_there_and_enabled() -> void:
	var screen := _open(_entry_for(_returned(_guild(), ExpeditionReport.Outcome.ESCAPED)))
	var leave := _button(screen, "주둔지로")
	assert_not_null(leave, "나가는 문이 없으면 흐름이 여기서 끊긴다")
	assert_false(leave.disabled)


# ---------------------------------------------------------------- 정산


func test_settling_happens_on_the_screen_not_before() -> void:
	var guild := _guild()
	var before := guild.funds
	var expedition := _returned(guild, ExpeditionReport.Outcome.ESCAPED)
	assert_eq(guild.funds, before, "화면에 오기 전에는 아직 아무것도 안 걸렸다")
	_open(_entry_for(expedition))
	assert_gt(guild.funds, before, "화면이 정산을 걸었다")


## **두 번 걸리지 않는다.** `Guild.mark_settled` 의 보장을 화면이 깨지 않는지 본다.
func test_second_visit_does_not_settle_again() -> void:
	var guild := _guild()
	var expedition := _returned(guild, ExpeditionReport.Outcome.ESCAPED)
	_open(_entry_for(expedition))
	var once := guild.funds
	_open(_entry_for(expedition))
	assert_eq(guild.funds, once, "같은 원정으로 두 번 들어와도 자금이 두 번 늘면 안 된다")


## 두 번째로 들어와도 **화면은 비지 않는다.** 무엇을 벌었는지 다시 볼 수 있어야 한다.
func test_second_visit_still_draws_the_result() -> void:
	var guild := _guild()
	var expedition := _returned(guild, ExpeditionReport.Outcome.ESCAPED)
	_open(_entry_for(expedition))
	var screen := _open(_entry_for(expedition))
	assert_gt(_panels(screen).size(), 0)
	assert_true(_text_of(screen).contains("이미 정산"), "다시 걸지 않았다는 것을 말한다")


func test_failed_run_shows_what_was_lost() -> void:
	var screen := _open(_entry_for(_returned(_guild(), ExpeditionReport.Outcome.DOWNED)))
	var text := _text_of(screen)
	assert_true(text.contains("전부 상실"), "잃은 것이 화면에 있다")
	assert_true(text.contains("무손실"), "그래도 대원은 잃지 않는다 (14-squad §14.6)")


# ---------------------------------------------------------------- 저장


func test_autosaves_after_settling() -> void:
	_open(_entry_for(_returned(_guild(), ExpeditionReport.Outcome.ESCAPED)))
	assert_true(FileAccess.file_exists(SAVE_PATH), "정산 뒤가 자동 저장 지점이다 (34 §34.4.5)")


func test_says_that_it_saved() -> void:
	var screen := _open(_entry_for(_returned(_guild(), ExpeditionReport.Outcome.ESCAPED)))
	assert_true(_text_of(screen).contains("저장했다"), "저장된 줄 알고 껐다가 잃는 것이 가장 나쁘다")


## 두 번째 방문에서는 정산이 안 걸리므로 **저장도 안 한다.**
func test_second_visit_does_not_write_again() -> void:
	var guild := _guild()
	var expedition := _returned(guild, ExpeditionReport.Outcome.ESCAPED)
	_open(_entry_for(expedition))
	_erase_save()
	_open(_entry_for(expedition))
	assert_false(FileAccess.file_exists(SAVE_PATH), "안 걸린 정산을 저장하지 않는다")


# ---------------------------------------------------------------- 혼자 띄웠을 때


func test_standalone_screen_still_draws() -> void:
	var screen := _open({})
	assert_gt(_panels(screen).size(), 0, "혼자 띄워도 그대로 돈다")
	assert_not_null(_button(screen, "주둔지로"))


## **꾸민 판은 절대 저장하지 않는다.** 화면 한 번 열어 본 것이 진행을 덮으면 안 된다.
func test_standalone_screen_never_saves() -> void:
	var screen := _open({})
	assert_false(FileAccess.file_exists(SAVE_PATH), "지어낸 길드가 세이브를 덮으면 안 된다")
	assert_true(_text_of(screen).contains("저장하지 않는다"), "왜 저장이 없는지 말한다")


# ---------------------------------------------------------------- 기사 단


func test_feed_column_is_absent_without_a_feed() -> void:
	var screen := _open(_entry_for(_returned(_guild(), ExpeditionReport.Outcome.ESCAPED)))
	assert_eq(
		screen.find_children("*", "RekkaFeedView", true, false).size(), 0, "기사가 안 넘어오면 빈 단을 세우지 않는다"
	)


func test_feed_column_stands_when_a_feed_arrives() -> void:
	var payload := _entry_for(_returned(_guild(), ExpeditionReport.Outcome.ESCAPED))
	payload[SettlementScreen.ENTRY_FEED] = RekkaFeed.new(_SEED)
	var screen := _open(payload)
	assert_eq(screen.find_children("*", "RekkaFeedView", true, false).size(), 1)
