class_name WalkRecord
extends RefCounted
## 이 판을 어떻게 걸었나. **판정이 아니라 기록이다.**
##
## docs/design/17-dungeon-generation.md §17.28.1 이 못 박은 것을 여기서 한 번 더 적는다.
##
##   되돌아섬이 0 이면 좋은 판이 아니고 5 면 나쁜 판이 아니다.
##   이것은 사람이 걸은 뒤에 **자기가 어떻게 걸었는지 되짚을 근거**이지,
##   느낌을 대신하는 값이 아니다.
##
## **생성기를 이 숫자에 맞춰 고치지 마라.** 고칠 근거는 사람이 말한 것이지
## 계수기가 말한 것이 아니다. §17.26 이 이미 적었다 — 수치가 사람이 느끼는 것을
## 대리하지 못하면, 틀린 것은 판이 아니라 수치다.
##
## ## 세는 넷
##
## | 값 | 정의 | §17.26.1 의 물음 |
## | --- | --- | --- |
## | 걸음 | 성사된 이동의 수 | (분모) |
## | 본 방 | 들어가 본 서로 다른 방 (시작 방 포함) | 지루한가 |
## | 되돌아섬 | **방금 있던 방**으로 되돌아간 이동 | 되돌아 나오게 되는가 |
## | 왕복 통로 | 양방향으로 다 걸어 본 서로 다른 통로 | 길을 잃는가 |
##
## **뒤의 둘은 다른 것을 센다.** 앞은 사건이고 뒤는 통로다. 어느 쪽으로도 벌어진다 —
## `a>b>a>b` 는 되돌아섬 2 에 왕복 통로 1 이고, 고리를 한 바퀴 돌아 들어온 길로
## 나오면 되돌아섬 0 에 왕복 통로 1 이다.

## 들어가 본 방들. 값은 쓰지 않는다 — 집합이 필요한데 GDScript 에 집합이 없다.
var _seen: Dictionary = {}

## 걸어 본 통로의 방향. "a>b" -> true.
##
## 방향을 지워 버리면 왕복을 셀 수 없다. 통로 하나를 한 번 지난 것과
## 양쪽으로 지난 것은 **다른 사건**이다.
var _walked: Dictionary = {}

var _steps := 0
var _backtracks := 0
var _retraced := 0

## 직전 이동의 출발 방. 되돌아섬은 이것과 비교해서 나온다.
##
## "직전에 있던 방"이지 "직전에 들어간 방"이 아니다. 지금 서 있는 방은
## 판이 알고 있으므로 여기서 들고 있을 이유가 없다.
var _previous := ""


## 시작 방을 놓는다. 판이 만들어질 때 한 번 부른다.
##
## 빈 문자열이면 아무것도 하지 않는다 — 아직 아무 데도 놓이지 않은 판이다.
## 그때는 첫 이동의 출발 방이 시작 방 노릇을 한다.
func begin_at(start_id: String) -> void:
	_seen.clear()
	_walked.clear()
	_steps = 0
	_backtracks = 0
	_retraced = 0
	_previous = ""
	if not start_id.is_empty():
		_seen[start_id] = true


## 이동 하나를 기록한다. **성사된 이동만 넘긴다.**
##
## 막힌 이동까지 세면 "되돌아섬"이 손가락 실수와 섞인다.
func note_move(from_id: String, to_id: String) -> void:
	if from_id.is_empty() or to_id.is_empty() or from_id == to_id:
		return
	_steps += 1
	# 시작 방을 못 받았을 수도 있다. 출발 방도 본 방에 넣어 두면 그 구멍이 메워진다.
	_seen[from_id] = true
	_seen[to_id] = true

	if to_id == _previous:
		_backtracks += 1
	_previous = from_id

	var forward := "%s>%s" % [from_id, to_id]
	var backward := "%s>%s" % [to_id, from_id]
	# 반대 방향을 이미 걸었고 이 방향은 처음일 때만 **새로** 왕복이 된다.
	if _walked.has(backward) and not _walked.has(forward):
		_retraced += 1
	_walked[forward] = true


## 한 걸음이라도 걸었는가. 화면이 "아직 안 걸었다"를 다르게 적기 위해 쓴다.
func has_walked() -> bool:
	return _steps > 0


func steps() -> int:
	return _steps


func seen_room_count() -> int:
	return _seen.size()


func backtracks() -> int:
	return _backtracks


func retraced_corridors() -> int:
	return _retraced
