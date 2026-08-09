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
