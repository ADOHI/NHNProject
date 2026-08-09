extends GutTest
## 휘두르기 — **오버슛이 실제로 목표를 지나치는가**가 이 파일의 중심이다.
##
## §25.3.1 이 지수 접근을 금지한 이유가 그것이다. `current += (target - current) * k` 로는
## 목표를 지나칠 방법이 아예 없어서 타격감이 원천적으로 불가능하다. 그래서
## **지나쳤는지를 단정으로 박아 둔다** — 안 그러면 언제 지수 접근으로 되돌아가도 모른다.
##
## 그리고 무기는 파츠가 아니라 손의 자식이므로 **파츠의 접지 검사가 검을 못 본다.**
## 검끝을 따로 잰다.

const SCAN_STEP := 0.004


func _clip(
	from_guard := WeaponGuard.Id.HIGH, to_guard := WeaponGuard.Id.LOW, cells := 1
) -> CharSwingClip:
	return CharSwingClip.new(CharRig.new(), from_guard, to_guard, CharWeapon.new(cells))


func _times(clip: CharSwingClip) -> Array[float]:
	var times: Array[float] = []
	var t := 0.0
	while t <= clip.loop_seconds():
		times.append(t)
		t += SCAN_STEP
	return times


func test_it_starts_at_the_opening_guard_and_ends_at_the_closing_one() -> void:
	# **이것이 체인의 바탕이다.** 마무리 자세가 값과 어긋나면 다음 동작이 튄다.
	var clip := _clip()
	var f := AnimFeatures.all_on()
	assert_almost_eq(clip.progress(0.0), 0.0, 0.0001, "시작 진행도는 0 이어야 한다")
	assert_almost_eq(clip.progress(clip.loop_seconds()), 1.0, 0.0001, "끝 진행도는 1 이어야 한다")

	var last := clip.sample(clip.loop_seconds(), f)
	assert_almost_eq(
		last.rotations[CharWeapon.HOLDER],
		WeaponGuard.hand_rotation(clip.to_guard, clip.rig, clip.weapon),
		0.001,
		"마무리 자세가 to_guard 와 달라지면 체인 조건이 거짓말한다"
	)


func test_the_anticipation_pulls_back_past_the_opening_guard() -> void:
	# 예비가 없으면 타격이 갑자기 튀어나온다. **진행도가 음수가 되어야** 물러난 것이다.
	var clip := _clip()
	var lowest := 0.0
	for t in _times(clip):
		lowest = minf(lowest, clip.progress(t))
	assert_lt(lowest, -0.05, "치기 전에 반대로 물러나지 않는다")


func test_the_strike_overshoots_past_the_closing_guard() -> void:
	# **지수 접근으로는 절대 만들 수 없는 값이다.** 1 을 넘는 순간이 있어야 한다.
	var clip := _clip()
	var highest := 0.0
	for t in _times(clip):
		highest = maxf(highest, clip.progress(t))
	assert_gt(highest, 1.05, "목표를 지나치지 않으면 타격감이 안 생긴다")


func test_the_swing_settles_instead_of_ringing_forever() -> void:
	# 오버슛만 있고 잦아들지 않으면 검이 계속 떤다.
	var clip := _clip()
	var late := clip.loop_seconds() - 0.02
	assert_almost_eq(clip.progress(late), 1.0, 0.02, "끝날 때쯤엔 거의 앉아 있어야 한다")


func test_the_strike_is_the_fastest_part() -> void:
	# 예비와 후속이 타격보다 빠르면 그건 휘두르기가 아니라 흔들기다.
	var clip := _clip()
	var fastest_at := 0.0
	var fastest := 0.0
	var times := _times(clip)
	for i in range(1, times.size()):
		var speed := absf(clip.progress(times[i]) - clip.progress(times[i - 1]))
		if speed > fastest:
			fastest = speed
			fastest_at = times[i]
	assert_gt(fastest_at, clip.anticipate - 0.01, "가장 빠른 순간이 예비 안에 있다")
	assert_lt(fastest_at, clip.anticipate + clip.strike + 0.01, "가장 빠른 순간이 타격 뒤에 있다")


func test_the_blade_never_goes_through_the_floor() -> void:
	# **파츠의 접지 검사가 검을 못 본다** — 검은 파츠가 아니라 손의 자식이다.
	# 처음에 마무리 자세가 너무 가팔라 검끝이 y = -17 까지 내려갔는데 아무도 안 잡았다.
	# **네 칸 전부** 본다. 무기가 길어지면 같은 자세라도 검끝이 더 내려간다.
	var f := AnimFeatures.all_on()
	for pair: Array in [
		[WeaponGuard.Id.HIGH, WeaponGuard.Id.LOW],
		[WeaponGuard.Id.LOW, WeaponGuard.Id.HIGH],
		[WeaponGuard.Id.NEUTRAL, WeaponGuard.Id.THRUST],
	]:
		for cells in range(CharWeapon.MIN_CELLS, CharWeapon.MAX_CELLS + 1):
			var clip := _clip(pair[0], pair[1], cells)
			for t in _times(clip):
				var tip := clip.weapon.tip_position(clip.sample(t, f), clip.rig)
				assert_gt(tip.y, 0.0, "%s 의 t = %.3f 에서 검끝이 땅을 뚫는다" % [clip.clip_name(), t])


func test_no_part_ever_sinks_into_its_ground() -> void:
	var clip := _clip()
	var f := AnimFeatures.all_on()
	for t in _times(clip):
		assert_lte(clip.sample(t, f).deepest_sink(clip.rig), 0.0001, "t = %.3f 에서 파츠가 땅을 판다" % t)


func test_it_does_not_loop() -> void:
	# 루프면 마무리 자세에 안 멈춰서 다음 동작이 거기서 이어받을 수가 없다.
	var clip := _clip()
	assert_false(clip.is_looping(), "휘두르기는 루프가 아니다")
	assert_almost_eq(clip.wrap_time(99.0), clip.loop_seconds(), 0.0001, "끝에서 멈춰야 한다")


func test_the_two_swings_chain_end_to_start() -> void:
	# 통합자가 제안한 규칙 — 앞 동작의 마무리가 다음 동작의 시작이어야 이어진다.
	# **판정은 아직 안 한다. 값이 맞물려 있는지만 본다.**
	var down := _clip(WeaponGuard.Id.HIGH, WeaponGuard.Id.LOW)
	var up := _clip(WeaponGuard.Id.LOW, WeaponGuard.Id.HIGH)
	assert_eq(down.to_guard, up.from_guard, "내려친 자리에서 올려치기가 시작되어야 한다")
	assert_eq(up.to_guard, down.from_guard, "올려친 자리에서 내려치기가 시작되어야 한다")


func test_every_guard_names_itself() -> void:
	# 이름이 비면 화면 표시가 빈칸이 되고, 그러면 어느 자세인지 눈으로 못 가른다.
	for id: WeaponGuard.Id in WeaponGuard.POSES:
		assert_gt(WeaponGuard.guard_name(id).length(), 0)


func test_the_weapon_rides_the_hand() -> void:
	# 무기가 손의 자식이라는 것이 값으로도 성립해야 한다 — 손이 돌면 검끝이 따라 돈다.
	var clip := _clip()
	var f := AnimFeatures.all_on()
	var early := clip.weapon.tip_position(clip.sample(0.0, f), clip.rig)
	var late := clip.weapon.tip_position(clip.sample(clip.loop_seconds(), f), clip.rig)
	assert_gt(early.distance_to(late), 30.0, "검끝이 거의 안 움직이면 손을 안 타고 있다")
	assert_gt(early.y, late.y, "위에서 아래로 내려친 것이므로 검끝이 내려가야 한다")


func test_a_heavier_weapon_swings_slower_in_every_phase() -> void:
	# **넷을 손으로 따로 만들지 않았다는 주장.** 칸 수만 넣으면 셋이 같이 늘어야 한다.
	var light := _clip(WeaponGuard.Id.HIGH, WeaponGuard.Id.LOW, CharWeapon.MIN_CELLS)
	var heavy := _clip(WeaponGuard.Id.HIGH, WeaponGuard.Id.LOW, CharWeapon.MAX_CELLS)
	assert_gt(heavy.anticipate, light.anticipate * 1.5, "무거우면 예비가 길어야 한다")
	assert_gt(heavy.strike, light.strike * 1.5, "무거우면 타격이 느려야 한다")
	assert_gt(heavy.recover, light.recover * 1.5, "무거우면 자세를 되찾는 데 오래 걸려야 한다")
	assert_gt(heavy.hold, light.hold, "무거우면 멈춤이 길어야 한다")
	assert_gt(heavy.loop_seconds(), light.loop_seconds() * 1.5, "한 방이 통째로 느려야 한다")


func test_a_heavier_weapon_drags_the_body_further() -> void:
	var f := AnimFeatures.all_on()
	var light := _clip(WeaponGuard.Id.HIGH, WeaponGuard.Id.LOW, CharWeapon.MIN_CELLS)
	var heavy := _clip(WeaponGuard.Id.HIGH, WeaponGuard.Id.LOW, CharWeapon.MAX_CELLS)
	var rest := light.rig.rest_positions[CharPart.Id.TORSO].x
	var light_end := light.sample(light.loop_seconds(), f).positions[CharPart.Id.TORSO].x - rest
	var heavy_end := heavy.sample(heavy.loop_seconds(), f).positions[CharPart.Id.TORSO].x - rest
	assert_gt(heavy_end, light_end + 2.0, "무거우면 상체가 더 끌려가야 한다")


func test_weight_comes_from_volume_not_from_a_hand_written_table() -> void:
	# 값이 표에 박혀 있으면 칸 수를 늘릴 때마다 사람이 네 줄을 더 적어야 한다.
	# **관성에서 나오면 그냥 나온다.** 단조성만 확인한다.
	var previous := 0.0
	for cells in range(CharWeapon.MIN_CELLS, CharWeapon.MAX_CELLS + 1):
		var weapon := CharWeapon.new(cells)
		assert_gt(weapon.inertia_ratio(), previous, "칸이 늘면 관성이 늘어야 한다")
		previous = weapon.inertia_ratio()
	assert_almost_eq(CharWeapon.new(1).time_scale(), 1.0, 0.0001, "1 칸이 기준이라 배수가 1 이다")


func test_a_long_weapon_cannot_be_lowered_as_far() -> void:
	# **길이가 자세를 정한다.** 손으로 네 번 맞추는 것이 아니라 기하로 풀린다.
	var rig := CharRig.new()
	var light := CharWeapon.new(CharWeapon.MIN_CELLS)
	var heavy := CharWeapon.new(CharWeapon.MAX_CELLS)
	assert_gt(heavy.length(), light.length(), "무거우면 길어야 한다")
	var low := WeaponGuard.Id.LOW
	assert_gte(
		WeaponGuard.weapon_angle(low, rig, heavy),
		WeaponGuard.weapon_angle(low, rig, light),
		"긴 무기는 덜 가파르게 내려야 바닥에 안 박힌다"
	)
