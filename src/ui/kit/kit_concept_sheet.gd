class_name KitConceptSheet
extends Control
## 안 하나의 **부품 한 벌**을 한 장에 그린다.
##
## docs/design/20-ui-kit.md §20.26.
##
##     godot --path . -s res://tools/capture_kit_concepts.gd -- .renders/41-kit
##
## ## 부품이 안마다 같아야 안을 고를 수 있다
##
## 버튼 넷 · 창 · 팝업 · 메뉴 · 입력 · 강조. **자리도 같다** — 자리가 다르면
## 「부품이 달라서 달라 보이는 것」과 「안이 달라서 달라 보이는 것」이 안 갈린다.
##
## 다른 것은 `KitConcept` 의 매개변수와 **재료를 칠하는 함수 하나**(`_material`)뿐이다.
##
## ## 신호는 한 선에만
##
## 「지금 여기」가 안마다 **한 군데**에서만 흐른다 — 메뉴의 고른 항목이다.
## 버튼 · 창 · 슬라이더에 다 흘리면 §20.1 의 *"이건 무슨 수학 같음"* 으로 돌아간다.

const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")

## 한 장의 크기. 여섯을 3 x 2 로 붙이면 접촉 인화지가 된다.
const CARD := Vector2(620.0, 700.0)

const PAD := 22.0

var kind := KitConcept.Kind.ENGRAVE

## 재료 무늬가 판마다 다르게 앉도록 하는 흔들림. **판마다 같은 무늬가 앉으면
## 「인쇄물」이 아니라 「타일」로 보인다.**
var _dice := RandomNumberGenerator.new()


func _draw() -> void:
	_dice.seed = 20260809 + int(kind) * 977
	draw_rect(Rect2(Vector2.ZERO, size), KitConcept.backdrop(kind), true)
	_head()
	_buttons(96.0)
	_window(Rect2(PAD, 190.0, 310.0, 168.0))
	_popup(Rect2(PAD + 330.0, 190.0, 248.0, 168.0))
	_menu(Rect2(PAD, 378.0, 268.0, 158.0))
	_inputs(Rect2(PAD + 288.0, 378.0, 290.0, 158.0))
	_here(Rect2(PAD, 556.0, 578.0, 62.0))
	_foot()


# ------------------------------------------------------------------ 머리와 발


func _head() -> void:
	var ink := KitConcept.ink(kind)
	draw_string(
		FONT, Vector2(PAD, 44.0), KitConcept.name_of(kind), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, ink
	)
	draw_string(
		FONT,
		Vector2(PAD, 68.0),
		KitConcept.says(kind),
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x - PAD * 2.0,
		14,
		Color(ink, 0.66)
	)


func _foot() -> void:
	var accent := KitConcept.accent(kind)
	draw_string(
		FONT,
		Vector2(PAD, size.y - 22.0),
		"약한 곳 — %s" % KitConcept.weakness(kind),
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x - PAD * 2.0,
		13,
		Color(accent, 0.9)
	)


# ------------------------------------------------------------------ 부품 여섯


## 버튼 넷 — 기본 · 올림 · 눌림 · 비활성. **상태가 재료로 갈려야 한다.**
func _buttons(top: float) -> void:
	var labels := ["기본", "올림", "눌림", "비활성"]
	var wide := (size.x - PAD * 2.0 - 24.0) / 4.0
	for i in 4:
		var box := Rect2(PAD + float(i) * (wide + 8.0), top, wide, 46.0)
		_plate(box, i)
		draw_string(
			FONT,
			Vector2(box.position.x, box.get_center().y + 6.0),
			labels[i],
			HORIZONTAL_ALIGNMENT_CENTER,
			box.size.x,
			16,
			_text_color(i)
		)


## 창 — 제목줄 · 테두리 · 닫기 · 배경.
func _window(box: Rect2) -> void:
	_plate(box, 0)
	var ink := KitConcept.ink(kind)
	var bar := Rect2(box.position, Vector2(box.size.x, 30.0))
	_title_bar(bar)
	draw_string(
		FONT, bar.position + Vector2(10.0, 21.0), "창", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink
	)
	# 닫기는 **글자가 아니라 도형**이다. X 는 폰트에 기대는 순간 안마다 달라진다.
	var shut := Vector2(bar.end.x - 17.0, bar.position.y + 15.0)
	draw_line(shut + Vector2(-5, -5), shut + Vector2(5, 5), ink, 1.6)
	draw_line(shut + Vector2(-5, 5), shut + Vector2(5, -5), ink, 1.6)
	for row in 3:
		draw_rect(
			Rect2(
				box.position.x + 12.0,
				box.position.y + 48.0 + float(row) * 20.0,
				box.size.x - 24.0 - float(row) * 46.0,
				7.0
			),
			Color(ink, 0.30 - float(row) * 0.06),
			true
		)


## 팝업 — 확인 · 취소 두 단추.
func _popup(box: Rect2) -> void:
	_plate(box, 0)
	var ink := KitConcept.ink(kind)
	draw_string(
		FONT,
		box.position + Vector2(0.0, 40.0),
		"버릴까요",
		HORIZONTAL_ALIGNMENT_CENTER,
		box.size.x,
		19,
		ink
	)
	draw_string(
		FONT,
		box.position + Vector2(0.0, 66.0),
		"되돌릴 수 없습니다",
		HORIZONTAL_ALIGNMENT_CENTER,
		box.size.x,
		13,
		Color(ink, 0.6)
	)
	var wide := (box.size.x - 34.0) * 0.5
	for i in 2:
		var button := Rect2(
			box.position.x + 12.0 + float(i) * (wide + 10.0), box.end.y - 52.0, wide, 38.0
		)
		# **확인만 강조를 받는다** — 둘 다 튀면 무엇이 기본인지 안 읽힌다.
		_plate(button, 1 if i == 0 else 0)
		draw_string(
			FONT,
			Vector2(button.position.x, button.get_center().y + 5.0),
			"확인" if i == 0 else "취소",
			HORIZONTAL_ALIGNMENT_CENTER,
			button.size.x,
			15,
			_text_color(1 if i == 0 else 0)
		)


## 메뉴 — 항목 넷, 그중 하나 선택됨. **여기가 「지금 여기」가 흐르는 유일한 자리다.**
func _menu(box: Rect2) -> void:
	_plate(box, 0)
	var ink := KitConcept.ink(kind)
	var accent := KitConcept.accent(kind)
	var items := ["출격", "길드", "인물", "설정"]
	for i in items.size():
		var row := Rect2(
			box.position.x + 8.0, box.position.y + 12.0 + float(i) * 34.0, box.size.x - 16.0, 30.0
		)
		if i == 2:
			_signal_row(row, accent)
		draw_string(
			FONT,
			row.position + Vector2(16.0, 21.0),
			items[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			row.size.x,
			16,
			ink if i != 2 else _on_accent()
		)


## 입력 — 슬라이더 하나 · 체크 하나.
func _inputs(box: Rect2) -> void:
	_plate(box, 0)
	var ink := KitConcept.ink(kind)
	var accent := KitConcept.accent(kind)

	var rail := Rect2(box.position.x + 16.0, box.position.y + 44.0, box.size.x - 32.0, 6.0)
	draw_rect(rail, Color(ink, 0.22), true)
	draw_rect(Rect2(rail.position, Vector2(rail.size.x * 0.62, rail.size.y)), Color(ink, 0.6), true)
	var knob := Vector2(rail.position.x + rail.size.x * 0.62, rail.get_center().y)
	_knob(knob, accent)
	draw_string(
		FONT,
		box.position + Vector2(16.0, 30.0),
		"소리",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		Color(ink, 0.7)
	)

	var tick := Rect2(box.position.x + 16.0, box.position.y + 86.0, 22.0, 22.0)
	_plate(tick, 0)
	draw_polyline(
		PackedVector2Array(
			[
				tick.position + Vector2(5.0, 11.0),
				tick.position + Vector2(9.5, 16.0),
				tick.position + Vector2(17.0, 6.0),
			]
		),
		accent,
		2.4
	)
	draw_string(
		FONT,
		Vector2(tick.end.x + 12.0, tick.position.y + 16.0),
		"전체 화면",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		ink
	)


## 강조 — 「지금 여기」를 가리키는 표시.
##
## 글에 가운뎃점(U+00B7)을 쓰지 않는다. **송명체에 없어서 웹 빌드에서 두부가 된다** —
## 글리프 검사가 잡았다 (문서에서는 쓰지만 화면에 나가는 글은 다르다).
func _here(box: Rect2) -> void:
	var ink := KitConcept.ink(kind)
	draw_string(
		FONT,
		box.position + Vector2(0.0, -6.0),
		"강조 — 지금 여기",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		Color(ink, 0.55)
	)
	_plate(box, 0)
	_signal_row(
		Rect2(box.position.x + 8.0, box.position.y + 8.0, box.size.x - 16.0, box.size.y - 16.0),
		KitConcept.accent(kind)
	)
	draw_string(
		FONT,
		Vector2(box.position.x, box.get_center().y + 7.0),
		"3층 봉인된 문",
		HORIZONTAL_ALIGNMENT_CENTER,
		box.size.x,
		18,
		_on_accent()
	)


# --------------------------------------------------------------- 재료 — 안의 전부


## 판 하나. `state` 는 0 기본 · 1 올림 · 2 눌림 · 3 비활성이다.
##
## **여섯 안의 차이가 전부 이 함수 안에 있다.** 자리와 크기는 위에서 같게 주므로
## 여기서만 갈리면 「무엇 때문에 달라 보이는가」가 재료 하나로 고정된다.
func _plate(box: Rect2, state: int) -> void:
	var shape := KitConcept.outline(kind, box)
	var surface := KitConcept.surface(kind)
	var ink := KitConcept.ink(kind)
	var accent := KitConcept.accent(kind)
	var lift := 0.0 if state == 0 else (0.10 if state == 1 else -0.08)
	var faded := state == 3

	match KitConcept.fill(kind):
		KitConcept.Fill.CARVED:
			_carved(box, shape, state, faded)
		KitConcept.Fill.LAYERED:
			_layered(box, shape, lift, faded)
		KitConcept.Fill.SHEER:
			_sheer(box, shape, lift, faded)
		KitConcept.Fill.HALFTONE:
			_halftone(box, shape, state, faded)
		KitConcept.Fill.EMPTY:
			_empty(box, shape, state, faded)
		_:
			_solid(box, shape, state, faded)

	if KitConcept.edge(kind) > 0.0 and KitConcept.fill(kind) != KitConcept.Fill.HALFTONE:
		var edge := Color(ink if not faded else Color(ink, 0.3), 0.55)
		if state == 1:
			edge = accent
		draw_polyline(_closed(shape), edge, KitConcept.edge(kind))
	_unused(surface)


## 각인 — **테두리가 없다.** 밝은 변과 어두운 변 한 쌍이 경계를 만든다.
func _carved(box: Rect2, shape: PackedVector2Array, state: int, faded: bool) -> void:
	var deep := state == 2
	# 눌리면 판이 바탕 쪽으로 내려앉는다. 변만 뒤집으면 「눌렸다」가 약하다.
	var face := KitConcept.surface(kind)
	if deep:
		face = face.darkened(0.22)
	elif state == 1:
		face = face.lightened(0.06)
	draw_colored_polygon(shape, Color(face, 1.0 if not faded else 0.5))
	# 음각은 **대비가 전부다.** 옅게 잡으면 넷이 다 같은 판으로 보인다.
	var top := Color(1, 1, 1, 0.26 if not deep else 0.04)
	var bottom := Color(0, 0, 0, 0.62 if not deep else 0.20)
	if deep:
		var swap := top
		top = bottom
		bottom = swap
	if faded:
		top = Color(top, 0.05)
		bottom = Color(bottom, 0.12)
	draw_line(box.position, Vector2(box.end.x, box.position.y), top, 2.4)
	draw_line(box.position, Vector2(box.position.x, box.end.y), top, 2.4)
	draw_line(Vector2(box.position.x, box.end.y), box.end, bottom, 2.4)
	draw_line(Vector2(box.end.x, box.position.y), box.end, bottom, 2.4)
	if state == 1:
		draw_line(
			Vector2(box.position.x, box.end.y - 1.0),
			Vector2(box.end.x, box.end.y - 1.0),
			KitConcept.accent(kind),
			2.0
		)


## 박엽 — 얇은 박이 겹친다. **가장자리에서만 빛난다.**
func _layered(box: Rect2, shape: PackedVector2Array, lift: float, faded: bool) -> void:
	var gold := KitConcept.accent(kind)
	draw_colored_polygon(shape, Color(KitConcept.surface(kind), 1.0 if not faded else 0.45))
	for leaf in 3:
		var inset := 2.0 + float(leaf) * 3.0
		var inner := KitConcept.outline(kind, box.grow(-inset))
		draw_polyline(
			_closed(inner), Color(gold, (0.30 - float(leaf) * 0.08) * (0.3 if faded else 1.0)), 1.0
		)
	# 결 — 박을 두드린 자국. 가로로 잘게 간다.
	for i in int(box.size.y / 5.0):
		var y := box.position.y + 3.0 + float(i) * 5.0
		var jitter := _dice.randf_range(0.0, 1.0)
		draw_line(
			Vector2(box.position.x + 3.0 + jitter * 6.0, y),
			Vector2(box.end.x - 3.0 - jitter * 9.0, y),
			Color(gold, (0.05 + jitter * 0.05) * (0.3 if faded else 1.0)),
			1.0
		)
	draw_polyline(_closed(shape), Color(gold, (0.55 + lift) * (0.3 if faded else 1.0)), 1.4)


## 주사 — 반투명에 주사선. **빛이 안에서 나온다.**
func _sheer(box: Rect2, shape: PackedVector2Array, lift: float, faded: bool) -> void:
	var glow := KitConcept.ink(kind)
	draw_colored_polygon(shape, Color(glow, (0.07 + lift * 0.5) * (0.4 if faded else 1.0)))
	for i in int(box.size.y / 4.0):
		var y := box.position.y + 2.0 + float(i) * 4.0
		draw_line(
			Vector2(box.position.x + 2.0, y),
			Vector2(box.end.x - 2.0, y),
			Color(glow, 0.10 * (0.3 if faded else 1.0)),
			1.0
		)
	# 잔상 — 판이 한 번 어긋나 겹친다. 정지 화면에서 「갱신 중」을 만드는 유일한 수단이다.
	if not faded:
		draw_polyline(
			_closed(KitConcept.outline(kind, box.grow(-1.0)).duplicate()),
			Color(KitConcept.accent(kind), 0.22),
			1.0
		)


## 호외 — 망점으로 찬다. **두 번 찍히고 두 번째가 어긋난다.**
func _halftone(box: Rect2, shape: PackedVector2Array, state: int, faded: bool) -> void:
	var ink := KitConcept.ink(kind)
	var second := KitConcept.accent(kind)
	draw_colored_polygon(shape, KitConcept.surface(kind))
	# **처음에 0.30~0.72 로 찍었더니 망점이 글자를 통째로 먹었다** — 「거칠다」가 아니라
	# 「못 읽는다」였다. 종이는 잉크가 적어야 종이로 보인다.
	var density := 0.10 if state == 0 else (0.20 if state == 1 else 0.34)
	if faded:
		density = 0.05
	var step := 6.0
	var rows := int(box.size.y / step)
	var cols := int(box.size.x / step)
	for row in rows:
		for col in cols:
			if _dice.randf() > density:
				continue
			var at := box.position + Vector2(float(col) + 0.5, float(row) + 0.5) * step
			draw_circle(at, step * 0.22, Color(ink, 0.42))
	# 두 번째 잉크가 어긋난 자리. **§18.3 「모든 것은 두 번 찍힌다」의 계보다.**
	if not faded:
		draw_polyline(
			_closed(KitConcept.outline(kind, Rect2(box.position + Vector2(2.5, 2.0), box.size))),
			Color(second, 0.55),
			2.0
		)
	draw_polyline(_closed(shape), Color(ink, 0.9), 2.5)


## 격자 — **면이 비었다.** 가는 선과 눈금만으로 경계를 만든다.
func _empty(box: Rect2, shape: PackedVector2Array, state: int, faded: bool) -> void:
	var line := KitConcept.ink(kind)
	if state == 2:
		draw_colored_polygon(shape, Color(line, 0.10))
	for i in int(box.size.x / 12.0):
		var x := box.position.x + float(i) * 12.0
		draw_line(Vector2(x, box.position.y), Vector2(x, box.end.y), Color(line, 0.06), 1.0)
	# 눈금 — 네 변에 짧은 선. 자로 잰 것처럼 보이는 유일한 이유다.
	var reach := 6.0 if state != 1 else 10.0
	for i in 5:
		var t := float(i) / 4.0
		var x := lerpf(box.position.x, box.end.x, t)
		draw_line(
			Vector2(x, box.position.y), Vector2(x, box.position.y + reach), Color(line, 0.5), 1.0
		)
		draw_line(Vector2(x, box.end.y - reach), Vector2(x, box.end.y), Color(line, 0.5), 1.0)
	_unused(faded)


## 적층 — 꽉 찬 판이 층으로. **그림자가 두께다.**
func _solid(box: Rect2, shape: PackedVector2Array, state: int, faded: bool) -> void:
	var depth := 5.0 if state != 2 else 1.5
	if state == 1:
		depth = 8.0
	if not faded:
		draw_colored_polygon(
			KitConcept.outline(kind, Rect2(box.position + Vector2(0.0, depth), box.size)),
			Color(0, 0, 0, 0.18)
		)
	var face := KitConcept.surface(kind)
	if state == 2:
		face = face.darkened(0.06)
	draw_colored_polygon(shape, Color(face, 1.0 if not faded else 0.5))
	if state == 1:
		draw_polyline(_closed(shape), KitConcept.accent(kind), 2.0)


# ------------------------------------------------------------------ 조각들


## 제목줄. 안마다 다른 방법으로 「여기가 머리다」를 말한다.
func _title_bar(bar: Rect2) -> void:
	var ink := KitConcept.ink(kind)
	match KitConcept.fill(kind):
		KitConcept.Fill.EMPTY:
			draw_line(
				Vector2(bar.position.x, bar.end.y),
				Vector2(bar.end.x, bar.end.y),
				Color(ink, 0.45),
				1.0
			)
		KitConcept.Fill.CARVED:
			draw_line(
				Vector2(bar.position.x, bar.end.y),
				Vector2(bar.end.x, bar.end.y),
				Color(0, 0, 0, 0.35),
				2.0
			)
		KitConcept.Fill.HALFTONE:
			draw_rect(bar, Color(ink, 0.88), true)
		_:
			draw_rect(bar, Color(ink, 0.14), true)


## 「지금 여기」가 흐르는 한 줄. **안마다 흐르는 방법이 다르다.**
func _signal_row(row: Rect2, accent: Color) -> void:
	match KitConcept.fill(kind):
		KitConcept.Fill.CARVED:
			# 파인 자리에 빛이 고인다.
			draw_rect(row, Color(accent, 0.20), true)
			draw_line(row.position, Vector2(row.position.x, row.end.y), accent, 3.0)
		KitConcept.Fill.LAYERED:
			draw_rect(row, Color(accent, 0.16), true)
			draw_polyline(_closed(KitConcept.outline(kind, row)), accent, 1.2)
		KitConcept.Fill.SHEER:
			# 주사선 한 줄이 지나간다.
			draw_rect(row, Color(accent, 0.12), true)
			draw_line(
				Vector2(row.position.x, row.get_center().y),
				Vector2(row.end.x, row.get_center().y),
				accent,
				1.6
			)
		KitConcept.Fill.HALFTONE:
			draw_rect(row, accent, true)
		KitConcept.Fill.EMPTY:
			# 눈금 한 칸만 밝다.
			draw_rect(Rect2(row.position, Vector2(6.0, row.size.y)), accent, true)
			draw_polyline(_closed(KitConcept.outline(kind, row)), Color(accent, 0.7), 1.0)
		_:
			draw_colored_polygon(KitConcept.outline(kind, row), accent)


func _knob(at: Vector2, accent: Color) -> void:
	match KitConcept.fill(kind):
		KitConcept.Fill.EMPTY:
			draw_polyline(
				_closed(KitConcept.outline(kind, Rect2(at - Vector2(6, 9), Vector2(12, 18)))),
				accent,
				1.4
			)
		KitConcept.Fill.HALFTONE:
			draw_rect(Rect2(at - Vector2(6, 10), Vector2(12, 20)), accent, true)
		KitConcept.Fill.CARVED:
			draw_rect(Rect2(at - Vector2(7, 9), Vector2(14, 18)), accent, true)
			draw_line(at - Vector2(7, 9), at + Vector2(-7, 9), Color(1, 1, 1, 0.3), 1.0)
		_:
			draw_circle(at, 9.0, accent)


## 강조 위에 얹히는 글자색. **면이 강조로 찼으면 글자는 바탕색이어야 읽힌다.**
func _on_accent() -> Color:
	var solid := KitConcept.fill(kind) == KitConcept.Fill.HALFTONE
	solid = solid or KitConcept.fill(kind) == KitConcept.Fill.SOLID
	return KitConcept.surface(kind) if solid else KitConcept.ink(kind)


func _text_color(state: int) -> Color:
	var ink := KitConcept.ink(kind)
	if state == 3:
		return Color(ink, 0.28)
	if state == 1 and KitConcept.fill(kind) == KitConcept.Fill.HALFTONE:
		return ink
	return ink


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	if not out.is_empty():
		out.append(out[0])
	return out


## 안 쓰는 값을 삼킨다. 린트가 「안 쓰는 지역 변수」를 잡는 것을 피하려고 두는 것이 아니라
## **읽는 사람에게 「여기서는 이 값을 안 쓴다」를 알리려고** 둔다.
func _unused(_value: Variant) -> void:
	pass
