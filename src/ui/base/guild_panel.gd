class_name BaseGuildPanel
extends VBoxContainer
## 아지트의 **왼쪽 기둥** — 길드 상태 · 시설 셋 · 영입 후보.
##
## ## 시설 칸이 이 화면의 핵심이다
##
## 지금 데려가기로 표시한 대원은 배치가 남아 있어도 **출전**으로 흐려지고
## 일하는 인원에서 빠진다 (FacilityAssignment.staff_count 의 absent_ids).
## 그래서 가운데 기둥에서 "데려간다" 를 켜는 순간 **여기가 비는 것이 보인다** —
## 편성과 배치가 같은 인원을 놓고 다툰다는 §22.4 가 문장이 아니라 움직임이 된다.
##
## 이 패널은 길드를 읽기만 한다. 아무것도 바꾸지 않는다 (conventions.md §3.1).


## 길드 상태를 다시 그린다.
##
## absent 는 지금 데려가기로 표시한 대원들이다. 아직 출발하지 않았어도
## **미리 빠진 것으로 계산한다** — 그래야 고르는 동안 결과가 보인다.
func refresh(guild: Guild, absent: Array[String]) -> void:
	BaseWidgets.clear(self)
	if guild == null:
		return
	add_child(_status_box(guild))
	for kind in Facility.all():
		add_child(_facility_box(guild, kind as Facility.Kind, absent))
	add_child(_prospect_box(guild))


## 길드 상태. 성장 세 축 중 **주둔지 축이 전부 여기 있다**
## (docs/design/06-progression.md §6.1).
func _status_box(guild: Guild) -> BaseBox:
	var box := BaseBox.new(guild.display_name)
	box.line("길드 등급 %d" % guild.rank())
	box.line("자금 %d" % guild.funds)
	box.line(
		(
			"아지트 레벨 %d      진척 %d / %d"
			% [guild.base_level, guild.base_progress, GuildBalance.BASE_PROGRESS_TO_LEVEL]
		)
	)
	box.line("스쿼드 정원 %d" % guild.squad_capacity())
	box.line("마친 원정 %d" % guild.expeditions_settled, BaseWidgets.INK_DIM)
	return box


## 시설 하나. 배치된 사람과 **그중 지금 일하는 사람**을 함께 보여 준다.
func _facility_box(guild: Guild, kind: Facility.Kind, absent: Array[String]) -> BaseBox:
	var staff := guild.staff_at(kind, absent)
	var box := BaseBox.new(Facility.label(kind), staff > 0)
	box.line(Facility.note(kind), BaseWidgets.INK_DIM)
	box.line("일하는 인원 %d / %d" % [staff, GuildBalance.FACILITY_CAPACITY])

	var assigned := guild.assignment.members_at(kind)
	if assigned.is_empty():
		box.line("배치 없음", BaseWidgets.INK_DIM)
	for member_id in assigned:
		var member := guild.member_by_id(member_id)
		if member == null:
			continue
		if absent.has(member_id):
			box.line("%s      출전" % member.display_name, BaseWidgets.INK_MARK)
		else:
			box.line(member.display_name)

	# 정보실만 효과가 화면의 다른 기둥에 나타난다. 그 연결을 여기서도 한 줄 적어 둔다.
	if kind == Facility.Kind.INTEL_ROOM:
		box.line(
			"게이트 공개 수준 %s" % GateDisclosure.label(guild.gate_disclosure(absent)),
			BaseWidgets.INK_MARK
		)
	return box


## 접선처가 찾아낸 후보들. **영입 실행은 없다** (RecruitProspect, §22.7).
func _prospect_box(guild: Guild) -> BaseBox:
	var box := BaseBox.new("영입 후보")
	if guild.prospects.is_empty():
		box.line("아직 없음", BaseWidgets.INK_DIM)
		return box
	for prospect in guild.prospects:
		box.line(prospect.summary())
	box.line(guild.prospects[0].blocked_reason(), BaseWidgets.INK_DIM)
	return box
