extends SceneTree
## **전투에서 무엇이 결과를 가르나.** 축을 하나씩만 흔들어 배율을 잰다.
##
##     godot --headless --path . -s res://tools/survey_what_decides.gd
##
## `docs/design/28-combat.md` §28.20.58.
##
## ## 왜 이걸 재나
##
## §28.20.55 가 기본값 둘을 켜고 나서 **표적 고르기 · 걸침 · 뒷줄 무기가 답을 거의 안
## 바꾸게 됐다.** 그리고 §28.20.57 에서 사용자가 *"전투 일단 길어도 돼"* 로 정하면서
## **시간이 압박이 아니게 됐다.**
##
## 그러면 물어야 할 것이 하나 남는다 — **전투에서 플레이어가 무엇을 정하나.**
## **결과를 안 바꾸는 손잡이는 선택이 아니다.**
##
## ## 이 표가 이미 정해 놓고 있는 것 (§28.20.43)
##
## 재는 자가 「빠를수록 좋다」를 전제한다. **사용자가 길어도 된다고 했으므로 그 전제는
## 이미 반쯤 깨져 있다.** 그래서 여기서 읽을 것은 「어느 쪽이 낫나」가 아니라
## **「흔들리기는 하나」**다 — 배율이 1.0 이면 그 축은 **없는 축**이다.
##
## 그리고 **판정을 하나 더 본다** — 축을 흔들어 **이기고 지는 것이 뒤집히나.**
## 시간은 안 뒤집혀도 승패가 뒤집히면 그것은 선택이다.

const SurveyClock := preload("res://tools/survey_clock.gd")

const _STEP := 1.0 / 60.0
const _MAX_SECONDS := SurveyClock.SECONDS
const _PER_RANK := 3

## 기준판. **여기서 한 축만 움직인다.**
const _BASE_SQUAD := 4
const _BASE_CELLS := 4
const _BASE_SCALE := 1.0

## 쉬운 판과 버거운 판. **하나만 보면 「천장에 붙어 있어 안 흔들린다」를 못 가른다.**
const _EASY := 25
const _HARD := 56

## §28.20.56 이 계산한 문턱. 이 밑이면 1칸 무기가 앞 켜에 못 닿는다.
const _PICKY_SCALE := 0.92

## **대원이 제각기 붙는 폭 (초).**
##
## 처음 이 도구는 **대원 넷이 t=0 에 동시에** 치는 판에서 쟀다. §28.20.59 가 그 판이
## **걸침이 통째로 겹치는 최악**임을 밝혔다 — 어긋내면 같은 판이 110초에서 68초가 된다.
## 그리고 이동 레인 실측(§33)에서 대원은 **초 단위로 벌어져** 붙는다.
##
## **0.15 ~ 2.4 초 사이는 거의 평평하다**(68~73초). 그래서 어느 값이든 되는데,
## 그러면 **0 이 아닌 것**을 고른다 — 0 만 특별히 나쁘기 때문이다.
const _STAGGER := 0.3

## 칸 수별로 한 번만 짓는 체인.
var _chains: Dictionary = {}


func _initialize() -> void:
	print("== 전투에서 무엇이 결과를 가르나 ==")
	print(
		(
			"  기준판: 대원 %d · 몸집 x%.2f · %d칸 체인 · 걸침 부피대로 · 가장 가까운 것 ·"
			% [_BASE_SQUAD, _BASE_SCALE, _BASE_CELLS]
		)
	)
	print("  다가옴 켬 · 쓰러지면 빠짐 · 전진 안 남음 · 대원이 %.2f초씩 벌어져 붙는다." % _STAGGER)
	print("  판정 창 %.0f초." % _MAX_SECONDS)
	print("  **한 축만 움직이고 나머지는 기준판 그대로다.**")
	print("")
	_report_axes()
	_report_player_axes()
	_report_scale_steps()
	_report_scale_spread()
	quit()


# ---------------------------------------------------------------- 몸집은 계단이다


## **몸집이 왜 3배를 내나.** 배율이 아니라 **닿는 켜 수**가 뛰기 때문이다.
##
## 처음에는 「걸침이 연속으로 벌어진다」로 읽었다. **틀렸다** — 몸집이 리치를 곱하고,
## 리치가 **켜 거리**를 넘을 때만 닿는 켜가 하나 는다. 그 사이는 완전히 평평하다.
## 경계를 **수에서 뽑는다**: `켜 거리 / 리치`.
func _report_scale_steps() -> void:
	var front := WeaponMotion.opening_gap_px()
	var depth := SparringField.new().rank_depth
	var reach := WeaponMotion.reach_px(_sized(_BASE_CELLS))

	print("== 몸집의 계단 — 앞 켜 %.0f · 켜 간격 %.0f · %d칸 리치 %.0f ==" % [front, depth, _BASE_CELLS, reach])
	print("  %-14s %-16s %-14s %s" % ["닿는 켜", "그러려면 몸집이", "닿는 인원", "적 25명 / 적 56명"])
	for ranks in [1, 2, 3]:
		var need := (front + float(ranks - 1) * depth) / reach
		var probe := maxf(need, 0.05) + 0.005
		var shape := func(plan: Dictionary) -> void: plan["scale"] = probe
		print(
			(
				"  %-14s %-16s %-14s %s / %s"
				% [
					"%d 켜" % ranks,
					"x%.3f 이상" % need,
					"%d 명" % (ranks * _PER_RANK),
					_mark(_fight(shape, _EASY)),
					_mark(_fight(shape, _HARD)),
				]
			)
		)
	print("")
	print("  **계단 사이는 완전히 평평하다** — x0.95 와 x1.05 가 초 단위로 같다 (아래 표).")
	print("  그러니 **몸집은 연속 축이 아니라 「몇 켜에 닿나」라는 등급**이다.")
	print("  경계가 리치와 켜 간격에서 나오므로 **무기를 바꾸면 경계도 옮겨진다.**")
	print("")


# ---------------------------------------------------------------- 플레이어의 두 축


## **배율 하나로는 못 읽는 축이 둘 있다** — 최고와 최저 사이가 **단조롭지 않다.**
## 그래서 값을 전부 편다.
func _report_player_axes() -> void:
	print("== 플레이어가 정하는 두 축을 펴 보면 (적 %d명 / 적 %d명) ==" % [_EASY, _HARD])
	print("  %-16s %s" % ["무기 칸 수", "결과"])
	for cells in [1, 2, 3, 4]:
		var here: int = cells
		var shape := func(plan: Dictionary) -> void: plan["cells"] = here
		print(
			(
				"  %-16s %s / %s"
				% ["%d칸" % cells, _mark(_fight(shape, _EASY)), _mark(_fight(shape, _HARD))]
			)
		)
	print("")
	print("  %-16s %s" % ["대원 수", "결과"])
	for squad in [1, 2, 3, 4]:
		var here: int = squad
		var shape := func(plan: Dictionary) -> void: plan["squad"] = here
		print(
			(
				"  %-16s %s / %s"
				% ["%d명" % squad, _mark(_fight(shape, _EASY)), _mark(_fight(shape, _HARD))]
			)
		)
	print("")
	print("  **둘 다 단조롭지 않다.** 더 크고 더 많은 쪽이 항상 낫지 않다 —")
	print("  §28.20.25 가 잡은 절벽과 같은 종류일 수 있지만 **까닭은 안 쟀다.**")
	print("")


# ---------------------------------------------------------------- 축 하나씩


func _report_axes() -> void:
	print("== 축 하나씩 흔들면 (적 %d명 / 적 %d명 눕히는 시간) ==" % [_EASY, _HARD])
	print("  %-26s %-10s %-24s %-24s %s" % ["축", "누가 정하나", "제일 빠름", "제일 느림", "배율"])
	for axis in _axes():
		_print_axis(axis[0], axis[1], axis[2])
	print("")
	print("  **배율이 1.0 이면 그 축은 없는 축이다** — 손잡이는 있는데 결과가 안 움직인다.")
	print("  **「패」가 섞인 줄은 승패가 뒤집힌 축이다.** 시간이 안 흔들려도 그건 선택이다.")
	print("")


## `[이름, 누가 정하나, [[값 이름, 판 짜는 Callable], ...]]`.
func _axes() -> Array:
	return [
		["표적 고르기", "시스템", _target_cases()],
		["걸침 인원", "시스템", _splash_cases()],
		["걸침이 켜를 넘나", "시스템", _span_cases()],
		["무너뜨리면 끊나", "시스템", _cut_cases()],
		["전진 뒤 남나", "무기", _advance_cases()],
		["무기 칸 수", "**백팩**", _cell_cases()],
		["대원 수", "**편성**", _squad_cases()],
		["대원 몸집", "**편성**", _scale_cases()],
	]


## **진 판은 시간으로 줄 세우지 않는다.**
##
## 처음에 진 판의 「걸린 초」를 그대로 점수로 썼더니 **일찍 진 값이 제일 빠른 것으로
## 올라왔다** — 배율이 x13 으로 찍히고 뜻이 없었다. 진 것은 **끝을 못 본 것**이라
## 시간 축의 값이 아니다 (§28.20.58).
func _print_axis(name: String, owner: String, cases: Array) -> void:
	var best := INF
	var worst := 0.0
	var best_name := "-"
	var worst_name := "-"
	var losses := 0
	for entry in cases:
		var easy: Array = _fight(entry[1], _EASY)
		var hard: Array = _fight(entry[1], _HARD)
		var label := "%s (%s / %s)" % [entry[0], _mark(easy), _mark(hard)]
		if not bool(easy[1]) or not bool(hard[1]):
			losses += 1
			if worst_name == "-" or worst < INF:
				worst = INF
				worst_name = label
			continue
		var score: float = hard[0]
		if score < best:
			best = score
			best_name = label
		if worst < INF and score > worst:
			worst = score
			worst_name = label
	var ratio := "-"
	if best < INF and worst < INF and best > 0.0:
		ratio = "**x%.2f**" % (worst / best)
	if losses > 0:
		ratio = "**승패가 갈린다** (%d/%d 이 진다)" % [losses, cases.size()]
	print("  %-26s %-10s %-24s %-24s %s" % [name, owner, best_name, worst_name, ratio])


func _mark(run: Array) -> String:
	if not run[1]:
		return "패"
	if run[0] >= _MAX_SECONDS:
		return "안 끝남"
	return "%.0f초" % run[0]


# ---------------------------------------------------------------- 축의 값들


func _target_cases() -> Array:
	var made: Array = []
	var names := ["가장 가까운 것", "번호로", "안 맞은 놈", "마저 눕힘"]
	var rules := [
		SparringField.TargetChoice.NEAREST,
		SparringField.TargetChoice.BY_NUMBER,
		SparringField.TargetChoice.LEAST_TARGETED,
		SparringField.TargetChoice.FINISH_OFF,
	]
	for index in rules.size():
		var rule: SparringField.TargetChoice = rules[index]
		made.append([names[index], func(plan: Dictionary) -> void: plan["target"] = rule])
	return made


func _splash_cases() -> Array:
	return [
		["한 명", func(plan: Dictionary) -> void: plan["splash"] = false],
		["부피대로", func(plan: Dictionary) -> void: plan["splash"] = true],
	]


func _span_cases() -> Array:
	return [
		["켜를 안 가림", func(plan: Dictionary) -> void: plan["span"] = false],
		["같은 켜만", func(plan: Dictionary) -> void: plan["span"] = true],
	]


func _cut_cases() -> Array:
	var made: Array = []
	var names := ["안 끊는다", "쓰러지면", "경직이면"]
	var kinds := [BreakState.Kind.NONE, BreakState.Kind.KNOCKDOWN, BreakState.Kind.STAGGER]
	for index in kinds.size():
		var kind: BreakState.Kind = kinds[index]
		made.append([names[index], func(plan: Dictionary) -> void: plan["cut"] = kind])
	return made


func _advance_cases() -> Array:
	return [
		[
			"돌아온다",
			func(plan: Dictionary) -> void: plan["advance"] = SparringField.AdvanceMode.RETURN
		],
		["남는다", func(plan: Dictionary) -> void: plan["advance"] = SparringField.AdvanceMode.STAY],
	]


func _cell_cases() -> Array:
	var made: Array = []
	for cells in [1, 2, 3, 4]:
		var here: int = cells
		made.append(["%d칸" % cells, func(plan: Dictionary) -> void: plan["cells"] = here])
	return made


func _squad_cases() -> Array:
	var made: Array = []
	for squad in [2, 3, 4]:
		var here: int = squad
		made.append(["%d명" % squad, func(plan: Dictionary) -> void: plan["squad"] = here])
	return made


func _scale_cases() -> Array:
	var made: Array = []
	for scale in [0.88, 1.00, 1.14]:
		var here: float = scale
		made.append(["x%.2f" % scale, func(plan: Dictionary) -> void: plan["scale"] = here])
	return made


# ---------------------------------------------------------------- 몸집 폭


## ★ **개인차 폭이 문턱 x%.2f 를 넘나 안 넘나.** 넘으면 「큰 무기만 닿는 대원」이 게임에 있다.
##
## 나이가 축에서 빠지면서(§28.20.56) 몸집을 정하는 것이 개인차만 남았는데
## **그 폭을 정하는 사람이 없다.** 여기서 두 폭을 재서 무엇이 달라지는지만 낸다.
func _report_scale_spread() -> void:
	print("== 몸집 개인차 폭 — 문턱 x%.2f 를 넘는 폭과 안 넘는 폭 ==" % _PICKY_SCALE)
	print("  넘으면 작은 대원이 **1칸 무기로 앞 켜에 못 닿는다** (§28.20.56).")
	print("")
	print(
		(
			"  %-34s %-12s %-10s %-10s %-14s %s"
			% ["폭", "1칸 못 쓰는", "적 25명", "적 56명", "1칸체인·25명", "하한넷 : 상한넷"]
		)
	)
	var spreads: Array = [
		[PackedFloat32Array([1.0, 1.0, 1.0, 1.0]), "없음 (전원 x1.00)"],
		[PackedFloat32Array([0.95, 0.98, 1.02, 1.05]), "좁다 x0.95~1.05 (문턱 위)"],
		[PackedFloat32Array([0.93, 0.97, 1.03, 1.07]), "문턱에 붙음 x0.93~1.07"],
		[PackedFloat32Array([0.85, 0.95, 1.05, 1.15]), "넓다 x0.85~1.15 (문턱 아래)"],
		[PackedFloat32Array([0.82, 0.94, 1.06, 1.18]), "아주 넓다 x0.82~1.18"],
	]
	for entry in spreads:
		var scales: PackedFloat32Array = entry[0]
		var wide := func(plan: Dictionary) -> void: plan["scales"] = scales
		var small := func(plan: Dictionary) -> void:
			plan["scales"] = scales
			plan["cells"] = 1
		print(
			(
				"  %-34s %-12s %-10s %-10s %-14s %s"
				% [
					entry[1],
					"%d / %d 명" % [_locked_out(scales), scales.size()],
					_mark(_fight(wide, _EASY)),
					_mark(_fight(wide, _HARD)),
					_mark(_fight(small, _EASY)),
					_edge_gap(scales),
				]
			)
		)
	print("")
	print("  **4칸 체인에서는 폭이 무엇이든 전원이 닿는다** — 4칸 리치는 x0.81 까지 버틴다.")
	print("  **1칸 체인이 문턱을 드러낸다** — 그 열이 갈리면 폭이 뜻을 가진 것이다.")
	print("")
	print("  ★ **폭을 정하는 것은 「작은 대원이 어떤 무기를 못 쓰나」를 정하는 것이다.**")
	print("  좁으면 몸집은 걸침 세기만 흔들고, 넓으면 **무기와 편성이 서로 걸린다.**")


## **폭의 양 끝만으로 짠 스쿼드 둘의 차이.** 폭이 「편성이 뜻을 가지나」에 얼마를 내나.
##
## 섞인 스쿼드는 큰 대원이 작은 대원을 가려서 폭이 커도 시간이 잘 안 움직인다.
## **양 끝을 갈라 세워야 그 폭이 실제로 몇 배인지 보인다.**
func _edge_gap(scales: PackedFloat32Array) -> String:
	var low := scales[0]
	var high := scales[0]
	for scale in scales:
		low = minf(low, scale)
		high = maxf(high, scale)
	var slow := _fight(func(plan: Dictionary) -> void: plan["scale"] = low, _EASY)
	var fast := _fight(func(plan: Dictionary) -> void: plan["scale"] = high, _EASY)
	if not bool(slow[1]) or not bool(fast[1]):
		return "승패가 갈린다"
	return "%.0f초 : %.0f초 (**x%.2f**)" % [slow[0], fast[0], slow[0] / maxf(fast[0], 0.01)]


## 그 폭에서 **1칸 무기로 앞 켜에 못 닿는 대원 수.** 시간이 아니라 **구조**다 —
## 스쿼드에 큰 대원이 섞여 있으면 시간은 가려지고 이 수만 남는다.
func _locked_out(scales: PackedFloat32Array) -> int:
	var front := WeaponMotion.opening_gap_px()
	var reach := WeaponMotion.reach_px(_sized(1))
	var count := 0
	for scale in scales:
		if reach * scale < front:
			count += 1
	return count


# ---------------------------------------------------------------- 한 판


## `[걸린 초, 이겼나]`. 못 끝내면 창 전체를 돌려준다.
func _fight(shape: Callable, enemies: int) -> Array:
	var plan := {
		"target": SparringField.TargetChoice.NEAREST,
		"splash": true,
		"span": false,
		"cut": BreakState.Kind.NONE,
		"advance": SparringField.AdvanceMode.RETURN,
		"cells": _BASE_CELLS,
		"squad": _BASE_SQUAD,
		"scale": _BASE_SCALE,
		"scales": PackedFloat32Array(),
		"stagger": _STAGGER,
	}
	shape.call(plan)

	var tuning := BreakTuning.new()
	if plan["splash"]:
		tuning.splash_base = BreakTuning.VOLUME_SPLASH_BASE
		tuning.splash_per_cell = BreakTuning.VOLUME_SPLASH_PER_CELL
	tuning.splash_spans_ranks = not bool(plan["span"])
	tuning.chain_cut_at = plan["cut"]

	var field := SparringField.new()
	field.stand_in_ranks(0.0, WeaponMotion.opening_gap_px(), _rank_counts(enemies))
	field.target_choice = plan["target"]
	field.advance_mode = plan["advance"]

	var scales: PackedFloat32Array = plan["scales"]
	if scales.is_empty():
		scales = PackedFloat32Array()
		for _index in int(plan["squad"]):
			scales.append(float(plan["scale"]))

	var chains: Array = []
	for _index in scales.size():
		chains.append(_uniform_chain(int(plan["cells"])))
	var bout := SparringBout.from_squad(chains, tuning, field, _sized(2), scales)
	bout.start()
	for index in scales.size():
		bout.hold(index, float(index) * float(plan["stagger"]))

	var ours := PackedFloat32Array()
	for _index in scales.size():
		ours.append(INF)

	var clock := 0.0
	while clock < _MAX_SECONDS and bout.is_running():
		bout.tick(_STEP)
		clock += _STEP
		for index in scales.size():
			if ours[index] == INF and _is_down(bout.ally_gauge(index)):
				ours[index] = clock
		if VictoryRule.decided_at(VictoryRule.Kind.ALL_DOWN, ours, scales.size()) < INF:
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
