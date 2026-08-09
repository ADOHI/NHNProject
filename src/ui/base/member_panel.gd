class_name BaseMemberPanel
extends VBoxContainer
## 아지트의 **가운데 기둥** — 보유 대원과 편성 요약.
##
## 대원 한 줄에 결정이 둘 붙어 있다. **데려갈 것인가**와 **어디에 둘 것인가**다.
## 두 결정이 같은 줄에 있어야 하는 이유는 둘이 같은 인원을 놓고 다투기 때문이다
## (docs/design/22-guild-base.md §22.4). 따로 놓으면 고르는 동안 무엇을 포기하는지 안 보인다.
##
## 이 패널은 길드를 바꾸지 않는다. 눌린 것을 시그널로 올리고 다시 그려질 뿐이다
## (conventions.md §3.3 — call down, signal up).

## 이 대원의 출전 여부를 뒤집어 달라.
signal deploy_toggled(member_id: String)

## 이 대원을 이 시설로 옮겨 달라. kind 가 UNASSIGN 이면 배치를 푼다.
signal facility_chosen(member_id: String, kind: int)

## 배치 해제를 뜻하는 값. Facility.Kind 밖의 수를 쓰는 이유는
## "어디에도 없음" 이 시설의 한 종류가 아니기 때문이다 (FacilityAssignment.facility_of 와 같다).
const UNASSIGN := -1


## 대원 목록과 편성 요약을 다시 그린다.
##
## locked 는 원정이 이미 출발했다는 뜻이다. 그때는 편성도 배치도 만질 수 없다 —
## 순서를 되돌릴 수 없다는 것은 Expedition 의 규칙이고, 화면은 그것을 따르기만 한다.
func refresh(guild: Guild, deployed: Array[String], locked: bool) -> void:
	BaseWidgets.clear(self)
	if guild == null:
		return
	for member in guild.members:
		add_child(_member_box(guild, member, deployed, locked))
	add_child(_summary_box(guild, deployed))


## 대원 한 명. 윗줄은 코어가 만든 요약이고 아랫줄이 결정 둘이다.
func _member_box(
	guild: Guild, member: GuildMember, deployed: Array[String], locked: bool
) -> BaseBox:
	var is_deployed := deployed.has(member.id)
	var box := BaseBox.new("", is_deployed)

	var head := BaseWidgets.row()
	var full := deployed.size() >= guild.squad_capacity()
	var toggle := BaseWidgets.button(
		"데려가는 중" if is_deployed else "데려간다", not locked and (is_deployed or not full)
	)
	toggle.pressed.connect(_on_deploy_pressed.bind(member.id))
	head.add_child(toggle)
	# 요약 문장은 코어가 만든다. 화면이 다시 조립하면 두 곳에서 갈린다.
	var summary := BaseWidgets.label(member.summary(), BaseWidgets.SIZE_BODY)
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(summary)
	box.body.add_child(head)

	var current := guild.assignment.facility_of(member.id)
	box.body.add_child(_facility_row(guild, member, current, locked))
	box.line(MemberDiscipline.eye_note(member.discipline), BaseWidgets.INK_DIM)
	# 대원이 세계의 인물이라는 것이 여기서 보인다 (설계 24.29). 문장은 코어가 만든다.
	box.line(guild.member_note(member), BaseWidgets.INK_DIM)
	return box


## 배치 버튼 줄. 지금 있는 곳은 눌러도 소용이 없으므로 잠근다.
func _facility_row(guild: Guild, member: GuildMember, current: int, locked: bool) -> HBoxContainer:
	var row := BaseWidgets.row()
	row.add_child(BaseWidgets.label("배치", BaseWidgets.SIZE_BODY, BaseWidgets.INK_DIM))
	for kind in Facility.all():
		var here := current == kind
		var full := (
			guild.assignment.members_at(kind as Facility.Kind).size()
			>= GuildBalance.FACILITY_CAPACITY
		)
		var button := BaseWidgets.button(
			Facility.label(kind as Facility.Kind), not locked and not here and not full
		)
		# 잠긴 버튼이 둘 다 흐리면 "지금 여기 있다" 와 "정원이 찼다" 가 구분되지 않는다.
		if here:
			button.add_theme_color_override("font_disabled_color", BaseWidgets.INK_MARK)
		button.pressed.connect(_on_facility_pressed.bind(member.id, kind))
		row.add_child(button)
	var clear_button := BaseWidgets.button("해제", not locked and current != UNASSIGN)
	clear_button.pressed.connect(_on_facility_pressed.bind(member.id, UNASSIGN))
	row.add_child(clear_button)
	return row


## 편성 요약. **데려갈 자를 고르는 것이 곧 남길 자를 고르는 것이다** (Expedition.deploy).
func _summary_box(guild: Guild, deployed: Array[String]) -> BaseBox:
	var box := BaseBox.new("편성", not deployed.is_empty())
	box.line("데려갈 자 %d / %d" % [deployed.size(), guild.squad_capacity()])

	var squad := guild.form_squad(deployed)
	if squad == null:
		box.line("아직 아무도 고르지 않았다", BaseWidgets.INK_DIM)
	else:
		box.line("스쿼드 전투력 %d      민첩 %d" % [squad.threat(), squad.agility()])
		box.line("데려갈 자      %s" % _names_of(guild, deployed), BaseWidgets.INK_MARK)

	box.line("남길 자      %s" % _names_of(guild, _garrison_of(guild, deployed)))
	return box


## 아지트에 남는 사람들. Expedition.garrison_ids() 와 같은 뺄셈이다 —
## **편성이 성립하기 전에도 보여 줘야 해서** 화면이 미리 계산한다.
func _garrison_of(guild: Guild, deployed: Array[String]) -> Array[String]:
	var remaining: Array[String] = []
	for member_id in guild.member_ids():
		if not deployed.has(member_id):
			remaining.append(member_id)
	return remaining


func _names_of(guild: Guild, member_ids: Array[String]) -> String:
	var names: Array[String] = []
	for member_id in member_ids:
		var member := guild.member_by_id(member_id)
		if member != null:
			names.append(member.display_name)
	return "없음" if names.is_empty() else "      ".join(names)


func _on_deploy_pressed(member_id: String) -> void:
	deploy_toggled.emit(member_id)


func _on_facility_pressed(member_id: String, kind: int) -> void:
	facility_chosen.emit(member_id, kind)
