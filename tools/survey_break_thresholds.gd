extends SceneTree
## **문턱을 어디에 둘 것인가.** 실제로 나올 수 있는 체인들을 눈금에 통과시켜 잰다.
##
##     godot --headless --path . -s res://tools/survey_break_thresholds.gd
##
## `docs/design/28-combat.md` §28.5 · §28.8 · §28.20.35.
##
## ## `survey_break_gauge.gd` 와 무엇이 다른가
##
## 저쪽은 **「몇 타에 무엇이 되나」**를 재고, 여기는 **「실제로 나올 수 있는 체인이
## 무엇이 되나」**를 잰다. 40타까지 쳐 보는 것은 판정 재료가 아니다 —
## 6x6 격자에서 작정해도 9타가 상한이기 때문이다 (§28.20.15).
##
## ## 판정 기준 넷
##
## 전부 이미 실측된 수에서 나온다. 새로 정한 것이 아니다.
##
## 1. **무작위 배치(0.79타)로는 띄우기가 안 난다** — 나면 결정이 값을 안 한다
## 2. **경직은 흔하다** — 표본 체인(5타)이면 난다. §28.1-14 「묵직한 액션」
## 3. **띄우기는 작정한 체인(9타)의 보상이다** — 6x6 의 상한에서 닿아야 한다
## 4. **쓰러짐은 한 판 체인으로는 안 난다** — 시작 노드 둘(16타)이나 더 큰 격자라야
##
## **값을 정하지 않고 표만 낸다.** 어느 감쇠에서 넷이 다 서는지를 코드가 세어 준다.

## 6x6 격자에서 작정했을 때의 체인 길이 (§28.20.15 실측).
const _BEST_HITS := 9

## 시작 노드를 둘로 늘렸을 때 (§28.20.15 실측).
const _TWO_NODE_HITS := 16

## 무작위 배치의 평균 (§28.20.13 실측). 반올림해서 한 타로 본다.
const _RANDOM_HITS := 1

## 큰 무기만 모았을 때 작정해도 나오는 길이 (§28.20.15 실측).
const _BULKY_HITS := 3

const _DECAYS: Array[float] = [0.0, 5.0, 8.0, 10.0, 12.0, 15.0, 20.0, 30.0]


func _initialize() -> void:
	var tuning := BreakTuning.new()
	print("== 문턱을 어디에 둘 것인가 ==")
	print(
		(
			"지금 문턱: 경직 %.0f / 띄우기 %.0f / 쓰러짐 %.0f   지금 감쇠: 초당 %.0f"
			% [tuning.stagger_at, tuning.launch_at, tuning.knockdown_at, tuning.decay_per_second]
		)
	)
	print("**이 셋은 따로 못 정한다** (§28.20.22). 감쇠를 움직이면 문턱의 뜻이 통째로 바뀐다.")
	print("")
	_report_reference_chains()
	_report_by_decay()
	_report_verdict()
	_report_our_side()
	quit()


# ---------------------------------------------------------------- 기준 체인들


## 이 판에서 **실제로 나올 수 있는** 체인들. 40타짜리는 여기 없다.
func _report_reference_chains() -> void:
	print("== 실제로 나올 수 있는 체인이 지금 감쇠(초당 %.0f)에서 얼마까지 차나 ==" % BreakTuning.new().decay_per_second)
	print("  %-26s %-8s %s" % ["체인", "타", "최고 눈금"])
	for entry in _references():
		var items: Array[BackpackItem] = entry[1]
		var outcome := ChainBreakSim.run_items(items, BreakTuning.new())
		print("  %-26s %-8s %.0f" % [entry[0], "%d타" % items.size(), outcome.peak])
	print("")
	print("  **9타와 5타의 차이가 곧 배치가 값을 하는 폭이다.** 좁으면 문턱을 어디 둬도 못 가른다.")
	print("")


## [이름, 아이템 목록]. 길이는 전부 §28.20.13 · §28.20.15 의 실측이다.
func _references() -> Array:
	return [
		["무작위 (1칸 한 타)", _uniform(_RANDOM_HITS, 1)],
		["무작위 (4칸 한 타)", _uniform(_RANDOM_HITS, 4)],
		["표본 배치", _sample_chain()],
		["작정하고 (1칸만)", _uniform(_BEST_HITS, 1)],
		["작정하고 (4칸만)", _uniform(_BEST_HITS, 4)],
		["작정하고 (번갈아)", _mixed(_BEST_HITS)],
		["큰 무기만 작정하고", _uniform(_BULKY_HITS, 4)],
		["시작 노드 둘", _uniform(_TWO_NODE_HITS, 1)],
	]


## 화면이 처음 보여 주는 그 체인. **손으로 짠 것이라 표본이지 밸런스가 아니다.**
func _sample_chain() -> Array[BackpackItem]:
	var grid := SampleBackpack.create_grid()
	SampleBackpack.fill(grid, SampleBackpack.create_items())
	var items: Array[BackpackItem] = []
	for chain in ChainResolver.resolve_all(grid):
		for placement in chain.steps:
			items.append(placement.item)
	return items


# ---------------------------------------------------------------- 감쇠별로


func _report_by_decay() -> void:
	var reference := BreakTuning.new()
	print(
		(
			"== 감쇠를 움직이면 그 체인들이 무엇이 되나 (문턱은 %.0f / %.0f / %.0f 고정) =="
			% [reference.stagger_at, reference.launch_at, reference.knockdown_at]
		)
	)
	print("  %-10s %-12s %-12s %-12s %s" % ["초당 빠짐", "무작위 1타", "표본 5타", "작정 9타", "시작노드 둘 16타"])
	for decay in _DECAYS:
		var tuning := BreakTuning.new(decay)
		print(
			(
				"  %-10s %-12s %-12s %-12s %s"
				% [
					"%.0f" % decay,
					_verdict_of(tuning, _uniform(_RANDOM_HITS, 4)),
					_verdict_of(tuning, _sample_chain()),
					_verdict_of(tuning, _mixed(_BEST_HITS)),
					_verdict_of(tuning, _uniform(_TWO_NODE_HITS, 1)),
				]
			)
		)
	print("")


func _verdict_of(tuning: BreakTuning, items: Array[BackpackItem]) -> String:
	var outcome := ChainBreakSim.run_items(items, tuning)
	return "%s %.0f" % [BreakState.label(outcome.highest), outcome.peak]


# ---------------------------------------------------------------- 판정


## **기준 넷을 코드가 세어 준다.** 해설에 수치를 박으면 값이 옮겨질 때 거짓말이 된다 —
## 이 레인에서 이미 두 번 그랬다 (§28.20.29).
func _report_verdict() -> void:
	var reference := BreakTuning.new()
	print("== 기준 넷을 다 세우는 감쇠가 어디인가 ==")
	print("  1. 무작위 한 타로는 띄우기가 안 난다")
	print("  2. 표본 5타면 경직은 난다")
	print("  3. 작정한 9타면 띄우기가 난다")
	print("  4. 한 판 체인(9타)으로는 쓰러짐이 안 난다")
	print("")
	print("  %-10s %-6s %-6s %-6s %-6s %s" % ["초당 빠짐", "1", "2", "3", "4", "판정"])
	var passing := PackedFloat32Array()
	for decay in _DECAYS:
		var tuning := BreakTuning.new(decay)
		var checks := _checks(tuning)
		var all_ok := true
		var marks := PackedStringArray()
		for ok in checks:
			marks.append("O" if ok else "X")
			all_ok = all_ok and ok
		if all_ok:
			passing.append(decay)
		print(
			(
				"  %-10s %-6s %-6s %-6s %-6s %s"
				% [
					"%.0f" % decay,
					marks[0],
					marks[1],
					marks[2],
					marks[3],
					"**선다**" if all_ok else "",
				]
			)
		)
	print("")
	if passing.is_empty():
		print("  **지금 문턱으로는 어떤 감쇠에서도 넷이 다 서지 않는다.** 문턱을 옮겨야 한다.")
	else:
		var listed := PackedStringArray()
		for decay in passing:
			listed.append("초당 %.0f" % decay)
		print(
			(
				"  문턱 %.0f / %.0f / %.0f 은 %s 에서 넷을 다 세운다."
				% [
					reference.stagger_at,
					reference.launch_at,
					reference.knockdown_at,
					", ".join(listed)
				]
			)
		)
	print("")
	_report_headroom()


## 기준 넷. 순서대로 [무작위 X, 표본 경직, 작정 띄우기, 한 판 쓰러짐 X].
func _checks(tuning: BreakTuning) -> Array[bool]:
	var random_hit := ChainBreakSim.run_items(_uniform(_RANDOM_HITS, 4), tuning)
	var sample := ChainBreakSim.run_items(_sample_chain(), tuning)
	var best := ChainBreakSim.run_items(_mixed(_BEST_HITS), tuning)
	return [
		BreakState.is_worse(BreakState.Kind.LAUNCH, random_hit.highest),
		not BreakState.is_worse(BreakState.Kind.STAGGER, sample.highest),
		not BreakState.is_worse(BreakState.Kind.LAUNCH, best.highest),
		BreakState.is_worse(BreakState.Kind.KNOCKDOWN, best.highest),
	]


## **한 타의 순증이 그 무기 한 방의 몇 퍼센트로 남는가.**
##
## 이것이 낮으면 체인 길이가 눈금에 거의 안 실린다 — 열 타를 쳐도 두 타와 비슷해진다.
## 문턱을 어디에 두든 그 상태는 못 고친다.
func _report_headroom() -> void:
	print("== 한 타가 실제로 남기는 몫 (한 방 무게 대비) ==")
	print("  %-10s %-14s %s" % ["초당 빠짐", "1칸", "4칸"])
	for decay in _DECAYS:
		var tuning := BreakTuning.new(decay)
		print("  %-10s %-14s %s" % ["%.0f" % decay, _kept(tuning, 1), _kept(tuning, 4)])
	print("")
	print("  이 몫이 작으면 **긴 체인과 짧은 체인이 같은 데서 만난다.**")
	print("  문턱은 그 폭을 나눌 뿐 폭을 만들지 못한다.")
	print("")


func _kept(tuning: BreakTuning, cells: int) -> String:
	var item := _sized(cells)
	var weight := tuning.poise_for(item)
	var net := weight - tuning.decay_per_second * tuning.strike_seconds_for(item)
	return "%.1f / %.1f  (%.0f%%)" % [net, weight, 100.0 * net / weight]


# ---------------------------------------------------------------- 우리 쪽


## **문턱은 우리에게도 걸린다.** 적이 여럿이면 같은 문턱이 훨씬 빨리 넘어간다 (§28.20.34).
func _report_our_side() -> void:
	print("== 적에게 맞을 때 우리가 몇 초 만에 무너지나 (지금 감쇠) ==")
	print("  %-10s %-12s %-12s %s" % ["적 수", "경직", "띄우기", "쓰러짐"])
	for count: int in [1, 2, 3]:
		var reached := _our_stage_times(count)
		print("  %-10s %-12s %-12s %s" % ["%d명" % count, reached[0], reached[1], reached[2]])
	print("")
	print("  **여기가 너무 빠르면 우리가 체인을 낼 시간이 없다.**")
	print("  §28.8 이 「우리에게도 걸리나」를 미정으로 뒀으므로 지금은 눈금만 오른다.")


## 대련장을 실제로 굴려 우리 눈금이 각 단계를 넘긴 시각.
func _our_stage_times(enemies: int) -> PackedStringArray:
	var tuning := BreakTuning.new()
	var field := SparringField.new()
	var xs := PackedFloat32Array()
	for index in enemies:
		xs.append(60.0 + float(index) * 8.0)
	field.reset_with(0.0, xs)

	# 우리는 오래 서 있기만 한다 — 재는 것은 **맞는 쪽**이다.
	var bout := SparringBout.new(_uniform(60, 1), tuning, field, _sized(2))
	bout.start()
	var stages: Array[BreakState.Kind] = [
		BreakState.Kind.STAGGER, BreakState.Kind.LAUNCH, BreakState.Kind.KNOCKDOWN
	]
	var times := PackedStringArray(["안 된다", "안 된다", "안 된다"])
	var clock := 0.0
	var step := 1.0 / 120.0
	for _frame in 20000:
		if not bout.is_running():
			break
		bout.tick(step)
		clock += step
		for index in stages.size():
			if (
				times[index] == "안 된다"
				and not BreakState.is_worse(stages[index], bout.ally_gauge().state())
			):
				times[index] = "%.1f초" % clock
	return times


# ---------------------------------------------------------------- 표본 무기


func _uniform(hits: int, cells: int) -> Array[BackpackItem]:
	var items: Array[BackpackItem] = []
	for _index in hits:
		items.append(_sized(cells))
	return items


func _mixed(hits: int) -> Array[BackpackItem]:
	var items: Array[BackpackItem] = []
	for index in hits:
		items.append(_sized(1 if index % 2 == 0 else 4))
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
