extends Control
## 방향 D — **검열: 지면을 먹으로 덮는다.** (일부러 과하게 만든 쪽)
##
## 다른 셋이 "읽히는 화면"을 만들려고 애쓰는 동안, 이 방향은 반대로 간다.
## 시설은 유출을 막으려 하고 렉카는 뚫으려 한다. 그 싸움이 지면 위에서 벌어진다 —
## **정보는 먹으로 덮여 있고, 플레이어는 덮이다 만 자리를 읽는다.**
##
## 서명 후보: **먹칠 막대.** 검은 막대가 화면 구조 그 자체다. 정보는 막대 사이의 틈이다.
##
## 왜 과한 쪽을 하나 만들어 두는가 — 안전한 셋을 만들어 놓고 그중 하나를 고르면
## 결국 안전한 것이 나온다. **끝을 봐야 가운데가 어디인지 알 수 있다.**
##
## 이 스케치가 실제로 쓰기 어려운 이유도 화면에 같이 적혀 있다.
## 판을 읽어야 하는 게임에서 판의 절반을 덮는 것은 정보 설계와 정면으로 부딪힌다.

const _PRESS := preload("res://src/ui/style/sketch/shaders/sketch_press.gdshader")

const _PAPER := Color(0.918, 0.898, 0.851)
const _INK := Color(0.043, 0.039, 0.035)
const _SPOT := Color(0.878, 0.098, 0.118)
const _OCHRE := Color(0.855, 0.620, 0.055)

const _TILE := Vector2(190.0, 84.0)

## 먹칠 막대의 자리. 화면 좌표 그대로 박아 둔다 — 이건 배치가 아니라 **구조**다.
const _BARS := [
	[Rect2(-40.0, 150.0, 1120.0, 62.0), 0.0],
	[Rect2(220.0, 262.0, 1480.0, 44.0), -1.4],
	[Rect2(-60.0, 400.0, 780.0, 96.0), 0.8],
	[Rect2(880.0, 430.0, 820.0, 58.0), 1.9],
	[Rect2(120.0, 596.0, 1360.0, 74.0), -0.6],
	[Rect2(-30.0, 742.0, 640.0, 40.0), 1.2],
]

var _font: Font


func _ready() -> void:
	_font = SketchStage.font()


## 바탕은 종이다. 먹칠이 무서운 이유는 **덮인 것이 종이라서**다.
func background_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _PRESS
	material.set_shader_parameter("paper_color", _PAPER)
	material.set_shader_parameter("shade_color", Color(0.820, 0.792, 0.729))
	return material


func _draw() -> void:
	_draw_masthead()
	_draw_board()
	_draw_bars()
	_draw_stamps()
	_draw_caption()
	_draw_warning()


func _draw_masthead() -> void:
	draw_rect(Rect2(0.0, 0.0, 1600.0, 128.0), _INK)
	_shout(Vector2(40.0, 104.0), "지하 실황", 96, _PAPER, _INK, 0.0)
	_shout(Vector2(560.0, 96.0), "호외", 62, _SPOT, _INK, 0.0)
	# 제호가 화면 밖으로 잘려 나간다. 지면이 화면보다 크다는 표시다.
	_shout(Vector2(1120.0, 110.0), "열람 제한", 108, _OCHRE, _INK, 0.0)


func _draw_board() -> void:
	var rooms := SketchStage.placed(Vector2(80.0, 60.0), 1.05)
	for link in SketchStage.LINKS:
		var from := SketchStage.screen_of(rooms, link[0])
		var to := SketchStage.screen_of(rooms, link[1])
		var live: bool = link[2] == "live"
		draw_line(from, to, _INK, 10.0 if live else 3.0)
	for room in rooms:
		var rect := Rect2((room["screen"] as Vector2) - _TILE * 0.5, _TILE)
		draw_rect(rect, _PAPER)
		draw_rect(rect, _INK, false, 6.0)
		_text(rect.position + Vector2(10.0, 28.0), room["name"] as String, 20, _INK)
		var value: String = room["value"]
		var width := _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 52).x
		_text(Vector2(rect.end.x - 12.0 - width, rect.end.y - 12.0), value, 52, _INK)


## **먹칠.** 화면의 절반을 덮는다. 이게 이 방향의 전부다.
func _draw_bars() -> void:
	for entry in _BARS:
		var rect: Rect2 = entry[0]
		draw_set_transform(rect.get_center(), deg_to_rad(entry[1] as float), Vector2.ONE)
		draw_rect(Rect2(-rect.size * 0.5, rect.size), _INK)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 덮고 나서 위에 찍는 것들. 도장은 반듯할 이유가 없다.
func _draw_stamps() -> void:
	_stamp(Vector2(300.0, 330.0), "삭 제", 74, -7.0, _SPOT)
	_stamp(Vector2(1080.0, 520.0), "유 출", 88, 5.0, _SPOT)
	_stamp(Vector2(190.0, 690.0), "확 인 요", 52, -3.0, _OCHRE)
	# 도장은 종이를 뚫고 지나간다 — 막대 위에도 찍힌다.
	_stamp(Vector2(700.0, 176.0), "1 면 톱", 60, 2.0, _OCHRE)


func _stamp(centre: Vector2, text: String, size: int, degrees: float, color: Color) -> void:
	draw_set_transform(centre, deg_to_rad(degrees), Vector2.ONE)
	var extent := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var box := Rect2(-extent * 0.5 - Vector2(18.0, 6.0), extent + Vector2(36.0, 18.0))
	draw_rect(box, color, false, 7.0)
	draw_string(
		_font,
		Vector2(-extent.x * 0.5, extent.y * 0.28),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		size,
		color
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 덮이다 만 자리로 문장이 새어 나온다. 읽히는 것이 목적이 아니라 **덮였다는 사실**이 목적이다.
func _draw_caption() -> void:
	_text(Vector2(240.0, 232.0), SketchStage.BROADCAST_TITLE, 40, _INK)
	_text(Vector2(240.0, 370.0), SketchStage.BROADCAST_BODY, 26, _INK)
	_text(Vector2(760.0, 566.0), SketchStage.INSTRUMENT_TITLE, 24, _INK)
	_text(Vector2(760.0, 660.0), SketchStage.INSTRUMENT_VALUE, 132, _SPOT)


func _draw_warning() -> void:
	draw_rect(Rect2(0.0, 812.0, 1600.0, 46.0), _OCHRE)
	_text(Vector2(40.0, 844.0), "과한 쪽 — 판의 절반이 덮이면 정보 설계와 정면으로 부딪힌다. 끝을 보려고 만든 스케치다.", 22, _INK)


func _shout(pos: Vector2, text: String, size: int, fill: Color, edge: Color, weight: float) -> void:
	if weight > 0.0:
		draw_string_outline(
			_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(weight), edge
		)
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, fill)


func _text(pos: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
