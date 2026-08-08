class_name AfterimageMotion
extends RefCounted
## 컨셉 5 — **잔상이 사건이 아니라 상태다.** (「너무 나간 것」 자리)
##
## > 판은 한 장이 아니다. **늘 네 장이 어긋난 채 겹쳐 있다.**
## > 가만히 두어도 판은 멎지 않고 아주 작은 궤도를 돌며, 색이 갈라진 세 장이
## > 시간차를 두고 그 궤도를 뒤따른다. 커서가 닿으면 궤도가 커지고 빨라지고,
## > 누르면 세 장이 사방으로 **부챗살처럼 터진다.**
##
## 넷 중 하나는 「이건 좀 과한데」 소리를 들어야 그 자리가 채워진다. 색분해가 화면에
## 상시로 보이는 UI 는 실용적으로는 미친 짓이고, 그래서 여기가 그 자리다.
##
## **다만 과함이 임무지 추함이 임무가 아니다.** 이 컨셉의 유일한 위험은 탁해지는 것이라,
## 그것만 구조로 막았다:
##
##   **잔상은 본체 **뒤**에 깔린다.** 본체는 불투명한 흰 판이라 겹치는 한복판을 덮는다.
##     그래서 색은 **가장자리 테두리로만** 보이고 서로 섞여 탁해질 자리가 없다
##   **세 색은 빛의 삼원색이다.** 겹치면 흰색으로 수렴하는 조합이라, 어긋남이 0 에
##     가까울수록 화면이 저절로 깨끗해진다. 감산 삼원색이면 겹칠수록 흙빛이 된다
##   **글자도 같이 갈라진다.** 판만 갈라지고 글자가 멀쩡하면 색분해가 아니라
##     그림자 세 개를 깐 것으로 보인다
##
## 그리고 **잔상 위치를 기록해 두지 않는다.** 궤도가 시각의 함수이므로 잔상은
## 그냥 `orbit(t - 지연)` 이다. 링 버퍼가 필요 없고, 프레임률이 달라도 잔상 간격이
## 변하지 않는다.

const BODY := Color(0.976, 0.976, 1.0)
const ACCENT := Color(0.145, 0.145, 0.180)
const INK := Color(0.055, 0.055, 0.078)

## 빛의 삼원색. 겹치면 흰색으로 가는 조합이라 어긋남이 줄면 저절로 깨끗해진다.
## 알파를 조금 먹인다. 검은 바탕에서는 섞여도 탁해지지 않고 어두워질 뿐이라
## 색은 그대로 살면서 터졌을 때 슬래브처럼 둔탁해지는 것만 덜어진다.
const GHOST_COLORS: Array[Color] = [
	Color(1.0, 0.153, 0.376, 0.88),
	Color(0.169, 1.0, 0.616, 0.88),
	Color(0.239, 0.478, 1.0, 0.88),
]

## 잔상 한 장이 본체보다 얼마나 뒤처지는가.
const GHOST_DELAY: float = 0.055

const IDLE_RADIUS: float = 3.4
const IDLE_PERIOD: float = 2.0
const HOVER_RADIUS: float = 13.0
const HOVER_PERIOD: float = 0.75


static func evaluate(
	time: float, hover_time: float, hovering: bool, press_time: float, pressing: bool, seed: int
) -> PlateState:
	var state := PlateState.new()
	state.body = BODY
	state.accent = ACCENT
	state.ink = INK

	# 호버는 궤도를 **키우고 빠르게** 한다. 켜고 끄는 것이 아니라 같은 운동의 세기다.
	var grow := 0.0
	if hovering:
		grow = clampf(hover_time / 0.18, 0.0, 1.0)
	else:
		grow = clampf(1.0 - hover_time / 0.30, 0.0, 1.0)
	var radius := lerpf(IDLE_RADIUS, HOVER_RADIUS, grow)
	var period := lerpf(IDLE_PERIOD, HOVER_PERIOD, grow)

	var burst := _burst(press_time, pressing)
	var phase := KitEase.hash01(seed) * TAU

	state.offset = _orbit(time, radius, period, phase)
	state.bar = 0.24 + grow * 0.54

	for i in range(GHOST_COLORS.size()):
		# 잔상은 지난 시각의 본체다. 자리를 기록해 둘 필요가 없다.
		var lag := float(i + 1) * GHOST_DELAY
		var at := _orbit(time - lag, radius, period, phase)
		# 눌리면 세 장이 사방으로 터진다. 방향은 120도씩 갈라 부챗살이 되게.
		var fan := Vector2.RIGHT.rotated(TAU * float(i) / 3.0 - 0.4) * burst
		state.add_ghost(at + fan, GHOST_COLORS[i])

	# 눌린 순간 본체만 살짝 주저앉는다. 잔상은 터져 나가는데 본체는 남아야
	# 「갈라졌다」로 읽힌다 — 다 같이 움직이면 그냥 판 하나가 흔들린 것이다.
	if pressing:
		var squash := KitEase.out_expo(press_time / 0.06, 12.0)
		state.scale = Vector2(1.0 + squash * 0.04, 1.0 - squash * 0.07)

	return state


## 본체가 도는 작은 궤도. **가만히 있어도 멎지 않는다** — 이 컨셉의 idle 은
## 「가끔 움직인다」가 아니라 **한순간도 정지하지 않는다**이다.
##
## 가로세로 주기를 어긋내 원이 아니라 열린 곡선이 되게 했다. 정원으로 돌면
## 잔상 셋이 늘 같은 간격으로 늘어서서 무늬가 되고, 무늬는 운동으로 안 읽힌다.
static func _orbit(time: float, radius: float, period: float, phase: float) -> Vector2:
	var w := TAU * time / period
	return Vector2(cos(w + phase), sin(w * 1.37 + phase * 0.6)) * radius


## 눌림 — 잔상이 터져 나갔다 빨려 들어온다.
static func _burst(press_time: float, pressing: bool) -> float:
	if pressing:
		return KitEase.out_expo(press_time / 0.05, 16.0) * 22.0
	if press_time > 0.55:
		return 0.0
	# 손을 떼면 되돌아오되 한 번 지나쳤다 온다. 잔상은 관성이 있는 물건이다.
	return 22.0 * exp(-5.0 * press_time) * cos(TAU * 2.2 * press_time)
