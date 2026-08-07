class_name PressPanel
extends PanelContainer
## 지면 위의 한 덩어리. **어느 판으로 찍힌 것인지를 형태와 질감으로** 선언한다.
##
## 이 게임의 화면에는 성질이 정반대인 두 정보가 함께 올라온다
## (docs/design/07-level-design.md §7.4).
##
##   먹판   시설이 잰 값. 정확하지만 모호하다. 괘선에 갇혀 축에 반듯하다
##   별색판 렉카가 쓴 말. 구체적이지만 못 믿는다. 오려 낸 조각이라 찢겨 있고 기울어 있다
##
## **플레이어가 읽기 전에 어느 쪽인지 알 수 있어야 한다.**
## 그래서 판을 패널의 속성으로 두고 종이•괘선•가장자리•기울기를 한꺼번에 결정한다.
## 라벨마다 색을 손으로 칠하면 이 규칙은 곧 무너진다.
##
## 씬에서 쓰는 법 — PanelContainer 에 이 스크립트를 붙이고, 내용을 MarginContainer 하나에
## 담아 자식으로 둔다. 종이면과 덧그림은 이 스크립트가 만들어 끼운다.
##
## 여백을 씬이 아니라 여기서 넣는 이유는, 씬 파일에 적힌 숫자는 토큰을 따라오지 않기
## 때문이다. 값이 두 곳에 있으면 반드시 어긋난다.

## 어느 판으로 찍힌 덩어리인가.
enum Plate {
	FACT,  ## 먹판. 위험도 • 고도 • 조판 지시
	STORY,  ## 별색판. 제목 • 속보 • 논평
	PROOF,  ## 교정쇄. 아직 인쇄기에 안 걸린 지면 — 개발 패널
}

const _SURFACE_SHADER := preload("res://src/ui/style/shaders/press_panel.gdshader")

## 별색 조각이 축에서 벗어나는 각도. 사실은 반듯하고 이야기는 기운다.
const _STORY_LEAN := -1.8

@export var plate: Plate = Plate.FACT

## 아래쪽에 지면 눈금을 세운다. "이건 재서 나온 값이다"를 말하는 표시다.
@export var show_ticks: bool = false

var _tear: Control
var _surface: ColorRect
var _overlay: Control
var _material: ShaderMaterial


func _ready() -> void:
	# 패널 자신은 여백을 갖지 않는다. 종이면과 덧그림이 패널 전체를 덮어야 하기 때문이다.
	add_theme_stylebox_override("panel", UiStyleBox.hollow())
	_pad_content()
	_build_tear()
	_build_surface()
	_build_overlay()
	resized.connect(_sync_size)
	_sync_size()


## 판을 바꾼다. 같은 패널을 상황에 따라 다르게 쓸 때만 필요하다.
func set_plate(value: Plate) -> void:
	plate = value
	if _material != null:
		_apply_plate()
		_sync_size()


## 내용 여백을 토큰에서 넣는다. 씬은 MarginContainer 를 두기만 하면 된다.
func _pad_content() -> void:
	for child in get_children():
		var margin := child as MarginContainer
		if margin == null:
			continue
		margin.add_theme_constant_override("margin_left", UiTokens.SPACE_GAP)
		margin.add_theme_constant_override("margin_right", UiTokens.SPACE_GAP)
		margin.add_theme_constant_override("margin_top", UiTokens.SPACE_STEP)
		margin.add_theme_constant_override("margin_bottom", UiTokens.SPACE_STEP)
		return


## 찢긴 종이 바탕. 별색 조각은 자로 자른 것이 아니라 지면에서 **오려 낸 것**이다.
func _build_tear() -> void:
	_tear = Control.new()
	_tear.name = "Tear"
	_tear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tear)
	move_child(_tear, 0)
	_tear.draw.connect(_draw_tear)


func _build_surface() -> void:
	_surface = ColorRect.new()
	_surface.name = "Surface"
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = _SURFACE_SHADER
	_surface.material = _material
	add_child(_surface)
	move_child(_surface, 1)
	_apply_plate()


## 덧그림은 **맨 뒤 자식**이어야 내용 위에 얹힌다.
## PanelContainer 자신의 그리기는 자식보다 먼저 일어나 종이면에 가린다.
func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.draw.connect(_draw_overlay)


func _apply_plate() -> void:
	_material.set_shader_parameter("paper_color", _paper())
	_material.set_shader_parameter("ink_color", UiTokens.INK)
	_material.set_shader_parameter("accent_color", UiTokens.SPOT)
	_material.set_shader_parameter("story", 1.0 if plate == Plate.STORY else 0.0)
	_material.set_shader_parameter("bleed_period", UiTokens.TIME_PRESS * 2.4)
	rotation = deg_to_rad(_STORY_LEAN) if plate == Plate.STORY else 0.0


func _sync_size() -> void:
	pivot_offset = size * 0.5
	if _material != null:
		var inset := _inset()
		_surface.position = Vector2(inset, inset)
		_surface.size = size - Vector2(inset, inset) * 2.0
		_material.set_shader_parameter("panel_size", _surface.size)
	if _overlay != null:
		_overlay.queue_redraw()
	if _tear != null:
		_tear.queue_redraw()


## 오려 낸 조각만 안쪽으로 물러난다. 물러난 만큼이 찢긴 가장자리의 자리다.
func _inset() -> float:
	return UiTokens.TEAR_AMPLITUDE if plate == Plate.STORY else 0.0


## 패널의 종이.
##
## **먹판 패널은 종이가 아니라 옅은 망(tint)이다.**
## 지면 위에 더 흰 종이를 얹어 봐야 인쇄판을 통과하면 바탕과 똑같아진다 —
## 종이는 종이일 뿐이라 점이 하나도 안 앉기 때문이다.
## 그래서 신문이 실제로 쓰는 방법을 그대로 쓴다: 곁들이는 기사는 **옅은 망을 깔아** 구분한다.
##
## 오려 붙인 조각만 흰 종이 그대로다. 다른 지면에서 잘라 온 것이라 망이 없는 것이 맞다.
func _paper() -> Color:
	match plate:
		Plate.STORY:
			return UiTokens.fade(UiTokens.PAPER_HIGH, 0.99)
		Plate.PROOF:
			return UiTokens.fade(UiTokens.PAPER.lerp(UiTokens.INK, 0.11), 0.98)
		_:
			return UiTokens.fade(UiTokens.PAPER.lerp(UiTokens.INK, 0.055), 0.97)


func _draw_tear() -> void:
	if plate != Plate.STORY or size.x < 8.0 or size.y < 8.0:
		return
	var rect := Rect2(Vector2.ZERO, size)
	var torn := UiShape.deckle_edge(rect, UiTokens.TEAR_AMPLITUDE, UiTokens.TEAR_STEP, 3.0)
	_tear.draw_colored_polygon(torn, UiTokens.PAPER_HIGH)
	_tear.draw_polyline(
		UiShape.closed_outline(torn), UiTokens.fade(UiTokens.INK_FAINT, 0.55), UiTokens.RULE_HAIR
	)


## 패널 위에 얹는 형태. 전부 절차적으로 만든다 (src/ui/style/shape.gd).
func _draw_overlay() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var rect := Rect2(Vector2.ZERO, size)
	match plate:
		Plate.PROOF:
			_draw_proof_marks(rect)
		Plate.STORY:
			_draw_story_rules(rect)
		_:
			_draw_fact_rules(rect)


## 먹판은 괘선에 갇힌다. 위에 굵은 선, 아래에 가는 선, 귀퉁이에 판 맞춤표.
##
## 사방 테두리를 두르지 않는 이유는, 얇은 테두리를 두른 회색 패널이야말로
## 어느 게임에 붙여도 말이 되는 형태이기 때문이다.
## 맞춤표는 그 대체물이면서 동시에 **이 화면이 인쇄 중인 판이라는 사실**이다.
func _draw_fact_rules(rect: Rect2) -> void:
	for band in UiShape.rule_stack(
		Vector2.ZERO,
		rect.size.x,
		PackedFloat32Array([UiTokens.RULE_BANNER, UiTokens.RULE_HAIR]),
		3.0
	):
		_overlay.draw_rect(band, UiTokens.INK)
	_overlay.draw_rect(
		Rect2(0.0, rect.size.y - UiTokens.RULE_TEXT, rect.size.x, UiTokens.RULE_TEXT), UiTokens.INK
	)
	for corner in [rect.position + Vector2(13.0, 26.0), rect.end - Vector2(13.0, 13.0)]:
		_draw_register(corner, UiTokens.fade(UiTokens.INK_MUTED, 0.7))
	if show_ticks:
		_draw_ticks(rect)


## 별색 조각은 갇히지 않는다. 위쪽에 별색 괘선 하나만 긋고 나머지는 찢긴 채로 둔다.
func _draw_story_rules(rect: Rect2) -> void:
	var inset := UiTokens.TEAR_AMPLITUDE
	_overlay.draw_rect(
		Rect2(inset, inset, rect.size.x - inset * 2.0, UiTokens.RULE_HEAVY), UiTokens.SPOT
	)
	# 먹판이 같은 자리에 어긋나서 한 번 더 지나간다. 서명은 조각에서도 같다.
	_overlay.draw_rect(
		Rect2(
			Vector2(inset, inset) + UiTokens.slip(UiTokens.SLIP_STORY),
			Vector2(rect.size.x - inset * 2.0, UiTokens.RULE_HAIR)
		),
		UiTokens.fade(UiTokens.INK, 0.55)
	)


## 교정쇄는 아직 인쇄기에 안 걸렸다. 별색이 없고 여백에 교정 눈금만 있다.
func _draw_proof_marks(rect: Rect2) -> void:
	_overlay.draw_rect(Rect2(0.0, 0.0, UiTokens.RULE_HEAVY, rect.size.y), UiTokens.INK)
	var top := Vector2(UiTokens.RULE_HEAVY + 2.0, UiTokens.SPACE_GAP)
	var bottom := Vector2(top.x, rect.size.y - UiTokens.SPACE_GAP)
	for tick in UiShape.tick_ruler(top, bottom, 23, 8.0):
		_overlay.draw_polyline(tick, UiTokens.fade(UiTokens.INK_MUTED, 0.65), UiTokens.RULE_HAIR)


func _draw_ticks(rect: Rect2) -> void:
	var left := Vector2(UiTokens.SPACE_STEP, rect.size.y - UiTokens.RULE_TEXT)
	var right := Vector2(rect.size.x - UiTokens.SPACE_STEP, rect.size.y - UiTokens.RULE_TEXT)
	for tick in UiShape.tick_ruler(left, right, 19, -6.0):
		_overlay.draw_polyline(tick, UiTokens.fade(UiTokens.INK_MUTED, 0.5), UiTokens.RULE_HAIR)


func _draw_register(center: Vector2, color: Color) -> void:
	for stroke in UiShape.register_mark(center, UiTokens.REGISTER_ARM, UiTokens.REGISTER_GAP):
		_overlay.draw_polyline(stroke, color, UiTokens.RULE_HAIR)
	_overlay.draw_polyline(
		UiShape.register_ring(center, UiTokens.REGISTER_ARM * 0.55), color, UiTokens.RULE_HAIR
	)
