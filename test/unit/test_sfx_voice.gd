extends GutTest
## 무게 축 검증 (docs/design/29-sound.md §29.4).
##
## 여기서 지키는 것은 그림이 아니라 **규칙**이다. 누가 나중에 "4칸이 좀 밋밋하네" 하고
## 값 하나를 손으로 만지면 축이 깨지고, 넷이 "같은 무기의 크고 작은 버전" 이 아니라
## "서로 다른 네 물건" 으로 들리기 시작한다. 그 순간을 여기서 잡는다.

## src/core/char_anim/char_weapon.gd 의 time_scale() 실측값.
## 애니메이션 레인이 휘두르기 길이를 이 배수로 정했다. 소리가 다른 배수를 쓰면 안 된다.
const ANIMATION_TIME_SCALE: Array[float] = [1.000, 1.741, 2.408, 3.031]


func test_weight_scale_matches_the_animation_lane() -> void:
	# 소리와 동작이 같은 축을 쓴다는 것이 §29.4 의 전제다. 여기가 어긋나면
	# 4칸 휘두르기 2.22초에 1칸짜리 짧은 소리가 붙는다.
	for cells in [1, 2, 3, 4]:
		assert_almost_eq(
			SfxVoice.weight_scale(float(cells)),
			ANIMATION_TIME_SCALE[cells - 1],
			0.002,
			"무게 %d 의 배수가 char_weapon.time_scale() 과 달라졌다" % cells
		)


func test_ring_cycles_stay_constant_across_weight() -> void:
	# f0 * tau = 상수. 감쇠비는 크기가 아니라 재질의 성질이므로
	# 큰 종과 작은 종은 음높이와 울림 길이가 같이 변하지 진동 횟수는 안 변한다.
	var reference := SfxVoice.resolve(SfxRequest.impact(SfxMaterial.Kind.METAL, 1.0)).ring_cycles()
	for cells in [2, 3, 4]:
		var voice := SfxVoice.resolve(SfxRequest.impact(SfxMaterial.Kind.METAL, float(cells)))
		assert_almost_eq(voice.ring_cycles(), reference, 0.01, "무게 %d 에서 진동 횟수가 흔들렸다" % cells)


func test_one_axis_moves_all_three_values() -> void:
	# 무거우면 낮고 길고 둔하다. 셋이 따로 놀면 손으로 맞춘 것이다.
	var light := SfxVoice.resolve(SfxRequest.impact(SfxMaterial.Kind.METAL, 1.0))
	var heavy := SfxVoice.resolve(SfxRequest.impact(SfxMaterial.Kind.METAL, 4.0))
	assert_lt(heavy.hz, light.hz, "무거운 쪽이 더 낮아야 한다")
	assert_gt(heavy.tau, light.tau, "무거운 쪽이 더 길게 울어야 한다")
	assert_lt(heavy.cutoff_hz, light.cutoff_hz, "무거운 쪽이 더 둔해야 한다")
	assert_gt(heavy.duration, light.duration, "무거운 쪽이 더 길어야 한다")


func test_sound_length_tracks_swing_length() -> void:
	# 4칸 휘두르기가 2.22초인데 소리가 0.1초면 안 맞는다.
	# 꼬리가 동작의 일정 비율을 유지하는지 본다.
	var swing: Array[float] = [0.710, 1.256, 1.752, 2.217]
	var ratios: Array[float] = []
	for cells in [1, 2, 3, 4]:
		var voice := SfxVoice.resolve(SfxRequest.impact(SfxMaterial.Kind.METAL, float(cells)))
		ratios.append(voice.duration / swing[cells - 1])
	for ratio in ratios:
		assert_between(ratio, 0.20, 0.45, "타격음이 휘두르기 길이의 20~45 %% 안에 있어야 한다")
		assert_almost_eq(ratio, ratios[0], 0.05, "비율이 무게에 따라 흔들리면 축이 어긋난 것이다")


func test_weight_is_clamped_to_the_weapon_range() -> void:
	# 무기 칸 수는 1..4 다 (char_weapon.gd 의 MIN_CELLS/MAX_CELLS).
	# 밖의 값이 들어와도 소리가 폭주하면 안 된다.
	assert_eq(SfxRequest.impact(SfxMaterial.Kind.METAL, 99.0).weight, 4.0)
	assert_eq(SfxRequest.impact(SfxMaterial.Kind.METAL, -5.0).weight, 1.0)
	assert_lt(
		SfxVoice.resolve(SfxRequest.impact(SfxMaterial.Kind.METAL, 99.0)).duration,
		SfxVoice.MAX_SECONDS + 0.001,
		"어떤 조합도 상한을 넘지 않아야 한다"
	)


func test_seed_zero_is_the_unshaken_reference() -> void:
	# 씨 0 은 흔들지 않는다. 테스트와 기준 파형이 성립하려면 결정적이어야 한다.
	var first := SfxVoice.resolve(SfxRequest.impact(SfxMaterial.Kind.WOOD, 2.0, 0))
	var second := SfxVoice.resolve(SfxRequest.impact(SfxMaterial.Kind.WOOD, 2.0, 0))
	assert_eq(first.hz, second.hz, "같은 씨는 같은 주파수여야 한다")
	assert_eq(first.tau, second.tau)


func test_seed_shakes_pitch_within_the_stated_range() -> void:
	# 변주 폭이 넘치면 다른 무기로 들린다 (§29.6 의 ±6 %).
	var base := SfxVoice.resolve(SfxRequest.impact(SfxMaterial.Kind.WOOD, 2.0, 0))
	var moved := 0
	for seed_value in range(1, 12):
		var voice := SfxVoice.resolve(SfxRequest.impact(SfxMaterial.Kind.WOOD, 2.0, seed_value))
		var drift: float = absf(voice.hz - base.hz) / base.hz
		assert_lt(drift, SfxVoice.PITCH_JITTER + 0.001, "피치 변주가 규정 폭을 넘었다")
		if drift > 0.0:
			moved += 1
	assert_gt(moved, 8, "씨가 실제로 흔들어야 한다")


func test_bend_separates_opening_from_closing() -> void:
	# 열림과 닫힘은 무게가 같다. 방향으로만 갈린다 (§29.3 UI 표).
	var opening := SfxVoice.resolve(
		SfxRequest.tone(SfxMaterial.Kind.METAL, 1.5, SfxRequest.Bend.UP)
	)
	var closing := SfxVoice.resolve(
		SfxRequest.tone(SfxMaterial.Kind.METAL, 1.5, SfxRequest.Bend.DOWN)
	)
	assert_lt(opening.pitch_drop, 0.0, "열림은 올라가야 한다")
	assert_gt(closing.pitch_drop, 0.0, "닫힘은 내려가야 한다")


func test_ui_sits_above_combat_in_frequency() -> void:
	# UI 가 전투에 묻히면 안 된다. 음량이 아니라 자리로 나눈다 (§29.7).
	var combat := SfxVoice.resolve(SfxCatalog.request_for(SfxEvent.Kind.HIT_LANDED))
	var ui := SfxVoice.resolve(SfxCatalog.request_for(SfxEvent.Kind.UI_PRESS))
	assert_gt(ui.hz, combat.hz, "UI 는 전투보다 높은 자리를 써야 한다")
	assert_lt(ui.duration, combat.duration, "UI 는 전투보다 짧아야 한다")


func test_materials_stay_distinguishable() -> void:
	# 재질이 무게와 직교하려면 서로 달라야 한다. 값이 수렴하면 축이 하나로 무너진 것이다.
	var seen := {}
	for kind in SfxMaterial.Kind.values():
		var voice := SfxVoice.resolve(SfxRequest.impact(kind, 2.0))
		var key := "%.0f" % voice.hz
		assert_false(seen.has(key), "재질 %s 의 주파수가 다른 재질과 겹친다" % SfxMaterial.label(kind))
		seen[key] = true
