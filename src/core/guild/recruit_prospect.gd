class_name RecruitProspect
extends RefCounted
## 접선처가 찾아낸 영입 후보. **여기까지가 접선처의 일이다.**
##
## ## 왜 영입 실행이 없는가 (docs/design/22-guild-base.md §22.7)
##
## docs/design/06-progression.md §6.1 이 확정했다 —
## **"영입은 자원만으로 되지 않고 던전에서 쌓은 관계를 요구한다"**
## (docs/design/05-rules.md §5.10 관계도).
##
## 이 클래스에는 영입 함수가 없다. Guild 에도 없다.
## 그것이 "아직 없다" 를 코드로 말하는 방법이다.
##
## ## 후보는 세계의 인물이다
##
## 예전에는 접선처가 **이름을 지어냈다.** 그러면 그 후보에게는 관계가 없고,
## 관계가 없으면 `can_recruit()` 이 볼 것이 없어 영원히 거짓이다 —
## **관계도를 만들어 놓고도 영입이 안 열리는 이유가 그것이었다.**
##
## 인구 3000명은 동결돼 있고 **인덱스가 곧 그 사람이다** (설계 24.24).
## 그러므로 후보를 지어내지 않고 인구에서 뽑는다. `person` 이 그 번호다.
##
## 이름과 계열을 여기에도 든 이유는 **인물 번호가 없는 후보가 아직 가능하기 때문**이다
## (세계 없이 정산하는 시험과 옛 저장이 그렇다). 세계가 있으면 둘은 인구에서 온 값이다.
##
## ## 판정은 RecruitStanding 이 한다
##
## 여기는 결과만 든다 — 후보가 `PersonRegistry` 와 `RelationGraph` 를
## 들고 다니지 않게 하려는 것이다.

## 후보를 가리키는 식별자.
var id: String

## 표시명.
var display_name: String

## 직업 계열.
var discipline: MemberDiscipline.Kind

## 이 후보를 찾아낸 시점의 원정 번호. 명단이 밀릴 때 오래된 것부터 나간다.
var found_at_expedition: int

## 세계의 인물 번호. **NO_PERSON 이면 세계 없이 만들어진 후보다.**
var person: int = PersonRegistry.NO_PERSON

## 누구를 통해 닿았나. **접선처는 연줄로 사람을 찾는다** —
## NO_PERSON 이면 연줄 없이 걸린 낯선 사람이다.
var introduced_by: int = PersonRegistry.NO_PERSON

## 관계 판정. **null 이면 아직 세계의 인물과 안 물린 것이다** (설계 24.1 의 2층).
var standing: RecruitStanding = null


func _init(
	prospect_id: String,
	name: String,
	prospect_discipline: MemberDiscipline.Kind,
	expedition_number: int = 0
) -> void:
	id = prospect_id
	display_name = name
	discipline = prospect_discipline
	found_at_expedition = expedition_number


## 영입할 수 있는가. **호감 · 유대 · 성향 궁합 셋이 서면 참이다** (설계 24.13).
func can_recruit() -> bool:
	return standing != null and standing.can_recruit()


## 영입이 막혀 있는 이유. 화면에 그대로 나간다.
func blocked_reason() -> String:
	if standing == null:
		return "이 후보가 세계의 인물과 아직 안 물려 있다 (인물-길드 층 미구현)"
	return standing.blocked_reason()


## 세계의 인물인가. 아니면 관계를 볼 수 없다.
func is_in_world() -> bool:
	return person != PersonRegistry.NO_PERSON


func summary() -> String:
	return "%s (%s)" % [display_name, MemberDiscipline.label(discipline)]


# ---------------------------------------------------------------- 저장


## 후보를 사전으로. **`standing` 은 담지 않는다** —
## 세계에서 계산되는 파생값이라, 담아 두면 세계와 어긋난 판정이 살아남는다.
## 불러올 때 다시 잰다 (Guild.from_dict).
func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"discipline": int(discipline),
		"found_at_expedition": found_at_expedition,
		"person": person,
		"introduced_by": introduced_by,
	}


static func from_dict(data: Dictionary) -> RecruitProspect:
	var prospect_id := String(data.get("id", ""))
	if prospect_id.is_empty():
		return null
	var discipline_kind := clampi(int(data.get("discipline", 0)), 0, MemberDiscipline.count() - 1)
	var prospect := RecruitProspect.new(
		prospect_id,
		String(data.get("display_name", prospect_id)),
		discipline_kind as MemberDiscipline.Kind,
		int(data.get("found_at_expedition", 0))
	)
	prospect.person = int(data.get("person", PersonRegistry.NO_PERSON))
	prospect.introduced_by = int(data.get("introduced_by", PersonRegistry.NO_PERSON))
	return prospect
