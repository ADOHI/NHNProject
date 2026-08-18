extends GutTest
## 합성 검증 (docs/design/29-sound.md §29.5).
##
## 파형은 노드 없이 검사된다 — SfxSynth 가 순수 함수라서 헤드리스에서 배열을 직접 본다.
## 소리를 들어야만 아는 것(음색)은 여기서 안 다룬다. **재면 아는 것만 잡는다.**

const RATE := SfxSynth.MIX_RATE


func test_sample_count_matches_the_stated_duration() -> void:
	var voice := SfxVoice.resolve(SfxRequest.impact(SfxMaterial.Kind.METAL, 2.0))
	var samples := SfxSynth.render(voice)
	assert_almost_eq(float(samples.size()) / RATE, voice.duration, 0.002, "길이가 선언한 값과 달라졌다")


func test_peak_leaves_room_for_other_voices() -> void:
	# 1.0 로 정규화하면 두 소리만 겹쳐도 즉시 넘친다 (§29.7 실측).
	for kind in SfxMaterial.Kind.values():
		for cells in [1, 4]:
			var samples := SfxSynth.render_request(SfxRequest.impact(kind, float(cells)))
			assert_lt(
				SfxSynth.peak(samples),
				SfxSynth.PEAK_TARGET + 0.001,
				"%s 무게 %d 가 여유를 넘겼다" % [SfxMaterial.label(kind), cells]
			)


func test_four_voices_stay_under_clipping() -> void:
	# 동시 발음 실측의 회귀 방지. 넷까지는 리미터 없이도 버텨야 한다.
	var mixed := PackedFloat32Array()
	mixed.resize(int(1.0 * RATE))
	var kinds := [
		SfxMaterial.Kind.METAL,
		SfxMaterial.Kind.FLESH,
		SfxMaterial.Kind.WOOD,
		SfxMaterial.Kind.DIRT,
	]
	for index in kinds.size():
		SfxSynth.mix_into(
			mixed, SfxSynth.render_request(SfxRequest.impact(kinds[index], 3.0, index + 1)), 0
		)
	assert_lt(SfxSynth.peak(mixed), 1.30, "네 소리가 겹쳤을 때 지나치게 넘치면 안 된다")


func test_the_same_seed_gives_the_same_waveform() -> void:
	# 결정적이지 않으면 테스트도 캐시도 성립하지 않는다.
	var first := SfxSynth.render_request(SfxRequest.impact(SfxMaterial.Kind.WOOD, 2.0, 5))
	var second := SfxSynth.render_request(SfxRequest.impact(SfxMaterial.Kind.WOOD, 2.0, 5))
	assert_eq(first.size(), second.size())
	for index in first.size():
		assert_eq(first[index], second[index], "같은 씨인데 %d 번째 샘플이 다르다" % index)
		if first[index] != second[index]:
			return


func test_different_seeds_give_genuinely_different_waveforms() -> void:
	# 5타가 1.4초에 나간다. 같은 배열 다섯 번이면 기계로 들린다 (§29.6).
	var base := SfxSynth.render_request(SfxRequest.impact(SfxMaterial.Kind.METAL, 3.0, 1))
	var other := SfxSynth.render_request(SfxRequest.impact(SfxMaterial.Kind.METAL, 3.0, 2))
	var count := mini(base.size(), other.size())
	var difference := 0.0
	for index in count:
		difference += absf(base[index] - other[index])
	assert_gt(difference / count, 0.001, "씨를 바꿨는데 파형이 사실상 같다")


func test_the_tail_is_faded_so_it_does_not_click() -> void:
	# 지수 감쇠만으로는 마지막에 계단이 남아 "틱" 이 난다.
	for kind in SfxMaterial.Kind.values():
		var samples := SfxSynth.render_request(SfxRequest.impact(kind, 2.0))
		assert_almost_eq(
			samples[samples.size() - 1], 0.0, 0.001, "%s 의 끝이 0 이 아니다" % SfxMaterial.label(kind)
		)


func test_it_starts_from_silence() -> void:
	# 첫 샘플이 튀면 그것도 클릭이다.
	var samples := SfxSynth.render_request(SfxRequest.impact(SfxMaterial.Kind.METAL, 2.0))
	assert_almost_eq(samples[0], 0.0, 0.01, "첫 샘플이 0 근처여야 한다")


func test_mix_into_ignores_samples_outside_the_target() -> void:
	# 체인 마지막 타의 꼬리가 버퍼 밖으로 나가도 죽으면 안 된다.
	var dest := PackedFloat32Array()
	dest.resize(100)
	var src := PackedFloat32Array()
	src.resize(50)
	src.fill(1.0)
	SfxSynth.mix_into(dest, src, 80)  # 30개는 밖으로 나간다
	SfxSynth.mix_into(dest, src, -20)  # 20개는 앞으로 나간다
	assert_eq(dest[99], 1.0, "안에 든 부분은 섞여야 한다")
	assert_eq(dest[0], 1.0, "앞으로 밀린 것도 겹치는 부분은 섞여야 한다")


func test_pcm16_is_two_bytes_per_sample() -> void:
	var samples := PackedFloat32Array([0.0, 1.0, -1.0, 0.5])
	var bytes := SfxSynth.to_pcm16(samples)
	assert_eq(bytes.size(), 8, "16비트 모노는 샘플당 2바이트다")
	assert_eq(bytes.decode_s16(2), 32767, "1.0 은 최대값이어야 한다")
	assert_eq(bytes.decode_s16(4), -32767, "-1.0 은 최소값 근처여야 한다")


func test_baked_stream_is_playable() -> void:
	# AudioStreamGenerator 가 아니라 AudioStreamWAV 인 것이 §29.5 의 결론이다.
	var stream := SfxSynth.bake_request(SfxRequest.impact(SfxMaterial.Kind.METAL, 2.0))
	assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_eq(stream.mix_rate, RATE)
	assert_false(stream.stereo, "효과음은 모노다. 스테레오면 용량이 두 배다")
	assert_gt(stream.get_length(), 0.0, "길이가 있어야 한다")


func test_whoosh_matches_the_swing_windup() -> void:
	# 휘두르기 예비 구간과 길이가 맞아야 한다 (swing_clip.gd 의 ANTICIPATE+STRIKE).
	for cells in [1, 4]:
		var voice := SfxVoice.resolve(SfxRequest.whoosh(SfxMaterial.Kind.CLOTH, float(cells)))
		var expected := SfxVoice.SWING_LEAD * SfxVoice.weight_scale(float(cells))
		assert_almost_eq(voice.duration, expected, 0.01, "무게 %d 의 휘두르기 길이가 안 맞는다" % cells)
