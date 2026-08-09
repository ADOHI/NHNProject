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
## ## 판정은 붙었다 — 관계가 물려 있으면 참이 나온다
##
## 관계도(`RelationGraph`)와 사건(`RelationResolver`)이 서면서
## **`can_recruit()` 이 더 이상 상수가 아니다.** 판정 자체는 `RecruitStanding` 이 하고
## 여기는 그 결과만 든다 — 후보가 `PersonRegistry` 를 들고 다니지 않게 하려는 것이다.
##
## **아직 안 물린 자리가 하나 남았다.** 접선처(`GuildSettlement`)는 후보를
## 이름과 계열로만 만들고 세계의 인물 번호를 모른다. 그것을 잇는 것이
## 설계 24.1 의 2층(인물↔길드)이고, 그때까지 `standing` 은 비어 있다.
## **빈 채로 두는 것이 임시 판정을 넣는 것보다 낫다** — 그래야 화면이 왜 막혔는지 말한다.

## 후보를 가리키는 식별자.
var id: String

## 표시명.
var display_name: String

## 직업 계열.
var discipline: MemberDiscipline.Kind

## 이 후보를 찾아낸 시점의 원정 번호. 명단이 밀릴 때 오래된 것부터 나간다.
var found_at_expedition: int

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


func summary() -> String:
	return "%s (%s)" % [display_name, MemberDiscipline.label(discipline)]
