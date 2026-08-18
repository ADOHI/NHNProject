extends GutTest
## **팔 길이 상한** (§25.29).
##
## 사용자가 지적했다 — 애니메이션 과장은 좋은데 **인체 거리감이 무너지고**,
## 특히 **뒷손이 몸에서 너무 떨어진다**고.
##
## **과장이 각도로 가야지 거리로 가면 몸이 분해된다.**
## 손은 어깨에서 「팔이 닿는 거리」 안에 있어야 **매달린 것**으로 읽히고,
## 넘으면 **따로 노는 것**으로 보인다.
##
## 이 자가 있으면 **앞으로 진폭을 키울 때 자동으로 막힌다.**

const LIMBS: Array[CharPart.Id] = [
	CharPart.Id.HAND_NEAR,
	CharPart.Id.HAND_FAR,
	CharPart.Id.FOOT_NEAR,
	CharPart.Id.FOOT_FAR,
]


func _clips(rig: CharRig) -> Dictionary:
	return {
		"idle": CharIdleClip.new(rig),
		"walk": CharWalkClip.new(rig),
		"run": CharRunClip.new(rig),
		"jump": CharJumpClip.new(rig),
		"hit": CharHitClip.new(rig),
		"die": CharDieClip.new(rig),
		"swing": CharSwingClip.new(rig, WeaponGuard.Id.HIGH, WeaponGuard.Id.LOW),
	}


func test_no_clip_ever_stretches_a_limb_past_the_limit() -> void:
	# **전부 본다.** 하나라도 빠지면 거기서 팔이 늘어난다.
	var rig := CharRig.new()
	var f := AnimFeatures.all_on()
	var limits := rig.reach_limits()
	var clips := _clips(rig)
	for name in clips:
		var clip: CharClip = clips[name]
		var t := 0.0
		while t <= clip.loop_seconds():
			var pose := clip.sample(t, f)
			for part in LIMBS:
				# **디딘 발은 뺀다.** 땅이 이겨서 안 끌어당기기 때문이다 —
				# 디딘 발이 멀면 그건 발이 아니라 몸이 너무 간 것이다.
				if clip.foot_is_planted(pose, part):
					continue
				assert_almost_eq(
					pose.overreach(part, rig, limits[part]),
					0.0,
					0.5,
					"%s t = %.3f 에서 파츠 %d 가 팔 길이를 넘었다" % [name, t, part]
				)
			t += 0.01


func test_the_socket_turns_with_the_torso() -> void:
	# **고정 좌표로 재면 안 된다.** 몸통이 돌면 어깨도 같이 돈다 —
	# 밑창·검끝에서 이미 겪은 함정이고, 여기서도 똑같다.
	var rig := CharRig.new()
	var pose := CharPose.from_rig(rig)
	var straight := pose.socket_of(CharPart.Id.HAND_FAR, rig)
	pose.rotations[CharPart.Id.TORSO] = 0.45
	var turned := pose.socket_of(CharPart.Id.HAND_FAR, rig)
	assert_gt(straight.distance_to(turned), 1.0, "몸통이 돌았는데 어깨가 안 돈다")


func test_idle_is_the_yardstick() -> void:
	# **기준은 idle 이다** — idle 이 「정상 인체」이고 거기가 `x1.00` 이다.
	var rig := CharRig.new()
	var f := AnimFeatures.all_on()
	var idle := CharIdleClip.new(rig)
	for part in LIMBS:
		var limit := rig.reach_limit(part)
		assert_gt(limit, rig.rest_reach(part), "상한이 쉬는 자세보다 좁다")
		var t := 0.0
		while t <= idle.loop_seconds():
			assert_lt(idle.sample(t, f).reach_of(part, rig), limit * 0.8, "idle 이 이미 상한에 붙었다")
			t += 0.02


func test_hands_may_reach_further_than_feet() -> void:
	# 쉬는 다리는 이미 거의 펴져 있어서 더 늘 자리가 적다.
	assert_gt(
		CharRig.REACH_LIMIT[CharPart.Id.HAND_NEAR],
		CharRig.REACH_LIMIT[CharPart.Id.FOOT_NEAR],
		"발이 손보다 더 늘어난다"
	)


func test_reining_in_keeps_the_direction() -> void:
	# **방향은 안 건드리고 거리만 줄인다.** 자세가 무엇을 하려던 것인지는 방향에 들어 있다.
	# 그래서 **과장이 사라지는 게 아니라 각도로 남는다.**
	var rig := CharRig.new()
	var clip := CharSwingClip.new(rig, WeaponGuard.Id.HIGH, WeaponGuard.Id.LOW)
	var pose := CharPose.from_rig(rig)
	var part := CharPart.Id.HAND_FAR
	var socket := pose.socket_of(part, rig)
	pose.positions[part] = socket + Vector2(140.0, -60.0)
	var before := (pose.positions[part] - socket).normalized()
	clip.rein_in_limbs(pose)
	var after := (pose.positions[part] - socket).normalized()
	assert_almost_eq(before.dot(after), 1.0, 0.001, "끌어당기면서 방향이 바뀌었다")
	assert_almost_eq(pose.reach_of(part, rig), rig.reach_limit(part), 0.5, "상한까지 안 줄었다")
