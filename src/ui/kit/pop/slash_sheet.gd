class_name SlashSheet
extends Control
## **참격 — 사선이 화면을 지배한다.** 부품 한 벌을 P5 계열 문법으로.
##
## docs/design/20-ui-kit.md §20.28.
##
##     godot --path . -s res://tools/capture_pop.gd -- .renders/pop-slash slash
##
## ## 물질을 흉내 내지 않는다
##
## 앞의 판들은 전부 **「이 UI 는 무슨 물질인가」**를 물었다 — 돌 · 금박 · 신문지 · 쇳물.
## 그게 기각당한 이유다. 여기서는 **그래픽 디자인으로 승부한다.**
##
## | 문법 | 여기서 |
## | --- | --- |
## | 판이 직사각형이 아니다 | 전부 평행사변형이거나 모서리가 잘렸다 |
## | 판이 여러 겹 겹친다 | 뒤판이 어긋나 삐져나온다 (그림자가 아니라 **판 한 겹 더**) |
## | 글자가 도형이다 | 제목이 기울고 판에 잘리고 판 밖으로 넘친다 |
## | 색이 둘셋뿐인데 세다 | 검정 · 미색 · 진홍 **셋뿐** |
## | 무늬가 그래픽 | 사선 줄무늬와 망점이 **평평하게** 깔리고 흐른다 |
## | 움직임이 스냅 | 미끄러져 들어와 **탁 멈춘다.** 느리게 빛나지 않는다 |
##
## **입자도 아지랑이도 없다.**

const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")
const DARK := preload("res://src/ui/kit/cel/phosphor_dark.gdshader")
const LIT := preload("res://src/ui/kit/cel/phosphor_lit.gdshader")

const CARD := Vector2(660.0, 700.0)
const LOOP := 4.0
const PAD := 26.0

## 판이 미끄러져 들어오는 거리와 시간.
const SLIDE := 190.0
const SNAP := 0.34

## 색은 **`HoloPalette` 한 곳에서만** 정해진다 (§20.31). 화면은 번호만 든다 —
## 색만 바꿔 여러 장을 찍으려면 바꾸는 자리가 한 줄이어야 한다.
var palette := 0:
	set(value):
		palette = wrapi(value, 0, HoloPalette.count())
		_tint_screen()
		queue_redraw()

var _clock := 0.0
var _driven := false
var _dark: ColorRect
var _lit: ColorRect


func _ready() -> void:
	# 브라운관 덮개 둘. **곱하기 층과 더하기 층이라 어둡게도 밝게도 한다** (§20.29.2).
	_dark = _screen_layer(DARK)
	_lit = _screen_layer(LIT)
	_tint_screen()
	set_process(not _driven)


## 덮개의 인광색을 팔레트에 맞춘다.
func _tint_screen() -> void:
	if _lit == null:
		return
	(_lit.material as ShaderMaterial).set_shader_parameter("glow", _accent())


func _void() -> Color:
	return HoloPalette.void_color(palette)


func _paper() -> Color:
	return HoloPalette.paper(palette)


func _accent() -> Color:
	return HoloPalette.accent(palette)


## 어긋난 뒤판의 색. **「혼합」 팔레트만 강조색과 다르다.**
func _back() -> Color:
	return HoloPalette.back(palette)


func _screen_layer(source: Shader) -> ColorRect:
	var layer := ColorRect.new()
	layer.color = Color.WHITE
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stuff := ShaderMaterial.new()
	stuff.shader = source
	stuff.set_shader_parameter("card", CARD)
	layer.material = stuff
	add_child(layer)
	layer.size = CARD
	return layer


func drive_externally() -> void:
	_driven = true
	set_process(false)


func _process(delta: float) -> void:
	set_clock(fposmod(_clock + delta, LOOP))


func set_clock(t: float) -> void:
	_clock = t
	for layer in [_dark, _lit]:
		if layer != null:
			(layer.material as ShaderMaterial).set_shader_parameter("clock", t)
	queue_redraw()


## 판이 **위에서부터 한 줄씩 그려진다.** 다 그려지면 원래 판 그대로다.
##
## 「호박」에서 만든 표시 방법을 그대로 가져왔다 — 형태는 안 건드린다.
func _reveal(shape: PackedVector2Array, from: float) -> Array[PackedVector2Array]:
	var since := _clock - from
	var tall := GraphicCut.span_of(shape).size.y
	if since >= tall * 0.0026:
		return [shape] as Array[PackedVector2Array]
	return GraphicCut.revealed(shape, since / 0.0026)


## 채워진 판 위의 **주사선.** 망점이 있던 자리다 — 무늬만 바뀌고 판은 그대로다.
func _scanlines(shape: PackedVector2Array, tint: Color) -> void:
	for bar in GraphicCut.stripes(shape, 0.0, 4.0, 1.6, _clock * 9.0):
		draw_colored_polygon(bar, tint)


## 모서리 꺾쇠와 작은 눈금. **큰 판 가장자리에 붙는 장식**이지 판을 대신하지 않는다.
func _rig(box: Rect2, slot: int) -> void:
	var reach := 13.0
	var corners := [
		[box.position, Vector2(1, 0), Vector2(0, 1)],
		[Vector2(box.end.x, box.position.y), Vector2(-1, 0), Vector2(0, 1)],
		[box.end, Vector2(-1, 0), Vector2(0, -1)],
		[Vector2(box.position.x, box.end.y), Vector2(1, 0), Vector2(0, -1)],
	]
	for corner in corners:
		var at: Vector2 = corner[0]
		draw_line(at, at + (corner[1] as Vector2) * reach, _accent(), 2.0)
		draw_line(at, at + (corner[2] as Vector2) * reach, _accent(), 2.0)
	for i in 9:
		var x := lerpf(box.position.x + 16.0, box.end.x - 16.0, float(i) / 8.0)
		var wobble := CelReadout.tick_jitter(slot + i, _clock, 0.6)
		draw_line(
			Vector2(x, box.end.y + 4.0),
			Vector2(x, box.end.y + 8.0 + wobble),
			Color(_accent(), 0.5),
			1.0
		)
	draw_string(
		FONT,
		Vector2(box.position.x + 2.0, box.position.y - 5.0),
		"%s %s" % [CelReadout.noise_hex(slot, _clock), CelReadout.noise_digits(slot, _clock, 3)],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		9,
		Color(_accent(), 0.65)
	)


## 스냅. **끝에서 살짝 넘겼다가 탁 선다** — 부드럽게 도착하면 P5 가 아니다.
func _snap(from: float, span: float = SNAP) -> float:
	var t := clampf((_clock - from) / span, 0.0, 1.0)
	if t >= 1.0:
		return 1.0
	var eased := 1.0 - pow(1.0 - t, 4.0)
	return eased + sin(t * PI) * 0.06


## 짧게 튀는 어긋남. **글리치는 길면 고장이고 짧으면 문법이다.**
func _jolt(at: float, span: float = 0.10) -> float:
	if _clock < at or _clock > at + span:
		return 0.0
	return 1.0 - (_clock - at) / span


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _void(), true)
	_backdrop()
	_title()
	_buttons()
	_window()
	_popup()
	_menu()
	_inputs()
	_here()
	_weak()


## 바탕 — **평평한 사선 줄무늬가 화면 전체를 흐른다.** 재질이 아니라 무늬다.
func _backdrop() -> void:
	var whole := PackedVector2Array(
		[Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]
	)
	for bar in GraphicCut.stripes(whole, -PI * 0.28, 46.0, 15.0, _clock * 34.0):
		draw_colored_polygon(bar, Color(_paper(), 0.045))
	# 굵은 사선 한 줄이 화면을 가로지른다. 이 안의 서명이다.
	var sweep := fposmod(_clock * 0.34, 1.0)
	var band := GraphicCut.lean(
		Rect2(-260.0 + sweep * (size.x + 520.0), -40.0, 90.0, size.y + 80.0), 0.42
	)
	draw_colored_polygon(band, Color(_accent(), 0.10))


## 제목 — **글자가 도형이다.** 기울고, 검은 판에 잘리고, 판 밖으로 넘친다.
func _title() -> void:
	var slab := GraphicCut.lean(Rect2(-30.0, 22.0, 340.0, 62.0), 0.30)
	draw_colored_polygon(GraphicCut.swelled(slab, 0.012, Vector2(7.0, 7.0)), _back())
	draw_colored_polygon(slab, _paper())
	# 글자를 판보다 크게 잡아 오른쪽으로 넘긴다.
	draw_set_transform(Vector2(24.0, 74.0), -0.075, Vector2.ONE)
	draw_string(FONT, Vector2.ZERO, "참격", HORIZONTAL_ALIGNMENT_LEFT, -1, 54, _void())
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_string(
		FONT,
		Vector2(PAD, 108.0),
		"베고 지나간 자리. 멈추지 않는다",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		Color(_paper(), 0.66)
	)


## 버튼 넷 — 기본 · 올림 · 눌림 · 비활성. 전부 평행사변형이다.
func _buttons() -> void:
	var labels := ["기본", "올림", "눌림", "비활성"]
	var wide := (size.x - PAD * 2.0 - 30.0) / 4.0
	for i in 4:
		var enter := _snap(0.06 + float(i) * 0.055)
		var box := Rect2(PAD + float(i) * (wide + 10.0) - (1.0 - enter) * SLIDE, 132.0, wide, 50.0)
		var shape := GraphicCut.lean(box, 0.24)
		var hot := i == 1 and _clock > 0.90 and _clock < 1.55
		var down := i == 2 and _clock > 1.55 and _clock < 1.95
		if down:
			shape = GraphicCut.swelled(shape, -0.03, Vector2(4.0, 4.0))

		# 뒤판 — **그림자가 아니라 판 한 겹 더**라서 어긋나 있고 색이 있다.
		if i != 3:
			draw_colored_polygon(
				GraphicCut.swelled(shape, 0.02, Vector2(8.0, 8.0)),
				_back() if not down else _paper()
			)
		draw_colored_polygon(shape, _paper() if not hot else _accent())
		if i == 3:
			for bar in GraphicCut.stripes(shape, -PI * 0.25, 9.0, 4.0, 0.0):
				draw_colored_polygon(bar, Color(_void(), 0.55))
		if hot:
			_scanlines(shape, Color(_void(), 0.30))
		_shape_text(labels[i], Rect2(box.position, box.size), 18, _void(), 0.35 if i == 3 else 1.0)


## 창 — 제목줄 · 테두리 · 닫기 · 배경. **모서리 둘이 잘렸다.**
func _window() -> void:
	var enter := _snap(0.24)
	var box := Rect2(PAD - (1.0 - enter) * SLIDE, 206.0, 336.0, 178.0)
	var shape := GraphicCut.clipped(box, 26.0, 2 | 8)
	# 뒤판이 **반투명해졌다** — 판 뒤에 다른 판이 비친다.
	draw_colored_polygon(GraphicCut.swelled(shape, 0.014, Vector2(9.0, 9.0)), Color(_back(), 0.55))
	var drawn := _reveal(shape, 0.24)
	if drawn.is_empty():
		return
	for piece in drawn:
		draw_colored_polygon(piece, _paper())
	if drawn.size() == 1 and drawn[0].size() != shape.size():
		return
	_scanlines(shape, Color(_void(), 0.12))
	_rig(box, 2)

	var bar := GraphicCut.lean(Rect2(box.position.x, box.position.y, box.size.x - 26.0, 34.0), 0.0)
	draw_colored_polygon(bar, _void())
	draw_string(
		FONT, box.position + Vector2(14.0, 24.0), "창", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, _paper()
	)
	var shut := Vector2(box.end.x - 46.0, box.position.y + 17.0)
	draw_line(shut + Vector2(-6, -6), shut + Vector2(6, 6), _paper(), 2.4)
	draw_line(shut + Vector2(-6, 6), shut + Vector2(6, -6), _paper(), 2.4)
	for row in 3:
		draw_colored_polygon(
			GraphicCut.lean(
				Rect2(
					box.position.x + 16.0,
					box.position.y + 58.0 + float(row) * 24.0,
					box.size.x - 40.0 - float(row) * 58.0,
					9.0
				),
				0.5
			),
			Color(_void(), 0.72 - float(row) * 0.18)
		)


## 팝업 — **사선으로 찢어지며 열린다.** 커지는 게 아니라 갈라지는 것이다.
func _popup() -> void:
	var open := _snap(2.00, 0.30)
	var box := Rect2(PAD + 356.0, 206.0, 252.0, 178.0)
	var shape := GraphicCut.clipped(box, 24.0, 1 | 4)
	for piece in GraphicCut.torn_open(shape, -PI * 0.22, open, 46.0):
		draw_colored_polygon(
			GraphicCut.swelled(piece, 0.012, Vector2(8.0, 8.0)), Color(_accent(), 0.55)
		)
		draw_colored_polygon(piece, _paper())
		_scanlines(piece, Color(_void(), 0.12))
	if open < 0.55:
		return
	_rig(box, 5)
	_shape_text(
		"버릴까요", Rect2(box.position + Vector2(0.0, 26.0), Vector2(box.size.x, 34.0)), 24, _void()
	)
	draw_string(
		FONT,
		box.position + Vector2(0.0, 92.0),
		"되돌릴 수 없습니다",
		HORIZONTAL_ALIGNMENT_CENTER,
		box.size.x,
		13,
		Color(_void(), 0.62)
	)
	var wide := (box.size.x - 40.0) * 0.5
	for i in 2:
		var button := Rect2(
			box.position.x + 14.0 + float(i) * (wide + 12.0), box.end.y - 54.0, wide, 38.0
		)
		var solid := i == 0
		var shape_button := GraphicCut.lean(button, 0.22)
		if solid:
			draw_colored_polygon(GraphicCut.swelled(shape_button, 0.03, Vector2(5.0, 5.0)), _void())
		draw_colored_polygon(shape_button, _accent() if solid else Color(_void(), 0.10))
		_shape_text("확인" if solid else "취소", button, 16, _void())


## 메뉴 — 항목 넷, 하나 선택됨. **「지금 여기」는 여기 하나에서만 흐른다.**
func _menu() -> void:
	var enter := _snap(0.42)
	var box := Rect2(PAD - (1.0 - enter) * SLIDE, 404.0, 292.0, 168.0)
	var shape := GraphicCut.clipped(box, 22.0, 4)
	draw_colored_polygon(shape, Color(_paper(), 0.10))
	var items := ["출격", "길드", "인물", "설정"]
	# 고른 자리가 2 번에서 시작해 2.9 초에 아래로 **슬램**한다.
	var chosen := 1 if _clock < 2.85 else 2
	var slam := _snap(2.85, 0.16)
	for i in 4:
		var row := Rect2(
			box.position.x + 12.0, box.position.y + 14.0 + float(i) * 36.0, box.size.x - 24.0, 32.0
		)
		var shape_row := GraphicCut.lean(row, 0.20)
		if i == chosen:
			var grow := 1.0 if _clock < 2.85 else slam
			var lit := GraphicCut.swelled(shape_row, 0.03 * grow, Vector2(6.0, 6.0) * grow)
			draw_colored_polygon(lit, _void())
			draw_colored_polygon(shape_row, _accent())
			_scanlines(shape_row, Color(_void(), 0.26))
		draw_string(
			FONT,
			row.position + Vector2(22.0, 23.0),
			items[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			17,
			_void() if i == chosen else Color(_paper(), 0.55)
		)


## 슬라이더와 체크 — 둘 다 기울어 있다.
func _inputs() -> void:
	var enter := _snap(0.50)
	var box := Rect2(PAD + 312.0 + (1.0 - enter) * SLIDE, 404.0, 296.0, 168.0)
	draw_colored_polygon(GraphicCut.clipped(box, 22.0, 1), Color(_paper(), 0.10))
	draw_string(
		FONT,
		box.position + Vector2(20.0, 34.0),
		"소리",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		Color(_paper(), 0.7)
	)

	var rail := Rect2(box.position.x + 20.0, box.position.y + 46.0, box.size.x - 40.0, 8.0)
	draw_colored_polygon(GraphicCut.lean(rail, 0.9), Color(_paper(), 0.18))
	draw_colored_polygon(
		GraphicCut.lean(Rect2(rail.position, Vector2(rail.size.x * 0.62, rail.size.y)), 0.9),
		_accent()
	)
	var knob := Rect2(
		rail.position.x + rail.size.x * 0.62 - 8.0, rail.position.y - 11.0, 18.0, 30.0
	)
	draw_colored_polygon(
		GraphicCut.swelled(GraphicCut.lean(knob, 0.4), 0.04, Vector2(4.0, 4.0)), _void()
	)
	draw_colored_polygon(GraphicCut.lean(knob, 0.4), _paper())

	var tick := Rect2(box.position.x + 20.0, box.position.y + 96.0, 26.0, 26.0)
	var shape_tick := GraphicCut.lean(tick, 0.22)
	draw_colored_polygon(GraphicCut.swelled(shape_tick, 0.04, Vector2(5.0, 5.0)), _void())
	draw_colored_polygon(shape_tick, _accent())
	draw_polyline(
		PackedVector2Array(
			[
				tick.position + Vector2(9.0, 13.0),
				tick.position + Vector2(14.0, 19.0),
				tick.position + Vector2(24.0, 5.0)
			]
		),
		_paper(),
		3.2
	)
	draw_string(
		FONT,
		Vector2(tick.end.x + 16.0, tick.position.y + 19.0),
		"전체 화면",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		15,
		_paper()
	)


## 강조 — **한 줄로 화면을 가른다.** 글자가 판을 넘는다.
func _here() -> void:
	var enter := _snap(0.60)
	var box := Rect2(PAD - (1.0 - enter) * SLIDE * 1.6, 596.0, size.x - PAD * 2.0, 58.0)
	var shape := GraphicCut.fang(Rect2(box.position, box.size - Vector2(26.0, 0.0)), 26.0)
	draw_colored_polygon(GraphicCut.swelled(shape, 0.012, Vector2(9.0, 9.0)), _paper())
	draw_colored_polygon(shape, _accent())
	_scanlines(shape, Color(_void(), 0.22))
	_rig(Rect2(box.position, box.size - Vector2(26.0, 0.0)), 8)
	draw_string(
		FONT,
		Vector2(PAD, 588.0),
		"강조 — 지금 여기",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		Color(_paper(), 0.5)
	)
	_shape_text("3층 봉인된 문", box, 24, _void())


func _weak() -> void:
	draw_string(
		FONT,
		Vector2(PAD, size.y - 20.0),
		"약한 곳 — 사선이 전부라 잔잔한 화면을 못 만든다. 목록이 길면 눈이 미끄러진다",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		_accent()
	)


## 글자를 **도형처럼** 얹는다. 살짝 기울고, 어긋난 그림자가 한 겹 있다.
##
## 색 분리(RGB split)를 흉내 내지 않고 **두 색으로 어긋나게 두 번 찍는다** —
## 색이 셋뿐인 문법에서 네 번째 색을 만들지 않으려는 것이다.
func _shape_text(text: String, box: Rect2, tall: int, tint: Color, fade: float = 1.0) -> void:
	var jolt := maxf(_jolt(1.62), _jolt(2.88))
	var lean := -0.045
	var seat := Vector2(box.position.x, box.get_center().y + float(tall) * 0.36)
	if jolt > 0.0:
		draw_set_transform(seat + Vector2(-3.0 * jolt, 0.0), lean, Vector2.ONE)
		draw_string(
			FONT,
			Vector2.ZERO,
			text,
			HORIZONTAL_ALIGNMENT_CENTER,
			box.size.x,
			tall,
			Color(_accent(), 0.85 * jolt)
		)
	draw_set_transform(seat + Vector2(2.0, 2.0), lean, Vector2.ONE)
	draw_string(
		FONT,
		Vector2.ZERO,
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		box.size.x,
		tall,
		Color(_void(), 0.28 * fade)
	)
	draw_set_transform(seat, lean, Vector2.ONE)
	draw_string(
		FONT, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, tall, Color(tint, fade)
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
