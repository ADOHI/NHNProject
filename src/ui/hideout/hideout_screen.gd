class_name HideoutScreen
extends Node2D
## 아지트 화면 — 아이소 격자와 그 위의 건물. **여섯 덩어리 중 ④(시점)만 서 있다.**
##
## docs/design/30-hideout.md 가 이 화면이 무엇이고 무엇이 아직 없는지를 적는다.
##
## ## main.tscn 에 연결하지 않는다
##
## 독립 씬으로 돌린다. src/ui/base/ 와 같은 규칙이다(§22.8) — 다른 레인이 인게임 화면과
## UI 조형을 동시에 만지고 있고, 미완인 화면을 진입점에 붙이면 남의 검증까지 같이 흔든다.
##
##     godot --path . res://src/ui/hideout/hideout_screen.tscn
##
## ## 이 노드가 하는 일은 셋뿐이다
##
## 코어(HideoutGrid)를 들고 · 입력을 칸으로 바꿔 넘기고 · 그리는 층들에게 다시 그리라고 한다.
## 판단은 전부 코어에 있다 (conventions.md §3.1).

## 카메라 조작 잠정값. 손맛을 재는 화면이 아니라 시점이 서는지를 보는 화면이라
## ProtoMoveTuning 같은 조절판을 두지 않았다.
const _PAN_SPEED := 700.0
const _ZOOM_STEP := 1.12
const _ZOOM_MIN := 0.35
const _ZOOM_MAX := 2.5

## 시설 셋이 처음 놓여 있는 자리. **잠정이다** — §30.9 ★3(건물 종류)이 정해지면 갈린다.
##
## 발자국은 여기 안 적는다. HideoutBuilding.footprint_for 가 유일한 출처다 —
## 두 곳에 적으면 미리보기와 실제 건물이 다른 크기가 된다.
const _STARTING_LAYOUT: Array[Dictionary] = [
	{"kind": Facility.Kind.WORKSHOP, "at": Vector2i(2, 2)},
	{"kind": Facility.Kind.INTEL_ROOM, "at": Vector2i(9, 3)},
	{"kind": Facility.Kind.CONTACT_POINT, "at": Vector2i(4, 9)},
]

## 숫자키로 고르는 시설 순서. Facility.all() 순서를 그대로 쓴다.
const _BUILD_KEYS := [KEY_1, KEY_2, KEY_3]

var _grid: HideoutGrid
var _iso: IsoProjection
var _plan: HideoutPlacement
var _panning := false

## 마지막으로 알려 줄 말 한 줄 (놓았다 · 못 놓는다 · 옮겼다).
var _notice := ""

@onready var _camera: Camera2D = %Camera
@onready var _floor_view: HideoutFloorView = %FloorView
@onready var _building_view: HideoutBuildingView = %BuildingView
@onready var _cursor_view: HideoutCursorView = %CursorView
@onready var _ghost_view: HideoutGhostView = %GhostView
@onready var _status_label: Label = %StatusLabel
@onready var _help_label: Label = %HelpLabel


func _ready() -> void:
	_iso = IsoProjection.new()
	_grid = HideoutGrid.new()
	_plan = HideoutPlacement.new(_grid)
	_place_starting_layout()
	_floor_view.bind(_grid, _iso)
	_building_view.bind(_grid, _iso)
	_cursor_view.bind(_iso)
	_ghost_view.bind(_iso, _plan)
	_frame_board()
	_help_label.text = _help_text()
	_refresh_status()


func _process(delta: float) -> void:
	_pan_with_keys(delta)
	_track_mouse()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventKey and (event as InputEventKey).pressed:
		_handle_key(event)
	elif event is InputEventMouseMotion and _panning:
		_camera.position -= (event as InputEventMouseMotion).relative / _camera.zoom


## 놓는 중인 상태. 배선 테스트가 같은 문으로 들어온다.
func placement() -> HideoutPlacement:
	return _plan


## 짓기를 시작한다 — 숫자키와 테스트가 같은 문으로 들어온다.
func begin_build(facility_kind: int) -> void:
	_plan.begin_build(facility_kind)
	_plan.aim_at(_cursor_view.cell())
	_notice = "%s 를 놓을 자리를 고른다" % Facility.label(facility_kind)
	refresh_views()


## 지금 가리키는 칸에서 건물을 집는다. 건물이 없으면 아무 일도 없다.
func grab_here() -> bool:
	if not _plan.begin_move(_cursor_view.cell()):
		return false
	_notice = "옮길 자리를 고른다"
	refresh_views()
	return true


## 놓는 중인 것을 지금 자리에 확정한다.
func commit_here() -> bool:
	var moved := _plan.mode() == HideoutPlacement.Mode.MOVE
	var placed_id := _plan.commit()
	if placed_id.is_empty():
		_notice = _plan.reason()
		refresh_views()
		return false
	var building := _grid.building(placed_id)
	_notice = "%s 를 %s" % [building.label(), "옮겼다" if moved else "놓았다"]
	refresh_views()
	return true


func cancel_placement() -> void:
	if not _plan.is_active():
		return
	_plan.cancel()
	_notice = "그만뒀다"
	refresh_views()


## 판이 바뀌었다. 그리는 층들에게 다시 그리라고 하고 글자를 새로 뽑는다.
##
## 판을 밖에서 고친 쪽(도구 · 테스트)도 이것을 불러 준다.
func refresh_views() -> void:
	_building_view.refresh()
	_floor_view.refresh()
	_ghost_view.refresh()
	_refresh_status()


## 이 화면이 들고 있는 판. 배선 테스트와 나중에 붙을 층(배회 · 배치)이 같은 것을 본다.
func grid() -> HideoutGrid:
	return _grid


func projection() -> IsoProjection:
	return _iso


## 이 화면 좌표를 가리킨다. 마우스와 테스트가 같은 문으로 들어온다 —
## 마우스만 통하는 길로 만들면 헤드리스에서 확인할 방법이 없어진다.
func point_at_world(world: Vector2) -> void:
	var cell := _iso.world_to_cell(world)
	var inside := _grid.in_bounds(cell)
	_cursor_view.point_at(cell, inside, inside and not _grid.is_free(cell))
	if _plan.is_active():
		_plan.aim_at(cell)
		_ghost_view.refresh()
	_refresh_status()


## 지금 가리키는 칸. 판 밖이면 두 번째 값이 false 다.
func pointed_cell() -> Vector2i:
	return _cursor_view.cell()


func is_pointing_inside() -> bool:
	return _cursor_view.has_cell()


func status_text() -> String:
	return _status_label.text


## 잠정 배치를 놓는다. 놓지 못한 것이 있으면 조용히 넘기지 않고 세어서 화면에 적는다 —
## LANE-RULES §1 "조용히 통과시키는 검사가 실패한 생성보다 위험하다".
func _place_starting_layout() -> void:
	for entry in _STARTING_LAYOUT:
		var kind := int(entry["kind"])
		var building := HideoutBuilding.new(
			_grid.unique_id("building"), kind, HideoutBuilding.footprint_for(kind), entry["at"]
		)
		if not _grid.place(building):
			push_warning("아지트: 잠정 배치 %s 를 놓지 못했다" % building.label())


func _frame_board() -> void:
	_camera.position = _iso.board_center(_grid.cols, _grid.rows)
	var board := _iso.board_size(_grid.cols, _grid.rows)
	var view := get_viewport_rect().size
	var fit := minf(view.x / maxf(1.0, board.x), view.y / maxf(1.0, board.y)) * 0.9
	var zoom := clampf(fit, _ZOOM_MIN, _ZOOM_MAX)
	_camera.zoom = Vector2(zoom, zoom)


func _pan_with_keys(delta: float) -> void:
	var move := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if move == Vector2.ZERO:
		return
	_camera.position += move.normalized() * _PAN_SPEED * delta / _camera.zoom.x


## 마우스 밑의 칸을 커서 층에 넘긴다. 판단(놓을 수 있는가)은 코어가 한다.
func _track_mouse() -> void:
	var world := get_global_mouse_position()
	if _iso.world_to_cell(world) == _cursor_view.cell() and _cursor_view.has_cell():
		return
	point_at_world(world)


func _handle_key(event: InputEventKey) -> void:
	var index := _BUILD_KEYS.find(event.keycode)
	if index >= 0 and index < Facility.count():
		begin_build(index)
	elif event.keycode == KEY_ESCAPE:
		cancel_placement()


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_left_click()
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		cancel_placement()
	elif event.button_index == MOUSE_BUTTON_MIDDLE:
		_panning = event.pressed
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_apply_zoom(_ZOOM_STEP)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_apply_zoom(1.0 / _ZOOM_STEP)


## 놓는 중이면 확정하고, 아니면 가리킨 건물을 집는다.
##
## 같은 버튼에 둘을 둔 이유는 **끌어 놓기가 한 손짓이기 때문**이다 —
## 집기와 놓기를 다른 버튼에 두면 옮기는 데 두 손이 든다.
func _handle_left_click() -> void:
	if _plan.is_active():
		commit_here()
	else:
		grab_here()


func _apply_zoom(factor: float) -> void:
	var zoom := clampf(_camera.zoom.x * factor, _ZOOM_MIN, _ZOOM_MAX)
	_camera.zoom = Vector2(zoom, zoom)


func _refresh_status() -> void:
	_status_label.text = "\n".join(_status_lines())


## 화면이 짓는 문자열은 칸 제목뿐이다. 건물 이름과 막힌 이유는 코어가 만든다 (§22.8.2).
func _status_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append(
		(
			"아지트  %d x %d 칸 · 건물 %d · 빈 칸 %d"
			% [_grid.cols, _grid.rows, _grid.buildings().size(), _grid.free_cell_count()]
		)
	)
	if not _cursor_view.has_cell():
		lines.append("가리키는 칸: 판 밖")
		return lines
	var cell := _cursor_view.cell()
	var building := _grid.building_at(cell)
	if building == null:
		lines.append("가리키는 칸: (%d, %d) · 빈 칸" % [cell.x, cell.y])
	else:
		lines.append(
			"가리키는 칸: (%d, %d) · %s — %s" % [cell.x, cell.y, building.label(), building.note()]
		)
	lines.append(_placement_line())
	return lines


## 놓는 중일 때 무엇을 어디에 놓으려는지와, 못 놓으면 그 이유.
##
## **이유 문장은 코어가 만든다** (HideoutGrid.blocked_reason). 화면이 지어내면
## 규칙과 설명이 따로 놀고, 규칙을 고쳐도 설명은 옛말을 계속 한다.
func _placement_line() -> String:
	if not _plan.is_active():
		return _notice
	var origin := _plan.origin()
	var footprint := _plan.footprint()
	var head := (
		"놓는 중: %s  %dx%d  (%d, %d)"
		% [
			Facility.label(_plan.facility_kind()),
			footprint.x,
			footprint.y,
			origin.x,
			origin.y,
		]
	)
	var reason := _plan.reason()
	return head if reason.is_empty() else "%s  —  %s" % [head, reason]


func _help_text() -> String:
	var lines := PackedStringArray(
		[
			"④ 시점 · ③ 배치가 선다. 배회 · 끌어 넣기 · 말풍선 · 메뉴는 아직 없다",
			"docs/design/30-hideout.md",
			"",
			"1 2 3           공방 · 정보실 · 접선처 짓기",
			"왼클릭          놓는 중이면 확정 · 아니면 건물 집기",
			"오른클릭 · ESC  그만두기",
			"WASD · 방향키   화면 이동",
			"휠              확대 · 축소",
			"가운데 버튼 끌기  화면 끌기",
		]
	)
	return "\n".join(lines)
