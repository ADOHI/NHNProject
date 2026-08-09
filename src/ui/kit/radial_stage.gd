class_name RadialStage
extends Control
## **원형 인물 배치 + 홀로그램 창 + 사건에 붙는 이펙트.** 조우 중에 상대를 훑는 화면이다.
##
##     godot --path . res://src/ui/kit/radial_stage.tscn
##
## **고른 인물이 가운데로 온다.** 휠을 돌리면 링이 돌고 다음 인물이 가운데에 서고
## 창이 그 인물에게 옮겨 붙는다. **가운데가 곧 선택됨이라 표지가 따로 없다.**
##
## 판 넷을 나란히 놓는다. **같은 회전 · 같은 재료 배정이고 화려함 세기만 다르다** —
## 한 화면에 축이 둘 움직이면 무엇 때문에 시끄러운지 못 가른다(§20.20.4).
##
## | 판 | 세기 | 무엇이 달라지나 |
## | --- | --- | --- |
## | 없음 | 0 | 사건에 아무것도 안 붙는다. 셰이더도 안 건다. **비교 기준** |
## | 약 | 0.45 | 한 곳에서만 작게 |
## | 세 | 1.00 | 이 킷이 쓰려는 자리 |
## | **과** | 2.00 | **골고루 뿌렸다.** 개수가 아니라 「한 곳에만」을 버렸다 |
##
## **정지로는 절반도 판정이 안 된다.** 접힘 · 펴짐 · 궤적 · 파문이 전부 사건이라
## GIF 가 판정 매체다.

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

## 한 칸에서 멈춰 있는 몫. 나머지에 넘어간다 — 등속으로 돌면 「고른다」가 아니라
## 「돌아간다」로 읽힌다.
const HOLD_PART: float = 0.55

## 스스로 누르는 시각. **GIF 가 판정 매체인데 손이 없으면 파문을 못 본다**(§20.20.5).
##
## 링이 **멈춰 있는 동안**으로 잡았다 — 도는 중에 누르면 파문과 궤적이 겹쳐
## 어느 쪽이 무엇인지 안 보인다. 사건이 둘이면 시각을 갈라야 각각이 읽힌다.
const POKE_AT: float = 2.90

## 파문이 다 퍼졌을 때의 반지름(px).
const POKE_SPREAD: float = 230.0

## `only_panel` 이 가리키는 특별한 화면 둘. 0..3 은 세기 넷이다.
const SQUAD_VIEW: int = 4
const WINDOW_VIEW: int = 5

## 이 화면이 서 있는 배율. **「한 명」 층이다**(§20.17.1) — 층 사이를 지나가는
## 카메라는 아직 없어서 층마다 배율이 고정이다.
const ZOOM_ONE: float = 1.0

## 재료가 그 칸의 종류를 말한다(§20.20.4). **줄 순서는 `RadialDeck.Slot` 그대로다.**
##
## 「접힌 모양이 그 창의 종류를 말한다」(§20.17.3)와 같은 축이다. 형태를 다섯으로
## 늘린 것이 아니다 — 실루엣은 여전히 모따기 하나고 재료는 형태가 아니다.
const SLOT_STUFF := [
	HoloPane.Stuff.FIELD,  # 관계 — 사람 사이에 걸린 것. 무늬가 흐르고 경계가 떨린다
	HoloPane.Stuff.GLASS,  # 성향 — 재면 보이는 것. 가장자리에서 빛이 모인다
	HoloPane.Stuff.PRINT,  # 신원 — 등록되고 찍힌 것. 이 킷의 계보 그대로다
	HoloPane.Stuff.METAL,  # 장비 — 쇠붙이. 결과 비스듬한 반사 띠
	HoloPane.Stuff.LIGHT,  # 열전 — 안에서 나오는 이야기
]

## 판 하나만 그리나. 0..3 이면 그 세기 하나, 4 는 스쿼드 여섯, 5 는 창 하나다.
## 태블릿 확인 화면이 이 화면을 **텍스처로** 받아 기울여 붙인다.
@export var only_panel: int = -1

## 재료 노드. **「없음」 판은 셰이더를 아예 안 걸어 자리가 없다** — 세기 셋 × 창 다섯.
##
## `ShaderMaterial` 은 캔버스 항목 하나에 걸리므로 부모가 전부 즉시 그리면
## **글자까지 같은 셰이더를 먹는다**(§20.19.1).
var _skins: Array[HoloPane] = []

## 창 위의 글과 테두리를 그리는 층. **자식이라 창보다 나중에 그려진다** — 유리 위의 잉크다.
var _over: Control = null

## 이번 프레임에 선 창들. **자리는 부모가 정하고 재료는 자식이 칠하고 글은 그 위에** —
## 세 번에 나눠 그리므로 계산을 한 번만 하고 넘겨 둔다.
var _pending: Array = []

## 누름은 사건이라 **시각이 있다.** 한 바퀴에 한 번 스스로 누르고, 마우스로 누르면
## 그 순간으로 다시 예약된다.
##
## **「없음」을 값으로 겸하지 않는다**(§20.18.5) — 파문이 살아 있는지는 이 값이
## 어떤 특별한 값이냐가 아니라 **경과 시간이 파문 길이보다 짧은가**로 안다.
var _poke_from := POKE_AT
var _poke_by_hand := false
var _poke_where := Vector2.ZERO

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
	# 세기 셋(약 · 세 · 과) × 창 다섯. **재료는 판이 아니라 칸이 정한다.**
	for level in range(HoloSpark.Level.SOFT, HoloSpark.levels()):
		for slot in RadialDeck.count():
			var skin := HoloPane.new()
			skin.set_stuff(SLOT_STUFF[slot], HoloSpark.stuff_strength(level))
			add_child(skin)
			_skins.append(skin)
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.draw.connect(_draw_over)
	add_child(_over)


func _process(delta: float) -> void:
	if _driven:
		return
	if not _frozen:
		set_clock(fposmod(_clock + delta, LOOP))


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_S:
		_frozen = not _frozen
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_poke(get_local_mouse_position())


## 누른 자리를 **판 안 좌표**로 받아 예약한다. 판 넷은 같은 화면이라 넷 다 함께 튄다.
func _poke(where: Vector2) -> void:
	if only_panel >= 0:
		_poke_where = where
		_poke_by_hand = true
		_poke_from = _clock
		return
	for i in HoloSpark.levels():
		var at := _panel_at(i)
		if Rect2(at, SCREEN).has_point(where):
			_poke_where = where - at
			_poke_by_hand = true
			_poke_from = _clock
			return


func set_clock(t: float) -> void:
	_clock = t
	_layout()
	for skin in _skins:
		skin.set_clock(t)
	if _over != null:
		_over.size = size
		_over.queue_redraw()
	queue_redraw()


## 창 자리를 **그리기 전에** 정한다. 여기가 이 화면의 유일한 기하 계산이고
## `_draw()` 와 `_draw_over()` 와 재료 노드가 그 결과를 **읽기만** 한다.
##
## > **`_draw()` 안에서 자식에게 `queue_redraw()` 를 걸면 그 자식은 다음 프레임에 그려진다.**
##
## 그리기 목록은 그리기 전에 짜인다. 그래서 자리는 이번 프레임에 옮겨지고 그림은
## 지난 프레임 것이 되어 **재료만 창 밖으로 밀려난다.** 판이 거의 안 움직이는 동안에는
## 「조금 어긋난 것」으로만 보였다 — §20.18.3 과 같은 종류의 함정이다.
func _layout() -> void:
	_pending.clear()
	# **안 쓰는 재료 노드는 숨긴다.** 크기만 0 으로 두면 지난 프레임의 실루엣이
	# 그대로 남는다 — 폴리곤은 제 상자가 아니라 넘겨받은 점을 그린다.
	for skin in _skins:
		skin.visible = false
	if only_panel >= 0:
		if only_panel < HoloSpark.levels():
			_plan(Vector2.ZERO, only_panel)
		return
	for level in HoloSpark.levels():
		_plan(_panel_at(level), level)


## 판 하나의 창 다섯을 잰다.
func _plan(at: Vector2, level: int) -> void:
	var picked := _picked()
	var figure := _figure_rect(RadialDeck.front_index(SQUAD, picked), picked, ZOOM_ONE)
	var live := HoloSpark.live_line(_clock, RadialDeck.count())
	for slot in RadialDeck.count():
		var here := slot as RadialDeck.Slot
		# **가운데가 바뀌는 순간이 접힘과 펴짐의 경계다.** 그래서 창이 옮겨 붙는 것을
		# 볼 일이 없다 — 옮겨 붙는 동안 접혀 있다. 그 잇는 계산은 `RadialDeck` 에 있다.
		var open := RadialDeck.unfolded(here, picked)
		var box := RadialDeck.slot_rect(here, figure, SCREEN, open)
		var line := RadialDeck.tether(here, figure, SCREEN, open)
		var pane := Rect2(at + box.position, box.size)
		var shape := _pane_shape(here, pane, level)
		var skin := _skin_for(level, slot) if open >= 0.22 else null
		if skin != null:
			skin.visible = true
			skin.position = pane.position
			skin.size = pane.size
			var local := PackedVector2Array()
			for point in shape:
				local.append(point - pane.position)
			skin.shape = local
			skin.queue_redraw()
		(
			_pending
			. append(
				{
					"slot": here,
					"pane": pane,
					"shape": shape,
					"open": open,
					"level": level,
					"live": slot == live,
					"skinned": skin != null,
					# **`Array` 로 두면 꺼낸 값이 Variant 라** 받는 쪽에서 타입 추론이 안 된다.
					"line": PackedVector2Array([at + line[0], at + line[1]])
				}
			)
		)


## 지금 고른 인물. **칸마다 멈췄다 다음으로 간다.**
func _picked() -> float:
	var step := TURN_TIME / float(SQUAD)
	var slot := floorf(_clock / step)
	return slot + smoothstep(HOLD_PART, 1.0, fposmod(_clock, step) / step)


## 링이 도는 속도 0..1. **재지 않고 미분한다**(§20.20.6).
##
## 캡처는 `set_clock` 으로 시각을 직접 꽂으므로 「지난 프레임과의 차이」를 쓸 수 없다.
## 넘어감이 `smoothstep` 이고 그 미분이 `6t(1-t)` 라 **시계 하나면 속도가 나온다.**
## 최대가 1.5 라 4t(1-t) 로 적으면 그대로 0..1 이 된다.
func _turn_speed() -> float:
	var step := TURN_TIME / float(SQUAD)
	var within := fposmod(_clock, step) / step
	if within <= HOLD_PART:
		return 0.0
	var t := (within - HOLD_PART) / (1.0 - HOLD_PART)
	return 4.0 * t * (1.0 - t)


## 파문이 난 뒤 흐른 몫. 1 을 넘으면 끝난 것이다. **특별한 값이 「없음」을 겸하지 않는다.**
func _poke_u() -> float:
	return fposmod(_clock - _poke_from, LOOP) / HoloSpark.RIPPLE_TIME


func _panel_at(index: int) -> Vector2:
	return Vector2(
		PANEL_GAP.x + float(index % 2) * (SCREEN.x + PANEL_GAP.x),
		TOP + float(index / 2) * (SCREEN.y + PANEL_GAP.y)
	)


func _draw() -> void:
	if only_panel >= 0:
		_screen(Vector2.ZERO, only_panel)
		return
	draw_rect(Rect2(Vector2.ZERO, size), SHEET)
	_label("조우 중 — 사건에 붙는 것들. 화려함 세기 넷", Vector2(30.0, 48.0), 22, INK)
	_label("창이 열릴 때 조각이 모이고, 선을 신호가 지나가고, 링이 돌면 자국이 남고, 누르면 파문이 퍼진다.", Vector2(30.0, 76.0), 14, DIM)
	_label("멈춰 있으면 값이 0 이다. 상시로 남는 둘은 선 하나와 가운데 인물 하나에만 붙는다.", Vector2(30.0, 100.0), 13, DIM)

	_panel(HoloSpark.Level.NONE, "없음 — 사건에 아무것도 안 붙는다. 셰이더도 없다")
	_panel(HoloSpark.Level.SOFT, "약 — 한 곳에서만 작게")
	_panel(HoloSpark.Level.STRONG, "세 — 이 킷이 쓰려는 자리")
	_panel(HoloSpark.Level.TOO_MUCH, "과 — 골고루 뿌렸다. 넘어가 본 자리")


func _panel(level: int, title: String) -> void:
	var at := _panel_at(level)
	_label(title, at + Vector2(0.0, -14.0), 16, INK)
	# 태블릿 뒤로 던전이 비친다. **조우 중이라는 것이 화면에 있어야 한다.**
	_behind(at)
	_screen(at, level)


## 화면 한 장. 태블릿 확인 화면은 이것만 텍스처로 받아 기울여 붙인다.
func _screen(at: Vector2, view: int) -> void:
	draw_rect(Rect2(at, SCREEN), Color(DESK, 0.86))
	draw_rect(Rect2(at, SCREEN), Color(RULE, 0.6), false, 1.5)
	if view == SQUAD_VIEW:
		_draw_squad(at)
		return
	if view == WINDOW_VIEW:
		_draw_window(at)
		return
	_draw_one(at, _picked(), view)


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


## 한 명 — 원형 + 창 다섯. `level` 은 화려함 세기다.
func _draw_one(at: Vector2, picked: float, level: int) -> void:
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
		_trail(at, i, picked, level)
	for i in order:
		_figure(at, i, picked, ZOOM_ONE, i == front, level)
	for each in _pending:
		if int(each["level"]) == level:
			_hologram(each)
	if level != HoloSpark.Level.NONE:
		_label("%s | 가운데가 곧 선택됨" % _names[front], at + Vector2(30.0, SCREEN.y - 26.0), 15, DIM)


## **판 안 좌표다.** 판 오프셋은 그리는 자리에서만 더한다 — 상자에 넣어 두면
## 창 자리 계산에서 한 번 더 더해져 판이 오른쪽에 있을수록 창이 밖으로 밀린다.
func _figure_rect(index: int, picked: float, zoom: float) -> Rect2:
	var stand := RadialDeck.stand(index, SQUAD, picked, zoom, SCREEN)
	var scale := RadialDeck.figure_scale(index, SQUAD, picked, zoom)
	var tall := 456.0 * scale
	var wide := 312.0 * scale
	return Rect2(stand - Vector2(wide * 0.5, tall * 0.86), Vector2(wide, tall))


## **링이 돌 때 남는 자국.** 멈춰 있으면 한 겹도 안 그린다.
##
## 자국은 **돌던 방향의 뒤쪽**에만 남는다. 「과」에서만 여섯 다 남기는데, 그러면
## 뒤쪽이 어디였는지 알 수 없어져 잔상이 아니라 후광이 된다.
func _trail(at: Vector2, index: int, picked: float, level: int) -> void:
	var many := HoloSpark.many(HoloSpark.Effect.GHOST, level)
	if many <= 0 or _figures.is_empty():
		return
	var speed := _turn_speed()
	var behind := HoloSpark.wake(index, SQUAD, picked, speed)
	if HoloSpark.spreads(level):
		behind = maxf(behind, speed * 0.45)
	if behind <= 0.001:
		return
	for depth in many:
		var ghost := _figure_rect(index, picked - HoloSpark.ghost_back(depth), ZOOM_ONE)
		# **잔상은 본체보다 훨씬 옅어야 한다.** 진하면 사람이 여럿 서 있는 것으로 읽힌다.
		draw_texture_rect(
			_figures[index % _figures.size()],
			Rect2(at + ghost.position, ghost.size),
			false,
			Color(COOL, behind * 0.6 / (1.0 + float(depth) * 1.1))
		)


func _figure(at: Vector2, index: int, picked: float, zoom: float, front: bool, level: int) -> void:
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
	# **티끌은 가운데 인물에만 돈다.** 「과」에서만 여섯 다 준다 — 밀도 대비가 죽는 자리다.
	if front or HoloSpark.spreads(level):
		_motes(box, level, 1.0 if front else 0.5)
	if not front:
		return
	# **여기가 밀도가 터지는 자리다.** 나머지는 조용하다.
	draw_rect(Rect2(box.position.x, box.end.y + 4.0, box.size.x, 2.0), Color(ACCENT, 0.9))
	if level == HoloSpark.Level.NONE:
		return
	_footing(box, level)


## 가운데 인물 둘레의 티끌. **여기가 터지는 자리다.**
func _motes(box: Rect2, level: int, weight: float) -> void:
	var many := HoloSpark.many(HoloSpark.Effect.MOTE, level)
	for i in many:
		var lit := HoloSpark.mote_alpha(i, _clock) * weight
		var tint := ACCENT if i % 4 == 0 else COOL
		draw_circle(HoloSpark.mote(i, many, box, _clock), 1.6 + 1.4 * lit, Color(tint, lit * 0.8))


## 가운데 인물의 발치 표. **겹인쇄를 색수차로 다시 읽은 것**(§20.16.2)이 여기 붙는다.
func _footing(box: Rect2, level: int) -> void:
	var ring := Rect2(box.position.x - 26.0, box.end.y - 16.0, box.size.x + 52.0, 34.0)
	for i in RadialDeck.count():
		var turn := fposmod(0.19 + float(i) * 0.6180339887, 1.0)
		draw_rect(
			Rect2(ring.position.x + ring.size.x * turn, ring.end.y - 4.0, 3.0 + turn * 9.0, 2.0),
			Color(RULE, 0.5)
		)
	draw_rect(Rect2(ring.position + Vector2(-2.5, -1.5), ring.size), Color(COOL, 0.42), false, 1.0)
	draw_rect(Rect2(ring.position + Vector2(2.5, 1.5), ring.size), Color(ACCENT, 0.38), false, 1.0)
	if not HoloSpark.spreads(level):
		return
	# 과하게 — 후광까지 얹는다. **이 판은 시끄러운 것이 목적이다.**
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


## 홀로그램 창 하나 중 **창 아래에 깔리는 것** — 선 · 접힌 표식 · 모여드는 조각.
##
## 자리는 `_layout()` 이 이미 정했다. 여기서는 읽기만 한다.
func _hologram(plan: Dictionary) -> void:
	var line: PackedVector2Array = plan["line"]
	var open: float = plan["open"]
	var level: int = plan["level"]
	var pane: Rect2 = plan["pane"]
	var slot: RadialDeck.Slot = plan["slot"]
	# **선은 창이 접혀도 남는다.** 끝점이 접힌 표식으로 옮겨갈 뿐이다.
	if level == HoloSpark.Level.NONE:
		draw_line(line[0], line[1], Color(COOL, 0.28 + 0.34 * open), 1.2, true)
	else:
		# **선에도 겹인쇄를 건다.** 두 색이 어긋나 지나가면 그냥 선이 아니라 신호가 된다.
		var away := (line[1] - line[0]).orthogonal().normalized() * 1.6
		draw_line(line[0] - away, line[1] - away, Color(COOL, 0.30 + 0.30 * open), 1.0, true)
		draw_line(line[0] + away, line[1] + away, Color(ACCENT, 0.22 + 0.26 * open), 1.0, true)
		draw_line(line[0], line[1], Color(RULE, 0.30 + 0.30 * open), 1.0, true)
	draw_circle(line[0], 3.0, Color(ACCENT, 0.9))

	if open < 0.22:
		draw_colored_polygon(_rect_poly(pane), Color(GLASS, 0.30 + 0.58 * open))
		# 접힌 모양이 그 창의 종류를 말한다 — 성향은 막대 하나, 관계는 점 넷.
		for mark in RadialDeck.folded_marks(slot, pane):
			draw_rect(mark, Color(RULE, 0.75))
		return

	# **창이 열릴 때 조각이 모여 붙고 접힐 때 흩어진다.** 다 붙고 나면 사라진다 —
	# 남으면 장식이다. 모임과 흩어짐이 같은 축의 양끝이라 따로 만들 것이 없다(§20.10).
	var gather := clampf((open - 0.22) / 0.62, 0.0, 1.0)
	if gather < 0.999:
		for i in HoloSpark.many(HoloSpark.Effect.SHARD, level):
			draw_rect(
				HoloSpark.shard(i, pane, gather),
				Color(ACCENT if i % 3 == 0 else COOL, HoloSpark.shard_alpha(gather))
			)
	# 재료 노드가 없는 판(「없음」)은 부모가 평평하게 칠한다.
	if not bool(plan["skinned"]):
		draw_colored_polygon(plan["shape"], Color(GLASS, 0.30 + 0.58 * open))


## 이 판 이 칸의 재료 노드. **「없음」에는 자리가 없다** — 셰이더를 아예 안 건다.
func _skin_for(level: int, slot: int) -> HoloPane:
	if level <= HoloSpark.Level.NONE:
		return null
	var index := (level - 1) * RadialDeck.count() + slot
	return _skins[index] if index < _skins.size() else null


## 창 **위**에 얹히는 것. 자식이라 창보다 나중에 그려진다 — 유리 위의 잉크다.
func _draw_over() -> void:
	var burst := _poke_u()
	for each in _pending:
		var pane: Rect2 = each["pane"]
		var shape: PackedVector2Array = each["shape"]
		var open: float = each["open"]
		var level: int = each["level"]
		var slot: RadialDeck.Slot = each["slot"]
		# **선은 창이 접혀도 남는다.** 그래서 신호는 접힘과 상관없이 흐른다.
		if level != HoloSpark.Level.NONE:
			_signals(each["line"], level, each["live"])
		# **테두리는 펴진 창에만.** 접힌 표식까지 갈라지면 골고루가 되어 죽는다(§20.17.3).
		if open >= 0.22:
			# **누른 순간 창 테두리가 번쩍한다.** 파문보다 훨씬 짧다.
			var flare := HoloSpark.flare(burst) if burst < 1.0 else 0.0
			if level == HoloSpark.Level.NONE:
				_over.draw_polyline(_closed(shape), Color(RULE, 0.65), 1.2, true)
			else:
				_pane_edge(shape, open, level, flare)
		if open < 0.72:
			continue
		_over.draw_string(
			FONT,
			pane.position + Vector2(16.0, 20.0),
			RadialDeck.label(slot),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			Color(INK, open)
		)
		_over.draw_rect(
			Rect2(pane.position.x + 16.0, pane.position.y + 26.0, 22.0, 2.0), Color(ACCENT, open)
		)
		if not RadialDeck.shows_text(ZOOM_ONE):
			continue
		_ink.only = [_section_for(slot)]
		_ink.columns = 1
		_ink.scroll = 0.0
		_ink.paint(
			_over, Rect2(pane.position + Vector2(16.0, 44.0), pane.size - Vector2(32.0, 56.0)), open
		)
	if burst < 1.0:
		_ripple(burst)


## **연결선을 따라 신호가 지나간다.** 몸에서 창 쪽으로만 가고 **한 번에 한 선**이다.
##
## 다섯 줄 다 흘리면 골고루 빛나는 화면이 되어 1 판의 「무슨 수학 같음」이 돌아온다.
## 「과」에서만 그것을 일부러 한다 — 같은 이펙트가 **어디에 붙느냐만으로** 소음이 된다.
func _signals(line: PackedVector2Array, level: int, live: bool) -> void:
	if not live and not HoloSpark.spreads(level):
		return
	var many := HoloSpark.many(HoloSpark.Effect.SIGNAL, level)
	var from := line[0]
	var to := line[1]
	for i in many:
		var along := HoloSpark.signal_at(i, many, _clock)
		var lit := HoloSpark.signal_alpha(along)
		_over.draw_circle(from.lerp(to, along), 1.6 + 1.4 * lit, Color(ACCENT, lit * 0.8))


## 누른 자리에서 퍼지는 파문. **한 번 지나가고 끝난다.**
func _ripple(u: float) -> void:
	for level in HoloSpark.levels():
		var many := HoloSpark.many(HoloSpark.Effect.RING, level)
		if many <= 0:
			continue
		var at := _panel_at(level) + _poke_point()
		if only_panel >= 0:
			if level != only_panel:
				continue
			at = _poke_point()
		for ring in many:
			var lit := HoloSpark.ripple_alpha(u, ring)
			if lit <= 0.002:
				continue
			_over.draw_arc(
				at,
				maxf(HoloSpark.ripple(u, POKE_SPREAD, ring), 1.0),
				0.0,
				TAU,
				64,
				Color(ACCENT, lit),
				2.0 + 2.0 * lit,
				true
			)
		# 「과」는 화면째 번쩍인다. **이 판은 시끄러운 것이 목적이다.**
		if HoloSpark.spreads(level):
			var flash := HoloSpark.flare(u)
			if flash > 0.002:
				var box := Rect2(Vector2.ZERO if only_panel >= 0 else _panel_at(level), SCREEN)
				_over.draw_rect(box, Color(SHEET, flash * 0.35))


## 파문이 나는 자리. 손이 안 댔으면 **가운데 인물 가슴**이다 — 「이 사람을 찍었다」로 읽힌다.
func _poke_point() -> Vector2:
	if _poke_by_hand:
		return _poke_where
	var picked := _picked()
	return _figure_rect(RadialDeck.front_index(SQUAD, picked), picked, 1.0).get_center()


func _rect_poly(box: Rect2) -> PackedVector2Array:
	return PackedVector2Array(
		[
			box.position,
			Vector2(box.end.x, box.position.y),
			box.end,
			Vector2(box.position.x, box.end.y)
		]
	)


## 창의 실루엣. **네모를 벗어난다** — 이 킷이 여덟 판에 만든 형태를 창 모양으로 쓴다.
##
## 자리마다 다른 형태를 주지 않는다. **같은 화면에 형태가 다섯이면 그게 시끄러움이다** —
## 모따기 하나를 공통으로 쓰고, 붙은 쪽에 따라 **깎이는 모서리만 반대**로 둔다.
func _pane_shape(slot: RadialDeck.Slot, pane: Rect2, level: int) -> PackedVector2Array:
	# **모따기는 판이 그만큼 클 때만 성립한다.** 접히는 동안 높이가 7px 까지 줄어드는데
	# 18px 를 그대로 깎으면 두 꼭짓점이 서로를 지나쳐 **실루엣이 나비넥타이로 뒤집힌다.**
	var cut := minf(12.0 if level == HoloSpark.Level.NONE else 18.0, pane.size.y * 0.45)
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
func _pane_edge(shape: PackedVector2Array, open: float, level: int, flare: float) -> void:
	var ring: PackedVector2Array = _closed(shape)
	var split := (
		5.0 if HoloSpark.spreads(level) else (2.5 if level == HoloSpark.Level.SOFT else 3.5)
	)
	var shifted := PackedVector2Array()
	for point in ring:
		shifted.append(point + Vector2(-split, -split * 0.6))
	_over.draw_polyline(shifted, Color(COOL, (0.34 + 0.5 * flare) * open), 1.0, true)
	shifted = PackedVector2Array()
	for point in ring:
		shifted.append(point + Vector2(split, split * 0.6))
	_over.draw_polyline(shifted, Color(ACCENT, (0.30 + 0.5 * flare) * open), 1.0, true)
	_over.draw_polyline(ring, Color(RULE, 0.68 + 0.32 * flare), 1.2 + 1.4 * flare, true)
	if not HoloSpark.spreads(level):
		return
	# 과하게 — 눈금까지 두른다. **모든 창이 다 빛나면 어디를 봐야 할지 모른다.**
	var box := PlateForm.bounds(shape)
	var y := box.position.y + 6.0
	while y < box.end.y - 4.0:
		_over.draw_rect(Rect2(box.end.x - 9.0, y, 6.0, 1.0), Color(RULE, 0.55))
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
