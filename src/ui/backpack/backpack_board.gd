class_name BackpackBoard
extends Control
## 백팩 격자와 대기줄을 그리고 드래그를 받는다. **판정 수단이지 게임 화면이 아니다.**
##
## `docs/design/28-combat.md` §28.20.9.
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

## 지금 짜 놓은 체인을 실제로 쏴 보라는 요청 (§28.4).
signal fire_requested

## 전진이 남을지 돌아올지를 바꿔 보라는 요청. **미정이라 만져 볼 수 있게 둔다** (§28.20.30).
signal advance_mode_toggled

const GRID_ORIGIN := Vector2(40.0, 110.0)
const CELL := 72.0

const TRAY_ORIGIN := Vector2(560.0, 110.0)
const TRAY_CELL := 28.0
const TRAY_ROW_GAP := 14.0
const TRAY_LABEL_HEIGHT := 20.0

## 대기줄은 두 줄로 세운다. 아이템을 늘리자 한 줄로는 화면 밖으로 넘쳤다.
const TRAY_COLUMNS := 2
const TRAY_COL_WIDTH := 100.0
const TRAY_WIDTH := TRAY_COLUMNS * TRAY_COL_WIDTH

const _BACKDROP := Color(0.09, 0.10, 0.13)
const _CELL_FILL := Color(0.16, 0.17, 0.21)
const _CELL_LINE := Color(0.28, 0.30, 0.36)
const _START_LINE := Color(1.0, 0.84, 0.35)
const _CHAIN_LINE := Color(0.45, 0.92, 1.0)
const _BREAK_LINE := Color(1.0, 0.38, 0.38)

## 끊긴 것이 아니라 **끝난** 것. 붉은색을 쓰면 정상 종료가 사고처럼 보인다.
const _DONE_LINE := Color(0.52, 0.86, 0.56)

## 말표가 올라가면 안 되는 위쪽 여백. 머리글 Label 이 이 위에 그려진다.
const _TAG_TOP_MARGIN := 96.0

## 대련장 자리. 글자판 아래의 빈 곳이다.
const ARENA_LEFT := 1052.0
const ARENA_GROUND := 640.0

## 대련장 거리를 화면에 줄여 그리는 비율. 기본 간격 240 이 화면 밖으로 나갔다.
const ARENA_SCALE := 0.78
const _LOOT_FILL := Color(0.33, 0.33, 0.31)
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
var _outcomes: Array[ChainBreakOutcome] = []
var _break_tuning: BreakTuning = null
var _bout: SparringBout = null
var _field: SparringField = null

var _drag_item: BackpackItem = null
var _drag_grab: Vector2i = Vector2i.ZERO
var _drag_came_from_grid := false
var _drag_return_origin := Vector2i.ZERO
var _mouse := Vector2.ZERO

## 아이템 id -> 색 번호. 본 순서대로 채워진다.
var _color_slots: Dictionary = {}

## 지금 어느 체인엔가 들어가 있는 배치들. 나머지는 흐리게 그린다.
var _chained: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func bind(grid: BackpackGrid, tray: Array[BackpackItem]) -> void:
	_grid = grid
	_tray = tray.duplicate()
	queue_redraw()


func set_chains(chains: Array[ChainResult]) -> void:
	_chains = chains
	_chained.clear()
	for chain in chains:
		for placement in chain.steps:
			_chained[placement] = true
	queue_redraw()


## 체인이 상대를 얼마나 무너뜨렸나 (§28.5). 눈금을 격자 아래에 그린다.
func set_break(outcomes: Array[ChainBreakOutcome], tuning: BreakTuning) -> void:
	_outcomes = outcomes
	_break_tuning = tuning
	queue_redraw()


## 지금 굴러가고 있는 대련 판. `null` 이면 아직 안 쐈다.
func set_bout(bout: SparringBout) -> void:
	_bout = bout
	queue_redraw()


## 대련장의 거리. 리치·전진 값이 오면 여기 그린 간격 위에서 판정이 붙는다 (§28.20.27).
func set_field(field: SparringField) -> void:
	_field = field
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
		KEY_F:
			fire_requested.emit()
		KEY_T:
			advance_mode_toggled.emit()
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


## 한 줄의 높이는 그 줄에서 **가장 키 큰 아이템**이 정한다.
func _tray_row_height(row: int) -> float:
	var tallest := 1
	var first := row * TRAY_COLUMNS
	for index in range(first, mini(first + TRAY_COLUMNS, _tray.size())):
		tallest = maxi(tallest, _tray[index].bounds_size().y)
	return TRAY_LABEL_HEIGHT + float(tallest) * TRAY_CELL + TRAY_ROW_GAP


## 대기줄 한 자리가 차지하는 네모. 그리기와 집기가 **같은 식**을 쓴다 —
## 따로 적으면 눈에 보이는 자리와 집히는 자리가 어긋난다.
func _tray_slot_rect(index: int) -> Rect2:
	var row := index / TRAY_COLUMNS
	var top := TRAY_ORIGIN.y
	for earlier in row:
		top += _tray_row_height(earlier)
	var left := TRAY_ORIGIN.x + float(index % TRAY_COLUMNS) * TRAY_COL_WIDTH
	return Rect2(Vector2(left, top), Vector2(TRAY_COL_WIDTH, _tray_row_height(row)))


func _tray_index_at(point: Vector2) -> int:
	for index in _tray.size():
		if _tray_slot_rect(index).has_point(point):
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
	_draw_break_gauge()
	_draw_arena()
	_draw_tray()
	_draw_dragged()


func _draw_empty_cells() -> void:
	for y in _grid.height:
		for x in _grid.width:
			var rect := _cell_rect(Vector2i(x, y))
			draw_rect(rect, _CELL_FILL)
			draw_rect(rect, _CELL_LINE, false, 1.0)


## 체인에 든 것은 또렷하게, 안 든 것은 흐리게.
##
## **이것이 이 화면의 값어치다** — 어느 아이템이 루트에서 빠졌는지가 한눈에 보여야
## "왜 이것만 안 걸리지" 를 눈으로 찾지 않는다.
func _draw_placement(placement: BackpackPlacement) -> void:
	var color := _color_for(placement.item)
	var faded := not _chained.is_empty() and not _chained.has(placement)
	if faded:
		color = color.darkened(0.55)
	for cell in placement.cells():
		var rect := _cell_rect(cell).grow(-2.0)
		draw_rect(rect, color)
		draw_rect(rect, color.lightened(0.25), false, 2.0)
		if placement.item.kind == BackpackItem.Kind.LOOT:
			_draw_hatch(rect, color.lightened(0.30))
	_draw_label_in_cell(
		placement.cells()[0], placement.item.display_name, _DIM_TEXT if faded else _TEXT, 16
	)
	if placement.has_output():
		_draw_output_arrow(placement.output_cell(), placement.item.output_direction, color)


## 전리품은 빗금으로 긋는다.
##
## 색만으로 가르면 무기 색 하나와 반드시 비슷해진다 — 실제로 창(주황)과 원석이
## 화면에서 헷갈렸다. 빗금은 색과 무관하게 **"이건 짐이다"** 로 읽힌다.
func _draw_hatch(rect: Rect2, color: Color) -> void:
	var step := 12.0
	var offset := step
	while offset < rect.size.x + rect.size.y:
		var from := Vector2(rect.position.x + minf(offset, rect.size.x), 0.0)
		from.y = rect.position.y + maxf(0.0, offset - rect.size.x)
		var to := Vector2(0.0, rect.position.y + minf(offset, rect.size.y))
		to.x = rect.position.x + maxf(0.0, offset - rect.size.y)
		draw_line(from, to, color, 1.5)
		offset += step


## 출력 블럭이 가리키는 쪽으로 삼각형을 그린다. **글자가 아니라 도형이다.**
func _draw_output_arrow(cell: Vector2i, direction: ChainDirection.Kind, base: Color) -> void:
	var rect := _cell_rect(cell)
	_draw_arrow_in(rect, direction, base.lightened(0.55), 10.0)
	# 출력 블럭 자체도 표시한다 — 여러 칸짜리 무기에서 어느 칸이 출력인지 보여야 한다.
	draw_rect(rect.grow(-6.0), base.lightened(0.55), false, 2.0)


## 방향 삼각형 하나. **격자에서도 대기줄에서도 같은 식을 쓴다** —
## 두 번 적으면 한쪽만 고쳤을 때 두 곳의 화살표가 서로 다른 데를 가리킨다.
func _draw_arrow_in(
	rect: Rect2, direction: ChainDirection.Kind, color: Color, half_width: float
) -> void:
	if direction == ChainDirection.Kind.NONE:
		return
	var center := rect.get_center()
	var forward := Vector2(ChainDirection.to_vector(direction))
	var side := Vector2(-forward.y, forward.x)
	var reach := minf(rect.size.x, rect.size.y) * 0.5 - 4.0
	var tip := center + forward * reach
	var back := center + forward * (reach - half_width * 1.5)
	draw_colored_polygon(
		PackedVector2Array([tip, back + side * half_width, back - side * half_width]), color
	)


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
	_draw_stop_mark(chain)


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


## 체인이 어디서 **왜** 멈췄는지를 격자 위에 바로 그린다.
##
## 멈춘 이유 7종을 만들어 뒀으니(§28.20.5) 화면이 그것을 써야 한다 —
## 「격자 밖」과 「빈 칸」과 「이미 지남」은 전부 "체인이 짧다" 로 보이지만
## **고치는 방법이 다르다.**
func _draw_stop_mark(chain: ChainResult) -> void:
	var reason := chain.stop_reason
	var color := _DONE_LINE if chain.is_complete() else _BREAK_LINE

	if reason == ChainResult.StopReason.NO_START_ITEM:
		_draw_tag_near(chain.start_node, chain.short_stop_label(), color)
		return

	if reason == ChainResult.StopReason.NO_OUTPUT:
		# 정상 종료. 마지막 아이템에 조용한 마감 표시만 둔다.
		if not chain.steps.is_empty():
			var last: BackpackPlacement = chain.steps[chain.steps.size() - 1]
			_draw_tag_near(last.cells()[0], chain.short_stop_label(), color)
		return

	if not chain.has_break_cell:
		return

	if reason == ChainResult.StopReason.ALREADY_CHAINED:
		# 돌아간 자리를 동그라미로 감는다. 가위표는 "없다" 로 읽혀서 안 맞는다.
		var center := _cell_center(chain.break_cell)
		draw_arc(center, CELL * 0.32, 0.0, TAU, 32, color, 4.0)
	else:
		_draw_cross(chain.break_cell, color)
	_draw_tag_near(chain.break_cell, chain.short_stop_label(), color)


func _draw_cross(cell: Vector2i, color: Color) -> void:
	var rect := _cell_rect(cell).grow(-20.0)
	draw_line(rect.position, rect.position + rect.size, color, 4.0)
	draw_line(
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + Vector2(0.0, rect.size.y),
		color,
		4.0
	)


## 칸 옆에 짧은 말표를 붙인다. 화면 밖으로 나가지 않게 가둔다 —
## 격자 밖을 가리킨 경우 칸 자체가 판 바깥이라 그냥 그리면 잘린다.
func _draw_tag_near(cell: Vector2i, text: String, color: Color) -> void:
	var font := get_theme_default_font()
	var extent := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13)
	var box := Vector2(extent.x + 12.0, extent.y + 8.0)
	var cell_rect := _cell_rect(cell)
	# 칸 **옆에** 붙인다. 위에 붙이면 격자 밖(위쪽)을 가리켰을 때 머리글과 겹친다.
	var at := Vector2(cell_rect.end.x + 6.0, cell_rect.get_center().y - box.y * 0.5)
	if at.x + box.x > size.x - 2.0:
		at.x = cell_rect.position.x - box.x - 6.0
	at.x = clampf(at.x, 2.0, maxf(2.0, size.x - box.x - 2.0))
	at.y = clampf(at.y, _TAG_TOP_MARGIN, maxf(_TAG_TOP_MARGIN, size.y - box.y - 2.0))
	var rect := Rect2(at, box)
	draw_rect(rect, _BADGE_FILL)
	draw_rect(rect, color, false, 1.5)
	draw_string(
		font, at + Vector2(6.0, extent.y + 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, color
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
		var slot := _tray_slot_rect(index)
		draw_string(
			font,
			slot.position + Vector2(0.0, 14.0),
			_tray_caption(item),
			HORIZONTAL_ALIGNMENT_LEFT,
			TRAY_COL_WIDTH,
			14,
			_DIM_TEXT
		)
		_draw_small_shape(item, slot.position + Vector2(0.0, TRAY_LABEL_HEIGHT))


## 방향은 글자로 적지 않고 **작은 삼각형으로** 보여 준다. 두 줄이 되면서 폭이
## 좁아져 "장검 (오른쪽)" 같은 글자가 옆 칸을 침범했다.
func _tray_caption(item: BackpackItem) -> String:
	if not item.has_output():
		return "%s (짐)" % item.display_name
	return item.display_name


## 대기줄과 손에 든 것을 작게 그린다. 출력 블럭은 밝은 테두리로만 표시한다.
func _draw_small_shape(item: BackpackItem, at: Vector2) -> void:
	var color := _color_for(item)
	for cell in item.shape:
		var rect := Rect2(at + Vector2(cell) * TRAY_CELL, Vector2(TRAY_CELL, TRAY_CELL)).grow(-1.0)
		draw_rect(rect, color)
		draw_rect(rect, color.lightened(0.25), false, 1.0)
		if item.kind == BackpackItem.Kind.LOOT:
			_draw_hatch(rect, color.lightened(0.30))
	if item.has_output():
		var out_rect := Rect2(
			at + Vector2(item.output_cell) * TRAY_CELL, Vector2(TRAY_CELL, TRAY_CELL)
		)
		draw_rect(out_rect.grow(-3.0), color.lightened(0.55), false, 2.0)
		_draw_arrow_in(out_rect, item.output_direction, color.lightened(0.6), 5.0)


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


## 무너짐 눈금을 격자 아래에 막대로 그린다 (§28.5).
##
## **체인 길이가 여기서 값을 한다** — 짧은 체인은 눈금이 다 차기 전에 끝나고,
## 긴 체인은 문턱을 넘긴다. 숫자로만 적으면 그 차이가 안 보인다.
##
## 문턱 눈금은 `BreakTuning` 이 정한다. 여기 수치를 따로 적지 않는다 —
## 두 곳에 적으면 막대가 옛 문턱을 그린다.
func _draw_break_gauge() -> void:
	if _break_tuning == null or _outcomes.is_empty():
		return
	var top := GRID_ORIGIN.y + float(_grid.height) * CELL + 26.0
	var width := float(_grid.width) * CELL

	# 판이 돌고 있으면 **지금 눈금**을, 아니면 계산해 둔 최고치를 보여 준다.
	# 실시간에 최고치만 그리면 눈금이 빠지는 것이 안 보인다.
	var peak := 0.0
	var highest := BreakState.Kind.NONE
	var live := -1.0
	if _bout != null and _bout.phase() != SparringBout.Phase.READY:
		peak = _bout.peak()
		highest = _bout.peak_state()
		live = _bout.gauge_value()
	else:
		for outcome in _outcomes:
			peak = maxf(peak, outcome.peak)
			if BreakState.is_worse(outcome.highest, highest):
				highest = outcome.highest

	_draw_one_gauge(Vector2(GRID_ORIGIN.x, top), width, "적 무너짐", live, peak, highest)

	# **우리 쪽도 그린다.** 적에게만 있으면 대련장이 샌드백이다.
	if _bout != null and _bout.has_enemy():
		_draw_one_gauge(
			Vector2(GRID_ORIGIN.x, top + 64.0),
			width,
			"우리 무너짐",
			_bout.own_gauge_value(),
			_bout.own_peak(),
			_bout.own_peak_state()
		)


## 눈금 막대 하나. 두 쪽이 **같은 식**으로 그려져야 견줄 수 있다.
func _draw_one_gauge(
	at: Vector2, width: float, label: String, live: float, peak: float, highest: BreakState.Kind
) -> void:
	var font := get_theme_default_font()
	draw_string(font, at + Vector2(0.0, -8.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, _TEXT)

	var bar := Rect2(at, Vector2(width, 22.0))
	draw_rect(bar, _CELL_FILL)
	draw_rect(bar, _CELL_LINE, false, 1.0)

	var shown := live if live >= 0.0 else peak
	var ratio := clampf(shown / maxf(1.0, _break_tuning.max_value), 0.0, 1.0)
	draw_rect(
		Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)),
		_state_color(_break_tuning.state_for(shown))
	)
	if live >= 0.0 and peak > shown:
		var mark := (
			bar.position.x
			+ bar.size.x * clampf(peak / maxf(1.0, _break_tuning.max_value), 0.0, 1.0)
		)
		draw_line(
			Vector2(mark, bar.position.y), Vector2(mark, bar.end.y), _state_color(highest), 3.0
		)

	var thresholds: Array[float] = [
		_break_tuning.stagger_at, _break_tuning.launch_at, _break_tuning.knockdown_at
	]
	for threshold in thresholds:
		var x := bar.position.x + bar.size.x * (threshold / maxf(1.0, _break_tuning.max_value))
		draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), _TEXT, 1.5)

	draw_string(
		font,
		Vector2(bar.position.x + 6.0, bar.end.y + 15.0),
		_gauge_caption(shown, peak, highest),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		14,
		_state_color(_break_tuning.state_for(shown))
	)


func _state_color(kind: BreakState.Kind) -> Color:
	if kind == BreakState.Kind.KNOCKDOWN:
		return Color(0.95, 0.45, 0.35)
	if kind == BreakState.Kind.LAUNCH:
		return Color(0.96, 0.72, 0.30)
	if kind == BreakState.Kind.STAGGER:
		return Color(0.60, 0.78, 0.45)
	return Color(0.36, 0.40, 0.48)


## **지금 값 옆에는 지금 단계를 적는다.**
##
## 처음에 최고 단계를 적었더니 눈금이 32(경직)로 빠진 뒤에도 "띄우기" 라고 적혀 있었다.
## 캡처에서 걸렸다 — 막대 색은 초록인데 글자는 띄우기였다.
func _gauge_caption(shown: float, peak_value: float, highest: BreakState.Kind) -> String:
	var now := (
		"%.0f / %.0f    %s"
		% [shown, _break_tuning.max_value, BreakState.label(_break_tuning.state_for(shown))]
	)
	if _bout == null or _bout.phase() == SparringBout.Phase.READY:
		return now
	return "%s    (최고 %.0f %s)" % [now, peak_value, BreakState.label(highest)]


## 대련장. **적은 네모 하나다** (§28.4 최소 대련장).
##
## 캐릭터 애니 레인이 `hit` 을 따로 만들었고 이름이 겹치지만 **지금 붙이지 않는다** —
## 양쪽이 굳은 다음에 붙인다. 여기서는 네모가 무너짐 단계를 그대로 비춘다.
##
## **이동 · 회전 · 배율만 쓴다** (§28.7). 프레임 교체도 변형도 없다.
func _draw_arena() -> void:
	if _field == null:
		return
	var font := get_theme_default_font()
	var ground := ARENA_GROUND
	draw_line(
		Vector2(ARENA_LEFT - 24.0, ground), Vector2(ARENA_LEFT + 224.0, ground), _CELL_LINE, 2.0
	)

	var state := BreakState.Kind.NONE
	if _bout != null and _bout.phase() != SparringBout.Phase.READY:
		state = _bout.state()

	# 대원과 적. **둘 다 위치를 가진다** — 리치·전진 값이 오면 이 간격 위에 판정이 얹힌다.
	var own_state := BreakState.Kind.NONE
	if _bout != null and _bout.phase() != SparringBout.Phase.READY:
		own_state = _bout.own_state()
	_draw_fighter(_field.attacker_x, ground, Color(0.42, 0.56, 0.78), own_state)
	_draw_fighter(_field.target_x, ground, _state_color(state), state)

	var left := _arena_x(minf(_field.attacker_x, _field.target_x))
	var right := _arena_x(maxf(_field.attacker_x, _field.target_x))
	draw_line(Vector2(left, ground + 12.0), Vector2(right, ground + 12.0), _DIM_TEXT, 1.0)
	_draw_reach(ground)

	# 글자는 **바닥선 아래 한 줄**로 모은다. 위에 두었더니 체인 목록과 겹쳤다 —
	# 18타짜리를 쐈을 때 캡처에서 드러났다.
	draw_string(
		font,
		Vector2(ARENA_LEFT - 24.0, ground + 32.0),
		(
			"대련장 (F)   간격 %.0f   전진 %s (T)"
			% [
				_field.gap(),
				"남는다" if _field.advance_mode == SparringField.AdvanceMode.STAY else "돌아온다",
			]
		),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		14,
		_DIM_TEXT
	)
	# 단계는 **둘째 줄**에 둔다. 간격·전진까지 한 줄에 넣었더니 글자가 겹쳤다.
	draw_string(
		font,
		Vector2(ARENA_LEFT - 24.0, ground + 52.0),
		BreakState.label(state),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		16,
		_state_color(state)
	)


## 다음에 나갈 무기가 **어디까지 닿는지**를 눈금으로 세운다.
##
## 닿지 않으면 체인이 거기서 끊긴다 — 백팩에서는 이어져 있는데도.
## **격자 이유와 다른 층이라** 격자 쪽 가위표와 다르게 보여야 한다.
func _draw_reach(ground: float) -> void:
	if _bout == null or _bout.total_hits() == 0:
		return
	var index := mini(_bout.landed(), _bout.total_hits() - 1)
	var item := _bout.item_at(index)
	if item == null:
		return
	var reach := WeaponMotion.reach_px(item)
	var edge := _arena_x(_field.attacker_x + _field.facing() * reach)
	var in_range := _field.gap() <= reach
	var color := _DIM_TEXT if in_range else _BREAK_LINE
	draw_line(Vector2(edge, ground - 122.0), Vector2(edge, ground + 6.0), color, 2.0)
	draw_string(
		get_theme_default_font(),
		Vector2(edge - 88.0, ground - 128.0),
		"리치 %.0f" % reach,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		13,
		color
	)
	if _bout.was_out_of_reach():
		draw_string(
			get_theme_default_font(),
			Vector2(ARENA_LEFT - 24.0, ground - 120.0),
			"닿지 않는다",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			16,
			_BREAK_LINE
		)


func _arena_x(field_x: float) -> float:
	return ARENA_LEFT + field_x * ARENA_SCALE


## 싸우는 것 하나. **이동 · 회전 · 배율만** 쓴다 (§28.7).
func _draw_fighter(field_x: float, ground: float, color: Color, state: BreakState.Kind) -> void:
	var lift := 0.0
	var tilt := 0.0
	var squash := 1.0
	if state == BreakState.Kind.STAGGER:
		tilt = 0.16
	elif state == BreakState.Kind.LAUNCH:
		lift = 62.0
		tilt = 0.42
	elif state == BreakState.Kind.KNOCKDOWN:
		squash = 0.32
		tilt = 1.35

	var half := Vector2(26.0, 38.0 * squash)
	var center := Vector2(_arena_x(field_x), ground - half.y - lift)
	var corners: Array[Vector2] = [
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	]
	var points := PackedVector2Array()
	for corner in corners:
		points.append(center + corner.rotated(tilt))
	draw_colored_polygon(points, color)
	draw_polyline(points + PackedVector2Array([points[0]]), _TEXT, 2.0)
