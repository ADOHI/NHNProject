extends GutTest
## idle 의 파형과 접지를 잡는다. 조절판 스위치는 `test_idle_features.gd` 가 본다.
##
## **"항상 참인 단정" 을 피하는 것이 이 파일의 규칙이다.** 각 테스트가 어떤 실패를
## 막는지 이름과 메시지에 적었다.

const EPS := 0.0001

# --- 루프 -------------------------------------------------------------------


func test_the_loop_seam_closes_exactly() -> void:
	# 주파수가 한 바퀴당 정수 회가 아니면 여기서 걸린다. GIF 이음매가 툭 끊기는 실패다.
	var clip := CharAnimProbe.clip()
	var f := AnimFeatures.all_on()
	var first := clip.sample(0.0, f)
	var last := clip.sample(CharIdleClip.LOOP, f)
	for part in CharPart.COUNT:
		assert_almost_eq(last.positions[part].x, first.positions[part].x, 0.001)
		assert_almost_eq(last.positions[part].y, first.positions[part].y, 0.001)
		assert_almost_eq(last.rotations[part], first.rotations[part], 0.001)
		assert_almost_eq(last.scales[part].y, first.scales[part].y, 0.001)


func test_the_clip_actually_moves() -> void:
	# 아무것도 안 하는 클립이 위의 테스트를 모두 통과할 수 있다. 그것을 막는다.
	var clip := CharAnimProbe.clip()
	var span := CharAnimProbe.span(clip, CharPart.Id.HEAD, AnimFeatures.all_on())
	assert_gt(span, 3.0, "머리가 3 px 도 안 움직이면 호흡이 안 보인다")


func test_wrap_time_folds_into_one_loop() -> void:
	var clip := CharAnimProbe.clip()
	assert_almost_eq(clip.wrap_time(CharIdleClip.LOOP + 0.5), 0.5, EPS)
	assert_almost_eq(clip.wrap_time(-0.5), CharIdleClip.LOOP - 0.5, EPS)


# --- 지연 -------------------------------------------------------------------


func test_delay_off_puts_the_head_in_phase_with_the_torso() -> void:
	var clip := CharAnimProbe.clip()
	var f := AnimFeatures.all_off()
	for t in CharAnimProbe.scan_times():
		var head := CharAnimProbe.offset(clip, CharPart.Id.HEAD, t, f).y / CharIdleClip.HEAD_RISE
		var torso := CharAnimProbe.offset(clip, CharPart.Id.TORSO, t, f).y / CharIdleClip.TORSO_RISE
		assert_almost_eq(head, torso, 0.001, "지연을 끄면 위상이 같아야 한다")


func test_delay_on_makes_the_head_peak_later_than_the_torso() -> void:
	# 부호가 반대면 머리가 몸보다 **먼저** 움직인다 — 어색함만 남고 원인이 안 보인다.
	var clip := CharAnimProbe.clip()
	var f := AnimFeatures.all_on()
	var torso_peak := CharAnimProbe.peak_time(clip, CharPart.Id.TORSO, f)
	var head_peak := CharAnimProbe.peak_time(clip, CharPart.Id.HEAD, f)
	assert_gt(head_peak, torso_peak, "머리가 몸보다 늦게 최고점에 닿아야 한다")
	assert_almost_eq(head_peak - torso_peak, CharIdleClip.HEAD_RISE_DELAY, 0.02)


func test_the_hands_lag_further_behind_than_the_head() -> void:
	# 붙어 있지 않은 파츠가 더 늦어야 무게가 읽힌다. 순서가 뒤집히면 그냥 어긋나 보인다.
	var clip := CharAnimProbe.clip()
	var f := AnimFeatures.all_on()
	assert_gt(
		CharAnimProbe.peak_time(clip, CharPart.Id.HAND_FAR, f),
		CharAnimProbe.peak_time(clip, CharPart.Id.HEAD, f),
		"손이 머리보다 늦어야 한다"
	)


func test_the_hands_float_higher_than_the_body() -> void:
	# 떠 있는 손은 부표처럼 몸보다 크게 떠야 예쁘다 (물리가 아니라 미감으로 고른 값이다).
	# 뒤집히면 손이 몸에 매달린 것으로 보이고, 팔이 없는 것이 어색함으로 읽힌다.
	var clip := CharAnimProbe.clip()
	var f := AnimFeatures.all_on()
	var torso := CharAnimProbe.span(clip, CharPart.Id.TORSO, f)
	assert_gt(CharAnimProbe.span(clip, CharPart.Id.HAND_NEAR, f), torso, "손이 몸보다 크게 떠야 한다")
	assert_gt(CharAnimProbe.span(clip, CharPart.Id.HEAD, f), torso)


# --- 호 ---------------------------------------------------------------------


func test_arc_on_makes_the_head_trace_a_figure_eight() -> void:
	# 좌우가 상하의 **절반** 주기여야 8 자가 된다. 같은 주기면 사선 왕복(1 자)이다.
	var clip := CharAnimProbe.clip()
	var f := AnimFeatures.all_on()
	var offsets: Array[Vector2] = []
	for t in CharAnimProbe.scan_times():
		offsets.append(CharAnimProbe.offset(clip, CharPart.Id.HEAD, t, f))
	assert_eq(CharAnimProbe.sign_changes(offsets, true), 2, "좌우는 한 바퀴에 두 번만 0 을 지나야 한다")
	assert_eq(CharAnimProbe.sign_changes(offsets, false), 4, "상하는 좌우의 두 배로 0 을 지나야 한다")


# --- 배율 -------------------------------------------------------------------


func test_squash_preserves_area() -> void:
	var clip := CharAnimProbe.clip()
	var f := AnimFeatures.all_on()
	for t in CharAnimProbe.scan_times():
		var pose := clip.sample(t, f)
		for part in CharPart.COUNT:
			var s := pose.scales[part]
			assert_almost_eq(s.x * s.y, 1.0, 0.00001, "부피가 안 지켜지면 파츠가 커지거나 작아진다")


func test_squash_on_actually_deforms_the_torso() -> void:
	var clip := CharAnimProbe.clip()
	var f := AnimFeatures.all_on()
	var span := 0.0
	for t in CharAnimProbe.scan_times():
		span = maxf(span, absf(clip.sample(t, f).scales[CharPart.Id.TORSO].y - 1.0))
	assert_gt(span, 0.02, "몸이 안 늘어나면 호흡이 위치 이동만으로 보인다")


func test_the_head_squashes_against_the_torso_stretch() -> void:
	# 같은 방향으로 늘어나면 가속이 안 보인다. 부호가 반대여야 한다.
	var clip := CharAnimProbe.clip()
	var f := AnimFeatures.all_on()
	f.delay = 0.0
	var pose := clip.sample(0.5, f)
	assert_gt(pose.scales[CharPart.Id.TORSO].y - 1.0, 0.0)
	assert_lt(pose.scales[CharPart.Id.HEAD].y - 1.0, 0.0, "몸이 늘어날 때 머리는 눌려야 한다")


# --- 접지 -------------------------------------------------------------------


func test_no_part_ever_sinks_into_its_ground() -> void:
	var clip := CharAnimProbe.clip()
	var f := AnimFeatures.all_on()
	for t in CharAnimProbe.scan_times():
		assert_lte(clip.sample(t, f).deepest_sink(clip.rig), EPS, "t = %.3f 에서 파츠가 땅을 파고든다" % t)


func test_the_loaded_foot_stays_exactly_on_its_ground() -> void:
	# 피벗이 중심에 있으면 눌리는 발이 땅에서 뜬다. 그것을 막는 단정이다.
	var clip := CharAnimProbe.clip()
	var rig := clip.rig
	var pose := clip.sample(CharIdleClip.LOOP * 0.25, AnimFeatures.all_on())
	var part := CharPart.Id.FOOT_NEAR
	assert_almost_eq(pose.part_bottom(part, rig).y, rig.ground_y(part), EPS)


func test_the_freed_foot_lifts_its_heel_and_keeps_its_toe_down() -> void:
	# **측면 문법의 핵심.** 정면에서는 발이 통째로 들렸다. 옆에서 그렇게 하면 발이
	# 공중에서 평행이동해 서 있는 것으로 안 보인다.
	#
	# 이 단정이 없으면 회전 보정을 빼먹어도 눈으로는 잘 안 걸린다 — 발끝이 땅에
	# 박히는 것은 안 보이고 발이 미끄러지는 느낌으로만 남는다.
	var clip := CharAnimProbe.clip()
	var rig := clip.rig
	# 무게가 앞으로 실리는 순간이면 뒷발이 자유로워진다.
	var pose := clip.sample(CharIdleClip.LOOP * 0.25, AnimFeatures.all_on())
	var part := CharPart.Id.FOOT_FAR
	assert_almost_eq(pose.part_toe(part, rig).y, rig.ground_y(part), 0.001, "발끝은 땅에 붙어 있어야 한다")
	assert_gt(pose.part_bottom(part, rig).y, rig.ground_y(part), "뒤꿈치 쪽은 들려야 한다")
	assert_lt(pose.rotations[part], 0.0, "뒤꿈치를 들려면 시계 방향으로 돌아야 한다")


func test_the_feet_do_not_breathe() -> void:
	# 발까지 같이 떠 있으면 캐릭터가 땅에 서 있지 않고 물에 떠 있다.
	#
	# 호흡이 발에 새어 들면 **두 발이 같이** 올라간다. 그래서 "항상 한 발은 쉬는 높이에
	# 그대로 있다" 가 그 누출을 정확히 잡는다. 무게 이동은 한쪽만 들어 올리기 때문이다.
	var clip := CharAnimProbe.clip()
	var f := AnimFeatures.all_on()
	for t in CharAnimProbe.scan_times():
		var far := CharAnimProbe.offset(clip, CharPart.Id.FOOT_FAR, t, f).y
		var near := CharAnimProbe.offset(clip, CharPart.Id.FOOT_NEAR, t, f).y
		assert_almost_eq(minf(far, near), 0.0, EPS, "t = %.3f 에서 두 발이 같이 떴다" % t)
		assert_gte(maxf(far, near), 0.0, "발이 쉬는 높이보다 내려가면 안 된다")


func test_the_weight_travels_fore_and_aft() -> void:
	# 몸이 앞으로 나가 있는 순간에는 **앞발**이 눌려 있어야 한다.
	# 부호가 어긋나면 몸과 발이 따로 놀고, 그건 눈으로 "뭔가 이상하다" 로만 보인다.
	var clip := CharAnimProbe.clip()
	var f := AnimFeatures.all_on()
	var forward_t := 0.0
	var furthest := -INF
	for t in CharAnimProbe.scan_times():
		var x := CharAnimProbe.offset(clip, CharPart.Id.TORSO, t, f).x
		if x > furthest:
			furthest = x
			forward_t = t
	var pose := clip.sample(forward_t, f)
	assert_lt(pose.scales[CharPart.Id.FOOT_NEAR].y, 1.0, "몸이 앞에 있으면 앞발이 눌려야 한다")
	assert_lt(pose.rotations[CharPart.Id.FOOT_FAR], 0.0, "그때 뒷발의 뒤꿈치가 들려야 한다")
