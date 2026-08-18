class_name FieldSheet
extends Control
## **장(場) — 부품들이 서로의 자리를 놓고 협상한 결과가 판의 윤곽이다.**
##
## docs/design/20-ui-kit.md §20.42.
##
##     godot --path . -s res://tools/capture_pop.gd -- .renders/55-field field
##
## ## 「참격」과 무엇이 다른가
##
## | | 참격(§20.28~20.41) | 여기 |
## | --- | --- | --- |
## | 판의 윤곽 | **사람이 정한다** — 평행사변형 · 잘린 모서리 | **이웃과의 협상 결과** |
## | 사이의 빈 줄 | 그린다 | **칸을 줄이고 남은 것** |
## | 강조 | 판을 옮기고 기울인다 | **무게를 키운다 — 이웃이 실제로 양보한다** |
## | 부품을 옮기면 | 그 판만 바뀐다 | **이웃 전부의 윤곽이 바뀐다** |
##
## 마지막 줄이 이 안의 전부다. 자로 그리려면 화면을 통째로 다시 그려야 하고,
## 무게를 조금 바꿀 때마다 또 다시 그려야 한다 — **사람이 할 수 있는 일이 아니다.**
##
## **부품 한 벌은 그대로다.** 제목 · 버튼 넷 · 창 · 팝업 · 목록 · 슬라이더 · 체크 ·
## 험 버튼 · 강조 띠. 바뀐 것은 그것들이 **무슨 모양인가**를 누가 정하느냐다.

## 종류. 그리는 방법과 색이 여기서 갈린다.
enum Kind { SPACER, TITLE, BUTTON, WINDOW, POPUP, ROW, VALUE, PERIL, HERE }

const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")
const DARK := preload("res://src/ui/kit/cel/phosphor_dark.gdshader")
const LIT := preload("res://src/ui/kit/cel/phosphor_lit.gdshader")

const CARD := Vector2(660.0, 760.0)
const LOOP := 6.4
const PAD := 12.0

## 칸을 이만큼 줄인다. **빈 줄의 폭은 이 값의 두 배**다 — 한 군데서 정해지므로
## 화면 전체의 사이가 늘 같다. 사람이 판마다 여백을 정하면 절대 이렇게 안 된다.
const INSET := 5.0

## **장을 세로로 눌러 놓는다.** 거리를 재기 전에 y 를 이만큼 늘렸다가, 칸이 나오면 되돌린다.
##
## 이것을 안 하면 칸이 전부 **동글동글한 조약돌**이 된다 — 거듭제곱 거리가 등방(等方)이라
## 칸의 반지름이 모든 방향에서 같기 때문이다. 조약돌은 UI 가 아니다.
##
## 늘렸다 되돌리는 것은 **평면의 일차변환**이라 볼록성도, 반평면이 직선이라는 것도,
## 「같은 무게끼리 반씩 나눈다」도 그대로 산다. 씨앗마다 다른 비율을 주면 그때는
## 경계가 직선이 아니게 되어 전부 깨진다 — **비율은 화면 전체에 하나만** 있어야 한다.
const ANISO := 2.3

## 목록 일곱 줄. §20.39.4 — 넷으로는 강조 방법을 못 가른다.
const ROWS: Array[String] = ["출격", "길드", "인물", "설정", "기록", "상점", "종료"]

## 시간표는 §20.39.5 그대로다. **같은 사건을 다른 문법으로 그린 것**이라야 비교가 된다.
const HOVER_UP := 1.60
const MOVE_AT := 2.50
const HOVER_OVER := 3.30
const HOVER_DOWN := 4.40
const MOVE_BACK := 5.30
const ROW_FIRST := 1
const ROW_NEXT := 4
const ROW_ASIDE := 6

## 고른 줄이 더 가져가는 무게. **이것 하나가 강조의 전부다.**
##
## 무게 차이는 두 씨앗 사이 거리 `d` 에 대해 경계를 `Δw / 2d` 만큼 민다.
## 줄 간격이 32px(장에서는 73.6)이므로 4000 은 경계를 약 12px 민다 — 고른 줄이 56px 로
## 넓어지고 위아래 이웃이 20px 로 좁아진다. **양보하는 것이 보여야 신호다.**
##
## 6000 은 **너무 컸다.** 경계가 18px 밀리자 아래 이웃의 두 경계가 서로를 지나쳐
## **칸이 통째로 사라졌다** — 목록에서 항목 하나가 없어진 것이다. 무게로 강조할 때의
## 상한은 「보기 싫어지는 값」이 아니라 **이웃이 없어지는 값**이고, 그건 줄 간격의 절반이다.
const ROW_CLAIM := 4000.0

var palette := 0:
	set(value):
		palette = wrapi(value, 0, HoloPalette.count())
		_tint_screen()
		queue_redraw()

var _clock := 0.0
var _driven := false
var _dark: ColorRect
var _lit: ColorRect


func _ready() -> void:
	_dark = _screen_layer(DARK)
	_lit = _screen_layer(LIT)
	_tint_screen()
	set_process(not _driven)


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


func _tint_screen() -> void:
	if _lit == null:
		return
	(_lit.material as ShaderMaterial).set_shader_parameter("glow", HoloPalette.glow(palette))


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


func _void() -> Color:
	return HoloPalette.void_color(palette)


func _paper() -> Color:
	return HoloPalette.paper(palette)


func _ink(surface: Color) -> Color:
	return HoloPalette.ink(palette, surface)


func _snap(from: float, span: float = 0.16) -> float:
	var t := clampf((_clock - from) / span, 0.0, 1.0)
	if t >= 1.0:
		return 1.0
	return 1.0 - pow(1.0 - t, 4.0)


func _marked_row() -> int:
	if _clock >= MOVE_AT and _clock < MOVE_BACK:
		return ROW_NEXT
	return ROW_FIRST


func _hovered_row() -> int:
	if _clock < HOVER_UP or _clock >= HOVER_DOWN:
		return -1
	return ROW_NEXT if _clock < HOVER_OVER else ROW_ASIDE


func _hover_force() -> float:
	if _clock < HOVER_UP or _clock >= HOVER_DOWN + 0.16:
		return 0.0
	if _clock >= HOVER_DOWN:
		return 1.0 - _snap(HOVER_DOWN)
	return _snap(HOVER_UP, 0.14)


func _mark_force() -> float:
	if _clock < MOVE_AT:
		return 1.0
	if _clock < MOVE_BACK:
		return _snap(MOVE_AT)
	return _snap(MOVE_BACK)


## 씨앗 한 벌. **자리와 반지름과 종류와 이름**, 그게 부품이 가진 전부다.
##
## ## 무게는 **반지름의 제곱**이다
##
## 무게 `w` 짜리 씨앗과 무게 0 짜리 씨앗이 거리 `d` 로 있으면 경계가 씨앗에서
## `d/2 + w/2d` 에 선다. 이 값은 `d = sqrt(w)` 에서 **최소 `sqrt(w)`** 다.
## 그래서 **빈칸을 촘촘히 깔아 두면 칸의 반지름이 정확히 `sqrt(w)` 가 된다** —
## 부르는 쪽은 「이 부품은 반지름 40」이라고만 말하면 된다.
##
## 그리고 **같은 무게끼리는 정확히 반씩 나눈다.** 목록의 일곱 줄이 서로 32px 간격으로
## 같은 무게를 가지므로 줄 높이가 16+16 으로 딱 떨어지고, 그 줄만 무게를 올리면
## **위아래 이웃이 그만큼만 양보한다.** 가로로는 빈칸이 정하므로 안 흔들린다 —
## 강조가 세로로만 일어나는 것이 우연이 아니라 **배치가 만든 결과**다.
##
## 빈칸(`SPACER`)은 안 그린다. **여백도 칸 하나**라서, 여백을 만들려면 여백에도
## 씨앗을 줘야 한다 — 여백이 「남는 자리」가 아니라 **자리를 주장하는 것**이 된다.
func _seeded() -> Array:
	var made: Array = []
	made.append([Vector2(110.0, 58.0), 88.0, Kind.TITLE, "참격"])
	var labels := ["기본", "올림", "눌림", "비활성"]
	for i in 4:
		made.append([Vector2(88.0 + float(i) * 146.0, 156.0), 54.0, Kind.BUTTON, labels[i]])
	made.append([Vector2(190.0, 278.0), 148.0, Kind.WINDOW, "창"])
	made.append([Vector2(498.0, 278.0), 116.0, Kind.POPUP, "버릴까요"])

	var mark := _marked_row()
	var over := _hovered_row()
	for i in ROWS.size():
		var claim := 0.0
		if i == mark:
			claim = ROW_CLAIM * _mark_force()
		elif i == over:
			# 올림은 **같은 축의 절반**이다 (§20.39.3). 축이 무게 하나라서 절반이 자명하다.
			claim = ROW_CLAIM * 0.5 * _hover_force()
		var seat := Vector2(150.0, 408.0 + float(i) * 32.0)
		made.append([seat, sqrt(10000.0 + claim), Kind.ROW, ROWS[i]])
	# **안 그리는 줄이 목록의 위아래 끝에 하나씩 있다.** 없으면 첫 줄과 끝 줄만
	# 같은 무게의 이웃이 한쪽에 없어서 바깥으로 부푼다 — 목록이 아니라 물방울이 된다.
	for edge in [376.0, 632.0]:
		made.append([Vector2(150.0, edge), 100.0, Kind.SPACER, ""])

	made.append([Vector2(486.0, 414.0), 82.0, Kind.VALUE, "소리"])
	made.append([Vector2(486.0, 502.0), 74.0, Kind.VALUE, "전체 화면"])
	made.append([Vector2(486.0, 588.0), 80.0, Kind.PERIL, "기록 버리기"])
	made.append([Vector2(300.0, 690.0), 122.0, Kind.HERE, "3층 봉인된 문"])

	# 빈칸 격자. **부품이 이 바탕을 밀어내고 자기 자리를 얻는다** —
	# 격자가 없으면 칸이 화면 끝까지 부풀어 무게가 아무 뜻도 없어진다.
	# 간격은 **장에서** 고르므로 세로로는 화면에서 `104 / ANISO` 만큼이다.
	var step := 104.0
	var x := -26.0
	while x < size.x + 52.0:
		var y := -26.0
		while y < size.y + 52.0:
			made.append([Vector2(x, y), 0.0, Kind.SPACER, ""])
			y += step / ANISO
		x += step
	return made


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _void(), true)
	var parts := _seeded()
	var seeds := PackedVector2Array()
	var weights := PackedFloat32Array()
	for part in parts:
		# 장으로 들어간다 — y 를 늘려 재고, 칸이 나오면 되돌린다.
		var seat := part[0] as Vector2
		seeds.append(Vector2(seat.x, seat.y * ANISO))
		# **부르는 쪽은 반지름을 주고 여기서 한 번만 제곱한다.** 무게로 말하면
		# 값이 픽셀과 안 맞아서 배치를 손볼 때마다 감으로 더듬게 된다.
		var reach := part[1] as float
		weights.append(reach * reach)
	var marked := -1
	var top := 0.0
	for i in parts.size():
		if (parts[i][2] as Kind) != Kind.ROW:
			continue
		if (parts[i][1] as float) > top:
			top = parts[i][1] as float
			marked = i
	var bounds := Rect2(PAD, PAD * ANISO, size.x - PAD * 2.0, (size.y - PAD * 2.0) * ANISO)

	for i in parts.size():
		var kind: Kind = parts[i][2]
		if kind == Kind.SPACER:
			continue
		var cell := _from_field(CellField.cell(seeds, weights, i, bounds))
		if cell.size() < 3:
			continue
		_part(cell, kind, parts[i][3] as String, i == marked)
	_notes()


## 장에서 나온 칸을 화면으로 되돌린다. **되돌리는 자리는 여기 하나뿐이어야 한다** —
## 두 군데가 되면 어느 좌표계의 다각형인지가 화면 코드 전체로 퍼지고 반드시 하나가 틀린다.
func _from_field(cell: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in cell:
		out.append(Vector2(point.x, point.y / ANISO))
	return out


## 칸 하나를 부품으로 만든다. **모양은 이미 정해져 왔고 여기서는 색과 글자만** 얹는다.
##
## 뒤판은 칸을 **덜 줄인 것**을 먼저 깔아 만든다. `notched` 로 파내지 않는 이유는,
## 칸이 매 프레임 다시 계산되어 감는 방향이 한결같지 않고 그때마다 파내기가 통째로
## 빗나가기 때문이다 — 빗나가면 뒤판이 앞판을 **덮어** 부품 색이 사라진다(실제로 났다).
func _part(cell: PackedVector2Array, kind: Kind, label: String, marked: bool) -> void:
	var plate := CellField.shrunk(cell, INSET)
	if plate.size() < 3:
		return
	_paint(CellField.shrunk(cell, INSET * 0.45), _back_of(kind))
	var face := _face_of(kind)
	if kind == Kind.BUTTON and label == "비활성":
		_paint(plate, Color(_paper(), 0.14))
		for bar in GraphicCut.stripes(plate, -PI * 0.25, 9.0, 4.0, 0.0):
			_paint(bar, Color(_void(), 0.34))
		_label(plate, label, 16, Color(_paper(), 0.42))
		return
	_paint(plate, face)
	if kind == Kind.WINDOW:
		_window_guts(plate)
		# 창 이름은 **위쪽**이다. 칸의 가운데에 놓으면 글줄 위에 앉는다.
		_label(plate, label, _size_of(kind), _ink(face), -0.34)
		return
	if kind == Kind.VALUE and label == "소리":
		_rail(plate)
	if marked:
		_row_idle(plate)
	_label(plate, label, _size_of(kind), _ink(face))


func _face_of(kind: Kind) -> Color:
	match kind:
		Kind.HERE:
			# **화면에서 신호색이 나오는 자리는 여기 하나다** (§20.32).
			return HoloPalette.accent(palette)
		Kind.PERIL:
			return HoloPalette.peril(palette)
		Kind.POPUP:
			return Color(_paper(), 0.92)
		Kind.ROW:
			return Color(_paper(), 0.15)
		Kind.VALUE:
			return Color(_paper(), 0.15)
		_:
			return _paper()


func _back_of(kind: Kind) -> Color:
	if kind == Kind.PERIL:
		return Color(HoloPalette.peril(palette), 0.6)
	if kind == Kind.HERE:
		return _paper()
	return HoloPalette.back(palette)


func _size_of(kind: Kind) -> int:
	match kind:
		Kind.TITLE:
			return 46
		Kind.HERE:
			return 24
		Kind.POPUP:
			return 22
		Kind.WINDOW:
			return 18
		_:
			return 17


## 다각형 하나를 칠한다. 넓이가 없는 조각은 안 그린다 — 무게가 시간에 따라 바뀌므로
## 어느 프레임에서 칸이 실오라기가 되는 일이 **반드시** 있다 (§20.36.1).
func _paint(shape: PackedVector2Array, tint: Color) -> void:
	if shape.size() < 3 or CellField.area_of(shape) < 0.05:
		return
	draw_colored_polygon(shape, tint)


## 글자를 **칸이 내주는 폭**에 맞춰 앉힌다 (§20.42.3).
##
## 칸이 직사각형이 아니라서 가운데에 그냥 놓으면 삐져나온다. `chord()` 로 그 띠에서
## 칸의 실제 폭을 재고, 좁으면 **글자를 줄인다.** 형태가 아무리 새로워도 글자가 먼저다.
func _label(
	cell: PackedVector2Array, text: String, base: int, tint: Color, lift: float = 0.0
) -> void:
	if text.is_empty():
		return
	var box := _bounds_of(cell)
	var mid := CellField.middle(cell) + Vector2(0.0, box.size.y * lift)
	var span := CellField.chord(cell, mid.y - float(base) * 0.62, mid.y + float(base) * 0.42)
	var wide := span.y - span.x - 14.0
	if wide < 16.0:
		return
	var count := maxf(1.0, float(text.length()))
	var fit := clampi(int(wide / (count * 1.06)), 9, base)
	draw_string(
		FONT,
		Vector2(span.x + 7.0, mid.y + float(fit) * 0.36),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		wide,
		fit,
		tint
	)


## 창 속 글줄 셋. 판이 무슨 모양이든 **칸이 내주는 폭 안에서** 그어진다.
func _window_guts(plate: PackedVector2Array) -> void:
	var box := _bounds_of(plate)
	for row in 3:
		var y := box.position.y + 46.0 + float(row) * 22.0
		var line := CellField.chord(plate, y, y + 9.0)
		if line.y - line.x < 24.0:
			continue
		var far := lerpf(line.x + 14.0, line.y - 14.0, 0.92 - float(row) * 0.18)
		_paint(
			PackedVector2Array(
				[
					Vector2(line.x + 14.0, y),
					Vector2(far, y),
					Vector2(far - 5.0, y + 9.0),
					Vector2(line.x + 9.0, y + 9.0),
				]
			),
			Color(_void(), 0.66 - float(row) * 0.16)
		)
	# 닫기는 험이다. 오른위 구석에 붙는다 — 구석이 어디인지도 칸이 알려 준다.
	var top := CellField.chord(plate, box.position.y + 22.0, box.position.y + 38.0)
	if top.y - top.x > 60.0:
		var at := Vector2(top.y - 22.0, box.position.y + 30.0)
		var peril := HoloPalette.peril(palette)
		draw_line(at + Vector2(-6, -6), at + Vector2(6, 6), peril, 2.6)
		draw_line(at + Vector2(-6, 6), at + Vector2(6, -6), peril, 2.6)


## 슬라이더 — 칸의 폭이 곧 궤도의 길이다. **값이 차 있는 쪽은 고름**이다.
func _rail(plate: PackedVector2Array) -> void:
	var box := _bounds_of(plate)
	var y := box.get_center().y + 12.0
	var line := CellField.chord(plate, y, y + 8.0)
	if line.y - line.x < 40.0:
		return
	var left := line.x + 12.0
	var right := line.y - 12.0
	_paint(_bar(left, right, y, 7.0), Color(_paper(), 0.2))
	_paint(_bar(left, lerpf(left, right, 0.62), y, 7.0), HoloPalette.pick(palette))
	var knob := lerpf(left, right, 0.62)
	_paint(_bar(knob - 6.0, knob + 8.0, y - 8.0, 24.0), _paper())


func _bar(left: float, right: float, top: float, tall: float) -> PackedVector2Array:
	return PackedVector2Array(
		[
			Vector2(left + tall * 0.5, top),
			Vector2(right + tall * 0.5, top),
			Vector2(right, top + tall),
			Vector2(left, top + tall),
		]
	)


## 고른 줄의 idle. §20.39.2 의 규칙 그대로 — **판 안쪽 무늬**만, 실루엣은 안 건드린다.
func _row_idle(plate: PackedVector2Array) -> void:
	for bar in GraphicCut.stripes(plate, -PI * 0.28, 20.0, 6.0, _clock * 13.0):
		_paint(bar, Color(_paper(), 0.11))


func _bounds_of(poly: PackedVector2Array) -> Rect2:
	var box := Rect2(poly[0], Vector2.ZERO)
	for point in poly:
		box = box.expand(point)
	return box


func _notes() -> void:
	draw_string(
		FONT,
		Vector2(PAD + 4.0, size.y - 8.0),
		"칸의 윤곽을 사람이 안 정한다 — 씨앗과 무게만 준다. 고른 줄은 무게가 커지고 이웃이 양보한다",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color(_paper(), 0.5)
	)
