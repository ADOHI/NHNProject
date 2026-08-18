class_name HideoutCrowd
extends RefCounted
## 아지트를 돌아다니는 대원들. **① 배회의 전부다.**
##
## ## 여기만 시간을 안다 (★5 의 조건)
##
## `src/core/hideout/` 의 나머지(격자 · 건물 · 배치)는 `delta` 를 모르고 앞으로도 모른다.
## **흐르는 것을 아는 것은 이 파일 하나뿐이다** (docs/design/30-hideout.md §30.3.4).
##
## 사용자 답이 「시간은 나중에 정한다, 지금 배회는 연출」이었고 **조건이 붙었다** —
## 나중에 시계가 붙어도 배회 쪽만 고치면 되어야 한다. 그래서 시계를 여기 가뒀다.
## 시계가 생기면 바뀌는 것은 `_pick_goal` 하나다 — 지금은 아무 빈 칸이나 고르고,
## 시계가 생기면 근무 시간표를 본다. **고르는 자리가 한 곳이면 갈아 끼우는 것도 한 곳이다.**
##
## ## 아래층을 아직 안 쓴다 — 경계 1번만으로 선다
##
## §30.3.1 이 정한 경계 셋 중 **`can_stand` 하나만** 쓴다. 흐름장(`direction_at`)과
## 여유 거리(`free_run`)는 안 부른다.
##
## 거점에는 **뚫어야 할 좁은 목이 없기 때문**이다. §30.3.2 의 배회 계약 3번이
## 「막히면 그 자리에 선다. 뚫으려 하지 않는다」이고, 그러면 길찾기가 필요 없다 —
## **막히면 목적지를 다시 고르면 된다.** 그것이 위층의 일이고 이 파일이 위층이다.
##
## 좁은 목이 생기거나(건물이 판을 막거나) 인원이 크게 늘면 그때 `direction_at` 을 붙인다.
## **그 전에 붙이면 안 쓰는 기계를 이고 다니는 것이다** (§30.3 표).

## 배회의 상태. §30.3.2 의 계약이 그대로 상태 기계다.
enum State {
	STANDING,  ## 서 있다. 남이 밀어도 안 움직인다
	WALKING,  ## 제가 고른 곳으로 간다
}

## 「칸이 없다」를 뜻하는 값. 칸 좌표는 늘 0 이상이라 겹치지 않는다.
##
## null 을 돌려주면 **반환형을 적을 수 없고**, 그러면 부르는 쪽의 타입 추론이 통째로 깨진다.
## 실제로 그렇게 짰다가 이 파일이 파스에 실패했고, class_name 이 등록되지 않아
## 화면 스크립트까지 줄줄이 안 붙었다. 파수병 값이 그것보다 싸다.
const NO_CELL := Vector2i(-1, -1)

## 대원이 걷는 빠르기(칸/초).
##
## **잠정이다.** 사람 걸음(초속 1.4 m)에 칸을 2 m 로 보면 0.7 칸/초인데,
## 그 값은 화면에서 너무 느려 배회로 안 읽혔다. 연출이므로 눈에 맞춘다.
const WALK_CELLS_PER_SECOND := 1.6

## 도착한 뒤 다음 목적지를 고르기까지 서 있는 시간(초). 이 사이에서 무작위로 고른다.
##
## 0 으로 두면 전원이 쉬지 않고 움직여 **개미집처럼 보인다.** 멈춰 서 있는 시간이
## 있어야 「사람이 지낸다」로 읽힌다.
const PAUSE_SECONDS := Vector2(0.8, 3.2)

## 목적지를 여기까지 고르다 못 찾으면 이번에는 포기하고 선다.
##
## 판이 건물로 가득 차면 빈 칸이 없을 수 있다. 무한히 고르면 그 프레임이 통째로 멎는다.
const _GOAL_TRIES := 12

## 서로 이만큼(칸)보다 가까운 곳은 목적지로 안 고른다.
##
## **밀치기를 안 만든 대신이다.** 겹침을 힘으로 푸는 대신 **목적지를 안 겹치게** 골라
## 애초에 안 겹치게 한다. 이 판에서는 이것으로 충분하다 — 인원이 열몇이고
## 빈 칸이 백 개가 넘는다.
const _GOAL_CLEARANCE := 1.4

var _grid: HideoutGrid
var _rng := RandomNumberGenerator.new()

## 대원 한 명당 한 칸씩. 각 칸은 Dictionary — id · 자리 · 목적지 · 상태 · 남은 대기.
var _people: Array[Dictionary] = []


func _init(grid: HideoutGrid, seed_value: int = 0) -> void:
	_grid = grid
	_rng.seed = seed_value


## 대원을 판에 세운다. 설 자리가 없으면 세우지 않고 false 를 돌려준다.
func spawn(member_id: String, at: Vector2i) -> bool:
	if not _grid.is_walkable(at):
		return false
	var person := {
		"id": member_id,
		"at": Vector2(at),
		"goal": Vector2(at),
		"state": State.STANDING,
		"wait": _rng.randf_range(PAUSE_SECONDS.x, PAUSE_SECONDS.y),
		"facing": Vector2.DOWN,
	}
	_people.append(person)
	return true


## 빈 칸에 알아서 세운다. 화면이 자리를 고르지 않게 한다.
func spawn_scattered(member_ids: Array[String]) -> int:
	var placed := 0
	for member_id in member_ids:
		var cell := _free_cell()
		if cell == NO_CELL:
			break
		if spawn(member_id, cell):
			placed += 1
	return placed


func count() -> int:
	return _people.size()


## 대원 한 명의 지금 상태. 화면과 테스트가 같은 문으로 읽는다.
func person(index: int) -> Dictionary:
	return _people[index]


func people() -> Array[Dictionary]:
	return _people


## **시간이 흐른다.** 이 파일에서만 부르는 말이다.
func tick(delta: float) -> void:
	for person in _people:
		if person["state"] == State.WALKING:
			_walk(person, delta)
		else:
			_stand(person, delta)


## 서 있다가 시간이 되면 갈 곳을 고른다. **다시 움직이는 이유는 자기 결정뿐이다** (계약 2).
func _stand(person: Dictionary, delta: float) -> void:
	person["wait"] -= delta
	if person["wait"] > 0.0:
		return
	var goal := _pick_goal(person)
	if goal == NO_CELL:
		person["wait"] = _rng.randf_range(PAUSE_SECONDS.x, PAUSE_SECONDS.y)
		return
	person["goal"] = Vector2(goal)
	person["state"] = State.WALKING


## 곧장 간다. 길을 찾지 않는다 — 거점에는 돌아가야 할 벽이 없다.
##
## **다음에 디딜 칸이 막혔으면 그 자리에 선다** (계약 3). 뚫지도 돌아가지도 않는다.
func _walk(person: Dictionary, delta: float) -> void:
	var here: Vector2 = person["at"]
	var goal: Vector2 = person["goal"]
	var to_goal := goal - here
	var step := WALK_CELLS_PER_SECOND * delta
	if to_goal.length() <= step:
		person["at"] = goal
		_settle(person)
		return
	var direction := to_goal.normalized()
	person["facing"] = direction
	var next := here + direction * step
	if not _grid.is_walkable(Vector2i(next.round())):
		_settle(person)
		return
	person["at"] = next


func _settle(person: Dictionary) -> void:
	person["state"] = State.STANDING
	person["wait"] = _rng.randf_range(PAUSE_SECONDS.x, PAUSE_SECONDS.y)


## 갈 만한 빈 칸 하나. 남이 가 있거나 가려는 곳 가까이는 안 고른다.
func _pick_goal(person: Dictionary) -> Vector2i:
	for _try in _GOAL_TRIES:
		var cell := _free_cell()
		if cell == NO_CELL:
			return NO_CELL
		if _is_crowded(cell, person):
			continue
		return cell
	return NO_CELL


func _free_cell() -> Vector2i:
	for _try in _GOAL_TRIES:
		var cell := Vector2i(
			_rng.randi_range(0, _grid.cols - 1), _rng.randi_range(0, _grid.rows - 1)
		)
		if _grid.is_walkable(cell):
			return cell
	return NO_CELL


func _is_crowded(cell: Vector2i, mover: Dictionary) -> bool:
	for other in _people:
		if other == mover:
			continue
		var claim: Vector2 = other["goal"] if other["state"] == State.WALKING else other["at"]
		if claim.distance_to(Vector2(cell)) < _GOAL_CLEARANCE:
			return true
	return false


## 이 칸 위에 서 있는 대원의 번호. 없으면 -1 이다. ⑤(클릭 -> 말풍선)가 쓸 문이다.
func person_at(cell: Vector2i) -> int:
	for index in _people.size():
		if Vector2i(Vector2(_people[index]["at"]).round()) == cell:
			return index
	return -1
