class_name ScrollBench
extends Control
## **스크롤을 견디는 형태가 있나.** 긴 열전을 여섯 형태에 흘려 보고 무엇이 무너지는지 본다.
##
##     godot --path . res://src/ui/kit/scroll_bench.tscn
##
## ## 왜 이걸 재야 하나
##
## 인물 열전은 앞으로 **「어린 시절부터 이렇게 살았다」** 수준의 내러티브가 된다.
## 그러면 스크롤이 필요한데, **스크롤은 §20.14 가 세운 원리와 정면으로 싸운다.**
##
## > **이음매를 자료가 정한다** — 이것은 자료가 **가만히 있을 때만** 성립한다.
##
## 글이 흐르면 빈틈도 흐르고 이음매도 흐른다. 형태가 매 프레임 달라진다.
## 그래서 「가로 이음매라 안전하다」가 스크롤에서는 답이 아니다.
##
## ## 카드 밑에 적히는 값
##
## | 값 | 무엇 | 무너짐의 뜻 |
## | --- | --- | --- |
## | 잘림 | 보이는 이음매가 글줄을 가로지른 횟수 | 흐르는 글이 이음매에 걸린다 |
## | 흔들림 | 실루엣 오른쪽 변이 스크롤 0 일 때와 몇 px 다른가 | **글을 읽는 동안 판 모양이 춤춘다** |
## | 남은 글 | 아직 창 아래에 있는 글의 높이 | 스크롤이 필요한 양 |
##
## **흔들림이 이 화면의 진짜 결과물이다.** 잘림은 §20.14 에서 이미 0 으로 만들었고,
## 흔들림은 그때 아예 재지 않던 축이다 — §20.13.1 이 정확히 그 사고였다.

const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")

const BACKDROP := Color("#dee2e8")
const FAINT := Color("#c2c8d1")
const INK := Color("#212a37")
const DIM := Color("#6d7681")
const ALARM := Color("#b03a2b")
const GOOD := Color("#4a7a5e")

const CARD := Vector2(596.0, 428.0)

const SEED: int = 20260809
const POPULATION: int = 240

const OPEN_AT: float = 0.30
const LOOP: float = 4.00

## 글이 흐르는 구간. 열고 잠깐 두었다가 끝까지 내린다.
const ROLL := Vector2(0.90, 3.40)

## 실루엣이 이만큼 넘게 움직이면 「춤춘다」고 적는다(px). **절대값이다** —
## 눈이 알아채는 것은 판 크기 대비 비율이 아니라 변이 움직인 거리다.
const JITTER_LIMIT: float = 6.0

## 열전 자리에 넣는 긴 글. **다른 레인이 GPT 로 뽑는 것의 자리 표시물이다** —
## 여기서 재려는 것은 문장의 질이 아니라 **분량이 형태를 어떻게 무너뜨리는가**다.
const CHRONICLE := [
	"열 살에 아버지를 잃었다. 게이트가 열린 날이었고 아버지는 남의 집 아이를 먼저 밀어냈다.",
	"마을 사람들은 그 이야기를 오래 했고, 아이는 들을 때마다 아버지가 조금씩 남의 것이 되는 것을 느꼈다.",
	"열세 살에 처음 남의 것을 훔쳤다. 배가 고파서가 아니라 훔치면 아버지의 아들로 안 불릴 것 같아서였다.",
	"들켰고 맞았고, 그 뒤로 마을에서는 아버지 이야기를 안 했다. 원하던 것을 얻었는데 아무도 축하하지 않았다.",
	"열여섯에 길드 문지기의 심부름을 시작했다. 문지기는 셈이 빠른 아이를 좋아했고 그것 말고는 아무것도 안 물었다.",
	"스무 살에 처음 게이트에 들어갔다. 아버지가 나오지 못한 문이 아니라 다른 문이었는데도 같은 냄새가 났다.",
	"돌아왔을 때 손에 든 것은 팔 수 있는 것 하나뿐이었고, 그것을 판 돈으로 아버지 이야기를 하는 사람에게 술을 샀다.",
	"스물다섯에 자기 조를 꾸렸다. 조원 넷 중 셋이 자기처럼 아버지 없는 아이였고 그것을 서로 말하지 않았다.",
	"서른에 처음으로 남을 두고 나왔다. 그날 이후로 그는 아버지 이야기를 하는 사람에게 술을 사지 않는다.",
]

var _cards: Array[LedgerCard] = []
var _base: Array[PackedFloat32Array] = []
var _reach_down: Array[float] = []
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
	var person := 0
	for i in registry.size():
		if registry.name_of(i).length() > registry.name_of(person).length():
			person = i
	_who = registry.name_of(person)
	var sheet := _with_chronicle(PersonSheet.build(registry, person, factions))

	for i in LedgerForm.count():
		var card := LedgerCard.new()
		card.form = i as LedgerForm.Kind
		card.person_name = _who
		card.sections = sheet
		card.paged = true
		if _driven:
			card.drive_externally()
		add_child(card)
		card.position = Vector2(
			26.0 + float(i % 2) * (CARD.x + 30.0), 116.0 + float(i / 2) * (CARD.y + 70.0)
		)
		card.size = CARD
		# 스크롤 0 일 때의 실루엣을 먼저 잡아 둔다. **비교 대상이 없으면 흔들림을 못 잰다.**
		card.scroll = 0.0
		card.measure()
		_base.append(card.profile())
		_reach_down.append(card.below())
		_cards.append(card)


## 열전 칸을 긴 글로 갈아 끼운다. 나머지 칸은 그대로다 — **분량만 바꾸고 비교한다.**
func _with_chronicle(sheet: Array[SheetSection]) -> Array[SheetSection]:
	var out: Array[SheetSection] = []
	for section in sheet:
		if section.title != "인물 열전":
			out.append(section)
			continue
		var long_one := SheetSection.new("인물 열전", SheetSection.Shape.PARAGRAPHS, CHRONICLE.size())
		for line in CHRONICLE:
			long_one.add(SheetField.filled("", line))
		out.append(long_one)
	return out


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
	var phase := PopupMotion.Phase.SHUT
	var since_open := -1.0
	if t >= OPEN_AT:
		since_open = t - OPEN_AT
		phase = PopupMotion.Phase.OPEN
		if since_open < PopupMotion.PIECE_TIME + PopupMotion.STAGGER * 5.0:
			phase = PopupMotion.Phase.OPENING
	var rolled := smoothstep(ROLL.x, ROLL.y, t)
	for i in _cards.size():
		var card := _cards[i]
		card.scroll = _reach_down[i] * rolled
		card.pose(phase, t, since_open, Vector3.ZERO)
		card.measure()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP)
	_label("스크롤을 견디는 형태가 있나 — 열전 아홉 줄을 흘린다", Vector2(26.0, 44.0), 19, INK)
	_label("이음매를 자료가 정하는 것은 자료가 가만히 있을 때만 성립한다. 글이 흐르면 형태도 흐른다.", Vector2(26.0, 68.0), 13, DIM)
	_label("인물 | %s | 열전만 긴 글로 갈아 끼웠다" % _who, Vector2(26.0, 88.0), 13, DIM)
	draw_rect(Rect2(0.0, 100.0, size.x, 1.0), FAINT)

	for i in _cards.size():
		var card := _cards[i]
		var at := card.position
		_label(LedgerForm.label(card.form), Vector2(at.x, at.y - 14.0), 15, INK)
		var shake := _jitter(i)
		var bad := card.crossings() > 0 or shake > JITTER_LIMIT
		_label(
			"잘림 %d | 흔들림 %d px | 남은 글 %d px" % [card.crossings(), int(shake), int(card.below())],
			Vector2(at.x, at.y + CARD.y + 26.0),
			14,
			ALARM if bad else GOOD
		)


## 실루엣이 스크롤 0 일 때와 몇 px 다른가. **최댓값이다** — 평균을 내면 한 층만
## 크게 움직인 것이 묻힌다.
func _jitter(index: int) -> float:
	var now := _cards[index].profile()
	var then := _base[index]
	var worst := 0.0
	for i in mini(now.size(), then.size()):
		worst = maxf(worst, absf(now[i] - then[i]))
	return worst


func _label(what: String, at: Vector2, size_px: int, color: Color) -> void:
	draw_string(FONT, at, what, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
