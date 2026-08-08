class_name KitRelief
extends RefCounted
## 요소 하나의 **고도 상태**. 노드가 아니다.
##
## 버튼도 팝업도 결국 "지금 이 사각형이 얼마나 높은가" 하나로 환원된다.
## 그 계산만 여기 모아 두면 버튼·팝업·앞으로 생길 무엇이든 같은 규칙으로 솟고 꺼진다.
## 노드에 붙여 두면 씬을 띄우지 않고는 검증할 수 없으므로 순수 클래스로 뺐다.

## 이 요소의 기본 급(고도 단).
var base_elevation := KitTokens.ELEVATION_MAIN

## 각 상태의 현재 세기(0~1). 목표값을 향해 시간으로 다가간다.
var hover := 0.0
var press := 0.0
var focus := 0.0
var dim := 0.0

## 이 요소가 얹혀 있는 바닥의 고도. 장은 고도를 겹쳐서(max) 합치므로
## 요소는 **절대 고도**를 신고해야 한다. 팝업(6단) 위의 버튼(2단)은 8단이다.
var stack_base := 0.0

## 요소마다 숨의 위상을 어긋나게 하는 값. 같은 박자로 뛰면 화면이 하나로 굳는다.
var phase := 0.0

var _hover_target := 0.0
var _press_target := 0.0
var _focus_target := 0.0
var _dim_target := 0.0
var _clock := 0.0


func _init(elevation: float = KitTokens.ELEVATION_MAIN, breath_phase: float = 0.0) -> void:
	base_elevation = elevation
	phase = breath_phase


func set_hover(value: bool) -> void:
	_hover_target = 1.0 if value else 0.0


func set_press(value: bool) -> void:
	_press_target = 1.0 if value else 0.0


func set_focus(value: bool) -> void:
	_focus_target = 1.0 if value else 0.0


func set_dim(value: bool) -> void:
	_dim_target = 1.0 if value else 0.0


## 시간을 흘려보낸다. 붙는 것이 떨어지는 것보다 빠르다 —
## 반응은 즉각이어야 하고 여운은 남아야 한다.
func advance(delta: float) -> void:
	_clock += delta
	hover = _approach(
		hover, _hover_target, KitTokens.TIME_HOVER_IN, KitTokens.TIME_HOVER_OUT, delta
	)
	press = _approach(
		press, _press_target, KitTokens.TIME_PRESS_IN, KitTokens.TIME_PRESS_OUT, delta
	)
	focus = _approach(focus, _focus_target, KitTokens.TIME_FOCUS, KitTokens.TIME_FOCUS, delta)
	dim = _approach(dim, _dim_target, KitTokens.TIME_HOVER_OUT, KitTokens.TIME_HOVER_OUT, delta)


## 지금의 고도. 셰이더로 넘어가는 최종 수치다.
##
## 눌림은 단순히 낮아지는 것이 아니라 **0 아래로 내려간다.** 봉우리가 웅덩이가 되면
## 등고선의 색과 방향이 함께 뒤집히므로, 눌렸다는 사실이 밝기가 아니라 형태로 보인다.
func elevation() -> float:
	var value := (
		base_elevation * (1.0 + KitTokens.GAIN_HOVER * hover + KitTokens.GAIN_FOCUS * focus)
	)
	value += KitTokens.BREATH_AMPLITUDE * sin(_clock * KitTokens.BREATH_RATE + phase)
	value *= 1.0 - KitTokens.SINK_PRESS * press
	# 숨을 먼저 얹고 비활성으로 함께 눌러야 한다. 나중에 더하면 거의 평지가 된
	# 비활성 요소가 숨 때문에 0 아래로 넘나들어, 잠긴 것이 구덩이로 깜빡인다.
	value *= 1.0 - KitTokens.FLATTEN_DIM * dim
	return stack_base + value


## 상태를 빼고 이 요소가 원래 서 있는 높이.
##
## "무엇이 무엇에 묻혔는가"는 이 값으로 따져야 한다. 지금 높이로 따지면 눌린 버튼은
## 스스로 0 아래로 내려가므로 **옆 버튼에게 묻혔다고 판정되어 사라진다**(실제로 사라졌다).
## 누르는 동안 버튼이 없어지는 UI 는 없다.
func rest_elevation() -> float:
	return stack_base + base_elevation


## 셰이더의 element_pulse 한 칸.
##
## 호버는 고도에 녹아 있어 셰이더에서 되뽑을 수 없다. 방향에 따라 호버를
## 높이가 아니라 **다른 것**(갈라짐 · 알갱이 크기)으로 말해야 하므로 따로 보낸다.
func pulse_vector() -> Vector4:
	return Vector4(hover, 0.0, 0.0, 0.0)


## 셰이더의 element_state 한 칸. 마지막 칸은 이 요소가 얹힌 바닥의 고도다 —
## 장이 고도를 겹칠 때 "무엇을 기준으로 솟았는가"를 알아야 눌림이 파고들 수 있다.
func state_vector() -> Vector4:
	return Vector4(focus, press, dim, stack_base)


static func _approach(
	current: float, target: float, time_in: float, time_out: float, delta: float
) -> float:
	var duration := time_in if target > current else time_out
	if duration <= 0.0:
		return target
	# 프레임률과 무관한 지수 접근. 웹에서 프레임이 튀어도 같은 시간에 도착한다.
	var weight := 1.0 - exp(-delta / (duration * 0.35))
	return current + (target - current) * clampf(weight, 0.0, 1.0)
