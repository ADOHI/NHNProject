class_name ChainBreakOutcome
extends RefCounted
## 체인 하나를 끝까지 돌렸을 때 **상대가 어떻게 됐는가.**
##
## `docs/design/28-combat.md` §28.5.
##
## ## 왜 이것이 필요한가
##
## 그 전까지 체인은 **길이만 있고 결과가 없었다.** 10 타가 1 타보다 무엇이 나은지가
## 코드 어디에도 없었다. 이 클래스가 그 답이다 —
## **긴 체인은 눈금을 넘기고, 짧은 체인은 다 차기 전에 끝난다.**

## 매 타 직후의 눈금.
var values: PackedFloat32Array = PackedFloat32Array()

## 매 타 직후의 단계. `values` 와 길이가 같다.
var states: Array[BreakState.Kind] = []

## 이 체인이 닿은 가장 높은 눈금과 단계.
var peak: float = 0.0
var highest: BreakState.Kind = BreakState.Kind.NONE

## 단계 -> 처음 닿은 타 번호(1 부터). 안 닿았으면 없다.
var _first_reach: Dictionary = {}


func hits() -> int:
	return values.size()


## 그 단계에 **몇 번째 타에서** 처음 닿았나. 안 닿았으면 -1.
##
## "몇 타부터 띄우기가 되나" 가 이 함수다.
func first_step_reaching(kind: BreakState.Kind) -> int:
	return int(_first_reach.get(kind, -1))


func reached(kind: BreakState.Kind) -> bool:
	return not BreakState.is_worse(kind, highest)


## 시뮬레이터가 한 타를 기록한다.
func record(value: float, state: BreakState.Kind) -> void:
	values.append(value)
	states.append(state)
	peak = maxf(peak, value)
	if BreakState.is_worse(state, highest):
		highest = state
	if state != BreakState.Kind.NONE and not _first_reach.has(state):
		_first_reach[state] = values.size()


func summary_line() -> String:
	if hits() == 0:
		return "친 것이 없다"
	# 가운뎃점(U+00B7)을 쓰지 마라. 본문 폰트에 없어서 **웹에서만** 두부가 된다
	# (docs/conventions.md §5.1). 데스크톱 캡처로는 멀쩡해 보인다 — 실제로 그랬다.
	return "%d타, 최고 눈금 %.0f, %s" % [hits(), peak, BreakState.label(highest)]
