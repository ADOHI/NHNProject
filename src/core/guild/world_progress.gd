class_name WorldProgress
extends RefCounted
## 씨앗 이후 세계가 **걸어온 길.** 세이브가 담는 「변경분」이 이것이다.
##
## docs/design/37-meta-loop.md §37.5, docs/design/34-systems.md §34.7.3 —
## *"봉투 버전을 2로 올리고 씨앗 이후의 변경분만 담아라."*
##
## ## 왜 이것이 없으면 안 되나
##
## 세이브는 씨앗만 담고(§34.4.1) 불러올 때 `NpcWorld.create(seed)` 로 **처녀 세계**를
## 다시 세운다. 그래서 껐다 켜면 지금까지 돈 틱이 **전부 없던 일**이 된다 —
## 오류는 안 나고 화면도 멀쩡하다. [36](36-settlement.md) §36.5.6 의
## *"원정 번호가 저장을 못 건넜다"* 와 같은 종류의 결함이다.
##
## ## 크기
##
## 한 틱이 정수 열 남짓이고 한 회차가 스무 판이다. **간선 만 개를 쓰는 것과 비교가 안 된다.**
##
## ## 순서가 전부다
##
## 세계 사건이 그다음 사건의 목격자 선택을 바꾸고, 내 원정이 남긴 것도 같은 그래프를
## 바꾼다. 그래서 **틱을 넣은 순서 그대로** 다시 건다.

## 걸어온 틱들. 앞이 오래된 것이다.
var steps: Array[WorldStep] = []


## 이 틱을 세계에 걸고 걸어온 길에 적는다. **정산이 지나는 문이 여기 하나다.**
func advance(world: NpcWorld, step: WorldStep) -> int:
	if world == null or step == null:
		return 0
	var shocked := step.apply_to(world)
	steps.append(step)
	return shocked


## 갓 선 세계에 걸어온 길을 다시 건다. 돌려주는 것은 다시 건 틱 수다.
##
## **씨앗에서 갓 세운 세계에만 건다.** 이미 돈 세계에 걸면 두 번 도는 것이 된다 —
## 부르는 곳은 `GameSave.restore` 한 곳이다.
func replay(world: NpcWorld) -> int:
	if world == null or not world.is_ready():
		return 0
	for step in steps:
		step.apply_to(world)
	return steps.size()


## 몇 틱 돌았나. 화면이 「세계가 몇 번 움직였나」를 말할 때 쓴다.
func tick_count() -> int:
	return steps.size()


## 지금까지 세계에 굴린 사건의 총수. 세계를 세울 때 굴린 것은 안 센다.
func events_rolled() -> int:
	var total := 0
	for step in steps:
		total += step.events
	return total


func is_empty() -> bool:
	return steps.is_empty()


# ---------------------------------------------------------------- 저장


func to_dict() -> Dictionary:
	var rows: Array = []
	for step in steps:
		rows.append(step.to_dict())
	return {"steps": rows}


## 사전에서 되돌린다. **없으면 빈 길이다** — 옛 세이브(봉투 v1)에는 이 칸이 없고,
## 그때는 세계가 처녀 상태로 서는 것이 맞다.
static func from_dict(data: Dictionary) -> WorldProgress:
	var progress := WorldProgress.new()
	for row in data.get("steps", []):
		if not (row is Dictionary):
			continue
		var step := WorldStep.from_dict(row as Dictionary)
		if step != null:
			progress.steps.append(step)
	return progress
