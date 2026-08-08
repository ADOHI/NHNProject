class_name BaseExpeditionPanel
extends VBoxContainer
## 아지트의 **오른쪽 아래** — 한 바퀴를 돌리는 칸.
##
##     들어간다  ->  방 버튼으로 몇 걸음  ->  결과  ->  정산한다  ->  다음 원정
##
## ## 던전을 판으로 그리지 않는다
##
## 인게임 화면은 다른 레인의 몫이다. 여기서는 **연결점만** 보인다 —
## 갈 수 있는 방이 버튼 목록으로 뜨고, 누르면 DungeonRun 이 실제로 턴을 올린다.
## 그 턴 수가 전리품이 되므로(GuildBalance.loot_for) 흉내가 아니라 진짜 한 바퀴다.
##
## ## 결과는 버튼으로 고른다
##
## 승패 판정은 인게임의 규칙이고 이 화면의 일이 아니다.
## 세 갈래를 눌러 볼 수 있어야 정산의 분기를 확인할 수 있다 (docs/design/22-guild-base.md §22.10).

## 편성한 대로 게이트에 들어가겠다.
signal enter_pressed

## 이 방으로 한 걸음 옮기겠다.
signal room_chosen(room_id: String)

## 이렇게 끝내겠다. 값은 ExpeditionReport.Outcome 이다.
signal outcome_chosen(outcome: int)

## 아지트에 반영하겠다.
signal settle_pressed

## 다음 원정으로 넘어가겠다. **게이트 목록이 통째로 갈린다** (Guild.board_seed_for).
signal next_pressed


## 원정 칸을 다시 그린다.
##
## note 는 아직 들어갈 수 없을 때 무엇이 모자란지 적는 한 줄이다.
## 버튼만 잠가 두면 왜 안 되는지 알 수 없다.
func refresh(
	expedition: Expedition, can_enter: bool, note: String, log_lines: Array[String]
) -> void:
	BaseWidgets.clear(self)
	if expedition == null:
		add_child(_ready_box(can_enter, note))
	else:
		match expedition.stage:
			Expedition.Stage.DEPLOYED:
				add_child(_dungeon_box(expedition))
			Expedition.Stage.RETURNED:
				add_child(_report_box(expedition))
			Expedition.Stage.SETTLED:
				add_child(_settled_box(expedition))
			_:
				add_child(_ready_box(can_enter, note))
	add_child(_log_box(log_lines))


func _ready_box(can_enter: bool, note: String) -> BaseBox:
	var box := BaseBox.new("원정", can_enter)
	box.line(note, BaseWidgets.INK if can_enter else BaseWidgets.INK_DIM)
	var button := BaseWidgets.button("들어간다", can_enter)
	button.pressed.connect(_on_enter_pressed)
	box.body.add_child(button)
	return box


## 던전 안. 방 하나를 누를 때마다 턴이 오른다.
func _dungeon_box(expedition: Expedition) -> BaseBox:
	var run := expedition.run
	var box := BaseBox.new("던전 안 - %s" % expedition.gate.display_name, true)
	box.line("제 %d 판" % run.turn)
	box.line("지금 방 %s" % run.blueprint.display_name_of(run.player_room_id()))
	box.line("인접 위험도 %d" % run.adjacent_threat())
	box.line(
		"탈출구에 서 있다" if expedition.is_at_exit() else "아직 탈출구가 아니다",
		BaseWidgets.INK_MARK if expedition.is_at_exit() else BaseWidgets.INK_DIM
	)

	var moves := HFlowContainer.new()
	for room_id in run.reachable_room_ids():
		var button := BaseWidgets.button(run.blueprint.display_name_of(room_id))
		button.pressed.connect(_on_room_pressed.bind(room_id))
		moves.add_child(button)
	box.body.add_child(moves)

	box.line("어떻게 끝났는가", BaseWidgets.INK_DIM)
	var outcomes := HFlowContainer.new()
	for outcome in [
		ExpeditionReport.Outcome.ESCAPED,
		ExpeditionReport.Outcome.DOWNED,
		ExpeditionReport.Outcome.RECALLED,
	]:
		var button := BaseWidgets.button(ExpeditionReport.outcome_label(outcome))
		button.pressed.connect(_on_outcome_pressed.bind(int(outcome)))
		outcomes.add_child(button)
	box.body.add_child(outcomes)
	return box


func _report_box(expedition: Expedition) -> BaseBox:
	var box := BaseBox.new("결과", true)
	box.line(expedition.report.summary())
	box.line("전리품 %d" % expedition.report.loot_funds)
	var button := BaseWidgets.button("정산한다")
	button.pressed.connect(_on_settle_pressed)
	box.body.add_child(button)
	return box


## 정산 결과. **갔다 오니 아지트가 달라져 있다** 를 말하는 칸이다 (SettlementResult.lines).
func _settled_box(expedition: Expedition) -> BaseBox:
	var box := BaseBox.new("정산", true)
	for text in expedition.result.lines():
		box.line(text)
	var button := BaseWidgets.button("다음 원정")
	button.pressed.connect(_on_next_pressed)
	box.body.add_child(button)
	return box


## 지나간 원정들. 아지트가 한 바퀴마다 어떻게 달라졌는지가 여기 쌓인다.
func _log_box(log_lines: Array[String]) -> BaseBox:
	var box := BaseBox.new("기록")
	if log_lines.is_empty():
		box.line("아직 다녀온 곳이 없다", BaseWidgets.INK_DIM)
		return box
	for text in log_lines:
		box.line(text, BaseWidgets.INK_DIM)
	return box


func _on_enter_pressed() -> void:
	enter_pressed.emit()


func _on_room_pressed(room_id: String) -> void:
	room_chosen.emit(room_id)


func _on_outcome_pressed(outcome: int) -> void:
	outcome_chosen.emit(outcome)


func _on_settle_pressed() -> void:
	settle_pressed.emit()


func _on_next_pressed() -> void:
	next_pressed.emit()
