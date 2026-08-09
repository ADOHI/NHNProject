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

## 시설 셋을 놓아 보는 자리. **잠정이다** — §30.9 ★3(건물 종류)이 정해지면 갈린다.
## 발자국 2x2 는 이름 한 줄이 지붕에 들어가는 최소 크기다.
const _STARTING_LAYOUT: Array[Dictionary] = [
	{"kind": Facility.Kind.WORKSHOP, "size": Vector2i(2, 2), "at": Vector2i(3, 3)},
	{"kind": Facility.Kind.INTEL_ROOM, "size": Vector2i(2, 3), "at": Vector2i(12, 4)},
	{"kind": Facility.Kind.CONTACT_POINT, "size": Vector2i(3, 2), "at": Vector2i(6, 13)},
]

var _grid: HideoutGrid
var _iso: IsoProjection
var _panning := false

@onready var _camera: Camera2D = %Camera
@onready var _floor_view: HideoutFloorView = %FloorView
@onready var _building_view: HideoutBuildingView = %BuildingView
@onready var _cursor_view: HideoutCursorView = %CursorView
@onready var _status_label: Label = %StatusLabel
@onready var _help_label: Label = %HelpLabel


func _ready() -> void:
	_iso = IsoProjection.new()
	_grid = HideoutGrid.new()
	_place_starting_layout()
	_floor_view.bind(_grid, _iso)
	_building_view.bind(_grid, _iso)
	_cursor_view.bind(_iso)
	_frame_board()
	_help_label.text = _help_text()
	_refresh_status()


func _process(delta: float) -> void:
	_pan_with_keys(delta)
	_track_mouse()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _panning:
		_camera.position -= (event as InputEventMouseMotion).relative / _camera.zoom


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
	var index := 0
	for entry in _STARTING_LAYOUT:
		var building := HideoutBuilding.new(
			"facility_%d" % index, int(entry["kind"]), entry["size"], entry["at"]
		)
		if not _grid.place(building):
			push_warning("아지트: 잠정 배치 %s 를 놓지 못했다" % building.label())
		index += 1


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


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_MIDDLE:
		_panning = event.pressed
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_apply_zoom(_ZOOM_STEP)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_apply_zoom(1.0 / _ZOOM_STEP)


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
	return lines


func _help_text() -> String:
	var lines := PackedStringArray(
		[
			"④ 시점만 서 있다. 배회 · 끌어 넣기 · 배치 · 말풍선 · 메뉴는 아직 없다",
			"docs/design/30-hideout.md",
			"",
			"WASD · 방향키   화면 이동",
			"휠              확대 · 축소",
			"가운데 버튼 끌기  화면 끌기",
		]
	)
	return "\n".join(lines)
