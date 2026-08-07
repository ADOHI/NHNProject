extends Control
## 방향 B — **호외: 인쇄된 판.**
##
## 화면은 장비가 아니라 **이번 턴의 호외 한 장**이다. 렉카는 유출로 먹고사는 자이고,
## 유출한 자가 내놓는 물건은 방송 장비가 아니라 **간행물**이다.
##
## 서명 후보: **오정합.** 모든 것은 두 번 찍힌다 — 검은 판이 사실이고,
## 붉은 판은 늦게, 어긋나서 찍힌다. 어긋난 크기가 곧 부풀린 크기다.
##
## 그리고 망점의 굵기가 곧 모르는 정도다. 좋은 원판이 있으면 곱게 찍고 없으면 뭉개 찍는다.
##
## 이건 비교용 스케치다. 채택되면 토큰·테마·셰이더로 옮긴다.

const _PRESS := preload("res://src/ui/style/sketch/shaders/sketch_press.gdshader")
const _HALFTONE := preload("res://src/ui/style/sketch/shaders/sketch_halftone.gdshader")

const _PAPER := Color(0.910, 0.878, 0.804)
const _PAPER_HIGH := Color(0.957, 0.933, 0.871)
const _INK := Color(0.086, 0.071, 0.055)
const _INK_MUTED := Color(0.310, 0.271, 0.220)
const _INK_FAINT := Color(0.545, 0.494, 0.416)
const _RED := Color(0.827, 0.141, 0.165)
const _OCHRE := Color(0.804, 0.573, 0.075)

## 붉은 판이 어긋나는 방향과 기본 크기(px).
const _SLIP := Vector2(4.0, -3.0)

const _TILE := Vector2(190.0, 84.0)

## 상태별 인쇄 조건. 간격이 클수록 거칠고, 거칠수록 모르는 방이다.
const _SCREEN := {
	"here": {"pitch": 3.0, "density": 0.13},
	"open": {"pitch": 6.5, "density": 0.30},
	"shut": {"pitch": 6.5, "density": 0.33},
	"far": {"pitch": 12.0, "density": 0.44},
}

var _font: Font
var _overlay: Control


func _ready() -> void:
	_font = SketchStage.font()
	_add_paper()
	for room in SketchStage.placed(Vector2(30.0, -26.0), 1.15):
		_add_cell(
			Rect2((room["screen"] as Vector2) - _TILE * 0.5, _TILE), room["state"] as String, 1.0
		)
	_add_cell(Rect2(Vector2(1148.0, 500.0), _TILE * 1.7), "open", 1.7)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.draw.connect(_draw_sheet)


func _add_paper() -> void:
	var paper := ColorRect.new()
	var material := ShaderMaterial.new()
	material.shader = _PRESS
	material.set_shader_parameter("paper_color", _PAPER)
	material.set_shader_parameter("shade_color", Color(0.824, 0.780, 0.678))
	paper.material = material
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(paper)


## 망점으로 찍힌 사진 한 칸. 이 게임에서 사진이란 곧 **그 방의 카메라 그림**이다.
func _add_cell(rect: Rect2, state: String, factor: float) -> void:
	var spec: Dictionary = _SCREEN[state]
	var cell := ColorRect.new()
	var material := ShaderMaterial.new()
	material.shader = _HALFTONE
	material.set_shader_parameter("cell_size", rect.size)
	material.set_shader_parameter("paper_color", _PAPER_HIGH)
	material.set_shader_parameter("ink_color", _INK)
	material.set_shader_parameter("spot_color", _RED)
	material.set_shader_parameter("screen_pitch", (spec["pitch"] as float) * factor)
	material.set_shader_parameter("density", spec["density"])
	material.set_shader_parameter("spot_density", 0.0)
	cell.material = material
	cell.position = rect.position
	cell.size = rect.size
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cell)


func _draw_sheet() -> void:
	_draw_masthead()
	_draw_board()
	_draw_measure_column()
	_draw_closeup()
	_draw_clipping()


# ---------------------------------------------------------------------------
# 제호 — 신문은 제호가 가장 크다
# ---------------------------------------------------------------------------


func _draw_masthead() -> void:
	_rule(Rect2(40.0, 20.0, 1520.0, 5.0), _INK)
	_rule(Rect2(40.0, 29.0, 1520.0, 1.0), _INK)
	_slipped(Vector2(44.0, 100.0), "지하 실황", 74, _INK, 1.0)
	_ink(Vector2(392.0, 100.0), "號 外", 46, _INK_MUTED)
	# 붉은 판은 늦게 찍혀 어긋난다. 여기가 그 규칙을 처음 보여 주는 자리다.
	_slipped(Vector2(1244.0, 98.0), "제 12 턴", 44, _RED, 2.4)
	_rule(Rect2(40.0, 118.0, 1520.0, 7.0), _INK)
	_ink(Vector2(44.0, 148.0), "연출부 유출 · 무단 전재 환영 · 조회수만이 진실이다", 15, _INK_MUTED)
	_rule(Rect2(40.0, 160.0, 1520.0, 1.0), _INK_FAINT)


# ---------------------------------------------------------------------------
# 판 — 1면에 실린 도해
# ---------------------------------------------------------------------------


func _draw_board() -> void:
	var rooms := SketchStage.placed(Vector2(30.0, -26.0), 1.15)
	for link in SketchStage.LINKS:
		_draw_link(
			SketchStage.screen_of(rooms, link[0]),
			SketchStage.screen_of(rooms, link[1]),
			link[2] as String
		)
	for room in rooms:
		_draw_frame(
			Rect2((room["screen"] as Vector2) - _TILE * 0.5, _TILE),
			room["name"] as String,
			room["value"] as String,
			room["state"] as String,
			1.0
		)


## 통로는 괘선이다. 지금 지나갈 수 있는 길만 굵은 실선으로 찍힌다.
func _draw_link(from: Vector2, to: Vector2, state: String) -> void:
	if state == "live":
		_overlay.draw_line(from, to, _INK, 6.0)
		return
	if state == "shut":
		# 막힌 길은 사라지지 않는다. 오커로 한 번 더 찍혀 "길은 있다"를 남긴다.
		_dashes(from, to, 14.0, 10.0, _OCHRE, 5.0)
		return
	_dashes(from, to, 5.0, 13.0, _INK_FAINT, 2.0)


func _dashes(from: Vector2, to: Vector2, dash: float, gap: float, color: Color, w: float) -> void:
	var span := from.distance_to(to)
	if span < 0.001:
		return
	var direction := (to - from) / span
	var walked := 0.0
	while walked < span:
		var tail := minf(walked + dash, span)
		_overlay.draw_line(from + direction * walked, from + direction * tail, color, w)
		walked += dash + gap


## 사진 한 칸을 둘러싼 **테와 캡션**. 신문 도해의 문법 그대로다.
func _draw_frame(rect: Rect2, room_name: String, value: String, state: String, factor: float) -> void:
	var heavy := state == "here"
	_overlay.draw_rect(rect, _INK, false, (5.0 if heavy else 2.0) * factor)
	if state == "shut":
		_overprint(rect, factor)

	# 이름은 사진 위에 얹힌 검은 띠에 흰 글씨로 찍는다.
	var bar := Rect2(rect.position, Vector2(rect.size.x, 26.0 * factor))
	_overlay.draw_rect(bar, _INK)
	_ink(
		rect.position + Vector2(9.0, 19.0) * factor,
		room_name,
		int(16.0 * factor),
		_PAPER_HIGH,
		_overlay
	)

	# 숫자는 오른쪽 아래. 내가 선 방만 붉은 판이 함께 찍혀 크게 흔들린다.
	var anchor := Vector2(rect.end.x - 20.0 * factor, rect.end.y - 12.0 * factor)
	var size := int((44.0 if heavy else 30.0) * factor)
	var width := _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if heavy:
		_slipped(anchor - Vector2(width, 0.0), value, size, _INK, 1.6, _overlay)
	else:
		_ink(anchor - Vector2(width, 0.0), value, size, _INK_MUTED, _overlay)

	if state == "here":
		_draw_onair(rect, factor)


## 오커 겹쳐찍기. "길은 있으나 못 오른다"는 색 하나에만 실리면 안 된다.
func _overprint(rect: Rect2, factor: float) -> void:
	var pitch := 15.0 * factor
	var offset := -rect.size.y
	while offset < rect.size.x:
		var a := rect.position + Vector2(offset, rect.size.y)
		var b := rect.position + Vector2(offset + rect.size.y, 0.0)
		_overlay.draw_line(
			a.clamp(rect.position, rect.end), b.clamp(rect.position, rect.end), _OCHRE, 5.0 * factor
		)
		offset += pitch


## 지금 그림이 나가는 방. 붉은 판이 테 밖으로 튀어나온다 — **틀을 뚫는다.**
func _draw_onair(rect: Rect2, factor: float) -> void:
	var tab := Rect2(
		rect.position + Vector2(-16.0 * factor, rect.size.y - 30.0 * factor),
		Vector2(94.0 * factor, 26.0 * factor)
	)
	_overlay.draw_rect(tab.grow(1.0), _RED)
	_ink(tab.position + Vector2(9.0, 19.0) * factor, "송출중", int(15.0 * factor), _PAPER_HIGH, _overlay)


# ---------------------------------------------------------------------------
# 계측 — 축에 반듯하다. 흔들리지 않는다
# ---------------------------------------------------------------------------


func _draw_measure_column() -> void:
	var x := 1148.0
	_overlay.draw_line(Vector2(1112.0, 180.0), Vector2(1112.0, 862.0), _INK, 2.0)
	_ink(Vector2(x, 208.0), SketchStage.INSTRUMENT_TITLE, 17, _INK_MUTED)
	_rule(Rect2(x, 220.0, 400.0, 1.0), _INK_FAINT)
	_ink(Vector2(x - 6.0, 348.0), SketchStage.INSTRUMENT_VALUE, 168, _INK)
	_ink(Vector2(x + 132.0, 348.0), "+2", 40, _RED)
	_rule(Rect2(x, 368.0, 400.0, 4.0), _INK)
	_ink(Vector2(x, 400.0), SketchStage.INSTRUMENT_NOTE, 16, _INK_MUTED)
	_ink(Vector2(x, 434.0), "판독 3 / 3   원판 양호", 14, _INK_FAINT)
	_rule(Rect2(x, 448.0, 400.0, 1.0), _INK_FAINT)


func _draw_closeup() -> void:
	_ink(Vector2(1148.0, 486.0), "방 하나 — 망점이 굵을수록 모르는 방이다", 14, _INK_MUTED)
	_draw_frame(
		Rect2(Vector2(1148.0, 500.0), _TILE * 1.7),
		SketchStage.CLOSEUP["name"] as String,
		SketchStage.CLOSEUP["value"] as String,
		"open",
		1.7
	)
	_ink(Vector2(1148.0, 668.0), "내림 1", 20, _INK)


# ---------------------------------------------------------------------------
# 송출 — 오려 붙인 조각. 축에서 벗어나고 가장자리가 찢겨 있다
# ---------------------------------------------------------------------------


func _draw_clipping() -> void:
	var origin := Vector2(96.0, 700.0)
	var size := Vector2(940.0, 168.0)
	_overlay.draw_set_transform(origin + size * 0.5, deg_to_rad(-2.4), Vector2.ONE)
	var rect := Rect2(-size * 0.5, size)
	_overlay.draw_colored_polygon(_deckle(rect, 7.0), _PAPER_HIGH)
	_overlay.draw_polyline(_deckle_closed(rect, 7.0), _INK_FAINT, 1.0)

	var tag := Rect2(rect.position + Vector2(-18.0, 18.0), Vector2(112.0, 46.0))
	_overlay.draw_rect(tag, _RED)
	_ink(tag.position + Vector2(14.0, 34.0), SketchStage.BROADCAST_TAG, 28, _PAPER_HIGH, _overlay)

	_slipped(rect.position + Vector2(122.0, 62.0), SketchStage.BROADCAST_TITLE, 40, _INK, 3.2, _overlay)
	_overlay.draw_rect(Rect2(rect.position + Vector2(24.0, 82.0), Vector2(880.0, 2.0)), _INK)
	_ink(rect.position + Vector2(24.0, 118.0), SketchStage.BROADCAST_BODY, 21, _INK_MUTED, _overlay)
	_ink(rect.position + Vector2(24.0, 148.0), "조회 41,208 · 지하 실황 채널", 15, _RED, _overlay)
	_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 찢긴 가장자리. 오려 낸 조각은 자로 자른 것이 아니다.
func _deckle(rect: Rect2, amplitude: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var step := 26.0
	var seed := 0.0
	for corner_pair in [
		[rect.position, Vector2(rect.end.x, rect.position.y)],
		[Vector2(rect.end.x, rect.position.y), rect.end],
		[rect.end, Vector2(rect.position.x, rect.end.y)],
		[Vector2(rect.position.x, rect.end.y), rect.position],
	]:
		var from: Vector2 = corner_pair[0]
		var to: Vector2 = corner_pair[1]
		var span := from.distance_to(to)
		var normal := (to - from).orthogonal().normalized()
		var count := maxi(2, int(span / step))
		for index in count:
			var ratio := float(index) / float(count)
			seed += 1.0
			var wobble := sin(seed * 12.9898) * 43758.5453
			points.append(from.lerp(to, ratio) + normal * (fmod(absf(wobble), 1.0) - 0.5) * amplitude)
	return points


func _deckle_closed(rect: Rect2, amplitude: float) -> PackedVector2Array:
	var points := _deckle(rect, amplitude)
	points.append(points[0])
	return points


# ---------------------------------------------------------------------------
# 찍는 법
# ---------------------------------------------------------------------------


## 두 판으로 찍는다. 붉은 판이 먼저 어긋난 자리에 오고, 검은 판이 제자리에 온다.
func _slipped(
	pos: Vector2, text: String, size: int, color: Color, slip: float, target: CanvasItem = null
) -> void:
	var canvas: CanvasItem = target if target != null else _overlay
	var ghost := _RED if color != _RED else _INK
	canvas.draw_string(
		_font,
		pos + _SLIP * slip,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		size,
		Color(ghost.r, ghost.g, ghost.b, 0.82)
	)
	canvas.draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _ink(
	pos: Vector2, text: String, size: int, color: Color, target: CanvasItem = null
) -> void:
	var canvas: CanvasItem = target if target != null else _overlay
	canvas.draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _rule(rect: Rect2, color: Color) -> void:
	_overlay.draw_rect(rect, color)
