class_name Expedition
extends RefCounted
## 원정 한 바퀴. **게이트 선택 -> 편성 -> 진입 -> 결과 -> 정산을 하나로 잇는다.**
##
##     게이트 목록  ->  Expedition.new(길드, 게이트)
##                       ->  deploy()   데려갈 자 / 남길 자
##                       ->  enter()    던전 진입 (기존 생성기 그대로)
##                       ->  finish()   결과
##                       ->  settle()   아지트 정산
##
## ## 왜 상태 기계인가
##
## 이 순서는 되돌릴 수 없다. 편성 전에 들어갈 수 없고, 끝나기 전에 정산할 수 없다.
## 그 순서를 화면마다 다시 확인하게 두면 화면이 늘어날 때마다 빠뜨리는 곳이 생긴다.
## **순서를 아는 곳을 하나로 둔다** (docs/design/22-guild-base.md §22.1).
##
## ## 기존 코드를 건드리지 않는 방법
##
## SampleDungeons.create_run() 은 자체 플레이스홀더 스쿼드를 세운다.
## 시그니처를 바꾸지 않기 위해, 판을 만든 뒤 그 말을 우리 스쿼드로 **갈아 끼운다**.
## 입구 위험도 조정은 스쿼드를 놓기 전에 끝나므로 결과가 달라지지 않는다 (§22.2).

## 원정이 밟는 단계. 되돌아가지 않는다.
enum Stage {
	PLANNING,  ## 편성 중. 아직 아무도 나가지 않았다
	DEPLOYED,  ## 던전 안. 데려간 대원은 시설 효과를 내지 못한다
	RETURNED,  ## 돌아왔다. 보고서가 나왔다
	SETTLED,  ## 정산까지 끝났다
}

## 원정 번호를 겹치지 않게 매기는 카운터.
##
## 정산 장부의 열쇠이므로 겹치면 두 번째 원정이 정산되지 않는다.
## 길드의 원정 횟수로 매기면 같은 게이트에 두 번 들어갈 때 겹칠 수 있어 따로 센다.
static var _next_number: int = 0

## 정산 장부의 열쇠.
var id: String

## 어느 게이트로.
var gate: Gate

var stage: Stage = Stage.PLANNING

## 데려가는 대원들. 편성 전에는 null 이다.
var squad: Squad = null

## 진입한 던전. 진입 전에는 null 이다.
var run: DungeonRun = null

## 결과. 끝나기 전에는 null 이다.
var report: ExpeditionReport = null

## 정산 결과. 정산 전에는 null 이다.
var result: SettlementResult = null

var _guild: Guild
var _deployed_ids: Array[String] = []


func _init(guild: Guild, target_gate: Gate) -> void:
	_guild = guild
	gate = target_gate
	_next_number += 1
	id = "exp_%d" % _next_number


# ---------------------------------------------------------------- 편성


## 데려갈 대원을 정한다. 정원을 넘거나 모르는 대원이 있으면 실패한다.
##
## **데려갈 자를 고르는 것이 곧 남길 자를 고르는 것이다.**
## 남은 사람만 시설 효과를 내므로(Facility), 이 한 번의 호출이 두 결정을 동시에 내린다.
func deploy(member_ids: Array[String]) -> bool:
	if stage != Stage.PLANNING:
		return false
	var formed := _guild.form_squad(member_ids)
	if formed == null:
		return false
	squad = formed
	_deployed_ids = member_ids.duplicate()
	return true


## 이 원정을 보낸 길드.
##
## **정산 화면이 길드를 따로 받지 않게 하려고 연다** (docs/design/36-settlement.md §36.5.2).
## 원정과 길드를 따로 넘기면 둘이 어긋날 자리가 생긴다 — 정산은 A 길드에 걸리고
## 화면은 B 길드를 그리는 종류의 버그다. **읽기만 한다. 갈아 끼우지 않는다.**
func guild() -> Guild:
	return _guild


## 데려가는 대원들.
func deployed_ids() -> Array[String]:
	return _deployed_ids.duplicate()


## 아지트에 남는 대원들. 시설 효과를 내는 것은 이쪽뿐이다.
func garrison_ids() -> Array[String]:
	var remaining: Array[String] = []
	for member_id in _guild.member_ids():
		if not _deployed_ids.has(member_id):
			remaining.append(member_id)
	return remaining


# ---------------------------------------------------------------- 진입


## 던전에 들어간다. 편성이 끝나 있어야 한다.
##
## 던전 생성은 게이트가 들고 있는 씨앗으로 기존 생성기가 한다 —
## 같은 게이트는 언제나 같은 판을 연다 (Gate).
func enter() -> DungeonRun:
	if stage != Stage.PLANNING or squad == null:
		return null
	# **민첩이 모자라면 여기서 막는다.** 들어간 뒤에 「보스까지 못 간다」를 알게 되면
	# 그 판은 편성 실수가 아니라 **알 수 없었던 실패**가 된다 (Gate.can_enter).
	if not gate.can_enter(squad.agility()):
		return null
	run = gate.create_run()
	_swap_in_squad(run, squad)
	stage = Stage.DEPLOYED
	return run


## 플레이스홀더 스쿼드를 편성한 스쿼드로 갈아 끼운다.
##
## SampleDungeons 를 고치지 않기 위한 조치다 (§22.2).
## 같은 방에 다시 놓으므로 판의 구조도 위험도 배치도 그대로다.
static func _swap_in_squad(target_run: DungeonRun, formed: Squad) -> void:
	var room_id := target_run.player_room_id()
	target_run.graph.remove_actor(target_run.player)
	var actor := formed.to_actor()
	target_run.graph.place_actor(actor, room_id)
	target_run.player = actor


## 지금 탈출구에 서 있는가. 결과를 자동으로 정할 때 쓴다.
func is_at_exit() -> bool:
	if run == null:
		return false
	var room := run.player_room()
	return room != null and room.kind == Room.Kind.EXIT


# ---------------------------------------------------------------- 결과와 정산


## 원정을 끝내고 보고서를 만든다.
##
## 턴 수를 던전에서 읽어 오는 것은 여기까지다. 이후 정산은 보고서만 본다
## (GuildSettlement).
func finish(outcome: ExpeditionReport.Outcome) -> ExpeditionReport:
	if stage != Stage.DEPLOYED:
		return null
	var turns: int = run.turn if run != null else 0
	report = ExpeditionReport.new(id, gate, outcome, turns, _deployed_ids, garrison_ids())
	stage = Stage.RETURNED
	return report


## 아지트에 반영한다. 두 번 불러도 두 번 적용되지 않는다 (Guild.mark_settled).
func settle() -> SettlementResult:
	if stage != Stage.RETURNED or report == null:
		return null
	result = GuildSettlement.apply(_guild, report, _prospect_seed())
	stage = Stage.SETTLED
	return result


## 영입 후보를 뽑는 씨앗.
##
## 게이트 씨앗과 턴 수에서 파생시켜 **같은 원정이면 같은 후보**가 나오게 한다.
## 무작위를 시각이나 전역 상태에서 끌어오면 판을 다시 볼 수 없다
## (docs/design/17-dungeon-generation.md §17.7 과 같은 이유).
func _prospect_seed() -> int:
	var turns: int = report.turns if report != null else 0
	return absi(gate.dungeon_seed + turns * 31 + _guild.expeditions_settled * 7919)
