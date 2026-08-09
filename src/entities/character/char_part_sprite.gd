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


func setup(p_part: CharPart.Id, p_rig: CharRig, p_texture: Texture2D, p_mirror := false) -> void:
	part = p_part
	rig = p_rig
	texture = p_texture
	mirror = p_mirror
	queue_redraw()


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
func draw_rect_local() -> Rect2:
	var half := rig.half_sizes[part]
	var centre := rig.local_centers[part]
	# 지역 좌표는 `+y` 가 아래다. 코어(`+y` 위)에서 잡은 중심을 뒤집어 넣는다.
	return Rect2(
		Vector2(centre.x - half.x, -centre.y - half.y), Vector2(half.x * 2.0, half.y * 2.0)
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
