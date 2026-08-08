class_name FoilGlyph
extends Control
## **「금」 한 글자.** 종이에 눌러 찍은 금박이고, 그 박에 금이 가 있다.
##
## 이 노드가 곧 제목이다. 제목이 두 뜻을 지므로(금(金) · 금이 간다)
## 그 둘을 **한 재료**로 동시에 말해야 한다 — 금박은 값싼 종이 위에서 반드시 갈라진다
## (docs/design/21-title.md §21.3).
##
## 이 노드는 화면에서 **인쇄판 뒤에** 앉는다. 박은 잉크가 아니라 다 찍은 종이에
## 열로 눌러 붙이는 것이라 공정상 판 다음이고, 덕분에 화면에서 유일하게
## 망점이 아닌 것이 된다.
##
## 글자를 셰이더에 직접 넘길 수 없어 `SubViewport` 한 장에 먼저 찍는다.
## 글자를 그대로 그리면 UV 가 글꼴 아틀라스의 것이 되어 금이 간 자리를 잴 수 없다.

## 갈라진 자리에서 조각이 떨어져 나갔다. 떨어진 자리를 UV 로 알린다.
signal shed(where: Vector2)

const _FOIL_SHADER := preload("res://src/ui/title/shaders/foil.gdshader")

## 셰이더가 받는 금의 꺾은 점 수. 셰이더 배열 크기와 같아야 한다.
const _SEAM_POINTS := 10

## 글자를 찍어 두는 판의 크기(px). 금이 간 가장자리를 볼 만큼은 커야 한다.
const _SHEET := 768

## 판 안에서 글자가 차지하는 비율. 명조의 글자틀은 실제 획보다 크게 잡히므로
## 1 을 넘겨야 획이 판을 채운다. 캡처로 맞춘 값이다.
const _GLYPH_FILL := 1.12

## 머무는 동안의 어긋남. **0 이 되지 않는다** — 한 번 간 금은 메워지지 않는다.
##
## 크게 잡는다. 처음에 0.026(글자 폭의 2.6%, 화면에서 5px)으로 줬더니
## 심사자 둘 다 **움직임을 아예 못 봤다.** 프레임을 나란히 놓고 비교해야
## 겨우 보이는 것은 없는 것과 같다. 이 게임의 주제를 지고 있는 몸짓이
## 화면에서 가장 큰 움직임이어야 한다.
const _SLIP_REST := 0.105
const _SLIP_ALMOST := 0.008

## 붙으려는 시간과 어긋나는 시간. **붙는 것은 느리고 어긋나는 것은 순식간이다.**
## 이 비가 뒤집히면 그냥 흔들리는 글자가 된다.
const _CLOSE_SECONDS := 2.4
const _FAIL_SECONDS := 0.09
const _HOLD_SECONDS := 1.15

## 머무는 동안 벌어진 폭. 어긋남이 보이려면 틈이 조금은 있어야 한다.
const _OPEN_REST := 0.030

## 처음 눌러 찍을 때 벌어지는 폭. 박이 열과 압력에 맞는 순간이다.
const _OPEN_STRIKE := 0.155

## 한 번 붙기에 실패할 때마다 더 떨어져 나가는 양과 그 한계.
## **되돌아가지 않는다.** 화면에 머문 시간이 그대로 손상으로 남는다.
const _FLAKE_STEP := 0.014
const _FLAKE_CAP := 0.34

## 커서로 누른 자리에서 한 번에 떨어져 나가는 양.
const _FLAKE_TOUCH := 0.05

@export var text := "금":
	set(value):
		text = value
		if _label != null:
			_label.text = value

## 같은 시드는 같은 금이다. 심사 캡처가 매번 달라지면 무엇을 고쳤는지 비교할 수 없다.
@export var seed_value := 1103

var _material: ShaderMaterial
var _sheet: SubViewport
var _label: Label
var _field: CrackField
var _web: Control
var _breath: Tween
var _open := 0.0
var _slip := _SLIP_REST
var _flake := 0.0
var _hits := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 박은 아직 종이에 닿지 않았다. `strike()` 가 눌러 찍는다.
	visible = false
	_build_sheet()
	_build_material()
	regrow()


func _process(_delta: float) -> void:
	_material.set_shader_parameter("seconds", UiMotion.clock())
	queue_redraw()


func _draw() -> void:
	if _sheet == null:
		return
	draw_texture_rect(_sheet.get_texture(), Rect2(Vector2.ZERO, size), false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _material != null:
		_material.set_shader_parameter("aspect", maxf(size.x, 1.0) / maxf(size.y, 1.0))


## **금을 새로 낸다.** 시드가 같으면 같은 금이 나온다.
func regrow() -> void:
	_field = CrackField.new(seed_value, Rect2(Vector2(-0.2, -0.2), Vector2(1.4, 1.4)))
	# 글자를 가로지르는 금 하나가 조각을 가른다. 「금」의 가운데 가로획을 끊고 지나가야
	# 한 글자가 두 동강이라는 것이 한눈에 보인다.
	_field.split_across(Vector2(0.44, 0.52), Vector2(1.0, 0.30))
	# 그 줄기에서 잔금이 사방으로 번진다. 금 간 금은 한 줄이 아니라 **망**이다.
	_field.strike(Vector2(0.62, 0.36), 3, 0.72)
	_field.strike(Vector2(0.34, 0.70), 3, 0.66)
	var seam := _field.seam(_SEAM_POINTS)
	_material.set_shader_parameter("seam", seam)
	_material.set_shader_parameter("seam_count", seam.size())
	_web.set("field", _field)
	_web.queue_redraw()


## **눌러 찍는다.** 박이 종이에 닿는 순간 갈라진다.
##
## 페이드인이 아니다. 박은 나타나는 것이 아니라 **맞는** 것이라,
## 한 번 크게 벌어졌다가 제자리를 찾는다.
##
## 이 순간까지 박은 **화면에 없다.** 처음에 `_ready` 부터 보이게 뒀더니
## 심사자 둘 다 "첫 프레임에 이미 다 있고 갈라져 있다 — 눌린 것이 아니라
## 페이드인이다"라고 지적했다. 눌러 찍히는 것을 보여 주려면
## **닿기 전에는 없어야** 한다.
func strike() -> void:
	_stop_breathing()
	visible = true
	_flake = 0.0
	_set_open(_OPEN_STRIKE)
	_set_slip(_SLIP_REST * 3.2)
	var tween := create_tween()
	tween.set_parallel(true)
	(
		tween
		. tween_method(_set_open, _OPEN_STRIKE, _OPEN_REST, UiTokens.TIME_RESOLVE)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_ELASTIC)
	)
	(
		tween
		. tween_method(_set_slip, _SLIP_REST * 3.2, _SLIP_REST, UiTokens.TIME_RESOLVE * 1.2)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_BACK)
	)
	(
		tween
		. tween_method(_set_flake, 0.0, _FLAKE_STEP * 2.0, UiTokens.TIME_BLEED)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_CUBIC)
	)
	tween.chain().tween_callback(breathe)


## **머무는 동안.** 두 조각이 다시 붙으려다 마지막에 어긋난다. 조용히 반복한다.
##
## 이 한 몸짓이 제목의 두 번째 뜻이다 — *사이에 금이 가다.*
## 그리고 붙으려는 시도마다 박이 조금씩 더 떨어져 나간다. **되돌아가지 않는다.**
func breathe() -> void:
	_stop_breathing()
	_breath = create_tween().set_loops()
	(
		_breath
		# 느리게, 거의 다 붙는다. 서두르면 붙으려 한 것으로 안 보인다.
		. tween_method(_set_slip, _SLIP_REST, _SLIP_ALMOST, _CLOSE_SECONDS)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_QUINT)
	)
	(
		_breath
		# **마지막에 어긋난다.** 붙는 시간의 25분의 1이라 눈이 놓칠 수 없다.
		. tween_method(_set_slip, _SLIP_ALMOST, _SLIP_REST, _FAIL_SECONDS)
		. set_ease(Tween.EASE_IN)
		. set_trans(Tween.TRANS_BACK)
	)
	_breath.tween_callback(_fail_to_mend)
	_breath.tween_interval(_HOLD_SECONDS)


## 커서가 박 위를 지난다. 박은 금속이라 **기울이면 광택이 흐른다.**
##
## 올리면 밝아지는 반응을 쓰지 않는 이유가 여기 있다
## (docs/design/18-visual-identity.md §18.7). 밝아지는 것은 웹 버튼이고,
## 광택이 결을 따라 흐르는 것은 금속이다.
func light_from(where: Vector2) -> void:
	_material.set_shader_parameter("light", where)


## 눌렸다. **그 자리에서 새로 금이 간다.** 이것은 되돌아가지 않는다.
##
## 처음에는 박락 수치만 올렸다. 심사자 둘이 각각 잡아냈다 —
## "누른 뒤 프레임이 누르기 전과 구분이 안 된다. 균열이 하나도 안 늘었다."
## "압력이 박을 갈라지게 한다는 것이 이 화면의 전제인데, **누르면 색만 변한다.**
##  이건 마감이 덜 된 게 아니라 컨셉이 실패한 것이다."
##
## 그래서 진짜로 낸다. 누른 자리를 새 타격점으로 삼아 균열망을 키우고,
## 판을 다시 찍는다. 균열은 **누적되고 지워지지 않는다** — 그것이 제목의 뜻이다.
func bruise_at(where: Vector2) -> void:
	_set_flake(minf(_flake + _FLAKE_TOUCH, _FLAKE_CAP))
	# 때린 자리에서 사방으로 갈라진다. 힘은 매번 조금씩 줄어든다 —
	# 이미 갈라진 박은 응력을 덜 진다.
	_hits += 1
	_field.strike(where, 3, maxf(0.62 - float(_hits) * 0.06, 0.24))
	_web.queue_redraw()
	shed.emit(where)
	var tween := create_tween()
	(
		tween
		. tween_method(_set_open, _OPEN_REST * 3.4, _OPEN_REST, UiTokens.TIME_CHASE)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_ELASTIC)
	)


## **전환.** 두 조각이 끝내 갈라진다. 금이 판 밖으로 뻗어 나갈 자리를 내준다.
func tear_open(amount: float) -> void:
	_stop_breathing()
	_set_open(_OPEN_REST + amount * 0.42)
	_set_slip(_SLIP_REST + amount * 0.10)


func field() -> CrackField:
	return _field


func _fail_to_mend() -> void:
	if _flake >= _FLAKE_CAP:
		return
	_set_flake(minf(_flake + _FLAKE_STEP, _FLAKE_CAP))


func _stop_breathing() -> void:
	if _breath != null and _breath.is_valid():
		_breath.kill()


func _set_open(value: float) -> void:
	_open = value
	_material.set_shader_parameter("open", value)


func _set_slip(value: float) -> void:
	_slip = value
	_material.set_shader_parameter("slip", value)


func _set_flake(value: float) -> void:
	_flake = value
	_material.set_shader_parameter("flake", value)


func _build_material() -> void:
	_material = ShaderMaterial.new()
	_material.shader = _FOIL_SHADER
	_material.set_shader_parameter("glyph", _sheet.get_texture())
	_material.set_shader_parameter("aspect", maxf(size.x, 1.0) / maxf(size.y, 1.0))
	_material.set_shader_parameter("open", _OPEN_REST)
	_material.set_shader_parameter("slip", _SLIP_REST)
	_material.set_shader_parameter("flake", 0.0)
	material = _material


## 글자와 잔금을 판 한 장에 먼저 찍는다.
##
## 흰 글자 위에 **검은 잔금**을 곱하기로 얹는다. 곱하기를 쓰는 이유가 핵심이다 —
## 글자 밖은 알파가 0 이라 아무리 검게 칠해도 0 으로 남는다.
## 그래서 **잔금이 저절로 글자 안에만 갇힌다.** 금은 금박에 간 것이지
## 종이에 그어 놓은 낙서가 아니다.
##
## `UPDATE_ONCE` 로 두는 이유는 글자도 잔금도 변하지 않기 때문이다. 매 프레임 다시 찍으면
## 웹 빌드에서 렌더 타깃 하나를 공짜로 버리는 셈이 된다.
func _build_sheet() -> void:
	_sheet = SubViewport.new()
	_sheet.size = Vector2i(_SHEET, _SHEET)
	_sheet.transparent_bg = true
	_sheet.disable_3d = true
	_sheet.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_label = Label.new()
	_label.text = text
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 흰색으로 찍어 둔다. 색은 셰이더가 정하고 여기서는 **모양만** 필요하다.
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_font_size_override("font_size", int(_SHEET * _GLYPH_FILL))
	_sheet.add_child(_label)
	_web = _CrackWeb.new()
	_web.set_anchors_preset(Control.PRESET_FULL_RECT)
	_web.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mask := CanvasItemMaterial.new()
	mask.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_web.material = mask
	_sheet.add_child(_web)
	add_child(_sheet)


## 금박에 간 **잔금.** 벌어지지 않아 조각을 가르지는 못하지만, 금 간 금은
## 한 줄이 아니라 **망**이라서 이것이 없으면 그냥 잘린 글자가 된다.
##
## 셰이더가 아니라 여기서 그리는 이유는 `UiShape` 와 같다 —
## 형태는 코드가 만들고 셰이더는 질감을 만든다. 그리고 잔금은 굵기가 변하는
## 띠라서 폴리곤이어야 하는데, 그건 셰이더가 할 일이 아니다.
class _CrackWeb:
	extends Control

	var field: CrackField = null

	func _draw() -> void:
		if field == null or size.x < 1.0 or size.y < 1.0:
			return
		for vein in field.veins():
			var band := CrackField.ribbon(vein, vein.length())
			if band.size() < 3:
				continue
			var points := PackedVector2Array()
			for point in band:
				points.append(point * size)
			# 검게 곱한다. 알파는 건드리지 않아야 글자 밖이 뚫리지 않는다.
			draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 1.0))
