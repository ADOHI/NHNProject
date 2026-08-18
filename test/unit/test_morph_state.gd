extends GutTest
## 물리가 낸 변위 — **상한 · 꺼짐 · 충격.**
##
## `docs/design/31-soft-body.md` §31.5.3.
##
## `MorphState` 는 **순수 자료**라 셰이더 없이 재진다. 그것이 이 클래스를 따로 둔
## 이유다 — 자가 보는 값과 화면이 받는 값이 **같은 값**이어야 §25.13.1 의
## 다섯 번째(그림과 자가 다른 것을 본다)가 안 난다.

const EPS := 0.0001


func _rig() -> CharRig:
	return CharRig.new()


func _idle() -> CharIdleClip:
	return CharIdleClip.new(_rig())


func _clip_of(name: String) -> CharClip:
	var rig := _rig()
	match name:
		"walk":
			return CharWalkClip.new(rig)
		"run":
			return CharRunClip.new(rig)
		_:
			return CharIdleClip.new(rig)


func _solved(morph: MorphRig, clip: CharClip, t: float) -> MorphState:
	var f := AnimFeatures.all_on()
	return MorphState.solve(morph, morph.drives_for(clip, f), t)


# --- 꺼짐이 진짜 꺼짐인가 ------------------------------------------------------


func test_strength_zero_is_exactly_zero_not_nearly_zero() -> void:
	# **근사가 아니라 등식이어야 한다.** 「거의 0」이면 픽셀이 달라질 수 있고,
	# 그러면 「끄면 지금 화면과 같다」가 거짓이 된다 (§31.4).
	var morph := MorphRig.default_for(_rig(), 0.0)
	var clip := _idle()
	for i in 40:
		var state := _solved(morph, clip, clip.loop_seconds() * float(i) / 40.0)
		for k in state.shifts.size():
			assert_eq(state.shifts[k], Vector2.ZERO, "세기 0 인데 %d 번 앵커가 움직였다" % k)
			assert_eq(state.bulges[k], 0.0)
		assert_true(state.is_rest())


func test_an_empty_rig_is_off() -> void:
	assert_true(MorphRig.none().is_off())
	assert_true(MorphState.solve(MorphRig.none(), [], 1.0).is_rest())


func test_a_null_rig_does_not_explode() -> void:
	assert_true(MorphState.solve(null, [], 1.0).is_rest())


func test_strength_scales_the_whole_thing() -> void:
	# 세기가 축 하나여야 한다 — 다른 것과 겹치면 조절판이 거짓말한다 (§25.5.2).
	var clip := _idle()
	var full := _solved(MorphRig.default_for(_rig(), 1.0), clip, 1.3)
	var half := _solved(MorphRig.default_for(_rig(), 0.5), clip, 1.3)
	for k in full.shifts.size():
		assert_almost_eq(half.raw_lengths[k], full.raw_lengths[k] * 0.5, EPS)


# --- 진폭 상한 ----------------------------------------------------------------


func test_the_tuning_is_already_inside_the_limit_before_clamping() -> void:
	# **상한이 걸린 값으로 「상한 안에 있나」를 물으면 늘 통과한다** (§25.13.2).
	# 그래서 **날것**을 본다. 상한이 일을 하고 있으면 눈금이 잘못 잡힌 것이다.
	var morph := MorphRig.default_for(_rig())
	for name in ["idle", "walk", "run"]:
		var clip := _clip_of(name)
		var drives := morph.drives_for(clip, AnimFeatures.all_on())
		for i in 60:
			var at := clip.loop_seconds() * float(i) / 60.0
			var state := MorphState.solve(morph, drives, at)
			for k in state.raw_lengths.size():
				var anchor := morph.anchors[k]
				assert_lte(
					state.raw_lengths[k],
					anchor.limit,
					(
						"%s 의 %s 가 상한을 넘는다 (%.2f > %.2f, t = %.2f)"
						% [name, anchor.anchor_name, state.raw_lengths[k], anchor.limit, at]
					)
				)


func test_the_limit_is_twelve_percent_of_the_part() -> void:
	# §25.29 「과장은 각도로, 거리로 하면 몸이 분해된다」의 이 층 판이다 (§31.4).
	var rig := _rig()
	var morph := MorphRig.default_for(rig)
	for anchor in morph.anchors:
		var half := rig.half_sizes[anchor.part]
		assert_almost_eq(anchor.limit, 0.12 * minf(half.x, half.y), EPS)


func test_a_huge_shock_still_stays_inside_the_limit() -> void:
	# 여러 대 맞아도 살이 몸에서 떨어져 나가면 안 된다 (§25.27.3 의 누적 상한과 같은 이유).
	var morph := MorphRig.default_for(_rig())
	var reaction := CharReaction.new()
	for i in 6:
		reaction.strike(0.1 * float(i), 3.0, -1.0)
	var drives := morph.drives_for(_idle(), AnimFeatures.all_on())
	for i in 120:
		var at := 0.02 * float(i)
		var state := MorphState.solve(morph, drives, at, reaction)
		for k in state.shifts.size():
			assert_lte(state.shifts[k].length(), morph.anchors[k].limit + EPS)


# --- 충격 -------------------------------------------------------------------


func test_a_shock_moves_the_flesh_against_the_push() -> void:
	# 몸이 뒤로(`-1`) 밀리면 살은 **앞에 남는다.** 같은 쪽으로 가면 밀림이 두 번 세어진다.
	var morph := MorphRig.default_for(_rig())
	var reaction := CharReaction.new()
	reaction.strike(0.0, 1.0, -1.0)
	var body := morph.anchors[0].body()
	var state := MorphState.solve(morph, [], body.peak_seconds(), reaction)
	assert_gt(state.shifts[0].x, 0.0, "뒤로 밀렸는데 살도 뒤로 가면 밀림이 두 번 세어진다")


func test_a_shock_dies_out() -> void:
	var morph := MorphRig.default_for(_rig())
	var reaction := CharReaction.new()
	reaction.strike(0.0, 1.0, -1.0)
	var settle := morph.anchors[0].body().settle_seconds()
	var late := MorphState.solve(morph, [], settle * 2.0, reaction)
	assert_lt(absf(late.shifts[0].x), 0.02, "충격이 안 잦아들면 계속 떤다")


func test_nothing_happens_before_the_hit() -> void:
	var morph := MorphRig.default_for(_rig())
	var reaction := CharReaction.new()
	reaction.strike(1.0, 2.0, -1.0)
	assert_true(MorphState.solve(morph, [], 0.5, reaction).is_rest())


func test_the_shock_list_is_not_a_second_copy() -> void:
	# **목록을 두 벌로 두면** 하나가 버린 것을 다른 하나가 안 버려 조용히 갈린다 (§25.27.3).
	var reaction := CharReaction.new()
	reaction.strike(0.0, 1.0, -1.0)
	assert_eq(reaction.impact_count(), 1)
	reaction.clear()
	assert_eq(reaction.impact_count(), 0)
	var morph := MorphRig.default_for(_rig())
	assert_true(MorphState.solve(morph, [], 0.05, reaction).is_rest())


# --- 이음매 -------------------------------------------------------------------


func test_the_loop_closes_with_the_physics_on() -> void:
	# **물리를 얹은 뒤에도 GIF 이음매가 맞아야 한다** (§25.3.2 · §31.5.2).
	var morph := MorphRig.default_for(_rig())
	for name in ["idle", "walk", "run"]:
		var clip := _clip_of(name)
		var drives := morph.drives_for(clip, AnimFeatures.all_on())
		var start := MorphState.solve(morph, drives, 0.0)
		var lap := MorphState.solve(morph, drives, clip.loop_seconds())
		for k in start.shifts.size():
			assert_almost_eq(lap.shifts[k].x, start.shifts[k].x, 1e-5, "%s 의 이음매가 가로로 끊긴다" % name)
			assert_almost_eq(lap.shifts[k].y, start.shifts[k].y, 1e-5, "%s 의 이음매가 세로로 끊긴다" % name)


# --- 좌표계 -------------------------------------------------------------------


func test_local_shift_undoes_the_part_rotation() -> void:
	# 몸이 기울었는데 안 되돌리면 살이 엉뚱한 쪽으로 어긋난다.
	var pose := CharPose.new()
	pose.rotations[CharPart.Id.TORSO] = PI * 0.5
	var state := MorphState.rest(1)
	state.shifts[0] = Vector2(1.0, 0.0)
	var local := state.local_shift(0, CharPart.Id.TORSO, pose)
	assert_almost_eq(local.x, 0.0, EPS)
	assert_almost_eq(local.y, -1.0, EPS)


func test_local_shift_undoes_the_part_scale() -> void:
	var pose := CharPose.new()
	pose.scales[CharPart.Id.TORSO] = Vector2(0.5, 2.0)
	var state := MorphState.rest(1)
	state.shifts[0] = Vector2(1.0, 1.0)
	var local := state.local_shift(0, CharPart.Id.TORSO, pose)
	assert_almost_eq(local.x, 2.0, EPS)
	assert_almost_eq(local.y, 0.5, EPS)


func test_local_shift_of_a_missing_anchor_is_zero() -> void:
	var state := MorphState.rest(1)
	assert_eq(state.local_shift(7, CharPart.Id.TORSO, CharPose.new()), Vector2.ZERO)


# --- 앵커 찾기 ----------------------------------------------------------------


func test_the_rig_can_find_its_anchors_by_part() -> void:
	var morph := MorphRig.default_for(_rig())
	assert_eq(morph.indices_of(CharPart.Id.TORSO).size(), 1)
	assert_eq(morph.indices_of(CharPart.Id.HEAD).size(), 1)
	assert_eq(morph.indices_of(CharPart.Id.HAND_NEAR).size(), 0)


func test_an_off_rig_reports_no_anchors_anywhere() -> void:
	# 켜졌는지 묻는 자리가 하나여야 한다 — 그리는 쪽이 따로 판단하면 갈린다.
	var morph := MorphRig.default_for(_rig(), 0.0)
	assert_eq(morph.indices_of(CharPart.Id.TORSO).size(), 0)


func test_copy_does_not_share_anchors() -> void:
	var morph := MorphRig.default_for(_rig())
	var clone := morph.copy()
	clone.anchors[0].centre += Vector2(20.0, 20.0)
	assert_ne(clone.anchors[0].centre, morph.anchors[0].centre)
