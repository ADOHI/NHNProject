class_name NoiseDossier
extends NoiseScreen
## **노이즈 축을 진짜 화면에 얹는다** — 인물 목록 스무 줄 + 인물 상세 한 창.
##
## docs/design/20-ui-kit.md §20.45 · §20.47.
##
##     godot --path . -s res://tools/capture_pop.gd -- .renders/62-person person stills
##
## ## 견본이 아니라 진짜 자료다
##
## 글은 `PersonSheet.build()` 가 낸 것이고 사람은 `PersonGenerator` 가 만든 것이다.
## 이름 · 나이 · 계열 · 유명세 · 전투 · 민첩 · 성향 6축 · 관계 목록 · 열전이
## **한 창에 다 들어간다.** 이 게임에서 글이 가장 많은 화면이다(§20.23).
##
## ## 자료의 상태가 사다리에 그대로 앉는다 — 이 판의 가장 큰 발견
##
## `SheetField.State` 는 셋을 가른다: **값이 있다 · 아직 안 만들었다 · 있지만 안 보인다.**
## 앞의 화면들은 이 셋을 「빈칸」이나 「회색 글자」로 그렸다 — 셋이 같아 보였다.
##
## | 상태 | 노이즈 | 화면에서 |
## | --- | --- | --- |
## | `FILLED` | 0.55 | 읽힌다 |
## | `MISSING` | 0.92 | 왜 없는지가 잡음 속에서 겨우 읽힌다 |
## | `HIDDEN` | 0.92 + **잡음 조각** | 값 자리에 글자가 아니라 **찢긴 띠**가 있다 |
##
## **「당신이 모른다」를 UI 가 그대로 말한다.** 가림(`SheetDisclosure.Level.CLUE`)이
## 지금까지 아무도 안 쓰던 층인데(§24.17.2) 이 축에서는 그것이 그림이 된다.

const CARD := Vector2(1280.0, 720.0)
const LOOP := 6.4

## 씨앗과 인구. **고정이다** — 캡처마다 다른 사람이 나오면 판정이 안 이어진다.
const SEED := 20260809
const POPULATION := 240

## 목록에 세우는 줄 수. **스무 줄이 물음이다** — 항목이 스물이면 노이즈가 스무 군데서
## 떠는데 그게 견딜 만한가 (§20.45.3).
const LIST := 20

const LIST_BOX := Rect2(16.0, 62.0, 316.0, 578.0)
const SHEET_BOX := Rect2(348.0, 62.0, 916.0, 578.0)
const MARK_BOX := Rect2(348.0, 654.0, 916.0, 50.0)

const ROW_TOP := 92.0
const ROW_PITCH := 26.0
const ROW_TALL := 22.0

const LINE_STEP := 20.0
const HEAD_SIZE := 14
const LINE_SIZE := 13

## 손이 올라가고 · 고르고 · 관계 줄로 초점이 넘어가고 · 되돌아온다.
const HOVER_UP := 1.30
const MOVE_AT := 2.20
const HOVER_DOWN := 3.20
const LINK_AT := 4.00
const LINK_OFF := 5.40

const ROW_FIRST := 3
const ROW_NEXT := 12

## 왼쪽 열에 세우는 칸과 오른쪽 열에 세우는 칸. **제목으로 고른다** —
## 순서 번호로 고르면 `PersonSheet` 가 칸을 하나 끼울 때 조용히 다른 칸이 그려진다.
const LEFT_TITLES := ["인물", "위협", "길드"]
const RIGHT_TITLES := ["성향", "관계", "인물 열전"]

var _registry: PersonRegistry
var _graph: RelationGraph
var _who: PackedInt32Array = PackedInt32Array([0, 0])
var _sheets: Array = []

## 관계 줄이 화면 어디에 얼마만큼 그려졌나. **초점이 그 줄로 넘어갈 때 쓴다** —
## 자리를 미리 정해 두면 칸이 자라거나 줄어들 때 초점만 딴 데를 가리킨다.
## 걷히는 자리가 **줄의 네모를 따라간다** (§20.47.3).
var _link_box := Rect2(-2000.0, -2000.0, 10.0, 10.0)


func screen_size() -> Vector2:
	return CARD


func loop_time() -> float:
	return LOOP


## 사람을 만들고 관계를 심는다. **캡처가 한 번만 부른다** — 240명이면 한 프레임에 든다.
func _ready_screen() -> void:
	var maker := PersonGenerator.new(SEED, POPULATION)
	_registry = maker.generate()
	var factions := FactionIndex.new(_registry)
	_graph = RelationGraph.new(_registry.size())
	var kin := KinSeeder.new(SEED, _registry, _graph)
	while not kin.seed_chunk(POPULATION):
		pass
	var norms := PersonNorms.new(_registry)
	# 관계가 가장 많은 사람 둘을 고른다. **관계 목록이 비면 이 화면이 재려던 것이 없다.**
	var ranked := _busiest()
	_who = PackedInt32Array([ranked[0], ranked[1]])
	for person in _who:
		_sheets.append(
			PersonSheet.build(
				_registry, person, factions, SheetDisclosure.Level.CLUE, _graph, norms
			)
		)


## 관계가 많은 순으로 둘. 같은 사람이 두 번 안 나오게 앞의 둘만 쓴다.
func _busiest() -> PackedInt32Array:
	var best := PackedInt32Array([0, 1])
	var most := PackedInt32Array([-1, -1])
	for i in _registry.size():
		var links := _graph.targets_of(i).size()
		if links > most[0]:
			most[1] = most[0]
			best[1] = best[0]
			most[0] = links
			best[0] = i
		elif links > most[1]:
			most[1] = links
			best[1] = i
	return best


func _hover_force() -> float:
	if _clock < HOVER_UP or _clock >= HOVER_DOWN + SNAP:
		return 0.0
	if _clock >= HOVER_DOWN:
		return 1.0 - snap(HOVER_DOWN)
	return snap(HOVER_UP)


## 관계 줄로 초점이 넘어간 정도 0..1. **화면에 또렷한 것은 여전히 하나다** —
## 이 값이 오르는 만큼 아래 강조 띠가 노이즈로 내려간다.
func _link_force() -> float:
	if _clock < LINK_AT or _clock >= LINK_OFF + SNAP:
		return 0.0
	if _clock >= LINK_OFF:
		return 1.0 - snap(LINK_OFF)
	return snap(LINK_AT)


func _marked_row() -> int:
	return ROW_NEXT if _clock >= MOVE_AT else ROW_FIRST


func _shown() -> int:
	return 1 if _clock >= MOVE_AT else 0


## 강조 띠는 916px 짜리 가로 띠고 관계 줄은 424px 짜리다 — **동그란 걷힘으로는 둘 다
## 양 끝이 잡음에 박힌다** (§20.47.3).
func focus_box() -> Rect2:
	if _link_force() > 0.5:
		return _link_box
	return MARK_BOX


func _paint_screen() -> void:
	_list()
	_sheet()
	_mark()


## 왼쪽 — 길드원 스무 줄. **고른 줄과 손이 닿은 줄만 또렷해진다.**
func _list() -> void:
	say(
		"길드원 %d" % _registry.size(),
		Vector2(LIST_BOX.position.x + 8.0, 46.0),
		15,
		paper(),
		Grain.KEPT
	)
	# **판이 직사각형이 아니다** — 왼아래 모서리가 비스듬히 잘리고 뒤판이 어긋나 있다.
	var board := GraphicCut.clipped(LIST_BOX, 22.0, 8)
	backplate(board, 0.008, Vector2(8.0, 8.0), Color(back(), 0.8), Grain.KEPT)
	paint(board, Color(paper(), 0.14), Grain.KEPT)
	var mark := _marked_row()
	var over := ROW_NEXT if _hover_force() > 0.0 else -1
	for i in LIST:
		var rect := Rect2(
			LIST_BOX.position.x + 10.0,
			ROW_TOP + float(i) * ROW_PITCH,
			LIST_BOX.size.x - 20.0,
			ROW_TALL
		)
		var noise := Grain.LIVE
		var out := 0.0
		var slant := SLANT * 0.7
		if i == mark:
			# 「자리」 — **기울기가 뒤집히고 판 밖으로 나간다.** 맑음(0.00)과 같이 온다.
			out = 18.0
			slant = -SLANT * 0.7
		elif i == over:
			out = 7.0 * _hover_force()
			slant = SLANT * 0.7 * (1.0 - _hover_force())
		rect.position.x -= out
		rect.size.x += out
		var shape := GraphicCut.lean(rect, slant)
		var tint := paper()
		if i == mark:
			noise = Grain.NEAR
			backplate(shape, 0.0, Vector2(9.0, 4.0), back(), noise)
			paint(shape, pick(), noise)
			paint(
				GraphicCut.fang(Rect2(rect.position, Vector2(8.0, rect.size.y)), 6.0),
				paper(),
				noise
			)
			tint = ink(pick())
		elif i == over:
			# 손 아래 있는 줄은 **끝까지 맑아진다** (§20.47.1).
			noise = lerpf(Grain.LIVE, Grain.NEAR, _hover_force())
			paint(shape, Color(paper(), 0.10 * _hover_force()), noise)
		_row_text(i, rect, tint, noise)


## 줄 하나의 글 — **이름과 나이·성별이 따로 논다** (§20.48).
##
## 초점이 정한 값(`seat`)은 「얼마나 보고 있나」고, 아는 정도는 **맑음의 천장**이다.
## 그래서 고른 줄이어도 **모르는 사람은 안 맑아진다** — 쳐다본다고 알게 되지 않는다.
##
## 나이·성별을 모를 때 **빈칸으로 두지 않는다.** 「없다」와 「모른다」를 가른 것이
## 이 축이 한 일이라(§20.45.2) 되돌리면 안 된다 — 값 자리에 **찢긴 띠**를 놓는다.
func _row_text(row: int, rect: Rect2, tint: Color, seat: float) -> void:
	var person := _person_of(row)
	var tier := _tier_of(row)
	var name_noise := KnownNoise.over(seat, tier, KnownNoise.Part.NAME)
	var trait_noise := KnownNoise.over(seat, tier, KnownNoise.Part.TRAIT)
	var seat_at := rect.position + Vector2(12.0, 16.0)
	say(_registry.name_of(person), seat_at, LINE_SIZE, tint, name_noise)
	var told := Vector2(rect.position.x + 96.0, seat_at.y)
	if not KnownNoise.tells(tier, KnownNoise.Part.TRAIT):
		paint(
			GraphicCut.lean(Rect2(told.x, told.y - 11.0, 96.0, 12.0), 0.5),
			Color(paper(), 0.5),
			trait_noise
		)
		return
	var told_line := (
		"%d세 %s" % [_registry.age_of(person), PersonGender.label(_registry.gender_of(person))]
	)
	say(told_line, told, LINE_SIZE, tint, trait_noise)


## 이 줄의 사람을 **얼마나 아는가** (§20.48).
##
## **임시로 줄 번호로 정해 뒀다.** 세 단을 여기서 흉내 내 두는 이유는 **세 단이 다
## 화면에 있어야 그림이 판정되기** 때문이지 관계 쪽 셈을 다시 하려는 것이 아니다.
##
## **관계 쪽 쌍 단위 질의가 이 저장소에 들어오면 이 함수의 속이 그 한 줄로 바뀐다** —
## 보는 사람과 보이는 사람의 세계 번호 둘을 넘기면 세 단이 나온다. 세계에 번호가
## 없는 사람은 `STRANGER` 로 그린다.
##
## > **유명세 문턱을 여기서 읽지 마라.** 무엇이 「들어 본 이름」인지는 관계 쪽이 정한다.
##
## 비율은 관계 쪽 실측에 맞췄다 — 겪어서 아는 얼굴 3/20(15%) · 들어 본 이름 5/20(25%).
## 고른 줄(3)은 겪어서 아는 사람이고 **나중에 고르는 줄(12)은 들어 본 이름**이다:
## 「고른 줄인데 나이·성별이 안 읽힌다」가 이 화면의 물음이다.
func _tier_of(row: int) -> KnownNoise.Tier:
	if row in [ROW_FIRST, 7, 15]:
		return KnownNoise.Tier.KNOWN
	if row in [1, 5, 9, ROW_NEXT, 18]:
		return KnownNoise.Tier.HEARD_OF
	return KnownNoise.Tier.STRANGER


## 이 줄이 누구인가. **고른 줄과 상세가 같은 사람이어야 한다** — 목록은 줄 번호로
## 사람을 고르고 상세는 따로 골랐더니, 고른 줄과 창의 이름이 서로 다른 사람이었다.
## 화면은 멀쩡해 보이고 **아무도 안 읽는 자리에서만 거짓말**을 한다.
func _person_of(row: int) -> int:
	if row == ROW_FIRST:
		return _who[0]
	if row == ROW_NEXT:
		return _who[1]
	return row


## 오른쪽 — 인물 상세 한 창. 칸을 두 열로 세운다.
func _sheet() -> void:
	var frame := GraphicCut.clipped(SHEET_BOX, 26.0, 2 | 8)
	backplate(frame, 0.006, Vector2(10.0, 10.0), Color(back(), 0.7), Grain.KEPT)
	paint(frame, Color(paper(), 0.14), Grain.KEPT)
	var sections: Array[SheetSection] = _sheets[_shown()]
	var person := _who[_shown()]
	var top := SHEET_BOX.position + Vector2(24.0, 44.0)
	# 이름은 **판을 뚫는 글자**다 (§20.37). 판 · 획 · 뒤판이 같은 띠로 통째로 움직인다.
	var slab := GraphicCut.lean(Rect2(top.x - 14.0, top.y - 34.0, 250.0, 46.0), 0.26)
	var unit := top.y - 11.0
	backplate(slab, 0.01, Vector2(6.0, 6.0), back(), Grain.KEPT, unit)
	paint(slab, paper(), Grain.KEPT, unit)
	var mark := glyphs(_registry.name_of(person), top, -0.06, 30)
	for ring: PackedVector2Array in mark["solid"]:
		pierce(slab, ring, void_color(), paper(), Grain.KEPT, unit)
	# 구멍을 안 덮으면 ㅇ · ㅁ 의 속이 메워져 **그 글자만 다른 글자로 읽힌다.**
	for ring: PackedVector2Array in mark["hole"]:
		pierce(slab, ring, paper(), void_color(), Grain.KEPT, unit)
	say(
		(
			"%d세 %s  %s"
			% [
				_registry.age_of(person),
				PersonGender.label(_registry.gender_of(person)),
				MemberDiscipline.label(_registry.discipline_of(person))
			]
		),
		top + Vector2(0.0, 24.0),
		LINE_SIZE,
		Color(paper(), 0.75),
		Grain.LIVE
	)
	_link_box = Rect2(-2000.0, -2000.0, 10.0, 10.0)
	var y := top.y + 52.0
	for title: String in LEFT_TITLES:
		y = _section(PersonSheet.section_of(sections, title), Vector2(top.x, y), 400.0)
	y = top.y + 52.0
	for title: String in RIGHT_TITLES:
		y = _section(PersonSheet.section_of(sections, title), Vector2(top.x + 444.0, y), 424.0)


## 칸 하나. 제목 한 줄과 밑줄, 그리고 필드들. 다음 칸이 시작할 `y` 를 돌려준다.
func _section(section: SheetSection, at: Vector2, wide: float) -> float:
	if section == null:
		return at.y
	say(section.title, at, HEAD_SIZE, Color(paper(), 0.8), Grain.KEPT)
	stroke(
		Vector2(at.x, at.y + 6.0),
		Vector2(at.x + wide, at.y + 6.0),
		Color(paper(), 0.3),
		Grain.KEPT,
		1.0
	)
	var y := at.y + 24.0
	for field: SheetField in section.fields:
		y = _line(field, Vector2(at.x, y), wide)
	return y + 18.0


## 필드 한 줄. **상태가 노이즈를 정한다** (§20.45.2).
func _line(field: SheetField, at: Vector2, wide: float) -> float:
	var noise := Grain.LIVE
	var linked := field.link != SheetField.NO_LINK
	if linked and _link_force() > 0.0 and _link_box.position.x < -1000.0:
		# 첫 관계 줄이 눌린 줄이다. **초점이 여기로 온다.**
		noise = lerpf(Grain.LIVE, Grain.HERE, _link_force())
		_link_box = Rect2(at.x - 6.0, at.y - 15.0, wide + 12.0, LINE_STEP)
		var hit := Rect2(at.x - 6.0 - 10.0 * _link_force(), at.y - 15.0, wide + 12.0, LINE_STEP)
		paint(
			GraphicCut.lean(hit, -SLANT * 0.5 * _link_force()),
			Color(accent(), 0.85 * _link_force()),
			noise
		)
	if field.state != SheetField.State.FILLED:
		return _blank(field, at, wide)
	var tint := paper() if not linked or noise > 0.2 else ink(accent())
	say(field.label, at, LINE_SIZE, Color(tint, 0.7), noise)
	var seat := Vector2(at.x + 92.0, at.y)
	if field.has_meter:
		_meter(field, Vector2(at.x + wide - 88.0, at.y - 9.0))
		say(field.value, seat, LINE_SIZE, tint, noise)
		return at.y + LINE_STEP
	say(field.value, seat, LINE_SIZE, tint, noise, wide - 92.0)
	return at.y + LINE_STEP


## 값이 없는 줄 — **아직 안 만든 것**과 **있지만 안 보이는 것.**
##
## 가려진 것은 값 자리에 **찢긴 띠**를 놓는다. 빈칸으로 두면 「없다」와 같아 보이고,
## 「■■■」 같은 글자로 채우면 **글꼴에 없는 글자**가 웹에서 두부가 된다(§tools/check_glyphs).
func _blank(field: SheetField, at: Vector2, wide: float) -> float:
	say(field.label, at, LINE_SIZE, Color(paper(), 0.7), Grain.LOST)
	if field.state == SheetField.State.HIDDEN:
		var chunk := Rect2(at.x + 92.0, at.y - 11.0, minf(wide - 100.0, 150.0), 12.0)
		paint(GraphicCut.lean(chunk, 0.5), Color(paper(), 0.5), Grain.LOST)
		return at.y + LINE_STEP
	say(field.reason, Vector2(at.x + 92.0, at.y), LINE_SIZE, paper(), Grain.LOST, wide - 92.0)
	return at.y + LINE_STEP


## 막대. **값이 차 있는 쪽은 고름**이다 — 켜진 것과 골라 둔 것과 찬 것은 같은 종류다.
func _meter(field: SheetField, at: Vector2) -> void:
	var rail := Rect2(at.x, at.y, 80.0, 8.0)
	paint(GraphicCut.lean(rail, 0.9), Color(paper(), 0.18), Grain.LIVE)
	var full := clampf(absf(field.bar), 0.0, 1.0)
	if field.is_signed_bar:
		var half := rail.size.x * 0.5
		var span := half * full
		var from := rail.position.x + half if field.bar >= 0.0 else rail.position.x + half - span
		paint(
			GraphicCut.lean(Rect2(from, rail.position.y, span, rail.size.y), 0.9),
			pick(),
			Grain.LIVE
		)
		return
	var full_box := Rect2(rail.position, Vector2(rail.size.x * full, rail.size.y))
	paint(GraphicCut.lean(full_box, 0.9), pick(), Grain.LIVE)


## 강조 — **지금 여기.** 관계 줄로 초점이 넘어가면 이 자리를 내준다.
func _mark() -> void:
	var noise := lerpf(Grain.HERE, Grain.LIVE, _link_force())
	# **뾰족한 끝.** 「지금 여기」는 판 중에 혼자 다른 도형이다.
	var shape := GraphicCut.fang(Rect2(MARK_BOX.position, MARK_BOX.size - Vector2(24.0, 0.0)), 24.0)
	backplate(shape, 0.01, Vector2(8.0, 8.0), paper(), noise)
	paint(shape, accent(), noise)
	say(
		"출정에 넣는다",
		Vector2(MARK_BOX.position.x, MARK_BOX.get_center().y + 8.0),
		22,
		ink(accent()),
		noise,
		MARK_BOX.size.x,
		HORIZONTAL_ALIGNMENT_CENTER
	)
