extends Control
## 방향 A — **지하 실황: 방송 그래픽 패키지.**
##
## 화면은 관제 장비가 아니라 **편집실에서 얹은 자막판**이다.
## 예능 자막처럼 크고, 노랗고, 기울어 있고, 자기 틀을 뚫고 나간다.
##
## 서명 후보: **12도 기울기.** 화면의 모든 판이 같은 각도로 기운다.
## 판만 축에 남고 그 위 그래픽은 전부 기울어, 판과 방송이 서로 다른 세계로 보인다.
##
## 이건 비교용 스케치다. 채택되면 토큰•테마•셰이더로 옮긴다.

const _FEED := preload("res://src/ui/style/sketch/shaders/sketch_feed.gdshader")

## 기울기. tan(12도).
const _LEAN := 0.2126

const _BLACK := Color(0.043, 0.039, 0.047)
const _WHITE := Color(0.976, 0.973, 0.961)
const _YELL := Color(1.0, 0.855, 0.078)
const _RED := Color(0.937, 0.145, 0.196)
const _CYAN := Color(0.239, 0.910, 0.898)
const _GREY := Color(0.376, 0.369, 0.400)

var _font: Font


func _ready() -> void:
	_font = SketchStage.font()


## 바탕은 카메라가 잡고 있는 그림이다. 그 위에 그래픽 패키지가 통째로 얹힌다.
func background_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _FEED
	material.set_shader_parameter("base_color", Color(0.098, 0.094, 0.114))
	material.set_shader_parameter("tint_color", Color(0.180, 0.161, 0.204))
	return material


func _draw() -> void:
	_draw_banner()
	_draw_board()
	_draw_closeup(Vector2(1108.0, 250.0))
	_draw_caption(Vector2(96.0, 726.0))
	_draw_counter(Vector2(1230.0, 96.0))


## 기울인 사각형. y 가 pivot 에서 멀수록 x 가 밀린다.
func _lean_rect(rect: Rect2, pivot: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for corner in [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	]:
		points.append(Vector2(corner.x + (pivot - corner.y) * _LEAN, corner.y))
	return points


## 화면 위를 가로지르는 채널 배너. **화면 밖으로 잘려 나간다.**
func _draw_banner() -> void:
	draw_colored_polygon(_lean_rect(Rect2(-80.0, -10.0, 1800.0, 96.0), 40.0), _BLACK)
	draw_colored_polygon(_lean_rect(Rect2(-80.0, 82.0, 1800.0, 9.0), 86.0), _YELL)
	_shout(Vector2(52.0, 66.0), "지하 실황", 54, _WHITE, _BLACK, 8.0)
	_shout(Vector2(360.0, 62.0), "제 12 화", 26, _YELL, _BLACK, 6.0)
	draw_colored_polygon(_lean_rect(Rect2(560.0, 12.0, 190.0, 56.0), 40.0), _RED)
	_shout(Vector2(586.0, 54.0), "생 방 송", 30, _WHITE, _BLACK, 5.0)


func _draw_board() -> void:
	var rooms := SketchStage.placed(Vector2(58.0, 118.0), 0.86)
	for link in SketchStage.LINKS:
		_draw_link(
			SketchStage.screen_of(rooms, link[0]),
			SketchStage.screen_of(rooms, link[1]),
			link[2] as String
		)
	for room in rooms:
		_draw_tile(room["screen"] as Vector2, room, 1.0)


## 통로는 두꺼운 갈매기 띠다. 갈 수 있는 길은 노랗고 굵다.
func _draw_link(from: Vector2, to: Vector2, state: String) -> void:
	var color := _YELL if state == "live" else (_RED if state == "shut" else _GREY)
	var width := 9.0 if state == "live" else 4.0
	if state == "dark":
		var direction := (to - from).normalized()
		var span := from.distance_to(to)
		var walked := 0.0
		while walked < span:
			var tail := minf(walked + 16.0, span)
			draw_line(from + direction * walked, from + direction * tail, color, width)
			walked += 28.0
		return
	draw_line(from, to, _BLACK, width + 8.0)
	draw_line(from, to, color, width)


## 방 하나. **평행사변형**이고, 이름은 검은 띠에 흰 글씨, 숫자는 틀 밖으로 튀어나온다.
func _draw_tile(center: Vector2, room: Dictionary, factor: float) -> void:
	var state: String = room["state"]
	var box := Rect2(center - Vector2(94.0, 42.0) * factor, Vector2(188.0, 84.0) * factor)
	var body := _lean_rect(box, center.y)
	var fill := _WHITE if state == "here" else Color(0.145, 0.137, 0.161)
	draw_colored_polygon(body, fill)
	var edge := _YELL if state == "here" else (_RED if state == "shut" else _GREY)
	draw_polyline(_closed(body), edge, 5.0 if state == "here" else 3.0)

	var bar := Rect2(box.position + Vector2(0.0, -1.0), Vector2(box.size.x * 0.74, 30.0 * factor))
	draw_colored_polygon(_lean_rect(bar, center.y), _BLACK if state != "here" else _RED)
	_shout(
		(
			box.position
			+ Vector2(16.0, 22.0) * factor
			+ Vector2((center.y - box.position.y) * _LEAN, 0)
		),
		room["name"] as String,
		int(17.0 * factor),
		_WHITE,
		_BLACK,
		0.0
	)
	var ink := _BLACK if state == "here" else _WHITE
	_shout(
		Vector2(box.end.x - 54.0 * factor, box.end.y + 10.0 * factor),
		room["value"] as String,
		int(46.0 * factor),
		ink,
		_YELL if state == "here" else _BLACK,
		7.0
	)
	if state == "shut":
		_draw_bars(box.position + Vector2(box.size.x - 62.0, box.size.y - 20.0), factor)


func _draw_bars(origin: Vector2, factor: float) -> void:
	for index in 3:
		var height := (7.0 + 5.0 * float(index)) * factor
		var rect := Rect2(origin + Vector2(float(index) * 9.0, -height), Vector2(6.0, height))
		draw_colored_polygon(_lean_rect(rect, origin.y), _RED if index < 2 else _GREY)


## 타일 하나를 크게. 스케일 대비를 보여 주는 자리다.
func _draw_closeup(center: Vector2) -> void:
	_shout(center + Vector2(-190.0, -110.0), "방 타일", 18, _YELL, _BLACK, 4.0)
	var room := {
		"name": SketchStage.CLOSEUP["name"],
		"value": SketchStage.CLOSEUP["value"],
		"state": "open",
	}
	_draw_tile(center, room, 2.0)


## 송출 자막. 화면 아래를 가로지르며 왼쪽으로 잘려 나간다.
func _draw_caption(origin: Vector2) -> void:
	var tag := Rect2(origin - Vector2(46.0, 46.0), Vector2(152.0, 52.0))
	draw_colored_polygon(_lean_rect(tag, origin.y), _RED)
	_shout(origin + Vector2(-28.0, -8.0), SketchStage.BROADCAST_TAG, 30, _WHITE, _BLACK, 6.0)
	var bar := Rect2(origin + Vector2(112.0, -50.0), Vector2(1400.0, 60.0))
	draw_colored_polygon(_lean_rect(bar, origin.y), _BLACK)
	_shout(origin + Vector2(136.0, -8.0), SketchStage.BROADCAST_TITLE, 34, _YELL, _BLACK, 0.0)
	var under := Rect2(origin + Vector2(112.0, 14.0), Vector2(980.0, 44.0))
	draw_colored_polygon(_lean_rect(under, origin.y + 36.0), _WHITE)
	_shout(origin + Vector2(132.0, 46.0), SketchStage.BROADCAST_BODY, 20, _BLACK, _WHITE, 0.0)


## 계측 값은 방송 문법을 쓰지 않는다 — 축에 반듯하게 남는다.
func _draw_counter(origin: Vector2) -> void:
	draw_rect(Rect2(origin, Vector2(300.0, 4.0)), _CYAN)
	_text(origin + Vector2(0.0, 30.0), SketchStage.INSTRUMENT_TITLE, 16, _CYAN)
	_text(origin + Vector2(0.0, 118.0), SketchStage.INSTRUMENT_VALUE, 92, _WHITE)
	_text(origin + Vector2(0.0, 150.0), SketchStage.INSTRUMENT_NOTE, 14, _GREY)
	draw_rect(Rect2(origin + Vector2(0.0, 168.0), Vector2(300.0, 1.0)), _GREY)


## 외곽선을 두른 글자. 방송 자막은 배경이 무엇이든 읽혀야 한다.
func _shout(pos: Vector2, text: String, size: int, fill: Color, edge: Color, weight: float) -> void:
	if weight > 0.0:
		draw_string_outline(
			_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(weight), edge
		)
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, fill)


func _text(pos: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array(points)
	out.append(points[0])
	return out
