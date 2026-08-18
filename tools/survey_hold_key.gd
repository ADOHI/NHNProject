extends SceneTree
## **대기 키가 배율을 내나.** §28.4 의 유일한 「전투 중 조작」이다.
##
##     godot --headless --path . -s res://tools/survey_hold_key.gd
##
## `docs/design/28-combat.md` §28.20.59.
##
## ## 왜 재나
##
## §28.20.58 이 낸 것: **시스템 손잡이 넷이 전부 x1.3 안쪽**이고 결과를 움직이는 것은
## 백팩과 편성뿐인데 **그 둘은 전투가 시작되기 전에 정해진다.**
## **전투 중에 플레이어가 정하는 것이 지금 하나도 없다.**
##
## §28.4 가 확정한 것이 하나 있다 — *"RTS 기본으로 행동하되 대기 키를 만들어 두면
## 고도화된 컨트롤 가능."* **그 「고도화」가 얼마짜리인지는 한 번도 안 쟀다.**
##
## **넣을지 말지를 여기서 정하지 않는다.** 배율만 낸다 (통합자 지시).
##
## ## 기준판이 이미 「완벽한 대기」다 — 그래서 뒤집어 잰다
##
## 지금 대련장은 대원 넷이 **같은 체인을 t=0 에 동시에** 시작한다. 이미 완벽히 정렬돼
## 있어서 **대기 키가 살 것이 없다.** 그러니 물음을 뒤집는다 —
## **대기 키가 없으면 얼마를 잃나.**
##
## 실제로는 대원이 제각기 붙으므로 타가 **엇갈린다.** 그 엇갈림을 0 으로 되돌리는 것이
## 대기 키가 사는 것이고, 그 값이 배율이다.
##
## ## 왜 엇갈림이 비싼가 — **눈금이 초당 빠진다**
##
## 문턱 30 / 60 / 100 이고 감쇠가 초당 10 이다 (§28.20.35).
## 몰아치면 넷이 한 번에 얹혀 문턱을 넘고, 흩어 치면 **사이에 빠져서 못 넘는다.**

const SurveyClock := preload("res://tools/survey_clock.gd")

const _STEP := 1.0 / 60.0
const _MAX_SECONDS := SurveyClock.SECONDS
const _PER_RANK := 3
const _SQUAD := 4
const _CELLS := 4

const _EASY := 25
const _HARD := 56

## 대원이 제각기 붙는 폭 (초). **0 이 지금이고, 그것이 「완벽한 대기」다.**
const _STAGGERS: Array[float] = [0.0, 0.15, 0.3, 0.6, 1.2, 2.4]

var _chains: Dictionary = {}


func _initialize() -> void:
	print("== 대기 키가 배율을 내나 ==")
	print("  대원 %d · %d칸 체인 · 걸침 부피대로 · 가장 가까운 것 · 다가옴 · 빠짐." % [_SQUAD, _CELLS])
	print("  문턱 30 / 60 / 100 · 감쇠 초당 10. 판정 창 %.0f초." % _MAX_SECONDS)
	print("")
	_report_stagger()
	_report_verdict()
	_report_why()
	_report_holding_costs()
	quit()


# ---------------------------------------------------------------- 엇갈림의 값


func _report_stagger() -> void:
	print("== 대원의 타가 엇갈리면 (대기 키 = 이것을 0 으로 되돌리는 것) ==")
	print("  %-16s %-14s %s" % ["엇갈림 폭", "적 %d명" % _EASY, "적 %d명" % _HARD])
	for spread in _STAGGERS:
		var note := "  <- 지금 (완벽 정렬)" if spread == 0.0 else ""
		print(
			(
				"  %-16s %-14s %s%s"
				% [
					"%.2f초" % spread,
					_mark(_fight(_EASY, spread)),
					_mark(_fight(_HARD, spread)),
					note,
				]
			)
		)
	print("")


## **지금 잰 값에서 문장을 짓는다** (§28.20.29). 수를 설명문에 박지 않는다.
##
## **처음에는 0.00초(완벽 정렬)를 제일 좋은 쪽으로 놓고 배율을 쟀다.** 감쇠 때문에
## 모아 쳐야 한다고 짐작했기 때문이다. 그 짐작이 틀려서 배율이 x1.00 으로 나왔다 —
## **제일 좋은 쪽을 전제에 박아 두면 그 축은 영영 안 움직인다** (§28.20.39 · §28.20.43).
func _report_verdict() -> void:
	var best_spread := _STAGGERS[0]
	var worst_spread := _STAGGERS[0]
	var best := _fight(_HARD, best_spread)
	var worst := best
	for spread in _STAGGERS:
		var run := _fight(_HARD, spread)
		if not bool(run[1]):
			worst = run
			worst_spread = spread
			break
		if run[0] < best[0]:
			best = run
			best_spread = spread
		if run[0] > worst[0]:
			worst = run
			worst_spread = spread

	print("== 그래서 대기 키가 사는 것 ==")
	if not bool(worst[1]):
		print("  **엇갈림 %.2f초에서 진다.** 이 축은 **승패를 가른다.**" % worst_spread)
		return
	var ratio: float = worst[0] / maxf(best[0], 0.01)
	print("  제일 좋은 엇갈림 %.2f초: %.0f초" % [best_spread, best[0]])
	print("  제일 나쁜 엇갈림 %.2f초: %.0f초" % [worst_spread, worst[0]])
	print("  **배율 x%.2f**" % ratio)
	print("")
	if ratio < 1.3:
		print("  **x1.3 안쪽이다** — §28.20.58 의 시스템 손잡이 넷과 같은 자리다.")
		print("  전투 중 조작이 **결과를 안 바꾼다.** 넣을 이유가 수에는 없다.")
	elif ratio < 2.0:
		print("  **손잡이 넷(x1.3)보다는 크고 몸집(x3.19)보다는 작다.**")
	else:
		print("  **몸집(x3.19) 급이다.** 전투 중 조작이 편성만큼 값을 한다.")
	print("")
	if best_spread > 0.0:
		print("  ★ **방향이 짐작과 반대다.** 제일 좋은 것이 완벽 정렬이 아니라 **어긋내기**다.")
		print("  그러면 대기 키가 파는 것은 「모으기」가 아니라 **「어긋내기」**여야 한다 —")
		print("  그리고 어긋내기는 **아무것도 안 누르면 저절로 되는 일**이다.")
	print("")


# ---------------------------------------------------------------- 왜 그런가


## **수가 맞아도 왜 그런가는 따로 재야 안다** (§28.20.41).
##
## 짐작 둘이 떠올랐다 — **히트스톱이 겹쳐 낭비된다** · **넷이 같은 적을 쳐서 넘친다.**
## 둘 다 끄고 다시 재면 어느 쪽이 사라지는지가 보인다. **짐작을 적지 않고 표를 낸다.**
func _report_why() -> void:
	print("== 왜 어긋내기가 빠른가 — 하나씩 꺼 본다 (적 %d명) ==" % _HARD)
	print("  %-24s %-14s %-14s %s" % ["판", "정렬 0.00초", "어긋 0.15초", "차이"])
	var cases: Array = [
		["지금 그대로", false, true],
		["히트스톱 끔", true, true],
		["걸침 끔 (한 명)", false, false],
		["둘 다 끔", true, false],
	]
	for entry in cases:
		var tight := _fight(_HARD, 0.0, 0.0, bool(entry[1]), bool(entry[2]))
		var loose := _fight(_HARD, 0.15, 0.0, bool(entry[1]), bool(entry[2]))
		var gap := "-"
		if bool(tight[1]) and bool(loose[1]):
			gap = "**x%.2f**" % (tight[0] / maxf(loose[0], 0.01))
		print("  %-24s %-14s %-14s %s" % [entry[0], _mark(tight), _mark(loose), gap])
	print("")
	print("  **차이가 x1.0 으로 내려앉는 줄이 원인이다.** 안 내려앉으면 둘 다 아니다.")
	print("")


# ---------------------------------------------------------------- 대기의 값


## **대기는 공짜가 아니다.** 붙들고 있는 동안 우리는 안 치고 적은 친다.
func _report_holding_costs() -> void:
	print("== 붙들고 있는 값 (전원을 그만큼 늦춘다 — 정렬은 안 깨진다) ==")
	print("  %-16s %-14s %s" % ["전원 대기", "적 %d명" % _EASY, "적 %d명" % _HARD])
	for wait in [0.0, 0.5, 1.0, 2.0, 4.0]:
		print(
			(
				"  %-16s %-14s %s"
				% [
					"%.1f초" % wait,
					_mark(_fight(_EASY, 0.0, wait)),
					_mark(_fight(_HARD, 0.0, wait)),
				]
			)
		)
	print("")
	print("  **정렬을 안 깨는 대기는 그냥 늦는 것이다** — 늦은 만큼 그대로 밀린다.")
	print("  그러니 대기 키의 값은 **기다리는 것**이 아니라 **모으는 것**에 있다.")


# ---------------------------------------------------------------- 한 판


func _mark(run: Array) -> String:
	if not bool(run[1]):
		return "패"
	return "%.0f초" % run[0]


## `[걸린 초, 이겼나]`. `spread` 는 대원 사이의 엇갈림, `wait` 는 전원이 함께 늦는 시간.
func _fight(
	enemies: int, spread: float, wait: float = 0.0, no_hitstop: bool = false, splash: bool = true
) -> Array:
	var tuning := BreakTuning.new()
	if splash:
		tuning.splash_base = BreakTuning.VOLUME_SPLASH_BASE
		tuning.splash_per_cell = BreakTuning.VOLUME_SPLASH_PER_CELL
	if no_hitstop:
		tuning.hitstop_base = 0.0
		tuning.hitstop_per_cell = 0.0

	var field := SparringField.new()
	field.stand_in_ranks(0.0, WeaponMotion.opening_gap_px(), _rank_counts(enemies))

	var chains: Array = []
	for _index in _SQUAD:
		chains.append(_uniform_chain(_CELLS))
	var bout := SparringBout.from_squad(chains, tuning, field, _sized(2))
	bout.start()
	for index in _SQUAD:
		bout.hold(index, wait + float(index) * spread)

	var ours := PackedFloat32Array()
	for _index in _SQUAD:
		ours.append(INF)

	var clock := 0.0
	while clock < _MAX_SECONDS and bout.is_running():
		bout.tick(_STEP)
		clock += _STEP
		for index in _SQUAD:
			if ours[index] == INF and _is_down(bout.ally_gauge(index)):
				ours[index] = clock
		if VictoryRule.decided_at(VictoryRule.Kind.ALL_DOWN, ours, _SQUAD) < INF:
			return [clock, false]
		if _downed(bout, enemies) >= enemies:
			return [clock, true]
	return [_MAX_SECONDS, false]


func _downed(bout: SparringBout, enemies: int) -> int:
	var count := 0
	for index in enemies:
		if _is_down(bout.enemy_gauge(index)):
			count += 1
	return count


func _rank_counts(enemies: int) -> Array[int]:
	var counts: Array[int] = []
	var left := enemies
	while left > 0:
		var here := mini(left, _PER_RANK)
		counts.append(here)
		left -= here
	return counts


func _is_down(gauge: BreakGauge) -> bool:
	return not BreakState.is_worse(BreakState.Kind.KNOCKDOWN, gauge.peak_state())


## 판정 창을 다 쓸 만큼 긴 체인. **한 번 짓고 돌려 쓴다** (§28.20.57).
func _uniform_chain(cells: int) -> Array[BackpackItem]:
	if _chains.has(cells):
		return _chains[cells]
	var hits := SurveyClock.hits_for(BreakTuning.new().strike_seconds_for(_sized(cells)))
	var items: Array[BackpackItem] = []
	for _index in hits:
		items.append(_sized(cells))
	_chains[cells] = items
	return items


func _sized(cells: int) -> BackpackItem:
	var shape: Array[Vector2i] = []
	for index in cells:
		shape.append(Vector2i(index, 0))
	return BackpackItem.new(
		"w%d" % cells,
		"무기%d" % cells,
		BackpackItem.Kind.WEAPON,
		shape,
		Vector2i(0, 0),
		ChainDirection.Kind.RIGHT
	)
