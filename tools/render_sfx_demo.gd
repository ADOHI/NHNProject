extends SceneTree
## 사용자에게 들려줄 **파일 하나**를 굽는다 (docs/design/29-sound.md §29.7).
##
## 소리는 직렬이라 여러 파일을 보내면 판정이 비싸진다. 열다섯 개를 보내면
## 열다섯 번 들어야 한다. **그래서 한 파일에 다 넣고 15초 안쪽으로 맞춘다.**
##
##     godot --headless --path . -s res://tools/render_sfx_demo.gd

const RATE := SfxSynth.MIX_RATE
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
	_track.resize(int(16.0 * RATE))

	_mark("무게 1 부터 4 까지 (금속 타격)")
	for cells in [1, 2, 3, 4]:
		_place(SfxRequest.impact(SfxMaterial.Kind.METAL, float(cells)), _cursor)
		_cursor += 0.62 + 0.06 * cells

	_gap()
	_mark("5타 체인 (무게 3, 타 간격 %.2f 초)" % CHAIN_INTERVAL)
	_chain(3.0, true)

	_gap()
	_mark("대조 A: 변주 없음 (같은 씨 5번)")
	_chain(3.0, false)

	_gap()
	_mark("대조 B: 변주 있음 (씨를 흔든 5번)")
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
		_place(SfxRequest.impact(material, 2.0), _cursor)
		_cursor += 0.55

	_finish()
	quit()


func _chain(weight: float, varied: bool) -> void:
	var start := _cursor
	for hit in CHAIN_HITS:
		var seed_value := (hit + 1) if varied else 7
		_place(
			SfxRequest.impact(SfxMaterial.Kind.METAL, weight, seed_value),
			start + hit * CHAIN_INTERVAL
		)
	# 마지막 타의 꼬리가 끝날 때까지 기다린다.
	var tail := SfxVoice.resolve(SfxRequest.impact(SfxMaterial.Kind.METAL, weight)).duration
	_cursor = start + (CHAIN_HITS - 1) * CHAIN_INTERVAL + tail


func _place(request: SfxRequest, at: float) -> void:
	SfxSynth.mix_into(_track, SfxSynth.render_request(request), int(at * RATE))


func _gap() -> void:
	_cursor += GAP


func _mark(text: String) -> void:
	_timeline.append("%6.2f s   %s" % [_cursor, text])


func _finish() -> void:
	# 실제로 쓴 만큼만 남긴다.
	var used := mini(int((_cursor + 0.3) * RATE), _track.size())
	_track = _track.slice(0, used)

	# **파일 전체를 한 번에** 0.90 으로 맞춘다. 전체를 같은 배수로 밀므로
	# 무게 사이 · 재질 사이의 음량 관계는 그대로 보존된다.
	# 게임 안에서는 이렇게 안 한다 — 거기선 SfxSynth.PEAK_TARGET 이 동시 발음 여유를 남긴다.
	var peak := SfxSynth.peak(_track)
	if peak > 0.0:
		var factor := 0.90 / peak
		for index in _track.size():
			_track[index] *= factor

	DirAccess.make_dir_recursive_absolute(OUT_PATH.get_base_dir())
	var stream := SfxSynth.from_samples(_track)
	var error := stream.save_to_wav(OUT_PATH)

	print("")
	print("=== 효과음 데모 ===")
	for line in _timeline:
		print(line)
	print("")
	print("길이      %.2f 초" % (float(_track.size()) / RATE))
	print("피크      %.3f" % peak)
	print("샘플레이트 %d Hz 모노 16비트" % RATE)
	print("용량      %.0f KB" % (_track.size() * 2 / 1024.0))
	print("경로      %s" % ProjectSettings.globalize_path(OUT_PATH))
	print("저장      %s" % ("성공" if error == OK else "실패 (%d)" % error))
