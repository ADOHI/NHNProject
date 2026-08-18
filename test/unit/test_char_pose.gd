extends GutTest
## `CharPose` 의 좌표계 변환과 피벗의 접지를 잡는다.
##
## 코어는 `+y` 가 위이고 Godot 은 `+y` 가 아래다. 그 변환에서 **회전은 뒤집히고
## 배율은 안 뒤집힌다.** 이 비대칭이 함정이라 셋을 따로 단정한다.
##
## 리그의 치수와 앞뒤 구분은 `test_char_rig.gd` 가 본다.

const EPS := 0.0001


func test_rest_pose_uses_the_rig_pivots() -> void:
	var rig := CharRig.new()
	var pose := CharPose.from_rig(rig)
	assert_eq(pose.positions[CharPart.Id.HEAD], rig.rest_positions[CharPart.Id.HEAD])
	assert_eq(pose.rotations[CharPart.Id.HEAD], 0.0)
	assert_eq(pose.scales[CharPart.Id.HEAD], Vector2.ONE)


func test_editing_a_pose_does_not_touch_the_rig() -> void:
	var rig := CharRig.new()
	var before := rig.rest_positions[CharPart.Id.TORSO]
	var pose := CharPose.from_rig(rig)
	pose.positions[CharPart.Id.TORSO] += Vector2(100.0, 100.0)
	assert_eq(rig.rest_positions[CharPart.Id.TORSO], before, "포즈가 리그를 공유하면 안 된다")


func test_canvas_transform_flips_height() -> void:
	var pose := CharPose.new()
	pose.positions[CharPart.Id.HEAD] = Vector2(5.0, 80.0)
	assert_eq(pose.canvas_transform(CharPart.Id.HEAD).origin, Vector2(5.0, -80.0))


func test_canvas_transform_also_flips_rotation() -> void:
	var pose := CharPose.new()
	pose.rotations[CharPart.Id.HEAD] = 0.4
	assert_almost_eq(pose.core_transform(CharPart.Id.HEAD).get_rotation(), 0.4, EPS)
	assert_almost_eq(
		pose.canvas_transform(CharPart.Id.HEAD).get_rotation(), -0.4, EPS, "회전을 안 뒤집으면 고개가 반대로 갸웃한다"
	)


func test_canvas_transform_does_not_flip_scale() -> void:
	var pose := CharPose.new()
	pose.scales[CharPart.Id.TORSO] = Vector2(0.8, 1.25)
	var part_scale := pose.canvas_transform(CharPart.Id.TORSO).get_scale()
	assert_almost_eq(part_scale.x, 0.8, EPS)
	assert_almost_eq(part_scale.y, 1.25, EPS, "배율까지 뒤집으면 상하가 반전된다")


func test_squashing_a_bottom_pivot_part_keeps_its_bottom_still() -> void:
	var rig := CharRig.new()
	var pose := CharPose.from_rig(rig)
	var part := CharPart.Id.FOOT_NEAR
	var before := pose.part_bottom(part, rig)
	pose.scales[part] = Vector2(1.1, 0.7)
	var after := pose.part_bottom(part, rig)
	assert_almost_eq(after.y, before.y, EPS, "발이 눌리면서 땅에서 뜨면 안 된다")
	assert_almost_eq(after.y, rig.ground_y(part), EPS)


func test_rotating_a_bottom_pivot_part_keeps_its_bottom_still() -> void:
	var rig := CharRig.new()
	var pose := CharPose.from_rig(rig)
	var part := CharPart.Id.FOOT_FAR
	pose.rotations[part] = 0.3
	assert_almost_eq(pose.part_bottom(part, rig).y, rig.ground_y(part), EPS)


func test_the_toe_sits_ahead_of_the_pivot() -> void:
	# 뒤꿈치 들기가 이 점을 축으로 돈다. 뒤에 있으면 회전 보정의 부호가 뒤집힌다.
	var rig := CharRig.new()
	assert_gt(rig.local_toe(CharPart.Id.FOOT_NEAR).x, rig.local_bottom(CharPart.Id.FOOT_NEAR).x)


func test_hand_pivot_is_its_center_so_its_bottom_hangs_below() -> void:
	var rig := CharRig.new()
	var pose := CharPose.from_rig(rig)
	var part := CharPart.Id.HAND_FAR
	var expected := rig.rest_positions[part].y - rig.half_sizes[part].y
	assert_almost_eq(pose.part_bottom(part, rig).y, expected, EPS)


func test_nothing_sinks_at_rest() -> void:
	var rig := CharRig.new()
	assert_almost_eq(CharPose.from_rig(rig).deepest_sink(rig), 0.0, EPS)


func test_each_foot_stands_on_its_own_ground() -> void:
	# 사이드 사선에서는 바닥이 멀어지며 화면 위로 물러난다. 지면을 하나로 두면
	# 뒷발이 땅에 파묻히거나 공중에 뜬다.
	var rig := CharRig.new()
	var pose := CharPose.from_rig(rig)
	for part: CharPart.Id in [CharPart.Id.FOOT_FAR, CharPart.Id.FOOT_NEAR]:
		assert_almost_eq(pose.part_bottom(part, rig).y, rig.ground_y(part), EPS)
	assert_gt(
		rig.ground_y(CharPart.Id.FOOT_FAR),
		rig.ground_y(CharPart.Id.FOOT_NEAR),
		"뒷발의 지면이 앞발보다 높아야 물러나 보인다"
	)
