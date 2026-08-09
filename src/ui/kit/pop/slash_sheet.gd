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
## | 색이 적은데 세다 | 바탕 · 미색에 **포인트 셋** — 신호 · 고름 · 험 (§20.32) |
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

## **화면을 가로지르는 벤 자국 한 줄.**
##
## 「참격」이 지금까지 **무늬**였다 — 사선 줄무늬와 기울어진 판. 이 한 줄은
## 걸린 판을 **실제로 가른다.** 판마다 자기 가운데를 여는 것이 아니라
## **한 줄이 판들을 건너 이어진다.**
##
## 각도와 지나는 점을 **손으로 안 고른다** — 판의 **왼아래에서 오른위로 가는 대각선**이고
## **판의 한가운데**를 지난다. 손으로 고르면 화면마다 다시 맞춰야 하고, 맞추다 보면
## 큰 판의 모서리를 얕게 스치는 각도에 앉는다(§20.33.3). 대각선은 **판을 가로질러 지나가서**
## 걸리는 것을 깊게 벤다.
const RIP_APART := 10.0

## 떨어져 나온 조각이 판의 이 비율보다 작으면 **안 베고 밀린다.**
##
## 0.12 로 시작했더니 **벨 만한 판까지 밀어냈다** — 강조 띠가 7% 짜리 조각을 내는데
## 그건 충분히 깊고 잘 보이는 자국이었다. 문턱은 **「그리다 만 것으로 보이는 크기」**여야지
## 「작은 크기」가 아니다. 5% 아래만 밀어낸다.
const RIP_LEAST := 0.05

## 베는 순간. 판이 다 들어와 선 직후에 **한 번에** 지나간다.
const RIP_AT := 0.78

## 앞판이 뒤판에서 잘라 내는 여유. **이 빈 줄 하나가 「판이 두 장」이라고 말한다.**
const BLEED := 3.0

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


## 덮개의 인광색을 팔레트에 맞춘다. **방의 빛이지 신호가 아니라서** 강조색을 안 쓴다 —
## 화면 전체를 훑는 띠가 신호색이면 「지금 여기」가 매초 화면을 가로지른다.
func _tint_screen() -> void:
	if _lit == null:
		return
	(_lit.material as ShaderMaterial).set_shader_parameter("glow", HoloPalette.glow(palette))


func _void() -> Color:
	return HoloPalette.void_color(palette)


func _paper() -> Color:
	return HoloPalette.paper(palette)


## **신호.** 이 함수를 부르는 곳은 `_here()` **하나뿐이어야 한다** (§20.32).
func _accent() -> Color:
	return HoloPalette.accent(palette)


## **고름** — 켜짐 · 선택 · 값. 신호가 아니라 구분이다.
func _pick() -> Color:
	return HoloPalette.pick(palette)


## **험** — 되돌릴 수 없는 것.
func _peril() -> Color:
	return HoloPalette.peril(palette)


## 어긋난 뒤판의 색. **고름의 짙은 쪽**이라 어긋남이 색으로도 읽힌다.
func _back() -> Color:
	return HoloPalette.back(palette)


## 그 면 위의 글자색. 면이 밝으면 어둡게, 어두우면 밝게 — **화면이 눈으로 안 고른다.**
func _ink(surface: Color) -> Color:
	return HoloPalette.ink(palette, surface)


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


## 지금 벤 자국이 얼마나 벌어져 있나. 스냅으로 **한 번에** 벌어지고 그대로 있는다.
func _rip() -> float:
	return _snap(RIP_AT, 0.12) * RIP_APART


## 벤 자국의 각도. **판의 왼아래에서 오른위로 가는 대각선**이다.
func _rip_angle() -> float:
	return atan2(-size.y, size.x)


## 벤 자국이 지나는 점. **판의 한가운데.**
func _rip_through() -> Vector2:
	return size * 0.5


## 판 하나를 그린다. **벤 자국에 걸리면 두 조각이 되어 어긋난다.**
##
## 판을 칠하는 모든 자리가 이 함수를 지나간다 — 한 군데라도 빠지면 그 판만
## 자국을 안 맞은 것이 되고, 그러면 자국이 **한 줄로 안 이어져** 그냥 깨진 판이 된다.
func _plate(shape: PackedVector2Array, tint: Color, least: float = RIP_LEAST) -> void:
	for piece in GraphicCut.severed(shape, _rip_angle(), _rip_through(), _rip(), least):
		draw_colored_polygon(piece, tint)


## 판 **안에** 깔리는 것 — 무늬 한 줄 · 뒤판 초승달 — 은 **판의 판정을 따라간다.**
##
## 각자 판정하게 두면 안 된다. 얇은 무늬 한 줄은 「얕게 걸렸다」가 거의 늘 참이라
## **판은 베였는데 무늬는 통째로 밀려** 벌어진 틈 위를 가로지른다. 반대도 난다 —
## 판이 밀렸는데 무늬만 베이면 있지도 않은 틈에 무늬가 갈라져 있다.
##
## **문턱은 판의 성질이지 그 위에 깔리는 것의 성질이 아니다.**
func _follow(panel: PackedVector2Array, piece: PackedVector2Array, tint: Color) -> void:
	var push := GraphicCut.shove(panel, _rip_angle(), _rip_through(), _rip(), RIP_LEAST)
	if push == Vector2.ZERO:
		_plate(piece, tint, 0.0)
		return
	draw_colored_polygon(GraphicCut.swelled(piece, 0.0, push), tint)


## 어긋난 **뒤판.** 앞판이 덮을 자리를 **잘라 내고** 초승달만 남긴다.
##
## 덮어서 안 보이는 것과 잘려서 없는 것은 화면에서 똑같아 보이지만 **가장자리가 다르다.**
## 잘라 내면 앞판과 뒤판 사이에 `BLEED` 만큼의 빈 줄이 생기고, 그 줄 하나가
## 「이건 그림자가 아니라 판이 두 장」이라고 말한다 — 겹쳐 두면 아무 말도 안 한다.
func _backplate(front: PackedVector2Array, by: float, at: Vector2, tint: Color) -> void:
	for crescent in GraphicCut.notched(GraphicCut.swelled(front, by, at), front, BLEED):
		_follow(front, crescent, tint)


## 채워진 판 위의 **주사선.** 망점이 있던 자리다 — 무늬만 바뀌고 판은 그대로다.
##
## 줄의 색을 부르는 쪽이 정하지 않는다. **면이 어두워지면 주사선은 밝아져야** 하고,
## 색을 갈아 끼울 때 그 뒤집힘을 화면 코드가 일곱 군데에서 따로 기억할 수 없다.
func _scanlines(shape: PackedVector2Array, surface: Color, force: float) -> void:
	var tint := Color(_ink(surface), force)
	for bar in GraphicCut.stripes(shape, 0.0, 4.0, 1.6, _clock * 9.0):
		_follow(shape, bar, tint)


## 모서리 꺾쇠와 작은 눈금. **큰 판 가장자리에 붙는 장식**이지 판을 대신하지 않는다.
##
## 포인트 색 셋 중 **아무것도 안 쓴다** (§20.32). 장식이 신호색을 입는 순간
## 화면에 「지금 여기」가 다섯 개가 된다 — 앞 판이 정확히 그렇게 죽었다.
func _rig(box: Rect2, slot: int) -> void:
	var reach := 13.0
	var trim := Color(_paper(), 0.42)
	var corners := [
		[box.position, Vector2(1, 0), Vector2(0, 1)],
		[Vector2(box.end.x, box.position.y), Vector2(-1, 0), Vector2(0, 1)],
		[box.end, Vector2(-1, 0), Vector2(0, -1)],
		[Vector2(box.position.x, box.end.y), Vector2(1, 0), Vector2(0, -1)],
	]
	for corner in corners:
		var at: Vector2 = corner[0]
		draw_line(at, at + (corner[1] as Vector2) * reach, trim, 2.0)
		draw_line(at, at + (corner[2] as Vector2) * reach, trim, 2.0)
	for i in 9:
		var x := lerpf(box.position.x + 16.0, box.end.x - 16.0, float(i) / 8.0)
		var wobble := CelReadout.tick_jitter(slot + i, _clock, 0.6)
		draw_line(
			Vector2(x, box.end.y + 4.0),
			Vector2(x, box.end.y + 8.0 + wobble),
			Color(_paper(), 0.3),
			1.0
		)
	draw_string(
		FONT,
		Vector2(box.position.x + 2.0, box.position.y - 5.0),
		"%s %s" % [CelReadout.noise_hex(slot, _clock), CelReadout.noise_digits(slot, _clock, 3)],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		9,
		Color(_paper(), 0.42)
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
	# 바탕의 띠는 신호색이 아니다 — 화면을 가로지르는 것이 「지금 여기」면 안 된다.
	draw_colored_polygon(band, Color(_pick(), 0.16))


## 제목 — **글자가 도형이다.** 기울고, 검은 판에 잘리고, 판 밖으로 넘친다.
func _title() -> void:
	var slab := GraphicCut.lean(Rect2(-30.0, 22.0, 340.0, 62.0), 0.30)
	_backplate(slab, 0.012, Vector2(7.0, 7.0), _back())
	_plate(slab, _paper())
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
		# 상태는 순서대로 **켜지고 그대로 걸린다.** 창처럼 잠깐 켰다 끄면
		# 대표 컷을 어느 시각에 뽑아도 넷 중 둘은 「기본」과 똑같이 찍힌다 —
		# 색을 판정하는 판에서 그것은 부품이 둘 모자란 것이다.
		var hot := i == 1 and _clock > 0.90
		var down := i == 2 and _clock > 1.55
		if down:
			shape = GraphicCut.swelled(shape, -0.03, Vector2(4.0, 4.0))

		# 뒤판 — **그림자가 아니라 판 한 겹 더**라서 어긋나 있고 색이 있다.
		if i != 3:
			_backplate(shape, 0.02, Vector2(8.0, 8.0), _back() if not down else _paper())
		# 「올림」은 **고름**이다. 켜진 것이지 「지금 여기」가 아니다.
		var face := _pick() if hot else _paper()
		_plate(shape, face)
		if i == 3:
			for bar in GraphicCut.stripes(shape, -PI * 0.25, 9.0, 4.0, 0.0):
				_follow(shape, bar, Color(_void(), 0.55))
		if hot:
			_scanlines(shape, face, 0.22)
		_shape_text(labels[i], Rect2(box.position, box.size), 18, face, 0.35 if i == 3 else 1.0)


## 창 — 제목줄 · 테두리 · 닫기 · 배경. **모서리 둘이 잘렸다.**
func _window() -> void:
	var enter := _snap(0.24)
	var box := Rect2(PAD - (1.0 - enter) * SLIDE, 206.0, 336.0, 178.0)
	var shape := GraphicCut.clipped(box, 26.0, 2 | 8)
	# 뒤판이 **반투명해졌다** — 판 뒤에 다른 판이 비친다.
	_backplate(shape, 0.014, Vector2(9.0, 9.0), Color(_back(), 0.55))
	var drawn := _reveal(shape, 0.24)
	if drawn.is_empty():
		return
	for piece in drawn:
		_plate(piece, _paper())
	if drawn.size() == 1 and drawn[0].size() != shape.size():
		return
	_scanlines(shape, _paper(), 0.10)
	_rig(box, 2)

	var bar := GraphicCut.lean(Rect2(box.position.x, box.position.y, box.size.x - 26.0, 34.0), 0.0)
	_plate(bar, _void())
	draw_string(
		FONT, box.position + Vector2(14.0, 24.0), "창", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, _paper()
	)
	# 닫기는 **험**이다. 창에서 되돌릴 수 없는 것은 이것 하나뿐이라 여기만 그 색이다.
	var shut := Vector2(box.end.x - 46.0, box.position.y + 17.0)
	draw_line(shut + Vector2(-6, -6), shut + Vector2(6, 6), _peril(), 2.8)
	draw_line(shut + Vector2(-6, 6), shut + Vector2(6, -6), _peril(), 2.8)
	for row in 3:
		_plate(
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


## **험이 지금 화면에 떠 있나** 0..1. 팝업이 찢어져 열리는 정도가 그대로 이 값이다.
##
## 창의 닫기 표시도 험의 색이지만 이 값에 안 넣는다 — 그건 **늘 거기 있는 표시**고,
## 늘 있는 것에 신호가 반응하면 신호가 영영 안 켜진다. 반응하는 것은 **뜨는 것**에만이다.
func _peril_up() -> float:
	return _snap(2.00, 0.30)


## 팝업 — **사선으로 찢어지며 열린다.** 커지는 게 아니라 갈라지는 것이다.
func _popup() -> void:
	var open := _peril_up()
	var box := Rect2(PAD + 356.0, 206.0, 252.0, 178.0)
	var shape := GraphicCut.clipped(box, 24.0, 1 | 4)
	for piece in GraphicCut.torn_open(shape, -PI * 0.22, open, 46.0):
		# 어긋난 뒤판이 **험**의 색이다 — 팝업 전체가 「되돌릴 수 없는 것」이라
		# 그 사실이 버튼 하나가 아니라 판 테두리에서 먼저 보인다.
		_backplate(piece, 0.012, Vector2(8.0, 8.0), Color(_peril(), 0.72))
		_plate(piece, _paper())
		_scanlines(piece, _paper(), 0.10)
	if open < 0.55:
		return
	_rig(box, 5)
	_shape_text(
		"버릴까요", Rect2(box.position + Vector2(0.0, 26.0), Vector2(box.size.x, 34.0)), 24, _paper()
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
			_backplate(shape_button, 0.03, Vector2(5.0, 5.0), _void())
		var face := _peril() if solid else Color(_void(), 0.10)
		_plate(shape_button, face)
		_shape_text("확인" if solid else "취소", button, 16, face if solid else _paper())


## 메뉴 — 항목 넷, 하나 선택됨. **「지금 여기」는 여기 하나에서만 흐른다.**
func _menu() -> void:
	var enter := _snap(0.42)
	var box := Rect2(PAD - (1.0 - enter) * SLIDE, 404.0, 292.0, 168.0)
	var shape := GraphicCut.clipped(box, 22.0, 4)
	_plate(shape, Color(_paper(), 0.10))
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
			_backplate(shape_row, 0.03 * grow, Vector2(6.0, 6.0) * grow, _void())
			# 골라 둔 것은 **고름**이다. 눈에 띄어야 하지만 「지금 여기」는 아니다.
			_plate(shape_row, _pick())
			_scanlines(shape_row, _pick(), 0.18)
		draw_string(
			FONT,
			row.position + Vector2(22.0, 23.0),
			items[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			17,
			_ink(_pick()) if i == chosen else Color(_paper(), 0.55)
		)


## 슬라이더와 체크 — 둘 다 기울어 있다.
func _inputs() -> void:
	var enter := _snap(0.50)
	var box := Rect2(PAD + 312.0 + (1.0 - enter) * SLIDE, 404.0, 296.0, 168.0)
	_plate(GraphicCut.clipped(box, 22.0, 1), Color(_paper(), 0.10))
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
	_plate(GraphicCut.lean(rail, 0.9), Color(_paper(), 0.18))
	# 값이 차 있는 쪽도 **고름**이다 — 켜진 것과 골라 둔 것과 찬 것은 같은 종류다.
	_plate(
		GraphicCut.lean(Rect2(rail.position, Vector2(rail.size.x * 0.62, rail.size.y)), 0.9),
		_pick()
	)
	var knob := Rect2(
		rail.position.x + rail.size.x * 0.62 - 8.0, rail.position.y - 11.0, 18.0, 30.0
	)
	_backplate(GraphicCut.lean(knob, 0.4), 0.04, Vector2(4.0, 4.0), _void())
	_plate(GraphicCut.lean(knob, 0.4), _paper())

	var tick := Rect2(box.position.x + 20.0, box.position.y + 96.0, 26.0, 26.0)
	var shape_tick := GraphicCut.lean(tick, 0.22)
	_backplate(shape_tick, 0.04, Vector2(5.0, 5.0), _void())
	_plate(shape_tick, _pick())
	draw_polyline(
		PackedVector2Array(
			[
				tick.position + Vector2(9.0, 13.0),
				tick.position + Vector2(14.0, 19.0),
				tick.position + Vector2(24.0, 5.0)
			]
		),
		_ink(_pick()),
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
##
## ## 험이 뜨면 신호가 숨을 죽인다
##
## 붉은색은 언제나 이긴다 — 팝업이 떠 있는 동안 「지금 여기」는 이미 그쪽이고,
## 여기가 계속 켜져 있으면 **화면에 「지금 여기」가 둘**이 된다.
##
## 다만 **면 색은 안 끈다.** 강조색은 이 부품의 **신분**이고, 신호는 그 위에 얹은 것들
## — 주사선 · 꺾쇠 · 밝은 뒤판 — 이다. 얹은 것이 물러나고 면이 바탕 쪽으로 내려앉으면
## **꺼진 것으로 읽히되 무엇이었는지는 남는다.** 색까지 지우면 부품이 사라진다.
func _here() -> void:
	var enter := _snap(0.60)
	var hush := _peril_up()
	var box := Rect2(PAD - (1.0 - enter) * SLIDE * 1.6, 596.0, size.x - PAD * 2.0, 58.0)
	var shape := GraphicCut.fang(Rect2(box.position, box.size - Vector2(26.0, 0.0)), 26.0)
	_backplate(shape, 0.012, Vector2(9.0, 9.0), _paper().lerp(_void(), 0.80 * hush))
	# **화면에서 신호색이 나오는 자리는 여기 하나다** (§20.32).
	var face := _accent().lerp(_void(), 0.34 * hush)
	_plate(shape, face)
	if hush < 0.5:
		_scanlines(shape, face, 0.18)
		_rig(Rect2(box.position, box.size - Vector2(26.0, 0.0)), 8)
	draw_string(
		FONT,
		Vector2(PAD, 588.0),
		"강조 — 지금 여기" if hush < 0.5 else "강조 — 험이 떠 있는 동안은 꺼진다",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		Color(_paper(), 0.5 - 0.22 * hush)
	)
	_shape_text("3층 봉인된 문", box, 24, face)


func _weak() -> void:
	draw_string(
		FONT,
		Vector2(PAD, size.y - 20.0),
		"약한 곳 — 험(붉은 쪽)이 신호보다 먼저 눈에 든다. 실제 화면에서는 팝업이 혼자 뜨니 안 겹친다",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		Color(_paper(), 0.5)
	)


## 글자를 **도형처럼** 얹는다. 살짝 기울고, 어긋난 그림자가 한 겹 있다.
##
## **부르는 쪽은 글자색이 아니라 「무슨 면 위인가」를 준다.** 포인트 색이 셋이 되면서
## 면마다 밝기가 달라졌고, 글자색을 손으로 고르면 어느 팔레트에서 하나가 반드시 묻힌다.
## 어긋난 한 겹도 **글자색의 반대쪽**이라 밝은 면에서든 어두운 면에서든 글자가 선다.
##
## 색 분리(RGB split)는 흉내 내지 않는다 — 잠깐 튀는 어긋남은 포인트 색이 아니라
## **인광색**으로 찍는다. 신호색이 0.1초 동안이라도 다른 자리에서 나오면 안 된다.
func _shape_text(text: String, box: Rect2, tall: int, surface: Color, fade: float = 1.0) -> void:
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
			Color(HoloPalette.glow(palette), 0.85 * jolt)
		)
	draw_set_transform(seat + Vector2(2.0, 2.0), lean, Vector2.ONE)
	draw_string(
		FONT,
		Vector2.ZERO,
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		box.size.x,
		tall,
		Color(HoloPalette.ink_prop(palette, surface), 0.34 * fade)
	)
	draw_set_transform(seat, lean, Vector2.ONE)
	draw_string(
		FONT,
		Vector2.ZERO,
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		box.size.x,
		tall,
		Color(_ink(surface), fade)
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
