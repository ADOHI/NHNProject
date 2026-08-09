class_name NoiseScreen
extends Control
## **노이즈 축을 쓰는 화면의 바탕.** 부품 견본이든 진짜 화면이든 여기서 상속받는다.
##
## docs/design/20-ui-kit.md §20.44 · §20.45.
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
## | 지금 또렷한 것이 어디인가 | `focus_at()` 을 덮어쓴다 |

const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")
const FIELD := preload("res://src/ui/kit/cel/grain_field.gdshader")

## 초점이 옮겨가는 데 걸리는 시간. **또렷해지는 것은 사건이라 스냅이다.**
const SNAP := 0.14

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
		# **또렷한 것이 어디 있나.** 그 둘레에서 바탕의 알갱이가 걷힌다.
		stuff.set_shader_parameter("focus", focus_at())
	if _face != null:
		_face.queue_redraw()
	queue_redraw()


## 지금 또렷한 것의 한가운데. 상속하는 쪽이 덮어쓴다.
func focus_at() -> Vector2:
	return screen_size() * 0.5


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
func paint(shape: PackedVector2Array, tint: Color, noise: float) -> void:
	var faint := Grain.dim(tint, noise, void_color())
	for piece in Grain.shred(shape, noise, _clock):
		if piece.size() < 3 or GraphicCut.area_of(piece) < 0.05:
			continue
		_face.draw_colored_polygon(piece, faint)


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
	var faint := Grain.dim(tint, noise, void_color())
	var echo := Grain.echo_force(noise)
	if echo > 0.0:
		var ghost := Vector2(Grain.slip(band + 2, _clock, noise), 0.0)
		_face.draw_string(FONT, at + ghost, text, align, wide, tall, Color(faint, faint.a * echo))
	var push := Vector2(Grain.slip(band, _clock, noise), 0.0)
	_face.draw_string(FONT, at + push, text, align, wide, tall, faint)


## 글자가 이 크기로 몇 픽셀을 먹나. 넘치는지 재는 쪽이 쓴다.
func text_wide(text: String, tall: int) -> float:
	return FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, tall).x
