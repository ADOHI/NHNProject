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


## 파츠의 **발끝**(앞쪽 밑 모서리)이 캐릭터 공간에서 어디에 있는가.
##
## 뒤꿈치를 드는 동안 이 점이 자기 지면에 붙어 있어야 발이 미끄러지지 않는다.
func part_toe(part: CharPart.Id, rig: CharRig) -> Vector2:
	return core_transform(part) * rig.local_toe(part)


## 파츠의 **뒤꿈치**가 캐릭터 공간에서 어디에 있는가. 뒤꿈치가 닿는 구간에서 쓴다.
func part_heel(part: CharPart.Id, rig: CharRig) -> Vector2:
	return core_transform(part) * rig.local_heel(part)


## 발이 실제로 땅에 닿는 점. **발끝 · 뒤꿈치 · 밑면 중 가장 낮은 것**이다.
##
## 미끄러짐을 재려면 이 점의 앞뒤 움직임을 봐야 한다 — 발이 구르는 동안 접지점이
## 뒤꿈치에서 발끝으로 옮겨 가기 때문이다.
func part_ground_point(part: CharPart.Id, rig: CharRig) -> Vector2:
	var lowest := part_bottom(part, rig)
	for corner in [part_toe(part, rig), part_heel(part, rig)]:
		if corner.y < lowest.y:
			lowest = corner
	return lowest


## 파츠가 자기 지면 아래로 얼마나 파고들었는가. 음수면 떠 있는 것이라 문제가 없다.
##
## **지면이 파츠마다 다르다** — 사이드 사선에서는 뒷발의 바닥이 앞발보다 높다.
## 발은 밑면과 발끝 중 더 낮은 쪽으로 재고, 나머지 파츠는 밑면으로 잰다.
func sink_depth(part: CharPart.Id, rig: CharRig) -> float:
	var lowest := part_bottom(part, rig).y
	if CharPart.is_foot(part):
		lowest = minf(lowest, part_ground_point(part, rig).y)
	return rig.ground_y(part) - lowest


## 여섯 파츠 중 가장 깊이 파고든 정도. 접지 검증이 쓴다.
func deepest_sink(rig: CharRig) -> float:
	var deepest := -INF
	for i in CharPart.COUNT:
		deepest = maxf(deepest, sink_depth(i, rig))
	return deepest
