extends GutTest
## `CharPose` 의 좌표계 변환과 `CharRig` 의 피벗을 잡는다.
##
## 코어는 `+y` 가 위이고 Godot 은 `+y` 가 아래다. 그 변환에서 **회전은 뒤집히고
## 배율은 안 뒤집힌다.** 이 비대칭이 함정이라 셋을 따로 단정한다.

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
	var part := CharPart.Id.FOOT_R
	var before := pose.part_bottom(part, rig)
	pose.scales[part] = Vector2(1.1, 0.7)
	var after := pose.part_bottom(part, rig)
	assert_almost_eq(after.y, before.y, EPS, "발이 눌리면서 땅에서 뜨면 안 된다")
	assert_almost_eq(after.y, 0.0, EPS)


func test_rotating_a_bottom_pivot_part_keeps_its_bottom_still() -> void:
	var rig := CharRig.new()
	var pose := CharPose.from_rig(rig)
	var part := CharPart.Id.FOOT_L
	pose.rotations[part] = 0.3
	assert_almost_eq(pose.part_bottom(part, rig).y, 0.0, EPS)


func test_hand_pivot_is_its_center_so_its_bottom_hangs_below() -> void:
	var rig := CharRig.new()
	var pose := CharPose.from_rig(rig)
	var part := CharPart.Id.HAND_L
	var expected := rig.rest_positions[part].y - rig.half_sizes[part].y
	assert_almost_eq(pose.part_bottom(part, rig).y, expected, EPS)


func test_the_lowest_part_at_rest_is_exactly_on_the_ground() -> void:
	var rig := CharRig.new()
	assert_almost_eq(CharPose.from_rig(rig).lowest_bottom_y(rig), 0.0, EPS)


func test_dimensions_come_from_one_place_only() -> void:
	var rig := CharRig.new()
	var head := CharPart.Id.HEAD
	assert_eq(
		rig.total_height(),
		rig.rest_positions[head].y + rig.half_sizes[head].y * 2.0,
		"키를 상수로 따로 적으면 도구가 옛 수치로 거짓말한다"
	)


func test_head_is_the_widest_part_so_the_silhouette_reads_as_chibi() -> void:
	var rig := CharRig.new()
	assert_gt(
		rig.half_sizes[CharPart.Id.HEAD].x,
		rig.half_sizes[CharPart.Id.TORSO].x,
		"머리가 몸보다 좁으면 SD 비례가 아니다"
	)


func test_parts_do_not_touch_each_other() -> void:
	# 팔다리 · 목이 없는 것이 이 스타일의 정체다. 파츠가 붙으면 그냥 인형이 된다.
	var rig := CharRig.new()
	var foot_top := rig.half_sizes[CharPart.Id.FOOT_R].y * 2.0
	var torso_bottom := rig.rest_positions[CharPart.Id.TORSO].y
	assert_gt(torso_bottom - foot_top, 0.0, "몸과 발 사이에 간격이 있어야 한다")

	var torso_top := torso_bottom + rig.half_sizes[CharPart.Id.TORSO].y * 2.0
	var head_bottom := rig.rest_positions[CharPart.Id.HEAD].y
	assert_gt(head_bottom - torso_top, 0.0, "몸과 머리 사이에 목이 있을 자리가 있어야 한다")

	var torso_side := rig.half_sizes[CharPart.Id.TORSO].x
	var hand_inner := (
		rig.rest_positions[CharPart.Id.HAND_R].x - rig.half_sizes[CharPart.Id.HAND_R].x
	)
	assert_gt(hand_inner - torso_side, 0.0, "손이 몸에 닿으면 팔이 있는 것으로 읽힌다")


func test_outward_sign_is_opposite_on_each_side() -> void:
	assert_eq(CharPart.outward_sign(CharPart.Id.HAND_L), -1.0)
	assert_eq(CharPart.outward_sign(CharPart.Id.HAND_R), 1.0)
	assert_eq(CharPart.outward_sign(CharPart.Id.TORSO), 0.0)


func test_draw_order_holds_every_part_exactly_once() -> void:
	assert_eq(CharPart.DRAW_ORDER.size(), CharPart.COUNT)
	var seen := {}
	for part: int in CharPart.DRAW_ORDER:
		seen[part] = true
	assert_eq(seen.size(), CharPart.COUNT, "파츠가 겹치거나 빠지면 하나가 안 그려진다")
