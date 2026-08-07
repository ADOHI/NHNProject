class_name SignalPanel
extends PanelContainer
## 패널 한 장. 어느 레이어의 정보인지를 **형태와 질감으로** 선언한다.
##
## 이 게임의 화면에는 성질이 정반대인 두 정보가 함께 올라온다
## (docs/design/07-level-design.md §7.4).
##
##   계측 — 정확하지만 모호하다. 반듯하고 조용하다
##   송출 — 구체적이지만 못 믿는다. 기울고 흔들린다
##
## 플레이어가 **읽기 전에** 어느 쪽인지 알 수 있어야 한다.
## 그래서 레이어를 패널의 속성으로 두고 색·모서리·간섭을 한꺼번에 결정한다.
## 라벨마다 색을 손으로 칠하면 이 규칙은 곧 무너진다.
##
## 씬에서 쓰는 법 — PanelContainer 에 이 스크립트를 붙이고, 내용을 MarginContainer 하나에
## 담아 자식으로 둔다. 배경면(셰이더)과 덧그림(절차적 형태)은 이 스크립트가 만들어 끼운다.
##
## 여백을 씬이 아니라 여기서 넣는 이유는, 씬 파일에 적힌 숫자는 토큰을 따라오지 않기
## 때문이다. 값이 두 곳에 있으면 반드시 어긋난다.

## 어느 레이어의 패널인가.
enum Layer {
	INSTRUMENT,  ## 시설이 만든 정보. 위험도 · 고도 · 조작반
	BROADCAST,  ## 렉카가 만든 정보. 자막 · 속보 · 논평
	TRUTH,  ## 송출되지 않는 화면. 개발 패널
}

const _SURFACE_SHADER := preload("res://src/ui/style/shaders/broadcast_panel.gdshader")

@export var layer: Layer = Layer.INSTRUMENT

## 아래쪽에 계측 눈금을 세운다. "이건 재서 나온 값이다"를 말하는 표시다.
@export var show_ticks: bool = false

var _surface: ColorRect
var _overlay: Control
var _material: ShaderMaterial


func _ready() -> void:
	# 패널 자신은 여백을 갖지 않는다. 배경면과 덧그림이 패널 전체를 덮어야 하기 때문이다.
	add_theme_stylebox_override("panel", UiStyleBox.hollow())
	_pad_content()
	_build_surface()
	_build_overlay()
	resized.connect(_sync_size)
	_sync_size()


## 레이어를 바꾼다. 같은 패널을 상황에 따라 다르게 쓸 때만 필요하다.
func set_layer(value: Layer) -> void:
	layer = value
	if _material != null:
		_apply_layer()
		_overlay.queue_redraw()


## 내용 여백을 토큰에서 넣는다. 씬은 MarginContainer 를 두기만 하면 된다.
func _pad_content() -> void:
	for child in get_children():
		var margin := child as MarginContainer
		if margin == null:
			continue
		margin.add_theme_constant_override("margin_left", UiTokens.SPACE_GAP)
		margin.add_theme_constant_override("margin_right", UiTokens.SPACE_STEP)
		margin.add_theme_constant_override("margin_top", UiTokens.SPACE_STEP)
		margin.add_theme_constant_override("margin_bottom", UiTokens.SPACE_STEP)
		return


func _build_surface() -> void:
	_surface = ColorRect.new()
	_surface.name = "Surface"
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = _SURFACE_SHADER
	_surface.material = _material
	add_child(_surface)
	move_child(_surface, 0)
	_apply_layer()


## 덧그림은 **맨 뒤 자식**이어야 내용 위에 얹힌다.
## PanelContainer 자신의 그리기는 자식보다 먼저 일어나 배경면에 가린다.
func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.draw.connect(_draw_overlay)


func _apply_layer() -> void:
	_material.set_shader_parameter("cuts", _cuts_vector())
	_material.set_shader_parameter("fill_color", _fill())
	_material.set_shader_parameter("accent_color", _accent())
	_material.set_shader_parameter("interference", 1.0 if layer == Layer.BROADCAST else 0.0)


func _sync_size() -> void:
	if _material != null:
		_material.set_shader_parameter("panel_size", size)
	if _overlay != null:
		_overlay.queue_redraw()


func _cuts_vector() -> Vector4:
	var cuts := _cuts()
	return Vector4(cuts[0], cuts[1], cuts[2], cuts[3])


func _cuts() -> PackedFloat32Array:
	match layer:
		Layer.BROADCAST:
			return UiTokens.chip_cuts()
		Layer.TRUTH:
			return PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
		_:
			return UiTokens.panel_cuts()


func _fill() -> Color:
	match layer:
		Layer.BROADCAST:
			return UiTokens.fade(UiTokens.PLATE_HIGH, 0.95)
		Layer.TRUTH:
			return UiTokens.fade(UiTokens.VOID, 0.97)
		_:
			return UiTokens.fade(UiTokens.PLATE_HIGH, 0.96)


func _accent() -> Color:
	match layer:
		Layer.BROADCAST:
			return UiTokens.ONAIR
		Layer.TRUTH:
			return UiTokens.SIGNAL_DIM
		_:
			return UiTokens.SIGNAL


## 패널 위에 얹는 형태. 전부 절차적으로 만든다 (src/ui/style/shape.gd).
func _draw_overlay() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var rect := Rect2(Vector2.ZERO, size)
	var accent := _accent()
	if layer == Layer.TRUTH:
		_draw_truth_rule(rect, accent)
		return
	# 계측·송출 패널은 카메라 프레임처럼 귀퉁이만 집는다.
	for corner in _bracket_corners():
		_overlay.draw_polyline(
			UiShape.bracket(rect, corner, UiTokens.BRACKET_ARM),
			UiTokens.fade(accent, 0.55),
			UiTokens.STROKE_HAIR
		)
	if show_ticks:
		_draw_ticks(rect, accent)


## 개발 패널은 송출되지 않으므로 프레임을 두르지 않는다.
## 왼쪽에 계측 눈금만 세운다 — 이건 화면이 아니라 장비의 옆면이다.
func _draw_truth_rule(rect: Rect2, accent: Color) -> void:
	var top := Vector2(1.0, UiTokens.SPACE_GAP)
	var bottom := Vector2(1.0, rect.size.y - UiTokens.SPACE_GAP)
	_overlay.draw_line(top, bottom, UiTokens.fade(accent, 0.9), UiTokens.STROKE_RULE)
	for tick in UiShape.tick_ruler(top, bottom, 21, 9.0):
		_overlay.draw_polyline(tick, UiTokens.fade(accent, 0.7), UiTokens.STROKE_HAIR)


func _draw_ticks(rect: Rect2, accent: Color) -> void:
	var left := Vector2(UiTokens.SPACE_STEP, rect.size.y - 1.0)
	var right := Vector2(rect.size.x - UiTokens.SPACE_STEP, rect.size.y - 1.0)
	for tick in UiShape.tick_ruler(left, right, 17, -5.0):
		_overlay.draw_polyline(tick, UiTokens.fade(accent, 0.35), UiTokens.STROKE_HAIR)


## 잘린 모서리에는 브래킷을 두지 않는다. 잘린 면 자체가 이미 표시다.
func _bracket_corners() -> Array[int]:
	if layer == Layer.BROADCAST:
		return [UiShape.Corner.TOP_LEFT, UiShape.Corner.BOTTOM_RIGHT]
	return [UiShape.Corner.TOP_LEFT, UiShape.Corner.BOTTOM_LEFT]
