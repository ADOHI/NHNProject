class_name ActionDialog
extends Control
## 게임에 그대로 들어가는 **팝업 하나.** 형태는 `PopupForm`, 거동은 `PopupMotion` 이
## 정하고 이 파일은 **색과 그리기만** 안다.
##
## 배색은 버튼(`ActionButton`)과 같은 값을 쓴다 — 채도 낮은 파스텔, 명도로 가르기,
## 흐리지 않은 그림자. 팝업이 버튼과 다른 배색이면 한 화면에 못 앉는다.
##
## ## 뒤가 있다는 것이 버튼과 가장 다른 점이다
##
## 뒤를 어떻게 하느냐가 그 자체로 축이라 형태마다 다르게 붙였다(`PopupForm.Backdrop`).
## 그리고 **뒤는 판보다 먼저 자리잡고 판보다 늦게 걷힌다.** 같이 움직이면 판이
## 어디에서 왔고 어디로 갔는지 안 보인다.

const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")

const PLATE := Color("#c9d4e0")
const PLATE_HIGH := Color("#dde5ee")
const RULE := Color("#6f8098")
const RULE_SOFT := Color("#93a2b5")
const INK := Color("#212a37")
const BODY_INK := Color("#4a5768")
const SHADOW := Color("#a8b1bd")
const ACCENT := Color("#c0705f")

## 제목 · 본문 크기. 팝업은 낱말 하나가 아니라 문장이 들어간다.
const TITLE_SIZE: int = 21
const BODY_SIZE: int = 15
const LINE_STEP: float = 21.0

@export var form: PopupForm.Kind = PopupForm.Kind.SHUTTER
@export var title: String = "출격 확인"
@export var lines: Array[String] = ["서초 3구역 균열로 4 명을 보낸다.", "돌아오지 못해도 계약은 유지된다."]

var _motion := PopupMotion.new()
var _confirm: ActionButton
var _cancel: ActionButton
var _panel := Rect2(0.0, 0.0, 380.0, 210.0)
var _driven := false


func _ready() -> void:
	_panel = Rect2(Vector2.ZERO, size)
	_build_buttons()
	if not _driven:
		set_process(true)
		_motion.open()


## 캡처 도구가 시계를 잡는다. **`add_child()` 앞에서 불러야 한다.**
func drive_externally() -> void:
	_driven = true
	set_process(false)


## 밖에서 시각을 앉힌다.
func pose(phase: PopupMotion.Phase, clock: float, since_open: float, since_close: float) -> void:
	_motion.phase = phase
	_motion.pose(clock, since_open, since_close)
	_place_buttons()
	queue_redraw()


func _process(delta: float) -> void:
	if _driven:
		return
	_motion.advance(delta)
	if _motion.phase == PopupMotion.Phase.OPENING and _motion.settled(_count()):
		_motion.phase = PopupMotion.Phase.OPEN
	_place_buttons()
	queue_redraw()


## 다시 연다. 확인 화면이 되돌릴 때 쓴다.
func replay() -> void:
	_motion.open()


func dismiss() -> void:
	_motion.close()


## 뒤 가림의 진행. 확인 화면이 뒤를 그릴 때 읽는다 — 뒤는 팝업 밖에 있으므로
## 팝업이 자기 뒤를 그릴 수 없다.
func veil_now() -> float:
	return _motion.veil()


func _count() -> int:
	return PopupForm.pieces(form, size).size()


func _build_buttons() -> void:
	_confirm = ActionButton.new()
	_confirm.form = PlateForm.Kind.SHARD
	_confirm.text = "출격"
	_cancel = ActionButton.new()
	_cancel.form = PlateForm.Kind.SLAB
	_cancel.text = "취소"
	for button in [_cancel, _confirm]:
		if _driven:
			button.drive_externally()
		add_child(button)
		button.size = button.custom_minimum_size
	_place_buttons()


## 단추도 판을 따라 들어온다. 내용이 판보다 늦게 들기 때문에 열림 중에는 숨는다.
func _place_buttons() -> void:
	if _confirm == null:
		return
	var shown := _motion.content()
	var at := PopupForm.buttons_at(form, size)
	# 내용이 아래에서 살짝 올라온다. 판과 같이 날아오면 글자가 날아다니는 것으로 보인다.
	var rise := (1.0 - shown) * 10.0
	_cancel.position = at + Vector2(0.0, rise + 6.0)
	_confirm.position = at + Vector2(_cancel.size.x + 18.0, rise)
	_cancel.modulate = Color(1.0, 1.0, 1.0, shown)
	_confirm.modulate = Color(1.0, 1.0, 1.0, shown)
	_cancel.visible = shown > 0.02
	_confirm.visible = shown > 0.02


func _draw() -> void:
	var here := PopupForm.pieces(form, size)
	var count := here.size()
	var shown := _motion.presence()
	if shown <= 0.001 and _motion.veil() <= 0.001:
		return

	var fold_axis := PopupForm.fold_axis(form)
	var lit := PLATE.lerp(PLATE_HIGH, 0.35)

	for i in count:
		var piece := _fly(here[i], i, count, fold_axis)
		if piece.is_empty():
			continue
		_shadow(piece, shown)
		if PopupForm.filled(form):
			# 조각마다 명도를 아주 조금 달리한다. 완전히 같으면 다섯이 한 장으로 붙어
			# 보여서 부챗살로 모인 것이 안 보인다.
			var step := 1.0 - absf(float(i) - float(count - 1) * 0.5) * 0.035
			draw_colored_polygon(piece, Color(lit.r * step, lit.g * step, lit.b * step, shown))
		draw_polyline(_closed(piece), Color(RULE, shown), 1.5, true)

	_draw_misprint(here, count, fold_axis, shown)
	if PopupForm.ruled(form):
		_draw_ruler(shown)
	_draw_content()


## 조각 하나를 **날아오는 자리에서 제자리로** 옮긴다. 닫힘에서는 접는다.
func _fly(
	piece: PackedVector2Array, index: int, count: int, fold_axis: Vector2
) -> PackedVector2Array:
	var come := _motion.piece(index, count)
	var from := PopupForm.entry(form, index, count, size)
	var grow := lerpf(PopupForm.entry_scale(form), 1.0, come)
	var shift := from * (1.0 - come)

	var folded := _motion.fold_of(index, count)
	var middle := size * 0.5
	var squeeze := Vector2(
		lerpf(1.0, 1.0 - fold_axis.x, folded), lerpf(1.0, 1.0 - fold_axis.y, folded)
	)
	if squeeze.x <= 0.01 or squeeze.y <= 0.01:
		return PackedVector2Array()

	var out := PackedVector2Array()
	for point in piece:
		var moved := middle + (point - middle) * grow + shift
		out.append(middle + (moved - middle) * squeeze)
	return out


func _shadow(piece: PackedVector2Array, shown: float) -> void:
	var moved := PackedVector2Array()
	for point in piece:
		moved.append(point + Vector2(0.0, 5.0))
	draw_colored_polygon(moved, Color(SHADOW, 0.55 * shown))


## 큰 면적에서 겹인쇄가 어떻게 되는지 보는 자리. 어긋남을 **절대값**으로 잡는다.
func _draw_misprint(
	here: Array[PackedVector2Array], count: int, fold_axis: Vector2, shown: float
) -> void:
	var slip := PopupForm.misprint(form)
	if slip == Vector3.ZERO:
		return
	for i in count:
		var piece := _fly(here[i], i, count, fold_axis)
		if piece.is_empty():
			continue
		var middle := size * 0.5
		var moved := PackedVector2Array()
		for point in piece:
			moved.append(middle + (point - middle).rotated(slip.z) + Vector2(slip.x, slip.y))
		draw_polyline(_closed(moved), Color(ACCENT, 0.8 * shown), 1.5, true)


## 사방 눈금. 계측기 틀이라 네 변을 다 두른다.
func _draw_ruler(shown: float) -> void:
	var inside := Rect2(Vector2.ZERO, size).grow(-7.0)
	var tone := Color(RULE_SOFT, 0.75 * shown)
	var step := 9.0
	var x := inside.position.x
	while x < inside.end.x:
		draw_rect(Rect2(x, inside.position.y, 1.0, 4.0), tone)
		draw_rect(Rect2(x, inside.end.y - 4.0, 1.0, 4.0), tone)
		x += step
	var y := inside.position.y
	while y < inside.end.y:
		draw_rect(Rect2(inside.position.x, y, 4.0, 1.0), tone)
		draw_rect(Rect2(inside.end.x - 4.0, y, 4.0, 1.0), tone)
		y += step


## 제목 · 본문. **판이 다 온 뒤에 든다.**
func _draw_content() -> void:
	var shown := _motion.content()
	if shown <= 0.02:
		return
	var rise := (1.0 - shown) * 10.0
	var at := PopupForm.title_at(form) + Vector2(0.0, rise)
	draw_string(FONT, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, Color(INK, shown))
	draw_rect(Rect2(at.x, at.y + 8.0, 26.0, 2.0), Color(ACCENT, shown))

	var box := PopupForm.body(form, size)
	var y := box.position.y + 20.0
	for line in lines:
		draw_string(
			FONT,
			Vector2(box.position.x, y + rise),
			line,
			HORIZONTAL_ALIGNMENT_LEFT,
			box.size.x,
			BODY_SIZE,
			Color(BODY_INK, shown)
		)
		y += LINE_STEP


func _closed(shape: PackedVector2Array) -> PackedVector2Array:
	var out := shape.duplicate()
	out.append(shape[0])
	return out
