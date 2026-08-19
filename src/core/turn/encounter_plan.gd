class_name EncounterPlan
extends RefCounted
## NPC 하나가 조우에서 무엇을 골랐는가, **그리고 왜.**
##
## docs/design/35-encounter.md §35.4.4.
##
## ## 근거가 왜 값에 붙어 있나
##
## 점수만 내면 **왜 그렇게 골랐는지 아무 데도 안 남는다.** 조우가 이상하게 풀렸을 때
## 「점수가 왜 그랬는가」를 되짚을 수 없으면 성향을 손볼 근거가 없고,
## 그러면 밸런싱이 감으로 바뀐다.
##
## **연출이 아니라 개발 도구다.** `tools/survey_encounter.gd` 가 이 문장을 표로 뽑는다.
## 화면이 이것을 그대로 띄우면 상대의 속을 다 보여 주는 셈이라
## docs/design/05-rules.md §5.4 의 *"단서는 보이지만 확신은 못 한다"* 가 깨진다 —
## **화면에 그대로 내보내지 마라.**

## 누가.
var actor_id: String

## 무엇을.
var choice: EncounterChoice.Kind = EncounterChoice.Kind.STAND

## 왜. 점수를 가장 크게 민 항 둘을 이어 붙인 한 줄이다.
var reason: String = ""

## 선택지마다의 점수. `EncounterChoice.Kind` 순서와 나란하다.
##
## 근거 문장이 두 항만 담으므로 나머지가 어떻게 나왔는지는 이것으로만 보인다.
var scores: Array[int] = []


func _init(plan_actor_id: String, plan_choice: EncounterChoice.Kind, plan_reason: String) -> void:
	actor_id = plan_actor_id
	choice = plan_choice
	reason = plan_reason


## "칼날의 요한 전투 (유리하다, 무모하다)" 꼴의 한 줄. 개발 도구가 쓴다.
func describe(display_name: String) -> String:
	var head := "%s %s" % [display_name, EncounterChoice.label(choice)]
	return head if reason.is_empty() else "%s (%s)" % [head, reason]


## 그 선택지가 받은 점수. 안 재진 것은 0 이다.
func score_of(kind: EncounterChoice.Kind) -> int:
	var slot := int(kind)
	return scores[slot] if slot >= 0 and slot < scores.size() else 0
