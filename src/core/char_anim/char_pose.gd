class_name CharPose
extends RefCounted
## 어느 한 순간의 파츠 여섯 트랜스폼 한 벌. **이동 · 회전 · 배율뿐이다.**
##
## 좌표계: **`+y` 가 위**, 원점은 두 발 사이의 지면, 회전은 **반시계가 양수**(수학 관례).
## "높이가 올라간다 = `y` 가 커진다" 로 읽혀야 호흡 · 눌림 · 도약을 사람이 검산할 수 있다.
##
## Godot 은 `+y` 가 아래이므로 변환이 필요하다. **그 변환은 `canvas_transform()`
## 한 곳에만 있다.** `F = diag(1, -1)` 로 켤레를 취하면
##
##     canvas = F · core · F   →   T(x, −y) · R(−θ) · S(sx, sy)
##
## **회전의 부호가 뒤집힌다는 것이 함정이다.** 놓치면 고개가 반대로 갸웃한다.
## 배율은 안 뒤집힌다. `test_char_pose.gd` 가 셋을 각각 잡아 둔다.
##
## `Packed*Array` 로 둔 이유는 나중에 `sample_into()` 로 재사용 경로를 열 수 있게
## 하기 위해서다 (§25.8 — 웹은 평균이 아니라 꼬리가 나쁘다).

var positions: PackedVector2Array
var rotations: PackedFloat32Array
var scales: PackedVector2Array


func _init() -> void:
	positions.resize(CharPart.COUNT)
	rotations.resize(CharPart.COUNT)
	scales.resize(CharPart.COUNT)
	for i in CharPart.COUNT:
		scales[i] = Vector2.ONE


## 쉬는 자세. 애니메이션은 여기서 시작해 변위를 얹는다.
static func from_rig(rig: CharRig) -> CharPose:
	var pose := CharPose.new()
	pose.positions = rig.rest_positions.duplicate()
	return pose


## 캐릭터 공간(`+y` 위)에서의 트랜스폼. 접지 판정과 테스트가 쓴다.
func core_transform(part: CharPart.Id) -> Transform2D:
	return Transform2D(rotations[part], positions[part]).scaled_local(scales[part])


## Godot 화면 공간(`+y` 아래)에서의 트랜스폼. 노드에 그대로 넣는 값이다.
##
## 파츠 노드의 지역 좌표도 `+y` 아래로 그린다 — 그래서 단순 변환이 아니라 **켤레**다.
func canvas_transform(part: CharPart.Id) -> Transform2D:
	var pivot := positions[part]
	var flipped := Transform2D(-rotations[part], Vector2(pivot.x, -pivot.y))
	return flipped.scaled_local(scales[part])


## 파츠의 밑면 한가운데가 캐릭터 공간에서 어디에 있는가. 회전 · 배율까지 반영한다.
##
## 이 값의 `y` 가 음수면 파츠가 땅을 파고든 것이다.
func part_bottom(part: CharPart.Id, rig: CharRig) -> Vector2:
	return core_transform(part) * rig.local_bottom(part)


## 여섯 파츠 중 가장 낮은 밑면의 높이. 접지 검증이 쓴다.
func lowest_bottom_y(rig: CharRig) -> float:
	var lowest := INF
	for i in CharPart.COUNT:
		lowest = minf(lowest, part_bottom(i, rig).y)
	return lowest
