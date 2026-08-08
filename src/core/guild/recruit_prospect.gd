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
## 관계도는 아직 구현이 없다. 자원으로 사는 영입을 임시로 넣으면
## 그 확정이 코드에서 뒤집히고, 관계도가 붙을 때 뜯어내야 한다.
## **그래서 후보를 찾는 데까지만 만들고, 다음 칸은 비워 둔다.**
##
## 이 클래스에는 영입 함수가 없다. Guild 에도 없다.
## 그것이 "아직 없다" 를 코드로 말하는 방법이다.

## 후보를 가리키는 식별자.
var id: String

## 표시명.
var display_name: String

## 직업 계열.
var discipline: MemberDiscipline.Kind

## 이 후보를 찾아낸 시점의 원정 번호. 명단이 밀릴 때 오래된 것부터 나간다.
var found_at_expedition: int


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


## 영입할 수 있는가. **지금은 언제나 아니다.**
##
## 관계도가 붙으면 이 함수가 친밀도를 보게 된다. 그때까지는
## 화면이 "왜 안 되는가" 를 말할 수 있도록 이유와 함께 막아 둔다.
func can_recruit() -> bool:
	return false


## 영입이 막혀 있는 이유. 화면에 그대로 나간다.
func blocked_reason() -> String:
	return "관계가 부족하다 (관계도 미구현)"


func summary() -> String:
	return "%s (%s)" % [display_name, MemberDiscipline.label(discipline)]
