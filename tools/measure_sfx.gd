extends SceneTree
## 효과음 실측 (docs/design/29-sound.md §29.7).
##
## **판정 없이 잴 수 있는 것만 잰다.** 여기서 나온 숫자만 문서에 적는다 —
## 재 보지 않고 "가벼울 것이다" 라고 쓰지 않는다 (레인 규칙).
##
##     godot --headless --path . -s res://tools/measure_sfx.gd

const RATE := SfxSynth.MIX_RATE

## 전투 레인 실측값. src/core/combat/break_tuning.gd 의 seconds_per_hit.
const CHAIN_INTERVAL := 0.35

## 애니메이션 레인 실측값. 1칸 → 4칸 휘두르기 전체 길이.
const SWING_SECONDS: Array[float] = [0.710, 1.256, 1.752, 2.217]


func _init() -> void:
	print("")
	print("=== 효과음 실측 ===")
	_bake_cost()
	_lengths()
	_overlap()
	_polyphony()
	_variation()
	_ui_versus_combat()
	print("")
	quit()


## 굽는 비용. **웹 단일 스레드에서 시작할 때 한 번 내는 값이다.**
## 이게 크면 로딩이 멈춘다 (01-constraints.md §1.2 의 이탈 지점).
func _bake_cost() -> void:
	print("")
	print("--- 굽는 비용 (사건 %d개 전수) ---" % SfxEvent.all().size())
	var started := Time.get_ticks_usec()
	var total_bytes := 0
	var total_seconds := 0.0
	var worst_ms := 0.0
	var worst_event := SfxEvent.Kind.HIT_LANDED
	for event in SfxEvent.all():
		var one := Time.get_ticks_usec()
		var samples := SfxSynth.render_request(SfxCatalog.request_for(event))
		var took := (Time.get_ticks_usec() - one) / 1000.0
		if took > worst_ms:
			worst_ms = took
			worst_event = event
		total_bytes += samples.size() * 2
		total_seconds += float(samples.size()) / RATE
	var elapsed := (Time.get_ticks_usec() - started) / 1000.0
	print("전체 굽기        %.1f ms   (시작할 때 한 번)" % elapsed)
	print("사건당 평균      %.2f ms" % (elapsed / SfxEvent.all().size()))
	print("가장 비싼 사건   %.2f ms  (%s)" % [worst_ms, SfxEvent.label(worst_event)])
	print("16비트 PCM 합계  %.1f KB (오디오 %.2f 초)" % [total_bytes / 1024.0, total_seconds])
	print("내려받는 용량    0 KB  (코드가 계산한다. 파일이 없다)")


## 사건별 소리 길이. 무게 축이 실제로 움직이는지 본다.
func _lengths() -> void:
	print("")
	print("--- 무게 축이 세 값을 같이 미는가 ---")
	print("무게   배수    기본 Hz   감쇠 ms   차단 Hz   길이 ms   진동 횟수")
	for cells in [1, 2, 3, 4]:
		var request := SfxRequest.impact(SfxMaterial.Kind.METAL, float(cells))
		var voice := SfxVoice.resolve(request)
		print(
			(
				"  %d   %5.3f   %7.1f   %7.2f   %7.1f   %7.1f   %8.2f"
				% [
					cells,
					SfxVoice.weight_scale(float(cells)),
					voice.hz,
					voice.tau * 1000.0,
					voice.cutoff_hz,
					voice.duration * 1000.0,
					voice.ring_cycles(),
				]
			)
		)
	print("진동 횟수가 일정해야 한다 = f0 * tau 가 상수 (29-sound.md §29.4)")

	print("")
	print("--- 소리 길이가 동작 길이와 맞는가 ---")
	print("칸   휘두르기 전체   타격음 꼬리   꼬리/전체")
	for cells in [1, 2, 3, 4]:
		var voice := SfxVoice.resolve(SfxRequest.impact(SfxMaterial.Kind.METAL, float(cells)))
		var swing: float = SWING_SECONDS[cells - 1]
		print(
			(
				"  %d      %6.3f s      %6.3f s       %4.1f %%"
				% [cells, swing, voice.duration, 100.0 * voice.duration / swing]
			)
		)


## 겹침. 체인 타 간격 0.35초보다 꼬리가 길면 다음 타를 뭉갠다.
func _overlap() -> void:
	print("")
	print("--- 겹침 (체인 타 간격 %.2f s) ---" % CHAIN_INTERVAL)
	print("재질     무게   꼬리 ms   겹치는 시간   판정")
	for material in [SfxMaterial.Kind.METAL, SfxMaterial.Kind.FLESH, SfxMaterial.Kind.WOOD]:
		for cells in [1, 4]:
			var voice := SfxVoice.resolve(SfxRequest.impact(material, float(cells)))
			var over := voice.duration - CHAIN_INTERVAL
			var verdict := "안 겹침" if over <= 0.0 else "겹침 %.0f ms" % (over * 1000.0)
			print(
				(
					"%-6s    %d    %7.1f      %+7.0f ms   %s"
					% [
						SfxMaterial.label(material),
						cells,
						voice.duration * 1000.0,
						over * 1000.0,
						verdict,
					]
				)
			)

	# 5타를 실제로 겹쳐 섞어 본다. 뭉개지는지는 피크로 드러난다.
	print("")
	print("--- 5타 체인을 실제로 섞었을 때 ---")
	print("무게   단타 피크   5타 합 피크   증가   클리핑")
	for cells in [1, 2, 3, 4]:
		var single := SfxSynth.render_request(
			SfxRequest.impact(SfxMaterial.Kind.METAL, float(cells))
		)
		var span := int((CHAIN_INTERVAL * 4.0 + 2.0) * RATE)
		var mixed := PackedFloat32Array()
		mixed.resize(span)
		for hit in 5:
			var varied := SfxSynth.render_request(
				SfxRequest.impact(SfxMaterial.Kind.METAL, float(cells), hit + 1)
			)
			SfxSynth.mix_into(mixed, varied, int(hit * CHAIN_INTERVAL * RATE))
		var single_peak := SfxSynth.peak(single)
		var mixed_peak := SfxSynth.peak(mixed)
		print(
			(
				"  %d      %5.3f       %5.3f      %4.2fx   %s"
				% [
					cells,
					single_peak,
					mixed_peak,
					mixed_peak / single_peak,
					"넘침" if mixed_peak > 1.0 else "여유 있음",
				]
			)
		)


## 동시 발음 수. 소프트웨어로 섞어 봐서 몇 개까지 안 넘치는지 본다.
func _polyphony() -> void:
	print("")
	print("--- 동시 발음 (같은 순간에 겹쳐 냈을 때) ---")
	print("겹친 수   피크    RMS     클리핑")
	var voices := [
		SfxRequest.impact(SfxMaterial.Kind.METAL, 3.0, 1),
		SfxRequest.impact(SfxMaterial.Kind.FLESH, 3.0, 2),
		SfxRequest.impact(SfxMaterial.Kind.DIRT, 2.0, 3),
		SfxRequest.tick(SfxMaterial.Kind.WOOD, 1.0, 4),
		SfxRequest.impact(SfxMaterial.Kind.WOOD, 2.0, 5),
		SfxRequest.tone(SfxMaterial.Kind.METAL, 2.0, SfxRequest.Bend.UP, 6),
		SfxRequest.impact(SfxMaterial.Kind.STONE, 3.0, 7),
		SfxRequest.impact(SfxMaterial.Kind.METAL, 4.0, 8),
	]
	var span := int(1.5 * RATE)
	for count in [1, 2, 4, 6, 8]:
		var mixed := PackedFloat32Array()
		mixed.resize(span)
		for index in count:
			SfxSynth.mix_into(mixed, SfxSynth.render_request(voices[index]), 0)
		var mixed_peak := SfxSynth.peak(mixed)
		print(
			(
				"   %d      %5.3f   %5.3f   %s"
				% [count, mixed_peak, SfxSynth.rms(mixed), "넘침" if mixed_peak > 1.0 else "여유"]
			)
		)


## 변주. 같은 소리 다섯 번이면 기계로 들린다 (§29.6).
func _variation() -> void:
	print("")
	print("--- 변주 (5타를 변주 없이 vs 있이) ---")
	var plain := SfxSynth.render_request(SfxRequest.impact(SfxMaterial.Kind.METAL, 3.0, 0))
	print("변주 없음: 5타가 전부 같은 배열이다. 차이 0.0 %%  길이 %.1f ms" % (plain.size() * 1000.0 / RATE))
	print("")
	print("씨   기본 Hz   길이 ms   파형이 기준과 다른 정도")
	var rendered: Array[PackedFloat32Array] = []
	for hit in 5:
		var request := SfxRequest.impact(SfxMaterial.Kind.METAL, 3.0, hit + 1)
		var varied := SfxSynth.render_request(request)
		rendered.append(varied)
		print(
			(
				" %d   %7.1f   %7.1f   %20.1f %%"
				% [
					hit + 1,
					SfxVoice.resolve(request).hz,
					varied.size() * 1000.0 / RATE,
					100.0 * _difference(plain, varied),
				]
			)
		)
	# 변주끼리도 서로 달라야 한다. 기준과만 다르고 서로 같으면 소용없다.
	var pair_min := 999.0
	for a in 5:
		for b in range(a + 1, 5):
			pair_min = minf(pair_min, _difference(rendered[a], rendered[b]))
	print("변주끼리 최소 차이  %.1f %%   (0 이면 같은 소리다)" % (100.0 * pair_min))
	print("변주 비용: 씨 하나. 파일이 안 늘어난다 (§29.6)")


## UI 소리가 전투 소리에 묻히나. 자리를 나눴는지 본다.
func _ui_versus_combat() -> void:
	print("")
	print("--- UI 가 전투에 묻히나 ---")
	print("사건            길이 ms   중심 Hz(영교차)   RMS")
	var checks := [
		SfxEvent.Kind.HIT_LANDED,
		SfxEvent.Kind.BREAK_KNOCKDOWN,
		SfxEvent.Kind.UI_PRESS,
		SfxEvent.Kind.UI_CONFIRM,
		SfxEvent.Kind.UI_HOVER,
	]
	for event in checks:
		var samples := SfxSynth.render_request(SfxCatalog.request_for(event))
		print(
			(
				"%-14s  %7.1f   %13.0f   %5.3f"
				% [
					SfxEvent.label(event),
					samples.size() * 1000.0 / RATE,
					_zero_crossing_rate(samples),
					SfxSynth.rms(samples),
				]
			)
		)

	# 전투가 울리는 동안 UI 를 눌렀을 때 UI 가 남아 있는가.
	var combat := SfxSynth.render_request(SfxCatalog.request_for(SfxEvent.Kind.BREAK_KNOCKDOWN))
	var ui := SfxSynth.render_request(SfxCatalog.request_for(SfxEvent.Kind.UI_PRESS))
	print("")
	print(
		(
			"전투 RMS %.3f 대 UI RMS %.3f — 차이 %.1f dB"
			% [
				SfxSynth.rms(combat),
				SfxSynth.rms(ui),
				20.0 * log(SfxSynth.rms(ui) / SfxSynth.rms(combat)) / log(10.0),
			]
		)
	)


## 두 파형이 얼마나 다른가. 같으면 0, 완전히 무관하면 1.4 근처.
##
## 영교차율만으로는 변주가 과소평가된다 — 영교차율은 저역 차단이 지배하는데
## 차단은 안 흔들리기 때문이다. 파형 자체를 빼 봐야 잡음 씨가 바뀐 것이 드러난다.
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


## 영교차율 (Hz). 중심 주파수의 싼 대용품이다 — 밝은 소리일수록 높다.
func _zero_crossing_rate(samples: PackedFloat32Array) -> float:
	if samples.size() < 2:
		return 0.0
	var crossings := 0
	for index in range(1, samples.size()):
		if signf(samples[index]) != signf(samples[index - 1]):
			crossings += 1
	return 0.5 * crossings * RATE / samples.size()
