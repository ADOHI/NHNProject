extends SceneTree
## **우두머리를 노리려면 무엇이 있어야 하나.**
##
##     godot --headless --path . -s res://tools/survey_leader_targeting.gd
##
## `docs/design/28-combat.md` §28.20.44 · §28.20.47.
##
## ## 왜 이걸 재는가
##
## §28.20.44 가 이렇게 끝났다:
## **"노리지 않으면 우두머리 조건은 전원 조건과 구별되지 않는다. 조건만 바꿔서는
## 아무것도 안 바뀐다."**
##
## 그러면 **노릴 수 있느냐**가 먼저다. 그리고 그 앞에 둘이 더 있다.
##
## | # | 물음 | 없으면 |
## | --- | --- | --- |
## | 1 | **어떻게 아나** | 모르면 못 노린다. 나머지가 다 공중에 뜬다 |
## | 2 | **노리는 대가가 있나** | 뒤에 있으면 못 닿아서 **고를 수조차 없다** |
##
## ## 2번이 구조에서 나온다
##
## 우리는 **닿는가(1단계)** 를 거른 다음 **누구를(2단계)** 를 고른다 (§28.20.38).
## 그래서 **뒤에 선 우두머리는 후보에 아예 안 올라온다** — 「노린다」가 성립하려면
## 뚫고 들어가는 것이 있어야 하고, 그것이 §28.20.30 의 **전진**이다.

const _CHAIN_HITS := 80
const SurveyClock := preload("res://tools/survey_clock.gd")
const _MAX_SECONDS := SurveyClock.SECONDS
const _STEP := 1.0 / 60.0
const _CELLS := 4
const _NEAR := 60.0
const _SPACING := 4.0

## 켜로 세울 때. 앞 켜 96, 뒤 켜는 112 가 되어 4칸만 닿는다 (§28.20.38).
const _PER_RANK := 3

const _SQUAD_SIZES: Array[int] = [1, 2, 3, 4]
const _ENEMY_SIZES: Array[int] = [1, 2, 3, 4, 5, 6]


func _initialize() -> void:
	print("== 우두머리를 노리려면 무엇이 있어야 하나 ==")
	print("  %d칸 무기 · 걸침 켬 · 우두머리는 맨 뒤. 사람 무리 조건(우두머리 하나)으로 판정한다." % _CELLS)
	print("")
	_report_knowledge()
	_report_price()
	_report_symmetry()
	quit()


func _rules() -> Array:
	return [
		[SparringField.TargetChoice.NEAREST, "가. 가장 가까운 것"],
		[SparringField.TargetChoice.FINISH_OFF, "라. 거의 눕은 놈을 마저"],
		[SparringField.TargetChoice.LEADER_FIRST, "마. 우두머리부터"],
	]


func _knowledges() -> Array:
	return [
		[SparringField.LeaderKnowledge.VISIBLE, "보인다"],
		[SparringField.LeaderKnowledge.ON_HIT, "때려 봐야 안다"],
		[SparringField.LeaderKnowledge.HIDDEN, "아예 모른다"],
	]


# ---------------------------------------------------------------- 어떻게 아나


## **첫째 물음.** 이게 없으면 나머지가 다 공중에 뜬다.
func _report_knowledge() -> void:
	print("== 어떻게 아나 (격자 24칸 중 사람 조건으로 이긴 칸) ==")
	var header := "  %-24s" % "규칙"
	for known in _knowledges():
		header += "%-18s" % known[1]
	print(header)
	for rule in _rules():
		var line := "  %-24s" % rule[1]
		for known in _knowledges():
			var won := 0
			for squad in _SQUAD_SIZES:
				for enemies in _ENEMY_SIZES:
					if _wins_leader(squad, enemies, rule[0], known[0]):
						won += 1
			line += "%-18s" % ("%d칸" % won)
		print(line)
	print("")
	print("  **「아예 모른다」면 우두머리부터가 가장 가까운 것과 똑같아진다** —")
	print("  노릴 대상을 모르니 거리순으로 떨어진다. 조건도 규칙도 값을 안 한다.")
	print("  **「때려 봐야 안다」가 그 사이 어디쯤인지**가 이 표의 알맹이다.")
	print("")


# ---------------------------------------------------------------- 노리는 대가


## **뒤에 선 우두머리는 후보에 아예 안 올라온다.**
##
## 닿는가를 먼저 거르기 때문이다 (§28.20.38). 그래서 「노린다」가 성립하려면
## **뚫고 들어가는 것**이 있어야 하고 그것이 전진이다 — 그런데 §28.20.30 이
## 「전진 뒤 남나 돌아오나」를 **미정**으로 뒀다.
func _report_price() -> void:
	print("== 노리는 대가 — 우두머리가 뒤 켜에 있으면 (적 4명: 앞 3 + 뒤 1) ==")
	print("  우두머리를 눕힌 시각. 켜 간격 때문에 뒤 켜(112)는 4칸(리치 118)만 닿는다.")
	print("  %-14s %-16s %-16s %s" % ["무기", "전진 돌아온다", "전진 남는다", "무엇이 갈렸나"])
	for cells: int in [1, 4]:
		var back := _leader_time_in_ranks(cells, SparringField.AdvanceMode.RETURN)
		var stay := _leader_time_in_ranks(cells, SparringField.AdvanceMode.STAY)
		var note := "같다"
		if back == INF and stay < INF:
			note = "**전진이 있어야 노릴 수 있다**"
		elif back < INF and stay < INF and absf(back - stay) > 0.05:
			note = "빨라진다"
		elif back == INF and stay == INF:
			note = "둘 다 못 노린다"
		print("  %-14s %-16s %-16s %s" % ["%d칸" % cells, _seconds(back), _seconds(stay), note])
	print("")
	print("  **손잡이는 짝이 있어야 돈다.** 우두머리를 노리는 규칙이 있어도")
	print("  전진이 돌아오는 판에서는 짧은 무기로 뒤 켜를 영영 못 고른다 —")
	print("  못 닿으면 후보에 안 올라오기 때문이다 (§28.20.38 의 2단계 구조).")
	print("  **§28.20.30 의 「전진 뒤 남나 돌아오나」가 여기서 값을 한다.**")
	print("")


func _seconds(at: float) -> String:
	return "못 눕힘" if at == INF else "%.1f초" % at


# ---------------------------------------------------------------- 대칭


## **적이 우리 우두머리를 노리면** — 이건 여기서 못 답한다.
func _report_symmetry() -> void:
	print("== 적이 우리 우두머리를 노리면 ==")
	print("  **여기서 못 답한다.** §28.8.1 이 「조장 중심을 어떻게 하나」를 **보류**로 뒀다 —")
	print("  사용자가 나중에 피드백한다고 했고, 통합자가 제안한 것도 사용자가 폐기했다.")
	print("")
	print("  그러니 **스쿼드에 우두머리가 있느냐부터가 사용자의 물음**이다.")
	print("  있다고 치고 재면 그 가정이 곧 답처럼 읽힌다 — §28.20.39 가 모아 둔 함정이다.")
	print("")
	print("  다만 **위 두 표가 그대로 뒤집힌다**는 것만 적어 둔다:")
	print("   - 적이 우리 우두머리를 「아예 모른다」면 우리 조장은 안전하다")
	print("   - 우리 조장을 **뒤에 세우면** 적이 뚫고 들어와야 하고, 그동안 우리가 친다")
	print("  **자리 배치가 곧 방어가 된다** — 그건 §28.4 의 RTS 자리 문제와 만난다.")


# ---------------------------------------------------------------- 한 판


func _wins_leader(
	squad: int, enemies: int, rule: SparringField.TargetChoice, known: SparringField.LeaderKnowledge
) -> bool:
	var run := _fight_line(squad, enemies, rule, known)
	var them := VictoryRule.leader_decided_at(run[0], enemies - 1)
	var us := VictoryRule.decided_at(VictoryRule.Kind.ALL_DOWN, run[1], squad)
	return them < INF and (us == INF or them < us)


## 적이 한 줄로 선 판. 전부 닿는다 — 여기서는 **아는가**만 갈린다.
func _fight_line(
	squad: int, enemies: int, rule: SparringField.TargetChoice, known: SparringField.LeaderKnowledge
) -> Array:
	var field := SparringField.new()
	field.clear_enemies()
	for index in enemies:
		var enemy := field.add_enemy(_NEAR + float(index) * _SPACING)
		enemy.kind = SparringEnemy.Kind.PERSON
		enemy.is_leader = index == enemies - 1
	field.target_choice = rule
	field.leader_knowledge = known
	return _run(field, squad, enemies, _CELLS)


## 우두머리가 **뒤 켜**에 선 판. 여기서는 **닿는가**가 갈린다.
func _leader_time_in_ranks(cells: int, advance: SparringField.AdvanceMode) -> float:
	var field := SparringField.new()
	field.stand_in_ranks(0.0, _front(), [_PER_RANK, 1] as Array[int])
	for index in field.enemy_count():
		var enemy := field.enemy_at(index)
		enemy.kind = SparringEnemy.Kind.PERSON
		enemy.is_leader = index == field.enemy_count() - 1
	field.target_choice = SparringField.TargetChoice.LEADER_FIRST
	field.advance_mode = advance
	var run := _run(field, 4, field.enemy_count(), cells)
	return VictoryRule.leader_decided_at(run[0], field.enemy_count() - 1)


func _run(field: SparringField, squad: int, enemies: int, cells: int) -> Array:
	var tuning := BreakTuning.new()
	tuning.splash_base = BreakTuning.VOLUME_SPLASH_BASE
	tuning.splash_per_cell = BreakTuning.VOLUME_SPLASH_PER_CELL

	var chains: Array = []
	for _index in squad:
		chains.append(_uniform_chain(cells))
	var bout := SparringBout.from_squad(chains, tuning, field, _sized(cells))
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


## 앞 켜가 서는 거리. **수를 안 박고 `WeaponMotion` 에서 뽑는다** (§28.20.50) —
## 애니 레인이 리치를 옮기면 이 거리도 같이 옮겨져야 한다.
func _front() -> float:
	return WeaponMotion.opening_gap_px()
