class_name ConceptPlate
extends BaseButton
## 컨셉 견본의 판 하나. **모든 컨셉이 이 렌더러 하나를 함께 쓴다.**
##
## 컨셉마다 그리는 코드를 따로 두면 넷을 나란히 놓았을 때 무엇 때문에 달라 보이는지
## 알 수 없게 된다. 여기서는 `PlateState` 채널만 해석하고, 컨셉은
## `src/core/ui/motion/*` 에서 그 채널을 **얼마나 세게 미느냐**로만 갈린다.
##
## 시간은 **사건이 일어난 뒤 흐른 시간**으로 잰다. 목표값으로 지수 접근시키면
## 요소가 영원히 도착하지 않아 타격감이 생기지 않는다 (앞 판이 그래서 죽었다).

## 어느 컨셉으로 움직일 것인가.
enum Concept { SLAM, SHEAR, HOLD }

const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")

@export var text: String = ""
@export var concept: Concept = Concept.SLAM
@export var font_size: int = 20

## 심사 · 캡처용 상태 대본. 음수면 실제 입력을 따른다.
var scripted_hover: float = -1.0
var scripted_press: float = -1.0

var _time: float = 0.0
var _hover_time: float = 999.0
var _press_time: float = 999.0
var _hovering: bool = false
var _pressing: bool = false
var _seed: int = 0
var _state: PlateState


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_seed = get_index() * 7 + int(position.x) / 13
	_state = PlateState.new()
	set_process(true)


func _process(delta: float) -> void:
	_time += delta

	var want_hover := is_hovered()
	if scripted_hover >= 0.0:
		want_hover = scripted_hover > 0.5
	var want_press := button_pressed
	if scripted_press >= 0.0:
		want_press = scripted_press > 0.5

	# 상태가 **바뀐 순간** 시계를 0 으로 돌린다. 이 한 줄이 오버슛을 가능하게 한다.
	if want_hover != _hovering:
		_hovering = want_hover
		_hover_time = 0.0
	else:
		_hover_time += delta
	if want_press != _pressing:
		_pressing = want_press
		_press_time = 0.0
	else:
		_press_time += delta

	_state = _evaluate()
	queue_redraw()


func _evaluate() -> PlateState:
	match concept:
		Concept.HOLD:
			return HoldMotion.evaluate(_time, _hover_time, _hovering, _press_time, _pressing, _seed)
		Concept.SHEAR:
			return ShearMotion.evaluate(
				_time, _hover_time, _hovering, _press_time, _pressing, _seed
			)
		_:
			return SlamMotion.evaluate(_time, _hover_time, _hovering, _press_time, _pressing, _seed)


func _draw() -> void:
	var state := _state
	if state == null:
		return

	# 잔상부터. 뒤에 남은 것이 먼저 깔려야 본체가 앞에 선다.
	for ghost in state.ghosts:
		draw_colored_polygon(
			_quad(ghost["offset"], ghost["scale"], ghost["skew"], 0.0), ghost["color"]
		)

	var quad := _quad(state.offset, state.scale, state.skew, state.rotation)
	if state.cuts.is_empty():
		draw_colored_polygon(quad, state.body)
	else:
		_draw_sliced(state, quad)
	if state.bar > 0.001:
		_draw_bar(quad, state.bar)

	if state.shock > 0.001:
		_draw_shock(state)

	_draw_label(state)


## 벤 판. **밑에 강세색을 깔고 그 위에 조각을 얹는다.**
##
## 조각이 미끄러져 벌어진 자리에서 강세색이 저절로 드러난다. 틈을 따로 그리는 것보다
## 정확하다 — 조각이 얼마나 어긋났든 드러나는 넓이가 알아서 맞는다.
func _draw_sliced(state: PlateState, quad: PackedVector2Array) -> void:
	draw_colored_polygon(quad, state.accent)
	var pieces := PolygonCut.slice(quad, state.cuts, state.cut_normal)
	for i in range(pieces.size()):
		var piece := pieces[i]
		var slide: Vector2 = state.piece_slide[i] if i < state.piece_slide.size() else Vector2.ZERO
		var spin: float = state.piece_spin[i] if i < state.piece_spin.size() else 0.0
		if absf(spin) > 0.0001:
			var pivot := _centroid(piece)
			var turn := Transform2D(spin, Vector2.ZERO)
			for j in range(piece.size()):
				piece[j] = turn * (piece[j] - pivot) + pivot
		for j in range(piece.size()):
			piece[j] += slide
		draw_colored_polygon(piece, state.body)


func _centroid(piece: PackedVector2Array) -> Vector2:
	var total := Vector2.ZERO
	for point in piece:
		total += point
	return total / maxf(1.0, float(piece.size()))


## 판의 네 귀퉁이. 기울이면 사각형이 평행사변형이 된다 — 직각은 기본값의 얼굴이다.
func _quad(
	at: Vector2, body_scale: Vector2, body_skew: float, body_rotation: float
) -> PackedVector2Array:
	var half := size * 0.5
	var lean := tan(body_skew) * size.y * 0.5
	var corners := PackedVector2Array(
		[
			Vector2(-half.x + lean, -half.y),
			Vector2(half.x + lean, -half.y),
			Vector2(half.x - lean, half.y),
			Vector2(-half.x - lean, half.y),
		]
	)
	var transform_matrix := Transform2D(body_rotation, half + at)
	for i in range(corners.size()):
		corners[i] = transform_matrix * (corners[i] * body_scale)
	return corners


## 강세 막대. 판의 아래 모서리를 따라 자란다.
func _draw_bar(corners: PackedVector2Array, amount: float) -> void:
	var left := corners[3]
	var right := corners[2]
	var top_left := corners[0]
	var thickness := (left - top_left).normalized() * -6.0
	var end_left := left + (right - left) * clampf(amount, 0.0, 1.0)
	draw_colored_polygon(
		PackedVector2Array([left, end_left, end_left + thickness, left + thickness]), _state.accent
	)


## 충격 고리. 누른 자리에서 퍼져 나간다.
func _draw_shock(state: PlateState) -> void:
	var center := size * 0.5 + state.offset
	var reach := 24.0 + state.shock * (size.x * 0.9)
	var fade := 1.0 - state.shock
	var color := state.accent
	color.a = fade * fade * 0.9
	# 원이 아니라 각진 고리다. 둥근 파문은 물이고, 이것은 찍힌 자국이다.
	var ring := PackedVector2Array()
	for i in range(6):
		var angle := TAU * float(i) / 6.0 + 0.26
		ring.append(center + Vector2(cos(angle), sin(angle) * 0.55) * reach)
	ring.append(ring[0])
	draw_polyline(ring, color, maxf(1.0, 7.0 * fade))


func _draw_label(state: PlateState) -> void:
	var variation := FontVariation.new()
	variation.base_font = FONT
	variation.spacing_glyph = 3
	var scaled := int(round(float(font_size) * state.ink_scale))
	var measured := variation.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled)
	var at := (
		size * 0.5 + state.offset + state.ink_offset - Vector2(measured.x * 0.5, -measured.y * 0.32)
	)
	draw_string(variation, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled, state.ink)
