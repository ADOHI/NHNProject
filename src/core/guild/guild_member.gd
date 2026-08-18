class_name GuildMember
extends RefCounted
## 길드에 소속된 대원 하나. **아웃게임 개체이며 Actor 가 아니다.**
##
## ## 왜 Actor 로 두지 않았는가 (docs/design/22-guild-base.md §22.2)
##
## 1. **판 위의 말은 하나다.** docs/design/14-squad.md §14.2 가 확정한 규칙이다.
##    대원 하나당 Actor 하나를 만들면 방의 개체 수가 인원만큼 늘어나고,
##    그 순간 docs/design/13-information-design.md §13.5 의 "개체 수" 가 뜻을 잃는다.
## 2. **Actor 는 던전 안의 개념이다.** 대원은 시설 배치 · 영입 · 관계처럼
##    던전이 알 필요 없는 속성을 가진다. 그것을 Actor 에 붙이면
##    src/core/dungeon/ 이 아웃게임을 알게 되고, 던전을 단독으로 테스트할 수 없다.
## 3. **접는 규칙이 이미 있다.** SquadStats 가 전투력=합 · 민첩=평균 을 못 박아 두었다.
##    대원이 곧 Actor 라면 그 클래스가 쓰일 자리가 없다.
##
## 대원들은 Squad 를 거쳐 **Actor 하나**로 접힌다. 그 접히는 순간이 편성이다.

## 길드 안에서 이 대원을 가리키는 식별자.
var id: String

## 표시명. 렉카 기사가 아웃게임 인물을 부를 때도 이 이름을 쓴다.
var display_name: String

## 직업 계열. 잠정 5계열 (MemberDiscipline).
var discipline: MemberDiscipline.Kind

## 전투력. 스쿼드에서 **합산**된다 (docs/design/14-squad.md §14.3).
var threat: int

## 민첩. 스쿼드에서 **평균**된다 (§14.3.1).
var agility: int

## 세계의 인물 번호. **NO_PERSON 이면 세계 없이 만들어진 대원이다.**
##
## 이것이 있어야 대원에게 **가족과 원수가 있다.** 없으면 이름뿐인 사람이고,
## 조우 화면에서 *"저쪽에 내 대원의 형이 있다"* 가 성립하지 않는다
## (docs/design/24-npc-relations.md §24.29).
var person: int = PersonRegistry.NO_PERSON


func _init(
	member_id: String,
	name: String,
	member_discipline: MemberDiscipline.Kind,
	member_threat: int = -1,
	member_agility: int = -1
) -> void:
	id = member_id
	display_name = name
	discipline = member_discipline
	# 음수를 주면 계열 기본값을 쓴다. 대원 대부분은 계열 그대로라
	# 매번 두 숫자를 적게 하면 계열별 성향이 흐려진다.
	threat = MemberDiscipline.base_threat(member_discipline) if member_threat < 0 else member_threat
	agility = (
		MemberDiscipline.base_agility(member_discipline) if member_agility < 0 else member_agility
	)


## 세계의 인물인가. 아니면 관계를 볼 수 없다.
func is_in_world() -> bool:
	return person != PersonRegistry.NO_PERSON


## 목록에 한 줄로 나가는 요약.
func summary() -> String:
	return (
		"%s (%s) 전투 %d 민첩 %d" % [display_name, MemberDiscipline.label(discipline), threat, agility]
	)
