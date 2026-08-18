extends Node2D
## 유닛 이동 조작감 프로토타입의 진입점. 입력을 받아 순수 로직에 넘기고 결과를 화면에 반영한다.
##
## **이 프로토타입의 목적은 기능 목록을 채우는 것이 아니라 손맛을 재는 것이다.**
## 그래서 여기서 하는 일은 셋뿐이다 — 입력을 해석하고, 시뮬레이션을 한 걸음 돌리고,
## 지금 상태를 드러낸다. 이동 규칙 자체는 core/ 의 순수 클래스에 있다.
##
## 전투는 범위 밖이다. 공격 · 체력 · 피해 · 사거리는 하나도 없다.

## 필드 크기. 화면(1280x720)보다 넓어야 부대 지정 화면 이동이 의미를 갖는다.
const GRID_COLS := 60
const GRID_ROWS := 34
const CELL_SIZE := 32.0

const DEFAULT_UNIT_COUNT := 24

## 이 거리보다 짧게 끈 것은 드래그가 아니라 클릭으로 본다.
const DRAG_THRESHOLD := 6.0

const CAMERA_PAN_SPEED := 900.0
const CAMERA_ZOOM_MIN := 0.45
const CAMERA_ZOOM_MAX := 2.0

## 프레임 시간 표본 개수. 유닛을 늘렸을 때 무엇이 무너지는지 보려면 평균과 최악이 함께 필요하다.
const _SAMPLE_COUNT := 120

var tuning: ProtoMoveTuning
var field: ProtoUnitField
var selection: ProtoUnitSelection
var groups: ProtoControlGroups

var _grid: NavGrid
var _obstacle_seed := 20260807
var _unit_count := DEFAULT_UNIT_COUNT
var _drag_active := false
var _drag_additive := false
var _drag_start := Vector2.ZERO
var _drag_current := Vector2.ZERO
var _suppress_release := false
var _panning := false
var _samples: Array[float] = []
var _last_group_slot := -1

@onready var _camera: Camera2D = %Camera
@onready var _terrain: ProtoTerrainView = %TerrainView
@onready var _view: ProtoFieldView = %FieldView
@onready var _debug: ProtoDebugDraw = %DebugDraw
@onready var _panel: ProtoTuningPanel = %TuningPanel
@onready var _stats: Label = %StatsLabel
@onready var _help: Label = %HelpLabel


func _ready() -> void:
	_grid = NavGrid.new(GRID_COLS, GRID_ROWS, CELL_SIZE)
	_build_obstacles(_obstacle_seed)
	tuning = ProtoMoveTuning.new()
	field = ProtoUnitField.new(_grid, tuning)
	selection = ProtoUnitSelection.new()
	groups = ProtoControlGroups.new()

	_terrain.bind(_grid)
	_view.bind(field, selection)
	_debug.bind(field, selection)
	_panel.bind(tuning)
	_panel.units_requested.connect(_on_units_requested)
	_panel.respawn_requested.connect(_respawn)
	_panel.obstacles_requested.connect(_on_obstacles_requested)
	_panel.debug_toggled.connect(_on_debug_toggled)

	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(_grid.field_size().x)
	_camera.limit_bottom = int(_grid.field_size().y)
	_camera.position = Vector2(340, _grid.field_size().y * 0.5)

	_help.text = _help_text()
	_respawn()


func _physics_process(delta: float) -> void:
	field.step(delta)
	_samples.append(field.last_step_usec / 1000.0)
	if _samples.size() > _SAMPLE_COUNT:
		_samples.remove_at(0)


func _process(delta: float) -> void:
	_pan_camera(delta)
	_view.drag_active = _drag_active
	_view.drag_rect = Rect2(_drag_start, _drag_current - _drag_start)
	_view.queue_redraw()
	_debug.queue_redraw()
	_stats.text = _stats_text()


# ----------------------------------------------------------------- 입력


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null:
		_on_mouse_button(button)
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		_on_mouse_motion(motion)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if _handle_group_key(key):
		return
	_handle_command_key(key)


func _on_mouse_button(event: InputEventMouseButton) -> void:
	var world := _screen_to_world(event.position)
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_begin_select(world, event)
			else:
				_end_select(world)
		MOUSE_BUTTON_RIGHT:
			if event.pressed:
				order_move_at(world)
		MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
		MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(1.1)
		MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(1.0 / 1.1)


func _on_mouse_motion(event: InputEventMouseMotion) -> void:
	if _panning:
		_camera.position -= event.relative / _camera.zoom.x
	if _drag_active:
		_drag_current = _screen_to_world(event.position)


## 좌클릭을 눌렀다. 더블클릭이면 상자 선택을 시작하지 않는다.
func _begin_select(world: Vector2, event: InputEventMouseButton) -> void:
	_drag_additive = event.shift_pressed
	if event.double_click:
		_select_same_kind(world)
		_drag_active = false
		_suppress_release = true
		return
	_drag_active = true
	_drag_start = world
	_drag_current = world


## 좌클릭을 뗐다. 끈 거리로 클릭과 상자 선택을 가른다.
func _end_select(world: Vector2) -> void:
	if _suppress_release:
		_suppress_release = false
		return
	if not _drag_active:
		return
	_drag_active = false
	var rect := Rect2(_drag_start, world - _drag_start).abs()
	if rect.size.length() < DRAG_THRESHOLD:
		_click_select(world)
	else:
		_box_select(rect)


func _click_select(world: Vector2) -> void:
	var agent := field.agent_at_point(world)
	if agent == null:
		# 빈 곳 클릭은 선택 해제다. 다만 Shift 로 고르는 중이었다면 건드리지 않는다.
		if not _drag_additive:
			selection.clear()
		return
	if _drag_additive:
		selection.toggle(agent.id)
	else:
		selection.replace(PackedInt32Array([agent.id]))


func _box_select(rect: Rect2) -> void:
	var boxed := field.ids_in_rect(rect)
	if _drag_additive:
		selection.add_from_box(boxed)
	else:
		selection.replace(boxed)


## 더블클릭. 화면에 보이는 같은 종류를 전부 고른다.
##
## 필드 전체가 아니라 화면 안으로 한정하는 이유는, 보이지 않는 유닛이 선택에 섞이면
## 다음 우클릭이 화면 밖의 누군가를 함께 움직여 버리기 때문이다.
func _select_same_kind(world: Vector2) -> void:
	var agent := field.agent_at_point(world)
	if agent == null:
		return
	var view_rect := _visible_world_rect()
	var ids := PackedInt32Array()
	for other in field.agents:
		if other.kind == agent.kind and view_rect.has_point(other.position):
			ids.append(other.id)
	if _drag_additive:
		selection.add(ids)
	else:
		selection.replace(ids)


# ----------------------------------------------------------------- 부대 지정


func _handle_group_key(key: InputEventKey) -> bool:
	var slot := _slot_of(key.keycode)
	if slot < 0:
		return false
	if key.ctrl_pressed:
		groups.assign(slot, selection.ids())
	elif key.shift_pressed:
		groups.append(slot, selection.ids())
	else:
		_recall_group(slot)
	_last_group_slot = slot
	return true


func _recall_group(slot: int) -> void:
	var jump := groups.note_press(slot, Time.get_ticks_msec())
	var members := groups.members(slot)
	if members.is_empty():
		return
	selection.replace(members)
	if jump:
		center_on_group(slot)


## 그 부대가 있는 곳으로 화면을 옮긴다.
func center_on_group(slot: int) -> void:
	var members := groups.members(slot)
	var sum := Vector2.ZERO
	var count := 0
	for id in members:
		var agent := field.agent_of(id)
		if agent != null:
			sum += agent.position
			count += 1
	if count > 0:
		focus_camera(sum / float(count))


func _slot_of(keycode: int) -> int:
	if keycode == KEY_0:
		return 0
	if keycode >= KEY_1 and keycode <= KEY_9:
		return keycode - KEY_1 + 1
	return -1


func _handle_command_key(key: InputEventKey) -> void:
	match key.keycode:
		KEY_F1:
			set_debug_visible(not _debug.visible)
		KEY_TAB:
			_panel.visible = not _panel.visible
		KEY_H:
			_help.visible = not _help.visible
		KEY_X:
			field.stop(selection.ids())
		KEY_R:
			_respawn()
		KEY_ESCAPE:
			selection.clear()
		KEY_A:
			if key.ctrl_pressed:
				select_all()


# ----------------------------------------------------------------- 화면


func _pan_camera(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		move.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		move.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		move.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		move.x += 1.0
	if move != Vector2.ZERO:
		_camera.position += move.normalized() * CAMERA_PAN_SPEED * delta / _camera.zoom.x


func _zoom_camera(factor: float) -> void:
	var next := clampf(_camera.zoom.x * factor, CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
	_camera.zoom = Vector2(next, next)


func _screen_to_world(point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * point


func _visible_world_rect() -> Rect2:
	var size := get_viewport_rect().size / _camera.zoom
	return Rect2(_camera.get_screen_center_position() - size * 0.5, size)


# ----------------------------------------------------------------- 도구가 부르는 입구
##
## 캡처 도구와 성능 측정이 쓴다. 화면 조작을 흉내 내지 않고 같은 경로를 그대로 부른다.


func select_all() -> void:
	selection.replace(field.all_ids())


func order_move_at(world: Vector2) -> void:
	if selection.is_empty():
		return
	field.issue_move(selection.ids(), world)


func set_debug_visible(value: bool) -> void:
	_debug.visible = value


## 화면을 이 지점으로 옮긴다. 부대 화면 이동과 캡처 도구가 같은 길을 쓴다.
func focus_camera(world: Vector2) -> void:
	_camera.position = world


func set_unit_count(count: int) -> void:
	_unit_count = maxi(0, count)
	_respawn()


func unit_count() -> int:
	return field.agents.size()


## 이동 계산 한 걸음의 평균 시간(밀리초).
func average_step_ms() -> float:
	if _samples.is_empty():
		return 0.0
	var total := 0.0
	for value in _samples:
		total += value
	return total / float(_samples.size())


func worst_step_ms() -> float:
	var worst := 0.0
	for value in _samples:
		worst = maxf(worst, value)
	return worst


func reset_samples() -> void:
	_samples.clear()


# ----------------------------------------------------------------- 필드 구성


func _on_units_requested(delta: int) -> void:
	set_unit_count(maxi(1, _unit_count + delta))


func _on_obstacles_requested() -> void:
	_obstacle_seed += 1
	_build_obstacles(_obstacle_seed)
	_terrain.refresh()
	_respawn()


func _on_debug_toggled(key: String, value: bool) -> void:
	match key:
		"flow":
			_debug.show_flow = value
		"forces":
			_debug.show_forces = value
		"slots":
			_debug.show_slots = value


## 유닛을 처음 자리로 되돌린다. 선택과 부대도 함께 정리한다.
func _respawn() -> void:
	field.clear_units()
	var columns := 6
	var origin := Vector2(120.0, 380.0)
	for index in _unit_count:
		var column := index % columns
		var row := index / columns
		var at := origin + Vector2(column * 34.0, row * 34.0)
		field.spawn(index % ProtoUnitAgent.KIND_NAMES.size(), _grid.push_out(at, 14.0))
	selection.retain(field.all_ids())
	groups.retain(field.all_ids())
	# 재배치는 화면도 처음 자리로 되돌린다. 유닛만 옮겨 놓고 화면이 딴 데 있으면 사라진 줄 안다.
	_camera.position = Vector2(340, _grid.field_size().y * 0.5)


## 방 바닥에 벽과 기둥을 놓는다. 흐름장과 대형 자리 배정이 장애물에서 어떻게 굴러가는지 봐야 한다.
##
## 완전히 빈 방에서는 뭉침 처리의 좋고 나쁨이 잘 드러나지 않는다. 문 하나짜리 벽을 두는 이유는
## 좁은 곳으로 여럿이 몰릴 때가 이동 손맛이 가장 크게 갈리는 상황이기 때문이다.
func _build_obstacles(seed_value: int) -> void:
	_grid.clear_blocked()
	for column in GRID_COLS:
		_grid.set_blocked(Vector2i(column, 0), true)
		_grid.set_blocked(Vector2i(column, GRID_ROWS - 1), true)
	for row in GRID_ROWS:
		_grid.set_blocked(Vector2i(0, row), true)
		_grid.set_blocked(Vector2i(GRID_COLS - 1, row), true)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_build_gate_wall(rng)
	for _i in 6:
		var width := rng.randi_range(2, 5)
		var height := rng.randi_range(2, 5)
		var left := rng.randi_range(16, GRID_COLS - 6)
		var top := rng.randi_range(3, GRID_ROWS - 6)
		_fill(left, top, width, height, true)
	_fill(2, 4, 12, GRID_ROWS - 8, false)


## 문이 하나 뚫린 세로 벽. 여럿이 한 줄로 통과해야 하는 상황을 만든다.
func _build_gate_wall(rng: RandomNumberGenerator) -> void:
	var wall_x := GRID_COLS / 2
	var gate := rng.randi_range(5, GRID_ROWS - 8)
	for row in range(1, GRID_ROWS - 1):
		var inside_gate := row >= gate and row < gate + 3
		_grid.set_blocked(Vector2i(wall_x, row), not inside_gate)


func _fill(left: int, top: int, width: int, height: int, blocked: bool) -> void:
	for y in height:
		for x in width:
			var cell := Vector2i(left + x, top + y)
			if cell.x <= 0 or cell.y <= 0 or cell.x >= GRID_COLS - 1 or cell.y >= GRID_ROWS - 1:
				continue
			_grid.set_blocked(cell, blocked)


# ----------------------------------------------------------------- 표시


func _stats_text() -> String:
	var lines := PackedStringArray()
	lines.append(
		(
			"유닛 %d  선택 %d  이동중 %d  fps %d"
			% [
				field.agents.size(),
				selection.size(),
				field.moving_count(),
				Engine.get_frames_per_second()
			]
		)
	)
	if not _debug.visible:
		lines.append("F1 개발 표시   Tab 조절판   H 도움말")
		return "\n".join(lines)
	lines.append(
		(
			"이동 계산 평균 %.2f ms  최악 %.2f ms  표본 %d"
			% [average_step_ms(), worst_step_ms(), _samples.size()]
		)
	)
	lines.append(
		(
			"명령 %d  장애물 시드 %d  바뀐 수치 %d  확대 %.2f"
			% [field.orders.size(), _obstacle_seed, tuning.changed_count(), _camera.zoom.x]
		)
	)
	# **전파와 재계산이 도는지 여기서 보인다.** 조절판에서 껐다 켜며 이 숫자를 견주면
	# 무엇이 일을 하고 있는지 눈으로 갈린다.
	(
		lines
		. append(
			(
				"전파 %d 회 (옮김 %d, 고리 %d)  길 다시 찾기 %d 회  흐름장 %.1f ms"
				% [
					field.propagate_runs,
					field.propagate_moves,
					field.propagate_cycles,
					field.rebake_count,
					float(field.flow_build_peak) / 1000.0,
				]
			)
		)
	)
	lines.append(_group_text())
	return "\n".join(lines)


func _group_text() -> String:
	var parts := PackedStringArray()
	for slot in ProtoControlGroups.SLOT_COUNT:
		if groups.has_members(slot):
			parts.append("%d 번 %d 명" % [slot, groups.size(slot)])
	if parts.is_empty():
		return "부대 없음 (Ctrl+숫자로 저장)"
	var text := "부대  " + "   ".join(parts)
	if _last_group_slot >= 0:
		text += "   마지막 %d 번" % _last_group_slot
	return text


func _help_text() -> String:
	return """조작
좌클릭 유닛 선택 / 빈 곳 클릭 선택 해제
좌드래그 상자 선택
Shift+좌클릭 선택에 더하기 빼기
Shift+드래그 선택에 더하기
더블클릭 화면 안의 같은 종류 전부
우클릭 이동 명령
Ctrl+숫자 부대 저장   숫자 부대 부르기   같은 숫자 두 번 그 부대로 화면 이동
Shift+숫자 부대에 더하기
Ctrl+A 전부 선택   X 정지   R 유닛 재배치   ESC 선택 해제
WASD 또는 방향키 화면 이동   휠 확대 축소   가운데 버튼 드래그 화면 끌기
F1 개발 표시   Tab 조절판   H 이 도움말"""
