class_name AmberSheet
extends Control
## **호박(琥珀) — 계기판.** 90년대 셀 애니메의 SF 홀로그램, 인광 호박색.
##
## docs/design/20-ui-kit.md §20.29.
##
##     godot --path . -s res://tools/capture_pop.gd -- .renders/cel-amber amber
##
## ## 미니멀 형태 + 맥시멀 효과
##
## 「참격」은 **형태가 화려했다**(평행사변형 · 찢김). 여기는 반대다 —
## **형태는 얇은 직사각 테두리와 꺾쇠와 눈금뿐**이고, 화려함은 전부 그 위에 얹은
## 효과로 온다: 주사선 · 잔광 · 훑는 띠 · 한 줄씩 그려지기 · 인터레이스 떨림.
##
## ## 네온이 아니다
##
## 형광 청록·자홍은 2010년대 사이버펑크다. **셀 시대의 홀로그램은 인광**이라
## 채도가 낮고 따뜻하다 — 호박색 · 뼈흰색, 바탕은 순검정이 아니라 **따뜻한 먹빛**.
##
## ## 아무 정보도 없는 정보
##
## 화면 구석에 뜻 없는 숫자열과 눈금이 잔뜩이다(`CelReadout`). 그게 「손으로 그린
## 미래」의 핵심이다 — 다만 **장식은 흐리고 작게, 진짜 신호는 하나만.**

const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")
const DARK := preload("res://src/ui/kit/cel/phosphor_dark.gdshader")
const LIT := preload("res://src/ui/kit/cel/phosphor_lit.gdshader")

const CARD := Vector2(660.0, 700.0)
const LOOP := 4.0
const PAD := 28.0

## 바탕은 **순검정이 아니라 따뜻한 먹빛**이다.
const GROUND := Color("#14100a")

## 인광 호박. 밝은 것과 그 잔광.
const AMBER := Color("#ffb54a")
const AMBER_DIM := Color("#9a6a2c")

## 뼈흰색. 글자가 이 색이라 호박이 신호로 남는다.
const BONE := Color("#efe6d2")

var _clock := 0.0
var _driven := false
var _dark: ColorRect
var _lit: ColorRect


static func card() -> Vector2:
	return CARD


static func loop() -> float:
	return LOOP


func _ready() -> void:
	_build_screen()
	set_process(not _driven)


func drive_externally() -> void:
	_driven = true
	set_process(false)


func _process(delta: float) -> void:
	set_clock(fposmod(_clock + delta, LOOP))


func set_clock(t: float) -> void:
	_clock = t
	for layer in [_dark, _lit]:
		if layer != null:
			var stuff := layer.material as ShaderMaterial
			stuff.set_shader_parameter("clock", t)
	queue_redraw()


## 브라운관 덮개 둘. **곱하기 층과 더하기 층이라 어둡게도 밝게도 한다.**
func _build_screen() -> void:
	_dark = _screen_layer(DARK)
	_lit = _screen_layer(LIT)
	var stuff := _lit.material as ShaderMaterial
	stuff.set_shader_parameter("glow", AMBER)


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


## 나타남. 판이 **한 줄씩 그려진다** — 통째로 뜨지 않는다.
func _rows_of(box: Rect2, from: float) -> int:
	return CelReadout.drawn_rows(int(box.size.y), _clock - from, 0.0022)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), GROUND, true)
	_grid()
	_title()
	_buttons()
	_window()
	_popup()
	_menu()
	_inputs()
	_here()
	_chrome()


## 얇은 격자. **정보가 아니라 바닥이다.**
func _grid() -> void:
	for i in int(size.x / 22.0) + 1:
		var x := float(i) * 22.0
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), Color(AMBER_DIM, 0.07), 1.0)
	for i in int(size.y / 22.0) + 1:
		var y := float(i) * 22.0
		draw_line(Vector2(0.0, y), Vector2(size.x, y), Color(AMBER_DIM, 0.07), 1.0)


## 모서리 꺾쇠. **테두리를 다 그리지 않는다** — 네 귀퉁이만 있으면 판이 읽힌다.
func _brackets(box: Rect2, reach: float, tint: Color, thick: float = 1.6) -> void:
	var corners := [
		[box.position, Vector2(1, 0), Vector2(0, 1)],
		[Vector2(box.end.x, box.position.y), Vector2(-1, 0), Vector2(0, 1)],
		[box.end, Vector2(-1, 0), Vector2(0, -1)],
		[Vector2(box.position.x, box.end.y), Vector2(1, 0), Vector2(0, -1)],
	]
	for corner in corners:
		var at: Vector2 = corner[0]
		draw_line(at, at + (corner[1] as Vector2) * reach, tint, thick)
		draw_line(at, at + (corner[2] as Vector2) * reach, tint, thick)


## 판 하나. 얇은 테두리 + 꺾쇠 + 아주 옅은 면. **형태는 여기서 끝난다.**
func _panel(box: Rect2, from: float, lit: bool = false) -> void:
	var rows := _rows_of(box, from)
	if rows <= 0:
		return
	var shown := Rect2(box.position, Vector2(box.size.x, float(rows)))
	draw_rect(shown, Color(AMBER_DIM, 0.10 if not lit else 0.16), true)
	# 그려지는 중에는 **맨 아랫줄이 밝다** — 지금 그려지고 있는 줄이다.
	if rows < int(box.size.y):
		draw_line(
			Vector2(box.position.x, box.position.y + float(rows)),
			Vector2(box.end.x, box.position.y + float(rows)),
			AMBER,
			1.6
		)
		return
	draw_rect(box, Color(AMBER, 0.34), false, 1.0)
	_brackets(box, 12.0, AMBER)


## 눈금 자. 변을 따라 짧은 선이 늘어서고 **의미 없이 미세하게 흔들린다.**
func _ruler(from: Vector2, to: Vector2, count: int, reach: float, slot: int) -> void:
	var step := (to - from) / float(count)
	var normal := (to - from).orthogonal().normalized()
	for i in count + 1:
		var at := from + step * float(i)
		var long := i % 5 == 0
		var wobble := CelReadout.tick_jitter(slot + i, _clock, 0.7)
		draw_line(
			at,
			at + normal * ((reach if long else reach * 0.45) + wobble),
			Color(AMBER, 0.55 if long else 0.28),
			1.0
		)


func _title() -> void:
	draw_string(FONT, Vector2(PAD, 52.0), "호박", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, BONE)
	draw_string(
		FONT,
		Vector2(PAD, 76.0),
		"1995년의 사람이 그린 미래의 계기판",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		Color(BONE, 0.55)
	)
	_ruler(Vector2(PAD, 90.0), Vector2(size.x - PAD, 90.0), 40, 6.0, 3)


## 버튼 넷. **형태는 얇은 테두리뿐**이고 상태는 빛과 잔광으로 갈린다.
func _buttons() -> void:
	var labels := ["기본", "올림", "눌림", "비활성"]
	var wide := (size.x - PAD * 2.0 - 30.0) / 4.0
	var hot := 1 if _clock > 0.85 and _clock < 1.60 else -1
	var down := 2 if _clock > 1.60 and _clock < 1.95 else -1
	for i in 4:
		var box := Rect2(PAD + float(i) * (wide + 10.0), 108.0, wide, 46.0)
		var live := i == hot
		var pushed := i == down
		var faded := i == 3
		_panel(box, 0.04 + float(i) * 0.04, live)
		if _rows_of(box, 0.04 + float(i) * 0.04) < int(box.size.y):
			continue
		if live:
			# 잔광 — 테두리를 한 겹 더 흐리게 덧그린다. 번짐을 흉내 내는 유일한 수단이다.
			draw_rect(box.grow(3.0), Color(AMBER, 0.16), false, 3.0)
			draw_rect(box.grow(6.0), Color(AMBER, 0.07), false, 3.0)
		if pushed:
			draw_rect(box, Color(AMBER, 0.30), true)
		_say(
			labels[i],
			Vector2(box.position.x, box.get_center().y + 6.0),
			box.size.x,
			17,
			BONE if not faded else Color(BONE, 0.3)
		)
		# 버튼마다 뜻 없는 번호. **장식은 흐리고 작게.**
		draw_string(
			FONT,
			box.position + Vector2(5.0, 11.0),
			CelReadout.noise_hex(i, _clock),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			9,
			Color(AMBER_DIM, 0.7)
		)


func _window() -> void:
	var box := Rect2(PAD, 182.0, 344.0, 186.0)
	_panel(box, 0.22)
	if _rows_of(box, 0.22) < int(box.size.y):
		return
	draw_line(
		Vector2(box.position.x, box.position.y + 28.0),
		Vector2(box.end.x, box.position.y + 28.0),
		Color(AMBER, 0.45),
		1.0
	)
	draw_string(
		FONT, box.position + Vector2(12.0, 20.0), "창", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, BONE
	)
	var shut := Vector2(box.end.x - 16.0, box.position.y + 14.0)
	draw_line(shut + Vector2(-5, -5), shut + Vector2(5, 5), BONE, 1.4)
	draw_line(shut + Vector2(-5, 5), shut + Vector2(5, -5), BONE, 1.4)
	# 십자선 하나. 계기판의 서명이다.
	var cross := box.get_center() + Vector2(80.0, 18.0)
	draw_line(cross - Vector2(26, 0), cross + Vector2(26, 0), Color(AMBER, 0.4), 1.0)
	draw_line(cross - Vector2(0, 26), cross + Vector2(0, 26), Color(AMBER, 0.4), 1.0)
	draw_arc(cross, 15.0, 0.0, TAU, 32, Color(AMBER, 0.5), 1.0)
	draw_arc(
		cross,
		15.0,
		CelReadout.spinner(1, _clock),
		CelReadout.spinner(1, _clock) + 1.2,
		12,
		AMBER,
		2.0
	)
	for row in 3:
		var bar := Rect2(
			box.position.x + 14.0, box.position.y + 54.0 + float(row) * 22.0, 150.0, 6.0
		)
		draw_rect(bar, Color(AMBER_DIM, 0.35), false, 1.0)
		draw_rect(
			Rect2(
				bar.position, Vector2(bar.size.x * CelReadout.noise_level(row, _clock), bar.size.y)
			),
			Color(AMBER, 0.75),
			true
		)
	_ruler(
		Vector2(box.position.x + 12.0, box.end.y - 14.0),
		Vector2(box.end.x - 12.0, box.end.y - 14.0),
		24,
		7.0,
		11
	)


## 팝업 — **한 줄씩 그려지며 나타난다.** 커지지도 갈라지지도 않는다.
func _popup() -> void:
	var box := Rect2(PAD + 366.0, 182.0, 238.0, 186.0)
	_panel(box, 1.98)
	if _rows_of(box, 1.98) < int(box.size.y):
		return
	_say("버릴까요", Vector2(box.position.x, box.position.y + 56.0), box.size.x, 21, BONE)
	draw_string(
		FONT,
		box.position + Vector2(0.0, 82.0),
		"되돌릴 수 없습니다",
		HORIZONTAL_ALIGNMENT_CENTER,
		box.size.x,
		12,
		Color(BONE, 0.6)
	)
	var wide := (box.size.x - 38.0) * 0.5
	for i in 2:
		var button := Rect2(
			box.position.x + 13.0 + float(i) * (wide + 12.0), box.end.y - 50.0, wide, 34.0
		)
		draw_rect(button, Color(AMBER, 0.30 if i == 0 else 0.0), i == 0)
		draw_rect(button, Color(AMBER, 0.6 if i == 0 else 0.3), false, 1.0)
		if i == 0:
			_brackets(button, 8.0, AMBER, 1.4)
		_say(
			"확인" if i == 0 else "취소",
			Vector2(button.position.x, button.get_center().y + 5.0),
			button.size.x,
			15,
			BONE if i == 0 else Color(BONE, 0.62)
		)


## 메뉴 — **「지금 여기」가 흐르는 유일한 자리다.**
func _menu() -> void:
	var box := Rect2(PAD, 388.0, 300.0, 172.0)
	_panel(box, 0.36)
	if _rows_of(box, 0.36) < int(box.size.y):
		return
	var items := ["출격", "길드", "인물", "설정"]
	var chosen := 1 if _clock < 2.80 else 2
	for i in 4:
		var row := Rect2(
			box.position.x + 10.0, box.position.y + 14.0 + float(i) * 37.0, box.size.x - 20.0, 32.0
		)
		if i == chosen:
			draw_rect(row, Color(AMBER, 0.26), true)
			draw_rect(row.grow(2.0), Color(AMBER, 0.35), false, 1.4)
			# 지시선 하나가 오른쪽으로 뻗어 작은 라벨을 단다.
			var out := Vector2(row.end.x + 6.0, row.get_center().y)
			draw_line(out, out + Vector2(34.0, 0.0), AMBER, 1.2)
			draw_line(out + Vector2(34.0, 0.0), out + Vector2(46.0, -10.0), AMBER, 1.2)
			draw_string(
				FONT,
				out + Vector2(48.0, -12.0),
				CelReadout.noise_digits(7, _clock, 3),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				10,
				Color(AMBER, 0.85)
			)
		draw_string(
			FONT,
			row.position + Vector2(14.0, 22.0),
			items[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			BONE if i == chosen else Color(BONE, 0.5)
		)


func _inputs() -> void:
	var box := Rect2(PAD + 322.0, 388.0, 282.0, 172.0)
	_panel(box, 0.44)
	if _rows_of(box, 0.44) < int(box.size.y):
		return
	draw_string(
		FONT,
		box.position + Vector2(16.0, 28.0),
		"소리",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		Color(BONE, 0.7)
	)
	var rail := Rect2(box.position.x + 16.0, box.position.y + 44.0, box.size.x - 32.0, 5.0)
	draw_rect(rail, Color(AMBER_DIM, 0.5), false, 1.0)
	draw_rect(
		Rect2(rail.position, Vector2(rail.size.x * 0.62, rail.size.y)), Color(AMBER, 0.8), true
	)
	var knob := Vector2(rail.position.x + rail.size.x * 0.62, rail.get_center().y)
	draw_rect(Rect2(knob - Vector2(3.0, 9.0), Vector2(6.0, 18.0)), BONE, true)
	_ruler(
		Vector2(rail.position.x, rail.end.y + 6.0),
		Vector2(rail.end.x, rail.end.y + 6.0),
		20,
		5.0,
		21
	)

	var tick := Rect2(box.position.x + 16.0, box.position.y + 92.0, 20.0, 20.0)
	draw_rect(tick, Color(AMBER, 0.5), false, 1.2)
	draw_polyline(
		PackedVector2Array(
			[
				tick.position + Vector2(4.0, 10.0),
				tick.position + Vector2(8.5, 15.0),
				tick.position + Vector2(16.0, 4.0)
			]
		),
		AMBER,
		2.0
	)
	draw_string(
		FONT,
		Vector2(tick.end.x + 12.0, tick.position.y + 15.0),
		"전체 화면",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		BONE
	)
	# 돌아가는 표시자. 아무것도 안 가리킨다.
	var spin := Vector2(box.end.x - 32.0, box.position.y + 100.0)
	draw_arc(spin, 12.0, 0.0, TAU, 24, Color(AMBER_DIM, 0.6), 1.0)
	draw_arc(
		spin,
		12.0,
		CelReadout.spinner(2, _clock),
		CelReadout.spinner(2, _clock) + 2.0,
		16,
		AMBER,
		1.6
	)


func _here() -> void:
	var box := Rect2(PAD, 580.0, size.x - PAD * 2.0, 54.0)
	_panel(box, 0.52, true)
	if _rows_of(box, 0.52) < int(box.size.y):
		return
	draw_rect(box.grow(3.0), Color(AMBER, 0.18), false, 3.0)
	draw_string(
		FONT,
		Vector2(PAD, 572.0),
		"강조 — 지금 여기",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color(BONE, 0.45)
	)
	_say("3층 봉인된 문", Vector2(box.position.x, box.get_center().y + 8.0), box.size.x, 22, BONE)
	_brackets(box, 16.0, AMBER, 2.0)


## 화면 가장자리의 **아무 정보도 없는 정보.** 흐리고 작다.
func _chrome() -> void:
	for i in 6:
		draw_string(
			FONT,
			Vector2(size.x - 104.0, 26.0 + float(i) * 12.0),
			"%s %s" % [CelReadout.noise_hex(i + 3, _clock), CelReadout.noise_digits(i, _clock)],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			9,
			Color(AMBER_DIM, 0.75)
		)
	_ruler(Vector2(14.0, 108.0), Vector2(14.0, size.y - 90.0), 34, 6.0, 41)
	_ruler(Vector2(size.x - 14.0, 108.0), Vector2(size.x - 14.0, size.y - 90.0), 34, -6.0, 57)
	draw_string(
		FONT,
		Vector2(PAD, size.y - 18.0),
		"약한 곳 — 눈금이 많아 조용한 화면이 안 된다. 급한 경고를 낼 자리가 없다",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color(AMBER, 0.8)
	)


## 글자를 **두 번 찍는다.** 「참격」에서 배운 것 — 효과가 글자를 먹으면 안 읽힌다.
func _say(text: String, at: Vector2, wide: float, tall: int, tint: Color) -> void:
	draw_string(
		FONT,
		at + Vector2(1.0, 1.0),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		wide,
		tall,
		Color(GROUND, 0.85)
	)
	draw_string(FONT, at, text, HORIZONTAL_ALIGNMENT_CENTER, wide, tall, tint)
