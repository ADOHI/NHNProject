class_name ProtoFieldView
extends Node2D
## 유닛과 선택 · 명령 표시를 도형으로 그린다. **이동 로직은 여기에 한 줄도 없다.**
##
## 바닥과 벽은 ProtoTerrainView 가 따로 그린다. 매 프레임 바뀌는 것과 거의 안 바뀌는 것을
## 같은 노드에 두면 안 바뀌는 쪽까지 매 프레임 다시 그리게 된다.
##
## 시점과 화풍은 이번 관심사가 아니다. 나중에 배경과 스프라이트가 들어오면
## 이 파일만 갈아 끼우면 되도록, 상태를 읽기만 하고 바꾸지 않는다.

## 종류별 색. ProtoUnitAgent.KIND_NAMES 와 순서가 같다.
const KIND_COLORS: Array[Color] = [
	Color(0.42, 0.62, 0.92),
	Color(0.86, 0.55, 0.35),
	Color(0.45, 0.80, 0.55),
]

const _SELECT_COLOR := Color(0.45, 0.95, 0.55)
const _MARKER_COLOR := Color(0.55, 0.95, 0.65)
const _BOX_FILL := Color(0.45, 0.95, 0.55, 0.10)

## 명령 지점 표시가 남아 있는 시간(초).
const _MARKER_LIFE := 0.9

var field: ProtoUnitField
var selection: ProtoUnitSelection

## 드래그 박스. 비어 있으면 그리지 않는다.
var drag_rect := Rect2()
var drag_active := false


func bind(unit_field: ProtoUnitField, unit_selection: ProtoUnitSelection) -> void:
	field = unit_field
	selection = unit_selection
	queue_redraw()


func _draw() -> void:
	if field == null:
		return
	_draw_markers()
	_draw_units()
	if drag_active:
		var box := drag_rect.abs()
		draw_rect(box, _BOX_FILL, true)
		draw_rect(box, _SELECT_COLOR, false, 1.5)


## 명령 지점 표시. 눌린 곳이 어디였는지 보여야 명령이 들어갔는지 알 수 있다.
func _draw_markers() -> void:
	for order in field.orders:
		if order.age > _MARKER_LIFE:
			continue
		var progress := order.age / _MARKER_LIFE
		var alpha := 1.0 - progress
		var color := Color(_MARKER_COLOR.r, _MARKER_COLOR.g, _MARKER_COLOR.b, alpha)
		draw_arc(order.target, 6.0 + progress * 22.0, 0.0, TAU, 24, color, 2.0)
		draw_line(order.target + Vector2(-5, 0), order.target + Vector2(5, 0), color, 2.0)
		draw_line(order.target + Vector2(0, -5), order.target + Vector2(0, 5), color, 2.0)


func _draw_units() -> void:
	for agent in field.agents:
		var color: Color = KIND_COLORS[agent.kind]
		if selection != null and selection.has(agent.id):
			draw_arc(agent.position, agent.radius + 4.0, 0.0, TAU, 20, _SELECT_COLOR, 2.0)
		draw_circle(agent.position, agent.radius, color)
		draw_circle(agent.position, agent.radius, color.darkened(0.45), false, 1.5)
		_draw_facing(agent)


## 바라보는 방향을 삼각형으로 그린다. 글리프 화살표는 폰트에 없어서 웹에서 두부가 된다.
func _draw_facing(agent: ProtoUnitAgent) -> void:
	var forward := Vector2.from_angle(agent.facing)
	var side := Vector2(-forward.y, forward.x)
	var tip := agent.position + forward * (agent.radius + 4.0)
	var base := agent.position + forward * (agent.radius - 2.0)
	var points := PackedVector2Array(
		[tip, base + side * agent.radius * 0.45, base - side * agent.radius * 0.45]
	)
	draw_colored_polygon(points, KIND_COLORS[agent.kind].lightened(0.35))
