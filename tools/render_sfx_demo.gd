extends SceneTree
## 사용자에게 들려줄 **파일 하나**를 굽는다 (docs/design/29-sound.md §29.8.1).
##
## **3판 데모는 구성이 다르다.** 2판까지는 "무게 1→4 를 나란히" 가 첫 구간이었는데,
## 그게 **리샘플 아티팩트를 가장 잘 들리게 하는 배치**였다. 넷을 연달아 들으면
## "같은 소리를 느리게" 가 바로 드러난다. 게임에서는 그렇게 안 들린다 —
## 5타 체인 안에 섞여 나온다.
##
## 그래서 **낱개 비교와 실제 상황을 둘 다** 넣는다. 그리고 맨 앞에 **원본 그대로** 를 둔다 —
## 원본이 좋은데 우리 처리가 망치는 건지, 원본부터 안 맞는 건지를 가르기 위해서다.
##
##     godot --headless --path . -s res://tools/render_sfx_demo.gd

const RATE := 44100
const OUT_PATH := "res://docs/design/samples/sfx/sfx_demo.wav"

## 전투 레인 실측값 (src/core/combat/break_tuning.gd 의 seconds_per_hit).
const CHAIN_INTERVAL := 0.35
const GAP := 0.42

var _timeline: Array[String] = []
var _cursor := 0.0
var _track := PackedFloat32Array()


func _init() -> void:
	_track.resize(int(20.0 * RATE))

	# ── 0. 대조군. 아무 처리도 안 한 원본 ────────────────────────────
	# 여기가 좋게 들리는데 뒤가 이상하면 우리 처리가 문제고,
	# 여기부터 안 맞으면 재료가 문제다. 그 판단을 사용자가 바로 할 수 있게 맨 앞에 둔다.
	_mark("원본 그대로 (금속 · 나무 · 살, 무처리)")
	SfxRender.mode = SfxRender.Source.RAW
	for material in [SfxMaterial.Kind.METAL, SfxMaterial.Kind.WOOD, SfxMaterial.Kind.FLESH]:
		_place(SfxRequest.impact(material, 2.0), _cursor, 0)
		_cursor += 0.52
	SfxRender.mode = SfxRender.Source.FILE

	# ── 1. 낱개 비교 ────────────────────────────────────────────────
	_gap()
	_mark("무게 1 부터 4 (낱개 비교)")
	for cells in [1, 2, 3, 4]:
		_place(SfxRequest.impact(SfxMaterial.Kind.METAL, float(cells)), _cursor, cells - 1)
		_cursor += 0.60

	# ── 2. 실제 상황 ────────────────────────────────────────────────
	_gap()
	_mark("실제 상황 1: 1칸 무기 5타")
	_chain(1.0, 5, CHAIN_INTERVAL)

	_gap()
	_mark("실제 상황 2: 4칸 무기 3타")
	_chain(4.0, 3, 0.50)

	_gap()
	_mark("실제 상황 3: 무게가 섞인 체인")
	_mixed_chain()

	# ── 3. 재질 ─────────────────────────────────────────────────────
	_gap()
	_mark("재질 다섯 (무게 2)")
	for material in [
		SfxMaterial.Kind.METAL,
		SfxMaterial.Kind.WOOD,
		SfxMaterial.Kind.FLESH,
		SfxMaterial.Kind.STONE,
		SfxMaterial.Kind.DIRT,
	]:
		_place(SfxRequest.impact(material, 2.0), _cursor, 0)
		_cursor += 0.48

	_finish()
	quit()


func _chain(weight: float, hits: int, interval: float) -> void:
	var start := _cursor
	var last := 0.0
	for hit in hits:
		last = _place(
			SfxRequest.impact(SfxMaterial.Kind.METAL, weight), start + hit * interval, hit
		)
	_cursor = start + (hits - 1) * interval + last


## 실제 스쿼드는 무기가 제각각이다. 한 체인 안에 무게가 섞여 나온다.
func _mixed_chain() -> void:
	var weights: Array[float] = [2.0, 1.0, 3.0, 1.0, 4.0, 2.0]
	var start := _cursor
	var last := 0.0
	for hit in weights.size():
		var material := SfxMaterial.Kind.FLESH if hit % 3 == 1 else SfxMaterial.Kind.METAL
		last = _place(SfxRequest.impact(material, weights[hit]), start + hit * CHAIN_INTERVAL, hit)
	_cursor = start + (weights.size() - 1) * CHAIN_INTERVAL + last


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

	# **파일 전체를 한 배수로** 0.90 으로 맞춘다. 구간 사이 음량 관계는 보존된다.
	var peak := SfxSynth.peak(_track)
	if peak > 0.0:
		var factor := 0.90 / peak
		for index in _track.size():
			_track[index] *= factor

	# 폴더에 .gdignore 가 있어 Godot 이 이 wav 를 임포트하지 않는다.
	# 임포트되면 (1) 리소스 핸들이 잡혀 덮어쓰기가 ERR_FILE_CANT_WRITE 로 실패하고
	# (2) 문서용 파일이 게임 팩에 1.2 MB 로 딸려 들어간다. 둘 다 안 된다.
	DirAccess.make_dir_recursive_absolute(OUT_PATH.get_base_dir())
	if FileAccess.file_exists(OUT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT_PATH))
	var error := SfxClip.new(_track, RATE).to_stream().save_to_wav(OUT_PATH)

	print("")
	print("=== 효과음 데모 3판 ===")
	for line in _timeline:
		print(line)
	print("")
	print("길이      %.2f 초" % (float(_track.size()) / RATE))
	print("형식      %d Hz 모노 16비트 · %.0f KB" % [RATE, _track.size() * 2 / 1024.0])
	print("경로      %s" % ProjectSettings.globalize_path(OUT_PATH))
	print("저장      %s" % ("성공" if error == OK else "실패 (%d)" % error))
