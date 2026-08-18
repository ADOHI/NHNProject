class_name BreakGauge
extends RefCounted
## 무너짐 눈금 하나. **차오르고, 시간이 지나면 빠진다.**
##
## `docs/design/28-combat.md` §28.5.
##
## 체력과 **별개다.** 체력은 깎이고 이것은 차오른다 — 서로 다른 축이다.
##
## ## 무너진 뒤 무엇이 되는지는 여기서 정하지 않는다
##
## §28.8 이 미정으로 남겼다. 이 눈금은 **차오르고 단계를 알려 줄 뿐**
## 쓰러진 뒤에 스스로 리셋하거나 상태를 강제하지 않는다.
## 그것을 정하는 것은 나중에 붙을 전투 쪽이다.

var _tuning: BreakTuning
var _value: float = 0.0

## 이 눈금이 살아 있는 동안 닿았던 가장 심한 단계.
var _peak: float = 0.0


func _init(tuning: BreakTuning = null) -> void:
	_tuning = tuning if tuning != null else BreakTuning.new()


func value() -> float:
	return _value


## 지금까지 닿았던 최고 눈금. 한 번 띄웠는지를 알려면 순간값으로는 부족하다.
func peak() -> float:
	return _peak


func state() -> BreakState.Kind:
	return _tuning.state_for(_value)


func peak_state() -> BreakState.Kind:
	return _tuning.state_for(_peak)


func tuning() -> BreakTuning:
	return _tuning


## 한 타 맞았다.
func add(amount: float) -> void:
	_value = clampf(_value + maxf(0.0, amount), 0.0, _tuning.max_value)
	_peak = maxf(_peak, _value)


## 아이템 한 타. 무게는 `BreakTuning` 이 정한다.
func hit_with(item: BackpackItem) -> void:
	add(_tuning.poise_for(item))


## 시간이 흘렀다. 눈금이 빠진다.
##
## **최고 기록(`peak`)은 안 빠진다.** 빠지는 것은 지금 값이다.
func tick(seconds: float) -> void:
	if seconds <= 0.0:
		return
	_value = maxf(0.0, _value - _tuning.decay_per_second * seconds)


func reset() -> void:
	_value = 0.0
	_peak = 0.0
