extends GutTest
## run 과 jump — **둘 다 새 구조가 필요 없다는 주장**을 검사한다.
##
## run 은 walk 의 값만 갈아 끼운 것이고, jump 는 `get hit` 의 포물선에 **예비**를 붙인 것이다.
## 그 주장이 참이려면 **walk 의 규칙이 run 에서도 그대로 성립해야 한다** — 특히
## 디딘 발의 등속이. 값만 바꿨는데 규칙이 깨졌다면 그건 값이 아니라 문법을 바꾼 것이다.

const SCAN_STEP := 0.004


func _times(clip: CharClip) -> Array[float]:
	var times: Array[float] = []
	var t := 0.0
	while t < clip.loop_seconds():
		times.append(t)
		t += SCAN_STEP
	return times


func test_running_has_a_moment_with_both_feet_off_the_ground() -> void:
	# **이것이 걷기와 달리기를 가르는 유일한 값이다.** walk 는 이 순간이 없다고 단정한다.
	var clip := CharRunClip.new(CharRig.new())
	var f := AnimFeatures.all_on()
	var airborne_moments := 0
	for t in _times(clip):
		var pose := clip.sample(t, f)
		var up := 0
		for part: CharPart.Id in [CharPart.Id.FOOT_NEAR, CharPart.Id.FOOT_FAR]:
			if pose.part_ground_point(part, clip.rig).y - clip.rig.ground_y(part) > 0.01:
				up += 1
		if up == 2:
			airborne_moments += 1
	assert_gt(airborne_moments, 0, "두 발이 다 뜨는 순간이 없으면 그건 걷기다")


func test_running_keeps_the_planted_foot_travelling_at_a_constant_speed() -> void:
	# **값만 바꿨다는 주장의 핵심.** 규칙이 깨졌다면 값이 아니라 문법을 바꾼 것이다.
	var clip := CharRunClip.new(CharRig.new())
	var f := AnimFeatures.all_on()
	var steps: Array[float] = []
	var previous := INF
	for t in _times(clip):
		var pose := clip.sample(t, f)
		if pose.part_ground_point(CharPart.Id.FOOT_NEAR, clip.rig).y > 0.01:
			previous = INF
			continue
		if previous != INF:
			steps.append(pose.positions[CharPart.Id.FOOT_NEAR].x - previous)
		previous = pose.positions[CharPart.Id.FOOT_NEAR].x
	assert_gt(steps.size(), 30, "디딤 표본이 너무 적다")
	var low := INF
	var high := -INF
	for step in steps:
		low = minf(low, step)
		high = maxf(high, step)
	assert_lt(high - low, 0.02, "달릴 때도 디딘 발은 등속이어야 한다")


func test_running_takes_longer_steps_and_leans_further() -> void:
	var walk := CharWalkClip.new(CharRig.new())
	var run := CharRunClip.new(CharRig.new())
	assert_gt(run.step_length, walk.step_length, "달리면 보폭이 커야 한다")
	assert_gt(run.torso_lean, walk.torso_lean, "달리면 더 앞으로 기울어야 한다")
	assert_lt(run.stride, walk.stride, "달리면 한 걸음이 짧아야 한다")
	assert_lt(run.stance, 0.5, "디딤 비율이 0.5 를 넘으면 체공이 안 생긴다")
	assert_gt(walk.stance, 0.5, "걷기는 양발 지지가 있어야 한다")


func test_neither_gait_ever_sinks() -> void:
	for clip: CharClip in [CharWalkClip.new(CharRig.new()), CharRunClip.new(CharRig.new())]:
		for t in _times(clip):
			assert_lte(
				clip.sample(t, AnimFeatures.all_on()).deepest_sink(clip.rig),
				0.0001,
				"%s 의 t = %.3f 에서 파고든다" % [clip.clip_name(), t]
			)


func test_the_jump_crouches_before_it_rises() -> void:
	# **예비가 없으면 갑자기 떠오른다.** 맞는 것과 뛰는 것의 유일한 차이가 이것이다.
	var clip := CharJumpClip.new(CharRig.new())
	var f := AnimFeatures.all_on()
	var rest := clip.rig.rest_positions[CharPart.Id.TORSO].y
	var lowest := INF
	var lowest_at := 0.0
	for t in _times(clip):
		var y := clip.sample(t, f).positions[CharPart.Id.TORSO].y
		if y < lowest:
			lowest = y
			lowest_at = t
	assert_lt(lowest, rest - 3.0, "웅크리지 않으면 예비가 없는 것이다")
	assert_lt(lowest_at, CharJumpClip.CROUCH + 0.01, "가장 낮은 순간이 예비 안에 있어야 한다")


func test_the_jump_leaves_the_ground_and_returns() -> void:
	var clip := CharJumpClip.new(CharRig.new())
	assert_almost_eq(clip.lift(0.0), 0.0, 0.0001, "웅크리는 동안에는 안 뜬다")
	assert_gt(clip.lift(CharJumpClip.CROUCH + CharJumpClip.AIR * 0.5), 40.0, "꼭대기가 너무 낮다")
	assert_almost_eq(clip.lift(clip.loop_seconds()), 0.0, 0.0001, "끝에 땅에 있어야 한다")


func test_the_landing_springs_back_past_neutral() -> void:
	# **지수 접근으로는 만들 수 없는 값이다.** 착지의 되튐이 0 을 지나쳐야 한다.
	var clip := CharJumpClip.new(CharRig.new())
	var lowest := 0.0
	var t := CharJumpClip.CROUCH + CharJumpClip.AIR
	while t < clip.loop_seconds():
		lowest = minf(lowest, clip.recoil(t))
		t += SCAN_STEP
	assert_lt(lowest, -0.01, "착지 뒤에 되펴지지 않으면 되튐이 아니다")
	assert_almost_eq(clip.recoil(clip.loop_seconds()), 0.0, 0.001, "끝에는 앉아 있어야 한다")


func test_the_jump_never_sinks_and_does_not_loop() -> void:
	var clip := CharJumpClip.new(CharRig.new())
	assert_false(clip.is_looping(), "뛰기는 루프가 아니다")
	for f: AnimFeatures in [AnimFeatures.all_on(), AnimFeatures.all_off()]:
		for t in _times(clip):
			assert_lte(clip.sample(t, f).deepest_sink(clip.rig), 0.0001, "t = %.3f 에서 파고든다" % t)


func test_the_head_trails_the_body_on_the_way_up() -> void:
	# 머리가 몸과 정확히 같이 뜨면 한 덩어리가 올라가는 것으로 보인다.
	var clip := CharJumpClip.new(CharRig.new())
	var rig := clip.rig
	var at := CharJumpClip.CROUCH + 0.05
	var with_delay := clip.sample(at, AnimFeatures.all_on())
	var head := with_delay.positions[CharPart.Id.HEAD].y - rig.rest_positions[CharPart.Id.HEAD].y
	var torso := with_delay.positions[CharPart.Id.TORSO].y - rig.rest_positions[CharPart.Id.TORSO].y
	assert_lt(head, torso, "올라가는 동안 머리가 몸보다 덜 올라와 있어야 한다")
