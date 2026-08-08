class_name ActionButtonMotion
extends RefCounted
## 버튼 한 개의 **거동**. 노드에 의존하지 않는 순수 계산이라 씬 없이 검증된다.
##
## `ActionButton` (src/ui/kit/action_button.gd) 이 이걸 하나 들고, 마우스 사건을
## 넘기고, 매 프레임 값을 읽어서 그린다. 그리는 쪽에는 시간 계산이 없다.
##
## ## 왜 상태값이 아니라 시계인가 — 앞 판이 여기서 죽었다
##
## 상태를 목표값으로 **지수 접근**(`current += (target - current) * k`) 시키면
## 어느 순간에도 목표를 **지나칠 방법이 없다.** 그래서 오버슛도 되튐도 원리적으로
## 불가능하고, 타격감이 나오지 않는다.
##
## 그래서 여기 있는 것은 값이 아니라 **사건이 일어난 뒤 흐른 시간**뿐이다
## (`_since_hover`, `_since_down` …). 모든 출력은 그 시간의 함수다. 시계가 0 에서
## 시작하므로 `KitEase.out_back` 이 목표를 지나갔다 되돌아올 자리가 생긴다.
##
## ## 색과 기하는 다른 곡선을 쓴다
##
## **기하는 오버슛하고 색은 오버슛하지 않는다.** 판이 목표 높이를 지나쳐 올라가는
## 것은 손맛이지만, 색이 목표를 지나치면 그냥 **번쩍하는 결함**으로 읽힌다.
## 그래서 `rise()`(기하)와 `warmth()`(색)가 같은 시계에서 다른 곡선으로 나온다.
##
## ## 판정 매체의 표본 간격이 설계 제약이다
##
## 20fps GIF 로 판정하므로 표본 간격이 0.05초다. 되튐을 0.34초 · 감쇠 9 로 잡으면
## 수치로는 완벽한데 **프레임 두 장에 다 끝나서 눈에는 아무 일도 안 일어난다.**
## 아래 상수는 표본 서너 장에 걸리도록 늘려 잡은 값이다.

## 상태 넷. `DISABLED` 는 시계가 아예 흐르지 않는다 — 비활성은 **정지**여야 한다.
enum State { NORMAL, HOVER, PRESSED, DISABLED }

## 커서가 올라와 판이 떠오르는 데 걸리는 시간.
const RISE_TIME: float = 0.22

## 커서가 떠나 판이 내려앉는 시간. 올라오는 것보다 빠르면 미련이 없어 보인다.
const FALL_TIME: float = 0.15

## 눌린 판이 바닥까지 가라앉는 시간. 손가락보다 빨라야 한다.
const SINK_TIME: float = 0.05

## 손을 뗀 뒤 되튐이 잦아드는 시간.
##
## 이 값과 아래 두 상수가 함께 20fps 표본에서 `1.00 → -0.07 → -0.41 → 0.08 → 0.15`
## 를 만든다. 음수가 **늘어남**이고, 그게 세 프레임에 걸쳐 잡히므로 동작으로 읽힌다.
const RECOVER_TIME: float = 0.34
const RECOVER_PERIOD: float = 0.55
const RECOVER_DECAY: float = 3.0

## 판이 떠오르는 높이(px)와 눌려 가라앉는 깊이(px).
const LIFT: float = 3.0
const SINK: float = 4.5

## 눌린 순간 안쪽 칸이 반전되는 데 걸리는 시간과 되돌아오는 시간.
const INVERT_IN: float = 0.05
const INVERT_OUT: float = 0.10

## 광택 띠가 판을 한 번 훑는 주기. 평상과 커서가 다르다.
const SHEEN_IDLE: float = 4.6
const SHEEN_HOVER: float = 0.62

## 테두리를 타고 도는 빛의 주기. 평상에서도 버튼이 살아 있게 하는 유일한 것이다.
const RUNNER_PERIOD: float = 2.6

## 갈매기표가 한 번 지나가는 주기.
const CHEVRON_IDLE: float = 2.2
const CHEVRON_HOVER: float = 0.70

## 눌림 충격파가 퍼져 사라지는 시간.
const IMPACT_TIME: float = 0.40

var state: State = State.NORMAL

## 평상시에도 흐르는 시계. 상시 모션(광택 · 테두리 빛)만 여기서 시각을 읽는다.
var _ambient: float = 0.0

## 사건 뒤 흐른 시간. `-1` 은 **아직 그 사건이 없었다**는 뜻이다.
var _since_hover: float = -1.0
var _since_leave: float = -1.0
var _since_down: float = -1.0
var _since_up: float = -1.0


## 한 프레임 흘린다. **비활성이면 아무 시계도 흐르지 않는다.**
func advance(delta: float) -> void:
	if state == State.DISABLED:
		return
	_ambient += delta
	if _since_hover >= 0.0:
		_since_hover += delta
	if _since_leave >= 0.0:
		_since_leave += delta
	if _since_down >= 0.0:
		_since_down += delta
	if _since_up >= 0.0:
		_since_up += delta


## 캡처 도구가 시각을 직접 앉힌다. 프레임 번호에서 계산해 밀어 넣어야
## GIF 를 두 번 뽑아 비교할 수 있다.
func pose(
	ambient: float, since_hover: float, since_leave: float, since_down: float, since_up: float
) -> void:
	_ambient = ambient
	_since_hover = since_hover
	_since_leave = since_leave
	_since_down = since_down
	_since_up = since_up


func enter_hover() -> void:
	if state == State.DISABLED:
		return
	_since_hover = 0.0
	_since_leave = -1.0


func exit_hover() -> void:
	_since_leave = 0.0
	_since_hover = -1.0


func press() -> void:
	if state == State.DISABLED:
		return
	_since_down = 0.0
	_since_up = -1.0


## 손을 뗀다. **`_since_down` 은 멈추지 않는다** — 충격파는 누른 순간에서 자란다.
func release() -> void:
	_since_up = 0.0


## 비활성으로 넘어갈 때 시계를 전부 지운다. 안 지우면 다시 켰을 때
## **누르지도 않은 충격파가 남아 있다.**
func disable() -> void:
	state = State.DISABLED
	_since_hover = -1.0
	_since_leave = -1.0
	_since_down = -1.0
	_since_up = -1.0


## 커서가 올라와 있는 정도 0..1. **오버슛하지 않는다** — 색이 여기서 나온다.
func warmth() -> float:
	if state == State.DISABLED:
		return 0.0
	if _since_hover >= 0.0:
		return KitEase.out_expo(_since_hover / RISE_TIME, 4.0)
	if _since_leave >= 0.0:
		return 1.0 - clampf(KitEase.in_quad(_since_leave / FALL_TIME), 0.0, 1.0)
	return 0.0


## 판이 떠오른 정도. **1 을 지나쳤다 되돌아온다** — 기하가 여기서 나온다.
func rise() -> float:
	if state == State.DISABLED:
		return 0.0
	if _since_hover >= 0.0:
		if _since_hover >= RISE_TIME:
			return 1.0
		return KitEase.out_back(_since_hover / RISE_TIME, 2.6)
	if _since_leave >= 0.0:
		return 1.0 - clampf(KitEase.in_quad(_since_leave / FALL_TIME), 0.0, 1.0)
	return 0.0


## 눌림의 세기. 누르는 동안 1 로 차고, 떼면 **0 아래로 지나쳐** 늘어난다.
##
## 이 하나가 눌림 압축 · 가라앉음 · 떼는 순간의 되튐을 다 만든다.
## 따로 만들면 세 개가 서로 어긋난 시각에 끝나 손맛이 흩어진다.
func squeeze() -> float:
	if state == State.DISABLED:
		return 0.0
	if state == State.PRESSED:
		if _since_down < 0.0:
			return 0.0
		return KitEase.out_expo(_since_down / SINK_TIME, 9.0)
	if _since_up >= 0.0 and _since_up < RECOVER_TIME:
		var u := _since_up / RECOVER_TIME
		return 1.0 - KitEase.out_elastic(u, RECOVER_PERIOD, RECOVER_DECAY)
	return 0.0


## 판이 뜬 높이(px). 음수면 가라앉은 것이다.
func lift() -> float:
	return LIFT * rise() - SINK * squeeze()


## 눌림 압축. y 로 눌리고 x 로 퍼진다. 부피가 줄지 않는 것처럼 보이게 한다.
func squash() -> Vector2:
	var s := squeeze()
	return Vector2(1.0 + 0.045 * s, 1.0 - 0.11 * s)


## 안쪽 칸이 반전된 정도 0..1. 눌림을 **한눈에** 알게 하는 것이 이것이다.
func inversion() -> float:
	if state == State.DISABLED:
		return 0.0
	if state == State.PRESSED:
		if _since_down < 0.0:
			return 0.0
		return KitEase.out_expo(_since_down / INVERT_IN, 9.0)
	if _since_up >= 0.0 and _since_up < INVERT_OUT:
		return 1.0 - KitEase.out_expo(_since_up / INVERT_OUT, 9.0)
	return 0.0


## 광택 띠의 자리. `-0.35`(판 왼쪽 밖)에서 `1.35`(오른쪽 밖)까지 간다.
func sheen_at() -> float:
	if state == State.DISABLED:
		return -1.0
	var period := SHEEN_IDLE
	var clock := _ambient
	if _since_hover >= 0.0:
		period = SHEEN_HOVER
		clock = _since_hover
	return fposmod(clock, period) / period * 1.70 - 0.35


## 광택의 세기. 평상에서도 0 이 아니지만 **글자를 방해할 만큼은 아니다.**
func sheen_strength() -> float:
	if state == State.DISABLED:
		return 0.0
	return 0.06 + 0.14 * warmth()


## 테두리를 타고 도는 빛의 자리 0..1. 둘레 길이에 대한 비율이다.
func runner_at() -> float:
	if state == State.DISABLED:
		return -1.0
	return fposmod(_ambient, RUNNER_PERIOD) / RUNNER_PERIOD


## 갈매기표를 지나가는 밝은 점의 자리 0..1.
func chevron_at() -> float:
	if state == State.DISABLED:
		return -1.0
	if _since_hover >= 0.0:
		return fposmod(_since_hover, CHEVRON_HOVER) / CHEVRON_HOVER
	return fposmod(_ambient, CHEVRON_IDLE) / CHEVRON_IDLE


## 아래 강세 띠가 그려진 길이 0..1. 커서에서 **끝을 지나쳤다 되돌아온다.**
func accent() -> float:
	if state == State.DISABLED:
		return 0.0
	if state == State.PRESSED:
		return 1.0
	if _since_hover >= 0.0:
		return clampf(KitEase.out_back(_since_hover / 0.26, 2.0), 0.0, 1.0)
	if _since_leave >= 0.0:
		return 1.0 - clampf(KitEase.in_quad(_since_leave / 0.12), 0.0, 1.0)
	return 0.0


## 충격파의 진행 0..1. `-1` 은 지금 충격파가 없다는 뜻이다.
func impact() -> float:
	if state == State.DISABLED or _since_down < 0.0:
		return -1.0
	if _since_down >= IMPACT_TIME:
		return -1.0
	return _since_down / IMPACT_TIME


## 글자가 눌려 내려앉는 양(px). 1px 을 넘기지 않는다 — 넘기면 글자가 흔들려 안 읽힌다.
func text_dip() -> float:
	return 1.0 * clampf(squeeze(), 0.0, 1.0)
