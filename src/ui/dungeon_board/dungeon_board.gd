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

const RoomNodeScene := preload("res://src/ui/dungeon_board/room_node.tscn")

const _EDGE_COLOR := Color(0.30, 0.33, 0.40)
const _EDGE_WIDTH := 3.0

var _run: DungeonRun
var _room_nodes: Dictionary = {}

@onready var _room_layer: Control = %RoomLayer
@onready var _room_label: Label = %RoomLabel
@onready var _threat_label: Label = %ThreatLabel
@onready var _squad_label: Label = %SquadLabel
@onready var _hint_label: Label = %HintLabel


## 판 하나를 이 화면에 붙인다.
func setup(run: DungeonRun) -> void:
	_run = run
	_build_room_nodes()
	_refresh()


func _draw() -> void:
	if _run == null:
		return
	# 방보다 먼저 그려져야 선이 방 아래로 깔린다. _room_layer 는 자식이라 나중에 그려진다.
	for pair in _run.blueprint.connections():
		var from_pos: Vector2 = _run.blueprint.position_of(pair[0])
		var to_pos: Vector2 = _run.blueprint.position_of(pair[1])
		draw_line(from_pos, to_pos, _EDGE_COLOR, _EDGE_WIDTH, true)


func _build_room_nodes() -> void:
	for child in _room_layer.get_children():
		child.queue_free()
	_room_nodes.clear()

	for id in _run.blueprint.room_ids():
		var node: RoomNode = RoomNodeScene.instantiate()
		_room_layer.add_child(node)
		# 설계도의 좌표는 방의 중심이다. 위젯은 좌상단 기준이라 절반만큼 당긴다.
		node.position = _run.blueprint.position_of(id) - node.custom_minimum_size * 0.5
		node.room_selected.connect(_on_room_selected)
		_room_nodes[id] = node
	queue_redraw()


func _refresh() -> void:
	var current_id := _run.player_room_id()
	var reachable := _run.reachable_room_ids()

	for id in _room_nodes:
		var node: RoomNode = _room_nodes[id]
		var state := RoomNode.State.DISTANT
		var value_text := "?"
		if id == current_id:
			state = RoomNode.State.CURRENT
			value_text = str(_run.adjacent_threat())
		elif reachable.has(id):
			state = RoomNode.State.REACHABLE
		node.display(id, _run.blueprint.display_name_of(id), value_text, state)

	_room_label.text = "현재 위치   %s" % _run.blueprint.display_name_of(current_id)
	_threat_label.text = "인접 위험도   %d" % _run.adjacent_threat()
	_squad_label.text = "스쿼드 전투력   %d" % _run.player.threat
	_hint_label.text = "밝은 방을 눌러 이동   ·   %d 턴" % _run.turn


func _on_room_selected(room_id: String) -> void:
	if not _run.can_move_to(room_id):
		return
	_run.move_player(room_id)
	_refresh()
