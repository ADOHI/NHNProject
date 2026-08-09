class_name SparringBout
extends RefCounted
## 백팩에서 짠 체인을 **실제로 시간 위에서 발사한다.** 최소 대련 한 판.
##
## `docs/design/28-combat.md` §28.4 (실시간) · §28.5 (무너짐).
##
## ## 여기까지 오기 전에는 시간이 흐르는 곳이 없었다
##
## `ChainResolver` 는 순서를 **계산**하고 `ChainBreakSim` 은 눈금을 **계산**한다.
## 둘 다 한순간에 끝난다. 이 클래스가 그것을 **초 단위로 늘어놓는다** —
## 타가 하나씩 간격을 두고 나가고, 그 사이에 눈금이 빠진다.
##
## ## 계산기와 어긋나면 안 된다
##
## 같은 체인을 `ChainBreakSim` 에 넣은 것과 여기서 끝까지 돌린 것의 결과가
## **같아야 한다.** 다르면 화면이 보여 주는 것과 측정 도구가 재는 것이 갈린다.
## 테스트가 그것을 붙들고 있다.
##
## 그래서 타를 **정확한 시각에** 때린다 — 프레임이 길게 튀어도 한 프레임에
## 여러 타가 몰리지 않고 각자 제 시각의 눈금 위에서 맞는다.
##
## ## 무너진 뒤에 무엇이 되는지는 정하지 않는다
##
## §28.8 이 미정으로 뒀다. 이 판은 **눈금이 차고 빠지는 것까지만** 보여 주고
## 일어나기 · 제압 · 반격을 만들지 않는다.

signal hit_landed(index: int, item: BackpackItem)
signal finished

enum Phase {
	READY,  ## 아직 안 시작했다
	SWINGING,  ## 체인이 나가는 중
	SETTLING,  ## 다 쳤다. 눈금이 빠지는 것을 보는 시간
	DONE,
}

## 마지막 타 뒤에 눈금이 빠지는 것을 지켜보는 시간.
##
## **연출이 아니라 관찰용이다.** 이게 없으면 체인이 끝나는 순간 화면이 멈춰서
## "빠짐 속도가 전부를 정한다"(§28.20.19)는 것이 눈에 안 보인다.
const SETTLE_SECONDS := 2.5

var _items: Array[BackpackItem] = []
var _tuning: BreakTuning
var _gauge: BreakGauge
var _phase: Phase = Phase.READY
var _elapsed := 0.0
var _next_index := 0
var _settle_left := 0.0

## 히트스톱으로 멈춰 있는 남은 시간. **이 동안 눈금도 일정도 멈춘다.**
var _hitstop_left := 0.0

## 실제로 흐른 시간(히트스톱 포함). `_elapsed` 는 멈춤을 뺀 전투 시계다.
var _wall_elapsed := 0.0

## 각 타가 **떨어지는 시각**(누적). 무기마다 다르므로 미리 쌓아 둔다.
var _due_times: PackedFloat32Array = PackedFloat32Array()


func _init(items: Array[BackpackItem], tuning: BreakTuning = null) -> void:
	_items = items.duplicate()
	_tuning = tuning if tuning != null else BreakTuning.new()
	_gauge = BreakGauge.new(_tuning)
	var running := 0.0
	for item in _items:
		running += _tuning.strike_seconds_for(item)
		_due_times.append(running)


## 체인 하나를 그대로 받아 판을 만든다.
static func from_chain(chain: ChainResult, tuning: BreakTuning = null) -> SparringBout:
	var items: Array[BackpackItem] = []
	for placement in chain.steps:
		items.append(placement.item)
	return SparringBout.new(items, tuning)


func start() -> void:
	_phase = Phase.SWINGING if not _items.is_empty() else Phase.DONE
	_elapsed = 0.0
	_wall_elapsed = 0.0
	_hitstop_left = 0.0
	_next_index = 0
	_settle_left = SETTLE_SECONDS
	_gauge.reset()
	if _phase == Phase.DONE:
		finished.emit()


## 시간이 흘렀다.
##
## **타를 정확한 시각에 때린다.** delta 를 통째로 눈금에 흘린 뒤 때리면
## 프레임이 튄 날에만 결과가 달라진다 — 그러면 측정 도구와 화면이 어긋난다.
func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	_wall_elapsed += delta

	# **히트스톱 동안에는 아무것도 흐르지 않는다** — 눈금도, 다음 타 일정도.
	# 안 멈추면 무거운 무기일수록 멈춤이 길어 그동안 더 빠지고,
	# 히트스톱이 연출이 아니라 **페널티**가 된다.
	if _hitstop_left > 0.0:
		var frozen := minf(delta, _hitstop_left)
		_hitstop_left -= frozen
		delta -= frozen
		if delta <= 0.0:
			return

	if _phase == Phase.SWINGING:
		_advance_swings(delta)
		return
	if _phase == Phase.SETTLING:
		_gauge.tick(delta)
		_settle_left -= delta
		if _settle_left <= 0.0:
			_phase = Phase.DONE
			finished.emit()


func _advance_swings(delta: float) -> void:
	var remaining := delta
	while remaining > 0.0 and _next_index < _items.size():
		var due := _due_times[_next_index]
		if _elapsed + remaining < due:
			break
		# 그 타의 시각까지만 눈금을 흘리고 나서 때린다.
		var step := maxf(0.0, due - _elapsed)
		_gauge.tick(step)
		_elapsed += step
		remaining -= step
		var item := _items[_next_index]
		_gauge.hit_with(item)
		hit_landed.emit(_next_index, item)
		_next_index += 1
		# 맞은 순간 멈춘다. 남은 delta 는 다음 tick 에서 히트스톱이 먼저 먹는다.
		_hitstop_left = _tuning.hitstop_seconds_for(item)
		if _hitstop_left > 0.0:
			var frozen := minf(remaining, _hitstop_left)
			_hitstop_left -= frozen
			remaining -= frozen

	if remaining > 0.0:
		_gauge.tick(remaining)
		_elapsed += remaining

	if _next_index >= _items.size():
		_phase = Phase.SETTLING


# ---------------------------------------------------------------- 지금 상태


func phase() -> Phase:
	return _phase


func is_running() -> bool:
	return _phase == Phase.SWINGING or _phase == Phase.SETTLING


func gauge_value() -> float:
	return _gauge.value()


func peak() -> float:
	return _gauge.peak()


func state() -> BreakState.Kind:
	return _gauge.state()


func peak_state() -> BreakState.Kind:
	return _gauge.peak_state()


func landed() -> int:
	return _next_index


func total_hits() -> int:
	return _items.size()


func elapsed() -> float:
	return _elapsed


## 히트스톱까지 포함해 **실제로 흐른** 시간. 사람이 느끼는 길이다.
func wall_elapsed() -> float:
	return _wall_elapsed


## 히트스톱까지 더한 체인 길이. `swing_seconds()` 는 멈춤을 뺀 전투 시계다.
func felt_seconds() -> float:
	var total := swing_seconds()
	for item in _items:
		total += _tuning.hitstop_seconds_for(item)
	return total


## 이 체인이 몇 초짜리인가. **무기 구성에 따라 달라진다** —
## 1칸 다섯 개짜리 체인과 4칸 다섯 개짜리 체인은 길이가 전혀 다르다.
func swing_seconds() -> float:
	if _due_times.is_empty():
		return 0.0
	return _due_times[_due_times.size() - 1]
