extends SceneTree
## **적에 따라 끝나는 조건이 갈리면 규칙도 갈려야 하나.**
##
##     godot --headless --path . -s res://tools/survey_mixed_enemies.gd
##
## `docs/design/28-combat.md` §28.10 · §28.20.43 · §28.20.44.
##
## ## 사용자를 안 기다려도 된다 — 이미 확정된 것에서 따라 나온다
##
## §28.10 이 확정했다: **"몬스터는 죽고 사람은 제압이야."**
## 그러면 **조건이 하나일 이유가 없다** — 몬스터 무리는 전원을 눕혀야 끝나고
## 사람 무리는 **우두머리 하나**를 제압하면 나머지가 물러난다.
##
## ## 우두머리는 「아무나 하나」가 아니다
##
## §28.20.43 의 `ANY_ONE` 은 **아무나** 하나였다. 우두머리는 **특정한 하나**다.
## **규칙 넷 중 아무도 그를 노리지 않는다** — 그래서 다섯째를 만들어 같이 잰다.
##
## ## 판을 두 번 안 돌린다
##
## 몬스터냐 사람이냐는 **싸우는 방식을 안 바꾼다.** 판정만 바꾼다.
## 그래서 규칙 넷은 판 하나에서 조합 셋을 다 읽는다.
## `LEADER_FIRST` 만 노리는 대상이 달라지므로 따로 돈다.

const _CHAIN_HITS := 80
const _MAX_SECONDS := 60.0
const _STEP := 1.0 / 60.0
const _NEAR := 60.0
const _SPACING := 4.0
const _CELLS := 4

const _SQUAD_SIZES: Array[int] = [1, 2, 3, 4]
const _ENEMY_SIZES: Array[int] = [1, 2, 3, 4, 5, 6]

## [규칙][대원][적] -> [적 무너진 시각들, 우리 무너진 시각들]
var _runs: Dictionary = {}


func _initialize() -> void:
	print("== 적에 따라 조건이 갈리면 규칙도 갈려야 하나 ==")
	print("  §28.10 확정: 몬스터는 죽고 사람은 제압. 그래서 조건이 무리마다 다르다.")
	print("  %d칸 무기 · 걸침 켬 · 적은 한 줄. 우두머리는 **맨 뒤**에 선다." % _CELLS)
	print("  격자는 대원 1~4 x 적 1~6 = 24 칸.")
	print("")
	_run_everything()
	_report_by_composition()
	_report_mixed()
	_report_cost_of_one_rule()
	quit()


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
		[SparringField.TargetChoice.LEADER_FIRST, "마. 우두머리부터"],
	]


func _key(rule: SparringField.TargetChoice, squad: int, enemies: int) -> String:
	return "%d/%d/%d" % [int(rule), squad, enemies]


# ---------------------------------------------------------------- 무리 하나짜리 판


func _report_by_composition() -> void:
	print("== 무리가 하나일 때 (격자 24칸 중 이긴 칸) ==")
	print("  %-24s %-20s %s" % ["규칙", "몬스터 (전원)", "사람 (우두머리)"])
	for rule in _rules():
		var monsters := 0
		var people := 0
		for squad in _SQUAD_SIZES:
			for enemies in _ENEMY_SIZES:
				if _wins_all(rule[0], squad, enemies):
					monsters += 1
				if _wins_leader(rule[0], squad, enemies):
					people += 1
		print("  %-24s %-20s %s" % [rule[1], "%d칸" % monsters, "%d칸" % people])
	print("")
	print("  **우두머리는 특정한 하나라 아무 규칙도 안 노리면 오래 걸린다.**")
	print("  그래서 「우두머리부터」가 사람 판에서만 값을 한다 — 몬스터 판에서는 거리순과 같다.")
	print("")


# ---------------------------------------------------------------- 섞인 판


## **한 판에 몬스터와 사람이 같이 나오면.** 앞 절반이 몬스터, 뒤 절반이 사람이고
## 우두머리는 맨 뒤다. 조건 둘을 어떻게 합치느냐가 새 물음이다.
func _report_mixed() -> void:
	print("== 섞인 판 — 앞 절반 몬스터, 뒤 절반 사람 (우두머리는 맨 뒤) ==")
	print("  적이 둘 이상인 20칸만 센다 (하나면 섞일 수가 없다).")
	print("  %-24s %-22s %s" % ["규칙", "둘 다 정리돼야", "한 무리만 정리되면"])
	for rule in _rules():
		var every := 0
		var any := 0
		for squad in _SQUAD_SIZES:
			for enemies in _ENEMY_SIZES:
				if enemies < 2:
					continue
				if _wins_mixed(rule[0], squad, enemies, VictoryRule.Mixed.EVERY_GROUP):
					every += 1
				if _wins_mixed(rule[0], squad, enemies, VictoryRule.Mixed.ANY_GROUP):
					any += 1
		print("  %-24s %-22s %s" % [rule[1], "%d칸" % every, "%d칸" % any])
	print("")
	print("  **한 무리만 정리되면 끝**이면 사람 쪽 우두머리를 노리는 것이 지름길이 된다.")
	print("  **둘 다 정리돼야** 하면 몬스터 전원이 발목을 잡아 그 지름길이 값을 잃는다.")
	print("")


# ---------------------------------------------------------------- 하나로 고정하면


## **규칙을 하나로 고정하면 어느 쪽에서 얼마나 손해인가.**
##
## 이것이 이 판의 물음이다 — 조건이 적에 따라 갈리는데 규칙이 하나면
## **한쪽에서 반드시 손해**다. 그 손해가 얼마인지를 재야 「갈라야 하나」에 답이 된다.
func _report_cost_of_one_rule() -> void:
	print("== 규칙을 하나로 고정하면 (조건별 이긴 칸, 24칸 만점) ==")
	print("  %-24s %-14s %-14s %-14s %s" % ["규칙", "몬스터", "사람", "둘 중 나쁜 쪽", "둘 다 켠 합"])
	var best_split := 0
	var best_fixed := 0
	var fixed_name := ""
	for rule in _rules():
		var monsters := 0
		var people := 0
		for squad in _SQUAD_SIZES:
			for enemies in _ENEMY_SIZES:
				if _wins_all(rule[0], squad, enemies):
					monsters += 1
				if _wins_leader(rule[0], squad, enemies):
					people += 1
		var worst := mini(monsters, people)
		if monsters + people > best_fixed:
			best_fixed = monsters + people
			fixed_name = rule[1]
		print(
			(
				"  %-24s %-14s %-14s %-14s %s"
				% [
					rule[1],
					"%d칸" % monsters,
					"%d칸" % people,
					"%d칸" % worst,
					"%d칸" % (monsters + people),
				]
			)
		)
		best_split = maxi(best_split, 0)

	# 적에 따라 갈랐을 때의 상한 — 몬스터에서 제일 나은 것 + 사람에서 제일 나은 것.
	var top_monster := 0
	var top_people := 0
	for rule in _rules():
		var monsters := 0
		var people := 0
		for squad in _SQUAD_SIZES:
			for enemies in _ENEMY_SIZES:
				if _wins_all(rule[0], squad, enemies):
					monsters += 1
				if _wins_leader(rule[0], squad, enemies):
					people += 1
		top_monster = maxi(top_monster, monsters)
		top_people = maxi(top_people, people)
	print("")
	print(
		(
			"  적에 따라 갈랐을 때의 상한: 몬스터 %d칸 + 사람 %d칸 = %d칸"
			% [top_monster, top_people, top_monster + top_people]
		)
	)
	print("  하나로 고정했을 때의 최고: %s, %d칸" % [fixed_name, best_fixed])
	var gap := (top_monster + top_people) - best_fixed
	if gap > 0:
		print("  **차이 %d칸 — 규칙을 하나로 고정하면 그만큼 손해다.**" % gap)
	else:
		print("  **차이가 없다 — 하나로 고정해도 잃는 것이 없다.**")
	print("")
	print("  **정하지 않는다.** 조건을 정하는 것이 먼저고, 그건 사용자의 몫이다 (§28.20.43).")


# ---------------------------------------------------------------- 판정


func _wins_all(rule: SparringField.TargetChoice, squad: int, enemies: int) -> bool:
	var run: Array = _runs[_key(rule, squad, enemies)]
	var them := VictoryRule.decided_at(VictoryRule.Kind.ALL_DOWN, run[0], enemies)
	var us := VictoryRule.decided_at(VictoryRule.Kind.ALL_DOWN, run[1], squad)
	return them < INF and (us == INF or them < us)


func _wins_leader(rule: SparringField.TargetChoice, squad: int, enemies: int) -> bool:
	var run: Array = _runs[_key(rule, squad, enemies)]
	var them := VictoryRule.leader_decided_at(run[0], enemies - 1)
	var us := VictoryRule.decided_at(VictoryRule.Kind.ALL_DOWN, run[1], squad)
	return them < INF and (us == INF or them < us)


func _wins_mixed(
	rule: SparringField.TargetChoice, squad: int, enemies: int, mixed: VictoryRule.Mixed
) -> bool:
	var run: Array = _runs[_key(rule, squad, enemies)]
	var times: PackedFloat32Array = run[0]
	var split := enemies / 2

	# 앞 절반이 몬스터 무리 — 전원이 누워야 한다.
	var monster_times := PackedFloat32Array()
	for index in split:
		monster_times.append(times[index])
	var monsters := VictoryRule.decided_at(VictoryRule.Kind.ALL_DOWN, monster_times, split)

	# 뒤 절반이 사람 무리 — 우두머리(맨 뒤) 하나다.
	var people := VictoryRule.leader_decided_at(times, enemies - 1)

	var groups := PackedFloat32Array([monsters, people])
	var them := VictoryRule.mixed_decided_at(mixed, groups)
	var us := VictoryRule.decided_at(VictoryRule.Kind.ALL_DOWN, run[1], squad)
	return them < INF and (us == INF or them < us)


# ---------------------------------------------------------------- 한 판


func _fight(squad: int, enemies: int, rule: SparringField.TargetChoice) -> Array:
	var tuning := BreakTuning.new()
	tuning.splash_base = BreakTuning.VOLUME_SPLASH_BASE
	tuning.splash_per_cell = BreakTuning.VOLUME_SPLASH_PER_CELL

	var field := SparringField.new()
	field.clear_enemies()
	for index in enemies:
		var enemy := field.add_enemy(_NEAR + float(index) * _SPACING)
		# 앞 절반 몬스터, 뒤 절반 사람. 우두머리는 맨 뒤 하나다.
		if index >= enemies / 2:
			enemy.kind = SparringEnemy.Kind.PERSON
		enemy.is_leader = index == enemies - 1
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
