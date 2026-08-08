class_name CharRig
extends RefCounted
## 파츠 여섯의 피벗과 치수. 애니메이션이 "무엇을" 움직이는지에 대한 정의.
##
## **피벗을 어디에 두는가가 연기의 절반이다.** 같은 각도의 회전이 피벗 위치에 따라
## "고개를 갸웃" 이 되거나 "머리가 옆으로 미끄러짐" 이 된다.
## 파츠별 피벗 근거는 `docs/design/25-character-animation.md` §25.2 에 있다.
##
## 좌표계: **`+y` 가 위**, 원점은 두 발 사이의 지면. Godot 은 `+y` 가 아래이므로
## 변환이 필요하고, 그 변환은 `CharPose.canvas_transform()` 한 곳에만 있다.
##
## 스프라이트로 갈아 끼울 때 바뀌는 파일이 이것과 `char_part_shape.gd` 둘뿐이다.
## 애니메이션 수식은 리그의 치수를 직접 읽지 않고 `rest_positions` 만 본다.

## 발 하나가 중심에서 벌어진 거리. 이 값이 서 있는 자세의 안정감을 정한다.
const FOOT_X := 13.0

## 부츠를 22 높이로 둔다. 18 이면 몸과의 간격이 16 이 되어 다리가 잘린 것으로 읽혔다.
const FOOT_HALF := Vector2(11.0, 11.0)

## 몸의 피벗 높이 = 부츠의 윗면(22)보다 12 위. 이 간격이 "다리가 있을 자리" 다.
const TORSO_Y := 34.0
const TORSO_HALF := Vector2(20.0, 21.0)

## 손이 몸에서 벌어진 거리. 37 은 너무 멀었다 — 손이 몸을 떠나가는 것으로 보였다.
## 레이맨은 **읽힐 만큼은 붙어 있다.**
const HAND_X := 34.0

## 몸의 중간 높이(55)에 맞춘다. 아래로 내리면 넓은 치맛단 옆에 붙어 더 멀어 보인다.
const HAND_Y := 56.0
const HAND_HALF := Vector2(11.0, 11.0)

## 머리의 피벗 높이 = 몸의 윗면(76)보다 5 위. **이 5 가 목이다.**
##
## 처음에 10 으로 뒀더니 머리가 몸에서 떠난 것으로 보였다. 0 이면 눈사람이 되고
## 30 이면 목이 잘린 것으로 읽힌다. 5 는 간격이 보이면서도 한 몸으로 읽히는 자리다.
const HEAD_Y := 81.0
const HEAD_HALF := Vector2(30.0, 30.0)

## 파츠의 피벗 위치 (쉬는 자세, 캐릭터 공간).
var rest_positions: PackedVector2Array

## 그려지는 덩어리의 중심이 피벗에서 얼마나 떨어져 있는가 (파츠 지역 공간, `+y` 위).
##
## 피벗이 밑면인 파츠는 이 값이 `(0, 반높이)` 다. 접지 판정이 이 값을 쓴다.
var local_centers: PackedVector2Array

## 그려지는 덩어리의 반크기. 접지 판정과 실루엣 계산에 쓴다.
var half_sizes: PackedVector2Array


func _init() -> void:
	rest_positions = PackedVector2Array(
		[
			Vector2(0.0, HEAD_Y),
			Vector2(0.0, TORSO_Y),
			Vector2(-HAND_X, HAND_Y),
			Vector2(HAND_X, HAND_Y),
			Vector2(-FOOT_X, 0.0),
			Vector2(FOOT_X, 0.0),
		]
	)
	half_sizes = PackedVector2Array(
		[HEAD_HALF, TORSO_HALF, HAND_HALF, HAND_HALF, FOOT_HALF, FOOT_HALF]
	)
	# 머리 · 몸 · 발은 피벗이 밑면이라 중심이 반높이만큼 위에 있다. 손은 피벗이 중심이다.
	local_centers = PackedVector2Array(
		[
			Vector2(0.0, HEAD_HALF.y),
			Vector2(0.0, TORSO_HALF.y),
			Vector2.ZERO,
			Vector2.ZERO,
			Vector2(0.0, FOOT_HALF.y),
			Vector2(0.0, FOOT_HALF.y),
		]
	)


## 정수리까지의 키. 화면에 맞춰 배율을 정할 때 쓴다.
##
## 상수로 두지 않는 이유는 리그 치수를 두 곳에 적으면 도구가 옛 수치로 거짓말하기 때문이다.
func total_height() -> float:
	return rest_positions[CharPart.Id.HEAD].y + half_sizes[CharPart.Id.HEAD].y * 2.0


## 손 바깥 끝까지의 폭. 위와 같은 이유로 계산해서 쓴다.
func total_width() -> float:
	return (rest_positions[CharPart.Id.HAND_R].x + half_sizes[CharPart.Id.HAND_R].x) * 2.0


## 파츠 지역 공간에서의 밑면 한가운데. 접지 판정의 기준점이다.
##
## 피벗이 밑면인 파츠는 이 값이 원점이라, **눌려도(`sy < 1`) 밑면이 안 움직인다.**
## 그래서 눌림을 위치로 보정하는 계산이 아예 없다.
func local_bottom(part: CharPart.Id) -> Vector2:
	return local_centers[part] - Vector2(0.0, half_sizes[part].y)
