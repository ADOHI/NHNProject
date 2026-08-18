extends GutTest
## 구동 하모닉 — **클립의 상수를 안 읽고 재서 뽑았는데 그 값이 나오나.**
##
## `docs/design/31-soft-body.md` §31.1.3.
##
## `SoftDrive` 는 `CharIdleClip` 의 상수를 **한 줄도 안 읽는다.** 한 바퀴를 표본해
## 이산 푸리에로 뽑을 뿐이다. 그런데 뽑아 보면 `호흡 2 회`와 `무게이동 1 회`가
## 그 진폭으로 나와야 한다.
##
## **이것이 자가 자기를 검사하지 않는 유일한 자리다** (§25.13.2).
## 여기가 깨지면 하모닉이 틀렸거나 표본이 모자란 것이고, 둘 다 조용히 틀린다.

const EPS := 0.02


func _idle() -> CharIdleClip:
	return CharIdleClip.new(CharRig.new())


func _torso_drive() -> SoftDrive:
	# 피벗을 그대로 재면 `pose.positions[TORSO]` 와 같다 — 클립이 쓴 값과 바로 견줄 수 있다.
	return SoftDrive.from_clip(_idle(), CharPart.Id.TORSO, Vector2.ZERO, AnimFeatures.all_on())


func _harmonic(drive: SoftDrive, cycles: int) -> int:
	for i in drive.cycles.size():
		if drive.cycles[i] == cycles:
			return i
	return -1


# --- 재서 뽑은 것이 클립이 쓴 값과 같은가 ---------------------------------------


func test_breath_shows_up_as_two_cycles_a_lap() -> void:
	var drive := _torso_drive()
	var index := _harmonic(drive, int(CharIdleClip.BREATH_CYCLES))
	assert_gte(index, 0, "호흡 하모닉이 아예 없다")
	# `TORSO_RISE * sin(...)` 이므로 `sin` 성분의 세로가 그 진폭이어야 한다.
	assert_almost_eq(drive.sin_amp[index].y, CharIdleClip.TORSO_RISE, EPS)
	assert_almost_eq(drive.cos_amp[index].y, 0.0, EPS, "위상이 어긋나 있으면 cos 로 샌다")


func test_weight_shift_shows_up_as_one_cycle_a_lap() -> void:
	var drive := _torso_drive()
	var index := _harmonic(drive, int(CharIdleClip.SWAY_CYCLES))
	assert_gte(index, 0, "무게이동 하모닉이 아예 없다")
	assert_almost_eq(drive.sin_amp[index].x, CharIdleClip.TORSO_SWAY, EPS)


func test_the_mean_is_the_rest_position() -> void:
	var rig := CharRig.new()
	var drive := _torso_drive()
	# 사인파의 한 바퀴 평균은 0 이므로 남는 것은 쉬는 자리뿐이다.
	assert_almost_eq(drive.mean.x, rig.rest_positions[CharPart.Id.TORSO].x, 0.05)
	assert_almost_eq(drive.mean.y, rig.rest_positions[CharPart.Id.TORSO].y, 0.05)


func test_the_harmonics_rebuild_the_original_track() -> void:
	# **뽑은 것으로 원래 신호를 되짚을 수 있어야 한다.** 못 되짚으면 성분이 샌 것이다.
	var clip := _idle()
	var f := AnimFeatures.all_on()
	var drive := _torso_drive()
	for i in 40:
		var at := clip.loop_seconds() * float(i) / 40.0
		var actual := clip.sample(at, f).positions[CharPart.Id.TORSO]
		assert_almost_eq(drive.drive_at(at).x, actual.x, 0.15, "가로가 안 맞는다 (t = %.2f)" % at)
		assert_almost_eq(drive.drive_at(at).y, actual.y, 0.15, "세로가 안 맞는다 (t = %.2f)" % at)


func test_rotation_and_scale_reach_the_drive() -> void:
	# **피벗이 아니라 앵커 그 점을 잰다.** 머리는 갸웃하고 눌리므로 정수리가 실제로 움직인다.
	var rig := CharRig.new()
	var crown := Vector2(0.0, rig.half_sizes[CharPart.Id.HEAD].y * 2.0)
	var pivot := SoftDrive.from_clip(
		_idle(), CharPart.Id.HEAD, Vector2.ZERO, AnimFeatures.all_on()
	)
	var top := SoftDrive.from_clip(_idle(), CharPart.Id.HEAD, crown, AnimFeatures.all_on())
	var pivot_swing := 0.0
	var top_swing := 0.0
	for i in pivot.cycles.size():
		pivot_swing += pivot.sin_amp[i].length() + pivot.cos_amp[i].length()
		top_swing += top.sin_amp[i].length() + top.cos_amp[i].length()
	assert_gt(top_swing, pivot_swing, "정수리가 피벗보다 더 움직여야 갸웃이 구동에 들어온 것이다")


# --- 이음매 -------------------------------------------------------------------


func test_the_response_closes_the_loop_exactly() -> void:
	# **물리를 얹은 뒤에도 GIF 이음매가 맞아야 한다** (§25.3.2).
	# 응답이 주파수를 안 바꾸므로 한 바퀴당 정수 회라는 성질이 그대로 남는다.
	var drive := _torso_drive()
	var body := SoftBody.new(5.0, 0.30)
	var start := drive.response(body, 0.0)
	var lap := drive.response(body, drive.loop_seconds)
	assert_almost_eq(lap.x, start.x, 1e-5, "한 바퀴 뒤 가로가 안 돌아왔다")
	assert_almost_eq(lap.y, start.y, 1e-5, "한 바퀴 뒤 세로가 안 돌아왔다")


func test_every_harmonic_is_a_whole_number_of_cycles() -> void:
	# 무리수 비율이면 파형이 절대 되돌아오지 않아 이음매가 툭 끊긴다 (§25.3.2).
	var drive := _torso_drive()
	assert_gt(drive.cycles.size(), 0)
	for cycles in drive.cycles:
		assert_gt(cycles, 0)


# --- 루프가 아닌 클립 ----------------------------------------------------------


func test_a_non_looping_clip_gives_no_driven_response() -> void:
	# `die` 는 루프가 아니라 주기 분해가 성립하지 않는다. 그런 클립은 충격으로만 흔들린다.
	var clip := CharDieClip.new(CharRig.new())
	assert_false(clip.is_looping(), "이 테스트의 전제가 깨졌다 — die 가 루프가 됐다")
	var drive := SoftDrive.from_clip(
		clip, CharPart.Id.TORSO, Vector2.ZERO, AnimFeatures.all_on()
	)
	assert_true(drive.is_still())
	assert_eq(drive.response(SoftBody.new(5.0, 0.3), 0.7), Vector2.ZERO)


func test_a_null_clip_does_not_explode() -> void:
	var drive := SoftDrive.from_clip(null, CharPart.Id.TORSO, Vector2.ZERO, AnimFeatures.all_on())
	assert_true(drive.is_still())
