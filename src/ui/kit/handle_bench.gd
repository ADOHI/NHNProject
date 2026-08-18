class_name HandleBench
extends Control
## **형태가 「어디까지 읽었나」를 말한다.** 스크롤바를 덧대지 않는다.
##
##     godot --path . res://src/ui/kit/handle_bench.tscn
##
## ## 왜 정지 화면으로 판정하나
##
## 자리 표시는 **위치의 함수**지 시간의 함수가 아니다. 「지금 어디쯤인가」를 한 장에서
## 읽을 수 있어야 쓸모가 있다. 그래서 같은 형태를 **처음 · 중간 · 끝** 세 자리에
## 나란히 세운다. 셋을 나란히 놓고 다르지 않으면 그 형태는 자리를 못 말하는 것이다.
##
## ## 셋만 세운다
##
## `LedgerForm.tells_position()` 이 참인 셋이다. 나머지 셋은 실루엣이 이미 내용에
## 잡아먹혀서(§20.15.1) 자리를 말할 채널이 안 남는다 — **같은 변에 두 가지 뜻을
## 얹으면 둘 다 안 읽힌다.**

const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")

const BACKDROP := Color("#dee2e8")
const FAINT := Color("#c2c8d1")
const INK := Color("#212a37")
const DIM := Color("#6d7681")

const CARD := Vector2(596.0, 428.0)
const SEED: int = 20260809
const POPULATION: int = 240

## 처음 · 중간 · 끝.
const STOPS := [0.0, 0.5, 1.0]
const STOP_NAMES := ["처음", "중간", "끝"]

var _cards: Array[LedgerCard] = []
var _driven := false
var _who := ""


func _ready() -> void:
	_build()


func drive_externally() -> void:
	_driven = true


func _build() -> void:
	var maker := PersonGenerator.new(SEED, POPULATION)
	var registry := maker.generate()
	var factions := FactionIndex.new(registry)
	var person := 0
	for i in registry.size():
		if registry.name_of(i).length() > registry.name_of(person).length():
			person = i
	_who = registry.name_of(person)
	var sheet := ScrollBench.long_sheet(PersonSheet.build(registry, person, factions))

	var row := 0
	for kind in LedgerForm.count():
		var form := kind as LedgerForm.Kind
		if not LedgerForm.tells_position(form):
			continue
		for stop in STOPS.size():
			var card := LedgerCard.new()
			card.form = form
			card.person_name = _who
			card.sections = sheet
			card.paged = true
			card.drive_externally()
			add_child(card)
			card.position = Vector2(
				30.0 + float(stop) * (CARD.x + 26.0), 132.0 + float(row) * (CARD.y + 86.0)
			)
			card.size = CARD
			_cards.append(card)
		row += 1
	_settle()


## 카드마다 제 자리로 흘려 둔다. **먼저 한 번 재야 흘릴 양을 안다.**
func _settle() -> void:
	for i in _cards.size():
		var card := _cards[i]
		card.scroll = 0.0
		card.pose(PopupMotion.Phase.OPEN, 1.0, 1.0, Vector3.ZERO)
		card.measure()
		card.scroll = card.below() * float(STOPS[i % STOPS.size()])
		card.measure()
	queue_redraw()


func set_clock(_t: float) -> void:
	_settle()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP)
	_label("형태가 자리를 말한다 — 스크롤바가 없다", Vector2(30.0, 46.0), 21, INK)
	_label("끝이 성하면 끝이고, 끝이 헐면 이어진다. 같은 형태를 처음 | 중간 | 끝 세 자리에 세웠다.", Vector2(30.0, 72.0), 14, DIM)
	_label("인물 | %s | 열전 아홉 줄" % _who, Vector2(30.0, 94.0), 13, DIM)
	draw_rect(Rect2(0.0, 108.0, size.x, 1.0), FAINT)

	for i in _cards.size():
		var card := _cards[i]
		var at := card.position
		var stop := i % STOPS.size()
		var head: String = STOP_NAMES[stop]
		if stop == 0:
			head = "%s — %s" % [LedgerForm.label(card.form), head]
		_label(head, Vector2(at.x, at.y - 22.0), 15, INK)
		_label(
			(
				"읽은 만큼 %d%% | 위 %d px | 아래 %d px 헐었다"
				% [
					int(card.reading().x * 100.0),
					int(LedgerForm.fray(card.form, card.reading()).x),
					int(LedgerForm.fray(card.form, card.reading()).y),
				]
			),
			Vector2(at.x, at.y + CARD.y + 26.0),
			14,
			DIM
		)


func _label(what: String, at: Vector2, size_px: int, color: Color) -> void:
	draw_string(FONT, at, what, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
