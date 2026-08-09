class_name NoiseSheet
extends NoiseScreen
## **선명함이 곧 주의(注意)다.** 아직 안 본 것은 노이즈고, 보는 순간 또렷해진다.
##
## docs/design/20-ui-kit.md §20.44 · §20.47.
##
##     godot --path . -s res://tools/capture_pop.gd -- .renders/62-clear noise
##
## ## 이 화면에 손잡이는 하나다
##
## §20.28~20.43 은 매 판 하나씩 더해 열 몇 가지가 됐다 — 층 · 무아레 · 파면 · 주사선 ·
## 훑는 띠 · 꺾쇠 · 눈금 · 숫자열 · 글리치 · 잔광 · 벤 자국. **컨셉이 없으면 뺄 근거가 없다.**
##
## 여기서는 부품마다 **노이즈 한 값**만 정한다. 그 값이 찢김 · 빠짐 · 대비를 다 정하고
## (`Grain`), 바탕은 축의 끝(`grain_field`)이다. 그래서 화면이 조용하다 —
## **효과가 적은 것이 아니라 효과가 하나**다.
##
## ## 이 게임에서 나온 컨셉이다
##
## 사람 셋넷을 데리고 던전에 들어가는데 안쪽은 안 가 보면 모르고, 대원은 배신하고,
## 소문은 틀린다. **정보가 불확실한 것이 이 게임의 내용**이고 UI 가 그것을 그대로 보인다.
##
## ## 노이즈는 **표면**이지 형태가 아니다 (§20.46)
##
## 처음에 축을 세우면서 「참격」의 형태와 색까지 같이 뺐다 — 그러면 화면이 조용해지는
## 것이 아니라 **비어 버린다.** 형태는 도로 가져왔다: 평행사변형 · 비스듬히 잘린 모서리 ·
## 뾰족한 끝 · **색을 가진 어긋난 뒤판** · 판을 뚫는 글자 · 꽉 찬 면.
##
## **한 부품이 축 둘을 갖는다 — 「참격의 형태」 × 「노이즈의 정도」.**
## 형태는 그것이 무엇인지를 말하고 노이즈는 그것을 얼마나 보고 있나를 말한다.
##
## **이것은 부품 견본이다.** 진짜 화면에 얹은 것은 `NoiseDossier` 다 (§20.45).

const CARD := Vector2(660.0, 760.0)
const LOOP := 7.2
const PAD := 26.0

const ROWS: Array[String] = ["출격", "길드", "인물", "설정", "기록", "상점", "종료"]

## 손이 올라가고 · 선택이 옮겨가고 · 팝업이 열리고 · 되돌아온다.
## **되돌아오는 것까지 한 바퀴 안에 있다** — 안 넣으면 바퀴 끝에서 화면이 튄다.
const HOVER_UP := 1.50
const MOVE_AT := 2.40
const HOVER_DOWN := 3.40
const POP_UP := 4.20
const POP_DOWN := 5.80
const MOVE_BACK := 6.40

const ROW_FIRST := 1
const ROW_NEXT := 4

const BOARD_TOP := 202.0
const BOARD_TALL := 372.0
const BAR_TALL := 36.0
const ROW_TOP := 256.0
const ROW_PITCH := 34.0
const ROW_TALL := 28.0
const ROW_LEFT := 44.0
const ROW_WIDE := 300.0

const MARK_TOP := 612.0
const MARK_TALL := 58.0

const POPUP := Rect2(150.0, 300.0, 360.0, 180.0)

## 고른 줄이 **판 밖으로도 나갈 것인가** (§20.40 의 「자리」).
##
## **한 번 내렸다가 되살렸다** (§20.46.3). 판이 반듯한 직사각형뿐일 때는 20px 나간 것이
## 잡음과 같은 종류로 읽혔다. 판이 다시 평행사변형이 되자 **기울기가 뒤집히는 것**이
## 축으로 살아난다 — 「자리」와 노이즈 0 이 **같이** 온다.
var place := true:
	set(value):
		place = value
		queue_redraw()


func screen_size() -> Vector2:
	return CARD


func loop_time() -> float:
	return LOOP


## 지금 팝업이 얼마나 열려 있나 0..1.
func _pop_force() -> float:
	if _clock < POP_UP or _clock >= POP_DOWN + SNAP:
		return 0.0
	if _clock >= POP_DOWN:
		return 1.0 - snap(POP_DOWN)
	return snap(POP_UP)


## 부품 하나의 최종 노이즈. **가림막이 여기 한 곳에서만 더해진다.**
func _noise(step: float) -> float:
	return Grain.veiled(step, Grain.VEIL * _pop_force())


func _hover_force() -> float:
	if _clock < HOVER_UP or _clock >= HOVER_DOWN + SNAP:
		return 0.0
	if _clock >= HOVER_DOWN:
		return 1.0 - snap(HOVER_DOWN)
	return snap(HOVER_UP)


func _hovered_row() -> int:
	return ROW_NEXT if _hover_force() > 0.0 else -1


func _marked_row() -> int:
	if _clock >= MOVE_AT and _clock < MOVE_BACK:
		return ROW_NEXT
	return ROW_FIRST


## 고른 줄이 자리로 얼마나 나갔나 0..1. **미끄러져 나가 탁 선다** — 스냅이다.
##
## 두 번의 이동이 같은 값을 쓴다. 나가는 것과 되돌아오는 것이 다른 곡선이면
## 한 바퀴 안에서 **같은 사건이 두 가지로** 보인다.
func _mark_force() -> float:
	if _clock < MOVE_AT:
		return 1.0
	if _clock < MOVE_BACK:
		return snap(MOVE_AT, 0.16)
	return snap(MOVE_BACK, 0.16)


## 지금 또렷한 것의 네모. **팝업이 열리면 초점이 팝업으로 넘어간다.**
##
## 강조 띠는 가로로 608px 이라 **동그란 걷힘으로는 양 끝이 잡음에 박혔다** (§20.47.3).
func focus_box() -> Rect2:
	if _pop_force() > 0.5:
		return POPUP
	return Rect2(PAD, MARK_TOP, CARD.x - PAD * 2.0, MARK_TALL)


func _paint_screen() -> void:
	_title()
	_buttons()
	_window()
	_mark()
	_popup()


## 제목 — **글자가 판을 뚫는다** (§20.37). 판은 기울고 뒤판이 색을 갖고 어긋나 있다.
##
## 판과 글자와 뒤판이 **같은 노이즈**를 받아 한 띠에서 같이 찢긴다 — 따로 주면
## 글자만 다른 데서 어긋나 「어긋난 것」이 아니라 「안 맞은 것」이 된다.
func _title() -> void:
	var noise := _noise(Grain.KEPT)
	var slab := GraphicCut.lean(Rect2(-30.0, 8.0, 196.0, 84.0), 0.30)
	# 판과 획과 뒤판이 **같은 띠 하나로** 움직인다. 따로 찢으면 획이 끊겨 못 읽는다.
	var unit := 50.0
	backplate(slab, 0.012, Vector2(7.0, 7.0), back(), noise, unit)
	paint(slab, paper(), noise, unit)
	var mark := glyphs("잡음", Vector2(24.0, 82.0), -0.075, 64)
	for ring: PackedVector2Array in mark["solid"]:
		pierce(slab, ring, void_color(), paper(), noise, unit)
	for ring: PackedVector2Array in mark["hole"]:
		pierce(slab, ring, paper(), void_color(), noise, unit)
	say("본 것만 또렷하다", Vector2(PAD, 112.0), 14, Color(paper(), 0.7), noise)


## 버튼 넷 — 기본 · 올림 · 눌림 · 비활성. **네 상태가 노이즈 사다리의 네 칸이다.**
##
## 비활성에 빗금을 안 친다. 안 쓰는 것은 **주의를 안 받는 것**이고 그건 이미 축 위에 있다.
func _buttons() -> void:
	var labels := ["기본", "올림", "눌림", "비활성"]
	var steps := [Grain.LIVE, Grain.NEAR, Grain.NEAR, Grain.LOST]
	var wide := (CARD.x - PAD * 2.0 - 36.0) / 4.0
	for i in 4:
		var rect := Rect2(PAD + float(i) * (wide + 12.0), 138.0, wide, 52.0)
		var noise: float = _noise(steps[i])
		var down := i == 2
		var shape := GraphicCut.lean(rect, 0.24)
		if down:
			# 눌린 판은 **조금 줄고 오른아래로 들어간다.** 뒤판이 미색이라 눌린 것이 읽힌다.
			shape = GraphicCut.swelled(shape, -0.03, Vector2(4.0, 4.0))
		var face := pick() if i == 1 or down else Color(paper(), 0.17)
		if i != 3:
			backplate(shape, 0.02, Vector2(8.0, 8.0), paper() if down else back(), noise)
		paint(shape, face, noise)
		say(
			labels[i],
			Vector2(rect.position.x, rect.get_center().y + 6.0),
			17,
			ink(face) if i == 1 or i == 2 else paper(),
			noise,
			rect.size.x,
			HORIZONTAL_ALIGNMENT_CENTER
		)


## 창 — 제목줄 · 닫기 · 메뉴 일곱 줄 · 슬라이더 · 체크 · 험.
func _window() -> void:
	var noise := _noise(Grain.KEPT)
	var box := Rect2(PAD, BOARD_TOP, CARD.x - PAD * 2.0, BOARD_TALL)
	# **모서리 둘이 비스듬히 잘렸다.** 넷을 다 자르면 팔각형이 되어 얌전해진다.
	var shape := GraphicCut.clipped(box, 26.0, 2 | 8)
	backplate(shape, 0.014, Vector2(9.0, 9.0), Color(back(), 0.75), noise)
	paint(shape, Color(paper(), 0.16), noise)
	var bar := Rect2(box.position.x, box.position.y, box.size.x - 26.0, BAR_TALL)
	paint(box_of(bar), Color(paper(), 0.30), noise)
	say("길드 본부", box.position + Vector2(16.0, 25.0), 17, paper(), noise)
	# 닫기는 **험**이다. 창에서 되돌릴 수 없는 것은 이것 하나뿐이다.
	var shut := Vector2(box.end.x - 26.0, box.position.y + 18.0)
	stroke(shut + Vector2(-6, -6), shut + Vector2(6, 6), peril(), noise, 2.6)
	stroke(shut + Vector2(-6, 6), shut + Vector2(6, -6), peril(), noise, 2.6)
	_menu()
	_inputs(Rect2(366.0, 258.0, 248.0, 296.0))


## 메뉴 — **고른 줄과 손이 닿은 줄만 또렷해진다.** 나머지는 노이즈 0.42 다.
func _menu() -> void:
	var mark := _marked_row()
	var over := _hovered_row()
	for i in ROWS.size():
		var rect := Rect2(ROW_LEFT, ROW_TOP + float(i) * ROW_PITCH, ROW_WIDE, ROW_TALL)
		var noise := _noise(Grain.LIVE)
		var out := 0.0
		var slant := SLANT
		if i == mark and place:
			# **기울기 자체가 축이다** (§20.40.1) — 밀림은 판 기울기와 섞이지만
			# 반대로 기운 줄은 **다른 도형**이라 안 섞인다. 스냅으로 나간다.
			out = 22.0 * _mark_force()
			slant = SLANT - 0.40 * _mark_force()
		elif i == over and place:
			out = 8.0 * _hover_force()
			slant = SLANT - 0.20 * _hover_force()
		rect.position.x -= out
		rect.size.x += out
		var shape := GraphicCut.lean(rect, slant)
		if i == mark:
			noise = _noise(Grain.NEAR)
			backplate(shape, 0.0, Vector2(10.0, 5.0), back(), noise)
			paint(shape, pick(), noise)
			# 쐐기는 줄의 **왼 끝에 물려** 앉는다. 밖에 따로 세우면 잘린 것처럼 보인다.
			var wedge := Rect2(rect.position, Vector2(9.0, rect.size.y))
			paint(GraphicCut.fang(wedge, 7.0), paper(), noise)
			say(ROWS[i], rect.position + Vector2(16.0, 20.0), 16, ink(pick()), noise)
			continue
		if i == over:
			# 손이 닿은 줄은 **끝까지 맑아진다.** 「거의 0」에서 멈추면 손 아래 있는 것이
			# 여전히 떨고, 그것이 앞 판에서 「선명한 것이 맑지 않다」로 보이던 자리다.
			noise = lerpf(_noise(Grain.LIVE), _noise(Grain.NEAR), _hover_force())
			paint(shape, Color(paper(), 0.10 * _hover_force()), noise)
		say(ROWS[i], rect.position + Vector2(16.0, 20.0), 16, paper(), noise)


## 슬라이더 · 체크 · 험. **손 닿는 부품이라 전부 노이즈 0.42 다.**
func _inputs(box: Rect2) -> void:
	var noise := _noise(Grain.LIVE)
	say("소리", box.position + Vector2(0.0, 14.0), 14, Color(paper(), 0.8), noise)
	var rail := Rect2(box.position.x, box.position.y + 30.0, box.size.x, 8.0)
	paint(GraphicCut.lean(rail, 0.9), Color(paper(), 0.18), noise)
	var full := Rect2(rail.position, Vector2(rail.size.x * 0.62, rail.size.y))
	paint(GraphicCut.lean(full, 0.9), pick(), noise)
	var knob_box := Rect2(full.end.x - 8.0, rail.position.y - 11.0, 16.0, 30.0)
	var knob := GraphicCut.lean(knob_box, 0.4)
	backplate(knob, 0.04, Vector2(4.0, 4.0), void_color(), noise)
	paint(knob, paper(), noise)

	var tick := Rect2(box.position.x, box.position.y + 86.0, 26.0, 26.0)
	var tick_shape := GraphicCut.lean(tick, 0.22)
	backplate(tick_shape, 0.04, Vector2(5.0, 5.0), void_color(), noise)
	paint(tick_shape, pick(), noise)
	stroke(
		tick.position + Vector2(6.0, 13.0),
		tick.position + Vector2(11.0, 19.0),
		ink(pick()),
		noise,
		3.0
	)
	stroke(
		tick.position + Vector2(11.0, 19.0),
		tick.position + Vector2(21.0, 6.0),
		ink(pick()),
		noise,
		3.0
	)
	say("전체 화면", Vector2(tick.end.x + 14.0, tick.position.y + 19.0), 15, paper(), noise)

	var wipe := Rect2(box.position.x, box.end.y - 46.0, box.size.x, 40.0)
	var wipe_shape := GraphicCut.lean(wipe, 0.22)
	backplate(wipe_shape, 0.03, Vector2(6.0, 6.0), void_color(), noise)
	paint(wipe_shape, peril(), noise)
	say(
		"기록 버리기",
		Vector2(wipe.position.x, wipe.get_center().y + 6.0),
		17,
		ink(peril()),
		noise,
		wipe.size.x,
		HORIZONTAL_ALIGNMENT_CENTER
	)


## 강조 — **화면에서 노이즈 0.00 인 곳.** 팝업이 열리면 이 자리를 내준다.
##
## idle 에서 **한 픽셀도 안 움직인다.** 다른 것이 전부 떠는 화면에서 안 떠는 것 하나는
## 그 자체로 신호다 — 움직여서 눈을 끄는 것보다 세다.
func _mark() -> void:
	var noise := _noise(Grain.HERE)
	var box := Rect2(PAD, MARK_TOP, CARD.x - PAD * 2.0, MARK_TALL)
	say("강조 — 지금 여기", Vector2(PAD, MARK_TOP - 10.0), 13, Color(paper(), 0.6), _noise(Grain.LIVE))
	# **뾰족한 끝.** 「지금 여기」는 판 중에 혼자 다른 도형이다.
	var shape := GraphicCut.fang(Rect2(box.position, box.size - Vector2(26.0, 0.0)), 26.0)
	backplate(shape, 0.012, Vector2(9.0, 9.0), paper(), noise)
	paint(shape, accent(), noise)
	say(
		"3층 봉인된 문",
		Vector2(box.position.x, box.get_center().y + 9.0),
		24,
		ink(accent()),
		noise,
		box.size.x,
		HORIZONTAL_ALIGNMENT_CENTER
	)


## 팝업 — 열리면 **초점이 여기로 넘어온다.** 나머지가 한 칸 시끄러워지는 것이 가림막이다.
func _popup() -> void:
	var force := _pop_force()
	if force <= 0.0:
		return
	# 열리는 동안은 아직 초점이 안 맞았다. **또렷해지는 것 자체가 등장이다.**
	var noise := lerpf(Grain.LIVE, Grain.HERE, force)
	# 팝업은 **미끄러져 와서 탁 선다.** 스냅이 이 문법의 절반이다.
	var slid := POPUP.position + Vector2(0.0, 26.0 * (1.0 - force))
	var shape := GraphicCut.clipped(Rect2(slid, POPUP.size), 22.0, 1 | 4)
	backplate(shape, 0.014, Vector2(10.0, 10.0), back(), noise)
	paint(shape, paper(), noise)
	say(
		"기록을 버릴까",
		Vector2(slid.x, slid.y + 58.0),
		22,
		ink(paper()),
		noise,
		POPUP.size.x,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	say(
		"되돌릴 수 없다",
		Vector2(slid.x, slid.y + 88.0),
		14,
		Color(ink(paper()), 0.7),
		noise,
		POPUP.size.x,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	var wide := (POPUP.size.x - 48.0) * 0.5
	var yes := Rect2(slid.x + 16.0, slid.y + POPUP.size.y - 56.0, wide, 40.0)
	var no := Rect2(yes.end.x + 16.0, yes.position.y, wide, 40.0)
	var yes_shape := GraphicCut.lean(yes, 0.22)
	backplate(yes_shape, 0.03, Vector2(5.0, 5.0), void_color(), noise)
	paint(yes_shape, peril(), noise)
	say(
		"버린다",
		Vector2(yes.position.x, yes.get_center().y + 6.0),
		17,
		ink(peril()),
		noise,
		yes.size.x,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	paint(GraphicCut.lean(no, 0.22), Color(void_color(), 0.5), noise)
	say(
		"둔다",
		Vector2(no.position.x, no.get_center().y + 6.0),
		17,
		paper(),
		noise,
		no.size.x,
		HORIZONTAL_ALIGNMENT_CENTER
	)
