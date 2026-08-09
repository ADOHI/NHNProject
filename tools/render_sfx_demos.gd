extends SceneTree
## **사건 종류별로 잘라 낸 데모** (docs/design/29-sound.md §29.8.3).
##
## 3판 데모는 한 파일에 전부 넣은 14초짜리였다. 그걸 듣고 "개판" 이라는 판정이 나왔는데,
## **어디가 개판인지는 알 수 없었다.**
##
## > **한 덩어리로 물으면 한 덩어리로 거절당한다.**
##
## 그래서 묶음별로 자른다. 판정이 "타격은 되는데 UI 가 싸구려다" 처럼
## **쓸 수 있는 모양**으로 돌아오게 하려는 것이다.
##
## 그리고 **A/B 로 붙인다.** "이게 어때?" 보다 "둘 중 뭐가 나아?" 가 답하기 쉽다.
## 게임에서 제일 많이 나는 소리인 타격은 반드시 그렇게 한다.
##
##     godot --headless --path . -s res://tools/render_sfx_demos.gd

const RATE := 44100
const OUT_DIR := "res://docs/design/samples/sfx"
const CHAIN_INTERVAL := 0.35
const GAP := 0.45

var _track := PackedFloat32Array()
var _cursor := 0.0
var _lines: Array[String] = []
var _made: Array[String] = []


func _init() -> void:
	_hits()
	_hits_ab()
	_ui()
	_locomotion()
	_world()
	_report()
	quit()


## 1. 타격 — 게임에서 제일 많이 나는 소리.
func _hits() -> void:
	_begin()
	_mark("무게 1 부터 4")
	for cells in [1, 2, 3, 4]:
		_place(_hit(float(cells)), _cursor, cells - 1)
		_cursor += 0.60
	_gap()
	_mark("1칸 5타")
	_chain(1.0, 5, CHAIN_INTERVAL)
	_gap()
	_mark("4칸 3타")
	_chain(4.0, 3, 0.50)
	_gap()
	_mark("무게 섞인 체인")
	var weights: Array[float] = [2.0, 1.0, 3.0, 1.0, 4.0, 2.0]
	var start := _cursor
	var last := 0.0
	for index in weights.size():
		last = _place(_hit(weights[index]), start + index * CHAIN_INTERVAL, index)
	_cursor = start + (weights.size() - 1) * CHAIN_INTERVAL + last
	_gap()
	_mark("적 셋이 동시에 (겹칠 때)")
	_crowd()
	_finish("sfx_hits")


## 2. 타격 A/B — 같은 사건을 다른 원재료로 두 벌.
##
## A 는 지금 쓰는 금속, B 는 같은 무게의 나무다. 재질이 아니라 **어느 쪽이 타격으로
## 읽히는가**를 묻는 것이다 — 무기가 금속이어야 할 이유는 소리에 없다.
func _hits_ab() -> void:
	_begin()
	for cells in [2, 4]:
		_mark("%d칸 — A (금속)" % cells)
		for repeat in 3:
			_place(_hit(float(cells)), _cursor, repeat)
			_cursor += 0.42
		_gap()
		_mark("%d칸 — B (나무)" % cells)
		for repeat in 3:
			_place(SfxRequest.impact(SfxMaterial.Kind.WOOD, float(cells)), _cursor, repeat)
			_cursor += 0.42
		_gap()
	_finish("sfx_hits_ab")


## 3. UI — 단추와 팝업. 전투와 자리를 나눴는지 귀로 확인하는 자리.
func _ui() -> void:
	_begin()
	_mark("커서 · 눌림 · 뗌")
	for event in [SfxEvent.Kind.UI_HOVER, SfxEvent.Kind.UI_PRESS, SfxEvent.Kind.UI_RELEASE]:
		_place(SfxCatalog.request_for(event), _cursor, 0)
		_cursor += 0.40
	_gap()
	_mark("확인 · 취소 · 비활성")
	for event in [SfxEvent.Kind.UI_CONFIRM, SfxEvent.Kind.UI_CANCEL, SfxEvent.Kind.UI_DISABLED]:
		_place(SfxCatalog.request_for(event), _cursor, 0)
		_cursor += 0.55
	_gap()
	_mark("팝업 열림 (뒤 · 판 · 내용)")
	_place(SfxCatalog.request_for(SfxEvent.Kind.UI_VEIL_IN), _cursor, 0)
	_place(SfxCatalog.request_for(SfxEvent.Kind.UI_PIECE_IN), _cursor + 0.18, 0)
	_place(SfxCatalog.request_for(SfxEvent.Kind.UI_PIECE_IN), _cursor + 0.24, 1)
	_place(SfxCatalog.request_for(SfxEvent.Kind.UI_CONTENT_IN), _cursor + 0.40, 0)
	_cursor += 1.10
	_gap()
	_mark("팝업 닫힘 (내용 · 판 · 뒤)")
	_place(SfxCatalog.request_for(SfxEvent.Kind.UI_CONTENT_OUT), _cursor, 0)
	_place(SfxCatalog.request_for(SfxEvent.Kind.UI_PIECE_OUT), _cursor + 0.16, 0)
	_place(SfxCatalog.request_for(SfxEvent.Kind.UI_VEIL_OUT), _cursor + 0.32, 0)
	_cursor += 1.10
	_gap()
	_mark("UI 가 전투 위에서 들리나 (같이)")
	_place(_hit(3.0), _cursor, 0)
	_place(SfxCatalog.request_for(SfxEvent.Kind.UI_PRESS), _cursor + 0.10, 0)
	_place(_hit(2.0), _cursor + 0.35, 1)
	_place(SfxCatalog.request_for(SfxEvent.Kind.UI_CONFIRM), _cursor + 0.45, 0)
	_cursor += 1.40
	_finish("sfx_ui")


## 4. 발과 몸.
func _locomotion() -> void:
	_begin()
	_mark("걷기 (1.2초에 2보)")
	for step in 6:
		_place(SfxCatalog.request_for(SfxEvent.Kind.FOOT_WALK), _cursor + step * 0.60, step)
	_cursor += 3.8
	_gap()
	_mark("달리기 (0.72초에 2보)")
	for step in 8:
		_place(SfxCatalog.request_for(SfxEvent.Kind.FOOT_RUN), _cursor + step * 0.36, step)
	_cursor += 3.1
	_gap()
	_mark("도약 · 착지")
	_place(SfxCatalog.request_for(SfxEvent.Kind.JUMP_TAKEOFF), _cursor, 0)
	_place(SfxCatalog.request_for(SfxEvent.Kind.JUMP_LAND), _cursor + 0.68, 0)
	_cursor += 1.5
	_gap()
	_mark("피격 · 바닥 튐 · 무너짐")
	_place(SfxCatalog.request_for(SfxEvent.Kind.HIT_REACTION).with_weight(3.0), _cursor, 0)
	_place(SfxCatalog.request_for(SfxEvent.Kind.HIT_BOUNCE).with_weight(3.0), _cursor + 0.43, 0)
	_place(SfxCatalog.request_for(SfxEvent.Kind.DEATH_COLLAPSE), _cursor + 1.0, 0)
	_cursor += 2.0
	_finish("sfx_body")


## 5. 던전 · 백팩 · 체인.
func _world() -> void:
	_begin()
	_mark("방 진입 · 못 가는 방 · 게이트")
	for event in [
		SfxEvent.Kind.ROOM_ENTERED, SfxEvent.Kind.ROOM_REFUSED, SfxEvent.Kind.GATE_SELECTED
	]:
		_place(SfxCatalog.request_for(event), _cursor, 0)
		_cursor += 0.65
	_place(SfxCatalog.request_for(SfxEvent.Kind.GATE_ENTERED), _cursor, 0)
	_cursor += 0.95
	_gap()
	_mark("백팩 집기 · 놓기 · 실패 · 회전")
	for event in [
		SfxEvent.Kind.PACK_PICKED,
		SfxEvent.Kind.PACK_PLACED,
		SfxEvent.Kind.PACK_REJECTED,
		SfxEvent.Kind.PACK_ROTATED
	]:
		_place(SfxCatalog.request_for(event), _cursor, 0)
		_cursor += 0.50
	_gap()
	_mark("체인 발사 · 진행 · 정상 종료")
	_place(SfxCatalog.request_for(SfxEvent.Kind.CHAIN_FIRED), _cursor, 0)
	for link in 4:
		_place(SfxCatalog.request_for(SfxEvent.Kind.CHAIN_LINK), _cursor + 0.30 + link * 0.16, link)
	_place(SfxCatalog.request_for(SfxEvent.Kind.CHAIN_ENDED), _cursor + 1.10, 0)
	_cursor += 1.8
	_gap()
	_mark("체인 끊김 (실패)")
	_place(SfxCatalog.request_for(SfxEvent.Kind.CHAIN_FIRED), _cursor, 0)
	_place(SfxCatalog.request_for(SfxEvent.Kind.CHAIN_BROKE), _cursor + 0.35, 0)
	_cursor += 1.0
	_finish("sfx_world")


## 적 셋이 각자 때린다. 데모가 하나씩만 내면 안 드러나는 자리다 (§29.7.12).
func _crowd() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var start := _cursor
	for attacker in 3:
		var at := start + rng.randf() * 0.12
		for swing in 3:
			var weight := 1.0 + float(attacker)
			_place(_hit(weight), at, swing)
			_place(
				SfxCatalog.request_for(SfxEvent.Kind.HIT_REACTION).with_weight(weight), at, swing
			)
			at += CHAIN_INTERVAL * 2.0
	_cursor = start + 2.4


func _hit(weight: float) -> SfxRequest:
	return SfxCatalog.request_for(SfxEvent.Kind.HIT_LANDED).with_weight(weight)


func _begin() -> void:
	_track = PackedFloat32Array()
	_track.resize(int(24.0 * RATE))
	_cursor = 0.0
	_lines = []


func _place(request: SfxRequest, at: float, variation: int) -> float:
	var clip := SfxRender.render(request, variation)
	var samples := clip.samples
	if clip.rate != RATE:
		samples = SfxSample.resample(samples, float(RATE) / clip.rate)
	SfxSynth.mix_into(_track, samples, int(at * RATE))
	return float(samples.size()) / RATE


func _chain(weight: float, hits: int, interval: float) -> void:
	var start := _cursor
	var last := 0.0
	for hit in hits:
		last = _place(_hit(weight), start + hit * interval, hit)
	_cursor = start + (hits - 1) * interval + last


func _gap() -> void:
	_cursor += GAP


func _mark(text: String) -> void:
	_lines.append("%6.2f s   %s" % [_cursor, text])


func _finish(name: String) -> void:
	var used := mini(int((_cursor + 0.3) * RATE), _track.size())
	var track := _track.slice(0, used)
	var peak := SfxSynth.peak(track)
	if peak > 0.0:
		var factor := 0.90 / peak
		for index in track.size():
			track[index] *= factor

	var path := "%s/%s.wav" % [OUT_DIR, name]
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var error := SfxClip.new(track, RATE).to_stream().save_to_wav(path)

	_made.append(
		(
			"%-16s %5.2f 초  %4.0f KB  %s"
			% [
				name + ".wav",
				float(track.size()) / RATE,
				track.size() * 2 / 1024.0,
				"OK" if error == OK else "실패"
			]
		)
	)
	print("")
	print("--- %s ---" % name)
	for line in _lines:
		print(line)


func _report() -> void:
	print("")
	print("=== 묶음별 데모 ===")
	for line in _made:
		print(line)
	print("")
	print("경로 %s" % ProjectSettings.globalize_path(OUT_DIR))
