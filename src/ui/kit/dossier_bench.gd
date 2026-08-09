class_name DossierBench
extends Control
## **같은 사람, 같은 내용, 다른 형태 넷.** 인물 상세를 형태 위에 얹어 무엇이 무너지는지 본다.
##
##     godot --path . res://src/ui/kit/dossier_bench.tscn
##
## | 조작 | 무엇 |
## | --- | --- |
## | `Space` 또는 클릭 | 넷을 다시 연다 |
## | `S` | 시계 정지 |
##
## ## 왜 인물 상세인가
##
## 이 게임에서 **글이 가장 많은 화면**이다. 이름 · 나이 · 길드 · 성향 6 축 막대 ·
## 관계 목록 · 열전 여러 줄이 한 창에 다 들어간다.
##
## 그리고 이미 증거가 있다 — 「선만」이 낱말 하나에서 살고 본문 두 줄에서 죽었다.
## **내용이 형태를 죽인다.** 견본 문구가 든 상자에서는 안 보이는 일이다.
##
## ## 고치지 않는다
##
## 넘치면 넘친 만큼 그리고 **넘친 픽셀 수를 화면에 적는다.** 줄이거나 가리면
## 「이 형태는 글이 안 들어간다」는 사실이 사라진다. 사용자가 형태를 고를 때
## 그 사실을 알고 골라야 한다.

const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")

const BACKDROP := Color("#dee2e8")
const FAINT := Color("#c2c8d1")
const INK := Color("#212a37")
const DIM := Color("#6d7681")
const ALARM := Color("#b03a2b")
const GOOD := Color("#4a7a5e")

## 실제 인물 상세 창의 크기. **네 개를 한 줄에 넣으려고 좁게 잡으면** 형태가
## 아니라 내 배치가 무너지는 것을 재게 된다. 1280x720 화면에 앉을 크기로 잡고
## 두 줄로 접는다.
const CARD := Vector2(596.0, 428.0)

## 씨앗을 고정한다. 캡처마다 다른 사람이 나오면 형태끼리 비교가 안 된다.
const SEED: int = 20260809
const POPULATION: int = 240

const FORMS: Array[PopupForm.Kind] = [
	PopupForm.Kind.SHUTTER,
	PopupForm.Kind.RIFT,
	PopupForm.Kind.TALLY,
	PopupForm.Kind.WIRE,
]
const NAMES: Array[String] = ["벌어지는 널", "어긋난 띠 셋", "계측기 틀", "선만"]

const OPEN_AT: float = 0.30
const LOOP: float = 2.60

var _cards: Array[DossierCard] = []
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
	# 이름이 가장 긴 사람을 고른다. **가장 가혹한 것으로 재야 재는 뜻이 있다.**
	var person := 0
	for i in registry.size():
		if registry.name_of(i).length() > registry.name_of(person).length():
			person = i
	_who = registry.name_of(person)
	var sheet := PersonSheet.build(registry, person, factions)

	for i in FORMS.size():
		var card := DossierCard.new()
		card.form = FORMS[i]
		card.person_name = _who
		card.sections = sheet
		if _driven:
			card.drive_externally()
		add_child(card)
		card.position = Vector2(
			30.0 + float(i % 2) * (CARD.x + 28.0), 122.0 + float(i / 2) * (CARD.y + 78.0)
		)
		card.size = CARD
		_cards.append(card)


func _process(delta: float) -> void:
	if _driven:
		return
	if not _frozen:
		_clock += delta
	queue_redraw()


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
		card.pose(phase, t, since_open, -1.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP)
	_label("인물 상세 — 같은 사람, 같은 내용, 형태 넷", Vector2(28.0, 46.0), 17, INK)
	_label("견본 문구가 아니라 PersonSheet 이 낸 진짜 칸이다. 넘치면 넘친 채로 그린다.", Vector2(28.0, 68.0), 13, DIM)
	draw_rect(Rect2(0.0, 84.0, size.x, 1.0), FAINT)

	for i in _cards.size():
		var card := _cards[i]
		var at := card.position
		_label(NAMES[i], Vector2(at.x, at.y - 14.0), 15, INK)
		var spill := card.overflow()
		var verdict := "들어간다"
		var tone := GOOD
		if spill.x > 0.5 or spill.y > 0.5:
			verdict = "무너진다  옆 %d px  아래 %d px" % [int(spill.x), int(spill.y)]
			tone = ALARM
		if card.cuts() > 0:
			verdict += "  글줄이 이음매에 %d 번 잘림" % card.cuts()
			tone = ALARM
		_label(verdict, Vector2(at.x, at.y + CARD.y + 26.0), 14, tone)


func _label(what: String, at: Vector2, size_px: int, color: Color) -> void:
	draw_string(FONT, at, what, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
