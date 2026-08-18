extends GutTest
## CC0 재료가 실제로 있는가 (docs/design/29-sound.md §29.9).
##
## **이 파일이 있는 이유는 실제 사고 때문이다.** Godot 4.7 의 wav 기본 임포트가
## QOA(`compress/mode=2`)라 `AudioStreamWAV.data` 에서 샘플을 못 꺼냈고,
## `SfxRender` 는 그걸 "재료 없음" 으로 보고 **조용히 합성으로 떨어졌다.**
## 사건 50개가 전부 파일에서 온다고 보고되는 동안 실제로는 하나도 안 왔다.
##
## 조용한 대체는 버그로 안 보인다. 그래서 여기서 **파일을 실제로 열어 본다.**


func test_every_declared_file_exists() -> void:
	for folder in SfxLibrary.COUNTS:
		for tier in SfxLibrary.COUNTS[folder]:
			var declared: int = SfxLibrary.COUNTS[folder][tier]
			var found := SfxLibrary.paths_in(folder, tier)
			assert_eq(found.size(), declared, "%s/%s 파일 수가 선언과 다르다" % [folder, tier])


func test_every_file_actually_yields_samples() -> void:
	# QOA 로 임포트되면 여기서 걸린다. 존재 여부만 보면 못 잡는다.
	for folder in SfxLibrary.COUNTS:
		for tier in SfxLibrary.COUNTS[folder]:
			for path in SfxLibrary.paths_in(folder, tier):
				var clip := SfxSample.load_clip(path)
				assert_false(clip.is_empty(), "샘플을 못 읽었다 (QOA 임포트?): %s" % path)
				assert_gt(SfxSynth.peak(clip.samples), 0.1, "%s 가 사실상 무음이다" % path)


func test_percussive_material_starts_immediately() -> void:
	# 타격음에 지연이 붙으면 "늦게 난다" 로 느껴진다. 체인 간격이 350 ms 라 여유가 없다.
	# 2판에서는 천이 64.7 ms 늦게 시작했다 (§29.12.2).
	for folder in ["metal", "wood", "flesh", "stone", "dirt"]:
		for tier in SfxLibrary.COUNTS[folder]:
			for path in SfxLibrary.paths_in(folder, tier):
				var clip := SfxSample.load_clip(path)
				assert_lt(_onset_ms(clip), 10.0, "%s 가 늦게 시작한다" % path)


func _onset_ms(clip: SfxClip) -> float:
	var peak := SfxSynth.peak(clip.samples)
	if peak <= 0.0:
		return 0.0
	for index in clip.samples.size():
		if absf(clip.samples[index]) > peak * 0.10:
			return 1000.0 * index / clip.rate
	return 0.0


func test_the_wav_importer_stays_on_pcm() -> void:
	# 위 테스트의 원인을 직접 잡는다. 누가 project.godot 의 importer_defaults 를
	# 지우면 다음 임포트부터 전부 QOA 로 돌아간다.
	var defaults: Dictionary = ProjectSettings.get_setting("importer_defaults/wav", {})
	assert_eq(defaults.get("compress/mode", -1), 0, "wav 임포트가 16비트 PCM 이 아니다")


func test_the_stream_is_sixteen_bit_mono() -> void:
	var stream := load("%s/metal/light_00.wav" % SfxLibrary.ROOT) as AudioStreamWAV
	assert_not_null(stream)
	assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS, "16비트가 아니면 샘플을 못 꺼낸다")
	assert_false(stream.stereo, "효과음은 모노다. 스테레오면 용량이 두 배다")


func test_cloth_keeps_the_higher_rate() -> void:
	# 대부분의 재질은 11 kHz 위에 에너지가 1 % 도 없는데 천만 9.65 % 다.
	# 천 소리의 정체가 그 고역이라 거기만 44100 을 준다 (§29.7.9).
	var cloth := SfxSample.load_clip("%s/cloth/medium_00.wav" % SfxLibrary.ROOT)
	var metal := SfxSample.load_clip("%s/metal/light_00.wav" % SfxLibrary.ROOT)
	assert_eq(cloth.rate, 44100, "천은 44100 이어야 한다")
	assert_eq(metal.rate, 22050, "나머지는 22050 이면 충분하다")


func test_every_event_finds_material() -> void:
	# 구멍이 생기면 그 사건만 합성으로 떨어진다. 개수를 문서(§29.9.4)와 맞춰 둔다.
	var gaps := SfxLibrary.gaps()
	var names := ""
	for event in gaps:
		names += SfxEvent.label(event) + " "
	assert_eq(gaps.size(), 0, "재료가 없는 사건: %s" % names)


func test_opening_and_closing_draw_from_different_folders() -> void:
	# 열림과 닫힘을 피치 조작으로 만들지 않는다. 원래 그렇게 녹음된 것을 쓴다.
	var up := SfxRequest.tone(SfxMaterial.Kind.METAL, 2.0, SfxRequest.Bend.UP)
	var down := SfxRequest.tone(SfxMaterial.Kind.METAL, 2.0, SfxRequest.Bend.DOWN)
	assert_eq(SfxLibrary.folder_for(up), "tone_up")
	assert_eq(SfxLibrary.folder_for(down), "tone_down")


func test_whoosh_ignores_material() -> void:
	# 공기를 가르는 소리에 "금속" 은 없다.
	for kind in [SfxMaterial.Kind.METAL, SfxMaterial.Kind.CLOTH]:
		assert_eq(SfxLibrary.folder_for(SfxRequest.whoosh(kind, 2.0)), "air")


func test_each_material_has_enough_for_variation() -> void:
	# 체인 5타가 0.35초 간격으로 나간다. 재료가 하나뿐이면 변주가 불가능하다.
	for kind in SfxMaterial.Kind.values():
		var paths := SfxLibrary.paths_for(SfxRequest.impact(kind, 2.0))
		assert_gte(paths.size(), SfxBank.VARIATION_COUNT, "%s 의 재료가 모자란다" % SfxMaterial.label(kind))
