class_name KitMetrics
extends RefCounted
## 나전 UI 키트의 치수 · 자간 · 전이 시간. **단일 출처.**
##
## 노드 트리에 의존하지 않는다. 씬 없이 검증할 수 있어야 하므로 전부 정적 함수다.
## 근거는 [`docs/design/20-ui-kit.md`](../../../docs/design/20-ui-kit.md) §20.3.2 · §20.3.3.

## 버튼의 급.
enum Grade {
	MINOR,  ## 보조
	MAIN,  ## 주 행동
	GRAVE,  ## 결단
}

## 길이의 원자. 끊음질(자개를 실처럼 끊어 붙이는 기법) 조각의 최소 폭에서 잡았다.
const UNIT: float = 4.0

## 자개 이음매의 폭. 판의 **왼쪽 모서리를 따라 세로로** 박힌다.
##
## 2차 · 3차 렌더에서 글자 밑을 가로지르는 띠로 두었더니 자개가 아니라
## **진행 막대**와 **자막 판**으로 읽혔다. 나전에서 상감은 면을 채우는 것이 아니라
## 모서리를 따라 가는 것이고, 세로로 세우면 글자와도 다투지 않는다.
const SEAM_WIDTH: float = 8.0

## 이음매는 판의 아래로 넘어간다. 위아래를 맞추면 그 순간 테두리가 된다.
const SEAM_OVERSHOOT_BOTTOM: float = 9.0

## 화면에 보이는 자개 조각 하나의 목표 폭. 판이 넓어져도 조각은 커지지 않는다 —
## 실제 나전에서 조각 크기는 판 크기와 무관하다. 그래서 띠는 늘이는 것이 아니라
## **원판에서 더 긴 구간을 잘라 온다.**
const BAND_PIECE_WIDTH: float = 15.0

## 오른쪽 위 모서리를 비스듬히 자른 폭. 자개는 톱으로 자르는 재료라 둥근 모서리가 없다.
const CHAMFER: float = 12.0

## 황동 실선은 **닫히지 않는다.** 왼쪽으로 넘어가고 오른쪽에서 못 미친다.
const BRASS_OVERSHOOT_LEFT: float = 10.0
const BRASS_SHORTFALL_RIGHT: float = 24.0

const _HEIGHT: Array[float] = [36.0, 44.0, 56.0]
const _FONT_SIZE: Array[int] = [13, 15, 18]
const _PAD_X: Array[float] = [24.0, 28.0, 36.0]

## 폰트가 SongMyung 하나뿐이라 굵기 대비가 없다. 자간이 위계의 절반을 진다 —
## 명조는 자간을 벌리면 격이 올라가고, 작은 글자일수록 더 벌려야 한다.
const _TRACKING: Array[float] = [2.2, 2.0, 1.6]

## 간격 세 급. 화면에서는 숫자가 아니라 **무엇이 이어지는가**로 읽힌다.
const GAP_ONE_BODY: float = UNIT * 1.0  ## 자개 띠가 두 판을 가로질러 이어진다
const GAP_GROUP: float = UNIT * 4.0  ## 띠는 끊기고 황동 실선만 이어진다
const GAP_APART: float = UNIT * 10.0  ## 아무것도 이어지지 않는다

## 상태가 붙는 것이 떨어지는 것보다 빠르다. 반대로 두면 굼떠 보인다.
const HOVER_IN: float = 0.09
const HOVER_OUT: float = 0.24
const PRESS_IN: float = 0.04
const PRESS_OUT: float = 0.18
const FOCUS_IN: float = 0.16
const FOCUS_OUT: float = 0.16


static func height_for(grade: Grade) -> float:
	return _HEIGHT[grade]


static func font_size_for(grade: Grade) -> int:
	return _FONT_SIZE[grade]


static func pad_x_for(grade: Grade) -> float:
	return _PAD_X[grade]


static func tracking_for(grade: Grade) -> float:
	return _TRACKING[grade]


## 글자 너비에 맞추되 **원자의 정수배로 올림한다.**
##
## 자동 크기에 맡기면 판마다 폭이 제각각이 되고, 그러면 자개 띠의 조각 리듬이
## 판마다 다른 자리에서 잘린다. 규격이 보이려면 셀 수 있어야 한다.
static func fit_width(text_width: float, grade: Grade) -> float:
	var padded := text_width + pad_x_for(grade) * 2.0
	return ceilf(padded / UNIT) * UNIT


## 목표값으로 지수 접근한다. `tau` 초에 약 95% 도달한다.
##
## Tween 을 쓰지 않는 이유: 호버가 붙는 도중에 떨어지면 Tween 은 끊고 새로 시작해
## 속도가 튄다. 지수 접근은 어느 지점에서 방향이 바뀌어도 이어진다.
static func approach(current: float, target: float, delta: float, tau: float) -> float:
	if tau <= 0.0 or delta <= 0.0:
		return target
	return current + (target - current) * (1.0 - exp(-delta * 3.0 / tau))


## 상태가 붙는 중인지 떨어지는 중인지에 따라 다른 시간을 골라 접근한다.
static func approach_state(
	current: float, target: float, delta: float, tau_in: float, tau_out: float
) -> float:
	return approach(current, target, delta, tau_in if target > current else tau_out)
