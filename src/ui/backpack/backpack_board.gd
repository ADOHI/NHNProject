class_name BackpackBoard
extends Control
## 백팩 격자와 대기줄을 그리고 드래그를 받는다. **판정 수단이지 게임 화면이 아니다.**
##
## `docs/design/28-combat.md` §28.10.9.
##
## ## 꾸미지 않는다
##
## `src/ui/kit/` 을 쓰지 않는다. UI 킷 컨셉이 아직 도는 중이라 지금 붙이면 두 번 고친다.
## 여기 있는 것은 사각형 · 삼각형 · 선 · 한글뿐이다.
##
## ## 기호 글자를 한 개도 쓰지 않는다
##
## 본문 폰트(`SongMyung-Regular.ttf`)에 **기호 글리프가 하나도 없다.** 화살표도
## 네모도 동그라미도 가운뎃점도 없다. 데스크톱에서는 OS 가 대신 그려 주어 멀쩡해 보이고
## **웹 빌드에서만 전부 두부**가 된다 (`docs/conventions.md` §5.1).
##
## 그래서 방향 · 순서 · 연결 · 끊김을 전부 `_draw()` 의 도형으로 그린다.
## 화면에 나가는 글자는 한글과 ASCII 숫자뿐이다.

## 배치가 바뀌었다. 화면이 체인을 다시 풀어야 한다.
signal layout_changed

const GRID_ORIGIN := Vector2(40.0, 110.0)
const CELL := 72.0

const TRAY_ORIGIN := Vector2(560.0, 110.0)
const TRAY_CELL := 34.0
const TRAY_WIDTH := 200.0
const TRAY_ROW_GAP := 18.0
const TRAY_LABEL_HEIGHT := 22.0

const _BACKDROP := Color(0.09, 0.10, 0.13)
const _CELL_FILL := Color(0.16, 0.17, 0.21)
const _CELL_LINE := Color(0.28, 0.30, 0.36)
const _START_LINE := Color(1.0, 0.84, 0.35)
const _CHAIN_LINE := Color(0.45, 0.92, 1.0)
const _BREAK_LINE := Color(1.0, 0.38, 0.38)
const _LOOT_FILL := Color(0.38, 0.34, 0.28)
const _TEXT := Color(0.93, 0.95, 0.98)
const _DIM_TEXT := Color(0.62, 0.66, 0.72)
const _BADGE_FILL := Color(0.06, 0.08, 0.11)

## 무기 색. 아이템을 **처음 본 순서대로** 하나씩 나눠 준다.
##
## 아이템 id 로 표를 만들지 않는 이유는, 그러면 표본 아이템 목록이 두 곳에 생겨서
## 한쪽만 고쳤을 때 색이 엉키기 때문이다.
const _ITEM_COLORS := [
	Color(0.30, 0.45, 0.72),
	Color(0.62, 0.34, 0.58),
	Color(0.30, 0.58, 0.48),
	Color(0.70, 0.46, 0.26),
	Color(0.40, 0.38, 0.68),
	Color(0.60, 0.32, 0.36),
	Color(0.32, 0.54, 0.62),
	Color(0.52, 0.52, 0.30),
]

var _grid: BackpackGrid
var _tray: Array[BackpackItem] = []
var _chains: Array[ChainResult] = []

var _drag_item: BackpackItem = null
var _drag_grab: Vector2i = Vector2i.ZERO
var _drag_came_from_grid := false
var _drag_return_origin := Vector2i.ZERO
var _mouse := Vector2.ZERO

## 아이템 id -> 색 번호. 본 순서대로 채워진다.
var _color_slots: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func bind(grid: BackpackGrid, tray: Array[BackpackItem]) -> void:
	_grid = grid
	_tray = tray.duplicate()
	queue_redraw()


func set_chains(chains: Array[ChainResult]) -> void:
	_chains = chains
	queue_redraw()


func tray_items() -> Array[BackpackItem]:
	return _tray.duplicate()


## 대기줄로 되돌린다. 화면 바깥(초기화 등)에서 격자를 갈아엎을 때 쓴다.
func reset_tray(items: Array[BackpackItem]) -> void:
	_tray = items.duplicate()
	queue_redraw()


# ---------------------------------------------------------------- 입력


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = (event as InputEventMouseMotion).position
		if _drag_item != null:
			queue_redraw()
		return

	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		_mouse = button.position
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_begin_drag()
			else:
				_end_drag()
		elif button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
			_send_to_tray_under_mouse()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_R:
			_rotate()
		KEY_C:
			_clear_grid()
		KEY_SPACE:
			_restore_sample()
		_:
			return
	get_viewport().set_input_as_handled()


func _begin_drag() -> void:
	if _drag_item != null:
		return

	var placement := _placement_under_mouse()
	if placement != null:
		_drag_item = placement.item
		_drag_grab = _grid_cell_at(_mouse) - placement.origin
		_drag_came_from_grid = true
		_drag_return_origin = placement.origin
		_grid.remove(placement)
		_emit_changed()
		return

	var index := _tray_index_at(_mouse)
	if index >= 0:
		_drag_item = _tray[index]
		_drag_grab = Vector2i.ZERO
		_drag_came_from_grid = false
		_tray.remove_at(index)
		_emit_changed()


func _end_drag() -> void:
	if _drag_item == null:
		return
	var item := _drag_item
	_drag_item = null

	var target := _grid_cell_at(_mouse) - _drag_grab
	if _is_over_grid(_mouse) and _grid.can_place(item, target):
		_grid.place(item, target)
	elif _is_over_tray(_mouse):
		_tray.append(item)
	elif _drag_came_from_grid and _grid.can_place(item, _drag_return_origin):
		_grid.place(item, _drag_return_origin)
	else:
		_tray.append(item)
	_emit_changed()


## 끌고 있으면 끌고 있는 것을, 아니면 마우스 밑의 것을 제자리에서 돌린다.
##
## 제자리 회전은 **돌린 모양이 그 자리에 들어갈 때만** 먹는다.
func _rotate() -> void:
	if _drag_item != null:
		_drag_grab = _drag_item.rotate_offset(_drag_grab)
		_drag_item = _drag_item.rotated()
		queue_redraw()
		return

	var placement := _placement_under_mouse()
	if placement == null:
		return
	var turned := placement.item.rotated()
	if not _grid.can_place(turned, placement.origin, placement):
		return
	var origin := placement.origin
	_grid.remove(placement)
	_grid.place(turned, origin)
	_emit_changed()


func _send_to_tray_under_mouse() -> void:
	var placement := _placement_under_mouse()
	if placement == null:
		return
	_grid.remove(placement)
	_tray.append(placement.item)
	_emit_changed()


func _clear_grid() -> void:
	for placement in _grid.placements():
		_tray.append(placement.item)
	_grid.clear()
	_emit_changed()


func _restore_sample() -> void:
	_grid.clear()
	_tray = SampleBackpack.fill(_grid, SampleBackpack.create_items())
	_emit_changed()


func _emit_changed() -> void:
	queue_redraw()
	layout_changed.emit()


# ---------------------------------------------------------------- 좌표


func _grid_rect() -> Rect2:
	return Rect2(GRID_ORIGIN, Vector2(_grid.width, _grid.height) * CELL)


func _is_over_grid(point: Vector2) -> bool:
	return _grid_rect().has_point(point)


func _is_over_tray(point: Vector2) -> bool:
	return point.x >= TRAY_ORIGIN.x and point.x <= TRAY_ORIGIN.x + TRAY_WIDTH


## 화면 좌표를 격자 칸으로. 격자 밖이어도 계산은 한다 (끌고 나갔을 때 필요하다).
func _grid_cell_at(point: Vector2) -> Vector2i:
	var local := (point - GRID_ORIGIN) / CELL
	return Vector2i(floori(local.x), floori(local.y))


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(GRID_ORIGIN + Vector2(cell) * CELL, Vector2(CELL, CELL))


func _cell_center(cell: Vector2i) -> Vector2:
	return _cell_rect(cell).get_center()


func _placement_under_mouse() -> BackpackPlacement:
	if _grid == null or not _is_over_grid(_mouse):
		return null
	return _grid.placement_at(_grid_cell_at(_mouse))


func _tray_row_top(index: int) -> float:
	var top := TRAY_ORIGIN.y
	for i in index:
		top += _tray_row_height(_tray[i])
	return top


func _tray_row_height(item: BackpackItem) -> float:
	return TRAY_LABEL_HEIGHT + item.bounds_size().y * TRAY_CELL + TRAY_ROW_GAP


func _tray_index_at(point: Vector2) -> int:
	if not _is_over_tray(point):
		return -1
	for index in _tray.size():
		var top := _tray_row_top(index)
		if point.y >= top and point.y < top + _tray_row_height(_tray[index]):
			return index
	return -1


func _color_for(item: BackpackItem) -> Color:
	if item.kind == BackpackItem.Kind.LOOT:
		return _LOOT_FILL
	if not _color_slots.has(item.id):
		_color_slots[item.id] = _color_slots.size()
	return _ITEM_COLORS[int(_color_slots[item.id]) % _ITEM_COLORS.size()]


# ---------------------------------------------------------------- 그리기


func _draw() -> void:
	if _grid == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), _BACKDROP)
	_draw_empty_cells()
	for placement in _grid.placements():
		_draw_placement(placement)
	_draw_start_nodes()
	for chain in _chains:
		_draw_chain(chain)
	_draw_tray()
	_draw_dragged()


func _draw_empty_cells() -> void:
	for y in _grid.height:
		for x in _grid.width:
			var rect := _cell_rect(Vector2i(x, y))
			draw_rect(rect, _CELL_FILL)
			draw_rect(rect, _CELL_LINE, false, 1.0)


func _draw_placement(placement: BackpackPlacement) -> void:
	var color := _color_for(placement.item)
	for cell in placement.cells():
		var rect := _cell_rect(cell).grow(-2.0)
		draw_rect(rect, color)
		draw_rect(rect, color.lightened(0.25), false, 2.0)
	_draw_label_in_cell(placement.cells()[0], placement.item.display_name, _TEXT, 16)
	if placement.has_output():
		_draw_output_arrow(placement.output_cell(), placement.item.output_direction, color)


## 출력 블럭이 가리키는 쪽으로 삼각형을 그린다. **글자가 아니라 도형이다.**
func _draw_output_arrow(cell: Vector2i, direction: ChainDirection.Kind, base: Color) -> void:
	var rect := _cell_rect(cell)
	var center := rect.get_center()
	var forward := Vector2(ChainDirection.to_vector(direction))
	var side := Vector2(-forward.y, forward.x)
	var reach := CELL * 0.5 - 6.0
	var tip := center + forward * reach
	var back := center + forward * (reach - 15.0)
	var points := PackedVector2Array([tip, back + side * 10.0, back - side * 10.0])
	draw_colored_polygon(points, base.lightened(0.55))
	# 출력 블럭 자체도 표시한다 — 여러 칸짜리 무기에서 어느 칸이 출력인지 보여야 한다.
	draw_rect(rect.grow(-6.0), base.lightened(0.55), false, 2.0)


func _draw_start_nodes() -> void:
	for cell in _grid.start_nodes:
		var rect := _cell_rect(cell)
		draw_rect(rect.grow(-1.0), _START_LINE, false, 4.0)
		_draw_label_below(rect, "시작", _START_LINE)


func _draw_chain(chain: ChainResult) -> void:
	for index in chain.steps.size():
		var placement := chain.steps[index]
		if index + 1 < chain.steps.size():
			var to_cell := placement.output_target()
			draw_line(
				_cell_center(placement.output_cell()), _cell_center(to_cell), _CHAIN_LINE, 4.0
			)
		_draw_order_badge(placement.cells()[0], index + 1)
	if chain.has_break_cell and not chain.is_complete():
		_draw_break_mark(chain.break_cell)


## 발동 순서를 동그라미와 **아라비아 숫자**로. 원문자(U+2460 등)는 폰트에 없다.
func _draw_order_badge(cell: Vector2i, order: int) -> void:
	var rect := _cell_rect(cell)
	var center := rect.position + Vector2(15.0, 15.0)
	draw_circle(center, 12.0, _BADGE_FILL)
	draw_arc(center, 12.0, 0.0, TAU, 24, _CHAIN_LINE, 2.0)
	var font := get_theme_default_font()
	var text := str(order)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15).x
	draw_string(
		font,
		center + Vector2(-width * 0.5, 5.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		15,
		_CHAIN_LINE
	)


## 체인이 끊긴 자리에 가위표. 격자 밖을 가리켰으면 격자 밖에 그려진다 — 그것이 정보다.
func _draw_break_mark(cell: Vector2i) -> void:
	var rect := _cell_rect(cell).grow(-18.0)
	draw_line(rect.position, rect.position + rect.size, _BREAK_LINE, 4.0)
	draw_line(
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + Vector2(0.0, rect.size.y),
		_BREAK_LINE,
		4.0
	)


func _draw_tray() -> void:
	var font := get_theme_default_font()
	draw_string(
		font, TRAY_ORIGIN + Vector2(0.0, -14.0), "대기줄", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, _TEXT
	)
	if _tray.is_empty():
		draw_string(
			font,
			TRAY_ORIGIN + Vector2(0.0, 18.0),
			"비었다",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			15,
			_DIM_TEXT
		)
		return

	for index in _tray.size():
		var item := _tray[index]
		var top := _tray_row_top(index)
		draw_string(
			font,
			Vector2(TRAY_ORIGIN.x, top + 15.0),
			_tray_caption(item),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			15,
			_DIM_TEXT
		)
		_draw_small_shape(item, Vector2(TRAY_ORIGIN.x, top + TRAY_LABEL_HEIGHT))


func _tray_caption(item: BackpackItem) -> String:
	if not item.has_output():
		return "%s (전리품)" % item.display_name
	return "%s (%s)" % [item.display_name, ChainDirection.label(item.output_direction)]


## 대기줄과 손에 든 것을 작게 그린다. 출력 블럭은 밝은 테두리로만 표시한다.
func _draw_small_shape(item: BackpackItem, at: Vector2) -> void:
	var color := _color_for(item)
	for cell in item.shape:
		var rect := Rect2(at + Vector2(cell) * TRAY_CELL, Vector2(TRAY_CELL, TRAY_CELL)).grow(-1.0)
		draw_rect(rect, color)
		draw_rect(rect, color.lightened(0.25), false, 1.0)
	if item.has_output():
		var out_rect := Rect2(
			at + Vector2(item.output_cell) * TRAY_CELL, Vector2(TRAY_CELL, TRAY_CELL)
		)
		draw_rect(out_rect.grow(-3.0), color.lightened(0.55), false, 2.0)


## 끌고 있는 것. 놓을 수 있으면 격자에 미리 비추고, 없으면 커서를 따라다닌다.
func _draw_dragged() -> void:
	if _drag_item == null:
		return
	var target := _grid_cell_at(_mouse) - _drag_grab
	if _is_over_grid(_mouse):
		var allowed := _grid.can_place(_drag_item, target)
		var tint := _color_for(_drag_item) if allowed else _BREAK_LINE
		for cell in _drag_item.cells_at(target):
			draw_rect(_cell_rect(cell).grow(-2.0), Color(tint, 0.55))
			draw_rect(_cell_rect(cell).grow(-2.0), tint, false, 2.0)
		if allowed and _drag_item.has_output():
			_draw_output_arrow(_drag_item.output_cell_at(target), _drag_item.output_direction, tint)
		return
	_draw_small_shape(_drag_item, _mouse - Vector2(TRAY_CELL, TRAY_CELL) * 0.5)


func _draw_label_in_cell(cell: Vector2i, text: String, color: Color, font_size: int) -> void:
	var rect := _cell_rect(cell)
	draw_string(
		get_theme_default_font(),
		rect.position + Vector2(4.0, CELL - 10.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		rect.size.x * 2.0,
		font_size,
		color
	)


func _draw_label_below(rect: Rect2, text: String, color: Color) -> void:
	draw_string(
		get_theme_default_font(),
		rect.position + Vector2(2.0, -6.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		14,
		color
	)
