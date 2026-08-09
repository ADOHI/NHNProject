class_name HideoutGrid
extends RefCounted
## 아지트 바닥. 몇 칸인가 · 무엇이 어디를 차지했는가 · 여기에 놓을 수 있는가.
##
## **아이소를 모른다.** 마름모로 접는 것은 IsoProjection 의 일이고, 여기는 정수 칸만 본다
## (docs/design/30-hideout.md §30.2). 시점을 쿼터뷰로 바꾸든 위에서 보든 이 파일은 그대로다.
##
## ## 왜 점유표를 칸 -> 건물 로 드는가
##
## 건물 목록만 들고 매번 훑어도 답은 같다. 그러나 겹침 검사는 건물을 놓을 때마다,
## 배회는 **사람마다 매 프레임** 통행을 묻는다. 칸 하나를 묻는 것이 O(건물 수)면
## 그 비용이 사람 수 × 건물 수로 붙는다. 웹 단일 스레드라 이런 것이 그대로 예산을 먹는다
## (docs/design/01-constraints.md §1.1).
##
## ## 실패하면 아무것도 바꾸지 않는다
##
## place 는 먼저 전부 검사하고 그 다음에 쓴다. 절반만 놓인 상태를 만들면
## 그것을 되돌리는 코드가 필요해지고, 되돌리기는 조용히 틀린다.

## 판 크기. **임시로 이렇게 뒀다** — §30.9 ★2.
##
## 20x20 으로 세웠다가 **창에 띄워 보고 줄였다.** 판 전체가 화면에 들어오게 맞추면
## 20x20 은 칸이 57px 로 뭉개지고 건물 셋이 사백 칸에 흩어져 텅 빈 벌판으로 읽혔다
## (건물이 판의 4%). 14x14 면 같은 화면에서 칸이 82px 이라 **줌 없이 칸이 읽힌다.**
##
## 마름모의 가로세로 비는 칸 수와 **무관하다** — 항상 3:1 이다(타일 비가 정한다).
## 그래서 판 모양을 바꿔서 화면을 채울 방법은 없고, 손잡이는 **칸 수 하나뿐**이다.
## 아지트는 사람이 돌아다니는 것을 지켜보는 화면이므로 **줌 없이 다 보이는 쪽**을 골랐다.
const DEFAULT_COLS := 14
const DEFAULT_ROWS := 14

## 가로 칸 수.
var cols: int

## 세로 칸 수.
var rows: int

## Vector2i -> 건물 id.
var _occupants: Dictionary = {}

## 건물 id -> HideoutBuilding. 놓인 순서를 유지한다.
var _buildings: Dictionary = {}


func _init(wide: int = DEFAULT_COLS, tall: int = DEFAULT_ROWS) -> void:
	cols = maxi(1, wide)
	rows = maxi(1, tall)


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cols and cell.y < rows


## 이 칸을 차지한 건물의 id. 비어 있으면 빈 문자열이다.
func occupant_at(cell: Vector2i) -> String:
	return String(_occupants.get(cell, ""))


func building_at(cell: Vector2i) -> HideoutBuilding:
	var building_id := occupant_at(cell)
	if building_id.is_empty():
		return null
	return _buildings.get(building_id)


## 판 안이면서 비어 있는가.
func is_free(cell: Vector2i) -> bool:
	return in_bounds(cell) and not _occupants.has(cell)


## 사람이 지나갈 수 있는가. 지금은 "비어 있는가" 와 같다.
##
## 같은 뜻이어도 이름을 나눠 둔다. 나중에 통행만 막는 것(울타리 · 화단)이나
## 건물 위를 지나가는 것(다리)이 생기면 갈라질 자리가 여기이고,
## 그때 부르는 쪽을 전부 뒤지지 않아도 된다.
func is_walkable(cell: Vector2i) -> bool:
	return is_free(cell)


## 이 발자국을 이 자리에 놓을 수 있는가.
func can_place(footprint: Vector2i, origin: Vector2i, ignore_id: String = "") -> bool:
	return blocked_reason(footprint, origin, ignore_id).is_empty()


## 놓을 수 없는 이유. 놓을 수 있으면 빈 문자열이다.
##
## 참/거짓만 돌려주면 화면이 "왜 안 놓이는가" 를 스스로 지어내게 된다.
## §22.8.5 가 이미 같은 문제를 만났다 — **잠긴 이유가 둘인데 둘 다 흐리면 구분이 안 된다.**
## 문장은 코어가 만들고 화면은 받아 적는다 (conventions.md §3.1).
func blocked_reason(footprint: Vector2i, origin: Vector2i, ignore_id: String = "") -> String:
	var span := Vector2i(maxi(1, footprint.x), maxi(1, footprint.y))
	for offset_y in span.y:
		for offset_x in span.x:
			var cell := origin + Vector2i(offset_x, offset_y)
			if not in_bounds(cell):
				return "판 밖이다"
			var holder := occupant_at(cell)
			if not holder.is_empty() and holder != ignore_id:
				var blocker: HideoutBuilding = _buildings[holder]
				return "%s 와 겹친다" % blocker.label()
	return ""


## 건물을 놓는다. 놓을 수 없으면 **아무것도 바꾸지 않고** false 를 돌려준다.
##
## 같은 id 로 다시 부르면 옮기는 것으로 본다 — 옮기려고 먼저 지울 필요가 없다.
## FacilityAssignment.assign 이 같은 규칙을 쓴다.
func place(building: HideoutBuilding) -> bool:
	if building == null or building.id.is_empty():
		return false
	if not can_place(building.footprint, building.origin, building.id):
		return false
	if _buildings.has(building.id):
		_clear_cells(building.id)
	for cell in building.cells():
		_occupants[cell] = building.id
	_buildings[building.id] = building
	return true


## 놓인 건물을 다른 자리로 옮긴다. 옮길 수 없으면 원래 자리에 그대로 있다.
func move(building_id: String, to: Vector2i) -> bool:
	var building: HideoutBuilding = _buildings.get(building_id)
	if building == null:
		return false
	var was := building.origin
	building.origin = to
	if place(building):
		return true
	building.origin = was
	return false


func remove(building_id: String) -> bool:
	if not _buildings.has(building_id):
		return false
	_clear_cells(building_id)
	_buildings.erase(building_id)
	return true


func has_building(building_id: String) -> bool:
	return _buildings.has(building_id)


func building(building_id: String) -> HideoutBuilding:
	return _buildings.get(building_id)


## 놓인 건물 전부. 놓은 순서다.
func buildings() -> Array[HideoutBuilding]:
	var placed: Array[HideoutBuilding] = []
	for building_id in _buildings:
		placed.append(_buildings[building_id])
	return placed


## 그리는 차례대로 정렬한 건물 목록. 뒤에 있는 것이 먼저 나온다.
##
## 화면이 정렬을 맡으면 그 규칙을 테스트가 못 지킨다 (IsoProjection.depth_of 참고).
func buildings_by_depth() -> Array[HideoutBuilding]:
	var placed := buildings()
	placed.sort_custom(
		func(a: HideoutBuilding, b: HideoutBuilding) -> bool:
			if a.depth() == b.depth():
				return a.id < b.id
			return a.depth() < b.depth()
	)
	return placed


## 비어 있는 칸 수. 배회할 자리가 남았는지를 판단할 때 쓴다(§30.3).
func free_cell_count() -> int:
	return cols * rows - _occupants.size()


func _clear_cells(building_id: String) -> void:
	for cell in _occupants.keys():
		if String(_occupants[cell]) == building_id:
			_occupants.erase(cell)
