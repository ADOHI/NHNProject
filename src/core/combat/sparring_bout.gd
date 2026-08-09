class_name SparringBout
extends RefCounted
## 백팩에서 짠 체인을 **실제로 시간 위에서 발사한다.** 최소 대련 한 판.
##
## `docs/design/28-combat.md` §28.4 (실시간) · §28.5 (무너짐) · §28.20.36 (대원 여럿).
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
## ## 양쪽 다 여럿이어도 시계는 하나다
##
## **대원마다의 다음 타**와 **적마다의 다음 타**가 한 시계 위에 올라온다.
## 매번 **가장 이른 것 하나**를 골라 거기까지만 흘린다. 한쪽을 몰아 처리하면
## 눈금이 잘못된 시점에 빠져 프레임 길이에 따라 결과가 달라지고,
## **사람이 늘수록 그 어긋남도 는다.**
##
## ## 대원이 여럿일 때 아직 안 정한 것 — **자리**
##
## 필드에는 **대원 자리가 하나뿐**이다 (§28.20.36). 전원이 같은 자리에 선다고 친다.
## 누가 어디 서고 누가 언제 붙는지는 §28.4 의 RTS 자동 이동이 정할 일이라
## 여기서 발명하지 않는다. **표시만 해 두고 숫자를 낸다.**
##
## ## 무너진 뒤에 무엇이 되는지는 정하지 않는다
##
## §28.8 이 미정으로 뒀다. **끊을지 말지는 `BreakTuning.chain_cut_at` 손잡이 하나**이고
## 기본값은 「안 끊는다」 — 그것이 지금까지의 동작이다.

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

var _tuning: BreakTuning
var _phase: Phase = Phase.READY
var _elapsed := 0.0
var _settle_left := 0.0

## 거리. `null` 이면 거리 판정을 하지 않는다 (눈금만 보는 옛 사용처).
var _field: SparringField = null

## ---- 우리 쪽. **대원 번호로 맞춘 배열들** ----
##
## 대원마다 체인 하나 · 눈금 하나 · 자기 시계 하나. 적 쪽과 같은 모양이다.
var _ally_items: Array = []
var _ally_due: Array = []
var _ally_next := PackedInt32Array()
var _ally_stop := PackedInt32Array()

## 무너져서 못 친 만큼 **뒤로 밀린 시간** (§28.20.36).
##
## `chain_cut_at` 이 꺼져 있으면 언제나 0 이라 옛 판과 한 치도 안 다르다.
var _ally_offset := PackedFloat32Array()
var _ally_gauges: Array[BreakGauge] = []

## 대원마다, 그 타가 **몇에게 걸쳤나** (§28.20.34 물음 ①).
##
## **`Array[int]` 이지 `PackedInt32Array` 가 아니다.** 묶음 배열 안에 넣은 Packed 는
## 꺼낼 때 **복사본**이 나와서 append 가 조용히 사라진다. 테스트가 그것을 잡았다.
var _ally_spread: Array = []

## ---- 적 쪽 ----
##
## **적마다 눈금 하나.** 적에게 달지 않고 여기 두는 이유는 §28.20.34 에 적었다 —
## 눈금은 판과 함께 살고 죽지만 자리는 판보다 오래 산다.
var _gauges: Array[BreakGauge] = []

## 표본용. 필드의 적 중 **자기 무기가 없는 것**이 이걸 든다.
## `null` 이면 그 적은 반격하지 않는다 (눈금만 보던 옛 사용처).
var _enemy_weapon: BackpackItem = null

## 적마다 다음 타가 떨어질 시각 (전투 시계) 과 지금까지 때린 횟수.
var _enemy_due := PackedFloat32Array()
var _enemy_landed := PackedInt32Array()

## 적마다 **몇 대 맞았나.** `TargetChoice.LEAST_TARGETED` 가 이걸 보고 고른다 (§28.20.37).
var _enemy_taken := PackedInt32Array()

## 히트스톱으로 멈춰 있는 남은 시간. **이 동안 눈금도 일정도 멈춘다.**
var _hitstop_left := 0.0


## 판 하나를 짠다. **대원 하나짜리다.**
##
## **명부는 여기서 굳는다** — 눈금을 그때 사람 수만큼 만든다. 판이 도는 중에
## 필드에 적을 더해도 그 적에게는 눈금이 없다. 새로 쏘면 다시 짜인다.
##
## `enemy_weapon` 은 표본용이다. **자기 무기가 없는 적 전부**가 이걸 든다.
func _init(
	items: Array[BackpackItem],
	tuning: BreakTuning = null,
	field: SparringField = null,
	enemy_weapon: BackpackItem = null
) -> void:
	_field = field
	_enemy_weapon = enemy_weapon
	_tuning = tuning if tuning != null else BreakTuning.new()
	_add_ally(items)
	for _index in enemy_count():
		_gauges.append(BreakGauge.new(_tuning))


## 체인 하나를 그대로 받아 판을 만든다.
static func from_chain(
	chain: ChainResult,
	tuning: BreakTuning = null,
	field: SparringField = null,
	enemy_weapon: BackpackItem = null
) -> SparringBout:
	return SparringBout.new(_items_of(chain), tuning, field, enemy_weapon)


## **대원 여럿짜리 판** (§28.20.36). 체인 목록 하나가 대원 하나다.
##
## 전원이 같은 자리에 선다 — 자리는 §28.4 가 정할 일이라 여기서 발명하지 않는다.
static func from_squad(
	chains: Array,
	tuning: BreakTuning = null,
	field: SparringField = null,
	enemy_weapon: BackpackItem = null
) -> SparringBout:
	var first: Array[BackpackItem] = []
	if not chains.is_empty():
		first.assign(chains[0])
	var bout := SparringBout.new(first, tuning, field, enemy_weapon)
	for index in range(1, chains.size()):
		var items: Array[BackpackItem] = []
		items.assign(chains[index])
		bout._add_ally(items)
	return bout


func start() -> void:
	_phase = Phase.DONE if _total_hits() == 0 else Phase.SWINGING
	_elapsed = 0.0
	_hitstop_left = 0.0
	_settle_left = SETTLE_SECONDS

	for index in ally_count():
		_ally_next[index] = 0
		_ally_stop[index] = Stop.NONE
		_ally_offset[index] = 0.0
		_ally_gauges[index].reset()
		(_ally_spread[index] as Array).clear()

	for gauge in _gauges:
		gauge.reset()
	_enemy_landed.clear()
	_enemy_due.clear()
	_enemy_taken.clear()
	for index in enemy_count():
		_enemy_landed.append(0)
		_enemy_taken.append(0)
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
		# 사람이 늘면 올라오는 사건도 는다 — 그래도 **한 번에 하나씩**이다.
		var soonest_ally := _soonest_ally()
		var soonest_enemy := _soonest_enemy()
		var next_due := minf(soonest_ally.x, soonest_enemy.x)
		if next_due == INF or _elapsed + remaining < next_due:
			break

		var step := maxf(0.0, next_due - _elapsed)
		_drain(step)
		_elapsed += step
		remaining -= step

		var struck: BackpackItem = null
		if soonest_ally.x <= soonest_enemy.x:
			struck = _swing_ally(int(soonest_ally.y))
		else:
			struck = _swing_enemy(int(soonest_enemy.y))

		if struck != null:
			remaining = _apply_hitstop(struck, remaining)

	if remaining > 0.0:
		_drain(remaining)
		_elapsed += remaining

	if _every_ally_stopped():
		_phase = Phase.SETTLING


## 다음에 칠 대원. [그 시각, 대원 번호]. 없으면 [INF, -1].
func _soonest_ally() -> Vector2:
	var best := Vector2(INF, -1.0)
	for index in ally_count():
		if _ally_stop[index] != Stop.NONE:
			continue
		var due: PackedFloat32Array = _ally_due[index]
		if _ally_next[index] >= due.size():
			continue
		var at := due[_ally_next[index]] + _ally_offset[index]
		if at < best.x:
			best = Vector2(at, float(index))
	return best


## 다음에 때릴 적. [그 시각, 적 번호]. 없으면 [INF, -1].
func _soonest_enemy() -> Vector2:
	var best := Vector2(INF, -1.0)
	for index in _enemy_due.size():
		if _weapon_of(index) == null:
			continue
		if _enemy_due[index] < best.x:
			best = Vector2(_enemy_due[index], float(index))
	return best


## 대원 하나의 한 타. 그 대원이 더 못 치면 `null` 을 돌려주고 **그 대원만** 멈춘다.
##
## **걸침이 여기서 일어난다** (§28.20.34 물음 ①) — 닿는 범위 안의 적들이
## 가까운 것부터 `splash_targets_for` 명까지 함께 맞는다. 지금 기본값은 한 명이다.
func _swing_ally(ally: int) -> BackpackItem:
	var items: Array[BackpackItem] = _ally_items[ally]
	var item := items[_ally_next[ally]]

	# **무너져서 못 치나** — §28.8 이 미정으로 뒀고 손잡이가 꺼져 있으면 언제나 아니다.
	#
	# **체인을 지우지 않고 미룬다.** 지우는 것은 「무너진 뒤에 무엇이 되나」를 정하는
	# 것이고 그건 §28.5 가 열어 둔 자리다. 눈금이 빠지면 다시 친다.
	if _tuning.cuts_chain(_ally_gauges[ally].state()):
		_ally_offset[ally] += _tuning.strike_seconds_for(item)
		return null

	var targets := _reachable_targets(item, ally)

	# **닿지 않으면 거기서 끝난다.** 백팩에서는 이어져 있어도 필드에서 못 나간다.
	if targets.is_empty():
		_ally_stop[ally] = Stop.OUT_OF_REACH
		return null

	for index in targets:
		if index < _gauges.size():
			_gauges[index].hit_with(item)
			_enemy_taken[index] += 1
	(_ally_spread[ally] as Array).append(targets.size())
	hit_landed.emit(_ally_next[ally], item)
	_ally_next[ally] += 1
	if _ally_next[ally] >= items.size():
		_ally_stop[ally] = Stop.COMPLETED

	# 맞은 만큼 몸이 나간다. 남을지 돌아올지는 미정이라 field 가 고른다.
	#
	# **0번 대원만 낸다.** 필드에 대원 자리가 하나뿐이라 전원이 밀면 사람 수만큼
	# 빨리 파고든다. 자리가 정해지기 전의 임시 규칙이다 (§28.20.36).
	if _field != null and ally == 0:
		_field.swing_advance(WeaponMotion.advance_px(item))
	return item


## 이 타가 때릴 적들.
##
## **두 단계다** (§28.20.37).
##
## 1. **닿는가** — 필드가 리치 안의 적들을 거리순으로 낸다. 이건 기하다
## 2. **그중 누구를** — `TargetChoice` 가 정한다. 이건 판단이고 눈금을 알아야 한다
##
## 섞어 두면 「안 맞은 놈부터」 같은 규칙이 필드로 새어 들어간다.
## 걸침 인원(`splash_targets_for`)은 **고른 뒤에** 자른다 — 인원이 범위를 늘리지 않는다.
##
## **못 닿는 적은 2단계에 아예 안 올라온다.** 그래서 `FINISH_OFF` 는
## 「제일 상한 놈」이 아니라 **「닿는 것 중 제일 상한 놈」**이다 (§28.20.38).
## 뒤 켜가 반쯤 무너져 있어도 못 닿으면 안 고른다.
##
## 거리가 없던 옛 사용처(`field == null`)에서는 **0번 적 하나**다.
func _reachable_targets(item: BackpackItem, ally: int) -> PackedInt32Array:
	if _field == null:
		return PackedInt32Array([0])
	var reach := WeaponMotion.reach_px(item)
	var candidates := _field.targets_within(reach, _field.enemy_count())
	var limit := _tuning.splash_targets_for(item)
	if candidates.size() <= 1:
		return candidates
	var ordered := _order_targets(candidates, ally)
	var picked := PackedInt32Array()
	for index in ordered:
		if picked.size() >= limit:
			break
		# **걸침이 켜를 넘나** (§28.20.38). 안 넘으면 고른 적과 같은 켜만 함께 맞는다.
		if not picked.is_empty() and not _tuning.splash_spans_ranks:
			if _rank_of(index) != _rank_of(picked[0]):
				continue
		picked.append(index)
	return picked


## 그 적이 몇 째 켜인가. 켜를 안 쓰는 판에서는 전부 0 이다.
func _rank_of(enemy: int) -> int:
	if _field == null:
		return 0
	var stood := _field.enemy_at(enemy)
	return stood.rank if stood != null else 0


## 닿는 적들을 **규칙대로 줄 세운다.** 들어오는 것은 거리순이다.
##
## 순서를 매길 때 **원래 자리(거리 순위)를 같이 넣어** 같은 값끼리는 가까운 쪽이 앞선다.
## `sort_custom` 은 안정 정렬이 아니라서 그렇게 안 하면 같은 판이 매번 달라진다.
func _order_targets(candidates: PackedInt32Array, ally: int) -> PackedInt32Array:
	match _field.target_choice:
		SparringField.TargetChoice.BY_NUMBER:
			return _rotated(candidates, ally % candidates.size())
		SparringField.TargetChoice.LEAST_TARGETED:
			return _sorted_by(candidates, func(enemy: int) -> float: return float(_taken_by(enemy)))
		SparringField.TargetChoice.LEADER_FIRST:
			# **우두머리는 특정한 하나다.** 아무 규칙도 안 노리면 사람 무리가 안 끝난다
			# (§28.20.44). 우두머리가 없는 무리에서는 거리순 그대로다.
			return _sorted_by(
				candidates, func(enemy: int) -> float: return 0.0 if _is_leader(enemy) else 1.0
			)
		SparringField.TargetChoice.FINISH_OFF:
			# **거의 눕은 놈을 마저.** 이미 다 누운 적은 뒤로 보낸다 — 더 때려야 소용이 없다.
			return _sorted_by(
				candidates,
				func(enemy: int) -> float:
					var gauge := enemy_gauge(enemy)
					if not BreakState.is_worse(BreakState.Kind.KNOCKDOWN, gauge.peak_state()):
						return 1.0
					return -gauge.value() / maxf(1.0, _tuning.max_value)
			)
		_:
			return candidates


## 그 자리부터 시작하도록 돌린다. 나머지는 거리순 그대로 뒤에 붙는다.
func _rotated(candidates: PackedInt32Array, start: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for step in candidates.size():
		out.append(candidates[(start + step) % candidates.size()])
	return out


## 점수가 작은 것부터. 같으면 가까운 쪽이 앞선다.
func _sorted_by(candidates: PackedInt32Array, score: Callable) -> PackedInt32Array:
	var keyed: Array[Vector3] = []
	for slot in candidates.size():
		keyed.append(
			Vector3(float(score.call(candidates[slot])), float(slot), float(candidates[slot]))
		)
	keyed.sort_custom(
		func(a: Vector3, b: Vector3) -> bool: return a.x < b.x if a.x != b.x else a.y < b.y
	)
	var out := PackedInt32Array()
	for entry in keyed:
		out.append(int(entry.z))
	return out


## 그 적이 이 무리의 우두머리인가.
func _is_leader(enemy: int) -> bool:
	if _field == null:
		return false
	var stood := _field.enemy_at(enemy)
	return stood != null and stood.is_leader


## 그 적이 지금까지 몇 대 맞았나.
func _taken_by(enemy: int) -> int:
	if enemy < 0 or enemy >= _enemy_taken.size():
		return 0
	return _enemy_taken[enemy]


## 적 하나의 한 타. **그 적이 문 대원의 눈금을 올린다.**
##
## 적이 닿지 않으면 그냥 헛친다 — 우리처럼 판을 끝내지 않는다.
## 적의 체인은 이 판의 관심사가 아니다.
func _swing_enemy(index: int) -> BackpackItem:
	var weapon := _weapon_of(index)
	if weapon == null:
		return null
	_enemy_due[index] += _enemy_interval(index)

	# 무너진 적도 못 친다. **한쪽에만 걸면 무너뜨리는 것이 한쪽 이득이 된다.**
	if _tuning.cuts_chain(enemy_gauge(index).state()):
		return null
	if _field != null and _field.gap_to(index) > WeaponMotion.reach_px(weapon):
		return null

	_ally_gauges[_bitten_by(index)].hit_with(weapon)
	_enemy_landed[index] += 1
	enemy_hit_landed.emit(weapon)
	return weapon


## **적 하나가 대원 하나를 문다.** 번갈아 나눠 문다.
##
## 이것이 §28.20.36 의 측정 가정이다. 전원이 같은 자리에 서 있으니 거리로는 못 고르고,
## 누가 누구에게 붙는지는 §28.4 의 자동 타겟팅이 정할 일이다.
## **한 명에게 몰아 주면 스쿼드의 값이 실제보다 낮게 나오고, 나눠 물리면 가장 좋은 쪽이다.**
func _bitten_by(enemy: int) -> int:
	return enemy % ally_count()


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


## 히트스톱을 걸고 남은 시간을 돌려준다. **모두와 모든 눈금이 함께 멈춘다.**
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
	for gauge in _ally_gauges:
		gauge.tick(seconds)


func _add_ally(items: Array[BackpackItem]) -> void:
	var due := PackedFloat32Array()
	var running := 0.0
	for item in items:
		running += _tuning.strike_seconds_for(item)
		due.append(running)
	_ally_items.append(items.duplicate())
	_ally_due.append(due)
	_ally_next.append(0)
	_ally_stop.append(Stop.NONE)
	_ally_offset.append(0.0)
	_ally_gauges.append(BreakGauge.new(_tuning))
	_ally_spread.append([] as Array[int])


func _every_ally_stopped() -> bool:
	for index in ally_count():
		if _ally_stop[index] == Stop.NONE:
			return false
	return true


func _total_hits() -> int:
	var total := 0
	for items in _ally_items:
		total += (items as Array).size()
	return total


static func _items_of(chain: ChainResult) -> Array[BackpackItem]:
	var items: Array[BackpackItem] = []
	for placement in chain.steps:
		items.append(placement.item)
	return items


# ---------------------------------------------------------------- 지금 상태


func phase() -> Phase:
	return _phase


func is_running() -> bool:
	return _phase == Phase.SWINGING or _phase == Phase.SETTLING


## 이 판에 선 대원 수.
func ally_count() -> int:
	return _ally_gauges.size()


## 그 대원의 무너짐 눈금. **번호를 안 주면 0번이다** — 대원 하나짜리 판이 대부분이다.
##
## ## 값을 하나씩 꺼내 주지 않고 눈금을 통째로 준다
##
## 양쪽이 여럿이 되면서 `값 · 최고 · 단계 · 최고 단계` 넷을 사람 수만큼 물어보게 됐다.
## 그걸 다 메서드로 내면 이 클래스가 **읽기 함수로만 서른 개**가 된다.
## `BreakGauge` 는 이미 그 넷을 아는 읽기 전용 값이므로 그대로 건넨다.
func ally_gauge(index: int = 0) -> BreakGauge:
	if index < 0 or index >= _ally_gauges.size():
		return BreakGauge.new(_tuning)
	return _ally_gauges[index]


## 그 대원이 지금까지 낸 타 수.
func ally_landed(index: int = 0) -> int:
	if index < 0 or index >= _ally_next.size():
		return 0
	return _ally_next[index]


## 그 대원의 체인 길이.
func ally_total_hits(index: int = 0) -> int:
	if index < 0 or index >= _ally_items.size():
		return 0
	return (_ally_items[index] as Array).size()


## 그 대원이 왜 멈췄나. **닿지 않아 끝난 것**인지는 `Stop.OUT_OF_REACH` 인지로 본다.
func ally_stop(index: int = 0) -> Stop:
	if index < 0 or index >= _ally_stop.size():
		return Stop.NONE
	return _ally_stop[index]


## 그 적의 무너짐 눈금. 범위를 벗어나면 **빈 눈금**이라 그리는 쪽이 안 터진다.
func enemy_gauge(index: int) -> BreakGauge:
	if index < 0 or index >= _gauges.size():
		return BreakGauge.new(_tuning)
	return _gauges[index]


## 이 판에 선 적의 수. 거리가 없던 옛 사용처에서도 **하나**다.
func enemy_count() -> int:
	if _field == null:
		return 1
	return _field.enemy_count()


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


## 0번 대원의 그 타가 **몇에게 걸쳤나** (§28.20.34). 아직 안 나간 타면 0.
func spread_at(hit_index: int) -> int:
	var spread: Array = _ally_spread[0]
	if hit_index < 0 or hit_index >= spread.size():
		return 0
	return spread[hit_index]


## 0번 대원 체인의 그 순서 아이템. 범위를 벗어나면 `null`.
func item_at(index: int) -> BackpackItem:
	var items: Array[BackpackItem] = _ally_items[0]
	if index < 0 or index >= items.size():
		return null
	return items[index]


## 히트스톱까지 더한 0번 대원 체인의 길이. `swing_seconds()` 는 멈춤을 뺀 전투 시계다.
func felt_seconds() -> float:
	var total := swing_seconds()
	for item: BackpackItem in _ally_items[0]:
		total += _tuning.hitstop_seconds_for(item)
	return total


## 0번 대원 체인이 몇 초짜리인가. **무기 구성에 따라 달라진다** —
## 1칸 다섯 개짜리 체인과 4칸 다섯 개짜리 체인은 길이가 전혀 다르다.
func swing_seconds() -> float:
	var due: PackedFloat32Array = _ally_due[0]
	if due.is_empty():
		return 0.0
	return due[due.size() - 1]
