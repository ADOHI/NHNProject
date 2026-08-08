class_name KitField
extends ColorRect
## 화면 전체를 덮는 **하나의 지형**. UI 의 모든 픽셀이 여기서 나온다.
##
## 버튼과 팝업은 자기 배경을 그리지 않는다. 자기 사각형과 고도를 이 노드에 등록하고
## 그리는 일은 전부 넘긴다. 그렇게 해야 요소들이 **같은 장(場)을 공유**한다 —
## 두 버튼이 붙어 있으면 비탈이 겹쳐 하나의 능선이 되고, 팝업이 뜨면 주변 지반이
## 실제로 꺼진다. 요소마다 재료를 따로 두면 이런 관계는 흉내밖에 낼 수 없다.
##
## 등록자는 다음 세 가지를 답할 수 있으면 된다 (상속 관계는 필요 없다).
##   kit_rect() -> Rect2       장 좌표계의 사각형
##   kit_form() -> Vector4     고도 · 모서리 · 비탈 폭 · 웅덩이 깊이
##   kit_state() -> Vector4    포커스 · 눌림 · 비활성 · 얹힌 바닥의 고도
##   kit_pulse() -> Vector4    호버

## 조형 방향. 같은 요소 데이터를 **서로 다른 원시 도형**으로 그린다.
##
## 셋의 차이는 색이 아니라 **무엇으로 그렸는가**다.
##   TERRAIN  선  — 곡선 등고선. 면이 없다
##   FACET    면  — 직선 현으로 잘린 파편. 곡선이 없다
##   GRAIN    점  — 알갱이의 크기와 밀도. 선도 면도 없다
enum Variant { TERRAIN, FACET, GRAIN }

const SHADERS := {
	Variant.TERRAIN: "res://src/ui/kit/kit_terrain.gdshader",
	Variant.FACET: "res://src/ui/kit/kit_facet.gdshader",
	Variant.GRAIN: "res://src/ui/kit/kit_grain.gdshader",
}

const GROUP := "kit_field"

## 셰이더 배열의 상한. 넘으면 조용히 잘리는 대신 경고한다.
const MAX_ELEMENTS := 16

@export var variant: Variant = Variant.TERRAIN:
	set = set_variant

var _registered: Array[Object] = []
var _rects := PackedVector4Array()
var _forms := PackedVector4Array()
var _states := PackedVector4Array()
var _pulses := PackedVector4Array()


func _ready() -> void:
	add_to_group(GROUP)
	color = KitTokens.GROUND
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 등록자들이 자기 상태를 갱신한 뒤에 모아야 한 프레임 늦지 않는다.
	process_priority = 100
	_rects.resize(MAX_ELEMENTS)
	_forms.resize(MAX_ELEMENTS)
	_states.resize(MAX_ELEMENTS)
	_pulses.resize(MAX_ELEMENTS)
	_build_material()


func _process(_delta: float) -> void:
	_push_uniforms()


## 장에 참여시킨다. 등록 순서는 그림에 영향을 주지 않는다 —
## 고도는 더해지는 값이라 무엇이 위인지는 높이가 정한다.
func register(element: Object) -> void:
	if element in _registered:
		return
	if _registered.size() >= MAX_ELEMENTS:
		push_warning("KitField: 요소가 %d 개를 넘어 등록을 거절했습니다." % MAX_ELEMENTS)
		return
	_registered.append(element)


func unregister(element: Object) -> void:
	_registered.erase(element)


## 이 자리가 더 높은 지형에 덮여 있는가.
##
## 고도를 겹쳐서 합치므로, 낮은 봉우리가 높은 고원 밑에 들어가면 지형에서는 사라진다.
## 그런데 노드의 글자는 그것과 상관없이 계속 그려진다 — 팝업이 떴는데 그 아래 묻힌
## 버튼의 글자만 고원 위에 떠 있는 꼴이 된다. 묻힌 것은 글자도 없어야 한다.
##
## 사각형 안에 들어갔는가로 따지면 안 된다. 고원의 **비탈**에 잠긴 것도 묻힌 것이고,
## 비탈은 사각형 밖으로 72px 까지 뻗는다. 셰이더가 쓰는 것과 같은 단면으로 재야 한다.
func is_buried(who: Object, rect: Rect2, elevation: float) -> bool:
	var point := rect.get_center()
	for element in _registered:
		# 자기 자신은 빼야 한다. 넣어 두면 호버로 솟은 버튼이 **스스로에게 묻혔다**고
		# 판정되어 사라지고, 사라지면 판정에서 빠져 다시 나타난다.
		# 매 프레임 켜졌다 꺼지는 깜빡임이 되고, 그 사이 포커스까지 잃는다.
		if element == who or not is_instance_valid(element):
			continue
		var other := element as CanvasItem
		if other != null and not other.is_visible_in_tree():
			continue
		var form: Vector4 = element.call("kit_form")
		var state: Vector4 = element.call("kit_state")
		var lift := form.x - state.w
		if lift <= 0.0 or form.x <= elevation + 0.6:
			continue
		var other_rect: Rect2 = element.call("kit_rect")
		var distance := _distance_to(other_rect, form.y, point)
		var falloff := form.z * 0.25
		if state.w + lift * falloff / (falloff + maxf(distance, 0.0)) > elevation + 0.6:
			return true
	return false


## 둥근 사각형까지의 부호 있는 거리. 셰이더의 sd_round_box 와 같은 식이다.
static func _distance_to(rect: Rect2, radius: float, point: Vector2) -> float:
	var half := rect.size * 0.5
	var offset := (point - rect.get_center()).abs() - half + Vector2(radius, radius)
	return minf(maxf(offset.x, offset.y), 0.0) + offset.max(Vector2.ZERO).length() - radius


## 씬 어디에서든 장을 찾는다. 부모를 거슬러 올라가지 않는 이유는
## 버튼이 팝업 안에 들어가든 화면 바닥에 놓이든 같은 장을 써야 하기 때문이다.
static func find_in(tree: SceneTree) -> KitField:
	return tree.get_first_node_in_group(GROUP) as KitField


## 방향을 갈아 끼운다. 요소 데이터는 그대로이고 그리는 법만 바뀐다 —
## 세 방향이 같은 규칙 위에 서 있다는 것을 이 한 줄이 보장한다.
func set_variant(value: Variant) -> void:
	variant = value
	if is_inside_tree():
		_build_material()


func _build_material() -> void:
	var shader_material := ShaderMaterial.new()
	shader_material.shader = load(SHADERS[variant])
	shader_material.set_shader_parameter("contour_step", KitTokens.CONTOUR_STEP)
	shader_material.set_shader_parameter("line_half_width", KitTokens.LINE_HALF_WIDTH)
	shader_material.set_shader_parameter("index_every", KitTokens.INDEX_EVERY)
	shader_material.set_shader_parameter("index_weight", KitTokens.INDEX_WEIGHT)
	shader_material.set_shader_parameter("ground_color", KitTokens.GROUND)
	shader_material.set_shader_parameter("line_low", KitTokens.LINE_LOW)
	shader_material.set_shader_parameter("line_mid", KitTokens.LINE_MID)
	shader_material.set_shader_parameter("line_high", KitTokens.LINE_HIGH)
	shader_material.set_shader_parameter("accent_color", KitTokens.ACCENT)
	material = shader_material


func _push_uniforms() -> void:
	var shader_material := material as ShaderMaterial
	if shader_material == null:
		return
	var origin := global_position
	var count := 0
	for element in _registered:
		if not is_instance_valid(element):
			continue
		# 숨은 요소는 지형에서도 없어야 한다. 남겨 두면 안 보이는 봉우리가 배경을 밀어 올린다.
		var item := element as CanvasItem
		if item != null and not item.is_visible_in_tree():
			continue
		var rect: Rect2 = element.call("kit_rect")
		rect.position -= origin
		_rects[count] = Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y)
		_forms[count] = element.call("kit_form")
		_states[count] = element.call("kit_state")
		_pulses[count] = element.call("kit_pulse")
		count += 1
	shader_material.set_shader_parameter("field_size", size)
	shader_material.set_shader_parameter("element_count", count)
	shader_material.set_shader_parameter("element_rect", _rects)
	shader_material.set_shader_parameter("element_form", _forms)
	shader_material.set_shader_parameter("element_state", _states)
	shader_material.set_shader_parameter("element_pulse", _pulses)
