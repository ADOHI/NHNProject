extends GutTest
## 무기의 **모양이 특성을 정한다** — 길이 축과 무게 축.
##
## 긴 쪽 칸 수가 길이를, 총 칸 수가 무게를 정한다. 하나로 뭉쳐 두면 사분면의
## 대각선 둘만 나오고 **창과 철퇴가 통째로 빠진다** (§25.20).

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


func test_a_heavier_weapon_swings_slower_in_every_phase() -> void:
	# **넷을 손으로 따로 만들지 않았다는 주장.** 칸 수만 넣으면 셋이 같이 늘어야 한다.
	var light := _clip(WeaponGuard.Id.HIGH, WeaponGuard.Id.LOW, CharWeapon.MIN_CELLS)
	var heavy := _clip(WeaponGuard.Id.HIGH, WeaponGuard.Id.LOW, CharWeapon.MAX_CELLS)
	assert_gt(heavy.anticipate, light.anticipate * 1.5, "무거우면 예비가 길어야 한다")
	assert_gt(heavy.strike, light.strike * 1.5, "무거우면 타격이 느려야 한다")
	assert_gt(heavy.recover, light.recover * 1.5, "무거우면 자세를 되찾는 데 오래 걸려야 한다")
	assert_gt(heavy.hitstop, light.hitstop, "무거우면 히트스톱이 길어야 한다")
	assert_gt(heavy.loop_seconds(), light.loop_seconds() * 1.5, "한 방이 통째로 느려야 한다")


func test_a_heavier_weapon_drags_the_body_further() -> void:
	var f := AnimFeatures.all_on()
	var light := _clip(WeaponGuard.Id.HIGH, WeaponGuard.Id.LOW, CharWeapon.MIN_CELLS)
	var heavy := _clip(WeaponGuard.Id.HIGH, WeaponGuard.Id.LOW, CharWeapon.MAX_CELLS)
	# **전진과 끌림을 갈라서 재야 한다.** 몸 전체가 나간 몫(`travel_at`)을 빼야
	# 「상체가 무기에 끌린 정도」만 남는다. 안 빼면 짧은 무기가 더 많이 전진하는 바람에
	# 가벼운 쪽이 앞서 있는 것으로 나오고, 엉뚱한 결론이 난다.
	var rest := light.rig.rest_positions[CharPart.Id.TORSO].x
	var light_end := (
		light.sample(light.loop_seconds(), f).positions[CharPart.Id.TORSO].x
		- rest
		- light.travel_at(light.loop_seconds())
	)
	var heavy_end := (
		heavy.sample(heavy.loop_seconds(), f).positions[CharPart.Id.TORSO].x
		- rest
		- heavy.travel_at(heavy.loop_seconds())
	)
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


func test_length_and_weight_are_separate_inputs() -> void:
	# **같은 4 칸인데 `4x1` 은 대검이고 `2x2` 는 철퇴다.** 하나로 뭉쳐 두면
	# 사분면의 대각선 둘만 나오고, 길고 가벼운 것과 짧고 무거운 것이 통째로 빠진다.
	var greatsword := CharWeapon.from_block(4, 1)
	var mace := CharWeapon.from_block(2, 2)
	assert_eq(greatsword.cells, mace.cells, "둘 다 4 칸이라 무게는 같아야 한다")
	assert_gt(greatsword.length(), mace.length(), "대검이 철퇴보다 길어야 한다")
	assert_gt(mace.blade_half_width(), greatsword.blade_half_width(), "철퇴가 더 굵어야 한다")
	assert_almost_eq(
		greatsword.hitstop_seconds(), mace.hitstop_seconds(), 0.0001, "멈춤은 무게 축이라 같아야 한다"
	)
	assert_almost_eq(greatsword.drag(), mace.drag(), 0.0001, "몸 끌림도 무게 축이라 같아야 한다")


func test_a_long_light_weapon_swings_faster_than_a_short_heavy_one() -> void:
	# **창과 철퇴가 이 판의 목적이다.** 창은 크게 도는데 빠르고 철퇴는 작게 도는데 느리다.
	var rig := CharRig.new()
	var spear := CharSwingClip.new(
		rig, WeaponGuard.Id.HIGH, WeaponGuard.Id.LOW, CharWeapon.from_block(3, 1)
	)
	var mace := CharSwingClip.new(
		rig, WeaponGuard.Id.HIGH, WeaponGuard.Id.LOW, CharWeapon.from_block(2, 2)
	)
	assert_gt(spear.weapon.length(), mace.weapon.length(), "창이 더 길어야 한다")
	assert_gt(mace.hitstop, spear.hitstop, "철퇴가 4 칸이라 창(3 칸)보다 멈춤이 길어야 한다")
	assert_gt(mace.weapon.drag(), spear.weapon.drag(), "철퇴가 몸을 더 끌어야 한다")


func test_the_block_shape_is_the_only_input() -> void:
	# 표를 안 늘린다. §28.2 의 블럭 모양을 그대로 먹는다.
	assert_eq(CharWeapon.from_block(1, 1).cells, 1)
	assert_eq(CharWeapon.from_block(1, 3).span, 3, "세로 3 칸도 긴 쪽이 3 이다")
	assert_eq(CharWeapon.from_block(2, 2).span, 2)
	# 긴 쪽이 총 칸 수를 넘을 수 없다 — 넘으면 밀도가 1 미만이 되어 뜻이 없다.
	assert_lte(CharWeapon.new(2, 4).span, 2, "긴 쪽이 총 칸 수를 넘으면 안 된다")


func test_every_block_shape_keeps_the_blade_off_the_floor() -> void:
	# 길이 축이 갈렸으니 **긴 쪽 칸 수마다** 다시 봐야 한다.
	var f := AnimFeatures.all_on()
	for block: Array in [[1, 1], [2, 1], [3, 1], [4, 1], [2, 2]]:
		var weapon := CharWeapon.from_block(block[0], block[1])
		for pair: Array in [
			[WeaponGuard.Id.HIGH, WeaponGuard.Id.LOW],
			[WeaponGuard.Id.LOW, WeaponGuard.Id.HIGH],
		]:
			var clip := CharSwingClip.new(CharRig.new(), pair[0], pair[1], weapon)
			for t in _times(clip):
				var tip := weapon.tip_position(clip.sample(t, f), clip.rig)
				assert_gt(tip.y, 0.0, "%dx%d 의 t = %.3f 에서 검끝이 뚫는다" % [block[0], block[1], t])
