extends GutTest
## 조절판 스위치 넷의 계약.
##
## **값만 받고 아무것도 안 끄는 스위치는 눈으로도 잘 안 걸린다.** 슬라이더를 내렸는데
## 화면이 조금 달라지면 사람은 "원래 이 정도인가" 하고 넘어간다. 그래서 각 스위치가
## 0 에서 **무엇을 정확히 없애는지**를 등식으로 못 박는다.
##
## 이 파일이 통과하면 조절판이 거짓말하지 않는다는 뜻이고, 그때만 사람의 판정이
## 의미가 있다 (`docs/design/25-character-animation.md` §25.5).

const EPS := 0.0001

# --- 호 ---------------------------------------------------------------------


func test_arc_off_moves_the_head_on_a_straight_vertical_line() -> void:
	var clip := CharAnimProbe.clip()
	var f := AnimFeatures.all_on()
	f.arc = 0.0
	for t in CharAnimProbe.scan_times():
		assert_almost_eq(CharAnimProbe.offset(clip, CharPart.Id.HEAD, t, f).x, 0.0, EPS)
		assert_almost_eq(clip.sample(t, f).rotations[CharPart.Id.HEAD], 0.0, EPS)


func test_arc_off_pins_the_hands_sideways_too() -> void:
	# 좌우 성분이 다른 경로로 새어 들면 "호 끄기" 가 반쪽만 듣는다.
	var clip := CharAnimProbe.clip()
	var f := AnimFeatures.all_on()
	f.arc = 0.0
	for t in CharAnimProbe.scan_times():
		assert_almost_eq(CharAnimProbe.offset(clip, CharPart.Id.HAND_NEAR, t, f).x, 0.0, EPS)
		assert_almost_eq(CharAnimProbe.offset(clip, CharPart.Id.TORSO, t, f).x, 0.0, EPS)


# --- 배율 -------------------------------------------------------------------


func test_squash_off_leaves_every_scale_exactly_one() -> void:
	# 근사가 아니라 등식이어야 한다. 한 파츠만 새어 나가도 스위치가 거짓말하는 것이다.
	var clip := CharAnimProbe.clip()
	var f := AnimFeatures.all_on()
	f.squash = 0.0
	for t in CharAnimProbe.scan_times():
		var pose := clip.sample(t, f)
		for part in CharPart.COUNT:
			assert_eq(pose.scales[part], Vector2.ONE, "%s 의 배율이 안 꺼졌다" % CharPart.part_name(part))


# --- 비대칭 -----------------------------------------------------------------


func test_asymmetry_leaves_the_hands_alone() -> void:
	# **축이 갈려 있는지** 본다. 정면일 때는 두 손의 차이가 전부 `asymmetry` 였지만
	# 측면에서는 앞뒤에서 나온다. 옮기다 만 항이 남아 있으면 여기서 걸린다.
	var clip := CharAnimProbe.clip()
	var on := AnimFeatures.all_on()
	var off := AnimFeatures.all_on()
	off.asymmetry = 0.0
	for t in CharAnimProbe.scan_times():
		for part: CharPart.Id in [CharPart.Id.HAND_FAR, CharPart.Id.HAND_NEAR]:
			assert_eq(
				CharAnimProbe.offset(clip, part, t, on),
				CharAnimProbe.offset(clip, part, t, off),
				"비대칭은 발의 소관이지 손의 소관이 아니다"
			)


func test_asymmetry_off_stops_the_feet_dead() -> void:
	var clip := CharAnimProbe.clip()
	var f := AnimFeatures.all_on()
	f.asymmetry = 0.0
	for t in CharAnimProbe.scan_times():
		var pose := clip.sample(t, f)
		for part: CharPart.Id in [CharPart.Id.FOOT_FAR, CharPart.Id.FOOT_NEAR]:
			assert_eq(pose.positions[part], clip.rig.rest_positions[part])
			assert_eq(pose.rotations[part], 0.0)
			assert_eq(pose.scales[part], Vector2.ONE)


func test_asymmetry_on_shifts_weight_between_the_feet() -> void:
	var clip := CharAnimProbe.clip()
	var f := AnimFeatures.all_on()
	# 무게가 앞으로 실리는 순간에는 앞발이 눌리고 뒷발의 뒤꿈치가 들린다.
	var pose := clip.sample(CharIdleClip.LOOP * 0.25, f)
	assert_lt(pose.scales[CharPart.Id.FOOT_NEAR].y, 1.0, "실린 발은 눌려야 한다")
	assert_gt(
		pose.positions[CharPart.Id.FOOT_FAR].y,
		clip.rig.rest_positions[CharPart.Id.FOOT_FAR].y,
		"무게가 빠진 발은 뒤꿈치가 들려 피벗이 올라가야 한다"
	)


# --- 앞뒤 -------------------------------------------------------------------


func test_depth_off_makes_the_far_hand_move_exactly_like_the_near_one() -> void:
	# 크기만 작고 궤도가 같으면 **종이 인형 두 장을 겹친 것**으로 보인다.
	# 사이드 사선에서 가장 잘 티 나는 실패라 등식으로 못 박는다.
	var clip := CharAnimProbe.clip()
	var f := AnimFeatures.all_on()
	f.depth = 0.0
	for t in CharAnimProbe.scan_times():
		assert_almost_eq(
			CharAnimProbe.offset(clip, CharPart.Id.HAND_FAR, t, f).y,
			CharAnimProbe.offset(clip, CharPart.Id.HAND_NEAR, t, f).y,
			EPS,
			"앞뒤를 끄면 두 손의 상하가 같아야 한다"
		)


func test_depth_on_shrinks_the_far_hand() -> void:
	var clip := CharAnimProbe.clip()
	var f := AnimFeatures.all_on()
	assert_lt(
		CharAnimProbe.span(clip, CharPart.Id.HAND_FAR, f),
		CharAnimProbe.span(clip, CharPart.Id.HAND_NEAR, f),
		"뒷손이 앞손보다 덜 움직여야 한다"
	)


func test_depth_on_slows_the_far_hand_more_than_it_shrinks_it() -> void:
	# **이것이 「느려 보인다」의 정의다.** 그냥 축소한 궤도라면 속력과 진폭이 같은 비율로
	# 준다. 잔떨림을 더 깎았으므로 속력이 진폭보다 더 많이 줄어야 한다.
	# 이 단정이 없으면 `FAR_FLUTTER` 를 1.0 으로 되돌려도 아무 테스트가 안 걸린다.
	var clip := CharAnimProbe.clip()
	var f := AnimFeatures.all_on()
	var span_ratio := (
		CharAnimProbe.span(clip, CharPart.Id.HAND_FAR, f)
		/ CharAnimProbe.span(clip, CharPart.Id.HAND_NEAR, f)
	)
	var speed_ratio := (
		CharAnimProbe.top_speed(clip, CharPart.Id.HAND_FAR, f)
		/ CharAnimProbe.top_speed(clip, CharPart.Id.HAND_NEAR, f)
	)
	assert_lt(speed_ratio, span_ratio, "속력이 진폭보다 더 줄어야 느려 보인다")


func test_depth_on_delays_the_far_hand_further() -> void:
	var clip := CharAnimProbe.clip()
	var f := AnimFeatures.all_on()
	assert_gt(
		CharAnimProbe.peak_time(clip, CharPart.Id.HAND_FAR, f),
		CharAnimProbe.peak_time(clip, CharPart.Id.HAND_NEAR, f),
		"멀수록 굼떠야 한다"
	)


# --- 정면 문법과의 대조 -----------------------------------------------------


func test_the_front_grammar_control_lifts_the_whole_foot() -> void:
	# 대조군이 실제로 **다른 문법**인지 확인한다. 같으면 나란히 놓는 GIF 가 무의미하다.
	var rig := CharRig.new()
	var side := CharIdleClip.new(rig)
	var front := CharFrontIdleClip.new(rig)
	var f := AnimFeatures.all_on()
	var at := CharIdleClip.LOOP * 0.25
	var part := CharPart.Id.FOOT_FAR

	# 측면: 발끝이 땅에 남는다. 정면: 발이 통째로 떠서 발끝이 땅을 떠난다.
	assert_almost_eq(side.sample(at, f).part_toe(part, rig).y, rig.ground_y(part), 0.001)
	assert_gt(
		front.sample(at, f).part_toe(part, rig).y - rig.ground_y(part), 0.3, "정면 문법은 발을 통째로 들어야 한다"
	)


func test_the_front_grammar_control_ignores_depth() -> void:
	var rig := CharRig.new()
	var front := CharFrontIdleClip.new(rig)
	var f := AnimFeatures.all_on()
	assert_almost_eq(
		CharAnimProbe.span(front, CharPart.Id.HAND_FAR, f),
		CharAnimProbe.span(front, CharPart.Id.HAND_NEAR, f),
		EPS,
		"정면 문법에서는 두 손이 똑같이 움직인다"
	)


# --- 다섯 다 끈 상태 --------------------------------------------------------


func test_everything_off_leaves_a_doll_that_only_bobs() -> void:
	# 조절판의 대조군. **이 상태와의 차이가 이 작업의 전부다.**
	var clip := CharAnimProbe.clip()
	var f := AnimFeatures.all_off()
	for t in CharAnimProbe.scan_times():
		var pose := clip.sample(t, f)
		for part in CharPart.COUNT:
			assert_almost_eq(
				pose.positions[part].x,
				clip.rig.rest_positions[part].x,
				EPS,
				"%s 이 좌우로 움직인다" % CharPart.part_name(part)
			)
			assert_eq(pose.scales[part], Vector2.ONE)
