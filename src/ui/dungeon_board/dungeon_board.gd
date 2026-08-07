class_name DungeonBoard
extends Control
## 던전 판을 그리고 클릭을 받는 화면.
##
## 이 화면은 상태를 갖지 않는다. DungeonRun 을 읽어 그리고, 클릭을 DungeonRun 에 넘기고,
## 다시 읽어 그린다. 게임의 규칙은 전부 src/core/ 에 있다 (conventions.md §3.1).
##
## **무엇을 보여 줄지가 이 파일의 유일한 판단이다.**
## 플레이어가 선 방에는 인접 위험도 합을 띄우고, 나머지 방은 전부 "?" 로 둔다.
## 판 전체가 한눈에 들어와야 하므로 스크롤도 카메라 이동도 없다
## (docs/design/07-level-design.md §7.8).
##
## 방의 세로 위치는 **고도**다. 위쪽이 높은 곳이고, 그래서 플레이어는
## "위는 위협의 출처, 아래는 도주로"를 설명 없이 읽는다 (§7.2.6.2).

## 플레이어가 실제로 행동했다. 화면 밖의 것들(개발 패널 등)이 갱신할 신호다.
signal player_acted

const RoomNodeScene := preload("res://src/ui/dungeon_board/room_node.tscn")

const _EDGE_COLOR := Color(0.30, 0.33, 0.40)
const _EDGE_BLOCKED_COLOR := Color(0.46, 0.28, 0.30)
const _EDGE_WIDTH := 3.0

## 판을 그릴 영역. 좌상단은 HUD 를 피하고, 하단은 상태 표시줄을 피한다.
##
## 층 수가 늘면 세로 간격이 좁아져 방이 서로 겹친다.
## 방 위젯 높이(room_node.tscn)와 함께 봐야 하는 값이다.
const _BOARD_MARGIN := Rect2(200.0, 70.0, 1020.0, 560.0)

## 개발 패널이 열렸을 때의 영역. 패널이 판을 가리면 확인하려던 것을 못 본다.
const _BOARD_MARGIN_WITH_PANEL := Rect2(200.0, 70.0, 620.0, 560.0)

## 개발 모드에서는 숨김을 걷어낸다.
##
## 플레이 화면은 정보를 숨기는 것이 곧 재미라서(docs/design/13-information-design.md),
## 개발 중에 "생성기가 의도대로 모호함을 만들었는지"를 확인할 방법이 없다.
## 이 값이 켜지면 모든 방이 실제 위험도와 개체 수를 드러낸다.
var reveal_everything := false

var _run: DungeonRun
var _room_nodes: Dictionary = {}
var _positions: Dictionary = {}

@onready var _room_layer: Control = %RoomLayer
@onready var _room_label: Label = %RoomLabel
@onready var _threat_label: Label = %ThreatLabel
@onready var _squad_label: Label = %SquadLabel
@onready var _hint_label: Label = %HintLabel


## 판 하나를 이 화면에 붙인다.
func setup(run: DungeonRun) -> void:
	_run = run
	_build_room_nodes()
	redraw()


## 판을 다시 배치하고 다시 그린다. 개발 모드가 켜지고 꺼질 때도 쓰인다.
func redraw() -> void:
	if _run == null:
		return
	_positions = _run.blueprint.layout(
		_BOARD_MARGIN_WITH_PANEL if reveal_everything else _BOARD_MARGIN
	)
	for id in _room_nodes:
		var node: RoomNode = _room_nodes[id]
		node.position = _positions.get(id, Vector2.ZERO) - node.custom_minimum_size * 0.5
	_refresh()
	queue_redraw()


func _draw() -> void:
	if _run == null:
		return
	# 방보다 먼저 그려져야 선이 방 아래로 깔린다. _room_layer 는 자식이라 나중에 그려진다.
	var current_id := _run.player_room_id()
	for pair in _run.blueprint.connections():
		var from_pos: Vector2 = _positions.get(pair[0], Vector2.ZERO)
		var to_pos: Vector2 = _positions.get(pair[1], Vector2.ZERO)
		draw_line(from_pos, to_pos, _edge_color(current_id, pair), _EDGE_WIDTH, true)


## 지금 서 있는 방에서 오를 수 없는 간선은 다르게 칠한다.
##
## 고도차로 막힌 길을 "연결이 없는 것"처럼 보이게 하면 안 된다.
## 길은 있고 내가 못 오르는 것이며, 민첩이 오르면 열린다.
func _edge_color(current_id: String, pair: Array) -> Color:
	if current_id.is_empty():
		return _EDGE_COLOR
	var touches_current: bool = pair[0] == current_id or pair[1] == current_id
	if not touches_current:
		return _EDGE_COLOR
	var other: String = pair[1] if pair[0] == current_id else pair[0]
	if _run.graph.can_traverse(current_id, other, _run.player.agility):
		return _EDGE_COLOR
	return _EDGE_BLOCKED_COLOR


func _build_room_nodes() -> void:
	for child in _room_layer.get_children():
		child.queue_free()
	_room_nodes.clear()

	for id in _run.blueprint.room_ids():
		var node: RoomNode = RoomNodeScene.instantiate()
		_room_layer.add_child(node)
		node.room_selected.connect(_on_room_selected)
		_room_nodes[id] = node
	# 위치는 redraw() 가 잡는다. 개발 패널 여닫이에 따라 영역이 달라지기 때문이다.


func _refresh() -> void:
	var current_id := _run.player_room_id()
	var reachable := _run.reachable_room_ids()
	var blocked := _run.blocked_room_ids()

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
			id, _run.blueprint.display_name_of(id), value_text, state, _climb_text(current_id, id)
		)

	var elevation := _run.blueprint.elevation_of(current_id)
	_room_label.text = (
		"현재 위치   %s   (고도 %d)" % [_run.blueprint.display_name_of(current_id), elevation]
	)
	_threat_label.text = "인접 위험도   %d" % _run.adjacent_threat()
	_squad_label.text = ("전투력 %d   ·   민첩 %d" % [_run.player.threat, _run.player.agility])
	_hint_label.text = (
		"개발 모드 — 모든 방의 실제 값" if reveal_everything else "밝은 방을 눌러 이동   ·   %d 턴" % _run.turn
	)


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

	var difference := elevation - _run.blueprint.elevation_of(current_id)
	if difference > 0:
		return "▲ %d" % difference
	if difference < 0:
		return "▼ %d" % -difference
	return "평지"


func _on_room_selected(room_id: String) -> void:
	if not _run.can_move_to(room_id):
		return
	_run.move_player(room_id)
	redraw()
	player_acted.emit()
