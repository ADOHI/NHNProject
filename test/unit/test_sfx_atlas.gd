extends GutTest
## 미리 섞어 둔 표 검증 (docs/design/29-sound.md §29.7.11).
##
## **이 표가 게임의 실제 오디오 경로다.** 원재료는 `export_presets.cfg` 가 빼므로
## 내보낸 빌드에는 없다 — 표에 구멍이 있으면 그 사건은 게임에서만 조용해지고,
## 에디터에서는 원재료로 잘 나서 안 보인다. **가장 잡기 어려운 종류의 버그다.**


func test_every_event_is_precomputed() -> void:
	# 표 기준 무게(칸 수를 안 넘길 때 쓰는 값)가 전부 들어 있어야 한다.
	# 실제로 "띄우기"(무게 2.5)만 빠져 혼자 실행 시점에 섞이고 있었다.
	for event in SfxEvent.all():
		var request := SfxCatalog.request_for(event)
		assert_ne(SfxAtlas.path_for(request, 0), "", "%s 가 표에 없다" % SfxEvent.label(event))


func test_every_weapon_cell_is_precomputed() -> void:
	# 무기 칸 수는 1..4 다. 배치 층이 넘기는 값이 전부 표에 있어야 한다.
	for event in SfxEvent.all():
		if not SfxCatalog.is_weight_driven(event):
			continue
		for cells in [1.0, 2.0, 3.0, 4.0]:
			var request := SfxCatalog.request_for(event).with_weight(cells)
			assert_ne(
				SfxAtlas.path_for(request, 0),
				"",
				"%s 의 %d칸이 표에 없다" % [SfxEvent.label(event), cells]
			)


func test_repeating_events_have_every_variation() -> void:
	# 체인 5타가 0.35초 간격이다. 변주가 표에 없으면 같은 소리가 반복된다.
	for event in SfxBank.REPEATING:
		var request := SfxCatalog.request_for(event)
		var found := 0
		for variation in SfxBank.VARIATION_COUNT:
			if not SfxAtlas.path_for(request, variation).is_empty():
				found += 1
		# 재료가 벌 수보다 적은 재질이 있다. 그때는 있는 만큼만 있으면 된다.
		var available := SfxLibrary.paths_for(request).size()
		var expected := mini(SfxBank.VARIATION_COUNT, maxi(available, 1))
		assert_eq(found, expected, "%s 의 변주가 표에 덜 들어 있다" % SfxEvent.label(event))
		assert_gt(found, 1, "%s 는 반복 사건이라 벌이 둘 이상이어야 한다" % SfxEvent.label(event))


func test_every_atlas_file_exists_and_plays() -> void:
	# 표에 이름만 있고 파일이 없으면 조용한 무음이 된다.
	for event in SfxEvent.all():
		var path := SfxAtlas.path_for(SfxCatalog.request_for(event), 0)
		assert_true(ResourceLoader.exists(path), "%s 의 파일이 없다: %s" % [SfxEvent.label(event), path])
		var stream := load(path) as AudioStreamWAV
		assert_not_null(stream, "%s 를 못 읽었다" % path)
		assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS)
		assert_gt(stream.get_length(), 0.0, "%s 가 길이 0 이다" % path)


func test_precomputed_matches_what_the_renderer_would_make() -> void:
	# 미리 섞은 것과 그 자리에서 섞은 것이 달라지면, 표를 다시 굽지 않은 것이다.
	# 값이 어긋난 채로 배포되면 에디터와 게임의 소리가 서로 다르다.
	for event in [SfxEvent.Kind.HIT_LANDED, SfxEvent.Kind.UI_PRESS, SfxEvent.Kind.GATE_ENTERED]:
		var request := SfxCatalog.request_for(event)
		var live := SfxRender.render(request, 0)
		var baked := load(SfxAtlas.path_for(request, 0)) as AudioStreamWAV
		assert_eq(baked.mix_rate, live.rate, "%s 의 레이트가 다르다" % SfxEvent.label(event))
		assert_almost_eq(
			baked.get_length(),
			live.seconds(),
			0.01,
			"%s 의 길이가 다르다. 표를 다시 구워야 한다" % SfxEvent.label(event)
		)


func test_the_bank_uses_the_atlas_not_the_renderer() -> void:
	# 은행이 표를 안 쓰면 웹에서 굽기 비용이 그대로 돌아온다 (652 ms).
	var bank := SfxBank.new()
	assert_almost_eq(bank.precomputed_ratio(), 1.0, 0.001, "표로 해결되지 않는 사건이 있다")


func test_the_atlas_is_skipped_when_synthesising() -> void:
	# 합성 대비책은 표를 지나쳐야 한다. 안 그러면 토글이 아무 일도 안 한다.
	SfxRender.mode = SfxRender.Source.SYNTH
	var bank := SfxBank.new()
	var stream := bank.stream_for(SfxEvent.Kind.HIT_LANDED)
	SfxRender.mode = SfxRender.Source.FILE
	assert_eq(stream.mix_rate, SfxSynth.MIX_RATE, "합성 모드인데 표에서 읽었다")
