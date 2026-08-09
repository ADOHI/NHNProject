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
## ## 적이 여럿이어도 시계는 하나다
##
## 우리 다음 타와 **적마다의 다음 타**가 한 시계 위에 올라온다 (§28.20.34).
## 매번 **가장 이른 것 하나**를 골라 거기까지만 흘린다. 한쪽을 몰아 처리하면
## 눈금이 잘못된 시점에 빠져 프레임 길이에 따라 결과가 달라지고,
## 적이 셋이면 그 어긋남이 셋으로 는다.
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
var _phase: Phase = Phase.READY
var _elapsed := 0.0
var _next_index := 0
var _settle_left := 0.0
var _stop: Stop = Stop.NONE

## 거리. `null` 이면 거리 판정을 하지 않는다 (눈금만 보는 옛 사용처).
var _field: SparringField = null

## **우리 쪽 무너짐 눈금.** 적에게만 있으면 대련장이 샌드백이다.
var _own_gauge: BreakGauge

## **적마다 눈금 하나.** 적 번호로 맞춰 둔 배열이다.
##
## 적에게 달지 않고 여기 두는 이유는 §28.20.34 에 적었다 — 눈금은 판과 함께 살고
## 죽지만 자리는 판보다 오래 산다.
var _gauges: Array[BreakGauge] = []

## 표본용. 필드의 적 중 **자기 무기가 없는 것**이 이걸 든다.
## `null` 이면 그 적은 반격하지 않는다 (눈금만 보던 옛 사용처).
var _enemy_weapon: BackpackItem = null

## 적마다 다음 타가 떨어질 시각 (전투 시계) 과 지금까지 때린 횟수.
var _enemy_due := PackedFloat32Array()
var _enemy_landed := PackedInt32Array()

## 우리 타마다 **몇에게 걸쳤나** (§28.20.34 물음 ①).
var _spread := PackedInt32Array()

## 히트스톱으로 멈춰 있는 남은 시간. **이 동안 눈금도 일정도 멈춘다.**
var _hitstop_left := 0.0

## 각 타가 **떨어지는 시각**(누적). 무기마다 다르므로 미리 쌓아 둔다.
var _due_times: PackedFloat32Array = PackedFloat32Array()


## 판 하나를 짠다.
##
## **적 명부는 여기서 굳는다** — 눈금을 그때 적 수만큼 만든다. 판이 도는 중에
## 필드에 적을 더해도 그 적에게는 눈금이 없다. 새로 쏘면 다시 짜인다.
##
## `enemy_weapon` 은 표본용이다. **자기 무기가 없는 적 전부**가 이걸 든다.
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
	_own_gauge = BreakGauge.new(_tuning)
	for _index in enemy_count():
		_gauges.append(BreakGauge.new(_tuning))
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
	_hitstop_left = 0.0
	_next_index = 0
	_settle_left = SETTLE_SECONDS
	for gauge in _gauges:
		gauge.reset()
	_own_gauge.reset()
	_spread.clear()
	_enemy_landed.clear()
	_enemy_due.clear()
	for index in enemy_count():
		_enemy_landed.append(0)
		_enemy_due.append(_enemy_interval(index))
	if _phase == Phase.DONE:
		finished.emit()


## 시간이 흘렀다.
##
## **타를 정확한 시각에 때린다.** delta 를 통째로 눈금에 흘린 뒤 때리면
## 프레임이 튄 날에만 결과가 달라진다 — 그러면 측정 도구와 화면이 어긋난다.
func tick(delta: float) -> void:
	if delta <= 0.0:
		return

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
		# **모든 사건을 시각 순서대로 처리한다.** 한쪽을 몰아 처리하면
		# 눈금이 잘못된 시점에 빠져서 결과가 프레임 길이에 따라 달라진다.
		# 적이 여럿이면 올라오는 사건도 여럿이다 — 그래도 **한 번에 하나씩**이다.
		var own_due := _due_times[_next_index] if _next_index < _items.size() else INF
		var soonest := _soonest_enemy()
		var enemy_due := soonest.x
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
			struck = _swing_enemy(int(soonest.y))

		if struck != null:
			remaining = _apply_hitstop(struck, remaining)

	if remaining > 0.0:
		_drain(remaining)
		_elapsed += remaining

	if _next_index >= _items.size():
		_stop = Stop.COMPLETED
		_phase = Phase.SETTLING


## 다음에 때릴 적. [그 시각, 적 번호]. 없으면 [INF, -1].
func _soonest_enemy() -> Vector2:
	var best := Vector2(INF, -1.0)
	for index in _enemy_due.size():
		if _weapon_of(index) == null:
			continue
		if _enemy_due[index] < best.x:
			best = Vector2(_enemy_due[index], float(index))
	return best


## 우리 한 타. 아무에게도 안 닿으면 `null` 을 돌려주고 판이 끝난다.
##
## **걸침이 여기서 일어난다** (§28.20.34 물음 ①) — 닿는 범위 안의 적들이
## 가까운 것부터 `splash_targets_for` 명까지 함께 맞는다. 지금 기본값은 한 명이다.
func _swing_ours() -> BackpackItem:
	var item := _items[_next_index]
	var targets := _reachable_targets(item)

	# **닿지 않으면 거기서 끝난다.** 백팩에서는 이어져 있어도 필드에서 못 나간다.
	if targets.is_empty():
		_stop = Stop.OUT_OF_REACH
		_phase = Phase.SETTLING
		return null

	for index in targets:
		if index < _gauges.size():
			_gauges[index].hit_with(item)
	_spread.append(targets.size())
	hit_landed.emit(_next_index, item)
	_next_index += 1
	# 맞은 만큼 몸이 나간다. 남을지 돌아올지는 미정이라 field 가 고른다.
	if _field != null:
		_field.swing_advance(WeaponMotion.advance_px(item))
	return item


## 이 타가 때릴 적들. 가까운 것부터.
##
## 거리가 없던 옛 사용처(`field == null`)에서는 **0번 적 하나**다.
func _reachable_targets(item: BackpackItem) -> PackedInt32Array:
	if _field == null:
		return PackedInt32Array([0])
	return _field.targets_within(WeaponMotion.reach_px(item), _tuning.splash_targets_for(item))


## 적 하나의 한 타. **우리 눈금을 올린다.**
##
## 적이 닿지 않으면 그냥 헛친다 — 우리처럼 판을 끝내지 않는다.
## 적의 체인은 이 판의 관심사가 아니다.
func _swing_enemy(index: int) -> BackpackItem:
	var weapon := _weapon_of(index)
	if weapon == null:
		return null
	_enemy_due[index] += _enemy_interval(index)
	if _field != null and _field.gap_to(index) > WeaponMotion.reach_px(weapon):
		return null
	_own_gauge.hit_with(weapon)
	_enemy_landed[index] += 1
	enemy_hit_landed.emit(weapon)
	return weapon


## 그 적이 든 것. 자기 무기가 없으면 표본 무기를 든다.
func _weapon_of(index: int) -> BackpackItem:
	if _field == null:
		return _enemy_weapon
	var enemy := _field.enemy_at(index)
	if enemy == null:
		return null
	return enemy.weapon if enemy.weapon != null else _enemy_weapon


func _enemy_interval(index: int) -> float:
	var weapon := _weapon_of(index)
	if weapon == null:
		return INF
	return _tuning.strike_seconds_for(weapon)


## 히트스톱을 걸고 남은 시간을 돌려준다. **양쪽과 눈금이 함께 멈춘다.**
func _apply_hitstop(item: BackpackItem, remaining: float) -> float:
	_hitstop_left = _tuning.hitstop_seconds_for(item)
	if _hitstop_left <= 0.0:
		return remaining
	var frozen := minf(remaining, _hitstop_left)
	_hitstop_left -= frozen
	return remaining - frozen


## 시간이 흐른다. **모든 눈금이 함께 빠진다.**
func _drain(seconds: float) -> void:
	for gauge in _gauges:
		gauge.tick(seconds)
	_own_gauge.tick(seconds)


# ---------------------------------------------------------------- 지금 상태


func phase() -> Phase:
	return _phase


func is_running() -> bool:
	return _phase == Phase.SWINGING or _phase == Phase.SETTLING


## 이 판에 선 적의 수. 거리가 없던 옛 사용처에서도 **하나**다.
func enemy_count() -> int:
	if _field == null:
		return 1
	return _field.enemy_count()


## 그 적이 서 있는 자리. 거리가 없으면 0.
func enemy_x(index: int) -> float:
	if _field == null:
		return 0.0
	var enemy := _field.enemy_at(index)
	return enemy.x if enemy != null else 0.0


## 그 적의 무너짐 눈금. 범위를 벗어나면 **빈 눈금**이라 그리는 쪽이 안 터진다.
##
## ## 값을 하나씩 꺼내 주지 않고 눈금을 통째로 준다
##
## 적이 여럿이 되면서 `값 · 최고 · 단계 · 최고 단계` 넷을 적 수만큼 물어보게 됐다.
## 그걸 다 메서드로 내면 이 클래스가 **읽기 함수로만 서른 개**가 된다.
## `BreakGauge` 는 이미 그 넷을 아는 읽기 전용 값이므로 그대로 건넨다.
func enemy_gauge(index: int) -> BreakGauge:
	if index < 0 or index >= _gauges.size():
		return BreakGauge.new(_tuning)
	return _gauges[index]


## **우리 쪽 눈금.** 적에게만 있으면 대련장이 샌드백이다.
##
## §28.8 이 *"경직 · 띄우기가 우리 대원에게도 걸리나"* 를 미정으로 뒀다.
## 여기서는 눈금을 쌓고 단계를 알려 줄 뿐 **체인을 끊지 않는다** —
## 애니 레인의 반응 층도 「때리다 맞아도 스윙이 안 끊긴다」로 만들어져 있다.
func own_gauge() -> BreakGauge:
	return _own_gauge


## 그 타가 **몇에게 걸쳤나** (§28.20.34). 아직 안 나간 타면 0.
func spread_at(hit_index: int) -> int:
	if hit_index < 0 or hit_index >= _spread.size():
		return 0
	return _spread[hit_index]


## 왜 멈췄나. **닿지 않아 끝난 것**인지는 `Stop.OUT_OF_REACH` 인지로 본다.
func stop_reason() -> Stop:
	return _stop


## 그 순서의 아이템. 범위를 벗어나면 `null`.
func item_at(index: int) -> BackpackItem:
	if index < 0 or index >= _items.size():
		return null
	return _items[index]


## 적들이 우리를 때린 횟수의 합.
func enemy_landed() -> int:
	var total := 0
	for count in _enemy_landed:
		total += count
	return total


## 반격하는 적이 하나라도 있나. 없으면 대련장이 샌드백이다.
func has_enemy() -> bool:
	for index in enemy_count():
		if _weapon_of(index) != null:
			return true
	return false


func landed() -> int:
	return _next_index


func total_hits() -> int:
	return _items.size()


## 전투 시계. 히트스톱으로 멈춘 동안은 안 흐른다.
func elapsed() -> float:
	return _elapsed


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
