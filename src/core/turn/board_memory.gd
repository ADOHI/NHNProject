class_name BoardMemory
extends RefCounted
## 플레이어가 기억하는 것. **§13.7 이 「추리 성립 조건」이라고 부른 것이다.**
##
## docs/design/13-information-design.md §13.7 —
## *"변화량 추론이 성립하려면 플레이어가 이전 값을 기억할 수 있어야 한다.
## 매 턴 암산을 강요하면 재미가 아니라 노동이 된다."*
##
## §13.5 가 이 게임의 핵심 추론을 이렇게 적었다.
##
## > 숫자의 절대값은 위험을 알려 주고, **숫자의 변화량은 사람을 알려 준다.**
##
## 절대값은 판을 보면 나온다. **변화량은 기억이 있어야 나온다.**
## 기억이 없으면 §13.5 도 §13.7 도 성립하지 않고, 그러면 NPC 를 움직여 봐야
## 플레이어에게는 아무 정보도 아니다.
##
## ## 왜 화면이 아니라 여기 있나
##
## 지금 `DungeonBoard._last_threat` 이 화면에 있다. **화면이 기억하면 화면을 닫을 때
## 지워진다** — 교정쇄를 열었다 닫으면 증감 표시가 사라지고, 그러면
## "걸어 보고 견준다"가 성립하지 않는다. `WalkRecord` 를 판에 붙인 것과 같은 이유다.
##
## ## 기호 주의
##
## `▲ ▼` 는 테마 폰트에 **없다** (docs/conventions.md §5.1).
## 데스크톱에서는 OS 가 대신 그려 줘서 보이지 않고 웹에서만 두부가 된다.
## 그래서 글자로 쓴다 — `오름 2` · `내림 1`.

## 아직 본 적 없다는 표시. 위험도 합은 0 일 수 있으므로 0 을 쓸 수 없다.
const UNSEEN := -1

## 방 id -> 그 방에 서서 마지막으로 읽은 인접 위험도 합.
var _last_threat: Dictionary = {}

## 방 id -> 발을 들인 적이 있는가.
var _visited: Dictionary = {}

## 방문한 순서. 되짚어 보여 줄 때 쓴다.
var _order: Array[String] = []


## 그 방에 서서 이 숫자를 봤다. 매 턴 끝에 한 번 부른다.
func note(room_id: String, threat: int) -> void:
	if room_id.is_empty():
		return
	if not _visited.has(room_id):
		_visited[room_id] = true
		_order.append(room_id)
	_last_threat[room_id] = threat


func has_visited(room_id: String) -> bool:
	return _visited.has(room_id)


func visited_count() -> int:
	return _order.size()


## 방문한 방들, 처음 본 순서대로.
func visited_room_ids() -> Array[String]:
	return _order.duplicate()


## 그 방에서 마지막으로 본 숫자. 본 적이 없으면 `UNSEEN`.
func last_threat(room_id: String) -> int:
	return int(_last_threat.get(room_id, UNSEEN))


## 지금 숫자가 기억보다 얼마나 달라졌는가. 처음 보는 방이면 0 이다.
##
## **0 도 정보다** — §13.5: *"숫자가 그대로다 → 아무도 안 지나갔다.
## 혹은 들어온 만큼 나갔다."* 그래서 「모른다」와 「안 변했다」를 섞지 않으려고
## 처음 보는 방은 `has_visited()` 로 따로 물어야 한다.
func delta(room_id: String, threat: int) -> int:
	var before := last_threat(room_id)
	return 0 if before == UNSEEN else threat - before


## 화면에 그대로 띄우는 한 줄. 변화가 없거나 처음이면 빈 문자열이다.
func delta_text(room_id: String, threat: int) -> String:
	var change := delta(room_id, threat)
	if change == 0:
		return ""
	return "오름 %d" % change if change > 0 else "내림 %d" % absi(change)


func clear() -> void:
	_last_threat.clear()
	_visited.clear()
	_order.clear()
