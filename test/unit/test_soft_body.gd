extends GutTest
## **해석해를 수치 적분과 대조한다.** 이 레인의 정직성이 여기 걸려 있다.
##
## `docs/design/31-soft-body.md` §31.5.1.
##
## `SoftBody` 는 감쇠 조화 진동자를 **닫힌 형태로** 푼다. 그것이 맞다는 것을
## **자기가 쓴 식으로** 검사하면 §25.13.2 그대로 늘 통과한다 —
##
## > 밑창 사건이 이것이다. 보정도 반너비를 쓰고 검증도 반너비를 썼다.
## > 서로 아귀가 맞으니 통과했고, 둘 다 그림과 어긋나 있었다.
##
## 그래서 **테스트 안에 작은 RK4 적분기를 둔다.** 미분방정식을 직접 풀어서 같은 답이
## 나오는지 잰다. 적분기는 **테스트 안에만** 있다 — 제품 코드에 들어가는 순간
## §25.3 의 셋(링버퍼 없음 · 프레임률 무관 · 결정적 캡처)을 잃는다.

## 적분기의 한 걸음(초). 2 kHz 면 12 Hz 짜리 진동을 한 주기에 160 점으로 본다.
const STEP := 0.0005

## 정상상태에 들어가는 데 주는 시간(초). 감쇠 시상수의 몇 배는 되어야 한다.
const SETTLE := 5.0


## `x'' + 2*z*w*x' + w^2*x = force(t)` 를 RK4 로 민다. **`SoftBody` 의 해를 안 본다.**
##
## `stops` 의 시각마다 `x` 를 하나씩 적어 돌려준다 — **한 번만 민다.**
## 시각마다 처음부터 다시 밀면 같은 구간을 몇 번씩 계산하게 된다.
func _integrate(body: SoftBody, force: Callable, stops: Array, x0 := 0.0, v0 := 0.0) -> Array:
	var w := TAU * body.hz
	var drag := 2.0 * body.damping * w
	var spring := w * w
	var x := x0
	var v := v0
	var t := 0.0
	var out := []
	for stop: float in stops:
		while t < stop - 1e-12:
			var h: float = minf(STEP, stop - t)
			var f1: float = force.call(t)
			var f2: float = force.call(t + 0.5 * h)
			var f3: float = force.call(t + h)
			var k1x := v
			var k1v := f1 - drag * v - spring * x
			var k2x := v + 0.5 * h * k1v
			var k2v := f2 - drag * k2x - spring * (x + 0.5 * h * k1x)
			var k3x := v + 0.5 * h * k2v
			var k3v := f2 - drag * k3x - spring * (x + 0.5 * h * k2x)
			var k4x := v + h * k3v
			var k4v := f3 - drag * k4x - spring * (x + h * k3x)
			x += h * (k1x + 2.0 * k2x + 2.0 * k3x + k4x) / 6.0
			v += h * (k1v + 2.0 * k2v + 2.0 * k3v + k4v) / 6.0
			t += h
		out.append(x)
	return out


# --- 충격 응답 ---------------------------------------------------------------


func test_impulse_response_matches_the_integrator() -> void:
	# `x(0) = 0, v(0) = 1` 이 곧 단위 충격이다. 강제항 없이 자유 진동을 푼다.
	var body := SoftBody.new(4.0, 0.30)
	var quiet := func(_at: float) -> float: return 0.0
	var stops := [0.02, 0.05, 0.11, 0.23, 0.40]
	var numeric := _integrate(body, quiet, stops, 0.0, 1.0)
	for i in stops.size():
		var at: float = stops[i]
		assert_almost_eq(
			body.impulse_raw(at), float(numeric[i]), 0.0005, "충격 응답이 적분과 갈렸다 (t = %.2f)" % at
		)


func test_impulse_response_matches_at_other_settings() -> void:
	# **한 설정에서만 맞는 식은 못 믿는다.** 작은 값에서는 옳고 큰 값에서 무너지는
	# 모양을 이 저장소에서 이미 봤다 (§25.13.45).
	var quiet := func(_at: float) -> float: return 0.0
	var stops := [0.03, 0.09, 0.25]
	for pair in [[2.0, 0.10], [3.2, 0.22], [6.5, 0.55], [9.0, 0.80]]:
		var body := SoftBody.new(pair[0], pair[1])
		var numeric := _integrate(body, quiet, stops, 0.0, 1.0)
		for i in stops.size():
			var at: float = stops[i]
			assert_almost_eq(
				body.impulse_raw(at),
				float(numeric[i]),
				0.0006,
				"%.1f Hz z=%.2f 에서 갈렸다 (t = %.2f)" % [pair[0], pair[1], at]
			)


func test_impulse_peak_is_where_the_curve_actually_turns() -> void:
	# 꼭대기를 닫힌 형태로 낸다. **훑어서 찾은 것과 같아야 한다.**
	var body := SoftBody.new(3.2, 0.22)
	var best := 0.0
	var best_at := 0.0
	for i in 4000:
		var at := float(i) * 0.0001
		var value := body.impulse_raw(at)
		if value > best:
			best = value
			best_at = at
	assert_almost_eq(body.peak_seconds(), best_at, 0.0005)
	assert_almost_eq(body.impulse_peak(), best, 1e-6)


func test_normalised_impulse_tops_out_at_one() -> void:
	for pair in [[2.0, 0.10], [4.0, 0.35], [8.0, 0.70]]:
		var body := SoftBody.new(pair[0], pair[1])
		var top := 0.0
		for i in 3000:
			top = maxf(top, body.impulse(float(i) * 0.0002))
		assert_almost_eq(top, 1.0, 0.001, "%.1f Hz 에서 정규화가 안 맞는다" % pair[0])


# --- 주기 구동의 정상상태 ------------------------------------------------------


## 바닥 가진: `x'' + 2zw x' + w^2 x = -u''`,  `u = amp * sin(W t)`.
func _steady_check(body: SoftBody, drive_hz: float, amp: float) -> void:
	var big_w := TAU * drive_hz
	var force := func(at: float) -> float: return amp * big_w * big_w * sin(big_w * at)
	var period := 1.0 / drive_hz
	var stops := []
	for step in 5:
		stops.append(SETTLE + period * float(step) / 5.0)
	var numeric := _integrate(body, force, stops)
	for i in stops.size():
		var at: float = stops[i]
		var closed := amp * body.gain(drive_hz) * sin(big_w * at - body.phase_lag(drive_hz))
		assert_almost_eq(
			closed,
			float(numeric[i]),
			amp * 0.01,
			"%.2f Hz 구동에서 정상상태가 적분과 갈렸다 (t = %.3f)" % [drive_hz, at]
		)


func test_steady_state_matches_the_integrator_below_resonance() -> void:
	_steady_check(SoftBody.new(5.0, 0.30), 0.5, 2.6)


func test_steady_state_matches_the_integrator_near_resonance() -> void:
	_steady_check(SoftBody.new(5.0, 0.30), 5.0, 1.0)


func test_steady_state_matches_the_integrator_above_resonance() -> void:
	_steady_check(SoftBody.new(3.2, 0.22), 12.0, 0.8)


# --- 두 끝이 옳은가 -----------------------------------------------------------


func test_slow_motion_makes_no_wobble() -> void:
	# **`r -> 0` 이면 살이 몸에 붙어 간다.** 가만히 서 있는데 가슴이 떠 있으면 진 것이다.
	var body := SoftBody.new(5.0, 0.30)
	assert_lt(body.gain(0.05), 0.001, "저주파에서 흔들리면 정지 자세가 떤다")


func test_fast_motion_leaves_the_flesh_behind() -> void:
	# **`r -> inf` 이면 살이 제자리에 남는다.** 이득이 1 로 붙고 위상이 반 바퀴다.
	var body := SoftBody.new(5.0, 0.30)
	assert_almost_eq(body.gain(400.0), 1.0, 0.01)
	assert_almost_eq(body.phase_lag(400.0), PI, 0.02)


func test_lag_is_never_negative() -> void:
	# 살이 몸보다 **먼저** 갈 수는 없다.
	var body := SoftBody.new(4.0, 0.35)
	for hz in [0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 20.0]:
		assert_between(body.phase_lag(hz), 0.0, PI + 0.0001, "%.2f Hz 의 위상이 범위 밖이다" % hz)
		assert_gte(body.lag_seconds(hz), 0.0)


func test_damping_is_kept_under_one() -> void:
	# **이 층은 늘 부족감쇠다.** 과감쇠 밀림은 `CharReaction` 소관이다 (§25.27.1).
	var body := SoftBody.new(4.0, 5.0)
	assert_lte(body.damping, SoftBody.MAX_DAMPING)
	assert_gt(body.damped_omega(), 0.0)


func test_a_still_drive_does_nothing() -> void:
	var body := SoftBody.new(4.0, 0.35)
	assert_eq(body.gain(0.0), 0.0)
	assert_eq(body.lag_seconds(0.0), 0.0)
	assert_eq(body.impulse_raw(-1.0), 0.0)
