extends SceneTree
## **전투 한 판을 그대로 재생한다** (docs/design/29-sound.md §29.8.4).
##
## 지금까지 들려준 것은 전부 **표본**이었다 — 소리를 하나씩, 또는 묶음별로 늘어놓은 것.
## 이건 **사건이 실제로 나는 순서와 간격 그대로** 낸다.
##
## **게임과 같은 규칙을 쓴다.** `SfxSequencer` 를 그대로 불러서 벌을 고르고 겹침을 막는다 —
## 규칙이 갈리면 사용자가 들은 것과 게임에서 나는 것이 달라진다.
##
## **다만 전투 로직을 돌린 것은 아니다.** `src/core/combat/` 는 아직 `combat` 브랜치에 있어
## 이 워크트리에 없다. 그래서 **다른 레인이 문서에 적어 둔 실측 상수로 순서를 짰다** —
## 체인 타 간격 0.35초, 무너짐 문턱 30/60/100, 휘두르기 길이, 걸음 주기.
## 로직이 합쳐지면 이 파일이 실제 시뮬레이션을 읽게 바꾸면 된다.
##
##     godot --headless --path . -s res://tools/render_sfx_battle.gd

const RATE := 44100
const OUT_PATH := "res://docs/design/samples/sfx/sfx_battle.wav"

## 전투 레인 실측값.
const CHAIN_INTERVAL := 0.35
## 애니메이션 레인 실측값 - 예비 구간. 휘두르는 소리는 타격보다 이만큼 앞선다.
const SWING_LEAD := 0.27
## 걷기 주기(1.2초에 2보) / 달리기 주기(0.72초에 2보).
const RUN_STEP := 0.36

var _track := PackedFloat32Array()
var _sequencer := SfxSequencer.new()
var _timeline: Array[String] = []
var _played := 0
var _dropped := 0


func _init() -> void:
	_track.resize(int(22.0 * RATE))

	_mark(0.0, "던전 방에 들어선다")
	_at(0.00, SfxEvent.Kind.ROOM_ENTERED)
	_at(0.30, SfxEvent.Kind.MOVE_ORDERED)
	for step in 5:
		_at(0.55 + step * RUN_STEP, SfxEvent.Kind.FOOT_RUN)

	_mark(2.4, "체인을 건다 - 3칸 무기 5타")
	_at(2.40, SfxEvent.Kind.CHAIN_FIRED)
	var chain_start := 2.75
	for hit in 5:
		var at := chain_start + hit * CHAIN_INTERVAL
		_at(at - SWING_LEAD, SfxEvent.Kind.SWING_WHOOSH, 3.0)
		_at(at, SfxEvent.Kind.HIT_LANDED, 3.0)
		_at(at, SfxEvent.Kind.HIT_REACTION, 3.0)
		_at(at + 0.02, SfxEvent.Kind.CHAIN_LINK)
		# 문턱 30 / 60 / 100 을 넘는 순간. 한 타에 20 쯤 쌓인다고 보면 2·3·5타째다.
		if hit == 1:
			_at(at + 0.05, SfxEvent.Kind.BREAK_STAGGER, 3.0)
		elif hit == 2:
			_at(at + 0.05, SfxEvent.Kind.BREAK_LAUNCH, 3.0)
		elif hit == 4:
			_at(at + 0.05, SfxEvent.Kind.BREAK_KNOCKDOWN, 3.0)
			_at(at + 0.48, SfxEvent.Kind.HIT_BOUNCE, 3.0)
	_at(chain_start + 5 * CHAIN_INTERVAL, SfxEvent.Kind.CHAIN_ENDED)

	_mark(5.1, "적 셋이 반격한다 - 여기가 제일 시끄럽다")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for attacker in 3:
		var at := 5.10 + rng.randf() * 0.20
		for swing in 2:
			var weight := 1.0 + float(attacker)
			_at(at - SWING_LEAD, SfxEvent.Kind.SWING_WHOOSH, weight)
			_at(at, SfxEvent.Kind.HIT_LANDED, weight)
			_at(at, SfxEvent.Kind.HIT_REACTION, weight)
			at += CHAIN_INTERVAL * 2.0

	_mark(7.6, "우리 하나가 눕는다")
	_at(7.60, SfxEvent.Kind.BREAK_KNOCKDOWN, 4.0)
	_at(8.05, SfxEvent.Kind.DEATH_COLLAPSE)

	_mark(8.9, "물러나 다시 붙는다")
	_at(8.90, SfxEvent.Kind.MOVE_BACKOFF)
	for step in 4:
		_at(9.10 + step * RUN_STEP, SfxEvent.Kind.FOOT_RUN)
	_at(10.6, SfxEvent.Kind.MOVE_ARRIVED)

	_mark(11.0, "체인이 끊긴다 - 실패")
	_at(11.00, SfxEvent.Kind.CHAIN_FIRED)
	_at(11.30, SfxEvent.Kind.HIT_LANDED, 2.0)
	_at(11.30, SfxEvent.Kind.HIT_REACTION, 2.0)
	_at(11.70, SfxEvent.Kind.CHAIN_BROKE)

	_mark(12.4, "결과 팝업 - 뒤 · 판 · 내용")
	_at(12.40, SfxEvent.Kind.UI_VEIL_IN)
	_at(12.58, SfxEvent.Kind.UI_PIECE_IN)
	_at(12.64, SfxEvent.Kind.UI_PIECE_IN)
	_at(12.70, SfxEvent.Kind.UI_PIECE_IN)
	_at(12.86, SfxEvent.Kind.UI_CONTENT_IN)
	_at(13.60, SfxEvent.Kind.UI_HOVER)
	_at(13.85, SfxEvent.Kind.UI_PRESS)
	_at(13.95, SfxEvent.Kind.UI_CONFIRM)
	_at(14.20, SfxEvent.Kind.UI_CONTENT_OUT)
	_at(14.36, SfxEvent.Kind.UI_PIECE_OUT)
	_at(14.52, SfxEvent.Kind.UI_VEIL_OUT)

	_mark(15.2, "게이트로 나간다")
	_at(15.20, SfxEvent.Kind.GATE_SELECTED)
	_at(15.75, SfxEvent.Kind.GATE_ENTERED)

	_finish()
	quit()


## 사건 하나를 그 시각에 낸다. **게임과 같은 규칙으로 벌을 고르고 겹침을 막는다.**
func _at(seconds: float, event: SfxEvent.Kind, weight: float = -1.0) -> void:
	var decision := _sequencer.request(event, seconds)
	if not decision["allowed"]:
		_dropped += 1
		return
	var request := SfxCatalog.request_for(event)
	if weight > 0.0 and SfxCatalog.is_weight_driven(event):
		request = request.with_weight(weight)
	var clip := SfxRender.render(request, int(decision["variation"]))
	var samples := clip.samples
	if clip.rate != RATE:
		samples = SfxSample.resample(samples, float(RATE) / clip.rate)
	# 겹칠 때는 앞을 조금 건너뛴다 - 늦추지 않는다.
	var skip := int(float(decision["stagger"]) * RATE)
	if skip > 0 and skip < samples.size():
		samples = samples.slice(skip)
	SfxSynth.mix_into(_track, samples, int(seconds * RATE))
	_played += 1


func _mark(seconds: float, text: String) -> void:
	_timeline.append("%6.2f s   %s" % [seconds, text])


func _finish() -> void:
	var used := mini(int(16.6 * RATE), _track.size())
	var track := _track.slice(0, used)
	var peak := SfxSynth.peak(track)
	if peak > 0.0:
		var factor := 0.90 / peak
		for index in track.size():
			track[index] *= factor

	DirAccess.make_dir_recursive_absolute(OUT_PATH.get_base_dir())
	if FileAccess.file_exists(OUT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT_PATH))
	var error := SfxClip.new(track, RATE).to_stream().save_to_wav(OUT_PATH)

	print("")
	print("=== 전투 한 판 ===")
	for line in _timeline:
		print(line)
	print("")
	print("소리 %d개 남 / 겹쳐서 버린 것 %d개" % [_played, _dropped])
	print(
		(
			"길이 %.2f 초 / 정규화 전 피크 %.3f %s"
			% [float(track.size()) / RATE, peak, "(넘쳤다)" if peak > 1.0 else "(여유)"]
		)
	)
	print("경로 %s" % ProjectSettings.globalize_path(OUT_PATH))
	print("저장 %s" % ("성공" if error == OK else "실패 (%d)" % error))
