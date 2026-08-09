extends SceneTree
## **적이 두 켜로 서면 §28.20.37 의 답이 그대로인가.**
##
##     godot --headless --path . -s res://tools/survey_ranks.gd
##
## `docs/design/28-combat.md` §28.20.38.
##
## ## 왜 이걸 재는가
##
## §28.20.37 이 뒤집은 손잡이 둘이 **전부 기하다** — 걸침은 「한 타가 몇을 덮나」,
## 표적 고르기는 「그 타가 어디로 가나」. 그런데 그 표는 **전원이 같은 자리**에
## 서 있는 판에서 잰 것이다. **자리가 없으면 반쪽만 잰 것이다.**
##
## 좌표를 넣지 않는다 — 넣는 순간 이동 · 충돌 · 자리 다툼이 딸려 온다 (§28.4 의 몫이다).
## **켜 번호만으로** 물을 것은 다 물을 수 있다.
##
## | 물음 | 왜 켜가 있어야 생기나 |
## | --- | --- |
## | **뒷줄에 닿나** | 못 치면 「안 넘어간다」가 규칙 문제가 아니라 **자리 문제**가 된다 |
## | **걸침이 앞뒤로도 걸리나** | 부피대로 자르는 방식이 두 켜에서도 뜻이 통하나 |
## | **`FINISH_OFF` 가 못 닿는 놈을 고르면** | 지금까지는 전부 닿아서 이 물음이 없었다 |
##
## ## 그리고 제일 중요한 확인
##
## **같은 격자를 다시 재서 대각선이 여전히 뒤집히나.**
## 안 뒤집히면 §28.20.37 의 답은 **「같은 자리」라는 가정 위에서만 참이었던 것이다.**

const _CHAIN_HITS := 80
const _MAX_SECONDS := 60.0
const _STEP := 1.0 / 60.0

## 앞 켜가 서는 거리. 1칸 리치(104)보다 안쪽이라 누구든 앞 켜는 친다.
const _FRONT := 96.0

const _SQUAD_SIZES: Array[int] = [1, 2, 3, 4]
const _ENEMY_SIZES: Array[int] = [1, 2, 3, 4, 5, 6]

## 한 켜에 몇까지 서나. 넘치면 뒤 켜로 밀린다.
const _PER_RANK := 3


func _initialize() -> void:
	var tuning := BreakTuning.new()
	print("== 적이 두 켜로 서면 답이 그대로인가 ==")
	print(
		(
			"문턱 %.0f / %.0f / %.0f   감쇠 초당 %.0f   앞 켜 %.0f   켜 간격 %.0f"
			% [
				tuning.stagger_at,
				tuning.launch_at,
				tuning.knockdown_at,
				tuning.decay_per_second,
				_FRONT,
				SparringField.new().rank_depth,
			]
		)
	)
	print("  한 켜에 %d 명까지 선다. 넘치면 뒤 켜다." % _PER_RANK)
	print("")
	_report_reach()
	_report_diagonal()
	_report_grid(SparringField.TargetChoice.FINISH_OFF, 4, true, "거의 눕은 놈을 마저 + 걸침 (4칸)")
	_report_span()
	quit()


# ---------------------------------------------------------------- 뒷줄에 닿나


## **이 한 표가 나머지 전부를 설명한다.**
func _report_reach() -> void:
	var field := SparringField.new()
	print("== 뒷줄에 닿나 ==")
	print("  %-10s %-10s %-14s %s" % ["무기", "리치", "뒤 켜까지", "닿나"])
	for cells: int in [1, 2, 3, 4]:
		var reach := WeaponMotion.reach_px(_sized(cells))
		var back := _FRONT + field.rank_depth
		print(
			(
				"  %-10s %-10s %-14s %s"
				% [
					"%d칸" % cells,
					"%.0f" % reach,
					"%.0f" % back,
					"닿는다" if reach >= back else "**못 닿는다**"
				]
			)
		)
	print("")
	print("  **작은 무기는 앞 켜밖에 못 친다.** 그러면 「안 넘어간다」가 규칙 문제가 아니라")
	print("  자리 문제가 된다 — 넘어갈 데가 없는 것이다.")
	print("")


# ---------------------------------------------------------------- 대각선을 다시


## **§28.20.37 의 대각선을 켜를 넣고 다시 잰다.** 이것이 제일 중요한 확인이다.
func _report_diagonal() -> void:
	for cells: int in [1, 4]:
		print("== 대각선 (동수) — 두 켜, %d칸 무기, 걸침 끔 ==" % cells)
		var header := "  %-24s" % "규칙"
		for size: int in [1, 2, 3, 4]:
			header += "%-13s" % ("%d대%d" % [size, size])
		print(header)
		for rule in _rules():
			var line := "  %-24s" % rule[1]
			for size: int in [1, 2, 3, 4]:
				line += "%-13s" % _cell(size, size, rule[0], false, cells)
			print(line)
		print("")


func _rules() -> Array:
	return [
		[SparringField.TargetChoice.NEAREST, "가. 가장 가까운 것"],
		[SparringField.TargetChoice.BY_NUMBER, "나. 번호로 나눈다"],
		[SparringField.TargetChoice.LEAST_TARGETED, "다. 안 맞은 놈부터"],
		[SparringField.TargetChoice.FINISH_OFF, "라. 거의 눕은 놈을 마저"],
	]


func _report_grid(
	rule: SparringField.TargetChoice, cells: int, splash: bool, title: String
) -> void:
	print("== 제일 나은 조합으로 격자 전체 — %s ==" % title)
	var header := "  %-10s" % "대원 / 적"
	for enemies in _ENEMY_SIZES:
		header += "%-13s" % ("%d명" % enemies)
	print(header)
	for squad in _SQUAD_SIZES:
		var line := "  %-10s" % ("%d명" % squad)
		for enemies in _ENEMY_SIZES:
			line += "%-13s" % _cell(squad, enemies, rule, splash, cells)
		print(line)
	print("")


# ---------------------------------------------------------------- 걸침이 켜를 넘나


func _report_span() -> void:
	print("== 걸침이 앞뒤로도 걸리나, 좌우로만 걸리나 (4칸 무기, 걸침 켬) ==")
	print("  왼쪽이 켜를 넘음(지금), 오른쪽이 같은 켜만.")
	var header := "  %-24s" % "규칙"
	var cases: Array = [[3, 4], [4, 4], [4, 6]]
	for pair in cases:
		header += "%-24s" % ("%d대%d" % [pair[0], pair[1]])
	print(header)
	for rule in _rules():
		var line := "  %-24s" % rule[1]
		for pair in cases:
			var span := _cell(pair[0], pair[1], rule[0], true, 4, true)
			var same := _cell(pair[0], pair[1], rule[0], true, 4, false)
			line += "%-24s" % ("%s / %s" % [span, same])
		print(line)
	print("")
	print("  **같은 켜에 셋까지 서므로** 좌우로만 걸려도 걸칠 데가 있다.")
	print("  차이가 없으면 켜를 넘는 것이 지금 판에서는 값을 안 하는 것이다.")
	print("  **어느 쪽이 옳은지는 무기가 어떻게 휘둘리는지에 달렸고 그건 아직 없다.**")


# ---------------------------------------------------------------- 한 판


func _cell(
	squad: int,
	enemies: int,
	rule: SparringField.TargetChoice,
	splash: bool,
	cells: int,
	spans: bool = true
) -> String:
	var outcome := _fight(squad, enemies, rule, splash, cells, spans)
	var ours := outcome.x
	var theirs := outcome.y
	if theirs < INF and (ours == INF or theirs < ours):
		return "%.1f초" % theirs
	if ours < INF:
		return "패 %.1f초" % ours
	return "무승부"


func _fight(
	squad: int,
	enemies: int,
	rule: SparringField.TargetChoice,
	splash: bool,
	cells: int,
	spans: bool
) -> Vector2:
	var tuning := BreakTuning.new()
	tuning.splash_spans_ranks = spans
	if splash:
		tuning.splash_base = BreakTuning.VOLUME_SPLASH_BASE
		tuning.splash_per_cell = BreakTuning.VOLUME_SPLASH_PER_CELL

	var field := SparringField.new()
	field.stand_in_ranks(0.0, _FRONT, _rank_counts(enemies))
	field.target_choice = rule

	var chains: Array = []
	for _index in squad:
		chains.append(_uniform_chain(cells))
	var bout := SparringBout.from_squad(chains, tuning, field, _sized(cells))
	bout.start()

	var clock := 0.0
	var ours := INF
	var theirs := INF
	while clock < _MAX_SECONDS and bout.is_running():
		bout.tick(_STEP)
		clock += _STEP
		if ours == INF and _all_down(bout, true, squad):
			ours = clock
		if theirs == INF and _all_down(bout, false, enemies):
			theirs = clock
		if ours < INF and theirs < INF:
			break
	return Vector2(ours, theirs)


## 앞 켜부터 채우고 넘치면 뒤 켜로.
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


func _uniform_chain(cells: int) -> Array[BackpackItem]:
	var items: Array[BackpackItem] = []
	for _index in _CHAIN_HITS:
		items.append(_sized(cells))
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
