class_name ExpeditionReport
extends RefCounted
## 원정 한 번의 결과. **정산의 입력이다.**
##
## 이 클래스가 따로 있는 이유는 정산이 던전을 몰라야 하기 때문이다.
## GuildSettlement 가 DungeonRun 을 읽으면 아웃게임이 인게임 구조에 묶이고,
## 나중에 인게임이 바뀔 때마다 정산을 다시 짜야 한다.
## **던전에서 나온 것은 여기서 네 칸으로 줄어든다** — 어디로, 몇 턴, 누구와, 어떻게 끝났나.
##
## 이벤트 로그(GameEvent)와 칸이 겹쳐 보이지만 층이 다르다.
## 로그는 판 안의 사건이고 이것은 판 하나의 요약이다.

## 원정이 끝난 방식.
enum Outcome {
	ESCAPED,  ## 탈출 성공. 전리품이 들어온다
	DOWNED,  ## 쓰러졌다. 빈손 귀환 (docs/design/14-squad.md §14.6)
	RECALLED,  ## 중도 회수. 결과는 빈손과 같다
}

const _OUTCOME_LABELS := ["탈출 성공", "쓰러짐", "중도 회수"]

## 원정 번호. 정산 장부의 열쇠다 (Guild.mark_settled).
var id: String

var gate_id: String
var gate_name: String
var gate_rank: GateRank.Kind

## 어떻게 끝났는가.
var outcome: Outcome

## 던전 안에서 보낸 턴 수.
var turns: int

## 데려간 대원들.
var deployed_ids: Array[String] = []

## 아지트에 남은 대원들. **시설 효과를 내는 것은 이쪽뿐이다.**
var garrison_ids: Array[String] = []

## 자금으로 환산된 전리품. 실패하면 0 이다.
var loot_funds: int = 0

## 정산이 끝났다는 표시. **판단의 근거는 아니다** — 그것은 길드 장부다.
## 화면이 같은 보고서를 두 번 그리지 않도록 하는 용도다.
var is_settled: bool = false


func _init(
	report_id: String,
	gate: Gate,
	report_outcome: Outcome,
	report_turns: int,
	deployed: Array[String],
	garrison: Array[String]
) -> void:
	id = report_id
	gate_id = gate.id if gate != null else ""
	gate_name = gate.display_name if gate != null else ""
	gate_rank = gate.rank if gate != null else GateRank.Kind.E
	outcome = report_outcome
	turns = maxi(0, report_turns)
	deployed_ids = deployed.duplicate()
	garrison_ids = garrison.duplicate()
	loot_funds = GuildBalance.loot_for(gate_rank, turns, is_success())


## 판이 스스로 끝났을 때 그것이 어떤 끝인가.
##
## **끝나는 길이 둘인데 둘 다 `DungeonRun.finished` 를 세운다** — 탈출해서 나가거나
## (docs/design/05-rules.md §5.9), 조우에서 제압당하거나 (§35.2.3).
## **안 가르면 털리고 나온 판이 탈출 성공으로 정산된다.**
##
## 화면이 아니라 여기 있는 이유: 이것은 그리는 방법이 아니라 **규칙**이다
## (`conventions.md` §3.1). 화면에 두면 `Router.go_to()` 가 씬을 갈아 끼우는 통에
## 헤드리스로 못 덮는다 — 실제로 그 자리가 한 번 비어 있었다.
##
## **중도 회수(`RECALLED`)는 여기서 안 나온다.** 그것은 판이 끝난 것이 아니라
## 사람이 그만둔 것이라 호출자가 직접 고른다.
static func outcome_for(defeated: bool) -> Outcome:
	return Outcome.DOWNED if defeated else Outcome.ESCAPED


## 원정 번호. 정산 장부의 열쇠다 (Guild.mark_settled).


static func outcome_label(value: Outcome) -> String:
	return _OUTCOME_LABELS[clampi(int(value), 0, _OUTCOME_LABELS.size() - 1)]


## 판이 스스로 끝났을 때 그것이 어떤 끝인가.
##
## **끝나는 길이 둘인데 둘 다 `DungeonRun.finished` 를 세운다** — 탈출해서 나가거나
## (docs/design/05-rules.md §5.9), 조우에서 제압당하거나 (§35.2.3).
## **안 가르면 털리고 나온 판이 탈출 성공으로 정산된다.**
##
## 화면이 아니라 여기 있는 이유: 이것은 그리는 방법이 아니라 **규칙**이다
## (`conventions.md` §3.1). 화면에 두면 `Router.go_to()` 가 씬을 갈아 끼우는 통에
## 헤드리스로 못 덮는다 — 실제로 그 자리가 한 번 비어 있었다.
##
## **중도 회수(`RECALLED`)는 여기서 안 나온다.** 그것은 판이 끝난 것이 아니라
## 사람이 그만둔 것이라 호출자가 직접 고른다.
static func outcome_for(defeated: bool) -> Outcome:
	return Outcome.DOWNED if defeated else Outcome.ESCAPED


## 전리품을 들고 나왔는가.
func is_success() -> bool:
	return outcome == Outcome.ESCAPED


## 화면에 한 줄로 나가는 요약.
func summary() -> String:
	return "%s [%s] %d턴 %s" % [gate_name, GateRank.label(gate_rank), turns, outcome_label(outcome)]
