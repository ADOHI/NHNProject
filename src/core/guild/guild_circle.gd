class_name GuildCircle
extends RefCounted
## 길드가 **아는 얼굴들.** 세계의 인물 번호로 낸다.
##
## docs/design/37-meta-loop.md §37.6.2.
##
## ## 왜 `Guild` 안이 아닌가
##
## 길드는 이미 자원 · 등급 · 대원 · 배치 · 후보 · 장부를 든다. 거기에 「누구를 아는가」를
## 더하면 **길드가 세계를 훑는 법까지 알게 된다** — 판정을 값으로 뽑아 두는 것이
## 이 저장소의 습관이고(`RecruitStanding` · `SettlementSheet`), 여기도 같다.
##
## ## 두 묶음이 다른 일을 한다
##
## | 묶음 | 뉴스에서 하는 일 |
## | --- | --- |
## | `known_of` | **이 소식을 볼 만한가** — 아는 얼굴이 끼면 본다 |
## | `own_of` | **이것이 내가 한 일인가** — 내 사람끼리면 소식이 아니다 |
##
## 둘을 하나로 묶으면 `WorldNews` 가 둘을 구분 못 하고, 그러면 피드가
## 「내 대원과 내 대원이 같이 뛰었다」로 도배된다 (`WorldNews` 주석의 실측).


## 내가 아는 얼굴들. **뉴스가 무엇을 보여 줄지 이것이 정한다.**
##
## 대원과 후보뿐 아니라 **후보를 소개한 사람**까지 넣는다 — 접선처가 연줄로 사람을
## 찾아 오므로(`SocialReach`) 그 연줄이 곧 내가 이름을 들어 본 사람이다.
static func known_of(guild: Guild) -> PackedInt32Array:
	var found := PackedInt32Array()
	if guild == null:
		return found
	var seen := {}
	for person in own_of(guild):
		seen[person] = true
		found.append(person)
	for prospect in guild.prospects:
		for person in [prospect.person, prospect.introduced_by]:
			if person != PersonRegistry.NO_PERSON and not seen.has(person):
				seen[person] = true
				found.append(person)
	return found


## 내 대원들. 세계에 안 물린 대원은 빠진다 — 그 사람에게는 인물 번호가 없다.
static func own_of(guild: Guild) -> PackedInt32Array:
	var found := PackedInt32Array()
	if guild == null:
		return found
	for member in guild.members:
		if member.is_in_world():
			found.append(member.person)
	return found
