class_name SquadBackpacks
extends RefCounted
## 스쿼드가 들고 들어간 백팩들. **대원마다 하나**이고, **탈출에 실패하면 전부 잃는다.**
##
## `docs/design/28-combat.md` §28.1-5 (백팩은 대원마다 하나) · §28.10 (전투는 어떻게 끝나나).
##
## ## 왜 여기가 「자리」인가
##
## 전투는 아직 없다. 그런데 §28.10 이 **실패의 대가**를 확정했으므로 그것이 얹힐
## 자리를 먼저 만든다 — 나중에 전투가 붙을 때 백팩이 어디 사는지부터 정하고 있으면
## 전투 코드가 저장 구조를 같이 발명하게 된다.
##
## ## 대원을 여기 담지 않는다
##
## 이 클래스는 **대원 id 만** 안다. 대원 기록은 `src/core/guild/` 가 갖고 있고
## 여기서 건드리지 않는다.
##
## 그것이 §28.10 의 *"대원은 잃지 않는다"* 를 구조로 보장한다 —
## **잃는 코드가 대원에 닿을 수조차 없다.** 몸은 복제된 것이라 죽어도 사라지지 않는다
## (`02-overview.md` §2.6.1.5).

## 대원 id -> BackpackGrid.
var _grids: Dictionary = {}

## 대원 id 를 넣은 순서. Dictionary 순서에 기대지 않고 정산 순서를 고정한다.
var _order: Array[String] = []


## 대원 하나에게 백팩을 준다. 이미 있으면 갈아 끼운다.
func assign(member_id: String, grid: BackpackGrid) -> void:
	assert(not member_id.is_empty(), "대원 id 가 비었다")
	if not _grids.has(member_id):
		_order.append(member_id)
	_grids[member_id] = grid


func has(member_id: String) -> bool:
	return _grids.has(member_id)


## 그 대원의 백팩. 없으면 `null`.
func for_member(member_id: String) -> BackpackGrid:
	return _grids.get(member_id)


## 백팩을 가진 대원들. 넣은 순서 그대로다.
func member_ids() -> Array[String]:
	return _order.duplicate()


func member_count() -> int:
	return _order.size()


## 지금 스쿼드가 들고 있는 물건 수. 칸 압박(§28.3)이 얼마나 찼는지의 눈금이다.
func total_items() -> int:
	var total := 0
	for member_id in _order:
		total += (_grids[member_id] as BackpackGrid).placements().size()
	return total


## 그 대원 백팩에 든 아이템들. 놓인 순서 그대로다.
func items_of(member_id: String) -> Array[BackpackItem]:
	var items: Array[BackpackItem] = []
	var grid: BackpackGrid = _grids.get(member_id)
	if grid == null:
		return items
	for placement in grid.placements():
		items.append(placement.item)
	return items


## **탈출 실패. 백팩을 통째로 잃는다** (§28.10 확정).
##
## 사용자 발언: *"백팩만 잃어버림. 일단은 전체 다 잃는 걸로 하자.
## 일부 복구나 되찾는 건 추후 구현이야."*
##
## ## 잃은 것을 버리지 않고 돌려준다
##
## 격자는 비우되 **무엇을 잃었는지는 돌려준다.** 두 가지가 이것을 필요로 한다 —
## 정산 화면이 "무엇을 잃었는가" 를 보여 줘야 하고, §28.10 이 **추후**로 미룬
## 「일부 복구 · 되찾기」가 붙을 자리가 여기이기 때문이다.
##
## 그냥 지워 버리면 그때 이 함수를 다시 설계해야 한다.
##
## **대원은 건드리지 않는다.** 이 클래스는 대원 id 밖에 모른다.
func lose_everything() -> Array[BackpackItem]:
	var lost: Array[BackpackItem] = []
	for member_id in _order:
		lost.append_array(items_of(member_id))
		(_grids[member_id] as BackpackGrid).clear()
	return lost


## 백팩이 전부 비었는가.
func is_empty() -> bool:
	return total_items() == 0
