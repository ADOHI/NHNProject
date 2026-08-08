class_name Squad
extends RefCounted
## 이번 판에 데려가는 대원들. **아웃게임과 인게임이 만나는 유일한 지점이다.**
##
## docs/design/14-squad.md §14.2 —
## "모든 스쿼드 속성이 편성에서 결정되고, 던전 안에서는 바뀌지 않는다."
##
## 이 클래스가 그 문장을 코드로 옮긴 것이다. to_actor() 를 지나는 순간
## 대원 개개인은 사라지고 **전투력과 민첩 두 숫자만** 남는다.
## 변환 지점이 하나뿐이라, 던전 안에서 대원 목록을 다시 들여다볼 방법이 없다.
##
## 접는 규칙 자체는 SquadStats 에 있다 (전투력=합, 민첩=평균 내림).
## 여기서 다시 구현하지 않는다 — 규칙이 두 곳에 있으면 반드시 갈라진다.

## 던전 안에서 스쿼드를 가리키는 식별자.
##
## SampleDungeons 가 세우는 플레이스홀더와 같은 값이다.
## 갈아 끼워도 사건 기록이 이어지게 하려면 같아야 한다.
const ACTOR_ID := "player_squad"

## 판 위에 뜨는 이름. 길드 이름을 짓는 기능이 없으므로 고정이다 (§22.10).
const ACTOR_NAME := "우리 스쿼드"

var members: Array[GuildMember] = []


func _init(squad_members: Array[GuildMember] = []) -> void:
	members = squad_members.duplicate()


func size() -> int:
	return members.size()


func is_empty() -> bool:
	return members.is_empty()


func member_ids() -> Array[String]:
	var ids: Array[String] = []
	for member in members:
		ids.append(member.id)
	return ids


## 전투력 합. 그대로 판 위 위험도 기여가 된다 (docs/design/14-squad.md §14.3).
func threat() -> int:
	var values: Array[int] = []
	for member in members:
		values.append(member.threat)
	return SquadStats.threat_of(values)


## 민첩 평균(내림). 올라갈 수 있는 곳을 정한다 (§14.3.1).
func agility() -> int:
	var values: Array[int] = []
	for member in members:
		values.append(member.agility)
	return SquadStats.agility_of(values)


## 데려간 계열들. 중복 없이, 정의된 순서대로.
##
## "무엇을 포기했는가" 를 화면에 보여 주기 위한 것이다 (§14.4.4).
func disciplines() -> Array[int]:
	var seen := {}
	for member in members:
		seen[int(member.discipline)] = true
	var result: Array[int] = []
	for kind in MemberDiscipline.count():
		if seen.has(kind):
			result.append(kind)
	return result


## 판 위의 말 하나로 접는다. **아웃게임에서 인게임으로 넘어가는 유일한 문이다.**
func to_actor() -> Actor:
	return Actor.new(ACTOR_ID, ACTOR_NAME, Actor.Kind.PLAYER_SQUAD, threat(), agility())
