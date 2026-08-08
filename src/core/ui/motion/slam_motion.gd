class_name SlamMotion
extends RefCounted
## 컨셉 1 — **내리찍기.**
##
## > 요소는 나타나지 않는다. **들이받는다.**
## > 커서가 닿으면 판이 화면 밖에서 날아와 제자리를 **지나쳤다가** 되튄다.
## > 누르면 판이 도장처럼 찍히면서 **색이 통째로 뒤집히고** 충격이 사방으로 퍼진다.
##
## 모션 서명 셋:
##   **오버슛** — 도착은 늘 목표를 지나친다 (18%)
##   **반전** — 눌림은 밝아지거나 어두워지지 않는다. 검정과 주황이 자리를 바꾼다
##   **충격** — 찍힌 자리에서 고리가 퍼지고 판이 떨린다
##
## idle 에서도 죽지 않는다. 2.2초마다 한 번씩 **툭 튄다** — 은은한 호흡이 아니라
## 짧고 분명한 한 방이다. 앞 판이 은은함으로 죽었다.

const BODY := Color(0.047, 0.047, 0.051)
const ACCENT := Color(1.0, 0.290, 0.059)
const INK := Color(0.976, 0.973, 0.965)

## 도착이 목표를 지나치는 비율.
const OVERSHOOT: float = 2.6

## idle 에서 한 번씩 튀는 주기.
const IDLE_KICK_PERIOD: float = 2.2


static func evaluate(
	time: float, hover_time: float, hovering: bool, press_time: float, pressing: bool, seed: int
) -> PlateState:
	var state := PlateState.new()
	state.body = BODY
	state.accent = ACCENT
	state.ink = INK

	_apply_idle(state, time, seed)
	_apply_hover(state, hover_time, hovering)
	_apply_press(state, press_time, pressing)

	state.apply_invert()
	return state


## idle — 2.2초마다 한 번 툭 튄다.
##
## 상시 사인파로 흔들면 「숨쉬는 UI」가 되는데 그건 어느 앱에나 있다.
## **긴 정적 + 짧은 한 방**이 훨씬 크게 읽히고, 옆 판과 위상이 달라 화면이 산만해지지 않는다.
static func _apply_idle(state: PlateState, time: float, seed: int) -> void:
	var phase := fposmod(time + KitEase.hash01(seed) * IDLE_KICK_PERIOD, IDLE_KICK_PERIOD)
	var kick := KitEase.shiver(phase, 5.2, 9.0)
	state.offset.y += kick * 3.0
	state.rotation += kick * 0.012
	state.bar = 0.34 + kick * 0.10


## 호버 — 판이 왼쪽 밖에서 날아와 제자리를 지나쳤다 되튄다.
static func _apply_hover(state: PlateState, hover_time: float, hovering: bool) -> void:
	if hovering:
		# 0.16초에 도착한다. 사람이 「빠르다」고 느끼는 하한이 대략 여기다.
		var u := clampf(hover_time / 0.16, 0.0, 1.0)
		var arrive := KitEase.out_back(u, OVERSHOOT)
		state.offset.x += (1.0 - arrive) * -46.0
		state.skew -= (1.0 - arrive) * 0.30
		state.bar = maxf(state.bar, arrive)
		# 도착한 뒤에도 잔떨림이 남는다. 멈춰 버리면 도착이 사건이 아니게 된다.
		state.offset.y += KitEase.shiver(hover_time - 0.16, 7.5, 12.0) * 4.0
		state.ink_scale = 1.0 + (1.0 - u) * 0.18
		state.ink_offset.x += (1.0 - arrive) * 22.0
	else:
		# 떠날 때는 오버슛하지 않는다. 붙는 것만 사건이다.
		var u := clampf(hover_time / 0.22, 0.0, 1.0)
		var leave := KitEase.in_quad(u)
		state.offset.x += leave * -14.0
		state.skew -= leave * 0.10
		state.bar = maxf(state.bar * (1.0 - leave), 0.34 * leave)


## 눌림 — 도장이 찍힌다. 색이 뒤집히고 고리가 퍼지고 판이 떨린다.
static func _apply_press(state: PlateState, press_time: float, pressing: bool) -> void:
	if pressing:
		var u := clampf(press_time / 0.05, 0.0, 1.0)
		state.invert = KitEase.out_expo(u, 22.0)
		state.scale = Vector2(1.0 - u * 0.06, 1.0 - u * 0.10)
		state.offset.y += u * 4.0
		state.shock = clampf(press_time / 0.34, 0.0, 1.0)
		state.ink_scale *= 1.0 - u * 0.05
		return

	# 손을 뗀 뒤 — 눌렸던 판이 튀어 오른다.
	if press_time > 0.45:
		return
	var u := clampf(press_time / 0.45, 0.0, 1.0)
	state.invert = (1.0 - KitEase.out_expo(u, 14.0)) * 0.85
	var back := KitEase.out_elastic(u, 0.30, 6.5)
	state.scale = Vector2(lerpf(0.94, 1.0, back), lerpf(0.90, 1.0, back))
	state.offset.y += (1.0 - back) * 4.0
	# 고리는 손을 떼도 계속 퍼져 나간다. 원인이 끝나도 결과는 남는다.
	state.shock = clampf(0.34 + press_time * 1.6, 0.0, 1.0)
