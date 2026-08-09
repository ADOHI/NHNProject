class_name SfxRender
extends RefCounted
## **원천 층의 문지기** (docs/design/29-sound.md §29.2).
##
## 요청 하나가 들어오면 CC0 파일로 만들지 합성으로 만들지 여기서 갈린다.
## 위의 SfxEvent / SfxRequest / SfxCatalog 는 이 파일의 존재를 모른다 —
## 사용자가 합성을 물리고 파일로 가기로 했을 때 **바뀐 것이 이 아래뿐이었던 이유**다.
##
## 합성 코드는 지우지 않았다. 재료에 구멍이 생기면 그때 메운다 (§29.10).

## 어디서 소리를 얻는가.
enum Source {
	FILE,  ## CC0 녹음물. 기본값
	SYNTH,  ## 엔진 합성. 재료가 없을 때의 대비책이자 비교용
}

## 지금 쓰는 원천. 프로토 화면이 이걸 토글해서 앞 판과 나란히 들어 볼 수 있다.
static var mode: Source = Source.FILE


## 요청 하나를 소리로. `variation` 은 몇 번째 벌인지 — 재료가 여럿이면 다른 파일이 걸린다.
static func render(request: SfxRequest, variation: int = 0) -> SfxClip:
	if mode == Source.FILE:
		var paths := SfxLibrary.paths_for(request)
		if not paths.is_empty():
			return _from_file(request, paths[variation % paths.size()])
	return _from_synth(request, variation)


## 이 요청이 실제로 어느 원천을 쓰는가. 문서와 실측이 구멍을 세는 데 쓴다.
static func source_for(request: SfxRequest) -> Source:
	if mode == Source.FILE and SfxLibrary.has_material(request):
		return Source.FILE
	return Source.SYNTH


static func _from_synth(request: SfxRequest, variation: int) -> SfxClip:
	var seeded := request.with_seed(variation + 1) if variation > 0 else request
	return SfxClip.new(SfxSynth.render_request(seeded), SfxSynth.MIX_RATE)


## 녹음물에 축을 먹인다. **순서가 중요하다.**
static func _from_file(request: SfxRequest, path: String) -> SfxClip:
	var source := SfxSample.load_clip(path)
	if source.is_empty():
		return _from_synth(request, 0)

	var voice := SfxVoice.resolve(request)
	# UI 는 무게로 피치를 바꾸지 않는다. 설계된 높이를 지킨다 (SfxVoice.scales_with_size).
	var scale := SfxVoice.weight_scale(request.weight) if voice.scales_with_size else 1.0

	# 0. 쓸 만큼만 남긴다. 늘인 뒤에 버리면 안 들릴 부분까지 계산하게 된다 —
	#    바람 소리(원본 1.5초)에서 이 한 줄이 굽는 시간을 21.4 ms 에서 크게 줄인다.
	var needed := int(voice.duration / scale * source.rate) + 2
	var samples := source.samples
	if needed < samples.size():
		samples = samples.slice(0, needed)

	# 1. 늘인다. 길이가 scale 배, 주파수가 1/scale 이 된다 — 축의 본체다.
	samples = SfxSample.resample(samples, scale)
	# 2. 깎는다. 무거울수록 둔하게. cutoff 에는 이미 /scale 이 들어 있다.
	SfxSample.lowpass(samples, voice.cutoff_hz, source.rate)
	# 2b. UI 는 아래를 깎아 전투 위로 올린다. 전투는 highpass_hz 가 0 이라 그냥 지나간다.
	SfxSample.highpass(samples, voice.highpass_hz, source.rate)
	# 3. 꼬리를 목표 길이에 맞춘다. 어택과 몸통은 안 건드린다.
	samples = SfxSample.shape_tail(samples, voice.duration, source.rate)
	# 4. 음량은 축과 표(gain)만 정한다. 파일이 정하지 않는다.
	SfxSample.normalize(samples, SfxSynth.PEAK_TARGET * voice.gain)
	SfxSample.fade_tail(samples, source.rate)

	return SfxClip.new(samples, source.rate)


## 재료가 없어 합성으로 떨어지는 사건들. §29.9.4 의 구멍 표가 이걸 쓴다.
static func gap_events() -> Array[SfxEvent.Kind]:
	var found: Array[SfxEvent.Kind] = []
	for event in SfxEvent.all():
		if source_for(SfxCatalog.request_for(event)) == Source.SYNTH:
			found.append(event)
	return found
