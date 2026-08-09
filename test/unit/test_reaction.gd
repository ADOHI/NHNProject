extends GutTest
## **반응 층** — 때리다가 맞는 것 (§25.27).
##
## 첫 판은 **감쇠 진동**이었고 **불합격**했다. 타격은 떨림이 아니라 **밀림**이다.
## 이 파일은 그 판정을 자로 굳혀 둔 것이다 — 다시 진동으로 돌아가면 여기서 막힌다.
##
## ```
## 멈춤(히트스톱)  →  밀림(방향, 몸 전체)  →  회복  →  잔진동
## ```


func _swing() -> CharSwingClip:
	return CharSwingClip.new(CharRig.new(), WeaponGuard.Id.HIGH, WeaponGuard.Id.LOW)


func test_the_body_is_pushed_one_way_not_wobbled() -> void:
	# **방향이 있어야 한다.** 진동은 좌우로 넘나들어 방향이 안 읽힌다.
	var reaction := CharReaction.new()
	reaction.strike(0.0, 1.0, -1.0)
	var t := 0.0
	while t < 0.09:
		assert_lt(reaction.root_offset(t).x, 0.0, "t = %.3f 에서 밀린 방향이 뒤집혔다" % t)
		t += 0.005


func test_the_push_is_largest_at_the_moment_of_impact() -> void:
	# **즉시 간다.** 서서히 커지면 「밀렸다」가 아니라 「끌려간다」로 읽힌다.
	var reaction := CharReaction.new()
	reaction.strike(0.0, 1.0)
	var first := absf(reaction.root_offset(0.0).x)
	assert_gt(first, 20.0, "맞는 순간 안 밀린다")
	assert_lt(absf(reaction.root_offset(0.4).x), first * 0.4, "안 돌아온다")


func test_the_root_moves_more_than_the_parts() -> void:
	# **뿌리가 통째로 밀리는 것이 가장 크게 읽힌다.** 파츠 진동보다 먼저다.
	assert_gt(CharReaction.ROOT_PUSH, CharReaction.PART_PUSH, "몸보다 파츠가 더 가면 분해된다")


func test_all_six_parts_start_together() -> void:
	# **밖에서 온 충격은 여섯에 한꺼번에 닿는다.** 시작이 다른 것은 `die` 의 축이다 —
	# 그건 안에서 힘이 빠지는 것이라 축이 다르다.
	var rig := CharRig.new()
	var reaction := CharReaction.new()
	reaction.strike(0.0, 1.0)
	var pose := CharPose.from_rig(rig)
	reaction.apply(pose, 0.0, rig)
	for part in CharPart.COUNT:
		assert_lt(pose.rotations[part], 0.0, "파츠 %d 가 같이 안 움직였다" % part)


func test_hitstop_freezes_the_swing() -> void:
	# **맞는 순간 동작 진행 자체가 멈춘다.** 안 그러면 「안 맞은 것 같다」.
	var reaction := CharReaction.new()
	assert_almost_eq(reaction.stalled(0.5), 0.0, 0.0001, "안 맞았는데 멈춘다")
	reaction.strike(0.2, 1.0)
	assert_almost_eq(reaction.stalled(0.2), 0.0, 0.0001, "맞기 전부터 멈춘다")
	var held := reaction.stalled(0.5)
	assert_gt(held, 0.03, "맞아도 안 멈춘다")
	assert_almost_eq(held, CharReaction.STOP_SECONDS, 0.001, "멈춘 시간이 다르다")
	# 멈춤은 **끝난다.** 안 풀리면 동작이 영영 안 나간다.
	assert_almost_eq(reaction.stalled(2.0), held, 0.0001, "히트스톱이 안 풀린다")


func test_the_wobble_only_comes_after_the_push() -> void:
	# **진동은 꼬리에만.** 처음부터 떨면 밀림이 안 읽힌다.
	assert_gt(CharReaction.WOBBLE_AFTER, 0.0, "꼬리 진동이 처음부터 나온다")
	assert_lt(CharReaction.WOBBLE, 0.5, "꼬리가 밀림보다 크면 진동으로 읽힌다")


func test_being_hit_does_not_stop_the_pose_from_being_computed() -> void:
	# 전환이 없다는 것이 이 층의 전부다. 스윙 자세는 계속 계산된다.
	var clip := _swing()
	var f := AnimFeatures.all_on()
	var at := clip.anticipate * 0.5
	var clean := clip.sample(at, f)
	var reaction := CharReaction.new()
	reaction.strike(at, 0.8)
	var shaken := clip.sample(at, f)
	reaction.apply(shaken, at + 0.02, clip.rig)
	var moved := shaken.positions[CharPart.Id.TORSO].distance_to(clean.positions[CharPart.Id.TORSO])
	assert_gt(moved, 0.5, "충격이 안 얹혔다")
	assert_lt(moved, 30.0, "충격이 자세를 통째로 갈아치웠다")


func test_many_hits_do_not_make_it_explode() -> void:
	# **누적이 폭주하면 캐릭터가 발작한다.** 상한이 있어야 어느 선에서 멈춘다.
	var reaction := CharReaction.new()
	for i in 40:
		reaction.strike(float(i) * 0.01, 1.0)
	var rig := CharRig.new()
	var pose := CharPose.from_rig(rig)
	var rest := rig.rest_positions[CharPart.Id.TORSO]
	reaction.apply(pose, 0.25, rig)
	assert_lt(pose.positions[CharPart.Id.TORSO].distance_to(rest), CharReaction.PART_PUSH * 2.0)
	assert_lt(absf(reaction.root_offset(0.25).x), CharReaction.ROOT_PUSH * 2.0, "뿌리가 폭주했다")


func test_the_parts_do_not_all_settle_alike() -> void:
	# 시작은 같고 **감쇠만 다르다** — 머리가 오래 남고 발이 먼저 선다.
	assert_lt(
		CharReaction.RETURN[CharPart.Id.HEAD],
		CharReaction.RETURN[CharPart.Id.FOOT_NEAR],
		"머리가 발보다 오래 남아야 한다"
	)


func test_nothing_sinks_no_matter_what_is_added() -> void:
	# **더한 결과가 파고들 수 있다.** 재서 올리는 방식이라 무엇을 더했든 잡힌다.
	var rig := CharRig.new()
	var clip := _swing()
	var f := AnimFeatures.all_on()
	var reaction := CharReaction.new()
	reaction.strike(0.0, 1.5)
	reaction.strike(0.04, 1.5)
	var t := 0.0
	while t <= clip.loop_seconds():
		var pose := clip.sample(t, f)
		reaction.apply(pose, t, rig)
		for part in CharPart.COUNT:
			if CharPart.is_foot(part):
				assert_lte(pose.sink_depth(part, rig), 0.001, "t = %.3f 에서 발이 파고든다" % t)
		t += 0.01


func test_a_hit_cannot_stretch_the_arms_past_the_limit() -> void:
	# **더한 뒤에 잰다.** 충격이 손을 팔 길이 밖으로 밀어낼 수 있다 (§25.29).
	var rig := CharRig.new()
	var clip := _swing()
	var f := AnimFeatures.all_on()
	var reaction := CharReaction.new()
	reaction.strike(0.0, 2.0)
	var t := 0.0
	while t <= clip.loop_seconds():
		var pose := clip.sample(t, f)
		reaction.apply(pose, t, rig)
		# **손만 본다.** 발은 땅이 잡고 있어서 반응 층도 안 끌어당긴다.
		for part in [CharPart.Id.HAND_NEAR, CharPart.Id.HAND_FAR]:
			var over := pose.overreach(part, rig, rig.reach_limit(part))
			assert_almost_eq(over, 0.0, 0.5, "t = %.3f 에서 충격이 팔을 늘렸다" % t)
		t += 0.01


func test_spent_hits_are_forgotten_so_the_list_cannot_grow() -> void:
	# 안 버리면 목록이 무한히 늘어 **오래 싸울수록 느려진다.**
	var reaction := CharReaction.new()
	for i in 20:
		reaction.strike(float(i) * 0.001, 1.0)
	assert_false(reaction.is_quiet(), "방금 맞았는데 조용하다")
	reaction.forget_spent(5.0)
	assert_true(reaction.is_quiet(), "잦아든 충격이 안 버려진다")


func test_clearing_drops_everything() -> void:
	# 상태가 바뀔 때 지운다 — 그쪽 클립이 이미 큰 반응을 갖고 있다.
	var reaction := CharReaction.new()
	reaction.strike(0.0, 1.0)
	reaction.clear()
	assert_true(reaction.is_quiet(), "지웠는데 남아 있다")
	assert_almost_eq(reaction.load_at(0.05), 0.0, 0.0001, "지웠는데 값이 남아 있다")
