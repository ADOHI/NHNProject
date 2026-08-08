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

## 전파가 방금 옆으로 밀어낸 유닛. **"비켜라"가 실제로 전해진 순간이 여기 보인다.**
const _PUSHED_COLOR := Color(1.00, 0.55, 0.15)

## 그 표시를 몇 프레임 남길지. 한 프레임만 그리면 눈에 안 걸린다.
##
## 24 프레임(0.4 초)이었는데 의뢰인이 못 봤다. 1.5 초로 늘렸다.
const _PUSHED_FRAMES := 90

## 사슬 선의 색. 노랑은 **진로를 막은 상대**, 하늘은 **내가 비켜설 자리를 막은 상대**다.
##
## 둘을 갈라 그리는 이유는 이 구분이 이번 고침의 핵심이기 때문이다. 진단에서 밝혔듯
## 그 둘은 다른 유닛이고, 예전에는 앞엣것만 알고 뒤엣것은 몰라서 시도의 54 퍼센트가
## 자리 없이 실패했다. 화면에서도 갈려 보여야 무엇이 일하는지 읽힌다.
const _CHAIN_COLOR := Color(1.00, 0.85, 0.25)
const _RELAY_COLOR := Color(0.35, 0.85, 1.00)

## 분홍은 **뒤로 물러나라**를 전한 상대. 옆이 막혔을 때만 나오는 색이라, 이 색이 많으면
## 그 자리가 옆으로는 못 비키는 곳이라는 뜻이다.
const _RECOIL_COLOR := Color(1.00, 0.45, 0.85)

## 길이 막혔다고 적혀 있어 비켜선 자리에서 **기다리는** 유닛. 되돌아가지 않는다는 표시다.
const _WAITING_COLOR := Color(0.55, 1.00, 0.55)
const _GOAL_COLOR := Color(0.60, 0.60, 0.68, 0.55)
const _SLOT_COLOR := Color(0.95, 0.55, 0.85, 0.85)
const _FLOW_COLOR := Color(0.35, 0.45, 0.60, 0.75)
const _TEXT_COLOR := Color(0.90, 0.92, 0.96)
const _BLOCKED_COLOR := Color(1.0, 0.35, 0.35)

## 앞이 막혀 기다리는 유닛. 막힘(빨강)과 달리 **비키면 스스로 다시 가는** 상태라 색을 가른다.
const _HOLDING_COLOR := Color(1.0, 0.78, 0.35)

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
	# **누가 누구에게 비켜라를 건넸는지 선으로 잇는다.** 고리만으로는 "나 때문에 저 유닛이
	# 비켰다"가 안 읽힌다. 선을 그리면 사슬이 앞으로 뻗는지 뒤로 뻗는지도 함께 보인다.
	if agent.chain_ago < _PUSHED_FRAMES and field != null:
		var target: ProtoUnitAgent = field.agent_of(agent.chain_to)
		if target != null:
			var line := _CHAIN_COLOR
			if agent.chain_kind == 1:
				line = _RELAY_COLOR
			elif agent.chain_kind == 2:
				line = _RECOIL_COLOR
			line.a = 1.0 - float(agent.chain_ago) / float(_PUSHED_FRAMES)
			draw_line(agent.position, target.position, line, 2.0)
			_draw_arrow(agent.position, target.position, line, 2.0)
	if agent.waiting_for_path:
		# 비켜선 자리에서 기다리는 중. **되돌아가지 않는다는 것이 여기서 보인다.**
		draw_arc(agent.position, agent.radius + 3.0, 0.0, TAU, 20, _WAITING_COLOR, 2.5)
	if agent.pushed_ago < _PUSHED_FRAMES:
		var fade := 1.0 - float(agent.pushed_ago) / float(_PUSHED_FRAMES)
		var ring := _PUSHED_COLOR
		ring.a = fade
		draw_arc(agent.position, agent.radius + 4.0 + fade * 6.0, 0.0, TAU, 20, ring, 2.0)
	if agent.state == ProtoUnitAgent.State.BLOCKED:
		draw_arc(agent.position, agent.radius + 8.0, 0.0, TAU, 16, _BLOCKED_COLOR, 1.5)
	elif agent.state == ProtoUnitAgent.State.HOLDING:
		draw_arc(agent.position, agent.radius + 8.0, 0.0, TAU, 16, _HOLDING_COLOR, 1.5)
	if agent.is_moving() or agent.state == ProtoUnitAgent.State.HOLDING:
		draw_line(agent.position, agent.goal, _GOAL_COLOR, 1.0)
	if show_forces and agent.is_moving():
		# 노랑은 **가려던 것**, 파랑은 **실제로 간 것**이다. 둘의 차이가 앞이 막힌 몫이고,
		# 이웃이 미는 힘이 없어진 지금 화살표 둘을 나란히 놓아야 볼 것이 남는다.
		_draw_arrow(
			agent.position, agent.position + agent.debug_seek * _FORCE_SCALE, _SEEK_COLOR, 1.5
		)
		var moved_end := agent.position + agent.velocity * _FORCE_SCALE
		_draw_arrow(agent.position, moved_end, _SEPARATION_COLOR, 1.5)
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
