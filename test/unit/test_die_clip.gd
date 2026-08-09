extends GutTest
## die — **「순서대로」가 이 클립의 전부다.**
##
## `get hit` 의 쓰러짐과 겉이 비슷해서, 검증이 그 둘을 갈라 놓지 않으면
## 「die 를 만들었다」가 「hit 를 한 번 더 만들었다」와 구별되지 않는다.
## 그래서 **파츠가 놓는 시각이 서로 다르다**를 정면으로 단정한다.

const SCAN_STEP := 0.004


func _clip() -> CharDieClip:
	return CharDieClip.new(CharRig.new())


func _times(clip: CharDieClip) -> Array[float]:
	var times: Array[float] = []
	var t := 0.0
	while t <= clip.loop_seconds():
		times.append(t)
		t += SCAN_STEP
	return times


func test_the_parts_let_go_one_after_another_not_together() -> void:
	# **여섯이 같이 무너지면 인형이 넘어지는 것이고, 하나씩 놓으면 힘이 빠지는 것이다.**
	var clip := _clip()
	var releases: Array[float] = []
	for part: CharPart.Id in CharDieClip.RELEASE:
		releases.append(CharDieClip.RELEASE[part])
	releases.sort()
	for i in range(1, releases.size()):
		assert_gt(releases[i], releases[i - 1] - 0.0001, "놓는 시각이 정렬되어야 한다")
	assert_gt(releases[releases.size() - 1] - releases[0], 0.3, "놓는 시각이 충분히 벌어져야 한다")


func test_the_hands_go_first_and_the_head_goes_last() -> void:
	# 머리가 먼저 떨어지면 목이 부러진 것으로 보인다. 마지막에 떨궈야 힘이 빠진 것이다.
	var hands: float = CharDieClip.RELEASE[CharPart.Id.HAND_NEAR]
	var head: float = CharDieClip.RELEASE[CharPart.Id.HEAD]
	var torso: float = CharDieClip.RELEASE[CharPart.Id.TORSO]
	assert_lt(hands, torso, "쥐는 힘이 가장 먼저 빠져야 한다")
	assert_lt(torso, head, "머리가 마지막이어야 한다")


func test_a_part_does_not_move_at_all_before_its_turn() -> void:
	# **「아직 버티고 있다」가 보이려면 정확히 0 이어야 한다.** 조금이라도 흐르면
	# 여섯이 다 같이 무너지는 것과 구별이 안 된다.
	var clip := _clip()
	var f := AnimFeatures.all_on()
	var head := CharPart.Id.HEAD
	var rest := clip.rig.rest_positions[head]
	var before: float = CharDieClip.RELEASE[head] - 0.01
	var pose := clip.sample(before, f)
	assert_almost_eq(pose.positions[head].x, rest.x, 0.0001, "차례 전에 머리가 움직였다")
	assert_almost_eq(pose.positions[head].y, rest.y, 0.0001, "차례 전에 머리가 움직였다")
	# 그런데 그때 손은 이미 놓았어야 한다 — 안 그러면 순서가 없는 것이다.
	assert_gt(clip.collapse(CharPart.Id.HAND_NEAR, before), 0.5, "그때 손은 이미 놓았어야 한다")


func test_it_ends_collapsed_and_stays_there() -> void:
	var clip := _clip()
	var f := AnimFeatures.all_on()
	var last := clip.sample(clip.loop_seconds(), f)
	var rest := clip.rig.rest_positions
	assert_lt(last.positions[CharPart.Id.HEAD].y, rest[CharPart.Id.HEAD].y - 30.0, "머리가 내려와야 한다")
	assert_lt(last.positions[CharPart.Id.TORSO].y, rest[CharPart.Id.TORSO].y - 15.0, "몸이 무너져야 한다")
	for part in CharPart.COUNT:
		assert_almost_eq(clip.collapse(part, clip.loop_seconds()), 1.0, 0.0001, "다 놓았어야 한다")


func test_it_never_comes_back() -> void:
	# **되돌아오지 않는 유일한 동작이다.** 무너짐이 단조 증가여야 한다.
	var clip := _clip()
	for part in CharPart.COUNT:
		var previous := -1.0
		for t in _times(clip):
			var now := clip.collapse(part, t)
			assert_gte(now, previous - 0.0001, "무너짐이 되돌아갔다")
			previous = now


func test_it_does_not_loop() -> void:
	var clip := _clip()
	assert_false(clip.is_looping(), "죽는 것은 루프가 아니다")
	assert_almost_eq(clip.wrap_time(99.0), clip.loop_seconds(), 0.0001, "끝에서 멈춘다")


func test_nothing_sinks_and_the_blade_stays_above_the_floor() -> void:
	# **클립이 실제로 든 무기로 재야 한다.** 1 칸을 들려 놓고 4 칸 검끝을 재면
	# 클립이 치우지도 않은 것을 나무라는 셈이라, 통과시키려고 엉뚱한 데를 고치게 된다.
	for cells in [CharWeapon.MIN_CELLS, CharWeapon.MAX_CELLS]:
		var clip := _clip()
		clip.weapon = CharWeapon.new(cells)
		for f: AnimFeatures in [AnimFeatures.all_on(), AnimFeatures.all_off()]:
			for t in _times(clip):
				var pose := clip.sample(t, f)
				assert_lte(pose.deepest_sink(clip.rig), 0.0001, "t = %.3f 에서 파고든다" % t)
				assert_gt(
					clip.weapon.tip_position(pose, clip.rig).y,
					0.0,
					"%d 칸 t = %.3f 에서 검끝이 뚫는다" % [cells, t]
				)


func test_dying_is_not_just_another_knockdown() -> void:
	# **겉이 비슷해서 이 단정이 필요하다.** hit 는 여섯이 한꺼번에 밀리고
	# die 는 하나씩 놓는다 — 같은 시각에 파츠들이 얼마나 제각각인지로 가른다.
	var die := _clip()
	var hit := CharHitClip.new(CharRig.new())
	assert_gt(_spread_at(die, 0.30), _spread_at(hit, 0.30), "die 가 hit 보다 파츠가 제각각이어야 한다")


## 그 시각에 여섯 파츠가 **쉬는 자리에서 벗어난 정도**가 얼마나 제각각인가.
func _spread_at(clip: CharClip, t: float) -> float:
	var f := AnimFeatures.all_on()
	var pose := clip.sample(t, f)
	var low := INF
	var high := -INF
	for part in CharPart.COUNT:
		var moved := pose.positions[part].distance_to(clip.rig.rest_positions[part])
		low = minf(low, moved)
		high = maxf(high, moved)
	return high - low
