extends SceneTree
## **뒷줄에 닿기 위해 무엇을 포기하나.**
##
##     godot --headless --path . -s res://tools/survey_reach_cost.gd
##
## `docs/design/28-combat.md` §28.3 · §28.20.38 · §28.20.40.
##
## ## 왜 이걸 재는가
##
## §28.20.38 이 물량전에 필요한 것을 셋으로 정리했다 —
## **걸침 · 표적 고르기 · 뒷줄에 닿는 무기.**
##
## 앞의 둘은 규칙이라 **공짜**다. 셋째만 값이 붙는다: **긴 무기는 칸을 먹는다** (§28.3).
## 그러면 진짜 물음은 「닿는 무기를 넣어라」가 아니라 **「그 자리에 무엇을 못 넣나」**다.
##
## ## 견줄 자를 칸으로 잡는다
##
## **칸 예산을 고정하고 그 안에서 구성을 바꾼다.** 그래야 값이 매겨진다.
##
## 예산 12칸이 §28.20.15 와 맞물린다 — 4칸 셋이면 **3타**이고,
## 그 절이 "큰 것만 있으면 작정해도 3타" 로 잰 것과 같은 수다.
##
## | 4칸 자루 | 1칸 자루 | 체인 길이 |
## | --- | --- | --- |
## | 0 | 12 | 12타 |
## | 1 | 8 | 9타 |
## | 2 | 4 | 6타 |
## | 3 | 0 | **3타** |
##
## ## 못 견주는 것도 적어 둔다
##
## **「그 칸에 회복을 넣었으면」은 아직 못 견준다** — 체력도 회복도 없다 (§28.5 는
## 무너짐만 확정했다). 지금 견줄 수 있는 것은 **같은 칸을 1칸 무기로 채운 화력**뿐이다.
##
## ## 회복이 생기는 날 고칠 곳은 두 군데뿐이다
##
## 그때 이 도구를 다시 짜지 않아도 되게 자리를 적어 둔다.
##
## | 어디 | 무엇 |
## | --- | --- |
## | `_cycle()` | 예산을 **셋으로** 나눈다 (4칸 · 1칸 · 회복). 지금은 둘이다 |
## | `_report_mix()` | 열을 하나 더 뺀다 — 회복 자루 수 |
##
## **예산(`_BUDGET`)과 판 짜는 부분(`_fight`)은 안 고친다.** 그래서 그때 나온 표가
## 지금 표와 **같은 자로 잰 것**이 된다 — 새 자로 재면 견줄 수가 없다.

const SurveyClock := preload("res://tools/survey_clock.gd")
const _MAX_SECONDS := SurveyClock.SECONDS
const _STEP := 1.0 / 60.0
const _PER_RANK := 3

## 무기가 쓰는 칸 예산. §28.20.15 의 「큰 것만 있으면 3타」와 맞물린다.
const _BUDGET := 12

## 체인은 평타라 계속 돈다 (§28.2.1). 구성을 이 길이까지 돌려 붙인다.
const _CHAIN_HITS := 80


func _initialize() -> void:
	print("== 뒷줄에 닿기 위해 무엇을 포기하나 ==")
	print("  칸 예산 %d 칸 고정. 4칸 자루를 늘리면 체인이 짧아진다." % _BUDGET)
	print("  적은 두 켜로 선다 (한 켜에 %d 명). 뒤 켜는 4칸만 닿는다." % _PER_RANK)
	print("  규칙은 「거의 눕은 놈을 마저」 + 걸침 켬 — §28.20.37 의 제일 나은 조합이다.")
	print("")
	_report_mix()
	_report_squad_split()
	_report_what_it_buys()
	quit()


# ---------------------------------------------------------------- 한 사람의 백팩


func _report_mix() -> void:
	print("== 한 사람이 4칸을 몇 자루 드나 (전원 같은 구성) ==")
	print("  %-10s %-10s %-10s %-12s %-12s %s" % ["4칸", "1칸", "체인", "한 바퀴", "4대4", "4대6"])
	for heavy in range(0, _BUDGET / 4 + 1):
		var light := _BUDGET - heavy * 4
		var cycle := _cycle(heavy, light)
		print(
			(
				"  %-10s %-10s %-10s %-12s %-12s %s"
				% [
					"%d자루" % heavy,
					"%d자루" % light,
					"%d타" % cycle.size(),
					"%.1f초" % _cycle_seconds(cycle),
					_cell(4, 4, cycle),
					_cell(4, 6, cycle),
				]
			)
		)
	print("")
	print("  **0자루는 뒷줄을 영영 못 친다** — 규칙을 무엇으로 바꿔도 안 바뀐다 (§28.20.38).")
	print("  자루를 늘리면 닿기는 하는데 체인이 짧아진다. **그 사이 어딘가가 값이다.**")
	print("")


# ---------------------------------------------------------------- 스쿼드가 나눠 든다


## **넷이 다 긴 무기를 들 필요는 없을지 모른다.** 몇이면 되나.
func _report_squad_split() -> void:
	print("== 스쿼드 넷 중 몇이 긴 무기를 드나 (나머지는 전부 1칸 12타) ==")
	print("  %-16s %-14s %-14s %s" % ["긴 무기 인원", "4대4", "4대6", "4대6 (걸침 끔)"])
	for heavy in range(0, 5):
		var chains: Array = []
		for index in 4:
			chains.append(_cycle(3, 0) if index < heavy else _cycle(0, _BUDGET))
		print(
			(
				"  %-16s %-14s %-14s %s"
				% [
					"%d명" % heavy,
					_cell_squad(4, chains, true),
					_cell_squad(6, chains, true),
					_cell_squad(6, chains, false),
				]
			)
		)
	print("")
	print("  **하나면 되나 둘이어야 하나가 여기서 갈린다.**")
	print("  긴 무기를 든 사람은 체인이 3타뿐이라 화력을 크게 잃는다 —")
	print("  그런데도 뒷줄을 여는 값이 그보다 크면 소수만 들면 된다.")
	print("")


# ---------------------------------------------------------------- 무엇을 얻었나


## **같은 칸을 1칸으로 채웠으면 얻었을 것.** 견줄 자가 이것뿐이다.
func _report_what_it_buys() -> void:
	var tuning := BreakTuning.new()
	print("== 같은 %d 칸이 내는 화력 (닿는 것과 무관하게) ==" % _BUDGET)
	print("  %-10s %-12s %-14s %s" % ["4칸 자루", "한 바퀴 무게", "한 바퀴 시간", "초당 무게"])
	for heavy in range(0, _BUDGET / 4 + 1):
		var cycle := _cycle(heavy, _BUDGET - heavy * 4)
		var weight := 0.0
		for item in cycle:
			weight += tuning.poise_for(item)
		var seconds := _cycle_seconds(cycle)
		print(
			(
				"  %-10s %-12s %-14s %s"
				% [
					"%d자루" % heavy,
					"%.0f" % weight,
					"%.2f초" % seconds,
					"%.1f" % (weight / maxf(0.001, seconds)),
				]
			)
		)
	print("")
	print("  **긴 무기는 화력으로는 언제나 손해다** (§28.20.30 의 기울기 그대로).")
	print("  그래서 값이 붙는 것은 오직 **닿는다는 것 하나**다 —")
	print("  개전(§28.20.30) 과 뒷줄(§28.20.38). 그 둘을 못 사면 넣을 이유가 없다.")
	print("")
	print("  **회복이나 다른 쓸모와는 아직 못 견준다** — 체력도 회복도 없다 (§28.5).")
	print("  그 자리가 생기면 이 표에 열이 하나 더 붙는다.")


# ---------------------------------------------------------------- 한 판


## 4칸과 1칸을 **고르게 섞은** 한 바퀴.
##
## 몰아 두면 4칸이 연달아 나오는 동안만 뒷줄이 열린다. 고르게 두는 것이
## 「닿는 기회가 체인 안에 퍼져 있다」는 쪽이고, 그것이 배치의 상한에 가깝다.
func _cycle(heavy: int, light: int) -> Array[BackpackItem]:
	var items: Array[BackpackItem] = []
	var total := heavy + light
	if total == 0:
		return items
	var placed := 0
	for slot in total:
		var want := int(floor(float(slot + 1) * float(heavy) / float(total)))
		if want > placed:
			items.append(_sized(4))
			placed += 1
		else:
			items.append(_sized(1))
	return items


func _cycle_seconds(cycle: Array[BackpackItem]) -> float:
	var tuning := BreakTuning.new()
	var total := 0.0
	for item in cycle:
		total += tuning.strike_seconds_for(item)
	return total


func _repeat(cycle: Array[BackpackItem]) -> Array[BackpackItem]:
	var items: Array[BackpackItem] = []
	if cycle.is_empty():
		return items
	while items.size() < _CHAIN_HITS:
		items.append(cycle[items.size() % cycle.size()])
	return items


## **한 바퀴 구성을 넘긴다.** 이미 늘린 것을 넘기면 두 번 늘어난다.
func _cell(squad: int, enemies: int, cycle: Array[BackpackItem]) -> String:
	var cycles: Array = []
	for _index in squad:
		cycles.append(cycle)
	return _cell_squad(enemies, cycles, true)


func _cell_squad(enemies: int, cycles: Array, splash: bool) -> String:
	var chains: Array = []
	for cycle in cycles:
		chains.append(_repeat(cycle))
	var outcome := _fight(enemies, chains, splash)
	var ours := outcome.x
	var theirs := outcome.y
	if theirs < INF and (ours == INF or theirs < ours):
		return "%.1f초" % theirs
	if ours < INF:
		return "패 %.1f초" % ours
	return "무승부"


func _fight(enemies: int, chains: Array, splash: bool) -> Vector2:
	var tuning := BreakTuning.new()
	if splash:
		tuning.splash_base = BreakTuning.VOLUME_SPLASH_BASE
		tuning.splash_per_cell = BreakTuning.VOLUME_SPLASH_PER_CELL

	var field := SparringField.new()
	field.stand_in_ranks(0.0, _front(), _rank_counts(enemies))
	field.target_choice = SparringField.TargetChoice.FINISH_OFF

	# 적은 2칸 무기를 든다 — 앞뒤 어느 켜에서든 우리에게 닿는 표본이다.
	var bout := SparringBout.from_squad(chains, tuning, field, _sized(2))
	bout.start()

	var clock := 0.0
	var ours := INF
	var theirs := INF
	while clock < _MAX_SECONDS and bout.is_running():
		bout.tick(_STEP)
		clock += _STEP
		if ours == INF and _all_down(bout, true, chains.size()):
			ours = clock
		if theirs == INF and _all_down(bout, false, enemies):
			theirs = clock
		if ours < INF and theirs < INF:
			break
	return Vector2(ours, theirs)


func _rank_counts(enemies: int) -> Array[int]:
	var counts: Array[int] = []
	var left := enemies
	while left > 0:
		var here := mini(left, _PER_RANK)
		counts.append(here)
		left -= here
	return counts


func _all_down(bout: SparringBout, ours: bool, count: int) -> bool:
	for index in count:
		var gauge := bout.ally_gauge(index) if ours else bout.enemy_gauge(index)
		if BreakState.is_worse(BreakState.Kind.KNOCKDOWN, gauge.peak_state()):
			return false
	return true


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


## 앞 켜가 서는 거리. **수를 안 박고 `WeaponMotion` 에서 뽑는다** (§28.20.50) —
## 애니 레인이 리치를 옮기면 이 거리도 같이 옮겨져야 한다.
func _front() -> float:
	return WeaponMotion.opening_gap_px()
