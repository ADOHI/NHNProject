class_name NoiseSheet
extends Control
## **선명함이 곧 주의(注意)다.** 아직 안 본 것은 노이즈고, 보는 순간 또렷해진다.
##
## docs/design/20-ui-kit.md §20.44.
##
##     godot --path . -s res://tools/capture_pop.gd -- .renders/57-noise noise
##
## ## 이 화면에 손잡이는 하나다
##
## §20.28~20.43 은 매 판 하나씩 더해 열 몇 가지가 됐다 — 층 · 무아레 · 파면 · 주사선 ·
## 훑는 띠 · 꺾쇠 · 눈금 · 숫자열 · 글리치 · 잔광 · 벤 자국. **컨셉이 없으면 뺄 근거가 없다.**
##
## 여기서는 부품마다 **노이즈 한 값**만 정한다. 그 값이 찢김 · 빠짐 · 대비를 다 정하고
## (`Grain`), 바탕은 축의 끝(`grain_field`)이다. 그래서 화면이 조용하다 —
## **효과가 적은 것이 아니라 효과가 하나**다.
##
## ## 이 게임에서 나온 컨셉이다
##
## 사람 셋넷을 데리고 던전에 들어가는데 안쪽은 안 가 보면 모르고, 대원은 배신하고,
## 소문은 틀린다. **정보가 불확실한 것이 이 게임의 내용**이고 UI 가 그것을 그대로 보인다.

const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")
const FIELD := preload("res://src/ui/kit/cel/grain_field.gdshader")

const CARD := Vector2(660.0, 760.0)
const LOOP := 7.2
const PAD := 26.0

## 초점이 옮겨가는 데 걸리는 시간. **또렷해지는 것은 사건이라 스냅이다.**
const SNAP := 0.14

## 노이즈 사다리 (§20.44.3). **0.00 은 정의상 화면에 하나뿐**이라
## 「신호는 한 번에 한 선에만」이 저절로 지켜진다.
const HERE := 0.0
const NEAR := 0.18
const LIVE := 0.42
const KEPT := 0.62
const LOST := 0.92

## 팝업이 열렸을 때 나머지가 시끄러워지는 양. **가림막이 어둠이 아니라 노이즈다.**
const VEIL := 0.24

const ROWS: Array[String] = ["출격", "길드", "인물", "설정", "기록", "상점", "종료"]

## 손이 올라가고 · 선택이 옮겨가고 · 팝업이 열리고 · 되돌아온다.
## **되돌아오는 것까지 한 바퀴 안에 있다** — 안 넣으면 바퀴 끝에서 화면이 튄다.
const HOVER_UP := 1.50
const MOVE_AT := 2.40
const HOVER_DOWN := 3.40
const POP_UP := 4.20
const POP_DOWN := 5.80
const MOVE_BACK := 6.40

const ROW_FIRST := 1
const ROW_NEXT := 4

const BOARD_TOP := 202.0
const BOARD_TALL := 372.0
const BAR_TALL := 36.0
const ROW_TOP := 256.0
const ROW_PITCH := 34.0
const ROW_TALL := 28.0
const ROW_LEFT := 44.0
const ROW_WIDE := 300.0

const MARK_TOP := 612.0
const MARK_TALL := 58.0

const POPUP := Rect2(150.0, 300.0, 360.0, 180.0)

## 색은 `HoloPalette` 한 곳에서만 정해진다 (§20.31). 화면은 번호만 든다.
var palette := 0:
	set(value):
		palette = wrapi(value, 0, HoloPalette.count())
		_tint_screen()
		queue_redraw()

## 고른 줄이 **판 밖으로도 나갈 것인가** (§20.40 의 「자리」).
##
## 강조가 「자리」로 확정돼 있었는데 이 컨셉은 강조를 **선명함**으로 한다 — 둘이 같은
## 일을 한다. 한 줄로 켜고 꺼서 나란히 뽑고 정한다 (§20.44.6).
var place := false:
	set(value):
		place = value
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
	stuff.set_shader_parameter("card", CARD)
	stuff.set_shader_parameter("churn", Grain.CHURN)
	_field.material = stuff
	add_child(_field)
	_field.size = CARD
	_face = Control.new()
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_face)
	_face.size = CARD
	_face.draw.connect(_paint_sheet)
	_tint_screen()
	set_process(not _driven)


func _tint_screen() -> void:
	if _field == null:
		return
	var stuff := _field.material as ShaderMaterial
	stuff.set_shader_parameter("deep", _void())
	stuff.set_shader_parameter("ink", _paper())


func drive_externally() -> void:
	_driven = true
	set_process(false)


func _process(delta: float) -> void:
	set_clock(fposmod(_clock + delta, LOOP))


func set_clock(t: float) -> void:
	_clock = t
	if _field != null:
		var stuff := _field.material as ShaderMaterial
		stuff.set_shader_parameter("clock", t)
		# **또렷한 것이 어디 있나.** 그 둘레에서 바탕의 알갱이가 걷힌다.
		stuff.set_shader_parameter("focus", _focus_at())
	if _face != null:
		_face.queue_redraw()
	queue_redraw()


func _void() -> Color:
	return HoloPalette.void_color(palette)


func _paper() -> Color:
	return HoloPalette.paper(palette)


## **신호.** 노이즈 0.00 인 자리에만 쓴다.
func _accent() -> Color:
	return HoloPalette.accent(palette)


## **고름** — 켜짐 · 선택 · 값.
func _pick() -> Color:
	return HoloPalette.pick(palette)


## **험** — 되돌릴 수 없는 것.
func _peril() -> Color:
	return HoloPalette.peril(palette)


func _ink(surface: Color) -> Color:
	return HoloPalette.ink(palette, surface)


## 스냅 0..1. 또렷해지는 것도 흐려지는 것도 이 하나를 쓴다.
func _snap(from: float, span: float = SNAP) -> float:
	return clampf((_clock - from) / span, 0.0, 1.0)


## 지금 팝업이 얼마나 열려 있나 0..1.
func _pop_force() -> float:
	if _clock < POP_UP or _clock >= POP_DOWN + SNAP:
		return 0.0
	if _clock >= POP_DOWN:
		return 1.0 - _snap(POP_DOWN)
	return _snap(POP_UP)


## 팝업이 열린 만큼 나머지가 시끄러워진다. **주의를 뺏긴 것이지 어두워진 것이 아니다.**
func _veil() -> float:
	return VEIL * _pop_force()


## 부품 하나의 최종 노이즈. **가림막이 여기 한 곳에서만 더해진다** —
## 자리마다 손으로 더하면 하나는 반드시 빠지고, 빠진 하나가 팝업 위로 떠오른다.
func _noise(step: float) -> float:
	return clampf(step + _veil(), 0.0, LOST)


func _hover_force() -> float:
	if _clock < HOVER_UP or _clock >= HOVER_DOWN + SNAP:
		return 0.0
	if _clock >= HOVER_DOWN:
		return 1.0 - _snap(HOVER_DOWN)
	return _snap(HOVER_UP)


func _hovered_row() -> int:
	return ROW_NEXT if _hover_force() > 0.0 else -1


func _marked_row() -> int:
	if _clock >= MOVE_AT and _clock < MOVE_BACK:
		return ROW_NEXT
	return ROW_FIRST


## 지금 또렷한 것의 한가운데. **팝업이 열리면 초점이 팝업으로 넘어간다.**
func _focus_at() -> Vector2:
	if _pop_force() > 0.5:
		return POPUP.get_center()
	return Vector2(CARD.x * 0.5, MARK_TOP + MARK_TALL * 0.5)


## 네 귀가 반듯한 판. **형태 문법을 안 쓴다** — 가장자리는 찢겨서 말한다 (§20.44.2).
func _box(rect: Rect2) -> PackedVector2Array:
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
## 부품마다 손으로 넣으면 스물다섯 군데 중 하나는 반드시 빠지고, 빠진 하나가
## **혼자 또렷해서** 「지금 여기」가 둘이 된다.
func _paint(shape: PackedVector2Array, tint: Color, noise: float) -> void:
	var faint := Grain.dim(tint, noise, _void())
	for piece in Grain.shred(shape, noise, _clock):
		if piece.size() < 3 or GraphicCut.area_of(piece) < 0.05:
			continue
		_face.draw_colored_polygon(piece, faint)


## 획 하나. **자기 띠의 밀림을 탄다** — 판과 같은 격자라 같은 줄에서 어긋난다.
func _stroke(from: Vector2, to: Vector2, tint: Color, noise: float, wide: float = 2.4) -> void:
	var band := Grain.band_of((from.y + to.y) * 0.5)
	if Grain.gone(band, _clock, noise):
		return
	var push := Vector2(Grain.slip(band, _clock, noise), 0.0)
	_face.draw_line(from + push, to + push, Grain.dim(tint, noise, _void()), wide)


## 글자. **획을 안 찢는다** — 찢으면 못 읽고, 못 읽는 것은 노이즈가 아니라 얼룩이다.
##
## 덩어리째 자기 띠의 밀림을 타고, 노이즈가 크면 **다른 띠의 밀림으로 한 벌 더** 겹친다.
## 읽힘의 경계는 노이즈 0.92 다 (§20.44.5).
func _say(
	text: String,
	at: Vector2,
	tall: int,
	tint: Color,
	noise: float,
	wide: float = -1.0,
	align: int = HORIZONTAL_ALIGNMENT_LEFT
) -> void:
	var band := Grain.band_of(at.y - float(tall) * 0.4)
	var faint := Grain.dim(tint, noise, _void())
	var echo := Grain.echo_force(noise)
	if echo > 0.0:
		var ghost := Vector2(Grain.slip(band + 2, _clock, noise), 0.0)
		_face.draw_string(FONT, at + ghost, text, align, wide, tall, Color(faint, faint.a * echo))
	var push := Vector2(Grain.slip(band, _clock, noise), 0.0)
	_face.draw_string(FONT, at + push, text, align, wide, tall, faint)


func _paint_sheet() -> void:
	_title()
	_buttons()
	_window()
	_mark()
	_popup()


## 제목. **늘 있는 것**이라 노이즈 0.62 — 읽히되 앞에 안 선다.
func _title() -> void:
	_say("잡음", Vector2(PAD, 66.0), 34, _paper(), _noise(KEPT))
	_say("본 것만 또렷하다", Vector2(PAD, 92.0), 13, Color(_paper(), 0.7), _noise(KEPT))


## 버튼 넷 — 기본 · 올림 · 눌림 · 비활성. **네 상태가 노이즈 사다리의 네 칸이다.**
##
## 비활성에 빗금을 안 친다. 안 쓰는 것은 **주의를 안 받는 것**이고 그건 이미 축 위에 있다.
func _buttons() -> void:
	var labels := ["기본", "올림", "눌림", "비활성"]
	var steps := [LIVE, NEAR, NEAR, LOST]
	var wide := (CARD.x - PAD * 2.0 - 36.0) / 4.0
	for i in 4:
		var rect := Rect2(PAD + float(i) * (wide + 12.0), 118.0, wide, 52.0)
		if i == 2:
			rect = rect.grow(-3.0)
		var noise: float = _noise(steps[i])
		var face := _pick() if i == 1 or i == 2 else Color(_paper(), 0.17)
		if i == 2:
			face = Color(_pick(), 0.55)
		_paint(_box(rect), face, noise)
		_say(
			labels[i],
			Vector2(rect.position.x, rect.get_center().y + 6.0),
			17,
			_ink(face) if i == 1 else _paper(),
			noise,
			rect.size.x,
			HORIZONTAL_ALIGNMENT_CENTER
		)


## 창 — 제목줄 · 닫기 · 메뉴 일곱 줄 · 슬라이더 · 체크 · 험.
##
## 목록을 창 안에 넣었다. 판을 둘로 나누면 **같은 노이즈 칸의 판이 둘**이 되고,
## 그러면 사다리가 아니라 배치가 화면을 가른다.
func _window() -> void:
	var noise := _noise(KEPT)
	var box := Rect2(PAD, BOARD_TOP, CARD.x - PAD * 2.0, BOARD_TALL)
	_paint(_box(box), Color(_paper(), 0.16), noise)
	var bar := Rect2(box.position.x, box.position.y, box.size.x, BAR_TALL)
	_paint(_box(bar), Color(_paper(), 0.30), noise)
	_say("길드 본부", box.position + Vector2(16.0, 25.0), 17, _paper(), noise)
	# 닫기는 **험**이다. 창에서 되돌릴 수 없는 것은 이것 하나뿐이다.
	var shut := Vector2(box.end.x - 26.0, box.position.y + 18.0)
	_stroke(shut + Vector2(-6, -6), shut + Vector2(6, 6), _peril(), noise, 2.6)
	_stroke(shut + Vector2(-6, 6), shut + Vector2(6, -6), _peril(), noise, 2.6)
	_menu()
	_inputs(Rect2(366.0, 258.0, 248.0, 296.0))


## 메뉴 — **고른 줄과 손이 닿은 줄만 또렷해진다.** 나머지는 노이즈 0.42 다.
##
## 「아직 안 본 것」이 여섯 줄이고 그 여섯은 **읽을 수는 있다.** 읽을 수 없으면
## 고를 것을 찾는 중인 사람이 손해를 본다 (§20.39.6 이 「여백」에서 배운 것).
func _menu() -> void:
	var mark := _marked_row()
	var over := _hovered_row()
	for i in ROWS.size():
		var rect := Rect2(ROW_LEFT, ROW_TOP + float(i) * ROW_PITCH, ROW_WIDE, ROW_TALL)
		var noise := _noise(LIVE)
		if i == mark:
			noise = _noise(NEAR)
			if place:
				# 「자리」 — 판 밖으로 나간다. 켜고 꺼서 견주는 한 줄이다 (§20.44.6).
				rect.position.x -= 20.0
				rect.size.x += 20.0
			_paint(_box(rect), _pick(), noise)
			_say(ROWS[i], rect.position + Vector2(14.0, 20.0), 16, _ink(_pick()), noise)
			continue
		if i == over:
			noise = lerpf(_noise(LIVE), _noise(NEAR) + 0.10, _hover_force())
			_paint(_box(rect), Color(_paper(), 0.10 * _hover_force()), noise)
		_say(ROWS[i], rect.position + Vector2(14.0, 20.0), 16, _paper(), noise)


## 슬라이더 · 체크 · 험. **손 닿는 부품이라 전부 노이즈 0.42 다.**
func _inputs(box: Rect2) -> void:
	var noise := _noise(LIVE)
	_say("소리", box.position + Vector2(0.0, 14.0), 14, Color(_paper(), 0.8), noise)
	var rail := Rect2(box.position.x, box.position.y + 30.0, box.size.x, 8.0)
	_paint(_box(rail), Color(_paper(), 0.18), noise)
	_paint(_box(Rect2(rail.position, Vector2(rail.size.x * 0.62, rail.size.y))), _pick(), noise)
	var knob := Rect2(
		rail.position.x + rail.size.x * 0.62 - 7.0, rail.position.y - 11.0, 14.0, 30.0
	)
	_paint(_box(knob), _paper(), noise)

	var tick := Rect2(box.position.x, box.position.y + 86.0, 26.0, 26.0)
	_paint(_box(tick), _pick(), noise)
	_stroke(
		tick.position + Vector2(6.0, 13.0),
		tick.position + Vector2(11.0, 19.0),
		_ink(_pick()),
		noise,
		3.0
	)
	_stroke(
		tick.position + Vector2(11.0, 19.0),
		tick.position + Vector2(21.0, 6.0),
		_ink(_pick()),
		noise,
		3.0
	)
	_say("전체 화면", Vector2(tick.end.x + 14.0, tick.position.y + 19.0), 15, _paper(), noise)

	var wipe := Rect2(box.position.x, box.end.y - 46.0, box.size.x, 40.0)
	_paint(_box(wipe), _peril(), noise)
	_say(
		"기록 버리기",
		Vector2(wipe.position.x, wipe.get_center().y + 6.0),
		17,
		_ink(_peril()),
		noise,
		wipe.size.x,
		HORIZONTAL_ALIGNMENT_CENTER
	)


## 강조 — **화면에서 노이즈 0.00 인 곳.** 팝업이 열리면 이 자리를 내준다.
##
## idle 에서 **한 픽셀도 안 움직인다.** 다른 것이 전부 떠는 화면에서 안 떠는 것 하나는
## 그 자체로 신호다 — 움직여서 눈을 끄는 것보다 세다.
func _mark() -> void:
	var noise := _noise(HERE)
	var box := Rect2(PAD, MARK_TOP, CARD.x - PAD * 2.0, MARK_TALL)
	_say("강조 — 지금 여기", Vector2(PAD, MARK_TOP - 10.0), 13, Color(_paper(), 0.6), _noise(LIVE))
	_paint(_box(box), _accent(), noise)
	_say(
		"3층 봉인된 문",
		Vector2(box.position.x, box.get_center().y + 9.0),
		24,
		_ink(_accent()),
		noise,
		box.size.x,
		HORIZONTAL_ALIGNMENT_CENTER
	)


## 팝업 — 열리면 **초점이 여기로 넘어온다.** 나머지가 한 칸 시끄러워지는 것이 가림막이다.
func _popup() -> void:
	var force := _pop_force()
	if force <= 0.0:
		return
	# 열리는 동안은 아직 초점이 안 맞았다. **또렷해지는 것 자체가 등장이다.**
	var noise := lerpf(LIVE, HERE, force)
	_paint(_box(POPUP), _paper(), noise)
	_say(
		"기록을 버릴까",
		Vector2(POPUP.position.x, POPUP.position.y + 58.0),
		22,
		_ink(_paper()),
		noise,
		POPUP.size.x,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_say(
		"되돌릴 수 없다",
		Vector2(POPUP.position.x, POPUP.position.y + 88.0),
		14,
		Color(_ink(_paper()), 0.7),
		noise,
		POPUP.size.x,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	var wide := (POPUP.size.x - 48.0) * 0.5
	var yes := Rect2(POPUP.position.x + 16.0, POPUP.end.y - 56.0, wide, 40.0)
	var no := Rect2(yes.end.x + 16.0, yes.position.y, wide, 40.0)
	_paint(_box(yes), _peril(), noise)
	_say(
		"버린다",
		Vector2(yes.position.x, yes.get_center().y + 6.0),
		17,
		_ink(_peril()),
		noise,
		yes.size.x,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_paint(_box(no), Color(_void(), 0.5), noise)
	_say(
		"둔다",
		Vector2(no.position.x, no.get_center().y + 6.0),
		17,
		_paper(),
		noise,
		no.size.x,
		HORIZONTAL_ALIGNMENT_CENTER
	)
