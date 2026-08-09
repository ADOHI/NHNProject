class_name MoltenSheet
extends Control
## 용광(鎔光) — **부품 한 벌에 층을 열한 겹씩.**
##
## docs/design/20-ui-kit.md §20.27.
##
##     godot --path . -s res://tools/capture_lush.gd -- .renders/lush-molten molten
##
## ## 대본이 있다 — 정지로는 절반도 안 보인다
##
## 사용자가 말한 「화려하게」의 뜻이 **그림체 · 쉐이더 · VFX** 다. VFX 는 정지 화면에
## 없다. 그래서 이 화면은 **스스로 올라가고 눌린다**(`SCRIPT`) — §20.20.5 의 규율이다.
##
## ## 신호는 여전히 한 선에만
##
## 층을 열한 겹 쌓아도 **「지금 여기」는 메뉴의 고른 항목 하나**다.
## 화려함은 층으로 쌓고 신호는 하나로 둔다 — 둘은 안 싸운다.

const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")
const SHADER := preload("res://src/ui/kit/lush/molten.gdshader")

const CARD := Vector2(660.0, 700.0)
const PAD := 26.0

## 한 바퀴(초). GIF 한 편의 길이이기도 하다.
const LOOP := 4.0

## 언제 무엇이 일어나나. `[시작, 끝, 무엇]` 이고 `무엇` 은 판 이름이다.
##
## **시각을 박아 둔다.** 사람이 눌러 뽑으면 판정할 때마다 다른 편을 보게 되고,
## 다른 것을 보면 무엇이 나아졌는지 못 가른다 (§20.21.1).
const SCRIPT := [
	[0.35, 1.30, "hover_button"],
	[0.95, 1.25, "press_button"],
	[1.70, 2.60, "hover_confirm"],
	[2.25, 2.55, "press_confirm"],
	[2.90, 3.80, "hover_menu"],
]

var _clock := 0.0
var _driven := false

var _buttons: Array[LushPlate] = []
var _window: LushPlate
var _popup: LushPlate
var _confirm: LushPlate
var _cancel: LushPlate
var _menu: LushPlate
var _rows: Array[LushPlate] = []
var _inputs: LushPlate
var _knob: LushPlate
var _here: LushPlate
var _backing: LushPlate

## 글자 덮개. **판보다 뒤에 붙어야 판 위에 그려진다** (LushInk 머리말).
var _ink: LushInk


func _ready() -> void:
	_build()
	set_process(not _driven)


## 캡처가 시계를 잡는다. **`add_child()` 전에 불러야 한다.**
func drive_externally() -> void:
	_driven = true
	set_process(false)


func _process(delta: float) -> void:
	set_clock(fposmod(_clock + delta, LOOP))


## 시각 `t` 의 화면을 앉힌다. 손짓도 여기서 나온다 — **캡처와 사람이 같은 문이다.**
func set_clock(t: float) -> void:
	_clock = t
	for plate in _every():
		plate.clock = t
	if _ink != null:
		_ink.queue_redraw()
	_buttons[3].dim = 1.0
	_apply("hover_button", _buttons[1], true)
	_apply("press_button", _buttons[2], false)
	_apply("hover_confirm", _confirm, true)
	_apply("press_confirm", _confirm, false)
	_apply("hover_menu", _rows[2], true)
	queue_redraw()


## 대본 한 줄을 판에 건다. 값이 **부드럽게 올랐다 내린다** — 켜고 끄면 손맛이 안 난다.
func _apply(what: String, plate: LushPlate, is_hover: bool) -> void:
	var level := 0.0
	for step in SCRIPT:
		if str(step[2]) != what:
			continue
		var from := float(step[0])
		var to := float(step[1])
		if _clock < from or _clock > to:
			continue
		var rise := smoothstep(from, from + 0.16, _clock)
		var fall := 1.0 - smoothstep(to - 0.16, to, _clock)
		level = minf(rise, fall)
	if is_hover:
		plate.hover = maxf(plate.hover if what.begins_with("hover") else 0.0, level)
		if level <= 0.0 and what.begins_with("hover"):
			plate.hover = 0.0
	else:
		plate.press = level


func _every() -> Array[LushPlate]:
	var out: Array[LushPlate] = []
	out.append_array(_buttons)
	out.append_array(_rows)
	out.append_array(
		(
			[_backing, _window, _popup, _confirm, _cancel, _menu, _inputs, _knob, _here]
			as Array[LushPlate]
		)
	)
	return out


func _make(box: Rect2, corner: float, sparks: bool = false) -> LushPlate:
	var plate := LushPlate.new(SHADER)
	plate.embers = sparks
	add_child(plate)
	plate.radius = corner
	plate.place(box)
	plate.palette(Color("#ffdb8a"), Color("#ec6a1e"), Color("#2a1310"), Color("#ffb35c"))
	return plate


func _build() -> void:
	# 뒤에 깔린 반투명 판 한 겹 — 층 열한 겹 중 마지막 하나는 **판 뒤에** 있다.
	_backing = _make(Rect2(PAD - 8.0, 96.0, CARD.x - PAD * 2.0 + 16.0, 470.0), 14.0)
	_backing.dim = 0.72

	var wide := (CARD.x - PAD * 2.0 - 24.0) / 4.0
	for i in 4:
		_buttons.append(_make(Rect2(PAD + float(i) * (wide + 8.0), 112.0, wide, 48.0), 7.0))

	_window = _make(Rect2(PAD, 200.0, 330.0, 172.0), 10.0, true)
	_popup = _make(Rect2(PAD + 350.0, 200.0, 258.0, 172.0), 10.0, true)
	_confirm = _make(Rect2(PAD + 362.0, 320.0, 110.0, 40.0), 6.0)
	_cancel = _make(Rect2(PAD + 484.0, 320.0, 110.0, 40.0), 6.0)
	_cancel.dim = 0.45

	_menu = _make(Rect2(PAD, 392.0, 286.0, 162.0), 10.0)
	for i in 4:
		var row := _make(Rect2(PAD + 10.0, 402.0 + float(i) * 36.0, 266.0, 32.0), 5.0)
		row.dim = 0.85
		_rows.append(row)
	# **「지금 여기」는 여기 하나다.** 고른 항목만 흐린 값을 벗는다.
	_rows[2].dim = 0.0

	_inputs = _make(Rect2(PAD + 306.0, 392.0, 302.0, 162.0), 10.0)
	_knob = _make(Rect2(PAD + 306.0 + 180.0, 434.0, 20.0, 26.0), 5.0)
	_here = _make(Rect2(PAD, 578.0, CARD.x - PAD * 2.0, 62.0), 10.0, true)

	# 맨 마지막에 붙는다 — 그래야 글자가 판 위에 온다.
	_ink = LushInk.new(_labels)
	add_child(_ink)
	_ink.size = CARD


func _draw() -> void:
	# 바탕만 여기서. **판보다 어두운 곳이 있어야 번짐이 번짐으로 보인다.**
	draw_rect(Rect2(Vector2.ZERO, size), Color("#120a0b"), true)


## 글자 전부. `LushInk` 가 판 위에서 부른다.
func _labels(on: CanvasItem) -> void:
	var ink := Color("#f6dcc0")
	_say(on, FONT, Vector2(PAD, 48.0), "용광", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, ink)
	_say(
		on,
		FONT,
		Vector2(PAD, 74.0),
		"쇳물이 식지 않은 것. 만지면 뜨겁다",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		Color(ink, 0.62)
	)
	_say(
		on,
		FONT,
		Vector2(PAD, CARD.y - 24.0),
		"약한 곳 — 눈이 쉴 데가 없다. 화면을 이걸로 다 덮으면 글이 안 읽힌다",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		Color("#ffb35c")
	)
	var names := ["기본", "올림", "눌림", "비활성"]
	for i in 4:
		var box := _buttons[i].plate_rect()
		_say(
			on,
			FONT,
			Vector2(box.position.x, box.get_center().y + 6.0),
			names[i],
			HORIZONTAL_ALIGNMENT_CENTER,
			box.size.x,
			16,
			Color(ink, 0.35 if i == 3 else 1.0)
		)

	var window := _window.plate_rect()
	_say(
		on, FONT, window.position + Vector2(14.0, 26.0), "창", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink
	)
	var shut := Vector2(window.end.x - 20.0, window.position.y + 20.0)
	on.draw_line(shut + Vector2(-5, -5), shut + Vector2(5, 5), ink, 1.6)
	on.draw_line(shut + Vector2(-5, 5), shut + Vector2(5, -5), ink, 1.6)
	for row in 3:
		on.draw_rect(
			Rect2(
				window.position.x + 14.0,
				window.position.y + 52.0 + float(row) * 22.0,
				window.size.x - 28.0 - float(row) * 52.0,
				7.0
			),
			Color(ink, 0.24 - float(row) * 0.05),
			true
		)

	var popup := _popup.plate_rect()
	_say(
		on,
		FONT,
		popup.position + Vector2(0.0, 44.0),
		"버릴까요",
		HORIZONTAL_ALIGNMENT_CENTER,
		popup.size.x,
		20,
		ink
	)
	_say(
		on,
		FONT,
		popup.position + Vector2(0.0, 70.0),
		"되돌릴 수 없습니다",
		HORIZONTAL_ALIGNMENT_CENTER,
		popup.size.x,
		13,
		Color(ink, 0.6)
	)
	for pair in [[_confirm, "확인"], [_cancel, "취소"]]:
		var plate: LushPlate = pair[0]
		var box := plate.plate_rect()
		_say(
			on,
			FONT,
			Vector2(box.position.x, box.get_center().y + 6.0),
			str(pair[1]),
			HORIZONTAL_ALIGNMENT_CENTER,
			box.size.x,
			15,
			Color(ink, 0.55 if plate == _cancel else 1.0)
		)

	var items := ["출격", "길드", "인물", "설정"]
	for i in 4:
		var row := _rows[i].plate_rect()
		_say(
			on,
			FONT,
			row.position + Vector2(18.0, 22.0),
			items[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			Color(ink, 1.0 if i == 2 else 0.62)
		)

	var inputs := _inputs.plate_rect()
	_say(
		on,
		FONT,
		inputs.position + Vector2(18.0, 32.0),
		"소리",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		Color(ink, 0.7)
	)
	on.draw_rect(
		Rect2(inputs.position.x + 18.0, inputs.position.y + 44.0, inputs.size.x - 36.0, 5.0),
		Color(ink, 0.16),
		true
	)
	on.draw_rect(
		Rect2(
			inputs.position.x + 18.0, inputs.position.y + 44.0, (inputs.size.x - 36.0) * 0.62, 5.0
		),
		Color("#ec6a1e"),
		true
	)
	var tick := Rect2(inputs.position.x + 18.0, inputs.position.y + 88.0, 22.0, 22.0)
	on.draw_rect(tick, Color(ink, 0.10), true)
	on.draw_polyline(
		PackedVector2Array(
			[
				tick.position + Vector2(5.0, 11.0),
				tick.position + Vector2(9.5, 16.0),
				tick.position + Vector2(17.0, 6.0)
			]
		),
		Color("#ffdb8a"),
		2.4
	)
	_say(
		on,
		FONT,
		Vector2(tick.end.x + 12.0, tick.position.y + 16.0),
		"전체 화면",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		ink
	)

	var here := _here.plate_rect()
	_say(
		on,
		FONT,
		Vector2(PAD, here.position.y - 10.0),
		"강조 — 지금 여기",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		Color(ink, 0.5)
	)
	_say(
		on,
		FONT,
		Vector2(here.position.x, here.get_center().y + 7.0),
		"3층 봉인된 문",
		HORIZONTAL_ALIGNMENT_CENTER,
		here.size.x,
		19,
		Color("#fff0d6")
	)


## 글자를 **두 번 찍는다** — 어두운 그림자를 먼저, 그 위에 색을.
##
## 층을 쌓자마자 나온 문제다: 「올림」 단추가 하얗게 타면서 **그 위의 글자가 사라졌다.**
## 화려함이 글자를 먹으면 그건 화려한 게 아니라 안 읽히는 것이다.
## 재료를 줄이지 않고 **글자 쪽을 세운다** — 그래야 둘 다 산다.
func _say(
	on: CanvasItem,
	font: Font,
	at: Vector2,
	text: String,
	align: HorizontalAlignment,
	wide: float,
	tall: int,
	tint: Color
) -> void:
	on.draw_string(
		font, at + Vector2(1.0, 1.5), text, align, wide, tall, Color(0.05, 0.02, 0.0, 0.75)
	)
	on.draw_string(font, at, text, align, wide, tall, tint)
