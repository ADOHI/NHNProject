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

## 적이 우리를 때렸다.
signal enemy_hit_landed(item: BackpackItem)
signal finished

## 왜 멈췄나. **격자 이유(ChainResult.StopReason)와 다른 층이다** —
## 저쪽은 백팩을 볼 때 이미 정해지고, 이쪽은 **필드에서 그 순간에만** 정해진다.
enum Stop {
	NONE,  ## 아직 안 끝났다
	COMPLETED,  ## 체인을 끝까지 냈다
	OUT_OF_REACH,  ## **닿지 않는다** — 백팩에서는 이어지는데 필드에서 못 나갔다
}

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
var _stop: Stop = Stop.NONE

## 거리. `null` 이면 거리 판정을 하지 않는다 (눈금만 보는 옛 사용처).
var _field: SparringField = null

## **우리 쪽 무너짐 눈금.** 적에게만 있으면 대련장이 샌드백이다.
var _own_gauge: BreakGauge

## 적이 들고 있는 것. `null` 이면 반격하지 않는다 (눈금만 보던 옛 사용처).
var _enemy_weapon: BackpackItem = null

## 적의 다음 타가 떨어질 시각 (전투 시계).
var _enemy_due := 0.0
var _enemy_landed := 0

## 히트스톱으로 멈춰 있는 남은 시간. **이 동안 눈금도 일정도 멈춘다.**
var _hitstop_left := 0.0

## 실제로 흐른 시간(히트스톱 포함). `_elapsed` 는 멈춤을 뺀 전투 시계다.
var _wall_elapsed := 0.0

## 각 타가 **떨어지는 시각**(누적). 무기마다 다르므로 미리 쌓아 둔다.
var _due_times: PackedFloat32Array = PackedFloat32Array()


func _init(
	items: Array[BackpackItem],
	tuning: BreakTuning = null,
	field: SparringField = null,
	enemy_weapon: BackpackItem = null
) -> void:
	_items = items.duplicate()
	_field = field
	_enemy_weapon = enemy_weapon
	_tuning = tuning if tuning != null else BreakTuning.new()
	_gauge = BreakGauge.new(_tuning)
	_own_gauge = BreakGauge.new(_tuning)
	var running := 0.0
	for item in _items:
		running += _tuning.strike_seconds_for(item)
		_due_times.append(running)


## 체인 하나를 그대로 받아 판을 만든다.
static func from_chain(
	chain: ChainResult,
	tuning: BreakTuning = null,
	field: SparringField = null,
	enemy_weapon: BackpackItem = null
) -> SparringBout:
	var items: Array[BackpackItem] = []
	for placement in chain.steps:
		items.append(placement.item)
	return SparringBout.new(items, tuning, field, enemy_weapon)


func start() -> void:
	_stop = Stop.NONE
	_phase = Phase.SWINGING if not _items.is_empty() else Phase.DONE
	_elapsed = 0.0
	_wall_elapsed = 0.0
	_hitstop_left = 0.0
	_next_index = 0
	_settle_left = SETTLE_SECONDS
	_gauge.reset()
	_own_gauge.reset()
	_enemy_landed = 0
	_enemy_due = _enemy_interval()
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
		_drain(delta)
		_settle_left -= delta
		if _settle_left <= 0.0:
			_phase = Phase.DONE
			finished.emit()


func _advance_swings(delta: float) -> void:
	var remaining := delta
	while remaining > 0.0:
		# **양쪽 사건을 시각 순서대로 처리한다.** 한쪽을 몰아 처리하면
		# 눈금이 잘못된 시점에 빠져서 결과가 프레임 길이에 따라 달라진다.
		var own_due := _due_times[_next_index] if _next_index < _items.size() else INF
		var enemy_due := _enemy_due if _enemy_weapon != null else INF
		var next_due := minf(own_due, enemy_due)
		if next_due == INF or _elapsed + remaining < next_due:
			break

		var step := maxf(0.0, next_due - _elapsed)
		_drain(step)
		_elapsed += step
		remaining -= step

		var struck: BackpackItem = null
		if own_due <= enemy_due:
			struck = _swing_ours()
			if struck == null:
				return
		else:
			struck = _swing_enemy()

		if struck != null:
			remaining = _apply_hitstop(struck, remaining)

	if remaining > 0.0:
		_drain(remaining)
		_elapsed += remaining

	if _next_index >= _items.size():
		_stop = Stop.COMPLETED
		_phase = Phase.SETTLING


## 우리 한 타. 닿지 않으면 `null` 을 돌려주고 판이 끝난다.
func _swing_ours() -> BackpackItem:
	var item := _items[_next_index]

	# **닿지 않으면 거기서 끝난다.** 백팩에서는 이어져 있어도 필드에서 못 나간다.
	if _field != null and _field.gap() > WeaponMotion.reach_px(item):
		_stop = Stop.OUT_OF_REACH
		_phase = Phase.SETTLING
		return null

	_gauge.hit_with(item)
	hit_landed.emit(_next_index, item)
	_next_index += 1
	# 맞은 만큼 몸이 나간다. 남을지 돌아올지는 미정이라 field 가 고른다.
	if _field != null:
		_field.swing_advance(WeaponMotion.advance_px(item))
	return item


## 적 한 타. **우리 눈금을 올린다.**
##
## 적이 닿지 않으면 그냥 헛친다 — 우리처럼 판을 끝내지 않는다.
## 적의 체인은 이 판의 관심사가 아니다.
func _swing_enemy() -> BackpackItem:
	_enemy_due += _enemy_interval()
	if _field != null and _field.gap() > WeaponMotion.reach_px(_enemy_weapon):
		return null
	_own_gauge.hit_with(_enemy_weapon)
	_enemy_landed += 1
	enemy_hit_landed.emit(_enemy_weapon)
	return _enemy_weapon


func _enemy_interval() -> float:
	if _enemy_weapon == null:
		return INF
	return _tuning.strike_seconds_for(_enemy_weapon)


## 히트스톱을 걸고 남은 시간을 돌려준다. **양쪽과 눈금이 함께 멈춘다.**
func _apply_hitstop(item: BackpackItem, remaining: float) -> float:
	_hitstop_left = _tuning.hitstop_seconds_for(item)
	if _hitstop_left <= 0.0:
		return remaining
	var frozen := minf(remaining, _hitstop_left)
	_hitstop_left -= frozen
	return remaining - frozen


## 시간이 흐른다. **양쪽 눈금이 함께 빠진다.**
func _drain(seconds: float) -> void:
	_gauge.tick(seconds)
	_own_gauge.tick(seconds)


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


func stop_reason() -> Stop:
	return _stop


## 닿지 않아서 못 나간 타가 있는가.
func was_out_of_reach() -> bool:
	return _stop == Stop.OUT_OF_REACH


## 그 순서의 아이템. 범위를 벗어나면 `null`.
func item_at(index: int) -> BackpackItem:
	if index < 0 or index >= _items.size():
		return null
	return _items[index]


## ---- 우리 쪽 ----
##
## **경직 · 띄우기가 우리에게도 걸리는지는 §28.8 이 미정으로 뒀다.**
## 여기서는 눈금을 쌓고 단계를 알려 줄 뿐 **체인을 끊지 않는다** —
## 애니 레인의 반응 층도 「때리다 맞아도 스윙이 안 끊긴다」로 만들어져 있다.
## 끊을지 말지는 정해지면 그때 넣는다.
func own_gauge_value() -> float:
	return _own_gauge.value()


func own_peak() -> float:
	return _own_gauge.peak()


func own_state() -> BreakState.Kind:
	return _own_gauge.state()


func own_peak_state() -> BreakState.Kind:
	return _own_gauge.peak_state()


func enemy_landed() -> int:
	return _enemy_landed


func has_enemy() -> bool:
	return _enemy_weapon != null


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
