extends GutTest
## get hit — **경직 · 띄우기 · 바닥 쓰러짐** 셋이 다 있는가, 그리고 셋이 지면 규칙과
## 어떻게 부딪히는가.
##
## §25.12. 여기서 가장 값나가는 단정은 **경직 동안 포즈가 한 톨도 안 움직인다**는 것이다.
## 정지가 타격의 무게인데, 조금이라도 흐르면 그냥 느린 시작이 된다.

const SCAN_STEP := 0.004


func _clip() -> CharHitClip:
	return CharHitClip.new(CharRig.new())


func _times(clip: CharHitClip) -> Array[float]:
	var times: Array[float] = []
	var t := 0.0
	while t <= clip.loop_seconds():
		times.append(t)
		t += SCAN_STEP
	return times


func test_the_freeze_holds_the_pose_perfectly_still() -> void:
	# **정지가 타격의 무게다.** 조금이라도 흐르면 그냥 느린 시작이 된다.
	var clip := _clip()
	var f := AnimFeatures.all_on()
	var first := clip.sample(0.0, f)
	var t := 0.0
	while t < CharHitClip.FREEZE:
		var now := clip.sample(t, f)
		for part in CharPart.COUNT:
			assert_almost_eq(now.positions[part].x, first.positions[part].x, 0.0001, "경직이 흐른다")
			assert_almost_eq(now.positions[part].y, first.positions[part].y, 0.0001, "경직이 흐른다")
			assert_almost_eq(now.rotations[part], first.rotations[part], 0.0001, "경직이 흐른다")
		t += SCAN_STEP


func test_the_hit_pose_is_not_the_rest_pose() -> void:
	# 경직이 「멈춤」이려면 **맞은 자세**로 멈춰야 한다. 쉬는 자세로 멈추면 그냥 정지 화면이다.
	var clip := _clip()
	var hit := clip.sample(0.0, AnimFeatures.all_on())
	assert_gt(absf(hit.rotations[CharPart.Id.HEAD]), 0.1, "맞은 순간 머리가 젖혀져 있어야 한다")


func test_it_leaves_the_ground_and_comes_back() -> void:
	var clip := _clip()
	var highest := 0.0
	for t in _times(clip):
		highest = maxf(highest, clip.lift(t))
	assert_gt(highest, 10.0, "안 뜨면 띄우기가 아니다")
	assert_almost_eq(clip.lift(clip.loop_seconds()), 0.0, 0.0001, "끝에 땅에 있어야 한다")
	assert_almost_eq(clip.lift(0.0), 0.0, 0.0001, "경직 동안에는 안 뜬다")


func test_it_bounces_once_before_settling() -> void:
	# 한 번 튀는 것이 「바닥에 떨어졌다」를 만든다. 안 튀면 내려앉는 것으로 보인다.
	var clip := _clip()
	var landed := CharHitClip.FREEZE + CharHitClip.FLIGHT
	var bounce_peak := clip.lift(landed + CharHitClip.BOUNCE * 0.5)
	assert_gt(bounce_peak, 1.0, "착지 뒤에 한 번 튀어야 한다")
	assert_lt(bounce_peak, CharHitClip.LAUNCH_HEIGHT, "튀는 높이가 처음보다 낮아야 한다")


func test_it_is_knocked_backward_not_forward() -> void:
	# 부호가 뒤집히면 맞고 앞으로 걸어 들어간다.
	var clip := _clip()
	assert_lt(clip.drift(clip.loop_seconds()), -10.0, "뒤로 밀려야 한다")
	assert_almost_eq(clip.drift(0.0), 0.0, 0.0001, "경직 동안에는 안 밀린다")


func test_it_ends_slumped_on_the_ground() -> void:
	var clip := _clip()
	var f := AnimFeatures.all_on()
	var last := clip.sample(clip.loop_seconds(), f)
	var rest := clip.rig.rest_positions
	assert_lt(last.positions[CharPart.Id.TORSO].y, rest[CharPart.Id.TORSO].y - 10.0, "몸이 주저앉아야 한다")
	assert_lt(last.positions[CharPart.Id.HEAD].y, rest[CharPart.Id.HEAD].y - 20.0, "머리가 내려와야 한다")


func test_nothing_ever_sinks_into_the_ground() -> void:
	# **쓰러짐이 지면 규칙과 부딪히는 유일한 지점이다.** 띄우기는 안 부딪힌다 —
	# 규칙이 파고드는 것만 금지하고 뜨는 것은 허용하기 때문이다.
	var clip := _clip()
	for f: AnimFeatures in [AnimFeatures.all_on(), AnimFeatures.all_off()]:
		for t in _times(clip):
			assert_lte(clip.sample(t, f).deepest_sink(clip.rig), 0.0001, "t = %.3f 에서 파고든다" % t)


func test_the_blade_never_goes_through_the_floor() -> void:
	# 검은 파츠가 아니라 손의 자식이라 파츠 검사가 못 본다 (§25.11.2).
	var f := AnimFeatures.all_on()
	for cells in [CharWeapon.MIN_CELLS, CharWeapon.MAX_CELLS]:
		var clip := _clip()
		clip.weapon = CharWeapon.new(cells)
		for t in _times(clip):
			var tip := clip.weapon.tip_position(clip.sample(t, f), clip.rig)
			assert_gt(tip.y, 0.0, "%d 칸 t = %.3f 에서 검끝이 땅을 뚫는다" % [cells, t])


func test_the_parts_do_not_all_shake_alike() -> void:
	# **파츠마다 감쇠가 다른 것이 「살로 보이는」 것의 정체다.** 같으면 한 덩어리로 떨린다.
	var head: float = CharHitClip.RING_DECAY[CharPart.Id.HEAD]
	var foot: float = CharHitClip.RING_DECAY[CharPart.Id.FOOT_NEAR]
	assert_lt(head, foot, "머리가 발보다 오래 흔들려야 한다")


func test_the_head_keeps_moving_after_the_feet_stop() -> void:
	# 위 단정이 값에만 있고 실제 궤도에는 없을 수 있다. 움직임으로 다시 잰다.
	var clip := _clip()
	var f := AnimFeatures.all_on()
	var late := CharHitClip.FREEZE + 0.30
	assert_gt(
		_travel(clip, CharPart.Id.HEAD, late, f),
		_travel(clip, CharPart.Id.FOOT_NEAR, late, f),
		"늦게까지 머리가 발보다 많이 움직여야 한다"
	)


func test_it_does_not_loop() -> void:
	var clip := _clip()
	assert_false(clip.is_looping(), "맞는 것은 루프가 아니다")
	assert_almost_eq(clip.wrap_time(99.0), clip.loop_seconds(), 0.0001, "쓰러진 자세에 멈춘다")


func test_plant_has_nothing_to_say_about_being_hit() -> void:
	# 통합자가 물었다 - 띄우기를 `plant` 로 끄면 되는가. **아니다.**
	# `plant` 는 walk 의 디딤 등속만 관장하고 이 클립은 그것을 아예 안 본다 (§25.12.1).
	var clip := _clip()
	var on := clip.sample(0.4, AnimFeatures.all_on())
	var off := clip.sample(0.4, AnimFeatures.without("plant"))
	for part in CharPart.COUNT:
		assert_almost_eq(on.positions[part].y, off.positions[part].y, 0.0001, "plant 가 끼어들었다")


## 그 시각 근처에서 파츠가 **자기 몫으로** 움직인 거리.
##
## **떠오르고 밀리는 것은 여섯 파츠가 똑같이 받는다.** 그것을 안 빼면 그 공통 성분이
## 전부를 덮어 버려서 파츠별 차이가 안 보인다 — 실제로 머리와 발이 1.006 대 1.022 로
## 거의 같게 나왔다. **공통 성분을 뺀 나머지**가 파츠마다 다른 감쇠다.
func _travel(clip: CharHitClip, part: CharPart.Id, at: float, f: AnimFeatures) -> float:
	return _own_offset(clip, part, at, f).distance_to(_own_offset(clip, part, at + SCAN_STEP, f))


func _own_offset(clip: CharHitClip, part: CharPart.Id, at: float, f: AnimFeatures) -> Vector2:
	var root := Vector2(clip.drift(at), clip.lift(at))
	return clip.sample(at, f).positions[part] - clip.rig.rest_positions[part] - root
