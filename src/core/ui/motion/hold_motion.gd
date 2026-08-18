class_name HoldMotion
extends RefCounted
## 컨셉 3 — **시간이 끊긴다.**
##
## > 화면이 60fps 로 돌지 않는다. **초당 여덟 칸으로 넘어간다.**
## > 손으로 한 장 한 장 찍은 자막처럼, 판은 한 포즈에 **멎어 있다가** 다음 포즈로
## > 순간이동한다. 누르면 아예 **완전히 멈춘다.**
##
## **SHEAR 와 겹치지 않게 축을 갈랐다.** 둘 다 「끊김」 계열이지만
##   SHEAR — **공간**이 끊긴다. 판이 조각나 어긋난다. 판 자체는 늘 움직인다
##   HOLD  — **시간**이 끊긴다. 판은 늘 성한 통짜이고, 대신 **멎는다**
##
## 모션 서명 셋:
##   **8칸 격자** — 모든 값이 초당 여덟 칸에서만 바뀐다. 그 사이엔 완전 정지다
##   **포즈 점프** — 자세가 이어지지 않는다. 중간 자세가 존재하지 않는다
##   **눌림 = 완전 정지** — 다른 판들이 계속 덜컥이는 동안 이 판만 얼어붙는다
##
## 배색도 앞의 둘과 갈랐다 (검정/주황 · 뼈색/청록 다음이라) — 형광 노랑에 마젠타다.

const BODY := Color(1.0, 0.898, 0.0)
const ACCENT := Color(1.0, 0.0, 0.565)
const INK := Color(0.051, 0.051, 0.055)

## 초당 몇 칸으로 넘길 것인가. **이 숫자 하나가 컨셉의 전부다.**
##
## 8 이 아니라 10 인 이유는 조형이 아니라 **인화** 때문이다. 견본을 20fps GIF 로 내는데
## 8 은 20 과 정수배가 아니라(20/8 = 2.5) 한 포즈가 2프레임 또는 3프레임 유지되어
## **불규칙**해졌다. 엔진에서는 규칙적인데 GIF 에서만 고장처럼 보였다 (§20.8).
const STEPS: float = 10.0

## idle 에서 한 포즈를 몇 칸 물고 있는가. 매 칸 바꾸면 지직거리는 잡음이 된다.
const IDLE_HOLD: int = 3


static func evaluate(
	time: float, hover_time: float, hovering: bool, press_time: float, pressing: bool, seed: int
) -> PlateState:
	var state := PlateState.new()
	state.body = BODY
	state.accent = ACCENT
	state.ink = INK

	var step := _step(time)
	_apply_idle(state, step, seed)

	if hovering:
		_apply_hover(state, _step(hover_time), step)
	if pressing:
		_apply_press(state, _step(press_time))
	elif press_time < 0.30:
		_apply_release(state, _step(press_time))

	state.apply_invert()
	return state


## 시각을 칸 번호로 바꾼다. 이 함수를 거치지 않은 값은 이 컨셉에 있으면 안 된다.
static func _step(time: float) -> int:
	return int(KitEase.hold(maxf(time, 0.0), STEPS) * STEPS)


## idle — 세 칸마다 다른 포즈로 **점프한다.** 그 사이엔 완전 정지다.
##
## 사인파로 흔들면 부드러워지고, 그러면 60fps 로 도는 다른 UI 와 구별되지 않는다.
## 자세가 이어지지 않는 것 자체가 「손으로 찍었다」의 증거다.
static func _apply_idle(state: PlateState, step: int, seed: int) -> void:
	var pose := step / IDLE_HOLD
	var a := KitEase.hash01(seed * 17 + pose)
	var b := KitEase.hash01(seed * 17 + pose * 3 + 5)
	state.offset = Vector2((a - 0.5) * 6.0, (b - 0.5) * 5.0)
	state.rotation = (a - 0.5) * 0.040
	state.scale = Vector2(1.0 + (b - 0.5) * 0.05, 1.0 + (a - 0.5) * 0.05)
	state.ink_offset = Vector2((b - 0.5) * 4.0, 0.0)
	state.bar = 0.28 + a * 0.16


## 호버 — 다섯 칸짜리 **타법**을 친 뒤 두 포즈를 오간다.
##
## 크기가 1 에서 1.22 로 「자라는」 것이 아니라 **1 다음 칸이 1.22 다.**
## 그리고 네 칸마다 한 칸씩 색이 뒤집혀 번쩍인다 — 예능 자막의 그 박자다.
static func _apply_hover(state: PlateState, since: int, step: int) -> void:
	match since:
		0:
			state.scale = Vector2(1.26, 0.84)
			state.ink_scale = 1.34
			state.offset = Vector2(0.0, -6.0)
			state.rotation = -0.035
		1:
			state.scale = Vector2(0.90, 1.14)
			state.ink_scale = 0.88
			state.offset = Vector2(0.0, 4.0)
			state.rotation = 0.028
		2:
			state.scale = Vector2(1.10, 0.95)
			state.ink_scale = 1.14
			state.offset = Vector2(3.0, -2.0)
			state.rotation = -0.014
		3:
			state.scale = Vector2(0.98, 1.03)
			state.ink_scale = 0.96
			state.offset = Vector2(-2.0, 1.0)
			state.rotation = 0.008
		_:
			# 타법이 끝나면 두 포즈를 8분음표로 오간다. 멎지 않되 부드럽지도 않다.
			var flip := 1.0 if step % 2 == 0 else -1.0
			state.scale = Vector2(1.04, 1.02)
			state.ink_scale = 1.06
			state.offset = Vector2(flip * 3.0, flip * -2.0)
			state.rotation = flip * 0.016
	state.bar = 1.0
	# 네 칸에 한 칸 번쩍. 켜져 있는 내내가 아니라 **박자로** 온다.
	state.invert = 1.0 if (step % 4 == 0) else 0.0


## 눌림 — **완전 정지.** 옆 판들이 계속 덜컥이는 동안 이 판만 얼어붙는다.
##
## 「멈춤」이 이 컨셉에서 가장 센 사건이다. 다른 컨셉에서 눌림은 더 크게 움직이는
## 것이었는데, 시간이 끊기는 판에서는 **아무것도 안 하는 것**이 가장 크게 읽힌다.
static func _apply_press(state: PlateState, since: int) -> void:
	state.offset = Vector2.ZERO
	state.rotation = 0.0
	state.scale = Vector2.ONE
	state.ink_offset = Vector2.ZERO
	state.ink_scale = 1.0
	state.bar = 1.0
	# 한 칸 얼어 있다가 색이 뒤집힌다. 동시에 하면 정지가 안 보인다.
	state.invert = 1.0 if since >= 1 else 0.0


## 뗌 — 두 칸 크게 튀고 끝. 되돌아오는 과정을 그리지 않는다.
static func _apply_release(state: PlateState, since: int) -> void:
	match since:
		0:
			state.scale = Vector2(1.18, 0.88)
			state.ink_scale = 1.20
			state.offset = Vector2(0.0, -5.0)
		1:
			state.scale = Vector2(0.94, 1.07)
			state.ink_scale = 0.94
			state.offset = Vector2(0.0, 3.0)
		_:
			pass
	state.bar = 1.0
