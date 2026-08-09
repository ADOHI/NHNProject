class_name SfxSample
extends RefCounted
## 읽은 파형에 **무게 축을 먹인다** (docs/design/29-sound.md §29.4).
##
## **파일을 그대로 틀면 무게 1~4 가 사라진다.** 5타가 똑같이 다섯 번 나고,
## 4칸 무기와 1칸 무기가 같은 소리를 낸다. 재료만 파일에서 오고 축은 계산에서 온다.
##
## 합성에서 파일로 바뀌면서 **입력이 「생성한 파형」에서 「읽은 파형」으로 바뀌었을 뿐**,
## 축은 SfxVoice 그대로다.

## 리샘플 비율이 이 아래로 내려가면 계산할 것이 없다.
const MIN_RATIO := 0.01

## 어택과 늘인 꼬리를 이어 붙일 때 섞는 길이.
const BLEND_SECONDS := 0.002

## 꼬리를 깎기 전에 원래 소리를 이만큼 그대로 둔다 (목표 길이 대비).
##
## 실제 녹음의 어택과 몸통은 건드리지 않는다는 뜻이다. 여기까지 합성 엔벨로프로
## 덮으면 녹음을 쓰는 의미가 없어진다 — 다시 합성처럼 들린다.
const HOLD_RATIO := 0.35

## 꼬리 끝에서 남는 크기. exp 로 여기까지 떨어뜨린 뒤 자른다.
const TAIL_FLOOR := 0.02

static var _cache: Dictionary = {}


## 파일 하나를 샘플로 읽는다. 같은 파일은 한 번만 읽는다.
static func load_clip(path: String) -> SfxClip:
	if _cache.has(path):
		return _cache[path]
	var stream := load(path) as AudioStreamWAV
	if stream == null:
		var empty := SfxClip.new()
		_cache[path] = empty
		return empty
	var clip := SfxClip.new(from_stream(stream), stream.mix_rate)
	_cache[path] = clip
	return clip


## `AudioStreamWAV` 의 PCM 을 부동소수 샘플로.
static func from_stream(stream: AudioStreamWAV) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var bytes := stream.data
	if stream.format != AudioStreamWAV.FORMAT_16_BITS:
		# 우리 도구가 굽는 것은 항상 16비트다. 다른 형식이 오면 조용히 비운다 —
		# 소리 하나가 안 나는 것이 게임이 죽는 것보다 낫다.
		return out
	var frames := bytes.size() / 2
	var channels := 2 if stream.stereo else 1
	out.resize(frames / channels)
	for index in out.size():
		if channels == 1:
			out[index] = bytes.decode_s16(index * 2) / 32768.0
		else:
			var left := bytes.decode_s16(index * 4)
			var right := bytes.decode_s16(index * 4 + 2)
			out[index] = (left + right) * 0.5 / 32768.0
	return out


## **무게 축의 핵심.** 비율만큼 늘여서 다시 읽는다.
##
## 테이프를 느리게 돌리는 것과 같다 — 길이가 `ratio` 배가 되고 주파수가 `1/ratio` 이 된다.
## **그래서 `f0 * tau` 가 저절로 보존된다.** 합성에서 손으로 맞췄던 불변량(§29.4)이
## 리샘플에서는 공짜로 나온다. 큰 물체와 작은 물체의 관계가 원래 그렇기 때문이다.
static func resample(samples: PackedFloat32Array, ratio: float) -> PackedFloat32Array:
	if ratio <= MIN_RATIO or samples.is_empty():
		return samples
	if is_equal_approx(ratio, 1.0):
		return samples
	var out := PackedFloat32Array()
	out.resize(int(samples.size() * ratio))
	var last := samples.size() - 1
	for index in out.size():
		var source := index / ratio
		var whole := int(source)
		if whole >= last:
			out[index] = samples[last]
			continue
		# 선형 보간. 이보다 좋은 방법도 있지만 타격음 길이에서는 차이가 안 들린다.
		out[index] = lerpf(samples[whole], samples[whole + 1], source - whole)
	return out


## **어택은 그대로 두고 뒤만 늘인다** (§29.4.1). 2판 실패의 직접 원인을 고치는 함수다.
##
## 리샘플은 파형 전체를 늘이므로 **부딪히는 순간까지 같이 느려진다.**
## 그런데 실제로는 그렇지 않다 —
##
##     작은 타격:  어택 빠름 · 감쇠 짧음
##     큰 타격:    어택 **똑같이 빠름** · 감쇠 김
##
## 큰 물체가 부딪혀도 **부딪히는 순간 자체는 순간이다.** 어택을 늘이면
## 무거워지는 대신 느려지고, 그게 "느리게 튼 소리" 로 들린다.
##
## 그래서 앞 `attack_seconds` 는 손대지 않고 뒤만 늘인 뒤 이어 붙인다.
static func stretch_keeping_attack(
	samples: PackedFloat32Array, ratio: float, rate: int, attack_seconds: float
) -> PackedFloat32Array:
	if samples.is_empty() or is_equal_approx(ratio, 1.0) or ratio <= MIN_RATIO:
		return samples
	# 어택이 소리의 절반을 넘으면 나눌 것이 없다. 그냥 전체를 늘인다.
	var attack := mini(int(attack_seconds * rate), samples.size() / 2)
	if attack <= 0:
		return resample(samples, ratio)

	var head := samples.slice(0, attack)
	var tail := resample(samples.slice(attack), ratio)
	var out := PackedFloat32Array()
	out.resize(head.size() + tail.size())
	for index in head.size():
		out[index] = head[index]
	for index in tail.size():
		out[head.size() + index] = tail[index]

	# 이어 붙인 자리를 짧게 섞는다. 그냥 붙이면 파형이 끊겨 "틱" 이 난다.
	var blend := mini(int(BLEND_SECONDS * rate), mini(head.size(), tail.size()))
	for index in blend:
		var mix := float(index) / blend
		var at := attack - blend + index
		if at >= 0 and at < out.size():
			out[at] = lerpf(out[at], tail[index], mix * 0.5)
	return out


## 1극 저역 통과. 무거울수록 둔해진다.
static func lowpass(samples: PackedFloat32Array, cutoff_hz: float, rate: int) -> void:
	var limit := clampf(cutoff_hz, SfxSynth.MIN_CUTOFF, rate * SfxSynth.MAX_CUTOFF_RATIO)
	var alpha := 1.0 - exp(-TAU * limit / rate)
	var value := 0.0
	for index in samples.size():
		value += (samples[index] - value) * alpha
		samples[index] = value


## 1극 고역 통과. **UI 가 전투에 묻히지 않게 아래를 깎는다** (§29.7.6).
##
## 저역 통과를 한 벌 만들어 빼는 방식이다 — 1극에서는 그게 곧 고역 통과다.
static func highpass(samples: PackedFloat32Array, cutoff_hz: float, rate: int) -> void:
	if cutoff_hz <= 0.0:
		return
	var limit := clampf(cutoff_hz, SfxSynth.MIN_CUTOFF, rate * SfxSynth.MAX_CUTOFF_RATIO)
	var alpha := 1.0 - exp(-TAU * limit / rate)
	var low := 0.0
	for index in samples.size():
		low += (samples[index] - low) * alpha
		samples[index] -= low


## 꼬리를 목표 길이에 맞춘다. **어택과 몸통은 안 건드린다.**
##
## 녹음이 목표보다 짧으면 아무것도 하지 않는다 — 억지로 늘이지 않는다.
static func shape_tail(
	samples: PackedFloat32Array, seconds: float, rate: int
) -> PackedFloat32Array:
	var target := int(seconds * rate)
	if target <= 0 or samples.size() <= target:
		return samples
	var hold := int(target * HOLD_RATIO)
	var out := samples.slice(0, target)
	var decay := maxi(target - hold, 1)
	# hold 지점부터 TAIL_FLOOR 까지 지수로 떨어뜨린다.
	var tau := decay / -log(TAIL_FLOOR)
	for index in range(hold, out.size()):
		out[index] *= exp(-float(index - hold) / tau)
	return out


## 피크를 맞춘다. **원본 음량 차이가 27.7 dB 라 이게 없으면 재질마다 음량이 널뛴다.**
static func normalize(samples: PackedFloat32Array, target: float) -> void:
	var peak := SfxSynth.peak(samples)
	if peak <= 0.0:
		return
	var factor := target / peak
	for index in samples.size():
		samples[index] *= factor


## 끝을 죽인다. 자른 자리에 계단이 남으면 "틱" 이 난다.
static func fade_tail(samples: PackedFloat32Array, rate: int) -> void:
	var fade := mini(int(SfxSynth.FADE_OUT_SECONDS * rate), samples.size())
	if fade <= 0:
		return
	var start := samples.size() - fade
	for index in fade:
		samples[start + index] *= 1.0 - float(index) / fade


static func clear_cache() -> void:
	_cache.clear()
