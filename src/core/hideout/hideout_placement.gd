class_name HideoutPlacement
extends RefCounted
## 건물을 **놓는 중**인 상태. 새로 짓는 것과 이미 놓인 것을 옮기는 것 **둘 다** 여기 산다.
##
## ## 왜 노드가 아닌가
##
## 「지금 어디를 겨누고 있고 거기 놓을 수 있는가」는 그리기와 아무 상관이 없다.
## 화면에 두면 규칙을 눈으로만 확인하게 되고, 겹침 판정이 조용히 회귀한다
## (conventions.md §3.1).
##
## ## 짓기와 옮기기를 한 클래스에 둔 이유
##
## 둘은 **끝에서만 다르다.** 겨누기 · 유효성 · 미리보기 · 취소가 전부 같고,
## `commit()` 이 새로 놓느냐 옮기느냐만 갈린다. 나눠 두면 그 네 가지가 두 벌이 되고
## 한쪽만 고치는 일이 생긴다.
##
## ## 잡은 자리를 기억한다
##
## 겨누는 칸이 곧 발자국의 왼쪽 위가 되면, 2x3 건물을 옮길 때 건물이 커서 밑에서
## 한 칸 튄다. 잡을 때의 **어긋남**을 들고 있다가 계속 더해 준다.
## 새로 짓는 것은 잡은 적이 없으므로 **발자국 가운데**를 잡은 셈 친다.

enum Mode {
	NONE,  ## 아무것도 놓는 중이 아니다
	BUILD,  ## 새 건물을 짓는 중
	MOVE,  ## 이미 놓인 건물을 옮기는 중
}

var _grid: HideoutGrid
var _mode: Mode = Mode.NONE

## 짓는 중일 때의 시설 종류. 옮기는 중이면 옮기는 건물의 종류다.
var _facility_kind := HideoutBuilding.NOT_A_FACILITY
var _footprint := Vector2i.ONE

## 옮기는 중일 때 그 건물의 id. 짓는 중이면 비어 있다.
var _moving_id := ""

## 잡은 칸과 발자국 왼쪽 위 사이의 어긋남.
var _grab_offset := Vector2i.ZERO

## 지금 겨누는 칸. 아직 안 겨눴으면 _aimed 가 false 다.
var _aim := Vector2i.ZERO
var _aimed := false


func _init(grid: HideoutGrid) -> void:
	_grid = grid


func mode() -> Mode:
	return _mode


func is_active() -> bool:
	return _mode != Mode.NONE


## 새 건물을 짓기 시작한다. 발자국 가운데를 잡은 것으로 본다.
func begin_build(facility_kind: int) -> void:
	_mode = Mode.BUILD
	_facility_kind = facility_kind
	_footprint = HideoutBuilding.footprint_for(facility_kind)
	_moving_id = ""
	_grab_offset = -Vector2i(_footprint.x / 2, _footprint.y / 2)
	_aimed = false


## 이미 놓인 건물을 이 칸에서 집는다. 그 칸에 건물이 없으면 아무 일도 없다.
func begin_move(grabbed_cell: Vector2i) -> bool:
	var building := _grid.building_at(grabbed_cell)
	if building == null:
		return false
	_mode = Mode.MOVE
	_facility_kind = building.facility_kind
	_footprint = building.footprint
	_moving_id = building.id
	_grab_offset = building.origin - grabbed_cell
	_aim = grabbed_cell
	_aimed = true
	return true


## 이 칸을 겨눈다.
func aim_at(cell: Vector2i) -> void:
	_aim = cell
	_aimed = true


## 지금 겨누는 발자국의 왼쪽 위.
func origin() -> Vector2i:
	return _aim + _grab_offset


func footprint() -> Vector2i:
	return _footprint


func facility_kind() -> int:
	return _facility_kind


func is_aimed() -> bool:
	return _aimed


## 지금 자리에 놓을 수 있는가.
func can_commit() -> bool:
	return is_active() and _aimed and reason().is_empty()


## 못 놓는 이유. 놓을 수 있으면 빈 문자열이다.
##
## 옮기는 중에는 **자기 자신과의 겹침을 빼고** 본다 — 한 칸만 옮기려는데
## 제 몸이 걸려서 못 놓는 것은 규칙이 아니라 버그다.
func reason() -> String:
	if not is_active() or not _aimed:
		return ""
	return _grid.blocked_reason(_footprint, origin(), _moving_id)


## 지금 자리에 확정한다. 못 놓는 자리면 **아무것도 바꾸지 않고** 빈 문자열을 돌려준다.
##
## 놓인 건물의 id 를 돌려주는 이유는, 부른 쪽이 방금 놓은 것을 이어서 다룰 수 있어야 하기
## 때문이다(선택 · 되돌리기). 실패와 성공이 같은 타입이라 부른 쪽이 분기를 잊기 어렵다.
func commit() -> String:
	if not can_commit():
		return ""
	var placed_id := _moving_id
	if _mode == Mode.MOVE:
		if not _grid.move(_moving_id, origin()):
			return ""
	else:
		placed_id = _grid.unique_id("building")
		var building := HideoutBuilding.new(placed_id, _facility_kind, _footprint, origin())
		if not _grid.place(building):
			return ""
	_reset()
	return placed_id


## 그만둔다. 옮기는 중이었으면 **원래 자리에 그대로 있다** (애초에 안 건드렸다).
func cancel() -> void:
	_reset()


func _reset() -> void:
	_mode = Mode.NONE
	_moving_id = ""
	_aimed = false
	_facility_kind = HideoutBuilding.NOT_A_FACILITY
	_footprint = Vector2i.ONE
	_grab_offset = Vector2i.ZERO
