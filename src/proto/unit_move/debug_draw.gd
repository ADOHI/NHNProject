class_name ProtoDebugDraw
extends Node2D
## 개발 표시. 유닛이 **왜 저렇게 움직이는지**를 화면에 드러낸다.
##
## `CLAUDE.md` §8 의 원칙 그대로다. 화면에 드러나지 않는 상태는 디버깅할 수 없고,
## 디버깅할 수 없는 상태는 반드시 틀린다. 이동은 특히 그렇다 — 유닛이 이상하게 도는 것을
## 보고도 그것이 흐름장 탓인지 분리력 탓인지 대형 속도 탓인지 눈으로는 구분할 수 없다.
##
## 켜고 끄기는 F1(InputMap 액션 toggle_debug) 또는 조절판의 버튼이다.

const _FONT_PATH := "res://assets/fonts/song_myung/SongMyung-Regular.ttf"

const _SEEK_COLOR := Color(0.95, 0.85, 0.35)
const _SEPARATION_COLOR := Color(0.45, 0.70, 1.00)
const _GOAL_COLOR := Color(0.60, 0.60, 0.68, 0.55)
const _SLOT_COLOR := Color(0.95, 0.55, 0.85, 0.85)
const _FLOW_COLOR := Color(0.35, 0.45, 0.60, 0.75)
const _TEXT_COLOR := Color(0.90, 0.92, 0.96)
const _BLOCKED_COLOR := Color(1.0, 0.35, 0.35)

## 힘 벡터를 화면 길이로 바꿀 때의 배수. 속도 단위 그대로 그리면 화면을 덮는다.
const _FORCE_SCALE := 0.12

## 선택이 이보다 많으면 유닛별 글자를 붙이지 않는다.
##
## 여든 명을 고른 채로 전부 붙이면 글자가 서로 겹쳐 아무것도 읽을 수 없고,
## 정작 보려던 움직임까지 글자에 덮인다. 그릴 수 있다고 다 그리면 안 보이는 것과 같다.
const _TEXT_LIMIT := 12

var field: ProtoUnitField
var selection: ProtoUnitSelection

## 흐름장 화살표는 칸마다 그리면 너무 빽빽하다. 이 간격마다 하나씩 뽑는다.
var flow_stride := 3

var show_flow := true
var show_forces := true
var show_slots := true

var _font: Font = load(_FONT_PATH)


func bind(unit_field: ProtoUnitField, unit_selection: ProtoUnitSelection) -> void:
	field = unit_field
	selection = unit_selection
	queue_redraw()


func _draw() -> void:
	if field == null or not visible:
		return
	if show_flow:
		_draw_flow()
	if show_slots:
		_draw_slots()
	for agent in field.agents:
		_draw_agent(agent)


## 가장 최근 명령의 흐름장. 유닛이 장애물을 어떻게 돌아가기로 했는지가 여기 다 있다.
func _draw_flow() -> void:
	if field.orders.is_empty():
		return
	var order: ProtoUnitField.MoveOrder = field.orders[field.orders.size() - 1]
	var grid := field.grid
	var length := grid.cell_size * 0.42
	for row in range(0, grid.rows, flow_stride):
		for column in range(0, grid.cols, flow_stride):
			var cell := Vector2i(column, row)
			if not grid.is_walkable(cell):
				continue
			var direction := order.flow.dirs[grid.cell_index(cell)]
			if direction == Vector2.ZERO:
				continue
			var center := grid.cell_to_world(cell)
			_draw_arrow(center - direction * length, center + direction * length, _FLOW_COLOR, 1.0)


## 대형 자리. 유닛이 한 점이 아니라 각자 다른 목표로 간다는 것이 여기서 보인다.
func _draw_slots() -> void:
	for order in field.orders:
		for slot in order.slots:
			draw_line(slot + Vector2(-4, -4), slot + Vector2(4, 4), _SLOT_COLOR, 1.0)
			draw_line(slot + Vector2(-4, 4), slot + Vector2(4, -4), _SLOT_COLOR, 1.0)


func _draw_agent(agent: ProtoUnitAgent) -> void:
	if agent.state == ProtoUnitAgent.State.BLOCKED:
		draw_arc(agent.position, agent.radius + 8.0, 0.0, TAU, 16, _BLOCKED_COLOR, 1.5)
	if agent.is_moving():
		draw_line(agent.position, agent.goal, _GOAL_COLOR, 1.0)
	if show_forces and agent.is_moving():
		var seek_end := agent.position + agent.debug_seek * _FORCE_SCALE
		_draw_arrow(agent.position, seek_end, _SEEK_COLOR, 1.5)
		var separation_end := agent.position + agent.debug_separation * _FORCE_SCALE
		_draw_arrow(agent.position, separation_end, _SEPARATION_COLOR, 1.5)
	if selection != null and selection.size() <= _TEXT_LIMIT and selection.has(agent.id):
		_draw_agent_text(agent)


## 선택된 유닛만 글자를 붙인다. 전부 붙이면 화면이 글자로 덮여 정작 움직임이 안 보인다.
func _draw_agent_text(agent: ProtoUnitAgent) -> void:
	var text := (
		"%d %s %s %.0f" % [agent.id, agent.kind_name(), agent.state_name(), agent.velocity.length()]
	)
	if agent.is_moving():
		text += " 남은 %.0f 배수 %.2f" % [agent.remaining(), agent.pace]
	draw_string(
		_font,
		agent.position + Vector2(agent.radius + 6.0, -agent.radius - 2.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		_TEXT_COLOR
	)


## 선 하나와 머리 두 개로 화살표를 그린다. 화살표 글리프는 폰트에 없다.
func _draw_arrow(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var delta := to - from
	if delta.length_squared() < 4.0:
		return
	draw_line(from, to, color, width)
	var direction := delta.normalized()
	var head := minf(6.0, delta.length() * 0.4)
	draw_line(to, to - direction.rotated(0.5) * head, color, width)
	draw_line(to, to - direction.rotated(-0.5) * head, color, width)
