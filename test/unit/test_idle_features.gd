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
		assert_almost_eq(CharAnimProbe.offset(clip, CharPart.Id.HAND_R, t, f).x, 0.0, EPS)
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


func test_asymmetry_off_makes_both_hands_rise_identically() -> void:
	var clip := CharAnimProbe.clip()
	var f := AnimFeatures.all_on()
	f.asymmetry = 0.0
	for t in CharAnimProbe.scan_times():
		assert_almost_eq(
			CharAnimProbe.offset(clip, CharPart.Id.HAND_L, t, f).y,
			CharAnimProbe.offset(clip, CharPart.Id.HAND_R, t, f).y,
			EPS,
			"비대칭을 끄면 두 손이 같아야 한다"
		)


func test_asymmetry_on_separates_the_two_hands() -> void:
	# 값만 다르고 위상이 같으면 이 테스트를 통과하지 못한다.
	var clip := CharAnimProbe.clip()
	var f := AnimFeatures.all_on()
	var widest := 0.0
	for t in CharAnimProbe.scan_times():
		var gap := (
			CharAnimProbe.offset(clip, CharPart.Id.HAND_L, t, f).y
			- CharAnimProbe.offset(clip, CharPart.Id.HAND_R, t, f).y
		)
		widest = maxf(widest, absf(gap))
	assert_gt(widest, 1.0, "두 손이 1 px 도 안 어긋나면 좌우가 살아 있지 않다")


func test_asymmetry_off_stops_the_feet_dead() -> void:
	var clip := CharAnimProbe.clip()
	var f := AnimFeatures.all_on()
	f.asymmetry = 0.0
	for t in CharAnimProbe.scan_times():
		var pose := clip.sample(t, f)
		for part: CharPart.Id in [CharPart.Id.FOOT_L, CharPart.Id.FOOT_R]:
			assert_eq(pose.positions[part], clip.rig.rest_positions[part])
			assert_eq(pose.rotations[part], 0.0)
			assert_eq(pose.scales[part], Vector2.ONE)


func test_asymmetry_on_shifts_weight_between_the_feet() -> void:
	var clip := CharAnimProbe.clip()
	var f := AnimFeatures.all_on()
	# 무게가 오른쪽에 실리는 순간(`drift` 최대)에는 오른발이 눌리고 왼발이 들린다.
	var pose := clip.sample(CharIdleClip.LOOP * 0.25, f)
	assert_lt(pose.scales[CharPart.Id.FOOT_R].y, 1.0, "실린 발은 눌려야 한다")
	assert_gt(
		pose.positions[CharPart.Id.FOOT_L].y,
		clip.rig.rest_positions[CharPart.Id.FOOT_L].y,
		"무게가 빠진 발은 들려야 한다"
	)


# --- 넷 다 끈 상태 ----------------------------------------------------------


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
