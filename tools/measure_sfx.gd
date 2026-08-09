extends SceneTree
## 효과음 실측 (docs/design/29-sound.md §29.7).
##
## **판정 없이 잴 수 있는 것만 잰다.** 여기서 나온 숫자만 문서에 적는다 —
## 재 보지 않고 "가벼울 것이다" 라고 쓰지 않는다 (레인 규칙).
##
## 원천이 합성에서 CC0 파일로 바뀌었으므로 **앞 판의 숫자를 그대로 쓰지 않고 다시 잰다.**
##
##     godot --headless --path . -s res://tools/measure_sfx.gd

## 섞어서 재는 것들은 여기로 레이트를 맞춘다 (천이 44100 이라 그쪽에 맞춘다).
const COMMON_RATE := 44100

## 전투 레인 실측값. src/core/combat/break_tuning.gd 의 seconds_per_hit.
const CHAIN_INTERVAL := 0.35

## 애니메이션 레인 실측값. 1칸 부터 4칸 휘두르기 전체 길이.
const SWING_SECONDS: Array[float] = [0.710, 1.256, 1.752, 2.217]


func _init() -> void:
	print("")
	print("=== 효과음 실측 (원천: CC0 파일) ===")
	_sources()
	_bake_cost()
	_axis()
	_overlap()
	_polyphony()
	_variation()
	_ui_versus_combat()
	print("")
	quit()


## 어느 사건이 파일에서 오고 어느 사건이 합성으로 떨어지나.
func _sources() -> void:
	print("")
	print("--- 원천 (사건 %d개) ---" % SfxEvent.all().size())
	var from_file := 0
	for event in SfxEvent.all():
		if SfxRender.source_for(SfxCatalog.request_for(event)) == SfxRender.Source.FILE:
			from_file += 1
	print("CC0 파일        %d 개" % from_file)
	print("합성으로 메움    %d 개" % (SfxEvent.all().size() - from_file))
	for event in SfxRender.gap_events():
		print("   구멍: %s" % SfxEvent.label(event))
	print("재료 파일 수     %d 개" % SfxLibrary.file_count())

	# 실제로 샘플이 읽히는지. 앞서 QOA 로 임포트돼 조용히 합성으로 떨어진 적이 있다.
	var empty := 0
	for folder in SfxLibrary.COUNTS:
		for index in int(SfxLibrary.COUNTS[folder]):
			var path := "%s/%s/%s_%02d.wav" % [SfxLibrary.ROOT, folder, folder, index]
			if SfxSample.load_clip(path).is_empty():
				empty += 1
				print("   못 읽음: %s" % path)
	print("못 읽은 파일     %d 개" % empty)


func _bake_cost() -> void:
	print("")
	print("--- 굽는 비용 (전수) ---")
	SfxSample.clear_cache()
	var started := Time.get_ticks_usec()
	var total_bytes := 0
	var worst := 0.0
	var worst_event := SfxEvent.Kind.HIT_LANDED
	for event in SfxEvent.all():
		var one := Time.get_ticks_usec()
		var clip := SfxRender.render(SfxCatalog.request_for(event))
		var took := (Time.get_ticks_usec() - one) / 1000.0
		if took > worst:
			worst = took
			worst_event = event
		total_bytes += clip.samples.size() * 2
	var elapsed := (Time.get_ticks_usec() - started) / 1000.0
	print("전체 (첫 읽기 포함) %.1f ms" % elapsed)
	print("사건당 평균         %.2f ms" % (elapsed / SfxEvent.all().size()))
	print("가장 비싼 사건      %.2f ms  (%s)" % [worst, SfxEvent.label(worst_event)])
	print("16비트 PCM 합계     %.1f KB" % (total_bytes / 1024.0))

	# 캐시가 데워진 뒤 다시. 두 번째부터는 파일 읽기가 빠진다.
	var again := Time.get_ticks_usec()
	for event in SfxEvent.all():
		SfxRender.render(SfxCatalog.request_for(event))
	print("두 번째 (캐시 후)   %.1f ms" % ((Time.get_ticks_usec() - again) / 1000.0))


func _axis() -> void:
	print("")
	print("--- 무게 축이 녹음물에도 먹히는가 ---")
	print("무게   배수    차단 Hz   길이 ms   휘두르기 대비")
	for cells in [1, 2, 3, 4]:
		var request := SfxRequest.impact(SfxMaterial.Kind.METAL, float(cells))
		var voice := SfxVoice.resolve(request)
		var clip := SfxRender.render(request)
		print(
			(
				"  %d   %5.3f   %7.1f   %7.1f   %11.1f %%"
				% [
					cells,
					SfxVoice.weight_scale(float(cells)),
					voice.cutoff_hz,
					clip.seconds() * 1000.0,
					100.0 * clip.seconds() / SWING_SECONDS[cells - 1],
				]
			)
		)
	print("리샘플이 길이를 scale 배로, 주파수를 1/scale 로 동시에 민다 (§29.4)")

	print("")
	print("--- 재질별 레이트와 길이 (무게 2) ---")
	print("재질     레이트   길이 ms   피크")
	for kind in SfxMaterial.Kind.values():
		var clip := SfxRender.render(SfxRequest.impact(kind, 2.0))
		print(
			(
				"%-6s   %6d   %7.1f   %.3f"
				% [
					SfxMaterial.label(kind),
					clip.rate,
					clip.seconds() * 1000.0,
					SfxSynth.peak(clip.samples),
				]
			)
		)


func _overlap() -> void:
	print("")
	print("--- 겹침 (체인 타 간격 %.2f s) ---" % CHAIN_INTERVAL)
	print("재질     무게   꼬리 ms   겹치는 시간")
	for material in [SfxMaterial.Kind.METAL, SfxMaterial.Kind.FLESH, SfxMaterial.Kind.WOOD]:
		for cells in [1, 4]:
			var clip := SfxRender.render(SfxRequest.impact(material, float(cells)))
			var over := clip.seconds() - CHAIN_INTERVAL
			print(
				(
					"%-6s    %d    %7.1f   %+8.0f ms  %s"
					% [
						SfxMaterial.label(material),
						cells,
						clip.seconds() * 1000.0,
						over * 1000.0,
						"겹침" if over > 0.0 else "안 겹침",
					]
				)
			)

	print("")
	print("--- 5타 체인을 실제로 섞었을 때 ---")
	print("무게   단타 피크   5타 합 피크   증가   판정")
	for cells in [1, 2, 3, 4]:
		var request := SfxRequest.impact(SfxMaterial.Kind.METAL, float(cells))
		var single := _at_common(SfxRender.render(request))
		var span := int((CHAIN_INTERVAL * 4.0 + 2.5) * COMMON_RATE)
		var mixed := PackedFloat32Array()
		mixed.resize(span)
		for hit in 5:
			var varied := _at_common(
				SfxRender.render(SfxRequest.impact(SfxMaterial.Kind.METAL, float(cells)), hit)
			)
			SfxSynth.mix_into(mixed, varied, int(hit * CHAIN_INTERVAL * COMMON_RATE))
		var single_peak := SfxSynth.peak(single)
		var mixed_peak := SfxSynth.peak(mixed)
		print(
			(
				"  %d      %5.3f       %5.3f      %4.2fx   %s"
				% [
					cells,
					single_peak,
					mixed_peak,
					mixed_peak / maxf(single_peak, 0.0001),
					"넘침" if mixed_peak > 1.0 else "여유 있음",
				]
			)
		)


func _polyphony() -> void:
	print("")
	print("--- 동시 발음 (같은 순간에 겹쳐 냈을 때) ---")
	print("겹친 수   피크    RMS     클리핑")
	var requests := [
		SfxRequest.impact(SfxMaterial.Kind.METAL, 3.0),
		SfxRequest.impact(SfxMaterial.Kind.FLESH, 3.0),
		SfxRequest.impact(SfxMaterial.Kind.DIRT, 2.0),
		SfxRequest.tick(SfxMaterial.Kind.WOOD, 1.0),
		SfxRequest.impact(SfxMaterial.Kind.WOOD, 2.0),
		SfxRequest.tone(SfxMaterial.Kind.METAL, 2.0, SfxRequest.Bend.UP),
		SfxRequest.impact(SfxMaterial.Kind.STONE, 3.0),
		SfxRequest.impact(SfxMaterial.Kind.METAL, 4.0),
	]
	var span := int(2.0 * COMMON_RATE)
	for count in [1, 2, 3, 4, 6, 8]:
		var mixed := PackedFloat32Array()
		mixed.resize(span)
		for index in count:
			SfxSynth.mix_into(mixed, _at_common(SfxRender.render(requests[index])), 0)
		var peak := SfxSynth.peak(mixed)
		print(
			(
				"   %d      %5.3f   %5.3f   %s"
				% [count, peak, SfxSynth.rms(mixed), "넘침" if peak > 1.0 else "여유"]
			)
		)


func _variation() -> void:
	print("")
	print("--- 변주 (벌마다 다른 녹음 파일이 걸린다) ---")
	print("벌   길이 ms     RMS   0번과의 파형 차이")
	var base := _at_common(SfxRender.render(SfxRequest.impact(SfxMaterial.Kind.METAL, 3.0), 0))
	var rendered: Array[PackedFloat32Array] = [base]
	for index in range(1, 5):
		var varied := _at_common(
			SfxRender.render(SfxRequest.impact(SfxMaterial.Kind.METAL, 3.0), index)
		)
		rendered.append(varied)
	for index in rendered.size():
		print(
			(
				" %d   %7.1f   %5.3f   %15.1f %%"
				% [
					index,
					rendered[index].size() * 1000.0 / COMMON_RATE,
					SfxSynth.rms(rendered[index]),
					100.0 * _difference(base, rendered[index]),
				]
			)
		)
	var pair_min := 999.0
	for a in rendered.size():
		for b in range(a + 1, rendered.size()):
			pair_min = minf(pair_min, _difference(rendered[a], rendered[b]))
	print("벌끼리 최소 차이  %.1f %%   (0 이면 같은 소리다)" % (100.0 * pair_min))


func _ui_versus_combat() -> void:
	print("")
	print("--- UI 가 전투에 묻히나 ---")
	print("사건            길이 ms   중심 Hz   RMS")
	var checks := [
		SfxEvent.Kind.HIT_LANDED,
		SfxEvent.Kind.BREAK_KNOCKDOWN,
		SfxEvent.Kind.GATE_ENTERED,
		SfxEvent.Kind.UI_PRESS,
		SfxEvent.Kind.UI_CONFIRM,
		SfxEvent.Kind.UI_CANCEL,
		SfxEvent.Kind.UI_HOVER,
	]
	for event in checks:
		var clip := SfxRender.render(SfxCatalog.request_for(event))
		print(
			(
				"%-14s  %7.1f   %7.0f   %5.3f"
				% [
					SfxEvent.label(event),
					clip.seconds() * 1000.0,
					_centroid(clip),
					SfxSynth.rms(clip.samples),
				]
			)
		)


## 클립을 공통 레이트로. 레이트가 섞여 있어서 섞기 전에 맞춰야 한다.
func _at_common(clip: SfxClip) -> PackedFloat32Array:
	if clip.rate == COMMON_RATE:
		return clip.samples
	return SfxSample.resample(clip.samples, float(COMMON_RATE) / clip.rate)


## 영교차율 (Hz). 중심 주파수의 싼 대용품이다.
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
