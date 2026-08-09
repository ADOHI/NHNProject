class_name RadialStage
extends Control
## **원형 인물 배치 + 홀로그램 창.** 조우 중에 태블릿으로 상대를 훑는 화면이다.
##
##     godot --path . res://src/ui/kit/radial_stage.tscn
##
## **고른 인물이 가운데로 온다.** 휠을 돌리면 링이 돌고 다음 인물이 가운데에 서고
## 창이 그 인물에게 옮겨 붙는다. **가운데가 곧 선택됨이라 표지가 따로 없다.**
##
## 판 넷을 나란히 놓는다. **같은 회전을 하되 화려함만 다르다.**
##
## | 판 | 화려함 | 왜 |
## | --- | --- | --- |
## | 지금 | 0 | 구조만. 비교 기준 |
## | 얹음 | 1 | 창이 형태를 갖고 색수차가 붙는다. **가운데에만 터진다** |
## | 과하게 | 2 | 전부 다 빛난다. **경계를 알려면 넘어가 본 게 있어야 한다** |
## | 스쿼드 여섯 | 0 | 멀리 보기 — 비교 |
##
## **정지로는 절반도 판정이 안 된다.** 접힘과 펴짐이 이 화면의 사건이라 GIF 가 판정 매체다.

const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")

const DESK := Color("#aab5c2")
const SHEET := Color("#dee2e8")
const GLASS := Color("#c6d2df")
const RULE := Color("#6f8098")
const RULE_SOFT := Color("#93a2b5")
const INK := Color("#212a37")
const DIM := Color("#6d7681")
const ACCENT := Color("#c0705f")

## 색수차의 차가운 쪽. **네온 청록이 아니다** — 같은 파스텔 청회색 계열이다(§20.16.2).
const COOL := Color("#5c86a8")

## 태블릿 화면 하나. 게임 화면과 같은 크기여야 창 크기가 거짓말을 안 한다.
const SCREEN := Vector2(1280.0, 720.0)
const PANEL_GAP := Vector2(30.0, 96.0)
const TOP: float = 128.0

const SEED: int = 20260809
const POPULATION: int = 240
const SQUAD: int = 6

## 아는 얼굴. **여섯이 조용하고 한 장만 터진다** — 밀도 대비의 교과서적 자리다.
const KNOWN: int = 2

const LOOP: float = 6.00

## 한 바퀴를 도는 데 쓰는 시간. **여섯 칸을 다 돌아 처음으로 돌아온다** —
## 링이 이어지는지는 한 바퀴를 봐야 안다.
const TURN_TIME: float = 5.20

## 화려함 층. 0 = 지금 · 1 = 얹음 · 2 = 과하게.
const PLAIN: int = 0
const DRESSED: int = 1
const TOO_MUCH: int = 2

var _figures: Array[Texture2D] = []
var _sheet: Array[SheetSection] = []
var _names: Array[String] = []
var _ink := SheetPainter.new()
var _clock := 0.0
var _frozen := false
var _driven := false


func _ready() -> void:
	_build()
	if not _driven:
		set_process(true)


func drive_externally() -> void:
	_driven = true
	set_process(false)


func _build() -> void:
	for i in SQUAD:
		var path := "res://assets/ui/kit/cast/figure_%d.webp" % i
		if ResourceLoader.exists(path):
			_figures.append(load(path))
	var registry := PersonGenerator.new(SEED, POPULATION).generate()
	var factions := FactionIndex.new(registry)
	for i in SQUAD:
		_names.append(registry.name_of(i * 7 + 3))
	_sheet = PersonSheet.build(registry, 3, factions)
	_ink.sections = _sheet
	_ink.paged = true


func _process(delta: float) -> void:
	if _driven:
		return
	if not _frozen:
		set_clock(fposmod(_clock + delta, LOOP))


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_S:
		_frozen = not _frozen


func set_clock(t: float) -> void:
	_clock = t
	queue_redraw()


## 지금 고른 인물. **칸마다 멈췄다 다음으로 간다** — 등속으로 돌면 「고른다」가 아니라
## 「돌아간다」로 읽힌다.
##
## 한 칸을 `머무름 + 넘어감` 으로 나누고 넘어감에만 곡선을 준다.
func _picked() -> float:
	var step := TURN_TIME / float(SQUAD)
	var slot := floorf(_clock / step)
	var within := fposmod(_clock, step) / step
	# 앞 55%는 멈춰 있고 뒤 45%에 넘어간다.
	var moved := smoothstep(0.55, 1.0, within)
	return slot + moved


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SHEET)
	_label("조우 중 — 원형 인물 배치와 홀로그램 창", Vector2(30.0, 48.0), 22, INK)
	_label("휠로 돌리면 다음 인물. 도는 동안 창이 접히고 멈추면 펴진다. 창을 누르면 그 칸으로 들어간다.", Vector2(30.0, 76.0), 14, DIM)
	_label("전신 일러스트는 초상 레인이 뽑은 832x1216 실물이다.", Vector2(30.0, 100.0), 13, DIM)

	_panel(0, "지금 — 구조만")
	_panel(1, "얹음 — 창이 형태를 갖는다")
	_panel(2, "과하게 — 넘어가 본 자리")
	_panel(3, "멀리 — 스쿼드 여섯 비교")


func _panel(index: int, title: String) -> void:
	var at := Vector2(
		PANEL_GAP.x + float(index % 2) * (SCREEN.x + PANEL_GAP.x),
		TOP + float(index / 2) * (SCREEN.y + PANEL_GAP.y)
	)
	_label(title, at + Vector2(0.0, -14.0), 16, INK)
	# 태블릿 뒤로 던전이 비친다. **조우 중이라는 것이 화면에 있어야 한다.**
	_behind(at)
	draw_rect(Rect2(at, SCREEN), Color(DESK, 0.86))
	draw_rect(Rect2(at, SCREEN), Color(RULE, 0.6), false, 1.5)

	match index:
		3:
			_draw_squad(at)
		_:
			_draw_one(at, _picked(), index)


## 태블릿 너머의 던전. **화면 안이 아니라 뒤다** — 가장자리로만 스친다.
func _behind(at: Vector2) -> void:
	for i in 11:
		var turn := fposmod(0.21 + float(i) * 0.6180339887, 1.0)
		draw_rect(
			Rect2(
				at.x - 18.0 + SCREEN.x * turn,
				at.y - 16.0 + SCREEN.y * fposmod(turn * 3.7, 1.0),
				40.0 + turn * 120.0,
				10.0 + turn * 26.0
			),
			Color(RULE, 0.10 + 0.10 * turn)
		)


## 한 명 — 원형 + 창 다섯. `turned` 는 휠이 굴러간 칸 수다(1.0 = 한 칸).
func _draw_one(at: Vector2, picked: float, dress: int) -> void:
	var order: Array = []
	for i in SQUAD:
		order.append(i)
	# 뒤쪽 인물부터 그린다. 앞이 나중이라야 겹침이 옳다.
	order.sort_custom(
		func(a: int, b: int) -> bool:
			return RadialDeck.nearness(a, SQUAD, picked) < RadialDeck.nearness(b, SQUAD, picked)
	)
	var front := RadialDeck.front_index(SQUAD, picked)
	for i in order:
		_figure(at, i, picked, 1.0, i == front, dress)

	# **가운데가 바뀌는 순간이 접힘과 펴짐의 경계다.** 그래서 창이 옮겨 붙는 것을
	# 볼 일이 없다 — 옮겨 붙는 동안 접혀 있다.
	var settled := RadialDeck.settled(picked)
	var moving := settled < 0.99
	var figure := _figure_rect(front, picked, 1.0)
	for slot in RadialDeck.count():
		var here := slot as RadialDeck.Slot
		var open := clampf(RadialDeck.open_amount(here, settled, moving), 0.0, 1.0)
		_hologram(at, here, figure, open, 1.0, dress)
	if dress != PLAIN:
		_label("%s | 가운데가 곧 선택됨" % _names[front], at + Vector2(30.0, SCREEN.y - 26.0), 15, DIM)


## **판 안 좌표다.** 판 오프셋은 그리는 자리에서만 더한다 — 상자에 넣어 두면
## 창 자리 계산에서 한 번 더 더해져 판이 오른쪽에 있을수록 창이 밖으로 밀린다.
## 판이 하나뿐인 동안에는 오프셋이 작아 안 보였다.
func _figure_rect(index: int, picked: float, zoom: float) -> Rect2:
	var stand := RadialDeck.stand(index, SQUAD, picked, zoom, SCREEN)
	var scale := RadialDeck.figure_scale(index, SQUAD, picked, zoom)
	var tall := 456.0 * scale
	var wide := 312.0 * scale
	return Rect2(stand - Vector2(wide * 0.5, tall * 0.86), Vector2(wide, tall))


func _figure(at: Vector2, index: int, picked: float, zoom: float, front: bool, dress: int) -> void:
	var box := Rect2(
		at + _figure_rect(index, picked, zoom).position, _figure_rect(index, picked, zoom).size
	)
	var near := RadialDeck.nearness(index, SQUAD, picked)
	# 발치의 그림자가 원형을 읽히게 한다. 없으면 인물이 공중에 떠 있다.
	draw_circle(
		Vector2(box.get_center().x, box.end.y), box.size.x * 0.30, Color(RULE, 0.08 + 0.15 * near)
	)
	if _figures.is_empty():
		draw_rect(box, Color(RULE_SOFT, 0.5))
		return
	# **뒤로 갈수록 옅다.** 밝기와 크기 둘이 같이 가야 「뒤에 있다」로 읽힌다.
	draw_texture_rect(
		_figures[index % _figures.size()], box, false, Color(1.0, 1.0, 1.0, 0.22 + 0.78 * near)
	)
	if not front:
		return
	# **여기가 밀도가 터지는 자리다.** 나머지는 조용하다.
	draw_rect(Rect2(box.position.x, box.end.y + 4.0, box.size.x, 2.0), Color(ACCENT, 0.9))
	if dress == PLAIN:
		return
	_footing(box, dress)


## 가운데 인물의 발치 표. **겹인쇄를 색수차로 다시 읽은 것**(§20.16.2)이 여기 붙는다.
func _footing(box: Rect2, dress: int) -> void:
	var ring := Rect2(box.position.x - 26.0, box.end.y - 16.0, box.size.x + 52.0, 34.0)
	for i in RadialDeck.count():
		var turn := fposmod(0.19 + float(i) * 0.6180339887, 1.0)
		draw_rect(
			Rect2(ring.position.x + ring.size.x * turn, ring.end.y - 4.0, 3.0 + turn * 9.0, 2.0),
			Color(RULE, 0.5)
		)
	draw_rect(Rect2(ring.position + Vector2(-2.5, -1.5), ring.size), Color(COOL, 0.42), false, 1.0)
	draw_rect(Rect2(ring.position + Vector2(2.5, 1.5), ring.size), Color(ACCENT, 0.38), false, 1.0)
	if dress != TOO_MUCH:
		return
	# 과하게 — 후광과 눈금을 더 얹는다. **이 판은 시끄러운 것이 목적이다.**
	for i in 5:
		draw_rect(
			Rect2(
				box.position - Vector2(float(i) * 5.0, float(i) * 5.0),
				box.size + Vector2(float(i) * 10.0, float(i) * 10.0)
			),
			Color(COOL, 0.14 - 0.02 * float(i)),
			false,
			1.0
		)


## 홀로그램 창 하나. **테두리가 색수차로 갈라진다** — 겹인쇄를 신호로 다시 읽은 것(§20.16.2).
func _hologram(
	at: Vector2, slot: RadialDeck.Slot, figure: Rect2, open: float, zoom: float, dress: int
) -> void:
	var box := RadialDeck.slot_rect(slot, figure, SCREEN, open)
	var line := RadialDeck.tether(slot, figure, SCREEN, open)
	# **선은 창이 접혀도 남는다.** 끝점이 접힌 표식으로 옮겨갈 뿐이다 —
	# 선이 사라지면 그 칸이 어디 붙어 있었는지를 잊는다.
	if dress == PLAIN:
		draw_line(at + line[0], at + line[1], Color(COOL, 0.28 + 0.34 * open), 1.2, true)
	else:
		# **선에도 겹인쇄를 건다.** 두 색이 어긋나 지나가면 그냥 선이 아니라 신호가 된다.
		var away := (line[1] - line[0]).orthogonal().normalized() * 1.6
		draw_line(
			at + line[0] - away, at + line[1] - away, Color(COOL, 0.30 + 0.30 * open), 1.0, true
		)
		draw_line(
			at + line[0] + away, at + line[1] + away, Color(ACCENT, 0.22 + 0.26 * open), 1.0, true
		)
		draw_line(at + line[0], at + line[1], Color(RULE, 0.30 + 0.30 * open), 1.0, true)
	draw_circle(at + line[0], 3.0, Color(ACCENT, 0.9))

	var pane := Rect2(at + box.position, box.size)
	if open < 0.22:
		draw_rect(pane, Color(GLASS, 0.30 + 0.58 * open))
		# 접힌 모양이 그 창의 종류를 말한다 — 성향은 막대 하나, 관계는 점 넷.
		for mark in RadialDeck.folded_marks(slot, box):
			draw_rect(Rect2(at + mark.position, mark.size), Color(RULE, 0.75))
		return

	# **창 자체가 형태다.** 네모가 아니라 이 킷이 만든 실루엣을 쓴다(§20.14).
	var shape := _pane_shape(slot, pane, dress)
	draw_colored_polygon(shape, Color(GLASS, 0.30 + 0.58 * open))
	if dress != PLAIN:
		_pane_edge(shape, open, dress)
	else:
		draw_polyline(_closed(shape), Color(RULE, 0.65), 1.2, true)
	if open < 0.72:
		return
	draw_string(
		FONT,
		pane.position + Vector2(16.0, 20.0),
		RadialDeck.label(slot),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		Color(INK, open)
	)
	draw_rect(Rect2(pane.position.x + 16.0, pane.position.y + 26.0, 22.0, 2.0), Color(ACCENT, open))
	if not RadialDeck.shows_text(zoom):
		return
	_ink.only = [_section_for(slot)]
	_ink.columns = 1
	_ink.scroll = 0.0
	_ink.paint(
		self, Rect2(pane.position + Vector2(16.0, 44.0), pane.size - Vector2(32.0, 56.0)), open
	)


## 창의 실루엣. **네모를 벗어난다** — 이 킷이 여덟 판에 만든 형태를 창 모양으로 쓴다.
##
## 자리마다 다른 형태를 주지 않는다. **같은 화면에 형태가 다섯이면 그게 시끄러움이다** —
## 모따기 하나를 공통으로 쓰고, 붙은 쪽에 따라 **깎이는 모서리만 반대**로 둔다.
func _pane_shape(slot: RadialDeck.Slot, pane: Rect2, dress: int) -> PackedVector2Array:
	var cut := 12.0 if dress == PLAIN else 18.0
	var left := pane.position.x
	var top := pane.position.y
	var right := pane.end.x
	var bottom := pane.end.y
	if RadialDeck.side(slot) > 0:
		# 오른쪽 창은 **몸 쪽 모서리**가 깎인다. 선이 들어오는 자리를 비켜 준다.
		return PackedVector2Array(
			[
				Vector2(left + cut, top),
				Vector2(right, top),
				Vector2(right, bottom),
				Vector2(left + cut, bottom),
				Vector2(left, bottom - cut),
				Vector2(left, top + cut),
			]
		)
	return PackedVector2Array(
		[
			Vector2(left, top),
			Vector2(right - cut, top),
			Vector2(right, top + cut),
			Vector2(right, bottom - cut),
			Vector2(right - cut, bottom),
			Vector2(left, bottom),
		]
	)


## 창 테두리. **색수차는 펴진 창에만** — 접힌 표식까지 갈라지면 골고루가 되어 죽는다.
func _pane_edge(shape: PackedVector2Array, open: float, dress: int) -> void:
	var ring: PackedVector2Array = _closed(shape)
	var split := 2.5 if dress == DRESSED else 5.0
	var shifted := PackedVector2Array()
	for point in ring:
		shifted.append(point + Vector2(-split, -split * 0.6))
	draw_polyline(shifted, Color(COOL, 0.34 * open), 1.0, true)
	shifted = PackedVector2Array()
	for point in ring:
		shifted.append(point + Vector2(split, split * 0.6))
	draw_polyline(shifted, Color(ACCENT, 0.30 * open), 1.0, true)
	draw_polyline(ring, Color(RULE, 0.68), 1.2, true)
	if dress != TOO_MUCH:
		return
	# 과하게 — 눈금까지 두른다. **모든 창이 다 빛나면 어디를 봐야 할지 모른다.**
	var box := PlateForm.bounds(shape)
	var y := box.position.y + 6.0
	while y < box.end.y - 4.0:
		draw_rect(Rect2(box.end.x - 9.0, y, 6.0, 1.0), Color(RULE, 0.55))
		y += 8.0


func _section_for(slot: RadialDeck.Slot) -> String:
	match slot:
		RadialDeck.Slot.TIES:
			return "관계"
		RadialDeck.Slot.TRAITS:
			return "성향"
		RadialDeck.Slot.GEAR:
			return "길드"
		RadialDeck.Slot.CHRONICLE:
			return "인물 열전"
		_:
			return "인물"


## 스쿼드 여섯 — 나란히 비교.
##
## **글이 거의 안 들어간다**(§20.16.4 — 창 폭 420px 아래는 한 열이고 여섯을 한 화면에
## 놓으면 그보다 훨씬 좁다). 그래서 여기서 나오는 것은 **도형 하나**다.
func _draw_squad(at: Vector2) -> void:
	for i in SQUAD:
		var box := Rect2(at + _figure_rect(i, 0.0, 0.0).position, _figure_rect(i, 0.0, 0.0).size)
		if not _figures.is_empty():
			draw_texture_rect(_figures[i % _figures.size()], box, false, Color(1, 1, 1, 0.92))
		var known := i == KNOWN
		var card := Rect2(box.position.x - 8.0, box.end.y + 12.0, box.size.x + 16.0, 64.0)
		draw_rect(card, Color(GLASS, 0.78 if known else 0.34))
		draw_rect(
			card, Color(ACCENT, 0.95) if known else Color(RULE, 0.5), false, 2.0 if known else 1.0
		)
		draw_string(
			FONT,
			card.position + Vector2(10.0, 21.0),
			_names[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			card.size.x - 34.0,
			15,
			Color(INK, 1.0 if known else 0.72)
		)
		# 위협 신호 — **도형이다.** 아는 얼굴만 강세로 터진다.
		for bar in 3:
			var lit := bar <= i % 3
			var tone := Color(RULE, 0.55 if lit else 0.16)
			draw_rect(
				Rect2(
					card.position.x + 10.0 + float(bar) * 15.0, card.position.y + 34.0, 11.0, 14.0
				),
				Color(ACCENT, 0.95) if (lit and known) else tone
			)
		# 모르는 칸은 「?」다. **빈칸이 있으면 도감이 아니라 스캔 중인 기기로 읽힌다.**
		if not known:
			draw_string(
				FONT,
				card.position + Vector2(card.size.x - 24.0, 48.0),
				"?",
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				20,
				Color(DIM, 0.85)
			)
	_label("아는 얼굴 하나만 터진다 | 나머지는 ? 다", at + Vector2(30.0, SCREEN.y - 26.0), 15, DIM)


## 창 하나 확대 — 그 칸이 화면을 채운다. 여기서 휠은 줌이나 스크롤이다.
func _draw_window(at: Vector2) -> void:
	var box := Rect2(at + Vector2(90.0, 70.0), Vector2(SCREEN.x - 180.0, SCREEN.y - 150.0))
	draw_rect(box, Color(GLASS, 0.72))
	draw_rect(box, Color(RULE, 0.75), false, 1.4)
	draw_rect(Rect2(box.position + Vector2(-3.0, -2.0), box.size), Color(COOL, 0.35), false, 1.0)
	draw_rect(Rect2(box.position + Vector2(3.0, 2.0), box.size), Color(ACCENT, 0.32), false, 1.0)
	draw_string(
		FONT, box.position + Vector2(20.0, 34.0), "성향", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK
	)
	draw_rect(Rect2(box.position.x + 20.0, box.position.y + 42.0, 32.0, 2.0), ACCENT)
	_ink.only = ["성향", "인물"]
	_ink.columns = 2
	_ink.scroll = 0.0
	_ink.paint(self, Rect2(box.position + Vector2(20.0, 66.0), box.size - Vector2(40.0, 86.0)), 1.0)
	_label("휠 = 줌/스크롤 | 바깥을 누르면 나온다", at + Vector2(30.0, SCREEN.y - 26.0), 15, DIM)


func _label(what: String, at: Vector2, size_px: int, color: Color) -> void:
	draw_string(FONT, at, what, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)


func _closed(shape: PackedVector2Array) -> PackedVector2Array:
	var out := shape.duplicate()
	out.append(shape[0])
	return out
