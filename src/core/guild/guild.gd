class_name Guild
extends RefCounted
## 길드 하나. 아웃게임의 상태가 전부 여기 모인다 — 자원 · 등급 · 대원 · 배치 · 후보.
##
## ## 길드 등급과 아지트 레벨은 같은 값이다
##
## 둘을 나누면 두 수치가 같은 일(무엇을 열 수 있는가)을 하게 된다.
## 갈라져야 할 이유가 생기면 그때 나눈다 (docs/design/22-guild-base.md §22.10).
## 그래서 rank() 는 base_level 을 그대로 돌려준다.
##
## ## 여기에 영입 함수가 없는 것은 의도다
##
## 영입은 자원이 아니라 던전에서 쌓은 관계를 요구한다
## (docs/design/06-progression.md §6.1, docs/design/05-rules.md §5.10).
## 후보 명단까지만 있다 (RecruitProspect).
##
## ## 길드가 세계에 발을 딛는 자리
##
## 관계도(`NpcWorld`)는 인물끼리의 것이고 길드는 아직 그 안에 없다
## (docs/design/24-npc-relations.md §24.1 의 2층이 미구현이다).
## 그런데 영입 판정은 **누가 누구를 어떻게 보는가**를 물어야 하고,
## 그러려면 길드 쪽에도 인물이 하나는 있어야 한다.
##
## 그래서 `leader_person` 하나만 세계에 발을 딛는다. **대원 전원을 세계 인물로 잇는 것이
## 2층이고 그것은 다음 순번이다.** 여기 하나로도 영입이 열리므로 지금은 이것으로 족하다
## (§24.16.1 — *"두 계층을 잇는 것은 영입 시점의 변환 하나로 족하다"*).

## 자원이나 아지트가 변했을 때. 화면 갱신의 신호다.
signal changed

## 길드 이름. 지금은 표시에만 쓴다.
var display_name: String

## 자금. 주둔지 축의 재료다 (docs/design/06-progression.md §6.1).
var funds: int = GuildBalance.STARTING_FUNDS

## 아지트 레벨. 영구 · 누적이며 실패해도 잃지 않는다.
var base_level: int = GuildBalance.STARTING_BASE_LEVEL

## 다음 레벨까지의 진척.
var base_progress: int = 0

## 보유 대원. 순서가 화면 순서다.
var members: Array[GuildMember] = []

## 시설 배치표.
var assignment := FacilityAssignment.new()

## 접선처가 찾아낸 영입 후보들.
var prospects: Array[RecruitProspect] = []

## 정산까지 끝난 원정 수. 후보 명단의 시간 표시에 쓴다.
var expeditions_settled: int = 0

## 인물과 관계의 세계. **null 이면 후보가 이름뿐인 사람으로 나온다.**
var world: NpcWorld = null

## 이 길드를 대표하는 세계의 인물. 영입 판정이 「후보가 이 사람을 어떻게 보는가」를 묻는다.
var leader_person: int = PersonRegistry.NO_PERSON

## 이미 정산한 원정 번호 장부.
##
## 보고서 쪽 플래그로도 막을 수 있지만, 그러면 보고서를 복제해 오면 뚫린다.
## **길드 쪽 장부가 더 강한 보증이라 판단의 근거를 여기 둔다**
## (docs/design/22-guild-base.md §22.6).
var _settled_ids: Dictionary = {}


func _init(name: String = "이름 없는 길드") -> void:
	display_name = name


## 시작 길드를 만든다. 계열 하나씩 다섯 명이다.
##
## 다섯인 이유는 정원(3)이 계열 수(5)보다 작아야 한다는 규칙을
## **첫 화면부터** 성립시키기 위해서다 (docs/design/14-squad.md §14.4.3).
## 넷 이하로 시작하면 초반에는 전부 데려갈 수 있어 편성이 결정이 아니게 된다.
##
## npc_world 를 주면 **길드가 세계에 발을 딛는다** — 대표 인물이 정해지고
## 접선처가 그 사람의 연줄로 후보를 찾는다 (GuildSettlement).
static func create_starting(
	seed_value: int = 0, name: String = "새벽 길드", npc_world: NpcWorld = null
) -> Guild:
	var guild := Guild.new(name)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var used := {}
	for discipline in MemberDiscipline.count():
		guild.add_member(
			GuildMember.new(
				"member_%d" % discipline,
				MemberNames.pick(rng, used),
				discipline as MemberDiscipline.Kind
			)
		)
	guild.bind_world(npc_world, rng)
	return guild


## 세계를 물린다. 대표는 **연줄이 있는 사람**으로 고른다 —
## 관계가 없는 사람을 세우면 접선처가 아무도 못 찾고, 그것은 세계의 사실이 아니라
## 뽑기 실패다 (NpcWorld.pick_connected).
func bind_world(npc_world: NpcWorld, rng: RandomNumberGenerator) -> void:
	if npc_world == null or not npc_world.is_ready():
		return
	world = npc_world
	leader_person = npc_world.pick_connected(rng)


# ---------------------------------------------------------------- 등급과 정원


## 길드 등급. 지금은 아지트 레벨과 같은 값이다.
func rank() -> int:
	return base_level


## 이번에 데려갈 수 있는 최대 인원.
func squad_capacity() -> int:
	return GuildBalance.squad_capacity(base_level)


# ---------------------------------------------------------------- 대원


func add_member(member: GuildMember) -> void:
	if member == null or has_member(member.id):
		return
	members.append(member)
	changed.emit()


func remove_member(member_id: String) -> void:
	for index in members.size():
		if members[index].id == member_id:
			members.remove_at(index)
			assignment.unassign(member_id)
			changed.emit()
			return


func has_member(member_id: String) -> bool:
	return member_by_id(member_id) != null


func member_by_id(member_id: String) -> GuildMember:
	for member in members:
		if member.id == member_id:
			return member
	return null


func member_ids() -> Array[String]:
	var ids: Array[String] = []
	for member in members:
		ids.append(member.id)
	return ids


## 주어진 대원들로 스쿼드를 짠다. 정원을 넘거나 모르는 대원이 있으면 null 이다.
##
## **검사를 여기서 하는 이유**는 편성이 아웃게임의 규칙이기 때문이다.
## Squad 쪽에서 검사하면 정원이라는 길드 상태를 Squad 가 알아야 한다.
func form_squad(deployed_ids: Array[String]) -> Squad:
	if deployed_ids.is_empty() or deployed_ids.size() > squad_capacity():
		return null
	var picked: Array[GuildMember] = []
	var seen := {}
	for member_id in deployed_ids:
		if seen.has(member_id):
			return null
		var member := member_by_id(member_id)
		if member == null:
			return null
		seen[member_id] = true
		picked.append(member)
	return Squad.new(picked)


# ---------------------------------------------------------------- 시설 효과


## 지금 이 시설에서 실제로 일하고 있는 인원.
##
## absent_ids 는 던전에 나가 있는 대원들이다 — 배치는 남아 있지만 일은 못 한다.
func staff_at(kind: Facility.Kind, absent_ids: Array[String] = []) -> int:
	return assignment.staff_count(kind, absent_ids)


## 지금 게이트를 얼마나 자세히 볼 수 있는가.
##
## 정보실 인원이 정한다. 정보실 대원을 데려가면 다음 목록이 도로 흐려진다
## (docs/design/22-guild-base.md §22.4).
func gate_disclosure(absent_ids: Array[String] = []) -> GateDisclosure.Level:
	return GateDisclosure.level_for(
		staff_at(Facility.Kind.INTEL_ROOM, absent_ids),
		GuildBalance.INTEL_STAFF_FOR_SURVEYED,
		GuildBalance.INTEL_STAFF_FOR_MAPPED
	)


## 지금 목록에 쓸 씨앗. 원정 한 번을 마칠 때마다 갈린다.
##
## **게이트는 만료된다.** 그놈들이 흥미를 잃은 문은 닫힌다
## (docs/design/02-overview.md §2.6.1, docs/design/22-guild-base.md §22.0).
## 만료 시각이나 남은 턴 같은 필드를 두는 대신 **원정 횟수를 시간으로 쓴다** —
## 아웃게임에 흐르는 시간은 그것뿐이라 별도의 시계를 만들 이유가 없다.
func board_seed_for(campaign_seed: int) -> int:
	return absi(campaign_seed + expeditions_settled * 104729)


## 지금 열려 있는 게이트 목록.
##
## 길드 등급이 상한을 정한다. 목록 자체는 정보실과 무관하다 —
## 정보실은 **얼마나 보이는가**를 바꿀 뿐 **무엇이 열려 있는가**를 바꾸지 않는다.
## 무엇이 열려 있는가는 그놈들이 정한다.
func open_gates(board_seed: int, count: int = GuildBalance.GATE_BOARD_SIZE) -> Array[Gate]:
	return GateBoard.create(board_seed, rank(), count)


# ---------------------------------------------------------------- 자원과 아지트


func add_funds(amount: int) -> void:
	funds = maxi(0, funds + amount)
	changed.emit()


## 아지트 진척을 더한다. 오른 레벨 수를 돌려준다.
##
## 진척은 **잃지 않는다.** 주둔지는 영구 · 누적 축이다
## (docs/design/06-progression.md §6.1).
func add_base_progress(amount: int) -> int:
	if amount <= 0:
		return 0
	base_progress += amount
	var gained := 0
	while (
		base_progress >= GuildBalance.BASE_PROGRESS_TO_LEVEL
		and base_level < GuildBalance.BASE_LEVEL_MAX
	):
		base_progress -= GuildBalance.BASE_PROGRESS_TO_LEVEL
		base_level += 1
		gained += 1
	if base_level >= GuildBalance.BASE_LEVEL_MAX:
		# 상한에 닿으면 남은 진척은 쌓아 두지 않는다. 쓸 데가 없는 수치가
		# 화면에 계속 오르면 플레이어는 무언가를 기다리게 된다.
		base_progress = 0
	changed.emit()
	return gained


# ---------------------------------------------------------------- 영입 후보


## 후보를 명단에 올린다. 넘치면 오래된 것부터 밀려난다.
func add_prospect(prospect: RecruitProspect) -> void:
	if prospect == null:
		return
	prospects.append(prospect)
	while prospects.size() > GuildBalance.PROSPECT_POOL_MAX:
		prospects.remove_at(0)
	changed.emit()


# ---------------------------------------------------------------- 정산 장부


func has_settled(expedition_id: String) -> bool:
	return _settled_ids.has(expedition_id)


## 정산이 끝났음을 장부에 적는다. 이미 적혀 있으면 false 다.
##
## GuildSettlement 만 부른다. 두 번 적용을 막는 유일한 관문이다.
func mark_settled(expedition_id: String) -> bool:
	if expedition_id.is_empty() or _settled_ids.has(expedition_id):
		return false
	_settled_ids[expedition_id] = true
	expeditions_settled += 1
	return true
