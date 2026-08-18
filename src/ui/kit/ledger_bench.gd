class_name LedgerBench
extends Control
## **글 많은 화면 전용 형태 여섯.** 같은 사람, 같은 칸, 형태만 다르다.
##
##     godot --path . res://src/ui/kit/ledger_bench.tscn
##
## | 조작 | 무엇 |
## | --- | --- |
## | `S` | 시계 정지 |
##
## ## 왜 또 인물 상세인가
##
## 이 게임에서 **글이 가장 많은 화면**이고, 사용자가 처음 만들라고 한 화면이다.
## 그리고 앞 판에서 형태 넷이 여기서 다 무너졌다(§20.13) — 같은 자리에 다시 선다.
##
## ## 카드 밑에 적히는 세 값이 이 화면의 결과물이다
##
## | 값 | 무엇 | 목표 |
## | --- | --- | --- |
## | 층 | 판이 몇 조각으로 갈렸나 | 형태마다 다르다. 자를 자리가 없으면 1 이다 |
## | 잘림 | 이음매가 글줄을 가로지른 횟수 | **0.** 이 묶음이 그걸 위해 만들어졌다 |
## | 넘침 | 글이 판 밖으로 나간 px | 0 |
##
## **잘림이 0 인 것은 자랑이 아니라 전제다.** 이 묶음은 「글이 들어가는가」를 통과한
## 다음에 **어느 형태가 보기 좋은가**를 묻는 자리다.

const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")

const BACKDROP := Color("#dee2e8")
const FAINT := Color("#c2c8d1")
const INK := Color("#212a37")
const DIM := Color("#6d7681")
const ALARM := Color("#b03a2b")
const GOOD := Color("#4a7a5e")

## 1280x720 에 실제로 앉을 크기. 앞 판(§20.13)과 같은 값이라 비교가 된다.
const CARD := Vector2(596.0, 428.0)

const SEED: int = 20260809
const POPULATION: int = 240

const OPEN_AT: float = 0.30
const LOOP: float = 3.20

## 손이 닿는 구간과 눌리는 구간. **둘이 겹치지 않아야** 사건이 갈려 보인다(§20.10).
const HOVER_IN := Vector2(1.10, 1.50)
const PRESS_IN := Vector2(1.95, 2.12)
const LET_GO: float = 2.45
const CALM: float = 2.85

var _cards: Array[LedgerCard] = []
var _clock := 0.0
var _frozen := false
var _driven := false
var _who := ""


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
	# 이름이 가장 긴 사람. **가장 가혹한 것으로 재야 재는 뜻이 있다.**
	var person := 0
	for i in registry.size():
		if registry.name_of(i).length() > registry.name_of(person).length():
			person = i
	_who = registry.name_of(person)
	var sheet := PersonSheet.build(registry, person, factions)

	for i in LedgerForm.count():
		var card := LedgerCard.new()
		card.form = i as LedgerForm.Kind
		card.person_name = _who
		card.sections = sheet
		if _driven:
			card.drive_externally()
		add_child(card)
		card.position = Vector2(
			26.0 + float(i % 2) * (CARD.x + 30.0), 116.0 + float(i / 2) * (CARD.y + 70.0)
		)
		card.size = CARD
		_cards.append(card)


func _process(delta: float) -> void:
	if _driven:
		return
	if not _frozen:
		_clock = fposmod(_clock + delta, LOOP)
		set_clock(_clock)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_S:
		_frozen = not _frozen


## 캡처가 시각 `t` 의 화면을 앉힌다.
func set_clock(t: float) -> void:
	_clock = t
	var phase := PopupMotion.Phase.SHUT
	var since_open := -1.0
	if t >= OPEN_AT:
		since_open = t - OPEN_AT
		phase = PopupMotion.Phase.OPEN
		if since_open < PopupMotion.PIECE_TIME + PopupMotion.STAGGER * 5.0:
			phase = PopupMotion.Phase.OPENING
	for card in _cards:
		card.pose(phase, t, since_open, _event_at(t))
	queue_redraw()


## `(손이 닿음, 눌림, 섬광)`. **눌리는 동안 손이 닿은 값이 0 으로 빠지지 않는다** —
## 누른 채로 손이 떨어질 리가 없으므로 그러면 형태가 두 번 튄다.
func _event_at(t: float) -> Vector3:
	var hover := smoothstep(HOVER_IN.x, HOVER_IN.y, t)
	var press := smoothstep(PRESS_IN.x, PRESS_IN.y, t) * (1.0 - smoothstep(LET_GO, LET_GO + 0.2, t))
	hover *= 1.0 - smoothstep(LET_GO + 0.15, CALM, t)
	return Vector3(hover, press, 0.0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP)
	_label("글 많은 화면 전용 형태 여섯 — 가로 이음매만 쓴다", Vector2(26.0, 44.0), 19, INK)
	_label("이음매 자리를 형태가 아니라 자료가 정한다. 두 열의 빈틈이 겹치는 데만 판이 갈린다.", Vector2(26.0, 68.0), 13, DIM)
	_label("인물 | %s | PersonSheet 이 낸 진짜 칸" % _who, Vector2(26.0, 88.0), 13, DIM)
	draw_rect(Rect2(0.0, 100.0, size.x, 1.0), FAINT)

	for i in _cards.size():
		var card := _cards[i]
		var at := card.position
		_label(LedgerForm.label(card.form), Vector2(at.x, at.y - 14.0), 15, INK)
		_label(_verdict(card), Vector2(at.x, at.y + CARD.y + 26.0), 14, _tone(card))


func _verdict(card: LedgerCard) -> String:
	var spill := card.overflow()
	var line := "조각 %d | 층 %d | 잘림 %d" % [card.bands(), card.steps(), card.crossings()]
	if spill.x > 0.5 or spill.y > 0.5:
		return line + " | 넘침 옆 %d 아래 %d px" % [int(spill.x), int(spill.y)]
	return line + " | 넘침 없음"


func _tone(card: LedgerCard) -> Color:
	var spill := card.overflow()
	if card.crossings() > 0 or spill.x > 0.5 or spill.y > 0.5:
		return ALARM
	return GOOD


func _label(what: String, at: Vector2, size_px: int, color: Color) -> void:
	draw_string(FONT, at, what, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
