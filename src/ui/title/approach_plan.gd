class_name ApproachPlan
extends RefCounted
## **누가 언제 한 걸음 옮기는가.** 다가오는 순서를 정하는 순수 로직.
##
## 이 게임은 턴제다(docs/design/02-overview.md §2.2). 그래서 타이틀 화면의
## 중경도 턴제여야 한다 — 여럿이 동시에 움직이면 그것은 돌격이고,
## 우리가 보여야 하는 것은 **재고 있는 정지된 긴장**이다
## (docs/design/21-title.md §21.3.1).
##
## 지키는 것 둘.
##
##   1. **한 번에 하나만** 움직인다
##   2. 아무도 잊히지 않는다 — 한 바퀴 안에 전부 한 번씩 움직인다
##
## 두 번째가 없으면 난수가 한 명을 계속 고르고 나머지는 굳어 버린다.
## 실제로 그렇게 만들면 "멈춰 있는 사람들" 이 아니라 "고장 난 화면" 으로 보인다.
##
## 노드 트리를 모르므로 씬 없이 단위 테스트된다 (test/unit/test_approach_plan.gd).

## 걸음과 걸음 사이. **걸음보다 멈춰 있는 시간이 훨씬 길어야** 재는 것으로 보인다.
const _GAP_MIN := 0.75
const _GAP_MAX := 2.30

var _count := 0
var _bag: Array[int] = []
var _last := -1
var _rng := RandomNumberGenerator.new()


func _init(count: int, seed_value: int = 0) -> void:
	_count = maxi(count, 0)
	_rng.seed = seed_value


## 다음에 움직일 사람. 아무도 없으면 -1.
##
## 남은 사람 중에서 고르고, 다 돌면 다시 채운다. 새 바퀴의 첫 사람이
## 지난 바퀴의 마지막 사람과 같으면 연달아 두 번 움직이게 되므로 그것만 피한다.
func next() -> int:
	if _count <= 0:
		return -1
	if _bag.is_empty():
		_refill()
	var pick := _rng.randi_range(0, _bag.size() - 1)
	if _count > 1 and _bag[pick] == _last and _bag.size() > 1:
		pick = (pick + 1) % _bag.size()
	_last = _bag[pick]
	_bag.remove_at(pick)
	return _last


## 다음 걸음까지 기다리는 시간(초). 일정하면 메트로놈이 된다.
func wait() -> float:
	return _rng.randf_range(_GAP_MIN, _GAP_MAX)


## 이번 바퀴에서 아직 안 움직인 사람 수.
func remaining() -> int:
	return _bag.size()


func _refill() -> void:
	_bag.clear()
	for index in _count:
		_bag.append(index)
