class_name SfxSynth
extends RefCounted
## **원천 층** — 지금은 합성이 여기 들어 있다 (docs/design/29-sound.md §29.2).
##
## 나중에 CC0 샘플이나 생성물로 갈아 끼울 때 **바뀌는 곳은 이 파일뿐이다.**
## 위의 SfxRequest / SfxEvent 는 그대로 둔다.
##
## 노드에 의존하지 않는다. 그래서 헤드리스에서 파형을 직접 검사할 수 있고,
## 굽는 시점을 재생 시점과 분리할 수 있다.

## 샘플레이트. **44100 이 아니라 22050 인 것은 실측 근거가 있다.**
##
## 우리 저역 차단은 가장 밝을 때(금속 · 무게 1)도 6000 Hz 고, 최고 배음은
## 620 * 8.933 = 5538 Hz 다. 둘 다 22050 의 나이퀴스트(11025 Hz) 아래다.
## 44100 으로 구우면 **들리지 않는 대역을 계산하느라 굽는 시간과 메모리가 정확히 두 배**가 된다.
## 웹 단일 스레드에서 시작할 때 내는 값이라 이 두 배가 그대로 로딩 지연이다 (§29.7).
##
## 재생 때 AudioServer 가 44100 으로 리샘플하지만 그건 엔진 C++ 이라 싸다.
const MIX_RATE := 22050

## 끝을 이만큼 선형으로 죽인다. 지수 감쇠만으로는 마지막에 계단이 남아 "틱" 이 난다.
const FADE_OUT_SECONDS := 0.003

## 정규화 목표 피크.
##
## **실측으로 정한 값이다.** 0.80 으로 두면 두 소리만 겹쳐도 피크가 1.30 이 되어 넘쳤다
## (§29.7 동시 발음 표). 0.50 이면 네 개까지 여유가 남고, 그 위는 버스 리미터가 받는다.
const PEAK_TARGET := 0.50

## 배음이 죽는 속도. 클수록 기본음만 남는다.
const PARTIAL_ROLLOFF := 1.4

## 필터 안정 구간. 나이퀴스트에 붙으면 1극 필터가 아무 일도 안 한다.
const MIN_CUTOFF := 80.0
const MAX_CUTOFF_RATIO := 0.45

## 피치가 여기 아래로 내려가면 소리가 아니라 진동이다.
const MIN_HZ := 20.0


## 목소리 하나를 샘플로 만든다. **여기가 유일한 합성 지점이다.**
##
## 사슬은 §29.5 그대로다 —
## 잡음 + 음 → 어택 → 지수 감쇠 → 저역 통과 → 페이드 → 정규화.
static func render(voice: SfxVoice) -> PackedFloat32Array:
	var count := int(voice.duration * MIX_RATE)
	var out := PackedFloat32Array()
	if count <= 0:
		return out
	out.resize(count)

	var rng := RandomNumberGenerator.new()
	rng.seed = voice.seed if voice.seed != 0 else 1

	var cutoff := clampf(voice.cutoff_hz, MIN_CUTOFF, MIX_RATE * MAX_CUTOFF_RATIO)
	var alpha := 1.0 - exp(-TAU * cutoff / MIX_RATE)  # 1극 저역 통과 계수
	var low_passed := 0.0

	var partial_count := voice.partials.size()
	var phases := PackedFloat64Array()
	phases.resize(partial_count)
	var amps := _partial_amplitudes(partial_count)

	var attack := maxf(voice.attack, 1.0 / MIX_RATE)
	var tau := maxf(voice.tau, 1.0 / MIX_RATE)
	var noise_tau := maxf(voice.noise_tau, 1.0 / MIX_RATE)
	var noise_ratio := 1.0 - voice.tone_ratio

	for index in count:
		var t := float(index) / MIX_RATE
		var tone_env := exp(-t / tau)
		var noise_env := exp(-t / noise_tau)
		var attack_env := minf(t / attack, 1.0)

		# 피치 하강. 부딪힌 물체가 에너지를 잃는 것 (sfxr 의 slide 에 해당).
		var hz := maxf(voice.hz * (1.0 - voice.pitch_drop * (1.0 - tone_env)), MIN_HZ)

		var tone := 0.0
		if voice.tone_ratio > 0.0:
			for p in partial_count:
				phases[p] += TAU * hz * voice.partials[p] / MIX_RATE
				tone += sin(phases[p]) * amps[p]

		var noise := rng.randf_range(-1.0, 1.0)
		var raw := (
			attack_env * (voice.tone_ratio * tone * tone_env + noise_ratio * noise * noise_env)
		)
		low_passed += (raw - low_passed) * alpha
		out[index] = low_passed

	_fade_tail(out)
	_normalize(out, voice.gain)
	return out


## 요청 하나를 바로 샘플로. 배치 층이 쓰는 짧은 길.
static func render_request(request: SfxRequest) -> PackedFloat32Array:
	return render(SfxVoice.resolve(request))


## 재생 가능한 스트림으로 굽는다.
##
## `AudioStreamGenerator` 가 아니라 `AudioStreamWAV` 인 이유는 §29.5 에 있다 —
## 웹 단일 스레드에서 매 프레임 버퍼를 채우다 굶으면 소리가 뚝뚝 끊긴다.
static func bake(voice: SfxVoice) -> AudioStreamWAV:
	return from_samples(render(voice))


static func bake_request(request: SfxRequest) -> AudioStreamWAV:
	return from_samples(render_request(request))


## 샘플 배열을 스트림으로 감싼다. 데모 파일 굽기(tools/render_sfx_demo.gd)도 이걸 쓴다.
static func from_samples(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = to_pcm16(samples)
	return stream


## 부동소수 샘플 → 리틀엔디언 16비트 PCM.
static func to_pcm16(samples: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for index in samples.size():
		var clamped := clampf(samples[index], -1.0, 1.0)
		bytes.encode_s16(index * 2, int(round(clamped * 32767.0)))
	return bytes


## src 를 dest 의 offset 위치에 더한다. **겹침 실측(§29.7)이 이걸 쓴다.**
##
## 체인 5타는 0.35초 간격인데 4칸 금속 꼬리는 그보다 길다. 실제로 겹쳐 봐야
## 뭉개지는지 알 수 있고, 그건 재생 없이 배열 위에서 잴 수 있다.
static func mix_into(
	dest: PackedFloat32Array, src: PackedFloat32Array, offset: int, gain: float = 1.0
) -> void:
	for index in src.size():
		var at := offset + index
		if at < 0 or at >= dest.size():
			continue
		dest[at] += src[index] * gain


## 피크 절댓값. 클리핑 판정에 쓴다.
static func peak(samples: PackedFloat32Array) -> float:
	var found := 0.0
	for value in samples:
		found = maxf(found, absf(value))
	return found


## 제곱평균제곱근. 체감 음량 비교에 쓴다 — 피크보다 귀에 가깝다.
static func rms(samples: PackedFloat32Array) -> float:
	if samples.is_empty():
		return 0.0
	var total := 0.0
	for value in samples:
		total += value * value
	return sqrt(total / samples.size())


static func _partial_amplitudes(count: int) -> PackedFloat32Array:
	var amps := PackedFloat32Array()
	amps.resize(count)
	var total := 0.0
	for index in count:
		var amount := 1.0 / pow(float(index + 1), PARTIAL_ROLLOFF)
		amps[index] = amount
		total += amount
	if total > 0.0:
		for index in count:
			amps[index] /= total
	return amps


static func _fade_tail(samples: PackedFloat32Array) -> void:
	var fade := mini(int(FADE_OUT_SECONDS * MIX_RATE), samples.size())
	if fade <= 0:
		return
	var start := samples.size() - fade
	for index in fade:
		samples[start + index] *= 1.0 - float(index) / fade


static func _normalize(samples: PackedFloat32Array, gain: float) -> void:
	var found := peak(samples)
	if found <= 0.0:
		return
	var factor := PEAK_TARGET * gain / found
	for index in samples.size():
		samples[index] *= factor
