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
## 이 패널은 길드를 읽기만 한다. **바꾸는 것은 화면이 코어에게 시킨다**
## (conventions.md §3.3 — call down, signal up).

## 이 후보를 데려와 달라. 화면이 `GuildRecruit.hire` 를 부른다.
signal recruit_pressed(prospect_id: String)


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
	add_child(_news_box(guild))


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
##
## 후보마다 **판정 한 줄**을 같이 낸다. 예전에는 첫 후보의 사유 한 줄만 냈는데,
## 그때는 사유가 전부 같았기 때문이다 — 관계도가 붙은 지금은 후보마다 다르다.
##
## **연줄을 적는 이유**는 그것이 이 화면에서 관계도가 하는 일이기 때문이다.
## *"박다성을 통해"* 가 붙으면 후보가 어디서 왔는지가 정보가 된다
## (docs/design/24-npc-relations.md §24.8).
func _prospect_box(guild: Guild) -> BaseBox:
	var box := BaseBox.new("영입 후보")
	if guild.prospects.is_empty():
		box.line("아직 없음", BaseWidgets.INK_DIM)
		return box
	for prospect in guild.prospects:
		box.body.add_child(_prospect_row(prospect))
		box.line(_prospect_note(guild, prospect), BaseWidgets.INK_DIM)
	return box


## 후보 한 줄 — 이름과 **데려오는 단추.**
##
## 단추는 데려올 수 있을 때만 켜진다. 잠긴 채로 두는 이유는 아래 줄이 **왜 안 되는지**를
## 이미 말하고 있기 때문이다 — 단추를 숨기면 그 사유가 무엇에 대한 말인지 안 읽힌다.
func _prospect_row(prospect: RecruitProspect) -> HBoxContainer:
	var row := BaseWidgets.row()
	var take := BaseWidgets.button("데려온다", prospect.can_recruit())
	take.pressed.connect(_on_recruit_pressed.bind(prospect.id))
	row.add_child(take)
	var name_label := BaseWidgets.label(
		prospect.summary(), BaseWidgets.SIZE_BODY, _prospect_ink(prospect)
	)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	return row


func _on_recruit_pressed(prospect_id: String) -> void:
	recruit_pressed.emit(prospect_id)


## 세계 소식. **판을 돌면 세계가 달라진다는 것이 화면에 나타나는 자리다** (설계 15.2.1).
##
## 문장은 코어가 만든다 (`WorldNews`) — 고르는 규칙도 조사도 화면의 일이 아니다.
## 세계가 안 물려 있으면 그 사실을 적는다. **빈 칸을 남기지 않는다.**
func _news_box(guild: Guild) -> BaseBox:
	var box := BaseBox.new("세계 소식")
	if guild.world == null or not guild.world.is_ready():
		box.line("세계가 안 물려 있다", BaseWidgets.INK_DIM)
		return box
	box.line("세계가 %d틱 돌았다" % guild.world_progress.tick_count(), BaseWidgets.INK_DIM)
	var news := WorldNews.gather(
		guild.world, GuildCircle.known_of(guild), GuildCircle.own_of(guild)
	)
	if news.is_empty():
		box.line("아는 얼굴 소식은 없다", BaseWidgets.INK_DIM)
	for line in news:
		box.line(line)
	return box


## 영입 가능한 후보만 밝게. **명단에서 눈에 띄어야 하는 것이 그것 하나다.**
func _prospect_ink(prospect: RecruitProspect) -> Color:
	return BaseWidgets.INK_MARK if prospect.can_recruit() else BaseWidgets.INK


## 후보 한 줄 아래에 붙는 말 — **누구를 통해 왔고, 되는가 안 되는가.**
func _prospect_note(guild: Guild, prospect: RecruitProspect) -> String:
	var judged := prospect.blocked_reason()
	if prospect.can_recruit():
		judged = "영입 가능 (호감 %+d 유대 %d)" % [prospect.standing.affinity, prospect.standing.bond]
	var introducer := _introducer(guild, prospect)
	return judged if introducer.is_empty() else "%s • %s" % [introducer, judged]


## 누구의 연줄인가. 연줄 없이 걸린 사람이면 빈 문자열이다.
func _introducer(guild: Guild, prospect: RecruitProspect) -> String:
	if guild.world == null or prospect.introduced_by == PersonRegistry.NO_PERSON:
		return ""
	if not guild.world.registry.has(prospect.introduced_by):
		return ""
	# 조사를 받침으로 고른다 — `양은담를` 이 나오면 이름이 이름으로 안 읽힌다.
	var who := guild.world.registry.name_of(prospect.introduced_by)
	return "%s%s 통해" % [who, KoreanParticle.object_of(who)]
