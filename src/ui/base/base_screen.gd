class_name BaseScreen
extends Control
## 길드 아지트 화면. **도형만으로 아웃게임 한 바퀴를 돌린다.**
##
##     게이트 고른다 -> 데려간다 켠다 -> 들어간다 -> 몇 걸음 -> 결과 -> 정산 -> 다음 원정
##
## ## 이 화면은 규칙을 하나도 갖지 않는다
##
## 코어를 읽어 그리고, 눌린 것을 코어에 넘기고, 다시 읽어 그린다
## (conventions.md §3.1). 정원 검사도 정산 중복 방지도 전부 src/core/ 에 있다.
## 화면이 스스로 만드는 문자열은 버튼 이름과 칸 제목뿐이다
## (docs/design/22-guild-base.md §22.8.2).
##
## ## 한 화면에 다 놓는다
##
## 배치와 편성이 **같은 인원을 놓고 다투는 것**이 이 화면의 전부다 (§22.4).
## 탭으로 나누면 그 다툼이 보이지 않는다. 그래서 기둥 셋을 나란히 세운다.
##
## ## 조형은 임시다
##
## 조형은 다른 레인의 src/ui/kit/ 에서 온다. 그것이 나오면 이 표현은 전부 버려진다.
##
##     godot --path . res://src/ui/base/base_screen.tscn
##
## ## 흐름에 물려 있다 (docs/design/34-systems.md §34.5.1)
##
## 타이틀에서 여기로 오고, 여기서 던전 화면으로 간다. **어느 씬으로 가는지는 모른다** —
## `Router` 에게 화면 이름만 말한다.
##
## ## 진행이 남는다
##
## 열 때 저장된 길드를 이어받고, **원정 정산 뒤에 저장한다** (§34.4.5).
## 못 읽으면 새로 시작하되 **왜인지 화면에 적는다** — 조용히 지우면
## 사용자는 자기 진행이 어디로 갔는지 영영 모른다.

## 이 판의 씨앗. 목록 씨앗은 여기에 마친 원정 수가 섞여서 나온다
## (Guild.board_seed_for) — **원정 횟수가 곧 시간이다** (§22.0).
const CAMPAIGN_SEED := 20260808

## 기둥 너비. 왼쪽 둘은 고정이고 오른쪽이 남는 폭을 가진다.
const _GUILD_WIDTH := 268
const _MEMBER_WIDTH := 396

## 어디에 저장하나. **시험과 도구가 갈아 끼운다.**
##
## 안 갈아 끼우면 시험이 사용자의 진짜 세이브를 읽고, 그 파일의 내용에 따라
## 초록과 빨강이 갈린다 — 기계마다 다른 결과가 나오는 시험은 시험이 아니다.
## `_ready()` 전에 정해야 하므로 `instantiate()` 와 `add_child()` 사이에 넣는다.
var save_path := SaveStore.DEFAULT_PATH

var _guild: Guild

## 이 판의 씨앗. **불러온 판은 저장된 씨앗을 쓴다** — 그것이 있어야
## 대원의 인물 번호가 같은 사람을 가리킨다 (docs/design/34-systems.md §34.4.1).
var _campaign_seed := CAMPAIGN_SEED

## 인물과 관계의 세계. **길드가 여기에 발을 딛어야 영입 판정이 선다** (Guild.bind_world).
var _world: NpcWorld

var _gates: Array[Gate] = []

## 지금 고른 게이트의 자리 번호.
var _selected_gate := 0

## 지금 데려가기로 표시한 대원들. **아직 출발하지 않았어도 시설에서는 빠진 것으로 센다** —
## 그래야 고르는 동안 어디가 비는지 보인다 (§22.8.1).
var _deployed: Array[String] = []

## 지금 돌고 있는 원정. 없으면 편성 중이다.
var _expedition: Expedition = null

## 지나간 원정들의 한 줄 기록.
var _log: Array[String] = []

var _guild_panel: BaseGuildPanel
var _member_panel: BaseMemberPanel
var _gate_panel: BaseGatePanel
var _expedition_panel: BaseExpeditionPanel


func _ready() -> void:
	_build_layout()
	_load_or_start()
	_open_new_board()
	_refresh()


## 저장된 진행을 이어받는다. 없거나 못 읽으면 **새로 시작하고 사유를 화면에 적는다.**
##
## **세계를 한 번에 세운다.** 3000명 + 가족 + 사건이 데스크톱에서 50ms 남짓이고
## (docs/design/24-npc-relations.md §24.26.4) 화면을 여는 순간 한 번뿐이다.
## 웹에서 이 멈춤이 거슬리면 `NpcWorld.build_chunk()` 로 나눠 돌리면 된다 —
## 인물 상세 화면이 그렇게 하고 있고 결과는 같다 (§24.16.2).
func _load_or_start() -> void:
	var loaded := SaveStore.new(save_path).read()
	if loaded.is_ok():
		_campaign_seed = loaded.campaign_seed
		_world = loaded.world
		_guild = loaded.guild
		_log.append("이어서 한다 — %s, 마친 원정 %d회" % [_guild.display_name, _guild.expeditions_settled])
		return
	_log.append(loaded.message())
	_campaign_seed = CAMPAIGN_SEED
	_world = NpcWorld.create(_campaign_seed)
	_guild = Guild.create_starting(_campaign_seed, "새벽 길드", _world)


# ---------------------------------------------------------------- 뼈대


func _build_layout() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = BaseWidgets.BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	add_child(margin)

	var page := BaseWidgets.column(8)
	margin.add_child(page)
	page.add_child(_header())
	page.add_child(
		BaseWidgets.label(
			"도형만 세운 배선 화면이다. 조형은 다른 레인에서 온다", BaseWidgets.SIZE_BODY, BaseWidgets.INK_DIM
		)
	)

	var columns := BaseWidgets.row(8)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(columns)

	_guild_panel = BaseGuildPanel.new()
	columns.add_child(_scroll(_guild_panel, _GUILD_WIDTH))

	_member_panel = BaseMemberPanel.new()
	_member_panel.deploy_toggled.connect(_on_deploy_toggled)
	_member_panel.facility_chosen.connect(_on_facility_chosen)
	columns.add_child(_scroll(_member_panel, _MEMBER_WIDTH))

	var right := BaseWidgets.column(8)
	_gate_panel = BaseGatePanel.new()
	_gate_panel.gate_selected.connect(_on_gate_selected)
	right.add_child(_gate_panel)
	_expedition_panel = BaseExpeditionPanel.new()
	_expedition_panel.enter_pressed.connect(_on_enter_pressed)
	_expedition_panel.room_chosen.connect(_on_room_chosen)
	_expedition_panel.outcome_chosen.connect(_on_outcome_chosen)
	_expedition_panel.settle_pressed.connect(_on_settle_pressed)
	_expedition_panel.next_pressed.connect(_on_next_pressed)
	right.add_child(_expedition_panel)
	columns.add_child(_scroll(right, 0))


## 제목 줄. 오른쪽 끝에 **어디로 갈 수 있는가**가 붙는다.
func _header() -> HBoxContainer:
	var row := BaseWidgets.row(8)
	row.add_child(BaseWidgets.label("길드 아지트", BaseWidgets.SIZE_TITLE))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	var board := BaseWidgets.button("던전 판 보기")
	board.pressed.connect(_on_board_pressed)
	row.add_child(board)
	var title := BaseWidgets.button("타이틀로")
	title.pressed.connect(_on_title_pressed)
	row.add_child(title)
	return row


## 고른 게이트를 들고 던전 화면으로 간다.
##
## **어느 씬인지 여기서 적지 않는다.** 화면 이름만 말하고 경로는 장부가 안다
## (docs/design/34-systems.md §34.3.1). 넘기는 값의 열쇠는 받는 쪽이 든다.
func _on_board_pressed() -> void:
	var gate := _current_gate()
	if gate == null:
		return
	(
		Router
		. go_to(
			SceneRoutes.Screen.DUNGEON,
			{
				DungeonScreen.ENTRY_SEED: gate.dungeon_seed,
				DungeonScreen.ENTRY_SIZE: gate.dungeon_size(),
				DungeonScreen.ENTRY_CHARACTER: gate.dungeon_character,
				DungeonScreen.ENTRY_GATE_NAME: gate.display_name,
			}
		)
	)


func _on_title_pressed() -> void:
	Router.go_to(SceneRoutes.Screen.TITLE)


## 기둥 하나를 세로로만 굴러가게 감싼다.
##
## 창이 작아도 칸이 잘리지 않아야 한다. 가로로 굴러가면 기둥 셋을 한눈에 볼 수 없으므로
## 세로만 연다.
func _scroll(content: Control, width: int) -> ScrollContainer:
	var box := ScrollContainer.new()
	box.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if width > 0:
		box.custom_minimum_size.x = width
	else:
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(content)
	return box


# ---------------------------------------------------------------- 그리기


func _refresh() -> void:
	var locked := _expedition != null
	_guild_panel.refresh(_guild, _deployed)
	_member_panel.refresh(_guild, _deployed, locked)
	_gate_panel.refresh(_gates, _guild.gate_disclosure(_deployed), _selected_gate, locked)
	_expedition_panel.refresh(_expedition, _can_enter(), _entry_note(), _log)


func _current_gate() -> Gate:
	if _selected_gate < 0 or _selected_gate >= _gates.size():
		return null
	return _gates[_selected_gate]


## 지금 들어갈 수 있는가. 정원 검사는 Guild.form_squad 가 하므로 여기서 다시 하지 않는다.
##
## **민첩 검사도 여기서 한다.** `Expedition.enter()` 가 막기는 하지만 그쪽은 `null` 을
## 돌려줄 뿐이라, 버튼이 눌리는데 아무 일도 안 일어나는 화면이 된다 —
## **조용히 실패하는 것이 가장 나쁘다.** 잠그고 이유를 적는다.
func _can_enter() -> bool:
	var squad := _guild.form_squad(_deployed)
	var gate := _current_gate()
	return gate != null and squad != null and gate.can_enter(squad.agility())


## 왜 못 들어가는지, 혹은 들어가면 무슨 일이 벌어지는지 한 줄.
func _entry_note() -> String:
	var gate := _current_gate()
	if gate == null:
		return "갈 게이트를 고른다"
	if _deployed.is_empty():
		return "데려갈 대원을 고른다"
	var squad := _guild.form_squad(_deployed)
	if squad == null:
		return "정원 %d 명을 넘었다" % _guild.squad_capacity()
	if not gate.can_enter(squad.agility()):
		# **모자란 값을 그대로 보여 준다.** "못 들어간다" 만 적으면 무엇을 바꿔야 할지 모른다.
		return "민첩이 모자라다 — 이 게이트는 %d, 지금 스쿼드는 %d" % [gate.required_agility(), squad.agility()]
	return "%s 로 %d 명을 데려간다" % [gate.display_name, _deployed.size()]


# ---------------------------------------------------------------- 편성과 배치


func _on_deploy_toggled(member_id: String) -> void:
	if _expedition != null:
		return
	if _deployed.has(member_id):
		_deployed.erase(member_id)
	elif _deployed.size() < _guild.squad_capacity():
		_deployed.append(member_id)
	_refresh()


func _on_facility_chosen(member_id: String, kind: int) -> void:
	if _expedition != null:
		return
	if kind == BaseMemberPanel.UNASSIGN:
		_guild.assignment.unassign(member_id)
	else:
		_guild.assignment.assign(member_id, kind as Facility.Kind)
	_refresh()


func _on_gate_selected(index: int) -> void:
	if _expedition != null:
		return
	_selected_gate = index
	_refresh()


# ---------------------------------------------------------------- 한 바퀴


func _on_enter_pressed() -> void:
	var gate := _current_gate()
	if _expedition != null or gate == null:
		return
	var expedition := Expedition.new(_guild, gate)
	if not expedition.deploy(_deployed) or expedition.enter() == null:
		return
	_expedition = expedition
	_refresh()


func _on_room_chosen(room_id: String) -> void:
	if _expedition == null or _expedition.run == null:
		return
	_expedition.run.move_player(room_id)
	_refresh()


func _on_outcome_chosen(outcome: int) -> void:
	if _expedition == null:
		return
	_expedition.finish(outcome as ExpeditionReport.Outcome)
	_refresh()


func _on_settle_pressed() -> void:
	if _expedition == null:
		return
	var result := _expedition.settle()
	if result != null:
		_log.append("%s      %s" % [_expedition.report.summary(), "      ".join(result.lines())])
		_autosave()
	_refresh()


## **한 판이 끝난 자리에서 저장한다.** 자동 저장 지점을 여기 하나로 시작하는 것은 의도다 —
## 여러 곳에 뿌리면 어느 시점의 상태가 파일에 있는지 아무도 모르게 된다
## (docs/design/34-systems.md §34.4.5).
##
## 실패해도 게임을 멈추지 않는다. 대신 **실패했다는 것을 화면에 적는다** —
## 저장된 줄 알고 껐다가 잃는 것이 가장 나쁘다.
func _autosave() -> void:
	var error := SaveStore.new(save_path).write(_guild, _campaign_seed)
	_log.append("저장했다" if error == OK else "저장하지 못했다 (오류 %d)" % error)


## 다음 원정. **게이트 목록이 통째로 갈린다** — 그놈들이 흥미를 잃은 문은 닫힌다 (§22.0).
func _on_next_pressed() -> void:
	_expedition = null
	_deployed.clear()
	_selected_gate = 0
	_open_new_board()
	_refresh()


func _open_new_board() -> void:
	_gates = _guild.open_gates(_guild.board_seed_for(_campaign_seed))
