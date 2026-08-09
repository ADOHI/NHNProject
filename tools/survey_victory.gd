extends SceneTree
## **싸움이 언제 끝나느냐가 어느 규칙이 이기는지를 바꾼다.**
##
##     godot --headless --path . -s res://tools/survey_victory.gd
##
## `docs/design/28-combat.md` §28.20.41 · §28.20.43.
##
## ## 왜 이걸 재는가
##
## §28.20.41 이 3대3 상쇄를 설명하면서 이렇게 끝났다:
## **"모으는 게 나쁜 게 아니라 판정 조건이 퍼뜨리는 쪽에 유리한 것이다."**
##
## 그러면 **지금까지의 표 전부가 「전원 눕히기」 위에 서 있다.**
## 그리고 그 조건을 아무도 정한 적이 없다 — 측정 도구가 편의상 고른 것이 전제가 됐다.
##
## ## 한 판을 돌려 조건 넷을 다 읽는다
##
## 조건은 **판을 안 바꾼다** — 언제 끝났다고 부를지만 정한다 (`VictoryRule` 참조).
## 그래서 같은 판 하나에서 넷을 다 읽을 수 있고, **조건 사이 비교가 같은 판 위에서** 이뤄진다.
## 조건마다 따로 돌리면 난수도 없는데 굳이 네 배를 도는 것이고,
## 무엇보다 **다른 판을 견주게 될 위험**이 있다.

const _CHAIN_HITS := 80
const _MAX_SECONDS := 60.0
const _STEP := 1.0 / 60.0
const _NEAR := 60.0
const _SPACING := 4.0

const _SQUAD_SIZES: Array[int] = [1, 2, 3, 4]
const _ENEMY_SIZES: Array[int] = [1, 2, 3, 4, 5, 6]

## 재는 판. 4칸 무기 + 걸침 켬 — §28.20.37 이 고른 제일 나은 조합이다.
const _CELLS := 4

var _conditions: Array[VictoryRule.Kind] = [
	VictoryRule.Kind.ALL_DOWN,
	VictoryRule.Kind.MAJORITY,
	VictoryRule.Kind.ANY_ONE,
	VictoryRule.Kind.TIMED,
]

## [규칙][대원][적] -> [적이 무너진 시각들, 우리가 무너진 시각들]. 한 번만 돌린다.
var _runs: Dictionary = {}


func _initialize() -> void:
	print("== 싸움이 언제 끝나느냐가 답을 바꾸나 ==")
	print("  %d칸 무기 · 걸침 켬 · 적은 한 줄. 조건은 판을 안 바꾸고 판정만 바꾼다." % _CELLS)
	print("  격자는 대원 1~4 x 적 1~6 = 24 칸. 규칙 넷을 각 조건에서 다시 읽는다.")
	print("  「시간 안에」는 %.0f 초 시점의 머릿수를 견준다." % VictoryRule.DEFAULT_TIME_LIMIT)
	print("")
	_run_everything()
	_report_summary()
	_report_diagonals()
	_report_verdict()
	quit()


## **먼저 96 판을 다 돌려 둔다.** 조건은 읽기일 뿐이므로 다시 돌 이유가 없다.
func _run_everything() -> void:
	for rule in _rules():
		for squad in _SQUAD_SIZES:
			for enemies in _ENEMY_SIZES:
				_runs[_key(rule[0], squad, enemies)] = _fight(squad, enemies, rule[0])


func _rules() -> Array:
	return [
		[SparringField.TargetChoice.NEAREST, "가. 가장 가까운 것"],
		[SparringField.TargetChoice.BY_NUMBER, "나. 번호로 나눈다"],
		[SparringField.TargetChoice.LEAST_TARGETED, "다. 안 맞은 놈부터"],
		[SparringField.TargetChoice.FINISH_OFF, "라. 거의 눕은 놈을 마저"],
	]


func _key(rule: SparringField.TargetChoice, squad: int, enemies: int) -> String:
	return "%d/%d/%d" % [int(rule), squad, enemies]


# ---------------------------------------------------------------- 요약


## **조건마다 규칙이 격자 24 칸 중 몇을 이기나.**
func _report_summary() -> void:
	print("== 조건마다 어느 규칙이 이기나 (격자 24칸 중 이긴 칸) ==")
	var header := "  %-24s" % "규칙"
	for kind in _conditions:
		header += "%-16s" % VictoryRule.label(kind)
	print(header)
	for rule in _rules():
		var line := "  %-24s" % rule[1]
		for kind in _conditions:
			var won := 0
			for squad in _SQUAD_SIZES:
				for enemies in _ENEMY_SIZES:
					if _wins(rule[0], squad, enemies, kind):
						won += 1
			line += "%-16s" % ("%d칸" % won)
		print(line)
	print("")


# ---------------------------------------------------------------- 대각선


func _report_diagonals() -> void:
	for kind in _conditions:
		print("== 대각선 (동수) — %s ==" % VictoryRule.label(kind))
		var header := "  %-24s" % "규칙"
		for size: int in [1, 2, 3, 4]:
			header += "%-14s" % ("%d대%d" % [size, size])
		print(header)
		for rule in _rules():
			var line := "  %-24s" % rule[1]
			for size: int in [1, 2, 3, 4]:
				line += "%-14s" % _cell(rule[0], size, size, kind)
			print(line)
		print("")


func _cell(
	rule: SparringField.TargetChoice, squad: int, enemies: int, kind: VictoryRule.Kind
) -> String:
	var run: Array = _runs[_key(rule, squad, enemies)]
	var theirs: PackedFloat32Array = run[0]
	var ours: PackedFloat32Array = run[1]

	if kind == VictoryRule.Kind.TIMED:
		var got := _down_by(theirs, VictoryRule.DEFAULT_TIME_LIMIT)
		var lost := _down_by(ours, VictoryRule.DEFAULT_TIME_LIMIT)
		return "%d:%d" % [got, lost]

	var at_them := VictoryRule.decided_at(kind, theirs, enemies)
	var at_us := VictoryRule.decided_at(kind, ours, squad)
	if at_them < INF and (at_us == INF or at_them < at_us):
		return "%.1f초" % at_them
	if at_us < INF:
		return "패 %.1f초" % at_us
	return "무승부"


## 그 조건에서 우리가 이겼나.
func _wins(
	rule: SparringField.TargetChoice, squad: int, enemies: int, kind: VictoryRule.Kind
) -> bool:
	var run: Array = _runs[_key(rule, squad, enemies)]
	var theirs: PackedFloat32Array = run[0]
	var ours: PackedFloat32Array = run[1]

	if kind == VictoryRule.Kind.TIMED:
		# **머릿수가 아니라 비율로 견준다.** 넷이 하나를 눕힌 것과 하나가 하나를
		# 눕힌 것은 다르다.
		var got := float(_down_by(theirs, VictoryRule.DEFAULT_TIME_LIMIT)) / float(enemies)
		var lost := float(_down_by(ours, VictoryRule.DEFAULT_TIME_LIMIT)) / float(squad)
		return got > lost

	var at_them := VictoryRule.decided_at(kind, theirs, enemies)
	var at_us := VictoryRule.decided_at(kind, ours, squad)
	return at_them < INF and (at_us == INF or at_them < at_us)


func _down_by(times: PackedFloat32Array, limit: float) -> int:
	var count := 0
	for at in times:
		if at <= limit:
			count += 1
	return count


# ---------------------------------------------------------------- 결론


## **해설을 지금 잰 값에서 짓는다** (§28.20.29 — 이 레인에서 두 번 거짓말했다).
func _report_verdict() -> void:
	print("== 조건이 답을 바꾸나 ==")
	for kind in _conditions:
		var best_name := ""
		var best_score := -1
		var tie := false
		for rule in _rules():
			var won := 0
			for squad in _SQUAD_SIZES:
				for enemies in _ENEMY_SIZES:
					if _wins(rule[0], squad, enemies, kind):
						won += 1
			if won > best_score:
				best_score = won
				best_name = rule[1]
				tie = false
			elif won == best_score:
				tie = true
		print(
			(
				"  %-16s 제일 나은 규칙: %s%s (%d칸)"
				% [VictoryRule.label(kind), best_name, "  (동률 있음)" if tie else "", best_score]
			)
		)
	print("")
	print("  **조건마다 답이 다르면 「어느 규칙이 옳은가」는 조건을 정하기 전에는 못 정한다.**")
	print("  그리고 조건은 게임의 성격을 정하는 물음이다 — 사용자가 정한다.")


# ---------------------------------------------------------------- 한 판


## 한 판을 끝까지 돌리고 **양쪽이 무너진 시각들**을 낸다.
func _fight(squad: int, enemies: int, rule: SparringField.TargetChoice) -> Array:
	var tuning := BreakTuning.new()
	tuning.splash_base = BreakTuning.VOLUME_SPLASH_BASE
	tuning.splash_per_cell = BreakTuning.VOLUME_SPLASH_PER_CELL

	var xs := PackedFloat32Array()
	for index in enemies:
		xs.append(_NEAR + float(index) * _SPACING)
	var field := SparringField.new()
	field.reset_with(0.0, xs)
	field.target_choice = rule

	var chains: Array = []
	for _index in squad:
		chains.append(_uniform_chain(_CELLS))
	var bout := SparringBout.from_squad(chains, tuning, field, _sized(_CELLS))
	bout.start()

	var theirs := PackedFloat32Array()
	var ours := PackedFloat32Array()
	for _index in enemies:
		theirs.append(INF)
	for _index in squad:
		ours.append(INF)

	var clock := 0.0
	while clock < _MAX_SECONDS and bout.is_running():
		bout.tick(_STEP)
		clock += _STEP
		for index in enemies:
			if theirs[index] == INF and _is_down(bout.enemy_gauge(index)):
				theirs[index] = clock
		for index in squad:
			if ours[index] == INF and _is_down(bout.ally_gauge(index)):
				ours[index] = clock
	return [theirs, ours]


func _is_down(gauge: BreakGauge) -> bool:
	return not BreakState.is_worse(BreakState.Kind.KNOCKDOWN, gauge.peak_state())


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
