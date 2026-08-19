class_name EncounterMark
extends RefCounted
## 조우가 관계도로 내보내는 표시 하나. **판과 세계를 잇는 유일한 통로다.**
##
## docs/design/05-rules.md §5.10 — 협력 · 협상 · 전투의 결과가 친밀도를 움직인다.
## docs/design/35-encounter.md §35.4.2.
##
## ## 왜 여기서 관계도를 직접 안 고치나
##
## `RelationGraph` 는 **인물 번호**로 돌고 판 위의 `Actor` 는 **문자열 id** 로 돈다
## (docs/design/24-npc-relations.md §24.21.1 — 인접 목록이라 번호가 곧 자리다).
## 둘을 잇는 표는 세계와 판을 잇는 자리의 것이지 조우 절차의 것이 아니다.
##
## 여기서 번호를 알아내려 하면 조우 해결기가 `PersonRegistry` 를 알아야 하고,
## 그 순간 **던전 한 판을 세우는 데 인물 3000명이 필요해진다.** 시험이 못 돈다.
##
## ## 사건 종류를 새로 만들지 않는다
##
## `RelationEvent.Kind` 가 이미 스물한 종을 정의해 뒀고 조우에서 나는 것은 전부
## 그 안에 있다 — 협력 · 배신 · 협상 · 선제공격 · 약탈 · 지나침.
## 새로 만들면 §24.5 의 성향 벡터를 다시 정해야 한다.

## 무엇이 일어났는가.
var kind: RelationEvent.Kind

## 한 쪽. **관계 사건은 비대칭이므로 누가 했는지가 있어야 한다** (§24.2).
var actor_id: String

## 당한 쪽 · 함께한 쪽.
var target_ids: Array[String] = []


func _init(mark_kind: RelationEvent.Kind, mark_actor_id: String, targets: Array[String]) -> void:
	kind = mark_kind
	actor_id = mark_actor_id
	target_ids = targets.duplicate()


func involves(id: String) -> bool:
	return actor_id == id or target_ids.has(id)


## "협력 squad -> rival" 꼴. 개발 도구와 시험 실패 메시지가 쓴다.
func describe() -> String:
	return "%s %s > %s" % [RelationEvent.label(kind), actor_id, ", ".join(target_ids)]
