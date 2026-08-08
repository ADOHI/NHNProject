extends GutTest
## walk — **디딘 발이 미끄러지지 않는가**가 이 파일의 중심이다.
##
## 걸음에서 가장 잘 보이는 실패가 미끄러짐이고, 눈으로는 "좀 이상한데" 까지만 간다.
## 그래서 자를 만들었다 — **발이 땅에 닿아 있는 표본만 모아 앞뒤 이동량의 폭을 잰다.**
## 등속이면 그 폭이 0 이고, 사인파로 흔들면 크게 벌어진다
## (`docs/design/25-character-animation.md` §25.10.3).

const EPS := 0.0001

## 한 걸음을 훑는 간격. 디딤 구간(0.72 초) 안에 표본이 넉넉히 들어가야 한다.
const SCAN_STEP := 0.004


func _clip() -> CharWalkClip:
	return CharWalkClip.new(CharRig.new())


func _times() -> Array[float]:
	var times: Array[float] = []
	var t := 0.0
	while t < CharWalkClip.STRIDE:
		times.append(t)
		t += SCAN_STEP
	return times


## 발이 땅에 닿아 있는 동안, 표본 사이의 **발 자체의 앞뒤 이동량**을 모은다.
##
## 접지 판정은 `is_planted()` 가 아니라 **포즈에서 직접** 한다. 클립이 스스로
## "지금 디디고 있다" 고 말하는 것을 믿으면 실제로 뜬 경우를 놓친다.
##
## **재는 것은 접지 「모서리」가 아니라 발의 몸통(피벗)이다.** 모서리로 재면
## 뒤꿈치에서 발끝으로 접지점이 넘어가는 순간 22 px 이 튄다 — 그것은 미끄러짐이 아니라
## **구름**이다. 구름과 미끄러짐을 안 가르면 자가 엉뚱한 것을 잰다 (§25.10.3).
func _contact_steps(clip: CharWalkClip, part: CharPart.Id, f: AnimFeatures) -> Array[float]:
	var steps: Array[float] = []
	var previous := INF
	for t in _times():
		var pose := clip.sample(t, f)
		if pose.part_ground_point(part, clip.rig).y - clip.rig.ground_y(part) > 0.01:
			previous = INF
			continue
		var here := pose.positions[part].x
		if previous != INF:
			steps.append(here - previous)
		previous = here
	return steps


func _spread(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var low := INF
	var high := -INF
	for v in values:
		low = minf(low, v)
		high = maxf(high, v)
	return high - low


func test_the_loop_seam_closes_exactly() -> void:
	var clip := _clip()
	var f := AnimFeatures.all_on()
	var start := clip.sample(0.0, f)
	var end := clip.sample(CharWalkClip.STRIDE, f)
	for part in CharPart.COUNT:
		assert_almost_eq(start.positions[part].x, end.positions[part].x, 0.001, "이음매가 끊긴다")
		assert_almost_eq(start.positions[part].y, end.positions[part].y, 0.001, "이음매가 끊긴다")
		assert_almost_eq(start.rotations[part], end.rotations[part], 0.001, "이음매가 끊긴다")


func test_the_planted_foot_travels_at_a_constant_speed() -> void:
	# **이것이 walk 의 중심 단정이다.** 지면은 일정한 속도로 흐르므로 디딘 발도 등속이어야
	# 한다. 속도가 변하면 발이 땅 위에서 썰매를 탄다.
	var clip := _clip()
	var f := AnimFeatures.all_on()
	for part: CharPart.Id in [CharPart.Id.FOOT_NEAR, CharPart.Id.FOOT_FAR]:
		var steps := _contact_steps(clip, part, f)
		assert_gt(steps.size(), 100, "디딤 구간의 표본이 너무 적어 아무것도 못 잰다")
		assert_lt(_spread(steps), 0.02, "%s 이 디디는 동안 속도가 변한다" % CharPart.part_name(part))


func test_turning_plant_off_makes_the_foot_skate() -> void:
	# 자가 실제로 미끄러짐을 재는지 확인한다. 안 그러면 위 단정이 늘 참인 단정이 된다.
	var clip := _clip()
	var planted := _spread(_contact_steps(clip, CharPart.Id.FOOT_NEAR, AnimFeatures.all_on()))
	var skating := _spread(
		_contact_steps(clip, CharPart.Id.FOOT_NEAR, AnimFeatures.without("plant"))
	)
	assert_gt(skating, planted * 10.0, "디딤을 꺼도 속도가 안 변하면 자가 아무것도 안 재고 있다")


func test_both_feet_travel_at_the_same_speed() -> void:
	# 두 발의 디딤 속도가 다르면 캐릭터가 자기를 찢는다. 한 발만 재면 못 잡는다.
	var clip := _clip()
	var f := AnimFeatures.all_on()
	var near := _contact_steps(clip, CharPart.Id.FOOT_NEAR, f)
	var far := _contact_steps(clip, CharPart.Id.FOOT_FAR, f)
	assert_almost_eq(near[near.size() / 2], far[far.size() / 2], 0.02, "두 발의 지면 속도가 다르다")


func test_the_planted_foot_moves_backward() -> void:
	# 부호가 뒤집히면 문워크가 된다. 속도가 일정하기만 해서는 안 된다.
	var clip := _clip()
	var steps := _contact_steps(clip, CharPart.Id.FOOT_NEAR, AnimFeatures.all_on())
	for step in steps:
		assert_lt(step, 0.0, "디딘 발은 뒤로 흘러야 한다")


func test_exactly_one_foot_flies_at_a_time_and_sometimes_neither() -> void:
	# **양발 지지가 있어야 걷기다.** 둘 다 떠 있는 순간이 있으면 그건 달리기다.
	var clip := _clip()
	var f := AnimFeatures.all_on()
	var both_down := 0
	for t in _times():
		var pose := clip.sample(t, f)
		var airborne := 0
		for part: CharPart.Id in [CharPart.Id.FOOT_NEAR, CharPart.Id.FOOT_FAR]:
			var point := pose.part_ground_point(part, clip.rig)
			if point.y - clip.rig.ground_y(part) > 0.01:
				airborne += 1
		assert_lt(airborne, 2, "t = %.3f 에서 두 발이 다 떴다 - 걷기가 아니라 달리기다" % t)
		if airborne == 0:
			both_down += 1
	assert_gt(both_down, 0, "양발 지지가 한 순간도 없으면 걷기가 아니다")


func test_no_part_ever_sinks_into_its_ground() -> void:
	var clip := _clip()
	for f: AnimFeatures in [AnimFeatures.all_on(), AnimFeatures.all_off()]:
		for t in _times():
			assert_lte(clip.sample(t, f).deepest_sink(clip.rig), EPS, "t = %.3f 에서 파츠가 땅을 파고든다" % t)


func test_the_feet_cross_but_the_draw_order_never_changes() -> void:
	# **깊이는 교대하지 않는다.** 교대하는 것은 앞뒤 「위치」이지 「깊이」가 아니다.
	# 발은 반드시 교차해야 하고(안 하면 어정거리는 것이다), 그리는 순서는 상수여야 한다
	# (바뀌면 그 순간 팝이 생긴다). §25.10.1
	var clip := _clip()
	var f := AnimFeatures.all_on()
	var crossings := 0
	var last := 0.0
	for t in _times():
		var pose := clip.sample(t, f)
		var gap := pose.positions[CharPart.Id.FOOT_NEAR].x - pose.positions[CharPart.Id.FOOT_FAR].x
		var now := signf(gap)
		if now != 0.0 and last != 0.0 and now != last:
			crossings += 1
		if now != 0.0:
			last = now
	assert_eq(crossings, 2, "한 걸음에 두 발이 정확히 두 번 교차해야 한다")
	assert_lt(
		CharPart.DRAW_ORDER.find(CharPart.Id.FOOT_FAR),
		CharPart.DRAW_ORDER.find(CharPart.Id.FOOT_NEAR),
		"교차하는데 순서가 바뀌면 팝이 생긴다 - 순서는 상수여야 한다"
	)


func test_the_arms_swing_opposite_to_the_legs_on_the_same_side() -> void:
	# 같은 위상이면 동측 보행이 되어 그 즉시 사람이 아닌 것으로 읽힌다.
	var clip := _clip()
	var f := AnimFeatures.all_on()
	var agreed := 0
	var times := _times()
	for t in times:
		var pose := clip.sample(t, f)
		var hand := (
			pose.positions[CharPart.Id.HAND_NEAR].x
			- clip.rig.rest_positions[CharPart.Id.HAND_NEAR].x
		)
		var foot := pose.positions[CharPart.Id.FOOT_NEAR].x - CharWalkClip.TRACK_CENTER
		if signf(hand) == signf(foot):
			agreed += 1
	assert_lt(float(agreed) / float(times.size()), 0.25, "앞손이 앞발과 같은 쪽으로 나가면 동측 보행이다")


func test_the_body_drops_after_the_foot_lands_not_with_it() -> void:
	# 몸이 발과 정확히 같이 내려가면 충격을 흡수하지 않는 것으로 보인다.
	var clip := _clip()
	var torso := CharPart.Id.TORSO
	var lowest_with_delay := _lowest_time(clip, torso, AnimFeatures.all_on())
	var lowest_without := _lowest_time(clip, torso, AnimFeatures.without("delay"))
	assert_gt(lowest_with_delay, lowest_without, "지연을 켜면 몸이 더 늦게 내려앉아야 한다")


func test_the_far_hand_swings_less_than_the_near_one() -> void:
	var clip := _clip()
	var f := AnimFeatures.all_on()
	assert_lt(
		_swing_span(clip, CharPart.Id.HAND_FAR, f),
		_swing_span(clip, CharPart.Id.HAND_NEAR, f),
		"뒷손이 앞손보다 크게 흔들리면 앞뒤가 뒤집힌다"
	)


func test_depth_off_makes_both_hands_swing_alike() -> void:
	var clip := _clip()
	var f := AnimFeatures.without("depth")
	assert_almost_eq(
		_swing_span(clip, CharPart.Id.HAND_FAR, f),
		_swing_span(clip, CharPart.Id.HAND_NEAR, f),
		0.001,
		"앞뒤 스위치가 안 먹는다"
	)


func _lowest_time(clip: CharWalkClip, part: CharPart.Id, f: AnimFeatures) -> float:
	var best := INF
	var best_t := 0.0
	for t in _times():
		var y := clip.sample(t, f).positions[part].y
		if y < best:
			best = y
			best_t = t
	return best_t


func _swing_span(clip: CharWalkClip, part: CharPart.Id, f: AnimFeatures) -> float:
	var low := INF
	var high := -INF
	for t in _times():
		var x := clip.sample(t, f).positions[part].x
		low = minf(low, x)
		high = maxf(high, x)
	return high - low
