extends GutTest
## **무너짐 눈금으로 구간을 자른다** — 경직 30 · 띄우기 60 · 쓰러짐 100 (§25.12.6).
##
## 문턱은 **전투 레인이 정했고** 여기는 그것을 구간으로 옮기기만 한다.
## §25.18.2 가 *"눈금이 정해지면 구간을 잘라 쓰면 된다"* 라고 적어 둔 자리다.
##
## **그 문장이 반만 맞았다.** 앞부분만 재생하면 되는 것이 아니라 **앞부분 + 제자리로**다 —
## 밀려난 채로 끝나면 다음 동작이 그 차이만큼 튄다. 쓰러짐만 안 돌아온다.

const STEP := 0.005


func _clip(depth: CharHitClip.Depth) -> CharHitClip:
	var clip := CharHitClip.new(CharRig.new())
	clip.depth = depth
	return clip


func _times(clip: CharClip) -> Array[float]:
	var out: Array[float] = []
	var t := 0.0
	while t <= clip.loop_seconds():
		out.append(t)
		t += STEP
	return out


func test_the_notch_picks_the_segment() -> void:
	# **전투가 준 값이 그대로 구간이 된다.** 여기서 값을 만들지 않는다.
	assert_eq(CharHitClip.depth_for(0.0), CharHitClip.Depth.STUN, "안 넘으면 경직이다")
	assert_eq(CharHitClip.depth_for(29.9), CharHitClip.Depth.STUN)
	assert_eq(CharHitClip.depth_for(CharHitClip.STUN_AT), CharHitClip.Depth.STUN, "30 은 경직")
	assert_eq(CharHitClip.depth_for(59.9), CharHitClip.Depth.STUN)
	assert_eq(CharHitClip.depth_for(CharHitClip.LAUNCH_AT), CharHitClip.Depth.LAUNCH, "60 은 띄우기")
	assert_eq(CharHitClip.depth_for(99.9), CharHitClip.Depth.LAUNCH)
	assert_eq(CharHitClip.depth_for(CharHitClip.FALL_AT), CharHitClip.Depth.FALL, "100 은 쓰러짐")
	assert_eq(CharHitClip.depth_for(400.0), CharHitClip.Depth.FALL, "더 세게 맞아도 쓰러짐이 끝이다")


func test_a_deeper_notch_takes_longer() -> void:
	# 구간을 더 붙이는 것이므로 **반드시 길어진다.** 짧아지면 자른 것이 아니라 갈아 끼운 것이다.
	var stun := _clip(CharHitClip.Depth.STUN).loop_seconds()
	var launch := _clip(CharHitClip.Depth.LAUNCH).loop_seconds()
	var fall := _clip(CharHitClip.Depth.FALL).loop_seconds()
	assert_lt(stun, launch, "경직이 띄우기보다 길다")
	assert_lt(launch, fall, "띄우기가 쓰러짐보다 길다")
	assert_gt(stun, CharHitClip.FREEZE, "경직에서 딱 끊으면 젖혀진 자세로 굳는다")


func test_a_stun_never_leaves_the_ground() -> void:
	# **30 을 넘고 60 을 못 넘긴 것은 안 뜬다.** 이게 눈금이 하는 일의 전부다.
	var clip := _clip(CharHitClip.Depth.STUN)
	for t in _times(clip):
		assert_eq(clip.lift(t), 0.0, "경직인데 t = %.3f 에서 떴다" % t)
		assert_eq(clip.drift(t), 0.0, "경직인데 t = %.3f 에서 밀렸다" % t)
		assert_eq(clip.slump(t), 0.0, "경직인데 t = %.3f 에서 주저앉는다" % t)


func test_a_launch_flies_but_does_not_slump() -> void:
	# 띄우기는 **떴다가 서는 것**이다. 주저앉으면 그건 쓰러짐이다.
	var clip := _clip(CharHitClip.Depth.LAUNCH)
	var highest := 0.0
	for t in _times(clip):
		highest = maxf(highest, clip.lift(t))
		assert_eq(clip.slump(t), 0.0, "띄우기인데 t = %.3f 에서 주저앉는다" % t)
	assert_gt(highest, 10.0, "띄우기인데 안 떴다")
	assert_almost_eq(clip.lift(clip.loop_seconds()), 0.0, 0.0001, "끝에는 땅에 있어야 한다")


func test_the_shallow_notches_come_home_and_the_deep_one_does_not() -> void:
	# **「앞부분만 재생」이 반만 맞았던 자리다.** 밀려난 채로 끝나면 다음 동작이 튄다.
	var f := AnimFeatures.all_on()
	var rest := CharPose.from_rig(CharRig.new())
	for depth: CharHitClip.Depth in [CharHitClip.Depth.STUN, CharHitClip.Depth.LAUNCH]:
		var clip := _clip(depth)
		assert_almost_eq(clip.drift(clip.loop_seconds()), 0.0, 0.001, "얕은 눈금인데 밀린 채로 끝난다")
		var last := clip.sample(clip.loop_seconds(), f)
		var gap := last.positions[CharPart.Id.TORSO].distance_to(rest.positions[CharPart.Id.TORSO])
		assert_lt(gap, 2.0, "얕은 눈금인데 끝 자세가 쉬는 자세에서 %.2f px 떨어져 있다" % gap)
	var fall := _clip(CharHitClip.Depth.FALL)
	assert_lt(fall.drift(fall.loop_seconds()), -20.0, "쓰러짐은 밀린 자리에 남아야 한다")


func test_nothing_sinks_at_any_notch() -> void:
	# 구간을 잘랐다고 지면 규칙이 헐거워지면 안 된다. **셋 다 다시 잰다.**
	var f := AnimFeatures.all_on()
	for depth: CharHitClip.Depth in [
		CharHitClip.Depth.STUN, CharHitClip.Depth.LAUNCH, CharHitClip.Depth.FALL
	]:
		var clip := _clip(depth)
		for t in _times(clip):
			var pose := clip.sample(t, f)
			assert_lte(pose.deepest_sink(clip.rig), 0.001, "눈금 %d 의 t = %.3f 에서 파고든다" % [depth, t])


func test_the_reaction_is_wiped_when_the_notch_crosses() -> void:
	# **통합자가 물은 것이다** — 충격이 쌓이다가 문턱을 넘어 상태가 바뀔 때 진동이 지워지나.
	#
	# 안 지우면 `hit` 클립이 이미 갖고 있는 큰 반응 **위에** 잔진동이 얹혀
	# 같은 사건을 두 번 세게 된다 (§25.27.3).
	var actor := CharActor.new()
	add_child_autofree(actor)
	actor.speed = 0.0
	actor.play(CharActor.Action.SWING)
	# 셋 앞에서 2.2 초 만에 눕는다 — 그동안 여러 번 얹힌다. 그 구간을 흉내 낸다.
	for i in 12:
		actor.take_hit(12.0)
	assert_gt(actor.stagger(), CharHitClip.FALL_AT, "이만큼 맞았으면 쓰러져야 한다")
	# `_settle_stagger` 는 `_process` 에서 돈다. 한 프레임 굴린다.
	actor.speed = 1.0
	actor._process(0.016)
	assert_eq(actor.current_action(), CharActor.Action.HIT, "문턱을 넘었는데 상태가 안 바뀌었다")
	assert_eq(actor.breakdown_depth(), CharHitClip.Depth.FALL, "100 을 넘었으면 쓰러짐이다")
	assert_eq(actor.stagger(), 0.0, "상태가 바뀌었으면 눈금은 0 부터다")


func test_many_hits_pick_the_notch_they_actually_reached() -> void:
	# **얕게 맞으면 얕게 무너진다.** 문턱 하나만 보면 셋이 다 같은 그림이 된다.
	for pair: Array in [
		[3, 12.0, CharHitClip.Depth.STUN],
		[6, 12.0, CharHitClip.Depth.LAUNCH],
		[10, 12.0, CharHitClip.Depth.FALL],
	]:
		var actor := CharActor.new()
		add_child_autofree(actor)
		actor.speed = 0.0
		actor.play(CharActor.Action.SWING)
		for i in int(pair[0]):
			actor.take_hit(float(pair[1]))
		actor.speed = 1.0
		actor._process(0.016)
		assert_eq(actor.current_action(), CharActor.Action.HIT, "%d 대면 무너져야 한다" % pair[0])
		assert_eq(actor.breakdown_depth(), pair[2], "%d 대의 눈금이 틀리다" % pair[0])
