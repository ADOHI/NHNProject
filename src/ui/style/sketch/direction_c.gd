extends Control
## 방향 C — **썸네일: 화면에 직접 그은 낙서.**
##
## 화면은 카메라 그림 그대로이고, 그 위에 렉카가 **빨간 펜으로 직접 그어 놓았다.**
## 동그라미 · 화살표 · 밑줄 · 가위표 · 감탄사. 조회수를 위해 그은 선이다.
##
## 서명 후보: **손으로 그은 획.** 자로 잰 선이 하나도 없고, 강조는 전부 떨리는 획으로 온다.
## 계측(카메라 그림)은 깨끗하고, 송출(낙서)은 삐뚤다 — 신뢰도가 필기감으로 갈린다.
##
## 이건 비교용 스케치다. 채택되면 토큰·테마·셰이더로 옮긴다.

const _FEED := preload("res://src/ui/style/sketch/shaders/sketch_feed.gdshader")

const _WHITE := Color(0.949, 0.957, 0.957)
const _BLACK := Color(0.043, 0.051, 0.055)
const _PEN := Color(0.949, 0.180, 0.180)
const _PEN2 := Color(1.0, 0.847, 0.157)
const _FEEDINK := Color(0.635, 0.686, 0.694)

const _TILE := Vector2(190.0, 84.0)

var _font: Font


func _ready() -> void:
	_font = SketchStage.font()


## 바탕은 카메라 그림 그대로다. 낙서는 그 위에 얹힌다.
func background_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _FEED
	material.set_shader_parameter("base_color", Color(0.114, 0.137, 0.145))
	material.set_shader_parameter("tint_color", Color(0.063, 0.086, 0.098))
	return material


func _draw() -> void:
	_draw_feed_furniture()
	_draw_board()
	_draw_scrawl()
	_draw_thumbnail_type()
	_draw_closeup(Vector2(1150.0, 234.0))


## 카메라 그림에 원래부터 찍혀 있는 것들. 얇고 반듯하고 조용하다 — 이게 사실 쪽이다.
func _draw_feed_furniture() -> void:
	draw_rect(Rect2(40.0, 34.0, 240.0, 1.0), _FEEDINK)
	_text(Vector2(40.0, 28.0), "CAM 07  관제실", 15, _FEEDINK)
	_text(Vector2(1330.0, 28.0), "T+12  REC", 15, _FEEDINK)
	for corner in [Vector2(40.0, 60.0), Vector2(1560.0, 60.0)]:
		var dir := 1.0 if corner.x < 800.0 else -1.0
		draw_line(corner, corner + Vector2(26.0 * dir, 0.0), _FEEDINK, 1.0)
		draw_line(corner, corner + Vector2(0.0, 26.0), _FEEDINK, 1.0)
	_text(Vector2(40.0, 856.0), SketchStage.INSTRUMENT_NOTE, 15, _FEEDINK)


func _draw_board() -> void:
	var rooms := SketchStage.placed(Vector2(30.0, -6.0), 1.02)
	for link in SketchStage.LINKS:
		var from := SketchStage.screen_of(rooms, link[0])
		var to := SketchStage.screen_of(rooms, link[1])
		var live: bool = link[2] == "live"
		draw_line(from, to, _WHITE if live else _FEEDINK, 2.0 if live else 1.0)
	for room in rooms:
		_draw_plain_tile(Rect2((room["screen"] as Vector2) - _TILE * 0.5, _TILE), room, 1.0)


## 방 타일은 꾸미지 않는다. 카메라가 잡은 칸일 뿐이다.
func _draw_plain_tile(rect: Rect2, room: Dictionary, factor: float) -> void:
	var here: bool = room["state"] == "here"
	draw_rect(rect, Color(0.078, 0.098, 0.106, 0.72))
	draw_rect(rect, _WHITE if here else _FEEDINK, false, 2.0 * factor if here else 1.0)
	_text(rect.position + Vector2(10.0, 24.0) * factor, room["name"] as String, int(16.0 * factor), _WHITE)
	var value: String = room["value"]
	var size := int((40.0 if here else 26.0) * factor)
	var width := _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(Vector2(rect.end.x - 12.0 * factor - width, rect.end.y - 12.0 * factor), value, size, _WHITE)


## 렉카가 그은 것들. 전부 손으로 그은 획이다.
func _draw_scrawl() -> void:
	var rooms := SketchStage.placed(Vector2(30.0, -6.0), 1.02)
	_scrawl_circle(SketchStage.screen_of(rooms, "r_here"), Vector2(132.0, 70.0), _PEN, 7.0, 3)
	_scrawl_text(SketchStage.screen_of(rooms, "r_here") + Vector2(-160.0, -76.0), "여기 지금 로또", 30, _PEN)
	_scrawl_arrow(
		SketchStage.screen_of(rooms, "r_here") + Vector2(-24.0, -62.0),
		SketchStage.screen_of(rooms, "r_here") + Vector2(-58.0, -28.0),
		_PEN,
		7.0
	)
	var vault := SketchStage.screen_of(rooms, "r_vault")
	_scrawl_cross(vault, Vector2(112.0, 54.0), _PEN2, 9.0)
	_scrawl_text(vault + Vector2(-30.0, 76.0), "못 올라감 ㅋㅋ", 26, _PEN2)
	var lift := SketchStage.screen_of(rooms, "r_lift")
	_scrawl_arrow(lift + Vector2(220.0, -110.0), lift + Vector2(70.0, -22.0), _PEN, 10.0)
	_scrawl_text(lift + Vector2(206.0, -122.0), "여기 비었음", 28, _PEN)
	_scrawl_line(
		SketchStage.screen_of(rooms, "r_altar") + Vector2(-70.0, 34.0),
		SketchStage.screen_of(rooms, "r_altar") + Vector2(66.0, 30.0),
		_PEN,
		6.0
	)


## 썸네일 글자. 크고 두꺼운 테두리를 두르고 화면 밖으로 잘려 나간다.
func _draw_thumbnail_type() -> void:
	var burst := Rect2(40.0, 660.0, 176.0, 92.0)
	_scrawl_polygon(burst, _PEN)
	_shout(Vector2(58.0, 726.0), "충 격", 46, _WHITE, _BLACK, 9.0)
	_shout(Vector2(238.0, 726.0), "금고 앞", 78, _PEN2, _BLACK, 12.0)
	_shout(Vector2(238.0, 812.0), "3인 난투 터짐", 78, _WHITE, _BLACK, 12.0)
	_text(Vector2(1150.0, 812.0), "조회 41,208", 24, _PEN)
	_scrawl_line(Vector2(1146.0, 822.0), Vector2(1350.0, 826.0), _PEN, 5.0)


func _draw_closeup(origin: Vector2) -> void:
	_text(origin + Vector2(0.0, -22.0), "방 하나 — 그림은 그대로, 낙서만 얹힌다", 15, _FEEDINK)
	var rect := Rect2(origin, _TILE * 1.7)
	_draw_plain_tile(
		rect,
		{
			"name": SketchStage.CLOSEUP["name"],
			"value": SketchStage.CLOSEUP["value"],
			"state": "open",
		},
		1.7
	)
	_scrawl_circle(rect.get_center() + Vector2(88.0, 34.0), Vector2(52.0, 40.0), _PEN, 6.0, 2)
	_scrawl_text(origin + Vector2(-18.0, 190.0), "여기부터 보세요", 26, _PEN)
	_text(origin + Vector2(0.0, 226.0), SketchStage.INSTRUMENT_TITLE + "  " + SketchStage.INSTRUMENT_VALUE, 22, _WHITE)


# ---------------------------------------------------------------------------
# 손으로 그은 획 — 자로 잰 선을 하나도 쓰지 않는다
# ---------------------------------------------------------------------------


## 떨림. 같은 자리에서는 늘 같은 값이 나와야 화면이 프레임마다 지직거리지 않는다.
func _wobble(seed: float) -> float:
	return fmod(absf(sin(seed * 12.9898) * 43758.5453), 1.0) - 0.5


func _scrawl_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	_stroke(_wobbled_path(from, to, 9.0, 1.0), color, width)


func _stroke(path: PackedVector2Array, color: Color, width: float) -> void:
	if path.size() < 2:
		return
	# 획을 두 번 긋는다. 잉크가 고르지 않은 펜의 느낌이 여기서 나온다.
	draw_polyline(path, Color(color.r, color.g, color.b, 0.42), width * 1.55)
	draw_polyline(path, color, width)


func _wobbled_path(from: Vector2, to: Vector2, amplitude: float, seed: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var normal := (to - from).orthogonal().normalized()
	var steps := 10
	for index in steps + 1:
		var ratio := float(index) / float(steps)
		var swell := sin(ratio * PI)
		points.append(
			from.lerp(to, ratio) + normal * _wobble(seed * 31.0 + float(index)) * amplitude * swell
		)
	return points


## 동그라미. 한 바퀴 반을 돌아 끝이 어긋난다 — 급하게 그은 표다.
func _scrawl_circle(center: Vector2, radii: Vector2, color: Color, width: float, seed: int) -> void:
	var points := PackedVector2Array()
	var steps := 46
	var turns := 1.18
	for index in steps + 1:
		var ratio := float(index) / float(steps)
		var angle := ratio * TAU * turns - 0.6
		var jitter := 1.0 + _wobble(float(seed) * 17.0 + float(index)) * 0.10
		points.append(center + Vector2(cos(angle), sin(angle)) * radii * jitter)
	_stroke(points, color, width)


## 화살표. 대가리는 획 두 개고 둘 다 삐뚤다.
func _scrawl_arrow(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	_stroke(_wobbled_path(from, to, 7.0, 3.0), color, width)
	var back := (from - to).normalized()
	for angle in [0.55, -0.55]:
		var wing := to + back.rotated(angle as float) * 34.0
		_stroke(_wobbled_path(to, wing, 4.0, 5.0 + angle), color, width)


func _scrawl_cross(center: Vector2, radii: Vector2, color: Color, width: float) -> void:
	_stroke(_wobbled_path(center - radii, center + radii, 8.0, 7.0), color, width)
	var flip := Vector2(radii.x, -radii.y)
	_stroke(_wobbled_path(center - flip, center + flip, 8.0, 11.0), color, width)


## 손글씨처럼 보이게 글자를 조금 기울이고 밑에 획을 하나 긋는다.
func _scrawl_text(pos: Vector2, text: String, size: int, color: Color) -> void:
	draw_set_transform(pos, deg_to_rad(-4.0), Vector2.ONE)
	draw_string_outline(_font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 7, _BLACK)
	draw_string(_font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 터지는 표. 정다각형을 쓰지 않고 반지름을 흔든다.
func _scrawl_polygon(rect: Rect2, color: Color) -> void:
	var points := PackedVector2Array()
	var center := rect.get_center()
	var steps := 16
	for index in steps:
		var angle := float(index) / float(steps) * TAU
		var reach := 1.0 if index % 2 == 0 else 0.72
		reach += _wobble(float(index) * 3.0) * 0.14
		points.append(center + Vector2(cos(angle), sin(angle)) * rect.size * 0.5 * reach)
	draw_colored_polygon(points, color)


func _shout(
	pos: Vector2, text: String, size: int, fill: Color, edge: Color, weight: float
) -> void:
	draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(weight), edge)
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, fill)


func _text(pos: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
