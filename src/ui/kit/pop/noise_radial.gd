class_name NoiseRadial
extends NoiseScreen
## **원형 스쿼드에 노이즈 축을 얹는다** — 가운데만 또렷하고 옆으로 갈수록 잡음이다.
##
## docs/design/20-ui-kit.md §20.45 · §20.47.
##
##     godot --path . -s res://tools/capture_pop.gd -- .renders/62-ring ring stills
##
## ## 두 문장이 같은 말을 하고 있었다
##
## `RadialDeck` 은 **「가운데가 곧 선택됨이다 — 자리가 상태다」**로 만들어졌고(§20.20),
## 이 축은 **「선명함이 곧 주의다」**다. 둘이 부딪히지 않는다 — `nearness` 가 그대로
## 노이즈가 된다. 앞의 화면은 그것을 **크기와 밝기**로 말했고 여기서는 **또렷함**으로 말한다.
##
## ## 도는 동안에는 또렷한 것이 없다
##
## `settled` 가 0 인 구간(가운데가 바뀌는 순간)에서는 **화면에 노이즈 0.00 이 하나도 없다.**
## 초점이 오는 중이라서다. 「지금 여기가 둘이 되는」 자리가 원래 여기였는데
## (옛 인물과 새 인물이 둘 다 커 보이는 반 칸) 축이 하나라서 **저절로 막힌다.**

const CARD := Vector2(1280.0, 720.0)
const LOOP := 6.4

const SEED := 20260809
const POPULATION := 240

## 링에 세우는 인원. **스쿼드 정원이 넷**이고 후보 하나를 더 붙였다.
const CREW := 5

## 한 사람에서 다음 사람으로 넘어가는 데 걸리는 시간. 한 바퀴가 `CREW` 걸음이다.
const STEP := LOOP / float(CREW)

## 그중 도는 시간. 나머지는 서 있다 — **선 뒤를 봐야 또렷함이 판정된다.**
const TURN := 0.42

## 액자 기본 크기. `RadialDeck.figure_scale` 이 0.30~0.74 를 곱한다.
const FIGURE := Vector2(240.0, 320.0)

## 이름패 높이.
const PLATE := 34.0

var _registry: PersonRegistry
var _sheets: Array = []


func screen_size() -> Vector2:
	return CARD


func loop_time() -> float:
	return LOOP


func _ready_screen() -> void:
	var maker := PersonGenerator.new(SEED, POPULATION)
	_registry = maker.generate()
	var factions := FactionIndex.new(_registry)
	var norms := PersonNorms.new(_registry)
	for i in CREW:
		_sheets.append(
			PersonSheet.build(_registry, i, factions, SheetDisclosure.Level.CLUE, null, norms)
		)


## 지금 링이 어디까지 돌았나. **정수면 서 있는 것**이고 사이값이면 도는 중이다.
func _picked() -> float:
	var k := floorf(_clock / STEP)
	var u := fposmod(_clock, STEP) / STEP
	if u >= TURN:
		return k + 1.0
	# 스냅 — 미끄러져 들어와 탁 선다.
	return k + (1.0 - pow(1.0 - u / TURN, 3.0))


## 이 사람이 서는 자리와 크기.
func _figure_of(index: int) -> Rect2:
	var picked := _picked()
	var scale := RadialDeck.figure_scale(index, CREW, picked, 1.0)
	var at := RadialDeck.stand(index, CREW, picked, 1.0, CARD)
	var box := FIGURE * scale
	return Rect2(at - Vector2(box.x * 0.5, box.y * 0.72), box)


## 이 사람의 노이즈. **`nearness` 를 사다리에 그대로 앉힌다.**
##
## 세제곱으로 누르는 것은 `figure_scale` 이 크기에 하는 것과 같다 — 같은 값을 두 축이
## 다르게 읽으면 **큰데 흐린 사람**이 생기고, 그러면 둘 중 무엇이 신호인지 안 읽힌다.
func _noise_of(index: int) -> float:
	var near := RadialDeck.nearness(index, CREW, _picked())
	var sharp := near * near * near
	# 서 있을 때만 맨 앞이 0.00 까지 간다. 도는 동안에는 아무도 다 또렷하지 않다.
	sharp *= RadialDeck.settled(_picked())
	return lerpf(Grain.LOST, Grain.HERE, sharp)


## 걷히는 네모 — **맨 앞 사람의 액자와 이름패, 그리고 붙어 있는 창까지.**
##
## 액자는 세로로 긴 판이라 걷힘이 동그라면 위아래가 잡음에 박힌다 (§20.47.3).
## 창을 합치는 이유는 그 창이 **반투명한 판**이라서다 — 노이즈 0 이라 안 찢기는데
## 뒤의 알갱이가 그대로 비쳐서 **면이 안 매끈했다.** 「맑음」은 부품의 성질만으로는
## 안 되고 **그 자리의 성질**이기도 하다.
func focus_box() -> Rect2:
	var picked := _picked()
	var front := RadialDeck.front_index(CREW, picked)
	var box := _figure_of(front)
	var seat := Rect2(box.position, box.size + Vector2(0.0, PLATE * 1.6))
	var unfold := RadialDeck.settled(picked)
	if unfold <= 0.0:
		return seat
	return seat.merge(RadialDeck.slot_rect(RadialDeck.Slot.IDENTITY, box, CARD, unfold))


func _paint_screen() -> void:
	say("출정 편성", Vector2(28.0, 44.0), 17, paper(), Grain.KEPT)
	say(
		"가운데가 곧 고른 사람이다. 옆은 아직 안 본 사람이라 잡음이다.",
		Vector2(28.0, 66.0),
		13,
		Color(paper(), 0.7),
		Grain.KEPT
	)
	# **뒤에서 앞으로 그린다.** 노이즈가 큰 것부터 그려야 또렷한 것이 위에 온다.
	var order := _back_to_front()
	for index in order:
		_figure(index)
	_slot()


## 노이즈가 큰 순서. 그리는 순서가 곧 앞뒤라 **정렬이 곧 층**이다.
func _back_to_front() -> Array:
	var order: Array = []
	for i in CREW:
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return _noise_of(a) > _noise_of(b))
	return order


## 한 사람 — 액자 · 이름패 · 값 두 줄.
##
## **얼굴 자산이 없다.** 액자는 빈 판이고, 그 판이 얼마나 찢겨 있는지가 이 사람을
## 얼마나 보고 있는지다 — 그림이 붙어도 축은 안 바뀐다.
func _figure(index: int) -> void:
	var noise := _noise_of(index)
	var box := _figure_of(index)
	# 액자도 **평행사변형**이고 뒤판이 색을 갖고 어긋나 있다 (§20.28).
	var frame := GraphicCut.lean(box, SLANT * 0.6)
	backplate(frame, 0.01, Vector2(9.0, 9.0), back(), noise)
	paint(frame, Color(paper(), 0.20), noise)
	var plate := Rect2(box.position.x, box.end.y, box.size.x, PLATE * (box.size.y / FIGURE.y) * 1.6)
	# 맨 앞의 이름패만 **신호색**이고 **뾰족하다.** 화면에 이 색이 나오는 자리는 하나뿐이다.
	var lit := noise < 0.05
	var face := accent() if lit else Color(paper(), 0.18)
	var tag := (
		GraphicCut.fang(Rect2(plate.position, plate.size - Vector2(14.0, 0.0)), 14.0)
		if lit
		else GraphicCut.lean(plate, SLANT * 0.6)
	)
	if lit:
		backplate(tag, 0.012, Vector2(7.0, 7.0), paper(), noise)
	paint(tag, face, noise)
	var tall := int(clampf(plate.size.y * 0.52, 9.0, 20.0))
	say(
		_registry.name_of(index),
		Vector2(plate.position.x, plate.get_center().y + float(tall) * 0.36),
		tall,
		ink(face) if noise < 0.05 else paper(),
		noise,
		plate.size.x,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	if box.size.y < FIGURE.y * 0.5:
		return
	say(
		(
			"%d세 %s  %s"
			% [
				_registry.age_of(index),
				PersonGender.label(_registry.gender_of(index)),
				MemberDiscipline.label(_registry.discipline_of(index))
			]
		),
		Vector2(plate.position.x, plate.end.y + 20.0),
		13,
		paper(),
		noise,
		plate.size.x,
		HORIZONTAL_ALIGNMENT_CENTER
	)


## 창 하나가 맨 앞 사람에게 붙는다. **도는 동안 접힌다** (`settled`).
##
## 접힘을 노이즈로 바꾸지 않았다 — 접힘은 **자리를 차지하는 방식**이고 노이즈는
## **얼마나 보고 있나**다. 접힌 창이 또렷할 수 있어야 「접혔다」가 읽힌다.
func _slot() -> void:
	var picked := _picked()
	var front := RadialDeck.front_index(CREW, picked)
	var unfold := RadialDeck.settled(picked)
	var figure := _figure_of(front)
	var rect := RadialDeck.slot_rect(RadialDeck.Slot.IDENTITY, figure, CARD, unfold)
	var noise := lerpf(Grain.LOST, Grain.NEAR, unfold)
	var shape := GraphicCut.clipped(rect, minf(18.0, rect.size.y * 0.4), 1 | 4)
	backplate(shape, 0.01, Vector2(8.0, 8.0), Color(back(), 0.8), noise)
	paint(shape, Color(paper(), 0.16), noise)
	stroke(
		RadialDeck.anchor_at(RadialDeck.Slot.IDENTITY, figure),
		Vector2(rect.position.x, rect.get_center().y),
		Color(paper(), 0.4),
		noise,
		1.6
	)
	if unfold < 0.35:
		return
	var sections: Array[SheetSection] = _sheets[front]
	var section := PersonSheet.section_of(sections, RadialDeck.label(RadialDeck.Slot.IDENTITY))
	if section == null:
		return
	say(section.title, rect.position + Vector2(14.0, 22.0), 14, Color(paper(), 0.8), noise)
	var y := rect.position.y + 46.0
	for field: SheetField in section.fields:
		if y > rect.end.y - 8.0:
			return
		say(field.label, Vector2(rect.position.x + 14.0, y), 13, Color(paper(), 0.7), noise)
		say(field.value, Vector2(rect.position.x + 78.0, y), 13, paper(), noise)
		if field.has_meter:
			var rail := Rect2(rect.position.x + 150.0, y - 9.0, 80.0, 8.0)
			paint(GraphicCut.lean(rail, 0.9), Color(paper(), 0.18), noise)
			var full := Rect2(
				rail.position, Vector2(rail.size.x * clampf(absf(field.bar), 0.0, 1.0), rail.size.y)
			)
			paint(GraphicCut.lean(full, 0.9), pick(), noise)
		y += 22.0
