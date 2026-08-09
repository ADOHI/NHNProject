extends GutTest
## **반응 층** — 때리다가 맞는 것을 절차적으로 처리한다 (§25.27).
##
## 사용자가 물었다 — *"결국 액션이 뒤엉키잖아 때리다가 맞고 이런거."*
## 핵심은 **피격을 클립이 아니라 힘으로** 만든 것이고, 이 파일이 그 주장을 검사한다.

const RIG := preload("res://src/core/char_anim/char_rig.gd")


func _swing() -> CharSwingClip:
	return CharSwingClip.new(CharRig.new(), WeaponGuard.Id.HIGH, WeaponGuard.Id.LOW)


func test_being_hit_does_not_stop_the_swing() -> void:
	# **전환이 없다는 것이 이 층의 전부다.** 맞아도 스윙 자세는 그대로 계산된다.
	var clip := _swing()
	var f := AnimFeatures.all_on()
	var at := clip.anticipate * 0.5
	var clean := clip.sample(at, f)
	var reaction := CharReaction.new()
	reaction.strike(at, 0.8)
	var shaken := clip.sample(at, f)
	reaction.apply(shaken, at + 0.06, clip.rig)
	# 자세는 계속 스윙이고, 그 위에 흔들림만 얹혔다.
	var moved := shaken.positions[CharPart.Id.TORSO].distance_to(clean.positions[CharPart.Id.TORSO])
	assert_gt(moved, 0.5, "충격이 안 얹혔다")
	assert_lt(moved, 20.0, "충격이 자세를 통째로 갈아치웠다")


func test_the_shake_dies_out_on_its_own() -> void:
	var reaction := CharReaction.new()
	reaction.strike(0.0, 1.0)
	assert_gt(reaction.load_at(0.06), 0.05, "맞은 직후에는 흔들려야 한다")
	assert_lt(reaction.load_at(2.0), 0.01, "시간이 지나면 잦아들어야 한다")


func test_many_hits_do_not_make_it_explode() -> void:
	# **누적이 폭주하면 캐릭터가 발작한다.** 상한이 있어야 어느 선에서 멈춘다.
	var reaction := CharReaction.new()
	for i in 40:
		reaction.strike(float(i) * 0.01, 1.0)
	var rig := CharRig.new()
	var pose := CharPose.from_rig(rig)
	var rest := rig.rest_positions[CharPart.Id.TORSO]
	reaction.apply(pose, 0.25, rig)
	var thrown := pose.positions[CharPart.Id.TORSO].distance_to(rest)
	assert_lt(thrown, CharReaction.SHIFT * CharReaction.MAX_LOAD + 1.0, "누적이 상한을 넘었다")
	assert_lt(
		absf(pose.rotations[CharPart.Id.TORSO]), CharReaction.TWIST * CharReaction.MAX_LOAD + 0.01
	)


func test_more_hits_shake_more_up_to_the_cap() -> void:
	var one := CharReaction.new()
	one.strike(0.0, 0.3)
	var three := CharReaction.new()
	for i in 3:
		three.strike(float(i) * 0.005, 0.3)
	assert_gt(three.load_at(0.05), one.load_at(0.05), "많이 맞으면 더 흔들려야 한다")


func test_the_parts_do_not_all_shake_alike() -> void:
	# `hit` 의 파츠별 감쇠를 그대로 쓴다 — 머리가 오래, 발이 짧게.
	assert_lt(
		CharReaction.DECAY[CharPart.Id.HEAD],
		CharReaction.DECAY[CharPart.Id.FOOT_NEAR],
		"머리가 발보다 오래 흔들려야 한다"
	)
	var reaction := CharReaction.new()
	reaction.strike(0.0, 1.0)
	var rig := CharRig.new()
	var pose := CharPose.from_rig(rig)
	reaction.apply(pose, 0.34, rig)
	var head := absf(pose.rotations[CharPart.Id.HEAD])
	var foot := absf(pose.rotations[CharPart.Id.FOOT_NEAR])
	assert_gt(head, foot, "늦게까지 머리가 발보다 흔들려야 한다")


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


func test_spent_hits_are_forgotten_so_the_list_cannot_grow() -> void:
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
