class_name DungeonBoard
extends Control
## 던전 판을 그리고 클릭을 받는 화면.
##
## 이 화면은 상태를 갖지 않는다. DungeonRun 을 읽어 그리고, 클릭을 DungeonRun 에 넘기고,
## 다시 읽어 그린다. 게임의 규칙은 전부 src/core/ 에 있다 (conventions.md §3.1).
##
## **무엇을 보여 줄지가 이 파일의 유일한 판단이다.**
## 플레이어가 선 방에는 인접 위험도 합을 띄우고, 나머지 방은 전부 "?" 로 둔다.
##
## 판은 한 화면에 다 들어오지 않아도 된다. **빈 곳을 끌어서 움직여 본다.**
## 지도가 화면에 맞춰 줄어들면 방이 뭉개져 오히려 읽기 어려워진다.

## 플레이어가 실제로 행동했다. 화면 밖의 것들(개발 패널 등)이 갱신할 신호다.
signal player_acted

## 어느 자리를 눌렀는가. 인쇄판이 그 자리에서 파문을 퍼뜨린다 —
## **조작이 지면에 자국을 남긴다**는 것이 이 화면의 반응 규칙이다.
signal struck(at: Vector2)

## 지도의 위치와 배율이 바뀌었다. 지면(종이와 단 괘선)이 같은 좌표를 따라가야 한다.
##
## 배경이 가만히 있으면 판을 끌어도 "지도를 움직인다"는 감각이 없다.
## 지면이 함께 흘러야 **큰 신문지를 책상 위에서 미는 것**이 된다.
signal view_changed(pan: Vector2, zoom: float)

## 통로의 상태. **그리는 방식이 여기서 갈린다.**
enum Link {
	LIVE,  ## 지금 방에서 실제로 지나갈 수 있는 길
	BLOCKED,  ## 길은 있으나 고도가 막는다
	DARK,  ## 지금 내 판단과 무관한 길
}

const RoomNodeScene := preload("res://src/ui/dungeon_board/room_node.tscn")

## 방 사이의 목표 간격.
##
## 방 위젯보다 넉넉해야 이름이 겹쳐 보이지 않고, 지도가 화면보다 커야
## 훑어볼 여지가 생긴다. 좁히면 판이 한 화면에 들어와 이동이 무의미해진다.
const _SPACING := 280.0

## 화면 가장자리에서 카메라가 따라 움직이기 시작하는 폭과 그 속도.
const _EDGE_MARGIN := 56.0
const _EDGE_SPEED := 900.0

## 지도 바깥으로 둘 여백의 최솟값. 실제로는 화면 절반과 비교해 큰 쪽을 쓴다.
##
## 화면 절반만큼 두는 이유는 **가장자리 방도 화면 가운데에 놓고 볼 수 있어야** 하기 때문이다.
## 이보다 좁으면 지도 끝의 방은 아무리 끌어도 화면 구석에 붙어 있다.
const _WORLD_PADDING_MIN := 200.0

## 확대 배율의 범위와 한 칸의 크기.
const _ZOOM_MIN := 0.4
const _ZOOM_MAX := 1.8
const _ZOOM_STEP := 1.12

## 이 배율보다 작아지면 글자가 뭉개진다. 읽히지 않을 글자는 지운다.
const _DETAIL_NAME_ZOOM := 0.62
const _DETAIL_FULL_ZOOM := 0.92

## 개발 모드에서는 숨김을 걷어낸다.
##
## 플레이 화면은 정보를 숨기는 것이 곧 재미라서(docs/design/13-information-design.md),
## 개발 중에 "생성기가 의도대로 모호함을 만들었는지"를 확인할 방법이 없다.
## 이 값이 켜지면 모든 방이 실제 위험도와 개체 수를 드러낸다.
var reveal_everything := false

var _run: DungeonRun
var _room_nodes: Dictionary = {}
var _positions: Dictionary = {}
var _pan := Vector2.ZERO
var _zoom := 1.0
var _dragging := false

## 커서가 실제로 움직인 적이 있는가.
##
## 이걸 보지 않으면, 창이 열리자마자 커서가 우연히 가장자리에 있다는 이유로
## 카메라가 저 혼자 흘러간다. 사용자가 지도를 만지기 전에는 가만히 있어야 한다.
var _pointer_moved := false

## 직전에 보여 준 인접 위험도 합. 변화량을 화면이 대신 기억하기 위한 값이다.
## 음수는 "아직 보여 준 적 없음"이다.
var _last_threat := -1

@onready var _room_layer: Control = %RoomLayer
@onready var _room_label: Label = %RoomLabel
@onready var _elevation_label: Label = %ElevationLabel
@onready var _threat_label: PlateLabel = %ThreatLabel
@onready var _threat_delta_label: Label = %ThreatDeltaLabel
@onready var _squad_label: Label = %SquadLabel
@onready var _hint_label: Label = %HintLabel
@onready var _turn_label: PlateLabel = %TurnLabel


## 판 하나를 이 화면에 붙인다.
func setup(run: DungeonRun, layout_seed: int) -> void:
	_run = run
	_last_threat = -1
	_threat_delta_label.text = ""
	_positions = run.blueprint.layout(layout_seed, _SPACING)
	_build_room_nodes()
	redraw()
	# 화면 크기는 배치가 끝난 뒤에야 확정된다. 그 전에 가운데를 잡으면 빗나간다.
	center_on_player.call_deferred()


## 판을 통째로 다시 그린다. 상태가 바뀐 뒤에 쓴다.
func redraw() -> void:
	if _run == null:
		return
	_reposition()
	_refresh()


## 지금 몇 번째 판인가. 제호에 찍을 값이라 화면 밖에서도 필요하다.
func turn_number() -> int:
	return 0 if _run == null else _run.turn


## 지면을 새로 찍는다. 판이 통째로 바뀌었을 때 상위가 부른다.
##
## **칸들이 한꺼번에 튀지 않는다.** 인쇄기의 앞머리는 왼쪽부터 지나가므로,
## 각 칸은 자기 자리가 화면에서 얼마나 왼쪽인가에 따라 늦게 찍힌다.
## 그 시차가 곧 박자이고, 박자가 있어야 전환이 사건으로 읽힌다.
func reprint() -> void:
	_threat_label.reprint()
	for id in _room_nodes:
		var node: RoomNode = _room_nodes[id]
		var lag := UiTokens.TIME_STAGGER * clampf(node.position.x / maxf(size.x, 1.0), 0.0, 1.0)
		get_tree().create_timer(lag).timeout.connect(node.reprint)
	# 턴 표시는 맨 마지막에 찍힌다. 판 번호는 판을 다 짜고 나서 붙이는 것이다.
	get_tree().create_timer(UiTokens.TIME_STAGGER).timeout.connect(_turn_label.reprint)


## 방 위젯의 자리와 크기만 다시 잡는다.
##
## 이동•확대는 **보이는 내용이 아니라 위치만** 바꾼다.
## 그때마다 라벨을 전부 새로 쓰면 끌 때마다 글자 배치가 다시 계산되어 버벅인다.
func _reposition() -> void:
	if _run == null:
		return
	for id in _room_nodes:
		var node: RoomNode = _room_nodes[id]
		node.scale = Vector2(_zoom, _zoom)
		node.position = _map_to_screen(id) - node.custom_minimum_size * 0.5 * _zoom
	queue_redraw()
	view_changed.emit(_pan, _zoom)


## 스쿼드가 있는 방이 화면 가운데 오도록 지도를 옮긴다.
func center_on_player() -> void:
	if _run == null:
		return
	_zoom = 1.0
	var current: Vector2 = _positions.get(_run.player_room_id(), Vector2.ZERO)
	_pan = size * 0.5 - current * _zoom
	_clamp_pan()
	redraw()


func _gui_input(event: InputEvent) -> void:
	# 방 위젯은 Button 이라 자기 클릭을 먼저 가져간다.
	# 여기까지 온 입력은 빈 곳에서 일어난 것이므로 지도 조작으로 해석한다.
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_pointer_moved = true
		if _dragging:
			_pan += (event as InputEventMouseMotion).relative
			_clamp_pan()
			_reposition()


## 커서가 화면 가장자리에 가면 카메라가 그쪽으로 따라 움직인다.
##
## 끌지 않고도 지도를 훑을 수 있어야 한다. 지도가 화면보다 큰 판에서
## 매번 끌어다 놓는 것은 번거롭다.
func _process(delta: float) -> void:
	if _run == null or _dragging or not _pointer_moved or not is_visible_in_tree():
		return
	# 창이 활성 상태가 아니면 멈춘다. 다른 창을 보는 동안 지도가 계속 흘러가면 안 된다.
	if not get_window().has_focus() or _pointer_blocked_by_ui():
		return
	var push := _edge_push(_pointer_position())
	if push == Vector2.ZERO:
		return
	_pan += push * _EDGE_SPEED * delta
	_clamp_pan()
	_reposition()


## 커서 위치. **창 밖으로 나가도 이어서 읽는다.**
##
## get_local_mouse_position() 은 창 안에서 들어온 입력만 반영하므로
## 커서가 창을 벗어나면 경계에서 멈춰 버린다. 그러면 스크롤도 함께 멈춘다.
## OS 가 아는 커서 위치를 직접 읽어 창 좌표로 옮긴다.
##
## 웹에서는 브라우저가 캔버스 밖 커서를 알려 주지 않으므로
## 창 경계까지만 동작한다.
func _pointer_position() -> Vector2:
	var cursor := Vector2(DisplayServer.mouse_get_position() - DisplayServer.window_get_position())
	return get_viewport().get_screen_transform().affine_inverse() * cursor - global_position


## 커서가 UI 위에 있는가. HUD•조작 패널 위에서는 카메라가 움직이면 안 된다.
##
## 화면 구석의 정보를 읽으려고 커서를 올렸을 뿐인데 지도가 흘러가면 읽던 곳을 놓친다.
## 창 밖에 있을 때는 가리키는 것이 없으므로(null) 막지 않는다.
func _pointer_blocked_by_ui() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered != null and hovered != self and not hovered is RoomNode


## 커서 위치가 만드는 카메라 이동 방향. 가장자리에 가까울수록 세고,
## 창 밖으로 나가면 최대 속도로 유지된다.
func _edge_push(mouse: Vector2) -> Vector2:
	return Vector2(_axis_push(mouse.x, size.x), _axis_push(mouse.y, size.y))


func _axis_push(value: float, extent: float) -> float:
	if value < _EDGE_MARGIN:
		return minf((_EDGE_MARGIN - value) / _EDGE_MARGIN, 1.0)
	if value > extent - _EDGE_MARGIN:
		return -minf((value - extent + _EDGE_MARGIN) / _EDGE_MARGIN, 1.0)
	return 0.0


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_apply_zoom(_zoom * _ZOOM_STEP, event.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_apply_zoom(_zoom / _ZOOM_STEP, event.position)


## 커서 아래 지점을 붙잡은 채 배율을 바꾼다.
##
## 화면 중심을 기준으로 확대하면 보고 있던 곳이 밀려나 매번 다시 찾아야 한다.
## 커서가 가리키는 방은 그 자리에 그대로 있어야 한다.
func _apply_zoom(target: float, anchor: Vector2) -> void:
	var next := clampf(target, _ZOOM_MIN, _ZOOM_MAX)
	if is_equal_approx(next, _zoom):
		return
	var previous_detail := _detail_level()
	var map_point := (anchor - _pan) / _zoom
	_zoom = next
	_pan = anchor - map_point * _zoom
	_clamp_pan()
	_reposition()
	# 배율이 정보량 경계를 넘었을 때만 라벨을 다시 쓴다.
	if _detail_level() != previous_detail:
		_refresh()
	else:
		_update_hint()


## 카메라를 **세계 범위** 안에 가둔다.
##
## 세계 = 지도 전체 크기 + 사방 패딩.
## 화면은 이 안에서만 움직인다. 나가면 아무것도 없는 곳을 하염없이 보게 된다.
##
## 패딩이 있어야 가장자리 방을 화면 구석이 아니라 **가운데에 놓고 볼 수 있다.**
## 패딩 없이 지도 경계로만 막으면 끝의 방은 늘 화면 모서리에 붙어 보인다.
func _clamp_pan() -> void:
	var world := _world_rect()
	if world.size == Vector2.ZERO:
		return
	_pan.x = _clamp_axis(_pan.x, world.position.x, world.end.x, size.x)
	_pan.y = _clamp_axis(_pan.y, world.position.y, world.end.y, size.y)


## 카메라가 돌아다닐 수 있는 세계. 화면 좌표계에서 잰다(= 배율이 적용된 크기).
func _world_rect() -> Rect2:
	if _positions.is_empty():
		return Rect2()
	var lowest := Vector2.INF
	var highest := -Vector2.INF
	for position in _positions.values():
		lowest = lowest.min(position as Vector2 * _zoom)
		highest = highest.max(position as Vector2 * _zoom)
	# 방 위젯은 좌표를 중심으로 그려지므로 그 절반만큼 더 뻗고,
	# 거기에 화면 절반만큼의 여백을 더 둔다.
	var padding := (size * 0.5).max(Vector2(_WORLD_PADDING_MIN, _WORLD_PADDING_MIN))
	var extent := _node_extent() + padding
	return Rect2(lowest - extent, highest - lowest + extent * 2.0)


func _clamp_axis(value: float, world_low: float, world_high: float, view: float) -> float:
	# 화면의 양 끝이 세계 안에 들어오는 이동량의 범위.
	# 세계가 화면보다 작으면 둘이 뒤집히는데, 그때는 세계가 화면 안에 들어오면 된다.
	var a := view - world_high
	var b := -world_low
	return clampf(value, minf(a, b), maxf(a, b))


## 방 위젯이 좌표 바깥으로 뻗는 크기.
func _node_extent() -> Vector2:
	if _room_nodes.is_empty():
		return Vector2.ZERO
	var node: RoomNode = _room_nodes.values()[0]
	return node.custom_minimum_size * 0.5 * _zoom


func _map_to_screen(room_id: String) -> Vector2:
	return (_positions.get(room_id, Vector2.ZERO) as Vector2) * _zoom + _pan


## 지금 배율에서 방이 얼마나 자세히 보여야 하는가.
func _detail_level() -> RoomNode.Detail:
	if _zoom < _DETAIL_NAME_ZOOM:
		return RoomNode.Detail.MINIMAL
	if _zoom < _DETAIL_FULL_ZOOM:
		return RoomNode.Detail.NORMAL
	return RoomNode.Detail.FULL


## 통로를 그린다.
##
## **통로는 이어진 선이 아니라 점선이다.** 근거는 세계관에 있다 —
## 던전은 방송용 시설이고, **통로는 중계 구역이 아니다.**
## 카메라가 없는 곳이라 지면에 실을 그림이 없고, 그래서 끊긴 자국으로 남는다
## (docs/design/02-overview.md §2.6.1).
##
## 지금 내가 실제로 지나갈 수 있는 길만 **괘선 다발**로 굵게 찍힌다.
## 그 순간 판 위에서 **내 선택지가 저절로 도드라진다** — 따로 표시를 붙일 필요가 없다.
## 신문에서 굵은 선 밑에 가는 선이 한 줄 더 붙는 것과 같은 문법이다.
func _draw() -> void:
	if _run == null:
		return
	# 방보다 먼저 그려져야 선이 방 아래로 깔린다. _room_layer 는 자식이라 나중에 그려진다.
	var current_id := _run.player_room_id()
	var dash := UiTokens.DASH_LENGTH * _zoom
	var gap := UiTokens.DASH_GAP * _zoom
	for pair in _run.blueprint.connections():
		var from_pos := _map_to_screen(pair[0])
		var to_pos := _map_to_screen(pair[1])
		var link := _edge_link(current_id, pair)
		if link == Link.LIVE:
			_draw_rule_pair(from_pos, to_pos)
			continue
		var blocked := link == Link.BLOCKED
		var color := UiTokens.MARK_DEEP if blocked else UiTokens.fade(UiTokens.INK_FAINT, 0.75)
		var width := maxf(1.0, (UiTokens.RULE_TEXT if blocked else UiTokens.RULE_HAIR) * _zoom)
		var length := (UiTokens.DASH_LENGTH * 2.0 * _zoom) if blocked else dash
		for segment in UiShape.dash_segments(from_pos, to_pos, length, gap):
			draw_line(segment[0], segment[1], color, width, true)


## 살아 있는 통로 한 줄. 굵은 괘선과 그 옆의 가는 괘선.
func _draw_rule_pair(from_pos: Vector2, to_pos: Vector2) -> void:
	var heavy := maxf(1.5, UiTokens.RULE_HEAVY * _zoom)
	var hair := maxf(1.0, UiTokens.RULE_HAIR * _zoom)
	var offset := (to_pos - from_pos).orthogonal().normalized() * (heavy * 0.5 + hair * 2.0)
	draw_line(from_pos, to_pos, UiTokens.INK, heavy, true)
	draw_line(from_pos + offset, to_pos + offset, UiTokens.fade(UiTokens.INK, 0.55), hair, true)


## 지금 서 있는 방에서 오를 수 없는 간선은 다르게 그린다.
##
## 고도차로 막힌 길을 "연결이 없는 것"처럼 보이게 하면 안 된다.
## 길은 있고 내가 못 오르는 것이며, 민첩이 오르면 열린다.
func _edge_link(current_id: String, pair: Array) -> Link:
	if current_id.is_empty():
		return Link.DARK
	var touches_current: bool = pair[0] == current_id or pair[1] == current_id
	if not touches_current:
		return Link.DARK
	var other: String = pair[1] if pair[0] == current_id else pair[0]
	if _run.graph.can_traverse(current_id, other, _run.player.agility):
		return Link.LIVE
	return Link.BLOCKED


func _build_room_nodes() -> void:
	for child in _room_layer.get_children():
		child.queue_free()
	_room_nodes.clear()

	for id in _run.blueprint.room_ids():
		var node: RoomNode = RoomNodeScene.instantiate()
		_room_layer.add_child(node)
		node.room_selected.connect(_on_room_selected)
		_room_nodes[id] = node
	# 위치는 redraw() 가 잡는다. 지도를 끌면 매번 다시 잡아야 하기 때문이다.


func _refresh() -> void:
	var current_id := _run.player_room_id()
	var reachable := _run.reachable_room_ids()
	var blocked := _run.blocked_room_ids()
	var detail := _detail_level()

	for id in _room_nodes:
		var node: RoomNode = _room_nodes[id]
		var state := RoomNode.State.DISTANT
		var value_text := "?"
		if id == current_id:
			state = RoomNode.State.CURRENT
			value_text = str(_run.adjacent_threat())
		elif reachable.has(id):
			state = RoomNode.State.REACHABLE
		elif blocked.has(id):
			state = RoomNode.State.BLOCKED
		if reveal_everything and id != current_id:
			# 합이 아니라 그 방 하나의 실제 값. 괄호 안은 개체 수다.
			var room := _run.graph.get_room(id)
			value_text = "%d (%d)" % [room.threat(), room.occupant_count()]
		node.display(
			id,
			_run.blueprint.display_name_of(id),
			value_text,
			state,
			_climb_text(current_id, id),
			detail
		)

	_room_label.text = _run.blueprint.display_name_of(current_id)
	_elevation_label.text = "고도 %d" % _run.blueprint.elevation_of(current_id)
	_squad_label.text = "전투력 %d      민첩 %d" % [_run.player.threat, _run.player.agility]
	# 턴은 방송 진행 단위다(docs/design/02-overview.md §2.6.1). 그래서 별색판 쪽에 붙인다.
	_turn_label.set_text("제 %d 판" % _run.turn)
	_update_threat()
	_update_hint()


## 인접 위험도 합과 그 변화량.
##
## **이 화면에서 가장 큰 글자는 이 숫자여야 한다.** 매 턴 "더 갈까 나갈까"를 묻는 게임에서
## 그 판단의 근거가 화면 어딘가에 작게 적혀 있으면 안 된다 (docs/design/08-ui-ux.md §8.5).
##
## 변화량을 함께 띄우는 이유는 플레이어에게 이전 값을 외우게 하지 않기 위해서다
## (docs/design/13-information-design.md §13.7).
func _update_threat() -> void:
	var threat := _run.adjacent_threat()
	# PlateLabel 이 값이 바뀐 것을 알아채고 별색판을 튀긴다. 서명은 여기서 가장 크게 보인다.
	_threat_label.set_text(str(threat))
	if _last_threat >= 0 and threat != _last_threat:
		var difference := threat - _last_threat
		_threat_delta_label.text = ("+%d" % difference) if difference > 0 else str(difference)
		_threat_delta_label.add_theme_color_override("font_color", UiTokens.SPOT)
		UiMotion.rise_and_fade(_threat_delta_label, UiTokens.SPACE_SNUG)
	_last_threat = threat


func _update_hint() -> void:
	if reveal_everything:
		_hint_label.text = "교정쇄 — 모든 방의 실제 값이 드러나 있다"
		return
	_hint_label.text = "끌거나 가장자리로 이동      휠 확대 %d%%" % int(round(_zoom * 100.0))


## 방에 붙일 고도 표시.
##
## **인접한 방은 지금 방 기준의 상대 고도**를 보여 준다. 실제로 필요한 것은
## "저기까지 얼마나 올라야 하나"이지 절대 고도가 아니기 때문이다.
## 인접하지 않은 방은 절대 고도를 보여 준다 — 판 전체의 지형을 읽고
## 경로를 계획할 수 있어야 한다.
##
## 고도는 숨기는 정보가 아니다. 숨기는 것은 방 안의 내용물뿐이다.
func _climb_text(current_id: String, room_id: String) -> String:
	var elevation := _run.blueprint.elevation_of(room_id)
	if current_id.is_empty() or current_id == room_id:
		return ""
	if not _run.graph.are_connected(current_id, room_id):
		return "고도 %d" % elevation

	# 화살표(▲▼)를 쓰지 않는 이유는 폰트에 그 글리프가 없기 때문이다.
	# 데스크톱에서는 시스템 폰트로 대체되어 멀쩡해 보이지만 웹에서는 두부가 된다
	# (tools/check_glyphs.gd 로 확인할 수 있다).
	var difference := elevation - _run.blueprint.elevation_of(current_id)
	if difference > 0:
		return "오름 %d" % difference
	if difference < 0:
		return "내림 %d" % -difference
	return "평지"


func _on_room_selected(room_id: String) -> void:
	if not _run.can_move_to(room_id):
		return
	var node: RoomNode = _room_nodes.get(room_id)
	if node != null:
		struck.emit(node.global_position + node.size * 0.5 * _zoom)
	_run.move_player(room_id)
	redraw()
	player_acted.emit()
