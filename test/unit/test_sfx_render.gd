extends GutTest
## 녹음물에 무게 축이 먹히는가 (docs/design/29-sound.md §29.4).
##
## **파일을 그대로 틀면 축이 사라진다.** 5타가 똑같이 다섯 번 나고 1칸과 4칸이 같아진다.
## 재료만 파일에서 오고 축은 계산에서 온다는 것이 이 판의 전제이므로, 여기서 지킨다.


func after_all() -> void:
	SfxRender.mode = SfxRender.Source.FILE


func test_nothing_renders_to_silence() -> void:
	# 사건 하나가 조용해지면 그건 버그로 안 보인다. 전수로 본다.
	for event in SfxEvent.all():
		var clip := SfxRender.render(SfxCatalog.request_for(event))
		assert_false(clip.is_empty(), "%s 가 무음이다" % SfxEvent.label(event))
		assert_gt(SfxSynth.peak(clip.samples), 0.0, "%s 의 피크가 0 이다" % SfxEvent.label(event))


func test_weight_stretches_recorded_impacts() -> void:
	# 리샘플이 길이를 scale 배로 민다. 이게 없으면 무기 칸 수가 소리에 안 닿는다.
	var light := SfxRender.render(SfxRequest.impact(SfxMaterial.Kind.METAL, 1.0))
	var heavy := SfxRender.render(SfxRequest.impact(SfxMaterial.Kind.METAL, 4.0))
	assert_gt(heavy.seconds(), light.seconds() * 2.0, "4칸이 1칸보다 한참 길어야 한다")


func test_length_grows_with_weight() -> void:
	# 3판에서는 길이가 **저역 몸통 레이어**에서 나온다. 늘여서 만드는 것이 아니므로
	# 정확한 배수가 아니라 **단조 증가**를 지킨다 (§29.4.1).
	var previous := 0.0
	for cells in [1, 2, 3, 4]:
		var clip := SfxRender.render(SfxRequest.impact(SfxMaterial.Kind.METAL, float(cells)))
		assert_gte(clip.seconds(), previous, "무게 %d 에서 길이가 줄었다" % cells)
		previous = clip.seconds()


func test_attack_does_not_slow_down_with_weight() -> void:
	# **2판이 물린 지점이다.** 큰 물체가 부딪혀도 부딪히는 순간은 순간이다.
	# 어택이 무게에 비례해 길어지면 그게 "느리게 튼 소리" 다.
	var light := _attack_ms(SfxRender.render(SfxRequest.impact(SfxMaterial.Kind.METAL, 1.0)))
	var heavy := _attack_ms(SfxRender.render(SfxRequest.impact(SfxMaterial.Kind.METAL, 4.0)))
	assert_lt(heavy, maxf(light, 1.0) * 2.5, "무거울수록 어택이 느려지고 있다")
	assert_lt(heavy, 8.0, "타격 어택이 8 ms 를 넘으면 타격으로 안 들린다")


func _attack_ms(clip: SfxClip) -> float:
	var peak := SfxSynth.peak(clip.samples)
	if peak <= 0.0:
		return 0.0
	var onset := -1
	for index in clip.samples.size():
		var level := absf(clip.samples[index])
		if onset < 0 and level > peak * 0.10:
			onset = index
		if level >= peak * 0.999:
			return 1000.0 * maxi(index - maxi(onset, 0), 0) / clip.rate
	return 0.0


func test_ui_keeps_its_designed_pitch() -> void:
	# 실제로 났던 사고다. 확인음(원본 791 Hz)에 무게 2.0 을 먹여 1.74배 늘였더니
	# 255 Hz 가 되어 전투음(374 Hz)보다 낮게 깔렸다.
	# UI 는 물리가 아니라 기호다 — 사람이 그 높이로 들으라고 만든 소리다.
	# 지켜야 하는 것은 **높이**지 길이가 아니다. 무게로 조금 길어지는 것은 상관없다 —
	# 무거운 상호작용이 좀 더 길게 울리는 것은 자연스럽다.
	#
	# 높이를 바꾸는 것은 리샘플 하나뿐이므로, 리샘플이 걸리는지를 직접 잡는다.
	# 파형을 비교하면 꼬리 길이 차이에 오염되어 무엇이 깨졌는지 못 읽는다.
	for kind in [SfxRequest.Kind.TICK, SfxRequest.Kind.TONE]:
		var voice := SfxVoice.resolve(SfxRequest.new(kind, SfxMaterial.Kind.WOOD, 4.0))
		assert_false(voice.scales_with_size, "UI 가 무게로 리샘플되면 설계된 높이가 망가진다")
	for kind in [SfxRequest.Kind.IMPACT, SfxRequest.Kind.WHOOSH]:
		var voice := SfxVoice.resolve(SfxRequest.new(kind, SfxMaterial.Kind.METAL, 4.0))
		assert_true(voice.scales_with_size, "타격은 물리다. 무게로 늘어나야 한다")

	# 반대로 타격은 무거워지면 반드시 낮아져야 한다. 그게 축이다.
	var light_hit := _centroid(SfxRender.render(SfxRequest.impact(SfxMaterial.Kind.METAL, 1.0)))
	var heavy_hit := _centroid(SfxRender.render(SfxRequest.impact(SfxMaterial.Kind.METAL, 4.0)))
	assert_lt(heavy_hit, light_hit * 0.75, "4칸 타격이 1칸보다 낮지 않다")


func test_ui_sits_above_combat() -> void:
	# 음량이 아니라 **자리**로 나눈다. 합성일 때는 기본 주파수를 올려서 했고,
	# 녹음물은 스펙트럼을 우리가 못 정하므로 아래를 깎아서 한다 (§29.7.6).
	var combat := _centroid(SfxRender.render(SfxCatalog.request_for(SfxEvent.Kind.HIT_LANDED)))
	for event in [SfxEvent.Kind.UI_PRESS, SfxEvent.Kind.UI_HOVER, SfxEvent.Kind.UI_CONFIRM]:
		var ui := _centroid(SfxRender.render(SfxCatalog.request_for(event)))
		assert_gt(ui, combat, "%s 가 전투음보다 낮게 깔린다" % SfxEvent.label(event))


func test_ui_kinds_carry_a_highpass() -> void:
	# 위 테스트가 무엇으로 성립하는지 직접 잡는다.
	assert_gt(SfxVoice.resolve(SfxRequest.tick(SfxMaterial.Kind.WOOD, 1.0)).highpass_hz, 0.0)
	assert_eq(
		SfxVoice.resolve(SfxRequest.impact(SfxMaterial.Kind.METAL, 1.0)).highpass_hz,
		0.0,
		"전투음은 아래를 깎으면 안 된다. 무게가 사라진다"
	)


func test_loudness_comes_from_the_axis_not_the_file() -> void:
	# 원본 음량이 27.7 dB 벌어져 있다. 정규화가 없으면 재질을 바꿀 때마다 음량이 널뛴다.
	for kind in SfxMaterial.Kind.values():
		var clip := SfxRender.render(SfxRequest.impact(kind, 2.0))
		var voice := SfxVoice.resolve(SfxRequest.impact(kind, 2.0))
		assert_almost_eq(
			SfxSynth.peak(clip.samples),
			SfxSynth.PEAK_TARGET * voice.gain,
			0.01,
			"%s 의 피크를 파일이 정하고 있다" % SfxMaterial.label(kind)
		)


func test_variations_are_different_recordings() -> void:
	# 벌마다 다른 파일이 걸려야 한다. 합성 씨를 흔드는 것보다 강한 변주다.
	var rendered: Array[PackedFloat32Array] = []
	for index in 4:
		rendered.append(
			SfxRender.render(SfxRequest.impact(SfxMaterial.Kind.METAL, 3.0), index).samples
		)
	for a in rendered.size():
		for b in range(a + 1, rendered.size()):
			assert_gt(_difference(rendered[a], rendered[b]), 0.10, "벌 %d 과 %d 이 사실상 같다" % [a, b])


func test_four_voices_stay_within_limiter_range() -> void:
	# **최악의 경우다** — 넷의 어택이 샘플 단위로 정확히 겹친 상황.
	# 실제 게임에서는 이렇게 안 겹치고(§29.7.4 실측 0.744), 겹쳐도 버스의
	# AudioEffectLimiter(천장 -1 dB)가 받는다. 여기서 잡는 것은 "리미터가 감당할 범위" 다.
	var mixed := PackedFloat32Array()
	mixed.resize(44100)
	var kinds := [
		SfxMaterial.Kind.METAL,
		SfxMaterial.Kind.FLESH,
		SfxMaterial.Kind.WOOD,
		SfxMaterial.Kind.DIRT,
	]
	for index in kinds.size():
		var clip := SfxRender.render(SfxRequest.impact(kinds[index], 3.0))
		SfxSynth.mix_into(mixed, clip.samples, 0)
	assert_lt(SfxSynth.peak(mixed), 1.35, "넷이 겹쳤을 때 리미터도 못 받을 만큼 넘친다")


func test_synth_still_works_as_a_fallback() -> void:
	# 합성 코드를 지우지 않았다. 재료에 구멍이 생기면 그때 메운다 (§29.10).
	SfxRender.mode = SfxRender.Source.SYNTH
	var clip := SfxRender.render(SfxCatalog.request_for(SfxEvent.Kind.HIT_LANDED))
	SfxRender.mode = SfxRender.Source.FILE
	assert_false(clip.is_empty(), "합성 대비책이 죽었다")
	assert_eq(clip.rate, SfxSynth.MIX_RATE)


func test_the_two_sources_really_differ() -> void:
	# 토글이 실제로 다른 소리를 내는지. 앞 판과 나란히 듣는 자리가 성립해야 한다.
	var request := SfxCatalog.request_for(SfxEvent.Kind.HIT_LANDED)
	var from_file := SfxRender.render(request).samples
	SfxRender.mode = SfxRender.Source.SYNTH
	var from_synth := SfxRender.render(request).samples
	SfxRender.mode = SfxRender.Source.FILE
	assert_gt(_difference(from_file, from_synth), 0.5, "파일과 합성이 같은 소리다")


func _centroid(clip: SfxClip) -> float:
	var samples := clip.samples
	if samples.size() < 2:
		return 0.0
	var crossings := 0
	for index in range(1, samples.size()):
		if signf(samples[index]) != signf(samples[index - 1]):
			crossings += 1
	return 0.5 * crossings * clip.rate / samples.size()


func _difference(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var count := mini(a.size(), b.size())
	if count == 0:
		return 0.0
	var diff := PackedFloat32Array()
	diff.resize(count)
	for index in count:
		diff[index] = a[index] - b[index]
	var reference := SfxSynth.rms(a.slice(0, count))
	if reference <= 0.0:
		return 0.0
	return SfxSynth.rms(diff) / reference
