class_name PressPlate
extends ColorRect
## **인쇄판 한 장.** 화면 맨 위에 늘 깔려 있고, 그 아래 그려진 모든 것을 다시 찍는다.
##
## 이것은 전환용 장막이 아니다. **꺼지지 않는다.** 화면에 그려진 모든 것이
## 이 판을 통과해서 점으로 다시 태어나므로, 이 노드가 곧 이 게임의 렌더링 모델이다
## (docs/design/18-visual-identity.md §18.5).
##
## 화면 위에 얇게 얹는 필터와 무엇이 다른가 — 필터는 색을 보정하고 이것은 **형태를 만든다.**
## 접힌 자리에서 그림이 어긋나고, 찢긴 자리에서 두 쪽이 벌어지고,
## 모든 계조가 점 크기로 뭉개진다. 부드러운 그라디언트가 화면에 존재할 수 없다.
##
## 쓰는 법 — 화면의 **맨 마지막 자식**으로 두고, 상태가 바뀐 직후에 부른다.
##
##     _plate.print_edition()        한 판이 넘어갔다. 지면이 점에서 자라난다
##     _plate.print_edition(true)    판을 새로 짰다. 찢고 다시 찍는다
##     _plate.strike_at(position)    누른 자리에서 파문이 퍼진다

## 인쇄가 어디까지 진행됐는가. 지면의 어느 부분이 이미 자리를 잡았는지 알린다.
signal front_moved(front: float)

const _PLATE_SHADER := preload("res://src/ui/style/shaders/ink_plate.gdshader")

var _material: ShaderMaterial
var _resolve: Tween
var _tear: Tween
var _shock: Tween


func _ready() -> void:
	color = Color(1.0, 1.0, 1.0, 1.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = _PLATE_SHADER
	_material.set_shader_parameter("paper_color", UiTokens.PAPER)
	_material.set_shader_parameter("ink_color", UiTokens.INK)
	_material.set_shader_parameter("spot_color", UiTokens.SPOT)
	_material.set_shader_parameter("pitch", UiTokens.SCREEN_PLATE)
	_material.set_shader_parameter("slip", UiTokens.SLIP)
	_material.set_shader_parameter("swell", 0.0)
	_material.set_shader_parameter("tear", 0.0)
	_material.set_shader_parameter("shock", Vector4.ZERO)
	material = _material


## 판이 흐르면 접힌 자리도 함께 흐른다. 지면은 화면이 아니라 책상 위의 종이다.
func follow_view(pan: Vector2, zoom: float) -> void:
	_material.set_shader_parameter("view_pan", pan)
	_material.set_shader_parameter("view_zoom", zoom)


## **새 판을 찍는다.**
##
## 지면이 굵은 점 덩어리에서 시작해 왼쪽부터 차례로 자리를 잡는다.
## 한꺼번에 나타나지 않는 것이 핵심이다 — 자리를 잡는 순서가 곧 박자가 되고,
## 방 타일들은 그 앞머리가 자기를 지나갈 때 각자 다시 찍힌다 (front_moved).
func print_edition(rip: bool = false) -> void:
	if _resolve != null and _resolve.is_valid():
		_resolve.kill()
	_material.set_shader_parameter("swell", 1.0)
	_resolve = create_tween()
	(
		_resolve
		# EASE_OUT + EXPO 를 쓰면 첫 5% 만에 다 풀려서 굵은 점이 눈에 보이지 않는다.
		# **뭉개진 상태를 잠깐 붙들고 있어야** 인쇄가 진행되는 것으로 읽힌다.
		. tween_method(_set_front, 1.0, 0.0, UiTokens.TIME_RESOLVE)
		. set_ease(Tween.EASE_IN_OUT)
		. set_trans(Tween.TRANS_CUBIC)
	)
	if rip:
		_rip()


## 지면을 찢었다가 다시 맞춘다. 벌어지는 것은 빠르고 맞물리는 것은 되튄다.
func _rip() -> void:
	if _tear != null and _tear.is_valid():
		_tear.kill()
	_tear = create_tween()
	(
		_tear
		. tween_method(_set_tear, 0.0, 1.0, UiTokens.TIME_TEAR * 0.35)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_QUINT)
	)
	_tear.tween_method(_set_tear, 1.0, 0.0, UiTokens.TIME_TEAR).set_ease(Tween.EASE_OUT).set_trans(
		Tween.TRANS_BACK
	)


## 누른 자리에서 파문이 퍼진다. **한 요소가 다른 요소를 뚫고 지나간 자국**이다.
func strike_at(where: Vector2) -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	var centre := where / size
	if _shock != null and _shock.is_valid():
		_shock.kill()
	_shock = create_tween()
	(
		_shock
		. tween_method(
			func(step: float) -> void: _set_shock(centre, step), 0.0, 1.0, UiTokens.TIME_SHOCK
		)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_CUBIC)
	)


func _set_front(value: float) -> void:
	_material.set_shader_parameter("swell", value)
	front_moved.emit(1.0 - value)


func _set_tear(value: float) -> void:
	_material.set_shader_parameter("tear", value)


func _set_shock(centre: Vector2, step: float) -> void:
	# 고리는 퍼지면서 약해진다. 끝까지 같은 세기면 화면이 계속 출렁인다.
	_material.set_shader_parameter(
		"shock", Vector4(centre.x, centre.y, step * 0.9, (1.0 - step) * (1.0 - step))
	)
