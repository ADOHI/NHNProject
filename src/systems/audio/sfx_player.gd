class_name SfxPlayer
extends Node
## 소리를 실제로 내는 곳. **배치 층이 유일하게 부르는 상대다.**
##
##     Sfx.play(SfxEvent.Kind.HIT_LANDED, weapon.cells)
##
## 부르는 쪽은 파일 이름도, 재질도, 무게 계산도 모른다 (docs/design/29-sound.md §29.2).
##
## 이 노드를 통째로 지워도 게임은 돈다 — `play()` 는 무엇이 없어도 조용히 넘어간다.
## 소리가 게임 로직을 멈추게 하지 않는 것이 이 층의 유일한 책임이다.

## 전용 버스. 마스터에 바로 꽂으면 클리핑을 막을 자리가 없다.
const BUS_NAME := "Sfx"

## 동시에 살아 있을 수 있는 소리 수.
##
## **실측으로 정한 값이다** (§29.7). 네 개가 겹치면 피크가 1.10 이라 넘쳤고,
## 그 위는 버스의 리미터가 받는다. 12 는 리미터가 감당하는 선이면서
## 웹 단일 스레드에서 믹싱이 프레임을 먹지 않는 선이다.
const VOICE_COUNT := 12

## 재생 때 흔드는 피치 폭. 굽지 않고 얻는 변주라 공짜다 (§29.6).
const PITCH_JITTER := SfxVoice.PITCH_JITTER

## 겹침과 벌 고르기 규칙은 SfxSequencer 가 갖는다. 데모를 굽는 도구도 같은 것을 쓴다 —
## 규칙이 갈리면 사용자가 들은 것과 게임에서 나는 것이 달라진다.
const SAME_EVENT_WINDOW := SfxSequencer.SAME_EVENT_WINDOW

const MAX_SAME_EVENT := SfxSequencer.MAX_SAME_EVENT

const STAGGER_SECONDS := SfxSequencer.STAGGER_SECONDS

var _bank := SfxBank.new()
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _sequencer := SfxSequencer.new()
var _rng := RandomNumberGenerator.new()
var _enabled := true
## 자리가 없어 못 낸 소리 수. 실측용이지 게임 로직이 읽는 값이 아니다.
var _dropped := 0


func _ready() -> void:
	_rng.randomize()
	var bus := _ensure_bus()
	for index in VOICE_COUNT:
		var voice := AudioStreamPlayer.new()
		voice.bus = bus
		voice.name = "Voice%d" % index
		add_child(voice)
		_voices.append(voice)


## 사건 하나를 낸다. `weight` 는 무기 칸 수 — 표가 무게를 쓰는 사건에만 반영된다.
##
## 자리가 없으면 **조용히 버린다.** 소리 때문에 게임이 멈추는 일은 없어야 한다.
func play(event: SfxEvent.Kind, weight: float = -1.0) -> bool:
	if not _enabled:
		return false
	var decision := _sequencer.request(event, Time.get_ticks_msec() / 1000.0)
	if not decision["allowed"]:
		# 같은 소리를 넷 이상 겹쳐 봐야 커지기만 하고 또렷해지지 않는다.
		_dropped += 1
		return false
	return _start(_bank.stream_for(event, weight, decision["variation"]), decision["stagger"])


## 요청을 직접 낸다. 프로토 화면(src/proto/sfx/)이 축을 만져 볼 때 쓴다.
## 게임 코드는 이걸 부르지 않는다 — 사건을 부른다.
func play_request(request: SfxRequest) -> bool:
	if not _enabled:
		return false
	return _start(_bank.streams_for(request)[0])


## 미리 굽는다. 걸린 시간(ms)을 돌려준다.
func warm(events: Array = []) -> float:
	return _bank.warm(events)


func set_enabled(value: bool) -> void:
	_enabled = value
	if not value:
		stop_all()


func is_enabled() -> bool:
	return _enabled


func stop_all() -> void:
	for voice in _voices:
		voice.stop()
	_sequencer.reset()


## 지금 울리고 있는 소리 수.
func active_count() -> int:
	var count := 0
	for voice in _voices:
		if voice.playing:
			count += 1
	return count


func dropped_count() -> int:
	return _dropped


func bank() -> SfxBank:
	return _bank


func _start(stream: AudioStreamWAV, from_position: float = 0.0) -> bool:
	var voice := _free_voice()
	if voice == null:
		_dropped += 1
		return false
	voice.stream = stream
	voice.pitch_scale = 1.0 + _rng.randf_range(-PITCH_JITTER, PITCH_JITTER)
	voice.play(minf(from_position, maxf(stream.get_length() - 0.01, 0.0)))
	return true


func _free_voice() -> AudioStreamPlayer:
	for offset in VOICE_COUNT:
		var voice := _voices[(_next_voice + offset) % VOICE_COUNT]
		if not voice.playing:
			_next_voice = (_next_voice + offset + 1) % VOICE_COUNT
			return voice
	return null


## 리미터가 달린 버스를 준비한다. 이미 있으면 그대로 쓴다.
##
## 리미터는 엔진 C++ 이라 웹 단일 스레드에서도 싸다. GDScript 로 소리마다
## 음량을 재계산하는 것보다 훨씬 낫다.
func _ensure_bus() -> String:
	var existing := AudioServer.get_bus_index(BUS_NAME)
	if existing != -1:
		return BUS_NAME
	var index := AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, BUS_NAME)
	AudioServer.set_bus_send(index, "Master")
	var limiter := AudioEffectLimiter.new()
	limiter.ceiling_db = -1.0
	limiter.threshold_db = -6.0
	AudioServer.add_bus_effect(index, limiter)
	return BUS_NAME
