class_name CharPartSprite
extends Node2D
## 파츠 하나를 **그림으로** 그린다. `char_part_shape.gd` 의 형제이고, **그것을 대신한다.**
##
## `docs/design/25-character-animation.md` §25.41.
##
## **애니메이션 수식은 이 파일도 모른다.** 도형판과 똑같이 트랜스폼만 받아서 그린다 —
## 그래서 도형에서 그림으로 갈아 끼우는 것이 **뷰의 스위치 하나**로 끝난다.
##
## ## 왜 `Sprite2D` 가 아닌가
##
## `Sprite2D` 는 자기 트랜스폼이 필요한데, 파츠의 트랜스폼은 **포즈가 정한다**.
## 그래서 노드 하나 안에서 `offset` 을 또 쓰면 두 곳에서 자리를 정하게 된다 —
## 도형판이 `local_centers` 하나로 끝냈던 것을 두 벌로 만드는 셈이다.
##
## 여기서는 **그리기만** 한다. 자리는 부모가 준 트랜스폼과 리그의 `local_centers` 뿐이다.

## 먼 파츠를 배경 쪽으로 물들이는 양. 도형판과 **같은 값**이라야 앞뒤가 같게 읽힌다.
const FAR_TINT := Color(0.353, 0.396, 0.439)
const FAR_TINT_AMOUNT := 0.32

## 닿는 순간의 번쩍임 색과 짙기. 도형판과 같다 (§25.28.4).
const FLASH := Color(1.0, 0.988, 0.941)
const FLASH_ALPHA := 0.85

## 모핑 셰이더. **켜졌을 때만 붙는다** — 안 붙어야 지금과 같은 경로로 그려진다 (§31.5.3).
const MORPH_SHADER := "res://src/entities/character/char_morph.gdshader"

## 모핑이 켜졌을 때 그리는 사각형을 넓히는 비율 (한쪽 변당).
##
## 그림이 알파 경계상자로 딱 잘려 있어(§25.41.2) 넓히지 않으면 **밀려난 살이 변에서
## 잘린다.** 진폭 상한이 반크기의 12 % 이므로 그보다 넉넉해야 한다 (§31.6.2).
const MORPH_PAD := 0.16

var part := CharPart.Id.HEAD
var rig: CharRig

## 그릴 그림. 알파 경계상자로 **이미 잘려 있어야 한다** (§25.41.2).
var texture: Texture2D

## **이 그림을 좌우로 뒤집어 그리나.** 짝의 그림을 빌려 쓸 때만 참이다 (§25.41.1).
##
## **파츠 이름으로 정하면 안 된다.** 뒷손이 제 그림을 갖고 오는 판에서도 뒤집게 되고,
## 뿌리가 이미 왼쪽 보기로 뒤집혀 있으므로(§25.41.9) **두 번 뒤집혀 제자리로 돌아온다.**
var mirror := false

## **닿는 순간의 번쩍임** (`0` … `1`). 도형판과 같은 규약이다.
var flash := 0.0:
	set(value):
		if is_equal_approx(value, flash):
			return
		flash = value
		queue_redraw()

var _canvas: CanvasItem = null

## 이 파츠에 붙은 앵커들. 비어 있으면 모핑이 안 걸린다.
var _anchors: Array[MorphAnchor] = []
var _morph: ShaderMaterial = null


func setup(p_part: CharPart.Id, p_rig: CharRig, p_texture: Texture2D, p_mirror := false) -> void:
	part = p_part
	rig = p_rig
	texture = p_texture
	mirror = p_mirror
	queue_redraw()


## 이 파츠가 휘는 자리들을 붙인다. **빈 목록이면 재질을 아예 안 붙인다.**
##
## 붙여 놓고 0 을 넣는 것과 다르다 — 안 붙어야 그리는 경로가 지금과 **같은 경로**이고,
## 그래야 「끄면 지금 화면과 픽셀 단위로 같다」가 성립한다 (§31.4 · §31.5.3).
func setup_morph(p_anchors: Array[MorphAnchor]) -> void:
	_anchors = p_anchors
	if _anchors.is_empty() or rig == null:
		_morph = null
		material = null
		queue_redraw()
		return
	_morph = ShaderMaterial.new()
	_morph.shader = load(MORPH_SHADER)
	material = _morph
	_push_shape()
	apply_morph(PackedVector2Array(), PackedFloat32Array())
	queue_redraw()


## 모핑이 켜져 있나. **묻는 자리를 하나로 둔다.**
func has_morph() -> bool:
	return _morph != null


## **그 순간의 변위와 부풀림을 셰이더에 넣는다.** `shifts` 는 파츠 지역 좌표다.
##
## 앵커 순서는 `setup_morph()` 에 준 것과 같다.
func apply_morph(shifts: PackedVector2Array, bulges: PackedFloat32Array) -> void:
	if _morph == null:
		return
	var uv_shift := PackedVector2Array()
	var uv_bulge := PackedFloat32Array()
	for i in _anchors.size():
		uv_shift.append(uv_delta_of(shifts[i] if i < shifts.size() else Vector2.ZERO))
		uv_bulge.append(bulges[i] if i < bulges.size() else 0.0)
	_morph.set_shader_parameter("anchor_shift", uv_shift)
	_morph.set_shader_parameter("anchor_bulge", uv_bulge)


## 앵커의 **모양**(자리 · 반경 · 마스크)을 넣는다. 셋업 때 한 번이면 된다.
func _push_shape() -> void:
	var box := base_rect_local()
	var uv := PackedVector2Array()
	var radius := PackedVector2Array()
	var mask := PackedVector4Array()
	for anchor in _anchors:
		uv.append(uv_of(anchor.centre))
		radius.append(Vector2(anchor.radius.x / box.size.x, anchor.radius.y / box.size.y))
		mask.append(_mask_uv(anchor, box))
	_morph.set_shader_parameter("anchor_count", _anchors.size())
	_morph.set_shader_parameter("pad", MORPH_PAD)
	_morph.set_shader_parameter("anchor_uv", uv)
	_morph.set_shader_parameter("anchor_radius", radius)
	_morph.set_shader_parameter("anchor_mask", mask)


## 반평면을 UV 공간으로 옮긴다. `xy` 단위법선 · `z` 자리 · `w` 무뎌지는 폭.
##
## **좌우 뒤집기가 여기서 한 번 들어온다** (§31.6.3). 파츠 지역 `+x` 가 뒤집힌
## 그림에서는 텍스처의 `-u` 라, 법선의 가로 성분이 부호를 바꾼다.
func _mask_uv(anchor: MorphAnchor, box: Rect2) -> Vector4:
	if anchor.mask_normal.is_zero_approx():
		return Vector4.ZERO
	var n := anchor.mask_normal.normalized()
	var raw := Vector2(n.x * box.size.x, -n.y * box.size.y)
	var offset := anchor.mask_offset + n.y * box.position.y
	if mirror:
		raw.x = -raw.x
		offset -= n.x * (box.position.x + box.size.x)
	else:
		offset -= n.x * box.position.x
	var length := raw.length()
	if length <= 0.0:
		return Vector4.ZERO
	return Vector4(raw.x / length, raw.y / length, offset / length, anchor.mask_feather / length)


## 파츠 지역의 한 점을 **텍스처 UV** 로 옮긴다.
func uv_of(point: Vector2) -> Vector2:
	var box := base_rect_local()
	var u := (point.x - box.position.x) / box.size.x
	if mirror:
		u = 1.0 - u
	return Vector2(u, (-point.y - box.position.y) / box.size.y)


## 파츠 지역의 **변위**를 UV 변위로 옮긴다. 자리가 아니라 방향이라 원점을 안 더한다.
func uv_delta_of(shift: Vector2) -> Vector2:
	var box := base_rect_local()
	var du := shift.x / box.size.x
	if mirror:
		du = -du
	return Vector2(du, -shift.y / box.size.y)


## 남의 캔버스에 그린다. 도형판과 같은 얼굴이라 뷰가 둘을 안 가려도 된다 (§25.32).
func paint_into(target: CanvasItem, at: Transform2D) -> void:
	_canvas = target
	target.draw_set_transform_matrix(at)
	_draw()
	target.draw_set_transform_matrix(Transform2D.IDENTITY)
	_canvas = null


## 그려지는 상자. **리그의 치수를 쓴다** — 그림 크기를 여기서 다시 읽지 않는다.
##
## 두 곳에서 읽으면 갈린다(§25.13.1). 리그가 그림에서 치수를 받아 갔으므로
## **여기서는 리그만 믿는다.**
func base_rect_local() -> Rect2:
	var half := rig.half_sizes[part]
	var centre := rig.local_centers[part]
	# 지역 좌표는 `+y` 가 아래다. 코어(`+y` 위)에서 잡은 중심을 뒤집어 넣는다.
	return Rect2(
		Vector2(centre.x - half.x, -centre.y - half.y), Vector2(half.x * 2.0, half.y * 2.0)
	)


## 실제로 찍는 사각형. **모핑이 켜져 있으면 여백만큼 넓다** (§31.6.2).
##
## 넓힌 만큼 셰이더가 UV 를 되돌리므로 **그림은 원래 크기로 남는다.**
## 꺼져 있으면 여백이 없다 — 그래야 지금과 같은 화소가 나온다.
func draw_rect_local() -> Rect2:
	var box := base_rect_local()
	if _morph == null:
		return box
	return box.grow_individual(
		box.size.x * MORPH_PAD, box.size.y * MORPH_PAD, box.size.x * MORPH_PAD,
		box.size.y * MORPH_PAD
	)


func _target() -> CanvasItem:
	return self if _canvas == null else _canvas


func _draw() -> void:
	if rig == null or texture == null:
		return
	var box := draw_rect_local()
	var canvas := _target()
	# **빌려 쓴 손만 좌우로 뒤집는다.** 왼손과 오른손은 거울이라 앞손 그림을 뒷손에도
	# 쓰면 오른손이 둘이 된다. **제 그림이 있으면 안 뒤집는다** — 뿌리가 이미
	# 뒤집혀 있어서 두 번 뒤집히면 제자리로 돌아온다 (§25.41.9).
	if mirror:
		box = Rect2(Vector2(-box.position.x - box.size.x, box.position.y), box.size)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0, 1.0))
	canvas.draw_texture_rect(texture, box, false, _tint())
	if mirror:
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if flash > 0.001:
		canvas.draw_texture_rect(texture, box, false, Color(FLASH, flash * FLASH_ALPHA))


## 먼 파츠는 배경 쪽으로 물든다. **곱하기가 아니라 섞기**라 도형판과 같은 색이 나온다.
func _tint() -> Color:
	if not CharPart.is_far(part):
		return Color.WHITE
	return Color.WHITE.lerp(FAR_TINT, FAR_TINT_AMOUNT)
