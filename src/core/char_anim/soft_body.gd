class_name SoftBody
extends RefCounted
## 감쇠 조화 진동자를 **닫힌 형태로** 푼다. 적분기가 없다.
##
## `docs/design/31-soft-body.md` §31.1.
##
## ## 왜 적분기를 안 쓰나
##
## 이 저장소의 애니메이션은 **시각의 순수 함수**다 (§25.3). 물리는 정의상 상태라
## `v += a*dt` 를 넣는 순간 셋을 잃는다 — 링 버퍼 없음 · 프레임률 무관 · 결정적 캡처.
##
## **그런데 감쇠진동에는 해석해가 있다.** 우리가 쓰는 두 경우 모두.
##
## | 구동 | 해 |
## | --- | --- |
## | 주기 구동 (idle · walk · run 은 한 바퀴당 정수 회다) | 같은 주파수, **진폭과 위상만 이동** |
## | 충격 (타격 · 착지) | `e^(-zw*t) * sin(wd*t)` — **사건 이후 흐른 시간의 함수** |
##
## ## 어떤 방정식인가 — **바닥 가진(base excitation)이다**
##
## 「살이 몸을 늦게 따라온다」는 **질량이 스프링으로 몸에 매달려 있고 몸이 흔들리는 것**이다.
## 몸의 변위를 `u(t)`, 살의 **상대 변위**를 `x(t)` 라 하면
##
##     x'' + 2*z*w*x' + w^2*x = -u''(t)
##
## `u = A sin(Wt)` 이면 정상상태가
##
##     x(t) = A * r^2 / sqrt((1 - r^2)^2 + (2*z*r)^2) * sin(Wt - psi)
##     r = W / w        psi = atan2(2*z*r, 1 - r^2)
##
## **이 모형을 고른 이유는 두 끝이 옳기 때문이다.** 몸이 아주 천천히 움직이면(`r -> 0`)
## 상대 변위가 **0** 이고 — 가만히 서 있는데 가슴이 떠 있지 않다 — 아주 빠르면
## (`r -> inf`) 상대 변위가 **-u** 다. 살이 제자리에 남고 몸만 지나간다.
##
## 가속도 전달률로 쓰면 저주파에서 흔들림이 안 죽어 **정지 상태가 떨린다.**
##
## ## `CharReaction` 과 나누는 일
##
## §25.27.1 이 **「타격은 떨림이 아니라 밀림이다」** 라고 못박았고, 그래서
## `CharReaction` 은 **과감쇠 계단 응답**이다 — 넘어갔다 되돌아오지 않는다.
##
## **이 파일은 그 문장의 나머지 절반이다** — *"진동은 꼬리에만 남는다."*
## 뿌리와 파츠의 밀림은 저쪽이 하고, **살의 떨림**은 여기가 한다. 그래서 여기는
## 늘 **부족감쇠**(`z < 1`)이고, 충격 목록도 저쪽 것을 그대로 읽는다 — 두 벌로 두지 않는다.

## 감쇠비의 상한. **`1` 이상이면 진동이 아니라 밀림이고, 그건 `CharReaction` 소관이다.**
const MAX_DAMPING := 0.98

## 감쇠비의 하한. `0` 이면 영원히 안 멎는다.
const MIN_DAMPING := 0.02

## 고유 진동수(Hz). 클수록 단단하다 — 가슴보다 머리카락이 낮다.
var hz := 4.0

## 감쇠비 `z`. 클수록 빨리 멎는다.
var damping := 0.35


func _init(p_hz := 4.0, p_damping := 0.35) -> void:
	hz = maxf(p_hz, 0.01)
	damping = clampf(p_damping, MIN_DAMPING, MAX_DAMPING)


## 고유 각진동수 `w`.
func omega() -> float:
	return TAU * hz


## 감쇠 각진동수 `wd = w * sqrt(1 - z^2)`. 실제로 흔들리는 빠르기다.
func damped_omega() -> float:
	return omega() * sqrt(maxf(1.0 - damping * damping, 0.0))


## **주기 구동의 이득.** 몸이 `A` 만큼 흔들릴 때 살이 몸에 대해 얼마나 어긋나는가.
##
## `r -> 0` 이면 `0`(붙어 간다), `r -> inf` 이면 `1`(제자리에 남는다).
func gain(drive_hz: float) -> float:
	if drive_hz <= 0.0:
		return 0.0
	var r := drive_hz / hz
	var rr := r * r
	var real := 1.0 - rr
	var imag := 2.0 * damping * r
	return rr / sqrt(real * real + imag * imag)


## **위상 지연(rad).** `0` 에서 `PI` 사이다 — 살은 절대 몸보다 먼저 가지 않는다.
func phase_lag(drive_hz: float) -> float:
	if drive_hz <= 0.0:
		return 0.0
	var r := drive_hz / hz
	return atan2(2.0 * damping * r, 1.0 - r * r)


## 위상 지연을 **초**로. 클립이 쓰는 `wave(cycles, t, delay)` 의 `delay` 에 그대로 더한다.
##
## **이것이 이 파일의 요점이다.** 응답이 「같은 주파수 · 다른 진폭 · 더 긴 지연」이라
## 클립과 **같은 어휘**로 표현된다. 한 바퀴당 정수 회라는 성질이 그대로 남아
## **GIF 이음매가 물리를 얹은 뒤에도 정확히 맞는다** (§25.3.2).
func lag_seconds(drive_hz: float) -> float:
	if drive_hz <= 0.0:
		return 0.0
	return phase_lag(drive_hz) / (TAU * drive_hz)


## **단위 충격 응답.** `x'' + 2zw x' + w^2 x = delta(t)` 의 해다.
##
## 물리 그대로의 값이라 **수치 적분과 그대로 견줄 수 있다** — `x(0) = 0, x'(0) = 1` 로
## 적분기를 돌리면 같은 곡선이 나와야 한다. 그 대조가 이 파일의 정직성 검사다 (§31.5.1).
func impulse_raw(age: float) -> float:
	if age <= 0.0:
		return 0.0
	var wd := damped_omega()
	if wd <= 0.0:
		return 0.0
	return exp(-damping * omega() * age) * sin(wd * age) / wd


## 최대치가 `1` 이 되게 맞춘 충격 응답. **세기를 밖에서 곱하려면 이쪽이 편하다.**
func impulse(age: float) -> float:
	var peak := impulse_peak()
	if peak <= 0.0:
		return 0.0
	return impulse_raw(age) / peak


## 충격 응답이 처음 꼭대기에 닿는 시각(초). **닫힌 형태다** — 훑어서 찾지 않는다.
func peak_seconds() -> float:
	var wd := damped_omega()
	if wd <= 0.0:
		return 0.0
	return atan2(wd, damping * omega()) / wd


## 충격 응답의 최댓값.
func impulse_peak() -> float:
	return impulse_raw(peak_seconds())


## 충격이 이만큼 지나면 잦아든 것으로 본다(초). 목록에서 버릴 때 쓴다.
func settle_seconds(ratio := 0.02) -> float:
	var decay := damping * omega()
	if decay <= 0.0:
		return INF
	return -log(maxf(ratio, 1e-6)) / decay
