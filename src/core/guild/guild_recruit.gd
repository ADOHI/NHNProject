class_name GuildRecruit
extends RefCounted
## 후보 하나를 **실제로 데려온다.** 관계도가 처음으로 보상을 주는 자리다.
##
## docs/design/37-meta-loop.md §37.8, docs/design/14-squad.md §14.5,
## docs/design/06-progression.md §6.1 — *"영입은 자원만으로 되지 않고
## 던전에서 쌓은 관계를 요구한다."*
##
## ## 지금까지 이 함수가 없었다
##
## `RecruitProspect` 주석이 그것을 이렇게 적어 뒀다 —
## *"이 클래스에는 영입 함수가 없다. Guild 에도 없다.
## 그것이 「아직 없다」를 코드로 말하는 방법이다."*
##
## **이제 있다.** 그래서 판정(`RecruitStanding`)이 처음으로 무언가를 연다 —
## 그전까지는 「영입 가능」이라고 적히기만 하고 누를 데가 없었다.
##
## ## 새 규칙을 하나도 안 만든다
##
## | 물음 | 이미 아는 곳 |
## | --- | --- |
## | 데려올 수 있나 | `RecruitProspect.can_recruit()` — 호감 · 유대 · 위계 셋 |
## | 왜 안 되나 | `RecruitStanding.blocked_reason()` — 막힌 조건 하나만 낸다 (§24.17.4) |
## | 얼마를 내나 | **안 낸다.** 이 게임의 화폐는 관계다 (§6.1). Q29 는 미결이고 여기서 안 정한다 |
## | 데려온 사람의 능력치 | **계열 기본값.** 아래 |
##
## ## 왜 `Guild` 안이 아닌가
##
## 두 가지다. 하나는 `Guild` 가 이미 공개 함수 스물이라 늘릴 자리가 없다는 것이고,
## 다른 하나가 더 중요하다 — **영입은 길드의 상태가 아니라 세계와 길드 사이의 판정**이다.
## `RecruitStanding` 을 따로 뽑아 둔 것과 같은 이유다.

## 데려온 대원의 식별자 앞자리. 시작 대원(`member_N`)과 갈라 두면
## **세이브를 열었을 때 누가 나중에 온 사람인지 보인다.**
const ID_PREFIX := "hired_"


## 후보를 대원으로 만든다. 못 데려오면 `null` 이다.
##
## **인물 번호를 그대로 들고 온다.** 그래야 데려온 사람에게 여전히 가족과 원수가 있고
## (설계 24.29), 다음 판부터 그 사람의 관계가 내 관계가 된다.
static func hire(guild: Guild, prospect_id: String) -> GuildMember:
	var prospect := find(guild, prospect_id)
	if prospect == null or not prospect.can_recruit():
		return null

	# **능력치는 계열 기본값이다** (음수를 주면 GuildMember 가 그렇게 채운다).
	# 세계는 사람마다 다른 전투/민첩을 이미 들고 있지만(PersonRegistry), 그것을 쓰면
	# 데려온 대원만 시작 대원과 다른 자로 잰 값을 갖게 된다 — **계열별 능력이 미결이라**
	# (Q17) 지금 그 문을 열지 않는다. 열 때 고칠 곳은 이 한 줄이다.
	var member := GuildMember.new(_free_id(guild), prospect.display_name, prospect.discipline)
	member.person = prospect.person
	guild.add_member(member)
	guild.prospects.erase(prospect)
	guild.changed.emit()
	return member


## 명단에서 후보 하나를 찾는다. 없으면 null.
static func find(guild: Guild, prospect_id: String) -> RecruitProspect:
	if guild == null or prospect_id.is_empty():
		return null
	for prospect in guild.prospects:
		if prospect.id == prospect_id:
			return prospect
	return null


## 왜 못 데려오는가. **화면에 그대로 나간다** — 빈 문자열이면 데려올 수 있다.
##
## 사유를 여기서 새로 쓰지 않고 후보에게 묻는다. 두 곳에 적으면 갈라진다.
static func blocked_reason(guild: Guild, prospect_id: String) -> String:
	var prospect := find(guild, prospect_id)
	if prospect == null:
		return "명단에 없는 후보다"
	return "" if prospect.can_recruit() else prospect.blocked_reason()


## 아직 안 쓰인 대원 번호. **이름이 겹치면 배치표와 편성이 엉뚱한 사람을 가리킨다** —
## 시설 배치도 원정 편성도 식별자로만 사람을 부른다 (`FacilityAssignment`).
static func _free_id(guild: Guild) -> String:
	var number := guild.members.size()
	while guild.has_member(ID_PREFIX + str(number)):
		number += 1
	return ID_PREFIX + str(number)
