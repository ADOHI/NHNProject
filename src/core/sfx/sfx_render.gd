class_name SfxRender
extends RefCounted
## **원천 층의 문지기** (docs/design/29-sound.md §29.2, §29.5).
##
## 위의 SfxEvent / SfxRequest / SfxCatalog 는 이 파일의 존재를 모른다.
## 원천을 두 번 갈아 끼우는 동안 그 세 층은 한 줄도 안 바뀌었다.
##
## 3판의 핵심은 **무게를 늘여서 만들지 않는다**는 것이다 (§29.4.1) —
## 강도별로 다른 녹음을 고르고, 층을 쌓고, 리샘플은 계단 사이만 메운다.

enum Source {
	FILE,  ## CC0 녹음물. 기본값
	SYNTH,  ## 엔진 합성. 재료가 없을 때의 대비책이자 비교용
	RAW,  ## **아무 처리도 안 한 원본.** 판정용 대조군 (§29.8.1)
}

## 저역 몸통을 얹기 시작하는 무게. 이 아래는 얹지 않는다 — 가벼운 타격은 몸통이 없다.
const LOW_LAYER_FROM := 1.8

## 저역 몸통의 최대 비중. 이보다 키우면 재질이 안 들리고 "쿵" 만 남는다.
const LOW_LAYER_MAX := 0.55

## 저역 몸통을 깎는 문턱. 여기 위는 본체가 맡는다.
const LOW_LAYER_CUTOFF := 190.0

## 트랜지언트를 뽑아내는 문턱과 길이.
const TRANSIENT_HIGHPASS := 2600.0
const TRANSIENT_SECONDS := 0.030

## 트랜지언트 비중. **가벼울수록 크다** — 가벼운 타격은 거의 전부가 "딱" 이다.
const TRANSIENT_LIGHT := 0.42
const TRANSIENT_HEAVY := 0.14

## 지금 쓰는 원천. 프로토 화면이 토글해서 판을 나란히 들어 볼 수 있다.
static var mode: Source = Source.FILE


## 요청 하나를 소리로. `variation` 은 몇 번째 벌인지.
static func render(request: SfxRequest, variation: int = 0) -> SfxClip:
	if mode == Source.SYNTH:
		return _from_synth(request, variation)
	var paths := SfxLibrary.paths_for(request)
	if paths.is_empty():
		return _from_synth(request, variation)
	var path := paths[variation % paths.size()]
	if mode == Source.RAW:
		return SfxSample.load_clip(path)
	return _from_file(request, path, variation)


static func source_for(request: SfxRequest) -> Source:
	if mode != Source.SYNTH and SfxLibrary.has_material(request):
		return mode
	return Source.SYNTH


static func _from_synth(request: SfxRequest, variation: int) -> SfxClip:
	var seeded := request.with_seed(variation + 1) if variation > 0 else request
	return SfxClip.new(SfxSynth.render_request(seeded), SfxSynth.MIX_RATE)


## 녹음물에 축을 먹인다. **늘이는 것이 아니라 고르고 쌓는다.**
static func _from_file(request: SfxRequest, path: String, variation: int) -> SfxClip:
	var source := SfxSample.load_clip(path)
	if source.is_empty():
		return _from_synth(request, variation)

	var voice := SfxVoice.resolve(request)
	var rate := source.rate
	var ratio := _residual_ratio(request, voice)

	# 1. 쓸 만큼만 남긴다.
	var samples := source.samples
	var needed := int(voice.duration / maxf(ratio, 0.1) * rate) + 2
	if needed < samples.size():
		samples = samples.slice(0, needed)

	# 2. **어택은 그대로 두고 뒤만 늘인다.** 계단 사이를 메우는 정도라 ratio 는 1 근처다.
	samples = SfxSample.stretch_keeping_attack(samples, ratio, rate, SfxVoice.KEEP_ATTACK_SECONDS)

	# 3. 무거울수록 둔하게 / UI 는 아래를 깎아 전투 위로.
	SfxSample.lowpass(samples, voice.cutoff_hz, rate)
	# 1극은 6 dB/oct 라 UI 음정 신호의 기본음을 못 눌렀다 (확인음이 536 Hz 에 남았다).
	# 두 번 걸어 12 dB/oct 로 만든다.
	SfxSample.highpass(samples, voice.highpass_hz, rate)
	SfxSample.highpass(samples, voice.highpass_hz, rate)
	samples = SfxSample.shape_tail(samples, voice.duration, rate)

	# 4. 층을 쌓는다. 타격일 때만 — UI 딸깍에 저역 몸통을 얹을 이유가 없다.
	#
	# **길이도 여기서 정해진다.** 무거운 타격이 긴 것은 어택이 느려서가 아니라
	# **저역 몸통이 오래 남기 때문**이다. 늘이지 않고 더해서 길이를 만든다.
	if request.kind == SfxRequest.Kind.IMPACT:
		var low := _low_body(request, variation, rate, voice.duration)
		var out := PackedFloat32Array()
		out.resize(maxi(samples.size(), low.size()))
		SfxSynth.mix_into(out, samples, 0)
		SfxSynth.mix_into(out, low, 0)
		_add_transient(out, request, rate)
		samples = out

	SfxSample.normalize(samples, SfxSynth.PEAK_TARGET * voice.gain)
	SfxSample.fade_tail(samples, rate)
	return SfxClip.new(samples, rate)


## 고른 강도 단과 실제 무게의 차이만 리샘플로 메운다.
##
## **2판은 여기서 최대 3.03배를 썼다.** 지금은 계단이 세 개라 ±25 % 안쪽이면 충분하다.
static func _residual_ratio(request: SfxRequest, voice: SfxVoice) -> float:
	if not voice.scales_with_size:
		return 1.0
	var folder := SfxLibrary.folder_for(request)
	if folder.is_empty():
		return 1.0
	var nominal := SfxLibrary.tier_weight_for(folder, request.weight)
	var ratio := SfxVoice.weight_scale(request.weight) / SfxVoice.weight_scale(nominal)
	return clampf(ratio, SfxVoice.RESIDUAL_MIN, SfxVoice.RESIDUAL_MAX)


## **트랜지언트 — "딱".** 자기 어택을 고역만 뽑아 다시 얹는다.
##
## 가벼울수록 크게 얹는다. 가벼운 타격은 거의 전부가 트랜지언트이고,
## 무거운 타격은 몸통이 주인공이다.
static func _add_transient(samples: PackedFloat32Array, request: SfxRequest, rate: int) -> void:
	var count := mini(int(TRANSIENT_SECONDS * rate), samples.size())
	if count <= 0:
		return
	var spark := samples.slice(0, count)
	SfxSample.highpass(spark, TRANSIENT_HIGHPASS, rate)
	var t := (
		(request.weight - SfxRequest.MIN_WEIGHT) / (SfxRequest.MAX_WEIGHT - SfxRequest.MIN_WEIGHT)
	)
	var gain := lerpf(TRANSIENT_LIGHT, TRANSIENT_HEAVY, t)
	for index in count:
		samples[index] += spark[index] * gain


## **저역 몸통 — "퍽".** 무게가 여기 있고, **길이도 여기서 나온다.**
##
## 무거워질수록 더 얹는다. 본체를 늘이는 것이 아니라 **다른 소리를 더하는 것**이다 —
## 이게 2판과 3판의 차이 전부다.
static func _low_body(
	request: SfxRequest, variation: int, rate: int, seconds: float
) -> PackedFloat32Array:
	if request.weight < LOW_LAYER_FROM:
		return PackedFloat32Array()
	var paths := SfxLibrary.low_paths()
	if paths.is_empty():
		return PackedFloat32Array()
	var source := SfxSample.load_clip(paths[variation % paths.size()])
	if source.is_empty():
		return PackedFloat32Array()

	var body := source.samples.duplicate()
	if source.rate != rate:
		body = SfxSample.resample(body, float(rate) / source.rate)
	SfxSample.lowpass(body, LOW_LAYER_CUTOFF, rate)
	body = SfxSample.shape_tail(body, seconds, rate)
	SfxSample.normalize(body, 1.0)

	var span := (request.weight - LOW_LAYER_FROM) / (SfxRequest.MAX_WEIGHT - LOW_LAYER_FROM)
	var gain := LOW_LAYER_MAX * clampf(span, 0.0, 1.0)
	for index in body.size():
		body[index] *= gain
	return body


## 재료가 없어 합성으로 떨어지는 사건들.
static func gap_events() -> Array[SfxEvent.Kind]:
	var found: Array[SfxEvent.Kind] = []
	for event in SfxEvent.all():
		if not SfxLibrary.has_material(SfxCatalog.request_for(event)):
			found.append(event)
	return found
