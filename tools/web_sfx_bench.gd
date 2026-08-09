extends Node2D
## **웹에서 효과음 비용을 재는 장면** (docs/design/29-sound.md §29.7.10).
##
## 헤드리스로 잰 값(굽기 117.7 ms)은 **데스크톱 값이지 웹 값이 아니다.**
## 헤드리스는 Dummy 오디오 드라이버라 믹싱을 아예 안 하고, wasm 은 대개 더 느리다.
## 그래서 못 잰 것으로 남겨 뒀던 넷을 여기서 잰다.
##
## 1. **디코딩** — 파일을 쓰면서 새로 생긴 항목이다. 1판(합성)에는 없었다
## 2. **굽기** — 층을 셋 쌓는 비용이 wasm 에서 얼마나 되나
## 3. **오디오 지연** — 단일 스레드에서 얼마나 늦게 나오나
## 4. **동시 발음** — 몇 개까지 프레임을 안 먹나
##
## `web_frame_bench.gd` 와 같은 이유로 `SceneTree` 스크립트가 아니라 **장면**이다.
## 내보낸 웹 빌드는 `run/main_scene` 하나만 띄우고 `-s` 로 스크립트를 못 돌린다.
##
## **프레임에 기대지 않는 것부터 잰다.** 브라우저가 탭을 안 그리면 `requestAnimationFrame`
## 이 멈추고 `_process` 도 같이 멈춘다. 그래서 디코딩 · 굽기 · 지연 · 발음 시작 비용은
## `_ready()` 안에서 프레임 없이 끝내고, 프레임 타이밍이 필요한 것만 뒤로 미룬다.
##
## **브라우저는 사용자 조작 전에는 오디오를 안 켠다.** 소리가 실제로 나는지는
## [3] 의 드라이버 이름이 말해 준다 — `Dummy` 면 안 난 것이다.

enum Phase { DECODE, BAKE, LATENCY, POLYPHONY, DONE }

## 한 단계에서 프레임을 이만큼 모은다. 웹은 rAF 이 조절돼 느리게 흐르므로 짧게 잡는다.
const _FRAMES := 90
const _WARMUP := 20

## 재 볼 동시 발음 수.
const _COUNTS: Array[int] = [1, 2, 4, 8, 12]

## 측정 중 이 간격으로 계속 새로 낸다. 한 번만 내면 꼬리가 죽은 뒤를 재게 된다.
const _RETRIGGER := 0.30

## 60 fps 예산.
const _BUDGET := 16.7

var _phase := Phase.DECODE
var _label: Label
var _lines := PackedStringArray()
var _index := -1
var _warmup := 0
var _frame_ms: PackedFloat32Array = PackedFloat32Array()
var _since_trigger := 0.0
var _sfx: Node


func _ready() -> void:
	_sfx = get_node_or_null("/root/Sfx")
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(16, 14)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98))
	layer.add_child(_label)

	# 프레임 없이 되는 것부터 즉시 끝낸다. 탭이 안 그려지면 _process 가 안 돌기 때문이다.
	_say("효과음 웹 실측")
	_say("엔진 %s / 플랫폼 %s" % [Engine.get_version_info().string, OS.get_name()])
	_say("")
	_phase = Phase.DECODE
	_decode()


func _unhandled_input(event: InputEvent) -> void:
	if _phase != Phase.POLYPHONY:
		return
	# `event is X and event.pressed` 는 타입 추론이 안 된다 (웹 빌드에서 파스 에러로 터졌다).
	# `--import` 는 0에러를 찍었고 씬을 실제로 띄워서야 드러났다.
	var pressed: bool = event is InputEventMouseButton and event.is_pressed()
	var touched: bool = event is InputEventScreenTouch and event.is_pressed()
	var keyed: bool = event is InputEventKey and event.is_pressed()
	if pressed or touched or keyed:
		_since_trigger = _RETRIGGER


## 1. 원재료 — 내보낸 빌드에는 없어야 정상이다.
##
## 층 쌓기를 미리 해 두었으므로 게임은 원재료를 안 쓴다 (§29.7.11).
## `export_presets.cfg` 가 `assets/audio/sfx/*` 를 뺀다.
func _decode() -> void:
	SfxSample.clear_cache()
	SfxLibrary.clear_cache()
	var present := 0
	for folder in SfxLibrary.COUNTS:
		for tier in SfxLibrary.COUNTS[folder]:
			present += SfxLibrary.paths_in(folder, tier).size()
	_say("[1] 원재료   %d개 (내보낸 빌드에서는 0이 정상)" % present)
	_say(
		(
			"     미리 섞은 표 %d개 / 사건 해결률 %.0f %%"
			% [
				SfxAtlas.size(),
				SfxBank.new().precomputed_ratio() * 100.0,
			]
		)
	)
	_phase = Phase.BAKE
	_bake()


## 2. 굽기 — 사건 50개를 층까지 쌓아 스트림으로.
func _bake() -> void:
	if _sfx == null:
		_say("[2] 굽기   Sfx 오토로드가 없다")
		_phase = Phase.LATENCY
		_latency()
		return
	var elapsed: float = _sfx.warm()
	var bank = _sfx.bank()
	_say(
		(
			"[2] 굽기    %.1f ms  (%d벌 %.0f KB)"
			% [elapsed, bank.baked_count(), bank.baked_bytes() / 1024.0]
		)
	)
	_say("     데스크톱 헤드리스는 117.7 ms 였다")
	_phase = Phase.LATENCY
	_latency()


## 3. 지연 — 단일 스레드 웹에서 소리가 얼마나 늦게 나오나.
func _latency() -> void:
	_say(
		(
			"[3] 지연    출력 %.1f ms / 다음 믹스까지 %.1f ms / %.0f Hz"
			% [
				AudioServer.get_output_latency() * 1000.0,
				AudioServer.get_time_to_next_mix() * 1000.0,
				AudioServer.get_mix_rate(),
			]
		)
	)
	_say(
		(
			"     드라이버 %s  %s"
			% [
				AudioServer.get_driver_name(),
				"소리 안 남 (조작 대기 또는 미지원)" if AudioServer.get_driver_name() == "Dummy" else "소리 남",
			]
		)
	)
	_play_cost()
	_say("")
	_say("[5] 프레임 타이밍은 화면이 그려질 때만 잽니다. 클릭하세요.")
	_phase = Phase.POLYPHONY
	_index = -1
	_next_count()


## 4. 발음 시작 비용 — `play()` 를 N번 부르는 데 드는 **메인 스레드** 시간.
##
## 웹에서 실제 믹싱은 AudioWorklet 쪽에서 일어나므로 프레임 예산과 분리해서 봐야 한다.
## 여기서 재는 것은 "소리를 내라고 시키는 비용" 이다.
func _play_cost() -> void:
	if _sfx == null:
		return
	_say("")
	for count in _COUNTS:
		_sfx.stop_all()
		var started := Time.get_ticks_usec()
		_trigger(count)
		var elapsed := (Time.get_ticks_usec() - started) / 1000.0
		_say(
			(
				"[4] 발음 시작  %2d개  %6.3f ms  (%.4f ms/개)  울림 %d  버림 %d"
				% [count, elapsed, elapsed / count, _sfx.active_count(), _sfx.dropped_count()]
			)
		)


func _next_count() -> void:
	_index += 1
	if _index >= _COUNTS.size():
		_finish()
		return
	_warmup = _WARMUP
	_frame_ms = PackedFloat32Array()
	_since_trigger = _RETRIGGER


func _process(delta: float) -> void:
	if _phase != Phase.POLYPHONY:
		return

	_since_trigger += delta
	if _since_trigger >= _RETRIGGER:
		_since_trigger = 0.0
		_trigger(_COUNTS[_index])

	if _warmup > 0:
		_warmup -= 1
		return

	_frame_ms.append(delta * 1000.0)
	if _frame_ms.size() < _FRAMES:
		return

	var sorted := _frame_ms.duplicate()
	sorted.sort()
	var p95: float = sorted[int(sorted.size() * 0.95)]
	var worst: float = sorted[sorted.size() - 1]
	var over := 0
	for value in sorted:
		if value > _BUDGET:
			over += 1
	_say(
		(
			"     %2d개  중앙 %5.1f  95%% %5.1f  최악 %5.1f ms  예산초과 %d/%d  버림 %d"
			% [
				_COUNTS[_index],
				sorted[sorted.size() / 2],
				p95,
				worst,
				over,
				sorted.size(),
				_sfx.dropped_count() if _sfx != null else 0,
			]
		)
	)
	_next_count()


func _trigger(count: int) -> void:
	if _sfx == null:
		return
	var events := [
		SfxEvent.Kind.HIT_LANDED,
		SfxEvent.Kind.HIT_REACTION,
		SfxEvent.Kind.FOOT_RUN,
		SfxEvent.Kind.UI_PRESS,
		SfxEvent.Kind.BREAK_STAGGER,
		SfxEvent.Kind.SWING_WHOOSH,
		SfxEvent.Kind.PACK_PLACED,
		SfxEvent.Kind.UI_CONFIRM,
		SfxEvent.Kind.BREAK_KNOCKDOWN,
		SfxEvent.Kind.FOOT_WALK,
		SfxEvent.Kind.ROOM_ENTERED,
		SfxEvent.Kind.CHAIN_LINK,
	]
	for index in count:
		_sfx.play(events[index % events.size()], 1.0 + float(index % 4))


func _finish() -> void:
	_phase = Phase.DONE
	_say("")
	_say("끝. 위 숫자를 그대로 문서에 옮긴다.")


## 화면과 콘솔에 같이 낸다 - 브라우저에서는 콘솔이 확실하고 화면은 사람이 바로 본다.
func _say(line: String) -> void:
	_lines.append(line)
	_label.text = "\n".join(_lines)
	print("[SFXBENCH] %s" % line)
