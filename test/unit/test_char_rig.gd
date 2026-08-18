extends GutTest
## `CharRig` 의 치수와 `CharPart` 의 앞뒤 구분을 잡는다.
##
## **여기 모인 단정은 거의 전부 「시점이 사이드 사선이다」를 지키는 것들이다.**
## 앞뒤 크기 · 그리는 순서 · 두 발의 어긋남 · 겹침의 방향 — 하나라도 무너지면
## 궤도가 아무리 측면이어도 화면은 정면으로 읽힌다. 궤도는 `test_idle_clip.gd` 가 본다.
##
## `test_char_pose.gd` 에서 갈라 나왔다. 좌표계 변환과 리그 치수는 깨지는 이유가 달라
## 한 파일에 두면 무엇이 무너졌는지 이름만 보고 알 수 없다.


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
	var foot_top := (
		rig.rest_positions[CharPart.Id.FOOT_NEAR].y + rig.half_sizes[CharPart.Id.FOOT_NEAR].y * 2.0
	)
	var torso_bottom := rig.rest_positions[CharPart.Id.TORSO].y
	assert_gt(torso_bottom - foot_top, 0.0, "몸과 발 사이에 간격이 있어야 한다")

	var torso_top := torso_bottom + rig.half_sizes[CharPart.Id.TORSO].y * 2.0
	var head_bottom := rig.rest_positions[CharPart.Id.HEAD].y
	assert_gt(head_bottom - torso_top, 0.0, "몸과 머리 사이에 목이 있을 자리가 있어야 한다")


func test_the_near_hand_floats_clear_but_the_far_hand_overlaps() -> void:
	# 두 손의 겹침이 **반대여야** 한다. 앞손은 떠 있는 것이 보여야 하고(레이맨의 표시),
	# 뒷손은 몸에 가려져야 뒤에 있는 것이 된다. 둘 다 띄우면 시점이 사라진다.
	#
	# **몸의 너비를 그 손의 높이에서 재야 한다.** 최대 반너비로 재면 밑단(어깨의 1.5 배)의
	# 폭으로 어깨 옆을 판정하게 되어, 화면에서는 멀쩡히 떠 있는 앞손을 겹쳤다고 우긴다.
	var rig := CharRig.new()
	var near := rig.rest_positions[CharPart.Id.HAND_NEAR]
	var far := rig.rest_positions[CharPart.Id.HAND_FAR]
	var near_inner := near.x - rig.half_sizes[CharPart.Id.HAND_NEAR].x
	var far_inner := far.x + rig.half_sizes[CharPart.Id.HAND_FAR].x
	assert_gt(near_inner, rig.torso_front_at(near.y), "앞손은 몸에서 떨어져 떠 있어야 한다")
	assert_gt(far_inner, rig.torso_back_at(far.y), "뒷손은 몸에 겹쳐야 가려진다")


func test_the_body_is_widest_at_the_hem_so_width_must_be_asked_per_height() -> void:
	# 이 함수가 높이를 무시하고 최대 반너비를 돌려주면 겹침 판정이 통째로 거짓말한다.
	var rig := CharRig.new()
	var bottom := rig.rest_positions[CharPart.Id.TORSO].y
	var span := rig.half_sizes[CharPart.Id.TORSO].y * 2.0
	var hem := rig.torso_half_width_at(bottom + span * 0.10)
	var shoulder := rig.torso_half_width_at(bottom + span * 0.82)
	assert_gt(hem, shoulder, "A 라인이면 밑단이 어깨보다 넓다")
	assert_almost_eq(hem, rig.half_sizes[CharPart.Id.TORSO].x, 0.01, "최대 반너비가 밑단의 폭이다")
	# 몸 밖을 물어도 터지지 않고 가장 가까운 끝을 돌려줘야 한다.
	assert_gt(rig.torso_half_width_at(bottom - 50.0), -1.0)
	assert_gt(rig.torso_half_width_at(bottom + span + 50.0), -1.0)


func test_the_far_side_is_drawn_behind_the_body() -> void:
	# 겹치게 해 놓고 순서를 안 바꾸면 뒷손이 몸 앞에 그려져 앞뒤가 뒤집힌다.
	var order := CharPart.DRAW_ORDER
	assert_lt(order.find(CharPart.Id.HAND_FAR), order.find(CharPart.Id.TORSO), "뒷손이 몸보다 먼저 그려져야 한다")
	assert_lt(order.find(CharPart.Id.FOOT_FAR), order.find(CharPart.Id.TORSO))
	assert_gt(
		order.find(CharPart.Id.HAND_NEAR), order.find(CharPart.Id.TORSO), "앞손은 몸보다 나중에 그려져야 한다"
	)


func test_the_far_side_is_smaller() -> void:
	var rig := CharRig.new()
	assert_lt(
		rig.half_sizes[CharPart.Id.HAND_FAR].x,
		rig.half_sizes[CharPart.Id.HAND_NEAR].x,
		"먼 손이 더 커 보이면 앞뒤가 뒤집힌다"
	)
	assert_lt(rig.half_sizes[CharPart.Id.FOOT_FAR].x, rig.half_sizes[CharPart.Id.FOOT_NEAR].x)


func test_the_feet_stand_fore_and_aft_not_side_by_side() -> void:
	# 나란히 세우면 그 자체로 정면 자세다. 어긋남이 시점을 말한다.
	var rig := CharRig.new()
	var gap := (
		rig.rest_positions[CharPart.Id.FOOT_NEAR].x - rig.rest_positions[CharPart.Id.FOOT_FAR].x
	)
	assert_gt(gap, 10.0, "앞발이 뒷발보다 확실히 앞에 있어야 한다")


func test_depth_sign_is_opposite_on_each_side() -> void:
	assert_eq(CharPart.depth_sign(CharPart.Id.HAND_FAR), -1.0)
	assert_eq(CharPart.depth_sign(CharPart.Id.HAND_NEAR), 1.0)
	assert_eq(CharPart.depth_sign(CharPart.Id.TORSO), 0.0)
	assert_true(CharPart.is_far(CharPart.Id.FOOT_FAR))
	assert_false(CharPart.is_far(CharPart.Id.FOOT_NEAR))


func test_draw_order_holds_every_part_exactly_once() -> void:
	assert_eq(CharPart.DRAW_ORDER.size(), CharPart.COUNT)
	var seen := {}
	for part: int in CharPart.DRAW_ORDER:
		seen[part] = true
	assert_eq(seen.size(), CharPart.COUNT, "파츠가 겹치거나 빠지면 하나가 안 그려진다")
