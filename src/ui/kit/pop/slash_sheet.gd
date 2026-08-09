class_name SlashSheet
extends Control
## **참격 — 사선이 화면을 지배한다.** 부품 한 벌을 P5 계열 문법으로.
##
## docs/design/20-ui-kit.md §20.28.
##
##     godot --path . -s res://tools/capture_pop.gd -- .renders/pop-slash slash
##
## ## 물질을 흉내 내지 않는다
##
## 앞의 판들은 전부 **「이 UI 는 무슨 물질인가」**를 물었다 — 돌 · 금박 · 신문지 · 쇳물.
## 그게 기각당한 이유다. 여기서는 **그래픽 디자인으로 승부한다.**
##
## | 문법 | 여기서 |
## | --- | --- |
## | 판이 직사각형이 아니다 | 전부 평행사변형이거나 모서리가 잘렸다 |
## | 판이 여러 겹 겹친다 | 뒤판이 어긋나 삐져나온다 (그림자가 아니라 **판 한 겹 더**) |
## | 글자가 도형이다 | 제목이 기울고 판에 잘리고 판 밖으로 넘친다 |
## | 색이 적은데 세다 | 바탕 · 미색에 **포인트 셋** — 신호 · 고름 · 험 (§20.32) |
## | 무늬가 그래픽 | 사선 줄무늬와 망점이 **평평하게** 깔리고 흐른다 |
## | 움직임이 스냅 | 미끄러져 들어와 **탁 멈춘다.** 느리게 빛나지 않는다 |
##
## **입자도 아지랑이도 없다.**

const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")
const DARK := preload("res://src/ui/kit/cel/phosphor_dark.gdshader")
const LIT := preload("res://src/ui/kit/cel/phosphor_lit.gdshader")

const CARD := Vector2(660.0, 760.0)
const LOOP := 6.4
const PAD := 26.0
const GAP := 14.0

const SNAP := 0.34

## 목록 일곱 줄. **넷으로는 강조 방법을 못 가른다** — 네 줄은 강조가 없어도 한눈에
## 다 들어와서 어느 방법이든 다 된다. 일곱 줄부터 훑기가 시작된다 (§20.39.4).
const ROWS: Array[String] = ["출격", "길드", "인물", "설정", "기록", "상점", "종료"]

## 강조 방법 셋. 순서가 곧 칸 순서다.
const WAYS: Array[String] = ["면 — 색으로 채운다", "자리 — 밀려 나간다", "여백 — 둘레가 빈다"]

## 손이 올라가는 때 · 선택이 옮겨가는 때 (§20.39.5).
##
## **되돌아오는 것까지 한 바퀴 안에 있다.** 안 넣으면 매 바퀴 끝에서 선택이 튀고,
## 그 튐이 화면에서 가장 큰 움직임이 되어 판정을 망친다.
const HOVER_UP := 1.60
const MOVE_AT := 2.50
const HOVER_OVER := 3.30
const HOVER_DOWN := 4.40
const MOVE_BACK := 5.30

## 처음 고른 줄과 옮겨 간 줄, 그리고 손만 따로 옮겨 가는 줄.
const ROW_FIRST := 1
const ROW_NEXT := 4
const ROW_ASIDE := 6

const BOARD_TOP := 384.0
const BOARD_TALL := 238.0

## 줄 사이 간격과 줄 높이.
const ROW_PITCH := 30.0
const ROW_TALL := 26.0

## **화면을 가로지르는 벤 자국 한 줄.**
##
## 「참격」이 지금까지 **무늬**였다 — 사선 줄무늬와 기울어진 판. 이 한 줄은
## 걸린 판을 **실제로 가른다.** 판마다 자기 가운데를 여는 것이 아니라
## **한 줄이 판들을 건너 이어진다.**
##
## 각도와 지나는 점을 **손으로 안 고른다** — 판의 **왼아래에서 오른위로 가는 대각선**이고
## **판의 한가운데**를 지난다. 손으로 고르면 화면마다 다시 맞춰야 하고, 맞추다 보면
## 큰 판의 모서리를 얕게 스치는 각도에 앉는다(§20.33.3). 대각선은 **판을 가로질러 지나가서**
## 걸리는 것을 깊게 벤다.
const RIP_APART := 10.0

## 떨어져 나온 조각이 판의 이 비율보다 작으면 **안 베고 밀린다.**
##
## 0.12 로 시작했더니 **벨 만한 판까지 밀어냈다** — 강조 띠가 7% 짜리 조각을 내는데
## 그건 충분히 깊고 잘 보이는 자국이었다. 문턱은 **「그리다 만 것으로 보이는 크기」**여야지
## 「작은 크기」가 아니다. 5% 아래만 밀어낸다.
const RIP_LEAST := 0.05

## 베는 순간. 판이 다 들어와 선 직후에 **한 번에** 지나간다.
const RIP_AT := 0.78

## 앞판이 뒤판에서 잘라 내는 여유. **이 빈 줄 하나가 「판이 두 장」이라고 말한다.**
const BLEED := 3.0

## 색은 **`HoloPalette` 한 곳에서만** 정해진다 (§20.31). 화면은 번호만 든다 —
## 색만 바꿔 여러 장을 찍으려면 바꾸는 자리가 한 줄이어야 한다.
var palette := 0:
	set(value):
		palette = wrapi(value, 0, HoloPalette.count())
		_tint_screen()
		queue_redraw()

## **벤 자국을 화면에 낼 것인가.** 기본은 아니다 (§20.38).
##
## 자국 하나가 걸린 판을 전부 어긋내는데, 그 대가가 **화면의 모든 줄맞춤**이다.
## 정렬은 UI 가 공짜로 주는 가장 센 신호고, 전부 어긋나면 어긋남이 배경이 된다.
## 코드는 남긴다 — **한 부품에서 한 번 쓰는 연출**로는 값이 있고, 켜는 것이 한 줄이라야
## 다시 견줘 볼 수 있다.
var rip_shown := false:
	set(value):
		rip_shown = value
		queue_redraw()

var _clock := 0.0
var _driven := false
var _dark: ColorRect
var _lit: ColorRect


func _ready() -> void:
	# 브라운관 덮개 둘. **곱하기 층과 더하기 층이라 어둡게도 밝게도 한다** (§20.29.2).
	_dark = _screen_layer(DARK)
	_lit = _screen_layer(LIT)
	_tint_screen()
	set_process(not _driven)


## 덮개의 인광색을 팔레트에 맞춘다. **방의 빛이지 신호가 아니라서** 강조색을 안 쓴다 —
## 화면 전체를 훑는 띠가 신호색이면 「지금 여기」가 매초 화면을 가로지른다.
func _tint_screen() -> void:
	if _lit == null:
		return
	(_lit.material as ShaderMaterial).set_shader_parameter("glow", HoloPalette.glow(palette))


func _void() -> Color:
	return HoloPalette.void_color(palette)


func _paper() -> Color:
	return HoloPalette.paper(palette)


## **신호.** 이 함수를 부르는 곳은 `_here()` **하나뿐이어야 한다** (§20.32).
func _accent() -> Color:
	return HoloPalette.accent(palette)


## **고름** — 켜짐 · 선택 · 값. 신호가 아니라 구분이다.
func _pick() -> Color:
	return HoloPalette.pick(palette)


## **험** — 되돌릴 수 없는 것.
func _peril() -> Color:
	return HoloPalette.peril(palette)


## 어긋난 뒤판의 색. **고름의 짙은 쪽**이라 어긋남이 색으로도 읽힌다.
func _back() -> Color:
	return HoloPalette.back(palette)


## 그 면 위의 글자색. 면이 밝으면 어둡게, 어두우면 밝게 — **화면이 눈으로 안 고른다.**
func _ink(surface: Color) -> Color:
	return HoloPalette.ink(palette, surface)


func _screen_layer(source: Shader) -> ColorRect:
	var layer := ColorRect.new()
	layer.color = Color.WHITE
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stuff := ShaderMaterial.new()
	stuff.shader = source
	stuff.set_shader_parameter("card", CARD)
	layer.material = stuff
	add_child(layer)
	layer.size = CARD
	return layer


func drive_externally() -> void:
	_driven = true
	set_process(false)


func _process(delta: float) -> void:
	set_clock(fposmod(_clock + delta, LOOP))


func set_clock(t: float) -> void:
	_clock = t
	for layer in [_dark, _lit]:
		if layer != null:
			(layer.material as ShaderMaterial).set_shader_parameter("clock", t)
	queue_redraw()


## 판이 **위에서부터 한 줄씩 그려진다.** 다 그려지면 원래 판 그대로다.
##
## 「호박」에서 만든 표시 방법을 그대로 가져왔다 — 형태는 안 건드린다.
## 이제 **등장**이 아니라 **선택이 옮겨간 자리**를 채우는 데 쓴다 (§20.39.6):
## 색이 켜지고 꺼지는 것만으로는 어디서 어디로 갔는지가 안 남는다.
##
## `GraphicCut.revealed` 가 받는 것은 비율이 아니라 **픽셀**이라 높이를 곱해 넘긴다.
func _drawn_in(shape: PackedVector2Array, upto: float) -> Array[PackedVector2Array]:
	if upto >= 1.0:
		return [shape] as Array[PackedVector2Array]
	return GraphicCut.revealed(shape, GraphicCut.span_of(shape).size.y * upto)


## 지금 벤 자국이 얼마나 벌어져 있나. 스냅으로 **한 번에** 벌어지고 그대로 있는다.
func _rip() -> float:
	return _snap(RIP_AT, 0.12) * RIP_APART


## 벤 자국의 각도. **판의 왼아래에서 오른위로 가는 대각선**이다.
func _rip_angle() -> float:
	return atan2(-size.y, size.x)


## 벤 자국이 지나는 점. **판의 한가운데.**
func _rip_through() -> Vector2:
	return size * 0.5


## 판 하나를 그린다. **벤 자국에 걸리면 두 조각이 되어 어긋난다.**
##
## 판을 칠하는 모든 자리가 이 함수를 지나간다 — 한 군데라도 빠지면 그 판만
## 자국을 안 맞은 것이 되고, 그러면 자국이 **한 줄로 안 이어져** 그냥 깨진 판이 된다.
## 다각형 하나를 칠한다. **꼭짓점이 셋 미만이거나 넓이가 없으면 안 그린다.**
##
## 자르는 것을 세 겹(찢어 열기 → 베기 → 초승달 파내기) 쌓으면 중간에 반드시
## **넓이 0 짜리 조각**이 나온다 — 팝업이 열리기 시작하는 한두 편이 그렇다.
## 그것을 그대로 넘기면 `canvas_item_add_polygon` 이 *"triangulation failed"* 로 운다.
## 이 저장소는 경고를 오류로 치므로 **거르는 자리가 하나 있어야 한다.**
func _paint(shape: PackedVector2Array, tint: Color) -> void:
	if shape.size() < 3 or GraphicCut.area_of(shape) < 0.05:
		return
	draw_colored_polygon(shape, tint)


func _plate(shape: PackedVector2Array, tint: Color, least: float = RIP_LEAST) -> void:
	if not rip_shown:
		_paint(shape, tint)
		return
	for piece in GraphicCut.severed(shape, _rip_angle(), _rip_through(), _rip(), least):
		_paint(piece, tint)


## 판 **안에** 깔리는 것 — 무늬 한 줄 · 뒤판 초승달 — 은 **판의 판정을 따라간다.**
##
## 각자 판정하게 두면 안 된다. 얇은 무늬 한 줄은 「얕게 걸렸다」가 거의 늘 참이라
## **판은 베였는데 무늬는 통째로 밀려** 벌어진 틈 위를 가로지른다. 반대도 난다 —
## 판이 밀렸는데 무늬만 베이면 있지도 않은 틈에 무늬가 갈라져 있다.
##
## **문턱은 판의 성질이지 그 위에 깔리는 것의 성질이 아니다.**
func _follow(panel: PackedVector2Array, piece: PackedVector2Array, tint: Color) -> void:
	if not rip_shown:
		_paint(piece, tint)
		return
	var push := GraphicCut.shove(panel, _rip_angle(), _rip_through(), _rip(), RIP_LEAST)
	if push == Vector2.ZERO:
		_plate(piece, tint, 0.0)
		return
	_paint(GraphicCut.swelled(piece, 0.0, push), tint)


## 어긋난 **뒤판.** 앞판이 덮을 자리를 **잘라 내고** 초승달만 남긴다.
##
## 덮어서 안 보이는 것과 잘려서 없는 것은 화면에서 똑같아 보이지만 **가장자리가 다르다.**
## 잘라 내면 앞판과 뒤판 사이에 `BLEED` 만큼의 빈 줄이 생기고, 그 줄 하나가
## 「이건 그림자가 아니라 판이 두 장」이라고 말한다 — 겹쳐 두면 아무 말도 안 한다.
func _backplate(front: PackedVector2Array, by: float, at: Vector2, tint: Color) -> void:
	for crescent in GraphicCut.notched(GraphicCut.swelled(front, by, at), front, BLEED):
		_follow(front, crescent, tint)


## 글자의 윤곽을 **다각형으로** 받아 자리에 앉힌다. `draw_set_transform` 을 안 쓰는 이유는
## 벤 자국이 **판 좌표**에서 계산되기 때문이다 — 변환을 걸어 둔 채로 넘기면 자국이
## 글자에만 딴 데서 지나간다. 자리와 기울기를 **점에 미리 발라** 넘긴다.
func _glyphs(text: String, seat: Vector2, lean: float, tall: int) -> Dictionary:
	var made := GlyphShape.of(text, FONT, tall, Vector2.ZERO)
	var pose := Transform2D(lean, seat)
	var out := {"solid": [] as Array[PackedVector2Array], "hole": [] as Array[PackedVector2Array]}
	for key: String in ["solid", "hole"]:
		var bag: Array[PackedVector2Array] = out[key]
		for ring: PackedVector2Array in made[key]:
			var moved := PackedVector2Array()
			for point in ring:
				moved.append(pose * point)
			bag.append(moved)
	return out


## 글자 획 하나를 **판 안팎으로 갈라** 칠한다. 안은 `within`, 밖은 `beyond`.
##
## 판 위에서 `within` 이 바탕색이면 **구멍**이 되고, 뚫린 자리에 바탕과 똑같은 줄무늬를
## 깔아 뒤가 이어져 보이게 한다. 판 밖에서는 `beyond` 가 미색이라 글자가 **판**이 된다.
func _pierce(
	slab: PackedVector2Array, ring: PackedVector2Array, within: Color, beyond: Color
) -> void:
	for inside in Geometry2D.intersect_polygons(ring, slab):
		_follow(slab, inside, within)
		if within == _void():
			for bar in GraphicCut.stripes(inside, -PI * 0.28, 46.0, 15.0, _clock * 34.0):
				_follow(slab, bar, Color(_paper(), 0.045))
	for outside in Geometry2D.clip_polygons(ring, slab):
		_follow(slab, outside, beyond)


## 채워진 판 위의 **주사선.** 망점이 있던 자리다 — 무늬만 바뀌고 판은 그대로다.
##
## 줄의 색을 부르는 쪽이 정하지 않는다. **면이 어두워지면 주사선은 밝아져야** 하고,
## 색을 갈아 끼울 때 그 뒤집힘을 화면 코드가 일곱 군데에서 따로 기억할 수 없다.
func _scanlines(shape: PackedVector2Array, surface: Color, force: float) -> void:
	var tint := Color(_ink(surface), force)
	for bar in GraphicCut.stripes(shape, 0.0, 4.0, 1.6, _clock * 9.0):
		_follow(shape, bar, tint)


## 모서리 꺾쇠와 작은 눈금. **큰 판 가장자리에 붙는 장식**이지 판을 대신하지 않는다.
##
## 포인트 색 셋 중 **아무것도 안 쓴다** (§20.32). 장식이 신호색을 입는 순간
## 화면에 「지금 여기」가 다섯 개가 된다 — 앞 판이 정확히 그렇게 죽었다.
func _rig(box: Rect2, slot: int) -> void:
	var reach := 13.0
	var trim := Color(_paper(), 0.42)
	var corners := [
		[box.position, Vector2(1, 0), Vector2(0, 1)],
		[Vector2(box.end.x, box.position.y), Vector2(-1, 0), Vector2(0, 1)],
		[box.end, Vector2(-1, 0), Vector2(0, -1)],
		[Vector2(box.position.x, box.end.y), Vector2(1, 0), Vector2(0, -1)],
	]
	for corner in corners:
		var at: Vector2 = corner[0]
		draw_line(at, at + (corner[1] as Vector2) * reach, trim, 2.0)
		draw_line(at, at + (corner[2] as Vector2) * reach, trim, 2.0)
	for i in 9:
		var x := lerpf(box.position.x + 16.0, box.end.x - 16.0, float(i) / 8.0)
		var wobble := CelReadout.tick_jitter(slot + i, _clock, 0.6)
		draw_line(
			Vector2(x, box.end.y + 4.0),
			Vector2(x, box.end.y + 8.0 + wobble),
			Color(_paper(), 0.3),
			1.0
		)
	draw_string(
		FONT,
		Vector2(box.position.x + 2.0, box.position.y - 5.0),
		"%s %s" % [CelReadout.noise_hex(slot, _clock), CelReadout.noise_digits(slot, _clock, 3)],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		9,
		Color(_paper(), 0.42)
	)


## 스냅. **끝에서 살짝 넘겼다가 탁 선다** — 부드럽게 도착하면 P5 가 아니다.
func _snap(from: float, span: float = SNAP) -> float:
	var t := clampf((_clock - from) / span, 0.0, 1.0)
	if t >= 1.0:
		return 1.0
	var eased := 1.0 - pow(1.0 - t, 4.0)
	return eased + sin(t * PI) * 0.06


## 짧게 튀는 어긋남. **글리치는 길면 고장이고 짧으면 문법이다.**
func _jolt(at: float, span: float = 0.10) -> float:
	if _clock < at or _clock > at + span:
		return 0.0
	return 1.0 - (_clock - at) / span


## 지금 고른 줄. 두 번 옮겨 가고 **제자리로 돌아온다** — 그래야 GIF 가 이어 붙는다.
func _marked_row() -> int:
	if _clock >= MOVE_AT and _clock < MOVE_BACK:
		return ROW_NEXT
	return ROW_FIRST


## 지금 손이 올라간 줄. 없으면 -1.
##
## 3.3 초에 손만 따로 옮겨 간다 — **고른 것과 올린 것이 한 화면에 나란히** 있어야
## 「같은 축의 반」이 구분되는지 볼 수 있다.
func _hovered_row() -> int:
	if _clock < HOVER_UP or _clock >= HOVER_DOWN:
		return -1
	return ROW_NEXT if _clock < HOVER_OVER else ROW_ASIDE


## 손이 얼마나 올라와 있나 0..1. 올라올 때도 내려갈 때도 스냅이다.
func _hover_force() -> float:
	if _clock < HOVER_UP or _clock >= HOVER_DOWN + 0.16:
		return 0.0
	if _clock >= HOVER_DOWN:
		return 1.0 - _snap(HOVER_DOWN, 0.16)
	return _snap(HOVER_UP, 0.14)


## 선택이 옮겨간 지 얼마나 됐나 0..1. 두 번의 이동이 같은 값을 쓴다.
func _mark_force() -> float:
	if _clock < MOVE_AT:
		return 1.0
	if _clock < MOVE_BACK:
		return _snap(MOVE_AT, 0.16)
	return _snap(MOVE_BACK, 0.16)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _void(), true)
	_backdrop()
	_title()
	_buttons()
	_window()
	_boards()
	_here()
	_weak()


## 바탕 — **평평한 사선 줄무늬가 화면 전체를 흐른다.** 재질이 아니라 무늬다.
##
## ## 훑는 띠는 **판 뒤로만** 지나간다 (§20.39.2)
##
## 이 띠가 idle 에서 가장 크게 움직이는 것이라 자리가 중요하다. 판 **위로** 지나가면
## 지나가는 동안 그 판이 밝아지고, 밝아진 판이 곧 「지금 여기」다 —
## **매초 화면을 가로지르는 가짜 신호**가 생긴다. 그래서 여기서만 그린다.
##
## 판 뒤라서 실루엣을 하나도 안 바꾼다. 실루엣이 안 바뀌면 주변시가 「변화 없음」으로
## 처리한다 — **느리게 하는 것이 아니라 무엇을 안 바꾸느냐가 기준이다.**
func _backdrop() -> void:
	var whole := PackedVector2Array(
		[Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]
	)
	# 바탕 줄무늬도 `_paint` 를 지나간다. 한 바퀴가 길어지자 위상이 어느 값일 때
	# **가장자리에서 넓이 0 짜리 조각**이 나왔고 그대로 `triangulation failed` 가 났다 —
	# 정지 컷에서는 한 번도 안 나고 편을 다 뽑아야 난다 (§20.36.1 과 같은 함정).
	for bar in GraphicCut.stripes(whole, -PI * 0.28, 46.0, 15.0, _clock * 34.0):
		_paint(bar, Color(_paper(), 0.045))
	# 굵은 사선 한 줄이 화면을 가로지른다. 이 안의 서명이다.
	var sweep := fposmod(_clock * 0.14, 1.0)
	var band := GraphicCut.lean(
		Rect2(-260.0 + sweep * (size.x + 520.0), -40.0, 90.0, size.y + 80.0), 0.42
	)
	# 바탕의 띠는 신호색이 아니다 — 화면을 가로지르는 것이 「지금 여기」면 안 된다.
	_paint(band, Color(_pick(), 0.10))


## 제목 — **글자가 판을 뚫는다.** 그리고 판 밖으로 나가면 **뒤집힌다.**
##
## §20.28 부터 「글자가 도형이다」라고 적어 놓고 실제로는 **도형처럼 다뤘을 뿐**이었다 —
## 기울이고 걸치고 두 번 찍었지 글자는 끝까지 `draw_string` 이었다. 윤곽선을 다각형으로
## 받으면(`GlyphShape`) 글자에 **판에 하는 짓을 그대로** 할 수 있다.
##
## | 글자가 있는 자리 | 무엇인가 |
## | --- | --- |
## | 판 **위** | **구멍이다.** 판이 없어서 뒤의 줄무늬가 그대로 이어져 보인다 |
## | 판 **밖** | **판이다.** 미색으로 차서 바탕 위에 뜬다 |
##
## 뚫린 자리에 까는 줄무늬는 바탕과 **각도 · 간격 · 위상이 같아야** 한다.
## 하나라도 다르면 구멍이 아니라 **무늬를 칠한 글자**가 된다.
##
## ## 뒤집힘은 내렸다 (§20.38.2)
##
## §20.37.2 는 뒤집힘을 보려고 판을 글자보다 **짧게** 잡았다. 그러면 「격」이 반쪽씩
## 다른 색이 되어 **글자로 안 뭉친다.** 판정 기준이 「읽히나」라서 그 경계를 없앴다 —
## 판이 글자를 다 담고 획은 전부 **구멍**이다. `_pierce` 는 그대로 두므로 `beyond`
## 가지가 안 돌 뿐이고, 획 하나만 넘는 자리가 생기면 그때는 다시 값이 있다.
func _title() -> void:
	var slab := GraphicCut.lean(Rect2(-30.0, 8.0, 190.0, 84.0), 0.30)
	_backplate(slab, 0.012, Vector2(7.0, 7.0), _back())
	_plate(slab, _paper())
	var mark := _glyphs("참격", Vector2(22.0, 82.0), -0.075, 64)
	for ring: PackedVector2Array in mark["solid"]:
		_pierce(slab, ring, _void(), _paper())
	for ring: PackedVector2Array in mark["hole"]:
		_pierce(slab, ring, _paper(), _void())
	draw_string(
		FONT,
		Vector2(PAD, 108.0),
		"베고 지나간 자리. 멈추지 않는다",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		Color(_paper(), 0.66)
	)


## 버튼 넷 — 기본 · 올림 · 눌림 · 비활성. 전부 평행사변형이다.
##
## **이제 범례다.** 시간에 따라 켜지지 않고 네 상태가 늘 그대로 서 있다 —
## 가만히 있는 것을 재는 판에서 버튼이 혼자 깜빡이면 그것부터 보게 된다 (§20.39.5).
func _buttons() -> void:
	var labels := ["기본", "올림", "눌림", "비활성"]
	var wide := (size.x - PAD * 2.0 - 30.0) / 4.0
	for i in 4:
		var box := Rect2(PAD + float(i) * (wide + 10.0), 132.0, wide, 50.0)
		var shape := GraphicCut.lean(box, 0.24)
		var hot := i == 1
		var down := i == 2
		if down:
			shape = GraphicCut.swelled(shape, -0.03, Vector2(4.0, 4.0))

		# 뒤판 — **그림자가 아니라 판 한 겹 더**라서 어긋나 있고 색이 있다.
		if i != 3:
			_backplate(shape, 0.02, Vector2(8.0, 8.0), _back() if not down else _paper())
		# 「올림」은 **고름**이다. 켜진 것이지 「지금 여기」가 아니다.
		var face := _pick() if hot else _paper()
		_plate(shape, face)
		if i == 3:
			for bar in GraphicCut.stripes(shape, -PI * 0.25, 9.0, 4.0, 0.0):
				_follow(shape, bar, Color(_void(), 0.55))
		if hot:
			_scanlines(shape, face, 0.22)
		_shape_text(labels[i], Rect2(box.position, box.size), 18, face, 0.35 if i == 3 else 1.0)


## 창 — 제목줄 · 테두리 · 닫기 · 배경. **모서리 둘이 잘렸다.**
##
## **서 있는 상태로 시작한다.** 미끄러져 들어오지도, 한 줄씩 그려지지도 않는다 —
## 등장은 `.renders/50-slash.gif` 에 이미 있고 이 판은 **선 뒤**를 재는 판이다 (§20.39.1).
func _window() -> void:
	var box := Rect2(PAD, 206.0, size.x - PAD * 2.0, 134.0)
	var shape := GraphicCut.clipped(box, 26.0, 2 | 8)
	# 뒤판이 **반투명해졌다** — 판 뒤에 다른 판이 비친다.
	_backplate(shape, 0.014, Vector2(9.0, 9.0), Color(_back(), 0.55))
	_plate(shape, _paper())
	_scanlines(shape, _paper(), 0.10)
	_rig(box, 2)

	var bar := GraphicCut.lean(Rect2(box.position.x, box.position.y, box.size.x - 26.0, 34.0), 0.0)
	_plate(bar, _void())
	draw_string(
		FONT, box.position + Vector2(14.0, 24.0), "창", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, _paper()
	)
	# 닫기는 **험**이다. 창에서 되돌릴 수 없는 것은 이것 하나뿐이라 여기만 그 색이다.
	var shut := Vector2(box.end.x - 46.0, box.position.y + 17.0)
	draw_line(shut + Vector2(-6, -6), shut + Vector2(6, 6), _peril(), 2.8)
	draw_line(shut + Vector2(-6, 6), shut + Vector2(6, -6), _peril(), 2.8)
	for row in 3:
		_plate(
			GraphicCut.lean(
				Rect2(
					box.position.x + 16.0,
					box.position.y + 58.0 + float(row) * 24.0,
					box.size.x - 40.0 - float(row) * 58.0,
					9.0
				),
				0.5
			),
			Color(_void(), 0.72 - float(row) * 0.18)
		)


## 강조 세 칸 — **같은 일곱 줄 · 같은 선택 · 같은 시각**으로 방법만 다르다 (§20.39.3).
##
## 셋을 같은 사건에 묶어 두지 않으면 비교가 아니라 그림 셋이다. 그래서 고른 줄과
## 올린 줄과 옮겨 가는 시각은 전부 `_marked_row()` · `_hovered_row()` 한 곳에서 나온다.
##
## **올림은 선택과 같은 축의 절반**이다. 축을 따로 쓰면(선택은 색, 올림은 테두리)
## 둘이 안 겹쳐 보이지만 **규칙이 둘**이 되고, 목록이 길면 매번 다시 배워야 한다.
func _boards() -> void:
	var wide := (size.x - PAD * 2.0 - GAP * 2.0) / 3.0
	var corners := [1, 2, 4]
	for col in 3:
		var box := Rect2(PAD + float(col) * (wide + GAP), BOARD_TOP, wide, BOARD_TALL)
		_plate(GraphicCut.clipped(box, 20.0, corners[col] as int), Color(_paper(), 0.10))
		draw_string(
			FONT,
			Vector2(box.position.x + 2.0, box.position.y - 8.0),
			WAYS[col],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			Color(_paper(), 0.55)
		)
		match col:
			0:
				_rows_face(box)
			1:
				_rows_place(box)
			_:
				_rows_air(box)


func _row_box(box: Rect2, i: int, lift: float) -> Rect2:
	return Rect2(
		box.position.x + 10.0,
		box.position.y + 14.0 + float(i) * ROW_PITCH + lift,
		box.size.x - 20.0,
		ROW_TALL
	)


func _row_text(row: Rect2, i: int, tint: Color, indent: float = 18.0) -> void:
	draw_string(
		FONT, row.position + Vector2(indent, 19.0), ROWS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, tint
	)


## **면** — 고름색으로 꽉 찬다. 지금까지 써 온 방법이다.
##
## 채워지는 것이 **한 줄씩 그려져** 들어온다(§20.28 의 표시 방법). 색이 켜지고 꺼지는
## 것만으로는 **어디서 어디로 갔는지가 안 남아서**, 방향을 그만큼이라도 준다.
##
## 가만히 있을 때 주사선이 흐르는 것도 여기뿐이다 — **무늬를 얹을 면이 있어야
## idle 이 걸린다** (§20.39.6).
func _rows_face(box: Rect2) -> void:
	var mark := _marked_row()
	var over := _hovered_row()
	for i in ROWS.size():
		var row := _row_box(box, i, 0.0)
		var shape := GraphicCut.lean(row, 0.20)
		if i == mark:
			_backplate(shape, 0.03, Vector2(5.0, 5.0), _void())
			for piece in _drawn_in(shape, _mark_force()):
				_paint(piece, _pick())
			_scanlines(shape, _pick(), 0.18)
			_row_text(row, i, _ink(_pick()))
		elif i == over:
			_plate(shape, Color(_pick(), 0.30 * _hover_force()))
			_row_text(row, i, Color(_paper(), 0.55 + 0.35 * _hover_force()))
		else:
			_row_text(row, i, Color(_paper(), 0.55))


## **자리** — 색을 하나도 안 쓴다. 밀림 · 쐐기 · 어긋난 뒤판뿐이다.
##
## 옮겨 가는 순간이 셋 중 가장 잘 보인다. 대신 **옮겨간 뒤가 가장 약하다** —
## 목록 전체가 이미 기울어 있어서 16px 밀림이 기울기와 섞인다 (§20.39.6).
func _rows_place(box: Rect2) -> void:
	var mark := _marked_row()
	var over := _hovered_row()
	for i in ROWS.size():
		var shift := 0.0
		if i == mark:
			shift = 18.0 * _mark_force()
		elif i == over:
			shift = 7.0 * _hover_force()
		var row := _row_box(box, i, 0.0)
		row.position.x += shift
		row.size.x -= shift
		var shape := GraphicCut.lean(row, 0.20)
		if i == mark:
			# 뒤판을 **왼아래로** 어긋낸다. 밀린 쪽 반대라서 밀림이 두 번 읽힌다 —
			# 줄이 오른쪽으로 나갔고 뒤에 있던 판이 그만큼 드러났다.
			_backplate(shape, 0.0, Vector2(-11.0, 5.0) * _mark_force(), _back())
			_plate(shape, Color(_paper(), 0.14))
			var wedge := Rect2(row.position - Vector2(15.0, 0.0), Vector2(9.0, row.size.y))
			_plate(GraphicCut.fang(wedge, 7.0), _paper())
			_row_text(row, i, _paper())
		elif i == over:
			_plate(shape, Color(_paper(), 0.05 * _hover_force()))
			_row_text(row, i, Color(_paper(), 0.55 + 0.35 * _hover_force()))
		else:
			_row_text(row, i, Color(_paper(), 0.55))


## **여백** — 고른 줄엔 장식이 하나도 없다. **나머지가 어두워지고 물러나는 것**이 강조다.
##
## 목록이 길수록 세진다 — 여섯 줄을 어둡게 깔면 남은 한 줄이 혼자 뜬다. 다만
## **어두워진 여섯 줄을 읽을 수 없어서**, 고를 것을 아직 찾는 중이면 손해다 (§20.39.6).
func _rows_air(box: Rect2) -> void:
	var mark := _marked_row()
	var over := _hovered_row()
	var air := 7.0 * _mark_force()
	for i in ROWS.size():
		var lift := 0.0
		if i < mark:
			lift = -air
		elif i > mark:
			lift = air
		var row := _row_box(box, i, lift)
		if i == mark:
			_row_text(row, i, _paper())
			continue
		var veil := 0.62 * _mark_force()
		if i == over:
			# **반만 걷는다.** 다 걷으면 올린 줄이 고른 줄과 똑같아 보인다 —
			# 처음에 다 걷었다가 정지 컷에서 둘을 구분 못 해 알았다.
			veil *= 1.0 - 0.5 * _hover_force()
		_plate(GraphicCut.lean(row, 0.20), Color(_void(), veil))
		_row_text(row, i, Color(_paper(), 0.86 - 0.40 * (veil / 0.62)))


## 강조 — **화면 하나에 「지금 여기」는 하나다.** 세 칸의 고름과 다른 층이다.
##
## 아래 세 칸이 가르는 것은 **목록 안에서** 무엇이 골라져 있나(고름)고,
## 이 띠는 **화면 전체가 지금 어디에 있나**(신호)다. 층이 달라서 같이 켜져 있어도
## 「지금 여기」가 둘이 되지 않는다 — 둘이 같은 층이면 하나를 꺼야 한다 (§20.35.1).
##
## 여기가 가만히 있을 때 흐르는 주사선과 떨리는 눈금이 이 판의 idle 이다.
func _here() -> void:
	var box := Rect2(PAD, 650.0, size.x - PAD * 2.0, 58.0)
	var shape := GraphicCut.fang(Rect2(box.position, box.size - Vector2(26.0, 0.0)), 26.0)
	_backplate(shape, 0.012, Vector2(9.0, 9.0), _paper())
	# **화면에서 신호색이 나오는 자리는 여기 하나다** (§20.32).
	var face := _accent()
	_plate(shape, face)
	_scanlines(shape, face, 0.18)
	_rig(Rect2(box.position, box.size - Vector2(26.0, 0.0)), 8)
	draw_string(
		FONT,
		# 634 인 이유 — `_rig` 가 판 위 5px 에 숫자열을 찍는다. 같은 x 에서 시작하므로
		# 둘의 y 가 가까우면 글자가 겹쳐 둘 다 못 읽는다.
		Vector2(PAD, 634.0),
		"강조 — 지금 여기",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		Color(_paper(), 0.5)
	)
	_shape_text("3층 봉인된 문", box, 24, face)


func _weak() -> void:
	draw_string(
		FONT,
		Vector2(PAD, size.y - 20.0),
		"약한 곳 — [자리]는 옮겨간 뒤가, [면]은 옮겨가는 순간이 약하다. [여백]은 어두워진 줄을 못 읽는다",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		Color(_paper(), 0.5)
	)


## 글자를 **도형처럼** 얹는다. 살짝 기울고, 어긋난 그림자가 한 겹 있다.
##
## **부르는 쪽은 글자색이 아니라 「무슨 면 위인가」를 준다.** 포인트 색이 셋이 되면서
## 면마다 밝기가 달라졌고, 글자색을 손으로 고르면 어느 팔레트에서 하나가 반드시 묻힌다.
## 어긋난 한 겹도 **글자색의 반대쪽**이라 밝은 면에서든 어두운 면에서든 글자가 선다.
##
## 색 분리(RGB split)는 흉내 내지 않는다 — 잠깐 튀는 어긋남은 포인트 색이 아니라
## **인광색**으로 찍는다. 신호색이 0.1초 동안이라도 다른 자리에서 나오면 안 된다.
func _shape_text(text: String, box: Rect2, tall: int, surface: Color, fade: float = 1.0) -> void:
	# 글리치가 **선택이 옮겨가는 순간에만** 튄다. 아무 때나 튀면 idle 이 아니다 —
	# 가만히 있는 화면에서 0.1초짜리 어긋남은 그 자체로 사건이 된다.
	var jolt := maxf(_jolt(MOVE_AT), _jolt(MOVE_BACK))
	var lean := -0.045
	var seat := Vector2(box.position.x, box.get_center().y + float(tall) * 0.36)
	if jolt > 0.0:
		draw_set_transform(seat + Vector2(-3.0 * jolt, 0.0), lean, Vector2.ONE)
		draw_string(
			FONT,
			Vector2.ZERO,
			text,
			HORIZONTAL_ALIGNMENT_CENTER,
			box.size.x,
			tall,
			Color(HoloPalette.glow(palette), 0.85 * jolt)
		)
	draw_set_transform(seat + Vector2(2.0, 2.0), lean, Vector2.ONE)
	draw_string(
		FONT,
		Vector2.ZERO,
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		box.size.x,
		tall,
		Color(HoloPalette.ink_prop(palette, surface), 0.34 * fade)
	)
	draw_set_transform(seat, lean, Vector2.ONE)
	draw_string(
		FONT,
		Vector2.ZERO,
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		box.size.x,
		tall,
		Color(_ink(surface), fade)
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
