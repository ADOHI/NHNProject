class_name SfxVoice
extends RefCounted
## 요청을 **소리 파라미터로 푼다** — §29.4 의 축이 여기 한 곳에 있다.
##
## 무게 1~4 를 넣으면 기본 주파수 · 감쇠 길이 · 저역 차단이 **같이** 움직인다.
## 넷을 손으로 맞추지 않는다. 손으로 맞추면 §29.4 의 `f0 * tau = 상수` 관계가 깨지고,
## "같은 무기의 크고 작은 버전" 이 아니라 "서로 다른 네 물건" 으로 들린다.

## 관성 시간 지수. src/core/char_anim/char_weapon.gd 의 `time_scale()` 과 **같은 값**이다.
##
##     질량 m ∝ c, 길이 L = 52*c^0.30, 관성 I = ⅓mL² ∝ c^1.60, 시간 ∝ √I = c^0.80
##
## 애니메이션 레인이 이미 이 지수로 휘두르기 길이를 정했다. 소리가 다른 지수를 쓰면
## 4칸 휘두르기 2.22초에 0.1초짜리 소리가 붙는 사고가 난다.
const WEIGHT_EXPONENT := 0.80

## 무게 1 · 감쇠 배수 1 에서의 감쇠 시간 (초).
const BASE_TAU := 0.030

## 무게 1 · 밝기 배수 1 에서의 저역 차단 (Hz).
const BASE_CUTOFF := 4000.0

## 몇 개의 tau 까지 남기고 자를지. exp(-4) = 0.018 이라 -35 dB, 사실상 안 들린다.
const TAIL_DECAYS := 4.0

## 잡음은 울림보다 빨리 죽는다. 이 비율이 "탁" 과 "웅" 을 가른다.
const NOISE_TAU_RATIO := 0.35

## 어택 시간 (초). 이보다 길면 타격이 아니라 "다가왔다" 로 들린다 (§29.5).
const ATTACK_SECONDS := 0.002

## 휘두르기 예비+타격 구간. src/core/char_anim/swing_clip.gd 의 ANTICIPATE(0.16)+STRIKE(0.11).
const SWING_LEAD := 0.27

## 변주 폭 (§29.6). 피치는 반음의 절반쯤 — 넘으면 다른 무기로 들린다.
const PITCH_JITTER := 0.06
const DECAY_JITTER := 0.12

## 안전 상한. 어떤 파라미터 조합도 이보다 긴 소리를 만들지 않는다.
const MAX_SECONDS := 2.0

var kind: SfxRequest.Kind
var hz: float
var tau: float
var noise_tau: float
var cutoff_hz: float
var tone_ratio: float
var partials: Array[float]
var pitch_drop: float
var attack: float
var duration: float
var gain: float
var seed: int


## 무게 축. 이 함수 하나가 세 값을 전부 움직인다.
static func weight_scale(weight: float) -> float:
	var clamped := clampf(weight, SfxRequest.MIN_WEIGHT, SfxRequest.MAX_WEIGHT)
	return pow(clamped, WEIGHT_EXPONENT)


## 요청을 푼다. 여기서 나온 SfxVoice 는 SfxSynth 가 그대로 읽어 샘플을 만든다.
static func resolve(request: SfxRequest) -> SfxVoice:
	var voice := SfxVoice.new()
	var material := SfxMaterial.of(request.material)
	var scale := weight_scale(request.weight)

	# 씨가 흔드는 것 둘. 씨가 0 이면 흔들지 않는다 (기준 소리 · 테스트용).
	var pitch_wobble := 1.0
	var decay_wobble := 1.0
	if request.seed != 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = request.seed
		pitch_wobble = 1.0 + rng.randf_range(-PITCH_JITTER, PITCH_JITTER)
		decay_wobble = 1.0 + rng.randf_range(-DECAY_JITTER, DECAY_JITTER)

	voice.kind = request.kind
	voice.seed = request.seed
	voice.partials = material.partials
	voice.tone_ratio = material.tone_ratio
	voice.pitch_drop = material.pitch_drop
	voice.attack = ATTACK_SECONDS

	# ── 축이 세 값을 동시에 민다 ──────────────────────────────────
	voice.hz = material.base_hz / scale * pitch_wobble  # 무거우면 낮다
	voice.tau = BASE_TAU * material.damping * scale * decay_wobble  # 무거우면 길다
	voice.cutoff_hz = BASE_CUTOFF * material.brightness / scale  # 무거우면 둔하다
	voice.noise_tau = voice.tau * NOISE_TAU_RATIO

	_apply_kind(voice, request, scale)
	_apply_bend(voice, request)

	# 무거우면 크다. 다만 음량 차이는 3 dB 안쪽으로 — 넘으면 작은 무기가 안 들린다.
	var loudness := 0.70 + 0.30 * (scale / weight_scale(SfxRequest.MAX_WEIGHT))
	voice.gain = request.gain * loudness
	voice.duration = minf(voice.duration, MAX_SECONDS)
	return voice


static func _apply_kind(voice: SfxVoice, request: SfxRequest, scale: float) -> void:
	match request.kind:
		SfxRequest.Kind.IMPACT:
			voice.duration = maxf(voice.tau * TAIL_DECAYS, 0.030)
		SfxRequest.Kind.WHOOSH:
			# 휘두르기 예비 구간과 길이를 맞춘다. 음이 아니라 바람이므로 잡음만 쓴다.
			voice.duration = SWING_LEAD * scale
			voice.tone_ratio = 0.0
			voice.attack = voice.duration * 0.55  # 서서히 차오른다
			voice.cutoff_hz = BASE_CUTOFF * 0.55 / scale
			voice.tau = voice.duration * 0.30
			voice.noise_tau = voice.tau
		SfxRequest.Kind.TICK:
			voice.duration = 0.018 + 0.010 * scale
			voice.tau = voice.duration * 0.25
			voice.noise_tau = voice.tau
			voice.tone_ratio = minf(voice.tone_ratio + 0.25, 0.85)
			voice.hz *= 2.0  # UI 는 전투보다 높은 자리를 쓴다 (§29.7 겹침 참고)
		SfxRequest.Kind.TONE:
			voice.duration = 0.090 * scale
			voice.tau = voice.duration * 0.42
			voice.noise_tau = voice.tau * 0.20
			voice.tone_ratio = 0.94
			voice.pitch_drop = 0.0
			voice.attack = 0.006
			voice.hz *= 2.0


static func _apply_bend(voice: SfxVoice, request: SfxRequest) -> void:
	# 열림과 닫힘은 무게가 같다. 방향으로만 갈린다 (§29.3 UI 표).
	match request.bend:
		SfxRequest.Bend.UP:
			voice.pitch_drop = -0.26  # 음수 = 올라간다
		SfxRequest.Bend.DOWN:
			voice.pitch_drop = 0.30
		_:
			pass


## 울림 안의 진동 횟수. 무게가 변해도 이 값은 안 변해야 한다 (§29.4 의 근거).
##
## 테스트가 이 불변량을 잡는다 — 누가 나중에 손으로 값을 맞추면 여기서 깨진다.
func ring_cycles() -> float:
	return hz * tau
