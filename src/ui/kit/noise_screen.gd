class_name NoiseScreen
extends Control
## **노이즈 축을 쓰는 화면의 바탕.** 부품 견본이든 진짜 화면이든 여기서 상속받는다.
##
## docs/design/20-ui-kit.md §20.44 · §20.45 · §20.47.
##
## ## 왜 바탕 클래스인가
##
## 축이 하나라는 것이 이 컨셉의 전부다(§20.44). 화면마다 칠하는 법을 다시 쓰면
## **화면마다 축이 조금씩 달라지고**, 그러면 축이 하나라는 말이 거짓이 된다.
## 칠하는 자리(`paint` · `say` · `stroke`)와 알갱이 장과 사다리가 여기 한 벌 있다.
##
## 상속하는 쪽이 하는 일은 셋뿐이다.
##
## | 무엇 | 어떻게 |
## | --- | --- |
## | 크기와 한 바퀴 | `CARD` · `LOOP` 상수 |
## | 무엇을 그리나 | `_paint_screen()` 을 덮어쓴다 |
## | 지금 또렷한 것이 어디에 얼마만큼 있나 | `focus_box()` 를 덮어쓴다 |

const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")
const FIELD := preload("res://src/ui/kit/cel/grain_field.gdshader")

## 초점이 옮겨가는 데 걸리는 시간. **또렷해지는 것은 사건이라 스냅이다.**
const SNAP := 0.14

## 앞판이 뒤판에서 잘라 내는 여유. **이 빈 줄 하나가 「판이 두 장」이라고 말한다** (§20.28).
##
## 겹쳐 두면 아무 말도 안 한다 — 덮여서 안 보이는 것과 잘려서 없는 것은 화면에서
## 똑같아 보이지만 **가장자리가 다르다** (§20.34.1).
const BLEED := 3.0

## 판이 눕는 기본 기울기. **직사각형이 아니다** (§20.28).
const SLANT := 0.20

## 또렷한 것의 네모 밖으로 알갱이가 얼마나 더 걷히나(px).
##
## 부품 크기에 딱 맞추면 **가장자리 바로 옆이 알갱이 한복판**이라 판의 윤곽이 잡음에
## 물린다. 여유를 여기 한 곳에 두는 이유는 화면마다 더하면 화면마다 맑음의 크기가
## 달라지고, 그러면 축이 하나라는 말이 거짓이 되기 때문이다 (§20.47.3).
const CLEAR_PAD := 16.0

## 색은 `HoloPalette` 한 곳에서만 정해진다 (§20.31). 화면은 번호만 든다.
var palette := 0:
	set(value):
		palette = wrapi(value, 0, HoloPalette.count())
		_tint_screen()
		queue_redraw()

var _clock := 0.0
var _driven := false
var _field: ColorRect
var _face: Control


func _ready() -> void:
	_field = ColorRect.new()
	_field.color = Color.WHITE
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stuff := ShaderMaterial.new()
	stuff.shader = FIELD
	stuff.set_shader_parameter("churn", Grain.CHURN)
	_field.material = stuff
	add_child(_field)
	_face = Control.new()
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_face)
	_face.draw.connect(_paint_screen)
	_fit()
	_tint_screen()
	_ready_screen()
	set_process(not _driven)


## 상속하는 쪽이 자기 것을 짓는 자리. `_ready()` 를 덮어쓰면 바탕이 안 서므로 여기다.
func _ready_screen() -> void:
	pass


## 화면 크기를 층 둘에 흘린다. **한 곳에서만 흘린다** — 자리마다 넣으면 하나가 빠지고,
## 빠진 하나는 크기가 0 이라 **아무것도 안 그려진 화면**이 된다.
func _fit() -> void:
	var card := screen_size()
	size = card
	_field.size = card
	_face.size = card
	(_field.material as ShaderMaterial).set_shader_parameter("card", card)


## 이 화면의 크기. 상속하는 쪽이 `CARD` 상수로 덮어쓴다.
func screen_size() -> Vector2:
	return Vector2(660.0, 760.0)


func drive_externally() -> void:
	_driven = true
	set_process(false)


func _process(delta: float) -> void:
	set_clock(fposmod(_clock + delta, loop_time()))


func loop_time() -> float:
	return 6.4


func set_clock(t: float) -> void:
	_clock = t
	if _field != null:
		var stuff := _field.material as ShaderMaterial
		stuff.set_shader_parameter("clock", t)
		# **또렷한 것이 어디에 얼마만큼 있나.** 그 네모 안에서 바탕의 알갱이가 걷힌다.
		var clear := focus_box().grow(CLEAR_PAD)
		stuff.set_shader_parameter("focus", clear.get_center())
		stuff.set_shader_parameter("span", clear.size * 0.5)
	if _face != null:
		_face.queue_redraw()
	queue_redraw()


## 지금 또렷한 것이 **어디에 얼마만큼** 있나. 상속하는 쪽이 덮어쓴다.
##
## 한가운데만 주던 것을 네모로 바꿨다 (§20.47.3). 「지금 여기」는 대개 가로로 긴 띠인데
## 걷힘이 동그라면 **그 띠의 양 끝이 알갱이에 박힌다** — 부품 자신은 또렷한데 자리가
## 안 맑다. 맑은 것은 **잡음에 뚫린 구멍 안에** 서 있어야 한다.
func focus_box() -> Rect2:
	return Rect2(screen_size() * 0.25, screen_size() * 0.5)


## 무엇을 그리나. 상속하는 쪽이 덮어쓴다.
func _paint_screen() -> void:
	pass


func _tint_screen() -> void:
	if _field == null:
		return
	var stuff := _field.material as ShaderMaterial
	stuff.set_shader_parameter("deep", void_color())
	stuff.set_shader_parameter("ink", paper())


func void_color() -> Color:
	return HoloPalette.void_color(palette)


func paper() -> Color:
	return HoloPalette.paper(palette)


## **신호.** 노이즈 0.00 인 자리에만 쓴다.
func accent() -> Color:
	return HoloPalette.accent(palette)


## **고름** — 켜짐 · 선택 · 값.
func pick() -> Color:
	return HoloPalette.pick(palette)


## **험** — 되돌릴 수 없는 것.
func peril() -> Color:
	return HoloPalette.peril(palette)


func ink(surface: Color) -> Color:
	return HoloPalette.ink(palette, surface)


## 스냅 0..1. 또렷해지는 것도 흐려지는 것도 이 하나를 쓴다.
func snap(from: float, span: float = SNAP) -> float:
	return clampf((_clock - from) / span, 0.0, 1.0)


## 네 귀가 반듯한 판. **형태 문법을 안 쓴다** — 가장자리는 찢겨서 말한다 (§20.44.2).
func box_of(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y)
		]
	)


## **칠하는 자리는 여기 하나다.** 노이즈가 찢김 · 빠짐 · 대비를 한 번에 정한다.
##
## `unit_y` 를 주면 **안 찢고** 그 높이의 띠 밀림만큼 통째로 민다. 글자를 뚫은 판이
## 그렇다 — 판과 획이 따로 찢기면 **획이 끊겨 글자를 못 읽는다**(§20.44.5 의 규칙을
## 판·글자 한 덩어리에도 그대로 쓴다). 한 덩어리는 **같은 `unit_y`** 를 받아야 한다.
##
## **`unit_y` 를 받은 덩어리는 글자다.** 그래서 밀림과 대비를 `Grain.read()` 가 깎은
## 값으로 받는다(§20.47.2) — 판의 세기를 그대로 받으면 뚫린 획이 바래서 못 읽는다.
## 깎는 자리를 여기 두는 이유는 **한 덩어리의 조각들이 다른 값을 받으면 갈라지기**
## 때문이다: 뒤판 · 판 · 획 · 구멍이 부르는 곳이 넷인데 넷 다 같은 폭으로 밀려야 한다.
func paint(shape: PackedVector2Array, tint: Color, noise: float, unit_y := INF) -> void:
	if is_inf(unit_y):
		var faint := Grain.dim(tint, noise, void_color())
		for piece in Grain.shred(shape, noise, _clock):
			if piece.size() < 3 or GraphicCut.area_of(piece) < 0.05:
				continue
			_face.draw_colored_polygon(piece, faint)
		return
	var legible := Grain.read(noise)
	var whole := Grain.moved(
		shape, Vector2(Grain.slip(Grain.band_of(unit_y), _clock, legible), 0.0)
	)
	if whole.size() < 3 or GraphicCut.area_of(whole) < 0.05:
		return
	_face.draw_colored_polygon(whole, Grain.dim(tint, legible, void_color()))


## 획 하나. **자기 띠의 밀림을 탄다** — 판과 같은 격자라 같은 줄에서 어긋난다.
func stroke(from: Vector2, to: Vector2, tint: Color, noise: float, wide: float = 2.4) -> void:
	var band := Grain.band_of((from.y + to.y) * 0.5)
	if Grain.gone(band, _clock, noise):
		return
	var push := Vector2(Grain.slip(band, _clock, noise), 0.0)
	_face.draw_line(from + push, to + push, Grain.dim(tint, noise, void_color()), wide)


## 글자. **획을 안 찢는다** — 찢으면 못 읽고, 못 읽는 것은 노이즈가 아니라 얼룩이다.
##
## 덩어리째 자기 띠의 밀림을 타고, 노이즈가 크면 **다른 띠의 밀림으로 한 벌 더** 겹친다.
## 읽힘의 경계는 노이즈 0.92 다 (§20.44.5).
##
## 밀림과 대비는 **판이 받는 값이 아니라 `Grain.read()` 가 깎은 값**을 받는다 (§20.47.2).
## 흐린 쪽을 더 흐리게 하려고 판의 세기를 올렸는데 글자가 그것을 그대로 받으면
## 0.92 에서 못 읽는다. **띠 주사위가 같아 방향은 같고 폭만 작다** — 같은 줄에서
## 같은 쪽으로 어긋나는 것은 그대로다.
func say(
	text: String,
	at: Vector2,
	tall: int,
	tint: Color,
	noise: float,
	wide: float = -1.0,
	align: int = HORIZONTAL_ALIGNMENT_LEFT
) -> void:
	var band := Grain.band_of(at.y - float(tall) * 0.4)
	var legible := Grain.read(noise)
	var faint := Grain.dim(tint, legible, void_color())
	var echo := Grain.echo_force(noise)
	if echo > 0.0:
		var ghost := Vector2(Grain.slip(band + 2, _clock, legible), 0.0)
		_face.draw_string(FONT, at + ghost, text, align, wide, tall, Color(faint, faint.a * echo))
	var push := Vector2(Grain.slip(band, _clock, legible), 0.0)
	_face.draw_string(FONT, at + push, text, align, wide, tall, faint)


## 어긋난 **뒤판.** 앞판이 덮을 자리를 **잘라 내고** 초승달만 남긴다 (§20.34).
##
## **그림자가 아니라 판 한 겹 더**라서 색이 있고 어긋나 있다. 노이즈는 앞판과 같은 값을
## 받는다 — 뒤판만 다른 칸에 있으면 **한 부품이 두 군데를 보고 있는 것**이 된다.
func backplate(
	front: PackedVector2Array, by: float, at: Vector2, tint: Color, noise: float, unit_y := INF
) -> void:
	for crescent in GraphicCut.notched(GraphicCut.swelled(front, by, at), front, BLEED):
		paint(crescent, tint, noise, unit_y)


## 어긋난 뒤판의 색. **고름의 짙은 쪽**이라 어긋남이 색으로도 읽힌다.
func back() -> Color:
	return HoloPalette.back(palette)


## 글자의 윤곽을 **다각형으로** 받아 자리에 앉힌다 (§20.37).
##
## `draw_set_transform` 을 안 쓰는 이유는 찢김이 **화면 좌표**의 띠 격자에서 계산되기
## 때문이다 — 변환을 걸어 둔 채로 넘기면 글자만 딴 띠에서 찢긴다.
## 자리와 기울기를 **점에 미리 발라** 넘긴다.
func glyphs(text: String, seat: Vector2, lean: float, tall: int) -> Dictionary:
	var made := GlyphShape.of(text, FONT, tall, Vector2.ZERO)
	var pose := Transform2D(lean, seat)
	var out := {"solid": [] as Array[PackedVector2Array], "hole": [] as Array[PackedVector2Array]}
	for key: String in ["solid", "hole"]:
		var bag: Array[PackedVector2Array] = out[key]
		for ring: PackedVector2Array in made[key]:
			var moved := PackedVector2Array()
			for point in ring:
				moved.append(pose * point)
			bag.append(moved)
	return out


## 글자 획 하나를 **판 안팎으로 갈라** 칠한다. 안은 `within`(구멍), 밖은 `beyond`(판).
##
## **글자가 도형이다** (§20.37) — 판 위에서는 구멍이고 판 밖에서는 판이다.
## 안팎이 같은 노이즈를 받으므로 같은 띠에서 같이 찢긴다.
func pierce(
	slab: PackedVector2Array,
	ring: PackedVector2Array,
	within: Color,
	beyond: Color,
	noise: float,
	unit_y := INF
) -> void:
	for inside in Geometry2D.intersect_polygons(ring, slab):
		paint(inside, within, noise, unit_y)
	for outside in Geometry2D.clip_polygons(ring, slab):
		paint(outside, beyond, noise, unit_y)
