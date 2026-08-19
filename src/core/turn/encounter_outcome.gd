class_name EncounterOutcome
extends RefCounted
## 조우 하나를 푼 결과 전부. 화면 · 렉카 피드 · 관계도가 읽는다.
##
## docs/design/05-rules.md §5.8 · docs/design/35-encounter.md §35.2.
##
## ## `Encounter` 와 무엇이 다른가
##
## `Encounter` 는 **났다는 사실**이고 이쪽은 **어떻게 됐는가**다.
## 하나가 여러 턴에 걸치므로 `Encounter` 하나에 `EncounterOutcome` 이 여럿 달린다 —
## §5.8 의 *"전투 지속 -> 다음 턴에도 조우 상태"* 가 그것이다.
##
## ## 결말이 아니라 **이번 턴의 결말**이다
##
## `continues` 가 참이면 아무것도 안 끝났다는 뜻이 아니라 **다음 턴에도 붙어 있다**는
## 뜻이다. 조우를 단발 판정으로 만들지 않는 것이 §5.8 의 전부이므로
## (*"버티면 기회가 생긴다"*), 끝나지 않은 것이 정상이다.

## 몇 턴에.
var turn: int

var room_id: String
var room_name: String

## **E5** — 이 방이 판돈과 확률을 어떻게 바꿨는가.
var stakes: EncounterStakes = null

## actor_id -> 그 주체가 실제로 쓴 태세. 몬스터도 들어간다(언제나 전투).
##
## **낸 것이 아니라 쓰인 것이다.** 몬스터가 없는 방에서 「협력」을 냈으면
## 여기에는 「전투」가 들어 있다 (`EncounterChoice.settle()`).
var choices: Dictionary = {}

## NPC 가 왜 그렇게 골랐는가. 플레이어와 몬스터는 여기 없다.
var plans: Array[EncounterPlan] = []

## 협상이 성립한 자들. 둘 이상이어야 성립한다 (§35.2.1).
var negotiated_ids: Array[String] = []

## 협력이 성립한 자들. 몬스터가 있고 둘 이상이 골라야 성립한다 (E9).
var allied_ids: Array[String] = []

## 도주에 성공해 방을 뜬 자들.
var fled_ids: Array[String] = []

## 도주에 실패한 자들. **등을 보인 대가**를 문다 (§35.3.1).
var failed_flight_ids: Array[String] = []

## 무너진 사람. **죽지 않는다 — 제압된다** (docs/design/28-combat.md §28.10).
var subdued_ids: Array[String] = []

## 무너진 몬스터. **죽는다** (§28.10).
var slain_ids: Array[String] = []

## 이번 턴 싸움에서 **가장 센 편에 선 자들.** 약탈이 이들에게 간다.
##
## 교착(모든 편의 힘이 같다)이면 비어 있다 — 아무도 안 이겼고 아무도 안 밀렸다.
var victor_ids: Array[String] = []

## 탈출 진행이 0 으로 돌아간 자들. **탈출 지점에서 도주하면** 그렇다 (§35.3.2 E5).
var escape_reset_ids: Array[String] = []

## actor_id -> 이번 조우에서 손에 넣은 값. 협상으로 나눈 몫과 약탈한 짐이다.
var spoils: Dictionary = {}

## actor_id -> 이번 턴에 쌓인 밀림. **0 이면 안 밀렸다.**
var pressure_dealt: Dictionary = {}

## 관계도로 나가는 표시들 (§35.4.2).
var marks: Array[EncounterMark] = []

## 로그로 나갈 사건들. **붓는 것은 해결 순서 5단계 한 곳뿐이다** (§33.1).
var events: Array[GameEvent] = []

## 다음 턴에도 조우 상태인가. §5.8 의 *"전투 지속"* 이 이 값이다.
var continues: bool = false


func _init(outcome_turn: int, encounter: Encounter) -> void:
	turn = outcome_turn
	if encounter != null:
		room_id = encounter.room_id
		room_name = encounter.room_name


## 그 주체가 쓴 태세. 안 낀 주체는 대치로 읽힌다.
func choice_of(actor_id: String) -> EncounterChoice.Kind:
	return choices.get(actor_id, EncounterChoice.Kind.STAND)


## 그 NPC 가 왜 그렇게 골랐는가. 없으면 `null`.
func plan_of(actor_id: String) -> EncounterPlan:
	for plan in plans:
		if plan.actor_id == actor_id:
			return plan
	return null


func spoil_of(actor_id: String) -> int:
	return int(spoils.get(actor_id, 0))


func pressure_on(actor_id: String) -> int:
	return int(pressure_dealt.get(actor_id, 0))


## 누가 무너졌는가. 사람이든 몬스터든.
func someone_broke() -> bool:
	return not subdued_ids.is_empty() or not slain_ids.is_empty()


## 아무도 치지 않은 조우인가. **E2 와 다르다** — 이쪽은 같은 방에 섰는데 안 친 것이다.
func was_bloodless() -> bool:
	for actor_id in choices:
		if EncounterChoice.means_harm(choices[actor_id]):
			return false
	return true
