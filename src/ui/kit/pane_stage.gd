class_name PaneStage
extends Control
## **떠 있는 창 배치 넷.** 태블릿 화면 넷을 나란히 놓고 창이 앞뒤를 바꾸는 것을 본다.
##
##     godot --path . res://src/ui/kit/pane_stage.tscn
##
## | 조작 | 무엇 |
## | --- | --- |
## | `S` | 시계 정지 |
##
## ## 판마다 무엇을 다르게 했나
##
## | 배치 | 겹침 | 세계 |
## | --- | --- | --- |
## | 층진 창 | 넷이 계단으로 깊게 겹친다 | 계측면 |
## | 끝에 물린 창 | 도킹 하나 + 뜬 것 둘 | 계측면 |
## | 갈라 붙인 창 | **안 겹친다.** 셋이 동시에 다 읽힌다 | 신호 |
## | 흩어 띄운 창 | 크기가 제각각, 살짝씩 겹친다 | 신호 |
##
## ## 화면에 적히는 값
##
## 창마다 **열 수**와 **글이 몇 줄 안 들어갔나**를 적는다. 창이 여럿이면 창 하나가
## 좁아지므로 **좁은 창에서 두 열이 되는지**가 정보 설계를 바꾼다 —
## 「끝에 물린 창」의 도킹 창이 256px 이고 그게 가장 좁은 경우다.

const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")

## 태블릿 바탕. 창보다 어두워야 창이 떠 보인다.
const DESK := Color("#b9c2cd")
const SHEET := Color("#dee2e8")
const PANE := Color("#ccd6e1")
const PANE_BACK := Color("#c2ccd8")
const RULE := Color("#6f8098")
const RULE_SOFT := Color("#93a2b5")
const INK := Color("#212a37")
const DIM := Color("#6d7681")
const SHADOW := Color("#8e98a6")
const ACCENT := Color("#c0705f")

## 색수차의 차가운 쪽. **네온 청록이 아니다** — 같은 파스텔 청회색 계열에서 고른다.
const COOL := Color("#5c86a8")

const SEED: int = 20260809
const POPULATION: int = 240

## 한 판이 앉는 자리.
const PANEL_GAP := Vector2(30.0, 84.0)
const TOP: float = 118.0

const LOOP: float = 5.20
const OPEN_AT: float = 0.25

## 뒤 창이 앞으로 나오는 구간과 되돌아가는 구간. **겹치지 않아야 두 사건이 갈린다.**
const RAISE_IN := Vector2(1.50, 2.10)
const DROP_IN := Vector2(3.40, 3.85)

var _who := ""
var _sheet: Array[SheetSection] = []
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
	var maker := PersonGenerator.new(SEED, POPULATION)
	var registry := maker.generate()
	var factions := FactionIndex.new(registry)
	var person := 0
	for i in registry.size():
		if registry.name_of(i).length() > registry.name_of(person).length():
			person = i
	_who = registry.name_of(person)
	_sheet = PersonSheet.build(registry, person, factions)
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


## 뒤 창 하나가 앞으로 나온 정도 0..1.
func _lift() -> float:
	var up := smoothstep(RAISE_IN.x, RAISE_IN.y, _clock)
	var down := smoothstep(DROP_IN.x, DROP_IN.y, _clock)
	if _clock < DROP_IN.x:
		return PaneDeck.rise(up)
	return 1.0 - PaneDeck.sink(down)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SHEET)
	_label("떠 있는 창 — 태블릿에 창이 여럿", Vector2(30.0, 46.0), 21, INK)
	_label("탭이 아니라 창이다. 동시에 여럿 보이고 앞뒤가 있다. 자리가 뜻을 갖는다.", Vector2(30.0, 72.0), 14, DIM)
	_label("인물 | %s | 앞 창만 글을 든다" % _who, Vector2(30.0, 94.0), 13, DIM)

	for kind in PaneDeck.count():
		var at := Vector2(
			PANEL_GAP.x + float(kind % 2) * (PaneDeck.SCREEN.x + PANEL_GAP.x),
			TOP + float(kind / 2) * (PaneDeck.SCREEN.y + PANEL_GAP.y)
		)
		_panel(kind as PaneDeck.Kind, at)


func _panel(kind: PaneDeck.Kind, at: Vector2) -> void:
	_label(
		"%s  |  %s" % [PaneDeck.label(kind), PaneDeck.air_label(kind)],
		at + Vector2(0.0, -14.0),
		16,
		INK
	)
	draw_rect(Rect2(at, PaneDeck.SCREEN), DESK)
	draw_rect(Rect2(at, PaneDeck.SCREEN), Color(RULE, 0.55), false, 1.0)

	var panes := PaneDeck.panes(kind)
	var order := _order(panes.size())
	var told := ""
	for slot in order.size():
		var index: int = order[slot]
		var deep := PaneDeck.depth(slot, order.size())
		var front := slot == order.size() - 1
		# 앞 창이 통째로 덮은 창은 글을 안 그린다. **안 보이는 글을 그리면 느리고,
		# 그린 줄 알고 자리를 재면 거짓말이 된다.**
		var hidden := false
		for later in range(slot + 1, order.size()):
			if PaneDeck.covers(panes[order[later]], panes[index]):
				hidden = true
		told += _pane(kind, panes[index], at, deep, front, index, hidden)
	_label(told, at + Vector2(4.0, PaneDeck.SCREEN.y + 22.0), 14, DIM)


## 지금의 앞뒤 순서. 평상시에는 그대로고, 들어올리는 동안 **첫 창이 맨 앞으로** 온다.
##
## 자리를 서서히 바꾸지 않고 **절반을 넘으면 자리를 맞바꾼다.** 창이 서로를 통과하는
## 것이 아니라 **앞으로 온 것**으로 읽혀야 하기 때문이다.
func _order(total: int) -> Array:
	var out := []
	for i in total:
		out.append(i)
	if _lift() > 0.5:
		out.remove_at(0)
		out.append(0)
	return out


## 창 하나. 돌려주는 것은 화면 아래에 적을 한 마디다.
func _pane(
	kind: PaneDeck.Kind,
	rect: Rect2,
	at: Vector2,
	deep: float,
	front: bool,
	index: int,
	hidden: bool
) -> String:
	var lift := _lift() if index == 0 else 0.0
	# 앞으로 오면 커지고 뒤로 가면 작아진다 — **같은 축의 양끝**(§20.10).
	var grow := 1.0 + 0.035 * lift
	var here := Rect2(at + rect.position - rect.size * (grow - 1.0) * 0.5, rect.size * grow)
	var shape := PaneDeck.outline(here)

	# 그림자 거리는 **절대값**이다 — 판이 뜬 높이는 판 크기가 아니라 표면과의 거리다.
	var drop := 3.0 + 7.0 * deep + 5.0 * lift
	var dropped := PackedVector2Array()
	for point in shape:
		dropped.append(point + Vector2(drop * 0.35, drop))
	draw_colored_polygon(dropped, Color(SHADOW, 0.16 + 0.22 * deep))

	draw_colored_polygon(shape, PANE_BACK.lerp(PANE, deep))
	_chrome(kind, here, shape, deep, front or lift > 0.5)

	_title(kind, here, index, 0.55 + 0.45 * deep)
	if hidden:
		return ""
	var box := PaneDeck.body(here)
	_ink.only = PaneDeck.cargo(kind)[index]
	# **좁은 창에서 두 열이 되나.** 이 물음이 정보 설계를 바꾼다.
	var wants := 2 if _ink.fits(box, 2) else 1
	_ink.columns = wants
	_ink.scroll = 0.0
	_ink.paged = true
	# 뒤 창도 글을 든다 — **창이 여럿인 이유가 그것이다.** 다만 흐리다.
	_ink.paint(self, box, 0.45 + 0.55 * deep)
	return "%dx%d %d열   " % [int(rect.size.x), int(rect.size.y), wants]


## 창의 테두리와 제목 띠. **세계가 갈리는 자리가 여기뿐이다** — 판과 글은 똑같다.
func _chrome(
	kind: PaneDeck.Kind, rect: Rect2, shape: PackedVector2Array, deep: float, hot: bool
) -> void:
	var bar := PaneDeck.title_bar(rect)
	if PaneDeck.air(kind) == PaneDeck.Air.SIGNAL and hot:
		# 겹인쇄를 색수차로 다시 읽는다. **앞 창에만** 준다 — 골고루면 죽는다(§20.9.4).
		var tint := [COOL, ACCENT]
		var shifts := PaneDeck.splits()
		for i in shifts.size():
			var ghost := PackedVector2Array()
			for point in shape:
				ghost.append(point + shifts[i])
			draw_polyline(_closed(ghost), Color(tint[i], 0.55), 1.3, true)
	draw_polyline(_closed(shape), Color(RULE, 0.55 + 0.45 * deep), 1.4, true)

	draw_rect(Rect2(bar.position, Vector2(bar.size.x, bar.size.y)), Color(RULE_SOFT, 0.22))
	draw_rect(Rect2(bar.position.x, bar.end.y, bar.size.x, 1.0), Color(RULE, 0.7))
	if not hot:
		return

	if PaneDeck.air(kind) == PaneDeck.Air.INSTRUMENT:
		# 눈금은 **오른쪽 변에만.** 간격은 절대값이다 — 창이 커진다고 성겨지지 않는다.
		var y := rect.position.y + PaneDeck.TITLE_H + 10.0
		while y < rect.end.y - 12.0:
			var long_tick := 11.0 if int(y) % 45 < 9 else 5.0
			draw_rect(Rect2(rect.end.x - long_tick - 4.0, y, long_tick, 1.0), Color(RULE, 0.6))
			y += 9.0
		draw_rect(Rect2(bar.position.x + 12.0, bar.end.y - 7.0, 26.0, 2.0), Color(ACCENT, 0.95))
	else:
		# 신호가 끊긴 자리. 제목 띠에 구멍을 낸다 — 판 전체에 주사선을 긋지 않는다.
		for i in 5:
			var gap := fposmod(0.13 + float(i) * 0.6180339887, 1.0)
			draw_rect(
				Rect2(bar.position.x + bar.size.x * gap, bar.end.y - 1.0, 16.0, 2.0),
				Color(SHEET, 0.9)
			)
		draw_rect(Rect2(bar.end.x - 44.0, bar.position.y + 12.0, 30.0, 2.0), Color(ACCENT, 0.95))


## 창 이름. **창의 이름이 곧 그 창이 무엇을 맡았나다** — 탭 이름이 하던 일이다.
func _title(kind: PaneDeck.Kind, rect: Rect2, index: int, alpha: float) -> void:
	var bar := PaneDeck.title_bar(rect)
	draw_string(
		FONT,
		Vector2(bar.position.x + 14.0, bar.position.y + 20.0),
		PaneDeck.title_of(kind, index),
		HORIZONTAL_ALIGNMENT_LEFT,
		bar.size.x - 60.0,
		14,
		Color(INK, alpha)
	)


func _label(what: String, at: Vector2, size_px: int, color: Color) -> void:
	draw_string(FONT, at, what, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)


func _closed(shape: PackedVector2Array) -> PackedVector2Array:
	var out := shape.duplicate()
	out.append(shape[0])
	return out
