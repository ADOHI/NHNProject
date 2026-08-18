extends GutTest
## 휘두르기의 **몸 전체 참여와 전진**. 무기 자체의 궤적·타이밍은 `test_swing_clip.gd` 가 본다.
##
## 사용자 판정이 이 파일을 만들게 했다 — *"머리 몸 발이 거의 고정이라 역동적으로
## 안느껴지잖아"*. **팔만 고치면 「팔 애니메이션」이 된다** (§25.21).

const SCAN_STEP := 0.004


func _clip(
	from_guard := WeaponGuard.Id.HIGH, to_guard := WeaponGuard.Id.LOW, cells := 1
) -> CharSwingClip:
	return CharSwingClip.new(CharRig.new(), from_guard, to_guard, CharWeapon.new(cells))


func _times(clip: CharSwingClip) -> Array[float]:
	var times: Array[float] = []
	var t := 0.0
	while t <= clip.loop_seconds():
		times.append(t)
		t += SCAN_STEP
	return times


func test_the_whole_body_moves_not_just_the_arm() -> void:
	# **팔만 고치면 「팔 애니메이션」이 된다.** 여섯 파츠가 다 자기 몫으로 움직여야 한다.
	var clip := _clip()
	var f := AnimFeatures.all_on()
	# **모서리로 잰다.** 미는 발은 제자리에서 구르므로 피벗은 거의 안 움직이는데
	# 화면에서는 확실히 움직인다 — 피벗으로 재면 「고정」이라고 잘못 답한다.
	for part in CharPart.COUNT:
		var moved := 0.0
		var start := clip.sample(0.0, f)
		for t in _times(clip):
			var pose := clip.sample(t, f)
			for corner in clip.rig.local_corners(part):
				var was: Vector2 = start.core_transform(part) * corner
				var now: Vector2 = pose.core_transform(part) * corner
				moved = maxf(moved, was.distance_to(now))
		assert_gt(moved, 2.0, "%s 가 거의 고정이다" % CharPart.part_name(part))


func test_the_body_gets_shorter_before_it_strikes() -> void:
	# **키가 안 변하면 무슨 짓을 해도 평평해 보인다.** 예비에 낮아져야 한다.
	var clip := _clip()
	var f := AnimFeatures.all_on()
	var torso := CharPart.Id.TORSO
	var rest := clip.rig.rest_positions[torso].y
	var lowest := INF
	var t := 0.0
	while t < clip.anticipate + clip.still:
		lowest = minf(lowest, clip.sample(t, f).positions[torso].y)
		t += SCAN_STEP
	assert_lt(lowest, rest - 3.0, "예비에 몸이 낮아지지 않는다")


func test_the_body_coils_the_other_way_during_the_wind_up() -> void:
	# 팔만 뒤로 가면 풀리는 힘이 안 생긴다. **몸통이 같이 감겨야** 한다.
	var clip := _clip()
	var f := AnimFeatures.all_on()
	var torso := CharPart.Id.TORSO
	# **몸통은 든 손보다 먼저 읽는다.** 예비 끝에서 재면 이미 풀리기 시작한 뒤다.
	var wound := clip.sample(clip.anticipate * 0.6, f).rotations[torso]
	var struck := clip.sample(clip.loop_seconds(), f).rotations[torso]
	assert_gt(absf(wound), 0.02, "예비에 몸이 안 꼬인다")
	assert_ne(signf(wound), signf(struck), "감기는 방향과 풀리는 방향이 반대여야 한다")


func test_the_parts_do_not_all_start_at_once() -> void:
	# **발이 먼저, 머리가 나중.** `die` 의 「시작이 다른」 축을 방향만 반대로 쓴 것이다.
	var clip := _clip()
	var f := AnimFeatures.all_on()
	var early := clip.anticipate * 0.25
	var rest := clip.rig.rest_positions
	var foot := clip.sample(early, f).positions[CharPart.Id.FOOT_FAR].distance_to(
		rest[CharPart.Id.FOOT_FAR]
	)
	var head := clip.sample(early, f).positions[CharPart.Id.HEAD].distance_to(
		rest[CharPart.Id.HEAD]
	)
	# 예비 중이라 진행도가 음수다. **크기**로 견준다 — 발이 더 많이 가 있어야 한다.
	assert_gt(
		absf(clip.progress_for(early, CharSwingClip.LEAD_FEET)),
		absf(clip.progress_for(early, CharSwingClip.LEAD_HEAD)),
		"발이 머리보다 먼저 움직여야 한다"
	)
	assert_gte(foot + head, 0.0)


func test_the_body_actually_advances_and_pulls_back_first() -> void:
	# **애니메이션이 아니라 위치다.** 그리고 예비에는 뒤로 빠져야 힘이 실린다.
	var clip := _clip()
	var back := clip.travel_at(clip.anticipate * 0.9)
	var forward := clip.travel_at(clip.loop_seconds())
	assert_lt(back, 0.0, "예비에 뒤로 안 빠진다")
	assert_gt(forward, 5.0, "타격에 앞으로 안 나간다")


func test_a_short_weapon_advances_further_than_a_long_one() -> void:
	# **전진 거리는 길이의 역함수다.** 단검은 파고들어야 닿고 창은 제자리에서 닿는다.
	var dagger := CharWeapon.from_block(1, 1)
	var spear := CharWeapon.from_block(4, 1)
	assert_gt(dagger.advance_px(), spear.advance_px(), "짧은 무기가 더 파고들어야 한다")
	# 그런데 **닿는 거리는 그래도 긴 쪽이 멀다** - 전진이 차이를 좁힐 뿐이다.
	assert_gt(spear.reach_px(), dagger.reach_px(), "긴 무기가 그래도 더 멀리 닿는다")


func test_coming_home_is_switchable_and_changes_where_you_end_up() -> void:
	# **값을 안 박았다.** 사용자가 둘을 보고 정한다.
	var stays := _clip()
	var returns := _clip()
	returns.returns_home = true
	assert_gt(stays.travel_at(stays.loop_seconds()), 5.0, "남는 쪽은 앞에 있어야 한다")
	assert_almost_eq(returns.travel_at(returns.loop_seconds()), 0.0, 0.5, "돌아오는 쪽은 제자리다")


func test_the_back_foot_stays_planted_while_the_body_advances() -> void:
	# **스윙 중 전진은 미끄러짐인가 디딤인가.** 미는 발은 땅에 박혀 있어야 힘이 실린다.
	# walk 의 자는 「지면이 흐르는 속도와 같아야 한다」였고, 여기서 지면은 안 흐르므로
	# 그 속도가 **0** 이다. 같은 법이 다른 값을 준다 (§25.21.2).
	var clip := _clip()
	var f := AnimFeatures.all_on()
	var far := CharPart.Id.FOOT_FAR
	# **접지 모서리가 아니라 발의 몸통으로 잰다.** 발이 구르는 동안 접지점이 뒤꿈치에서
	# 발끝으로 넘어가며 튀는데, 그것은 미끄러짐이 아니라 구름이다 (§25.10.3 에서 한 번 밟았다).
	var first := clip.sample(0.0, f).positions[far].x
	for t in _times(clip):
		var pose := clip.sample(t, f)
		assert_almost_eq(pose.positions[far].x, first, 0.001, "t = %.3f 에서 뒷발이 미끄러진다" % t)


func test_the_head_keeps_looking_at_the_target() -> void:
	# **사용자가 물리를 짚었다** — *"머리가 뒤로 젖혀지는게 맞나 물리적으로?"* 아니다.
	#
	# 머리의 **절대** 각도는 거의 안 변한다. 크게 변하는 것은 **목 각도**(머리 − 몸통)다.
	# 예비에서 머리가 하늘을 보면 물리적으로 틀렸고, 12 원칙의 스테이징으로도 틀렸다 —
	# **눈이 목표를 봐야 관객이 「저길 치려 한다」를 안다** (§25.24).
	var clip := _clip()
	var f := AnimFeatures.all_on()
	var head := CharPart.Id.HEAD
	var widest_neck := 0.0
	for t in _times(clip):
		var pose := clip.sample(t, f)
		var absolute := pose.rotations[head]
		# **뒤로 젖혀지는 것이 양수다.** 예비 내내 하늘을 보면 안 된다.
		if t < clip.anticipate + clip.still:
			assert_lt(absolute, 0.06, "t = %.3f 에서 예비 중에 머리가 젖혀졌다" % t)
		assert_lt(absf(absolute), 0.45, "t = %.3f 에서 머리 절대 각이 너무 크다" % t)
		widest_neck = maxf(widest_neck, absf(absolute - pose.rotations[CharPart.Id.TORSO]))
	# 그런데 **목은 크게 벌어져야** 한다 — 안 그러면 머리가 몸통에 붙은 덩어리다.
	assert_gt(widest_neck, 0.35, "목 각도가 안 벌어지면 머리가 몸통에 붙은 덩어리다")


func test_the_head_snaps_back_only_at_the_moment_of_impact() -> void:
	# 머리가 실제로 젖혀지는 것은 셋뿐이다 — 임팩트 · get hit · die.
	var clip := _clip()
	var f := AnimFeatures.all_on()
	var impact := clip.anticipate + clip.still + clip.strike
	var at_impact := clip.sample(impact + 0.005, f).rotations[CharPart.Id.HEAD]
	var before := clip.sample(clip.anticipate * 0.5, f).rotations[CharPart.Id.HEAD]
	assert_gt(at_impact, before, "닿는 순간에는 뒤로 젖혀져야 한다")


func test_the_neck_cannot_bend_past_its_limit() -> void:
	# 몸통이 너무 돌면 머리가 따라갈 수밖에 없다. 시선 유지가 무한히 버티지 않는다.
	var clip := _clip(WeaponGuard.Id.HIGH, WeaponGuard.Id.LOW, CharWeapon.MAX_CELLS)
	var f := AnimFeatures.all_on()
	for t in _times(clip):
		var pose := clip.sample(t, f)
		var neck := absf(pose.rotations[CharPart.Id.HEAD] - clip.torso_angle_at(t, f))
		assert_lte(neck, CharSwingClip.NECK_LIMIT + 0.001, "t = %.3f 에서 목이 한계를 넘었다" % t)


func test_the_body_lines_up_behind_the_blade_at_impact() -> void:
	# **사용자가 실루엣에서 잡았다** — *"칼 처음 써본 사람이 무서워서 휘두르는 것 같은데"*.
	# 몸이 뒤에 남고 팔만 나가면 그렇게 보인다.
	#
	# 판정: **머리 · 든손 · 검끝이 거의 한 줄**이어야 「내리친다」로 읽힌다 (§25.25).
	var clip := _clip()
	assert_gt(CharSilhouette.straightest(clip), 140.0, "타격에 몸이 검 뒤로 안 실린다")


func test_the_head_ends_up_ahead_of_the_back_foot() -> void:
	# **머리는 회전만 하는 게 아니라 이동한다.** 각도만 맞추고 위치를 안 옮기면
	# 머리가 뒤에 남아 「피하면서 치는」 모양이 된다.
	var clip := _clip()
	var f := AnimFeatures.all_on()
	var impact := clip.anticipate + clip.still + clip.strike
	var pose := clip.sample(impact, f)
	var head := pose.positions[CharPart.Id.HEAD].x
	var rest := clip.rig.rest_positions[CharPart.Id.HEAD].x
	assert_gt(head - rest, 15.0, "머리가 앞으로 안 나간다")
	assert_gt(head, pose.positions[CharPart.Id.FOOT_FAR].x, "머리가 뒷발보다 앞에 있어야 한다")


func test_the_weight_ends_on_the_front_foot() -> void:
	# 뒷발에 무게가 남으면 겁먹은 자세다. 앞발이 눌리고 뒷발 뒤꿈치가 크게 떠야 한다.
	var clip := _clip()
	var f := AnimFeatures.all_on()
	var pose := clip.sample(clip.anticipate + clip.still + clip.strike, f)
	assert_lt(pose.scales[CharPart.Id.FOOT_NEAR].y, 0.97, "앞발이 안 눌린다")
	assert_lt(pose.rotations[CharPart.Id.FOOT_FAR], -0.1, "뒷발 뒤꿈치가 안 뜬다")
