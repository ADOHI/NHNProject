class_name BackpackGrid
extends RefCounted
## 대원 한 명의 백팩. 칸 · 놓인 것들 · **시작 노드**를 들고 있다.
##
## `docs/design/28-combat.md` §28.2 · §28.10.1.
##
## ## 시작 노드는 목록이다
##
## §28.8 이 「시작 노드 개수 (하나 vs 여럿)」를 **미정**으로 뒀다. 그래서 개수를
## 하나로 못 박지 않고 목록으로 들고 있는다. 지금 샘플은 하나만 꽂아 두지만
## 여럿으로 정해져도 이 클래스도 해석기도 안 바뀐다 (§28.10.7).
##
## ## 격자는 체인을 모른다
##
## 여기는 「무엇이 어디에 있는가」만 안다. 순서를 푸는 것은 `ChainResolver` 다.
## 배치와 해석을 갈라 놓아야 §28.2.2 의 미정된 연결 조건을 나중에 갈아 끼울 수 있다.

var width: int
var height: int

## 이 칸을 덮고 있는 아이템이 공격의 시작 아이템이 된다.
var start_nodes: Array[Vector2i]

var _placements: Array[BackpackPlacement] = []

## Vector2i -> BackpackPlacement. 칸 조회를 배치 수와 무관하게 만든다.
var _occupancy: Dictionary = {}


func _init(p_width: int, p_height: int, p_start_nodes: Array[Vector2i]) -> void:
	assert(p_width > 0 and p_height > 0, "격자는 최소 1x1 이다")
	width = p_width
	height = p_height
	start_nodes = p_start_nodes.duplicate()
	for cell in start_nodes:
		assert(contains(cell), "시작 노드가 격자 밖이다: %s" % cell)


func contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func is_start_node(cell: Vector2i) -> bool:
	return start_nodes.has(cell)


## 그 칸을 덮고 있는 배치. 비어 있거나 격자 밖이면 `null`.
func placement_at(cell: Vector2i) -> BackpackPlacement:
	return _occupancy.get(cell)


func placements() -> Array[BackpackPlacement]:
	return _placements.duplicate()


func is_empty() -> bool:
	return _placements.is_empty()


## 격자 안에 들어가고 다른 아이템과 겹치지 않는가.
##
## `ignored` 는 겹침 검사에서 빼 둘 배치다. **자기 자신을 조금 옮길 때** 필요하다 —
## 빼 두지 않으면 옛 자리와 새 자리가 겹쳐서 항상 실패한다.
func can_place(item: BackpackItem, origin: Vector2i, ignored: BackpackPlacement = null) -> bool:
	for cell in item.cells_at(origin):
		if not contains(cell):
			return false
		var occupant: BackpackPlacement = _occupancy.get(cell)
		if occupant != null and occupant != ignored:
			return false
	return true


## 놓는다. 놓을 수 없으면 `null` 을 돌려주고 격자는 그대로다.
func place(item: BackpackItem, origin: Vector2i) -> BackpackPlacement:
	if not can_place(item, origin):
		return null
	var placement := BackpackPlacement.new(item, origin)
	_placements.append(placement)
	for cell in placement.cells():
		_occupancy[cell] = placement
	return placement


func remove(placement: BackpackPlacement) -> bool:
	var index := _placements.find(placement)
	if index < 0:
		return false
	_placements.remove_at(index)
	for cell in placement.cells():
		if _occupancy.get(cell) == placement:
			_occupancy.erase(cell)
	return true


## 이미 놓인 것을 다른 자리로 옮긴다. **실패하면 원래 자리 그대로 남는다.**
##
## 갈 수 있는지를 **먼저 전부** 확인하고 나서 자리를 옮긴다. 옮기다 실패하면
## 아이템이 반쯤 들린 채로 격자에서 사라지기 때문이다.
##
## 배치 객체의 정체성을 유지한다 — 화면이 끌고 있는 것과 같은 객체여야 한다.
func move(placement: BackpackPlacement, new_origin: Vector2i) -> bool:
	if not _placements.has(placement):
		return false
	if not can_place(placement.item, new_origin, placement):
		return false
	for cell in placement.cells():
		if _occupancy.get(cell) == placement:
			_occupancy.erase(cell)
	placement.origin = new_origin
	for cell in placement.cells():
		_occupancy[cell] = placement
	return true


func clear() -> void:
	_placements.clear()
	_occupancy.clear()
