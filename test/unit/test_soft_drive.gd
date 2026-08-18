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


## 그 하모닉의 진폭(축마다). 위상이 어디에 있든 크기는 이것 하나다.
func _amplitude(drive: SoftDrive, cycles: int) -> Vector2:
	var i := _harmonic(drive, cycles)
	if i < 0:
		return Vector2.ZERO
	return Vector2(
		Vector2(drive.cos_amp[i].x, drive.sin_amp[i].x).length(),
		Vector2(drive.cos_amp[i].y, drive.sin_amp[i].y).length()
	)


func _head_drive(local_point: Vector2) -> SoftDrive:
	return SoftDrive.from_clip(_idle(), CharPart.Id.HEAD, local_point, AnimFeatures.all_on())


func test_the_pivot_sees_exactly_what_the_clip_wrote() -> void:
	var pivot := _head_drive(Vector2.ZERO)
	assert_almost_eq(_amplitude(pivot, 1).x, CharIdleClip.HEAD_SWAY, EPS)
	assert_almost_eq(_amplitude(pivot, 2).y, CharIdleClip.HEAD_RISE, EPS)


func test_scale_reaches_the_drive() -> void:
	# **피벗이 아니라 앵커 그 점을 잰다.** 머리가 눌리면 정수리가 피벗과 다르게 움직인다.
	#
	# 피벗이 `HEAD_RISE` 만큼 오르는 동안 머리는 `HEAD_SQUASH` 만큼 눌리므로,
	# 정수리에서는 그 눌린 양(`머리 높이 x HEAD_SQUASH`)이 **빠진다.**
	# 이 예측은 클립의 상수에서 나오고, 잰 값은 표본에서 나온다 — 두 길이 만나야 한다.
	var rig := CharRig.new()
	var head_height := rig.half_sizes[CharPart.Id.HEAD].y * 2.0
	var crown := Vector2(0.0, head_height)
	var want := CharIdleClip.HEAD_RISE - head_height * CharIdleClip.HEAD_SQUASH
	assert_almost_eq(_amplitude(_head_drive(crown), 2).y, want, 0.02)


func test_rotation_reaches_the_drive_and_it_cancels_the_sway() -> void:
	# **갸웃이 무게이동을 지운다.** 몸이 앞으로 갈 때 머리는 늦어 정수리가 뒤에 남는데
	# (§25.4.2 의 척추 S 곡선), 그 둘이 정수리에서 거의 상쇄된다.
	#
	# **그래서 정수리가 피벗보다 덜 움직인다.** 처음에 반대로 예상했다가 자에 걸렸다 —
	# 회전이 구동에 안 들어왔으면 둘이 **같았을** 것이므로, 이 차이가 곧 회전의 증거다.
	var rig := CharRig.new()
	var crown := Vector2(0.0, rig.half_sizes[CharPart.Id.HEAD].y * 2.0)
	var pivot_sway := _amplitude(_head_drive(Vector2.ZERO), 1).x
	var crown_sway := _amplitude(_head_drive(crown), 1).x
	assert_lt(crown_sway, pivot_sway * 0.5, "정수리가 피벗만큼 흔들리면 회전이 안 들어온 것이다")
	assert_gt(crown_sway, 0.0)


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
