extends GutTest
## **실루엣 검사** — 「크게 했다」와 「충분히 크다」를 가른다.
##
## > 프레임을 전부 검게 칠했을 때, 어느 프레임인지 구분되나.
##
## 이 자가 없으면 진폭을 키워도 **판정할 방법이 없다.** 사용자가 두 번 불합격을 냈고
## 둘 다 「양이 부족하다」였다 (§25.22).


func test_the_ruler_actually_catches_a_still_pose() -> void:
	# **자가 틀릴 수 있다.** 진폭을 0 으로 만들어 놓고 자가 그걸 잡는지 먼저 본다.
	# 안 그러면 「자가 통과했다」가 아무것도 안 뜻한다.
	var rig := CharRig.new()
	var clip := CharSwingClip.new(rig, WeaponGuard.Id.HIGH, WeaponGuard.Id.LOW)
	var frozen := CharSilhouette.mask(clip.sample(0.0, AnimFeatures.all_on()), rig)
	assert_almost_eq(CharSilhouette.overlap(frozen, frozen), 1.0, 0.0001, "같은 포즈는 1 이어야 한다")

	# 쉬는 자세 둘은 완전히 같다 — 자가 1 을 내야 한다.
	var rest_a := CharSilhouette.mask(CharPose.from_rig(rig), rig)
	var rest_b := CharSilhouette.mask(CharPose.from_rig(rig), rig)
	assert_almost_eq(CharSilhouette.overlap(rest_a, rest_b), 1.0, 0.0001, "안 움직이면 1 이다")


func test_the_ruler_separates_a_big_move_from_a_small_one() -> void:
	# 자가 방향은 맞는지 — 크게 움직인 것이 더 낮게 나와야 한다.
	var rig := CharRig.new()
	var rest := CharPose.from_rig(rig)
	var nudged := CharPose.from_rig(rig)
	nudged.positions[CharPart.Id.HEAD] += Vector2(0.0, 4.0)
	var shoved := CharPose.from_rig(rig)
	shoved.positions[CharPart.Id.HEAD] += Vector2(40.0, 40.0)
	var small := CharSilhouette.overlap(
		CharSilhouette.mask(rest, rig), CharSilhouette.mask(nudged, rig)
	)
	var large := CharSilhouette.overlap(
		CharSilhouette.mask(rest, rig), CharSilhouette.mask(shoved, rig)
	)
	assert_gt(small, large, "크게 움직인 쪽이 더 낮게 나와야 한다")
	assert_lt(large, 0.85, "크게 움직였는데 자가 거의 같다고 한다")


func test_the_swing_is_more_dynamic_than_idle() -> void:
	# **idle 과 견주는 것이 요점이다.** idle 이 0.95 이고 스윙이 0.90 이면
	# 스윙이 정적인 것이다 — 절대값만 보면 그 판정을 못 한다.
	var rig := CharRig.new()
	var idle := CharSilhouette.widest_change(CharIdleClip.new(rig))
	var swing := CharSilhouette.widest_change(
		CharSwingClip.new(rig, WeaponGuard.Id.HIGH, WeaponGuard.Id.LOW)
	)
	# **절대값이 아니라 견줌으로 읽는다.** idle 도 숨쉬고 손이 흔들려 0.75 언저리다.
	# 중요한 것은 스윙이 그보다 **훨씬** 낮다는 것이다.
	assert_gt(idle, 0.6, "idle 은 실루엣이 크게 안 변해야 한다")
	assert_lt(swing, idle * 0.5, "스윙이 idle 의 절반만큼도 안 다르면 정적인 것이다")
	assert_lt(swing, 0.35, "스윙의 가장 다른 두 프레임이 이만큼 겹치면 정적이다")


func test_a_heavier_weapon_is_exaggerated_more() -> void:
	# **과장이 무게 축과 안 싸운다** — 무거운 것이 더 크게 과장된다.
	#
	# **실루엣 자로는 이걸 못 가른다.** 가벼운 무기가 두 배 더 전진하는데(25 대 12 px),
	# 몸이 통째로 옆으로 가는 것이 실루엣을 가장 크게 바꾼다. 그래서 자가
	# 「가벼운 쪽이 더 역동적」이라고 답한다 — **틀린 답이 아니라 다른 것을 잰 것이다.**
	# 자는 「얼마나 다르게 생겼나」를 재지 「얼마나 과장됐나」를 재지 않는다.
	var rig := CharRig.new()
	var light := CharSwingClip.new(rig, WeaponGuard.Id.HIGH, WeaponGuard.Id.LOW, CharWeapon.new(1))
	var heavy := CharSwingClip.new(rig, WeaponGuard.Id.HIGH, WeaponGuard.Id.LOW, CharWeapon.new(4))
	assert_gt(heavy.exaggeration(), light.exaggeration() * 1.2, "무거운 쪽이 더 과장돼야 한다")
	# 그리고 둘 다 역동적이어야 한다 — 어느 쪽도 정적이면 안 된다.
	assert_lt(CharSilhouette.widest_change(light), 0.35, "1 칸이 정적이다")
	assert_lt(CharSilhouette.widest_change(heavy), 0.35, "4 칸이 정적이다")


func test_the_other_actions_are_dynamic_too() -> void:
	var rig := CharRig.new()
	for entry: Array in [
		["run", CharRunClip.new(rig)],
		["jump", CharJumpClip.new(rig)],
		["hit", CharHitClip.new(rig)],
		["die", CharDieClip.new(rig)],
	]:
		var worst := CharSilhouette.widest_change(entry[1] as CharClip)
		assert_lt(worst, 0.75, "%s 의 실루엣이 거의 안 변한다" % entry[0])
