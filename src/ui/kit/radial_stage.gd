class_name RadialStage
extends Control
## **원형 인물 배치 + 홀로그램 창.** 조우 중에 태블릿으로 상대를 훑는 화면이다.
##
##     godot --path . res://src/ui/kit/radial_stage.tscn
##
## 판 넷을 나란히 놓는다. **같은 시계를 쓰되 판마다 다른 층을 본다.**
##
## | 판 | 무엇 | 왜 |
## | --- | --- | --- |
## | 한 명 — 접혔다 펴진다 | 휠로 돌리면 창이 접히고 멈추면 펴진다 | 확정된 거동 |
## | 한 명 — 멈추기 전에 다시 돌린다 | 펴지다 말고 다시 접힌다 | **중간 상태가 되는지** |
## | 스쿼드 여섯 | 위협 신호 하나씩, **아는 얼굴 하나만 터진다** | 비교 |
## | 창 하나 확대 | 그 칸이 화면을 채운다 | 이해 |
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

## 휠을 굴린 구간. **돌리는 동안 창이 접혀 있다.**
const SPIN_IN := Vector2(0.60, 1.90)

## 두 번째 판이 쓰는 구간. 첫 번째가 다 펴지기 전에 두 번째가 시작된다.
const NUDGE_ONE := Vector2(0.35, 1.10)
const NUDGE_TWO := Vector2(1.35, 2.30)
const NUDGE_AT: float = 1.25

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


## 휠 한 칸이 굴러간 정도 0..1.
func _rolled(window: Vector2) -> float:
	return smoothstep(window.x, window.y, _clock)


## 펴지다 말고 다시 접히는 경우. **중간 상태에서 잘 되는지가 그 판의 전부다.**
func _interrupted() -> float:
	if _clock < NUDGE_AT:
		return _rolled(NUDGE_ONE)
	return 1.0 + _rolled(NUDGE_TWO)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SHEET)
	_label("조우 중 — 원형 인물 배치와 홀로그램 창", Vector2(30.0, 48.0), 22, INK)
	_label("휠로 돌리면 다음 인물. 도는 동안 창이 접히고 멈추면 펴진다. 창을 누르면 그 칸으로 들어간다.", Vector2(30.0, 76.0), 14, DIM)
	_label("전신 일러스트는 초상 레인이 뽑은 832x1216 실물이다.", Vector2(30.0, 100.0), 13, DIM)

	_panel(0, "한 명 — 접혔다 펴진다")
	_panel(1, "한 명 — 멈추기 전에 다시 돌린다")
	_panel(2, "스쿼드 여섯 — 비교")
	_panel(3, "창 하나 확대 — 휠은 여기서 줌")


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
		2:
			_draw_squad(at)
		3:
			_draw_window(at)
		1:
			_draw_one(at, _interrupted())
		_:
			_draw_one(at, _rolled(SPIN_IN))


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
func _draw_one(at: Vector2, turned: float) -> void:
	var spin := turned * TAU / float(SQUAD)
	var order: Array = []
	for i in SQUAD:
		order.append(i)
	# 뒤쪽 인물부터 그린다. 앞이 나중이라야 겹침이 옳다.
	order.sort_custom(
		func(a: int, b: int) -> bool:
			return RadialDeck.nearness(a, SQUAD, spin) < RadialDeck.nearness(b, SQUAD, spin)
	)
	var front: int = order[order.size() - 1]
	for i in order:
		_figure(at, i, spin, 1.0, i == front)

	# 한 칸의 어디쯤인가. 0 과 1 근처면 멈춘 것이고 가운데면 도는 중이다.
	var within := fposmod(turned, 1.0)
	var moving := within > 0.03 and within < 0.97
	var settled := 1.0 - minf(within, 1.0 - within) * 2.0
	var figure := _figure_rect(at, front, spin, 1.0)
	for slot in RadialDeck.count():
		var here := slot as RadialDeck.Slot
		var open := RadialDeck.open_amount(here, settled, moving)
		_hologram(at, here, figure, clampf(open, 0.0, 1.0), 1.0)


func _figure_rect(at: Vector2, index: int, spin: float, zoom: float) -> Rect2:
	var near := RadialDeck.nearness(index, SQUAD, spin)
	var stand := RadialDeck.stand(index, SQUAD, spin, zoom, SCREEN)
	var scale := (0.40 + 0.32 * near) if zoom > RadialDeck.TO_ONE else 0.62
	var tall := 456.0 * scale
	var wide := 312.0 * scale
	return Rect2(at + stand - Vector2(wide * 0.5, tall * 0.86), Vector2(wide, tall))


func _figure(at: Vector2, index: int, spin: float, zoom: float, front: bool) -> void:
	var box := _figure_rect(at, index, spin, zoom)
	var near := RadialDeck.nearness(index, SQUAD, spin)
	# 발치의 그림자가 원형을 읽히게 한다. 없으면 인물이 공중에 떠 있다.
	draw_circle(
		Vector2(box.get_center().x, box.end.y), box.size.x * 0.30, Color(RULE, 0.10 + 0.13 * near)
	)
	if _figures.is_empty():
		draw_rect(box, Color(RULE_SOFT, 0.5))
		return
	draw_texture_rect(
		_figures[index % _figures.size()], box, false, Color(1.0, 1.0, 1.0, 0.32 + 0.68 * near)
	)
	if front:
		draw_rect(Rect2(box.position.x, box.end.y + 4.0, box.size.x, 2.0), Color(ACCENT, 0.9))


## 홀로그램 창 하나. **테두리가 색수차로 갈라진다** — 겹인쇄를 신호로 다시 읽은 것(§20.16.2).
func _hologram(at: Vector2, slot: RadialDeck.Slot, figure: Rect2, open: float, zoom: float) -> void:
	var box := RadialDeck.slot_rect(slot, figure, SCREEN, open)
	var line := RadialDeck.tether(slot, figure, SCREEN, open)
	# **선은 창이 접혀도 남는다.** 끝점이 접힌 표식으로 옮겨갈 뿐이다 —
	# 선이 사라지면 그 칸이 어디 붙어 있었는지를 잊는다.
	draw_line(at + line[0], at + line[1], Color(COOL, 0.28 + 0.34 * open), 1.2, true)
	draw_circle(at + line[0], 3.0, Color(ACCENT, 0.9))

	var pane := Rect2(at + box.position, box.size)
	draw_rect(pane, Color(GLASS, 0.30 + 0.58 * open))
	if open < 0.22:
		# 접힌 모양이 그 창의 종류를 말한다 — 성향은 막대 하나, 관계는 점 넷.
		for mark in RadialDeck.folded_marks(slot, box):
			draw_rect(Rect2(at + mark.position, mark.size), Color(RULE, 0.75))
		return

	draw_rect(pane, Color(RULE, 0.65), false, 1.2)
	# 색수차는 **펴진 창에만.** 접힌 표식까지 갈라지면 골고루가 되어 밀도 대비가 죽는다.
	draw_rect(
		Rect2(pane.position + Vector2(-2.5, -1.5), pane.size), Color(COOL, 0.34 * open), false, 1.0
	)
	draw_rect(
		Rect2(pane.position + Vector2(2.5, 1.5), pane.size), Color(ACCENT, 0.30 * open), false, 1.0
	)
	if open < 0.72:
		return
	draw_string(
		FONT,
		pane.position + Vector2(12.0, 20.0),
		RadialDeck.label(slot),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		Color(INK, open)
	)
	draw_rect(Rect2(pane.position.x + 12.0, pane.position.y + 26.0, 22.0, 2.0), Color(ACCENT, open))
	if not RadialDeck.shows_text(zoom):
		return
	_ink.only = [_section_for(slot)]
	_ink.columns = 1
	_ink.scroll = 0.0
	_ink.paint(
		self, Rect2(pane.position + Vector2(12.0, 44.0), pane.size - Vector2(24.0, 56.0)), open
	)


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
		var box := _figure_rect(at, i, 0.0, 0.0)
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
