extends SceneTree
## 사용자에게 들려줄 **파일 하나**를 굽는다 (docs/design/29-sound.md §29.8.1).
##
## 소리는 직렬이라 여러 파일을 보내면 판정이 비싸진다. 열다섯 개를 보내면
## 열다섯 번 들어야 한다. **그래서 한 파일에 다 넣고 15초 안쪽으로 맞춘다.**
##
## **앞 판(합성)과 구간 구성을 똑같이 유지한다.** 그래야 나란히 놓고 비교된다.
##
##     godot --headless --path . -s res://tools/render_sfx_demo.gd

## 재질마다 레이트가 달라서(천 44100, 나머지 22050) 섞기 전에 여기로 맞춘다.
const RATE := 44100
const OUT_PATH := "res://docs/design/samples/sfx/sfx_demo.wav"

## 전투 레인 실측값 (src/core/combat/break_tuning.gd 의 seconds_per_hit).
const CHAIN_INTERVAL := 0.35
const CHAIN_HITS := 5

## 구간 사이 침묵. 이게 없으면 어디서 어디까지가 한 묶음인지 안 들린다.
const GAP := 0.60

var _timeline: Array[String] = []
var _cursor := 0.0
var _track := PackedFloat32Array()


func _init() -> void:
	_track.resize(int(18.0 * RATE))

	_mark("무게 1 부터 4 까지 (금속 타격)")
	for cells in [1, 2, 3, 4]:
		_place(SfxRequest.impact(SfxMaterial.Kind.METAL, float(cells)), _cursor, cells - 1)
		_cursor += 0.62 + 0.06 * cells

	_gap()
	_mark("5타 체인 (무게 3, 타 간격 %.2f 초)" % CHAIN_INTERVAL)
	_chain(3.0, true)

	_gap()
	_mark("대조 A: 변주 없음 (같은 파일 5번)")
	_chain(3.0, false)

	_gap()
	_mark("대조 B: 변주 있음 (매번 다른 녹음)")
	_chain(3.0, true)

	_gap()
	_mark("재질 다섯 (무게 2 로 고정)")
	for material in [
		SfxMaterial.Kind.METAL,
		SfxMaterial.Kind.WOOD,
		SfxMaterial.Kind.FLESH,
		SfxMaterial.Kind.STONE,
		SfxMaterial.Kind.CLOTH,
	]:
		_place(SfxRequest.impact(material, 2.0), _cursor, 0)
		_cursor += 0.55

	_finish()
	quit()


func _chain(weight: float, varied: bool) -> void:
	var start := _cursor
	var last := 0.0
	for hit in CHAIN_HITS:
		# 변주 없음 = 매번 같은 벌(같은 파일). 변주 있음 = 벌을 돌린다.
		var variation := hit if varied else 0
		var at := start + hit * CHAIN_INTERVAL
		last = _place(SfxRequest.impact(SfxMaterial.Kind.METAL, weight), at, variation)
	_cursor = start + (CHAIN_HITS - 1) * CHAIN_INTERVAL + last


## 소리 하나를 놓는다. 그 소리의 길이(초)를 돌려준다.
func _place(request: SfxRequest, at: float, variation: int) -> float:
	var clip := SfxRender.render(request, variation)
	var samples := clip.samples
	if clip.rate != RATE:
		samples = SfxSample.resample(samples, float(RATE) / clip.rate)
	SfxSynth.mix_into(_track, samples, int(at * RATE))
	return float(samples.size()) / RATE


func _gap() -> void:
	_cursor += GAP


func _mark(text: String) -> void:
	_timeline.append("%6.2f s   %s" % [_cursor, text])


func _finish() -> void:
	var used := mini(int((_cursor + 0.3) * RATE), _track.size())
	_track = _track.slice(0, used)

	# **파일 전체를 한 배수로** 0.90 으로 맞춘다. 전체를 같은 배수로 밀므로
	# 무게 사이 · 재질 사이의 음량 관계는 그대로 보존된다.
	# 게임 안에서는 이렇게 안 한다 — 거기선 동시 발음 여유를 남긴다 (§29.7.4).
	var peak := SfxSynth.peak(_track)
	if peak > 0.0:
		var factor := 0.90 / peak
		for index in _track.size():
			_track[index] *= factor

	DirAccess.make_dir_recursive_absolute(OUT_PATH.get_base_dir())
	var stream := SfxClip.new(_track, RATE).to_stream()
	var error := stream.save_to_wav(OUT_PATH)

	print("")
	print("=== 효과음 데모 (원천: CC0 파일) ===")
	for line in _timeline:
		print(line)
	print("")
	print("길이      %.2f 초" % (float(_track.size()) / RATE))
	print("피크      %.3f (정규화 전)" % peak)
	print("형식      %d Hz 모노 16비트" % RATE)
	print("용량      %.0f KB" % (_track.size() * 2 / 1024.0))
	print("경로      %s" % ProjectSettings.globalize_path(OUT_PATH))
	print("저장      %s" % ("성공" if error == OK else "실패 (%d)" % error))
