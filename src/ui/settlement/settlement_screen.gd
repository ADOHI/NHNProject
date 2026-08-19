class_name SettlementScreen
extends Control
## **정산 화면 — 한 판이 여기서 닫힌다.**
##
##     던전에서 탈출/회수  ->  여기  ->  자동 저장  ->  주둔지
##
## 익스트랙션인데 한 판의 끝이 화면에 없었다. `GuildSettlement` 는 정산할 줄 아는데
## 그 결과를 사람에게 보여 줄 자리가 없어서, 던전에서 나와도 아무 일도 안 일어났다
## (docs/design/16-build-order.md §16.0.2 의 B 순번).
##
## ## 이 화면은 규칙을 하나도 갖지 않는다
##
## 무엇이 얼마나 들어오는지는 `GuildBalance` 가, 두 번 정산되지 않는 것은
## `Guild.mark_settled` 가, **무엇을 어떤 순서로 말할 것인가**는 `SettlementSheet` 가 안다.
## 여기 남는 것은 셋뿐이다 — **읽고 · 그리고 · 저장한다** (docs/conventions.md §3.1).
##
## ## 결과 화면과 정산 화면을 하나로 본다
##
## docs/design/08-ui-ux.md §8.4 의 화면 목록에 「결과 정산」이 하나로 적혀 있다.
## 둘로 가르면 클릭이 늘고 얻는 것이 없다 — 앞은 사라지는 것이고 뒤는 남는 것이라
## **나란히 놓을 때만** docs/design/06-progression.md §6.1 이 화면으로 옮겨진다.
##
## ## 혼자 띄워도 돈다. 그리고 그때는 저장하지 않는다
##
##     godot --path . res://src/ui/settlement/settlement_screen.tscn
##
## 넘어온 값이 없으면 한 판을 꾸며 세운다. **그 판은 절대 저장하지 않는다** —
## 지어낸 길드를 사용자의 세이브에 쓰면 화면 한 번 열어 본 것이 진행을 덮는다
## (docs/design/36-settlement.md §36.7).

## 넘어오는 값의 열쇠. **받는 쪽이 계약을 든다** (DungeonScreen.ENTRY_SEED 와 같은 규칙).
##
## 보내는 화면이 저마다 문자열을 적으면 오타 하나가 조용히 기본 화면을 띄우고,
## 그것은 화면만 봐서는 구분되지 않는다.
const ENTRY_EXPEDITION := "expedition"
const ENTRY_CAMPAIGN_SEED := "campaign_seed"
const ENTRY_SAVE_PATH := "save_path"

## 이번 판의 렉카 피드. 없으면 그 자리가 통째로 빠진다 —
## **자리만 비워 두지 않는다** (docs/design/36-settlement.md §36.4.3).
const ENTRY_FEED := "feed"

## 혼자 띄웠을 때 꾸미는 판의 씨앗. 고정이라 조형을 고치는 사람이 같은 화면을 다시 본다.
const _DEMO_SEED := 20260819

## 꾸민 판이 던전에서 보낸 턴 수. 전리품이 여기서 나온다 (GuildBalance.loot_for).
const _DEMO_TURNS := 7

## 기사 단의 폭. 가로 화면에서만 선다.
const _FEED_WIDTH := 380

## 칸을 몇 열로 세우나. 넷을 한 화면에 놓으려면 둘이다.
const _SHEET_COLUMNS := 2

## 손실 줄이 안으로 물러나는 거리. **자리가 상태다** (docs/design/20-ui-kit.md §20.18.1).
##
## 색으로 가르지 않는 이유는 §36.8 에 적었다 — 이 지면에는 잉크가 둘뿐이고
## 별색은 렉카의 몫이다 (`UiTokens.MARK` 주석 — *"세 번째 잉크를 쓰지 않는다"*).
const _LOSS_INDENT := UiTokens.SPACE_STEP

## 어디에 저장하나. 넘어온 값이 이것을 갈아 끼운다.
##
## **시험과 도구가 갈아 끼운다** — 안 갈아 끼우면 시험이 사용자의 진짜 세이브를 읽고,
## 그 파일의 내용에 따라 초록과 빨강이 갈린다 (BaseScreen.save_path 와 같은 사정).
var save_path := SaveStore.DEFAULT_PATH

## 라우터를 거치지 않고 넣는 값. **시험이 쓴다.**
##
## 시험에서 `Router.go_to()` 를 부르면 GUT 러너가 선 씬이 사라진다
## (docs/design/34-systems.md §34.7.4). 그래서 넘어오는 값만 직접 꽂는다.
## `_ready()` 가 이것을 먼저 보므로 `add_child()` 전에 채워야 한다.
var entry: Dictionary = {}

var _guild: Guild = null
var _report: ExpeditionReport = null
var _result: SettlementResult = null
var _feed: RekkaFeed = null

## 이번 방문에서 정산이 **실제로 걸렸는가.** 저장 여부가 이 값 하나로 갈린다.
var _settled_now := false

## 꾸며 세운 판인가. **꾸민 판은 저장하지 않는다.**
var _is_demo := false

## 이 판의 씨앗. 저장에 들어간다 — **이것이 있어야 대원의 인물 번호가 같은 사람을
## 가리킨다** (docs/design/34-systems.md §34.4.1). 넘어온 값이 없으면 길드가 딛고 선
## 세계에서 되찾는다. 상수를 여기 또 적으면 두 곳이 갈린다 (conventions.md §6.5).
var _campaign_seed := 0
var _note := ""
var _sheets: Array[SettlementSheet] = []

## 칸이 서는 자리. 창이 커지면 칸도 같이 커져야 한다 (`_fit_sheets`).
var _sheet_scroll: ScrollContainer
var _sheet_grid: GridContainer


func _ready() -> void:
	# Theme 은 루트에 한 번만 문다. 자식에게 그대로 흘러내린다.
	theme = UiTheme.get_theme()
	_take_entry()
	_settle()
	_sheets = SettlementSheet.build(_report, _result, _guild)
	_build()


# ---------------------------------------------------------------- 값과 정산


## 넘어온 원정을 편다. 없으면 한 판을 꾸민다.
func _take_entry() -> void:
	var payload := entry if not entry.is_empty() else Router.take_payload()
	var expedition := payload.get(ENTRY_EXPEDITION) as Expedition
	if expedition == null:
		_build_demo()
		return
	save_path = String(payload.get(ENTRY_SAVE_PATH, save_path))
	_feed = payload.get(ENTRY_FEED) as RekkaFeed
	_guild = expedition.guild()
	_report = expedition.report
	_campaign_seed = int(payload.get(ENTRY_CAMPAIGN_SEED, _world_seed()))
	# **정산은 여기서 한 번 걸린다.** 두 번째로 들어오면 `settle()` 이 null 을 주고
	# (Guild.mark_settled), 그때는 지난번 결과를 그대로 그린다 — 화면이 비면
	# 사용자는 자기가 무엇을 벌었는지 영영 못 본다.
	var fresh := expedition.settle()
	_settled_now = fresh != null
	_result = fresh if fresh != null else expedition.result


## 길드가 딛고 선 세계의 씨앗. 세계가 없으면 0 이다.
func _world_seed() -> int:
	if _guild == null or _guild.world == null:
		return 0
	return _guild.world.seed_value


## 저장은 **정산이 실제로 걸렸을 때만** 한다.
##
## docs/design/34-systems.md §34.4.5 가 자동 저장 지점을 「원정 정산 뒤」 한 곳으로
## 못 박았고, 지금까지 그것을 부르는 곳은 주둔지의 배선 칸뿐이었다. 여기가 그 자리다.
##
## 실패해도 게임을 멈추지 않는다. 대신 **실패했다는 것을 화면에 적는다** —
## 저장된 줄 알고 껐다가 잃는 것이 가장 나쁘다 (§34.4.4).
func _settle() -> void:
	if _is_demo:
		_note = "꾸며 세운 판이다 — 저장하지 않는다"
		return
	if _report == null:
		# 오지 않은 원정을 「이미 정산됐다」고 말하면 그것이 거짓말이 된다.
		_note = "돌아온 원정이 없다 — 정산할 것이 없다"
		return
	if not _settled_now:
		_note = "이미 정산된 원정이다 — 다시 걸지 않았다"
		return
	var error := SaveStore.new(save_path).write(_guild, _campaign_seed)
	_note = "저장했다" if error == OK else "저장하지 못했다 (오류 %d)" % error


## 혼자 띄웠을 때 세우는 한 판.
##
## **세계를 세우지 않는다.** 인구 3000명이 없어도 정산은 돌고(GuildSettlement 가
## 두 길을 다 든다), 조형을 고치는 사람이 화면 하나 보자고 50ms 를 기다릴 이유가 없다.
func _build_demo() -> void:
	_is_demo = true
	_guild = Guild.create_starting(_DEMO_SEED, "새벽 길드")
	var gate := Gate.new("demo_gate", "무너진 지하도", GateRank.Kind.E, _DEMO_SEED)
	var deployed: Array[String] = [_guild.members[0].id]
	var garrison: Array[String] = []
	for member_id in _guild.member_ids():
		if not deployed.has(member_id):
			garrison.append(member_id)
	_report = ExpeditionReport.new(
		"demo_run", gate, ExpeditionReport.Outcome.ESCAPED, _DEMO_TURNS, deployed, garrison
	)
	_result = GuildSettlement.apply(_guild, _report, _DEMO_SEED)
	_settled_now = _result != null


# ---------------------------------------------------------------- 뼈대


func _build() -> void:
	var paper := ColorRect.new()
	paper.name = "Paper"
	paper.color = UiTokens.PAPER
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(paper)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, UiTokens.SPACE_GAP)
	add_child(margin)

	var page := VBoxContainer.new()
	page.name = "Page"
	page.add_theme_constant_override("separation", UiTokens.SPACE_STEP)
	margin.add_child(page)

	page.add_child(_masthead())

	var body := HBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", UiTokens.SPACE_GAP)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	body.add_child(_sheet_column())
	# 기사가 안 넘어오면 단 자체를 안 세운다. 빈 칸은 「고장난 것」으로 읽힌다.
	if _feed != null:
		body.add_child(_feed_column())

	page.add_child(_footer())


## 제호. **이 지면이 무엇인지**와 판이 어떻게 끝났는지가 한 줄에 선다.
func _masthead() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Masthead"
	row.add_theme_constant_override("separation", UiTokens.SPACE_GAP)

	var title := PlateLabel.new()
	title.text = "정산"
	title.variation = UiTheme.HEAD
	row.add_child(title)

	var deck := Label.new()
	deck.text = _headline()
	deck.theme_type_variation = UiTheme.SUB
	deck.size_flags_vertical = Control.SIZE_SHRINK_END
	deck.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(deck)
	return row


## 한 줄 요약. **보고서가 아는 것을 그대로 옮긴다** — 화면이 다시 판정하지 않는다.
func _headline() -> String:
	return "돌아온 원정이 없다" if _report == null else _report.summary()


## 칸들이 서는 자리. 세로로만 굴러간다 — 가로로 굴러가면 넷을 한눈에 볼 수 없다.
func _sheet_column() -> ScrollContainer:
	_sheet_scroll = ScrollContainer.new()
	_sheet_scroll.name = "Sheets"
	_sheet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sheet_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_sheet_grid = GridContainer.new()
	_sheet_grid.name = "Grid"
	_sheet_grid.columns = _SHEET_COLUMNS
	_sheet_grid.add_theme_constant_override("h_separation", UiTokens.SPACE_STEP)
	_sheet_grid.add_theme_constant_override("v_separation", UiTokens.SPACE_STEP)
	_sheet_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# **칸 수를 화면이 알지 않는다.** 코어가 몇 칸을 내든 그만큼 세운다.
	for sheet in _sheets:
		_sheet_grid.add_child(_sheet_panel(sheet))
	_sheet_scroll.add_child(_sheet_grid)
	_sheet_scroll.resized.connect(_fit_sheets)
	_fit_sheets.call_deferred()
	return _sheet_scroll


## 칸이 지면을 채우게 한다. **글이 적다고 지면이 반쯤 비면 안 된다** —
## 신문은 남는 자리를 두지 않는다.
##
## `ScrollContainer` 는 굴러가는 축으로 자식을 늘려 주지 않는다. 늘려 주면 굴러갈 것이
## 언제나 창 크기여서 스크롤이 성립하지 않기 때문이다. 그래서 **최소 높이를 창 높이로
## 밀어 준다** — 내용이 더 길면 그쪽이 이기므로 굴러가는 성질은 그대로 남는다.
func _fit_sheets() -> void:
	if _sheet_grid == null or _sheet_scroll == null:
		return
	_sheet_grid.custom_minimum_size.y = _sheet_scroll.size.y


## 칸 하나. `PressPanel` 이 종이와 괘선을 맡고 여기서는 글만 쌓는다.
func _sheet_panel(sheet: SettlementSheet) -> PressPanel:
	var panel := PressPanel.new()
	panel.plate = PressPanel.Plate.FACT
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var pad := MarginContainer.new()
	panel.add_child(pad)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UiTokens.SPACE_TIGHT)
	pad.add_child(column)

	var title := Label.new()
	title.text = sheet.title
	title.theme_type_variation = UiTheme.CAPTION
	column.add_child(title)

	for line in sheet.lines:
		column.add_child(_line_row(line))
	return panel


## 줄 하나. 손실이면 **안으로 물러난다** (§20.18.1 — 자리가 상태다).
func _line_row(line: SettlementLine) -> Control:
	var label := Label.new()
	label.text = line.text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.theme_type_variation = _variation_for(line.tone)
	if not line.is_loss():
		return label
	var indent := MarginContainer.new()
	indent.add_theme_constant_override("margin_left", _LOSS_INDENT)
	indent.add_child(label)
	return indent


## 줄의 성격을 글자 위계로 옮긴다. **색이 아니다** — §36.8.
func _variation_for(tone: SettlementLine.Tone) -> String:
	match tone:
		SettlementLine.Tone.GAIN, SettlementLine.Tone.LOSS:
			return UiTheme.SUB
		SettlementLine.Tone.DIM:
			return UiTheme.CAPTION
		_:
			return ""


## 이번 판의 기사. **무슨 일이 있었나의 진짜 답이 여기 있다** (docs/design/32-rekka-feed.md).
func _feed_column() -> RekkaFeedView:
	var view := RekkaFeedView.new()
	view.name = "Feed"
	view.custom_minimum_size.x = _FEED_WIDTH
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# 자식으로 들어가기 전에는 _ready 가 안 돌아서 안쪽 위젯이 없다
	# (RekkaFeedView._card_for 와 같은 사정).
	view.ready.connect(view.bind.bind(_feed))
	return view


## 아래 줄 — 저장이 어떻게 됐는지와 나가는 문.
func _footer() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Footer"
	row.add_theme_constant_override("separation", UiTokens.SPACE_STEP)

	var note := Label.new()
	note.name = "Note"
	note.text = _note
	note.theme_type_variation = UiTheme.CAPTION
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(note)

	var leave := Button.new()
	leave.name = "LeaveButton"
	leave.text = "주둔지로"
	leave.pressed.connect(_on_leave_pressed)
	row.add_child(leave)
	return row


# ---------------------------------------------------------------- 나가는 문


## 주둔지로 간다. **되돌아가지 않는다** — 정산은 한 번 지나면 닫히는 문이다.
##
## `Router.back()` 을 쓰면 던전으로 돌아간다. 익스트랙션에서 끝난 판으로 되돌아갈 수
## 있으면 손실 규칙이 무너진다 (docs/design/36-settlement.md §36.5.3).
func _on_leave_pressed() -> void:
	Sfx.play(SfxEvent.Kind.UI_PRESS)
	Router.go_to(SceneRoutes.Screen.BASE)
