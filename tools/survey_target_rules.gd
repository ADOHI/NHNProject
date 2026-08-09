extends SceneTree
## **누구를 때리나가 물량전을 가르나.** 고르는 규칙 넷을 같은 격자에서 잰다.
##
##     godot --headless --path . -s res://tools/survey_target_rules.gd
##
## `docs/design/28-combat.md` §28.20.34 물음 ② · §28.20.36 · §28.20.37.
##
## ## 왜 이걸 재는가
##
## §28.20.36 이 잡은 것: **넷이 붙어도 넷 다 앞의 하나를 친다. 그 하나가 눕고 나면
## 뒷줄은 영영 안 맞는다.** 그래서 사람을 늘려도 대각선이 안 뒤집힌다.
##
## **처음에 「리치 안에 둘이면 누구를」이라는 작은 물음으로 적어 뒀는데,
## 실제로는 물량전이 성립하느냐가 거기 걸려 있었다.**
##
## ## 넷을 잰다 — 셋은 퍼뜨리고 하나는 모은다
##
## | 규칙 | 무엇 |
## | --- | --- |
## | `NEAREST` | 가장 가까운 것 (지금) |
## | `BY_NUMBER` | 대원 i 는 적 i%N. 제일 단순하고 고르게 퍼진다 |
## | `LEAST_TARGETED` | 안 맞은 놈부터 |
## | `FINISH_OFF` | 거의 눕은 놈을 마저. **퍼뜨리는 게 항상 옳은지는 모른다** |
##
## ## 측정 가정은 §28.20.36 과 같다 — **우리에게 유리한 판이다**
##
## 특히 **적이 대원을 번갈아 문다**는 것은 스쿼드에게 **가장 좋은 쪽**이다.
## 그런데도 지금 규칙에서는 4대4 가 진다. **표를 실제보다 낙관적으로 읽지 마라.**

const _CHAIN_HITS := 80
const _MAX_SECONDS := 60.0

## 판이 사건 시각에 정확히 맞춰 도므로 **걸음이 굵어도 결과가 안 바뀐다.**
## 바뀌는 것은 「언제 갈렸나」를 알아채는 해상도뿐이다.
const _STEP := 1.0 / 60.0

const _NEAR := 60.0
const _SPACING := 4.0

const _SQUAD_SIZES: Array[int] = [1, 2, 3, 4]
const _ENEMY_SIZES: Array[int] = [1, 2, 3, 4, 5, 6]


func _initialize() -> void:
	var tuning := BreakTuning.new()
	print("== 누구를 때리나가 물량전을 가르나 ==")
	print(
		(
			"문턱 %.0f / %.0f / %.0f   감쇠 초당 %.0f"
			% [tuning.stagger_at, tuning.launch_at, tuning.knockdown_at, tuning.decay_per_second]
		)
	)
	print("")
	print('  칸 읽는 법:  "3.4초" = 그때 적 전원을 눕혔다 (이김)')
	print('               "패 2.1초" = 그때 우리 전원이 먼저 누웠다')
	print('               "무승부" = 60초 안에 어느 쪽도 전원이 안 누웠다')
	print("")
	print("  **이 표는 우리에게 유리한 판이다** — 적이 대원을 번갈아 물어 준다고 가정했다.")
	print("  한 명에게 몰리면 이보다 나쁘다. 그런데도 지금 규칙은 대각선을 못 넘는다.")
	print("")
	for rule in _rules():
		_report_table(rule[0], false, "%s (걸침 끔)" % rule[1])
	_report_diagonal()
	_report_with_splash()
	_report_stall()
	quit()


func _rules() -> Array:
	return [
		[SparringField.TargetChoice.NEAREST, "가. 가장 가까운 것 (지금)"],
		[SparringField.TargetChoice.BY_NUMBER, "나. 번호로 나눈다"],
		[SparringField.TargetChoice.LEAST_TARGETED, "다. 안 맞은 놈부터"],
		[SparringField.TargetChoice.FINISH_OFF, "라. 거의 눕은 놈을 마저"],
	]


# ---------------------------------------------------------------- 표


func _report_table(rule: SparringField.TargetChoice, splash: bool, title: String) -> void:
	print("== %s ==" % title)
	var header := "  %-10s" % "대원 / 적"
	for enemies in _ENEMY_SIZES:
		header += "%-13s" % ("%d명" % enemies)
	print(header)
	for squad in _SQUAD_SIZES:
		var line := "  %-10s" % ("%d명" % squad)
		for enemies in _ENEMY_SIZES:
			line += "%-13s" % _cell(squad, enemies, rule, splash)
		print(line)
	print("")


## **대각선만 모아 본다.** 「사람을 늘려도 안 뒤집힌다」가 여기서 갈린다.
func _report_diagonal() -> void:
	print("== 대각선 (동수) — 어느 규칙이 뒤집나 ==")
	var header := "  %-24s" % "규칙"
	for size: int in [1, 2, 3, 4]:
		header += "%-13s" % ("%d대%d" % [size, size])
	print(header)
	for rule in _rules():
		var line := "  %-24s" % rule[1]
		for size: int in [1, 2, 3, 4]:
			line += "%-13s" % _cell(size, size, rule[0], false)
		print(line)
	print("")


## **걸침과 겹치면 더해지나, 하나면 충분한가.**
##
## **4칸 무기 판이다.** 부피대로 걸침은 1칸이면 1명이라, 위 표들이 쓰는 1칸 무기로는
## 켜도 한 칸도 안 바뀐다 — 처음에 그렇게 재고 "걸침이 아무것도 안 한다" 로 읽을 뻔했다.
## **손잡이를 켜는 것과 그 손잡이가 실제로 걸리는 것은 다르다.**
func _report_with_splash() -> void:
	print("== 표적 고르기와 걸침을 같이 켜면 (4칸 무기 판) ==")
	print("  네 칸으로 본다. 왼쪽이 걸침 끔, 오른쪽이 켬(부피대로 = 4칸이면 2명).")
	print("  **1칸 무기로 재면 켜도 한 칸도 안 바뀐다** — 부피대로면 1칸은 1명이라서다.")
	var cases: Array = [[2, 2], [3, 3], [4, 4], [4, 6]]
	var header := "  %-24s" % "규칙"
	for pair in cases:
		header += "%-22s" % ("%d대%d" % [pair[0], pair[1]])
	print(header)
	for rule in _rules():
		var line := "  %-24s" % rule[1]
		for pair in cases:
			var off := _cell(pair[0], pair[1], rule[0], false, 4)
			var on := _cell(pair[0], pair[1], rule[0], true, 4)
			line += "%-22s" % ("%s / %s" % [off, on])
		print(line)
	print("")
	print("  **둘 다 필요하면 그것도 결론이다.** 값은 안 박았다 (§28.8 · §28.20.34 미정).")


## **3대3 에서 모으는 규칙이 왜 느린가** (§28.20.41).
##
## 총합만 보면 「모으는 게 느리다」로만 읽힌다. 그런데 **판이 끝나는 시점은
## 제일 늦게 눕는 하나가 정한다.** 그 하나가 누구인지를 봐야 답이 나온다.
func _report_stall() -> void:
	print("== 3대3 에서 모으는 규칙이 왜 느린가 (4칸, 걸침 켬) ==")
	print("  적이 셋이면 **한 줄에 다 선다** — 켜가 갈리는 자리가 아니다.")
	print("  %-24s %-11s %-11s %-11s %s" % ["규칙", "적1", "적2", "적3", "판정"])
	for rule in _rules():
		var times := _knockdown_times(3, 3, rule[0], true, 4)
		var shown := PackedStringArray()
		for at in times:
			shown.append("안 눕음" if at == INF else "%.1f초" % at)
		print(
			(
				"  %-24s %-11s %-11s %-11s %s"
				% [rule[1], shown[0], shown[1], shown[2], _cell(3, 3, rule[0], true, 4)]
			)
		)
	print("")
	print("  **판정이 「전원」이라 제일 늦은 하나가 전부를 정한다.**")
	print("  모으는 쪽은 둘을 빨리 눕히고 셋째를 뒤에 남긴다. 퍼뜨리는 쪽은 셋이 같이 눕는다.")
	print("")
	_report_cut_flip()


## **눕히는 것이 이득이면 답이 뒤집히나** (§28.20.41).
##
## 「모으는 쪽이 손해인 건 눕혀도 아무 일이 안 일어나서일 것」이라는 짐작을 재 봤다.
## **아니었다.** 끊는 판에서도 거의 그대로다 — 짐작을 적기 전에 재서 다행이었다.
func _report_cut_flip() -> void:
	print("== 눕히는 것이 이득이면 답이 뒤집히나 (3대3, 4칸, 걸침 켬) ==")
	print("  %-24s %-16s %s" % ["규칙", "안 끊는다", "쓰러지면 못 친다"])
	for rule in _rules():
		print(
			(
				"  %-24s %-16s %s"
				% [
					rule[1],
					_cell(3, 3, rule[0], true, 4),
					_cell(3, 3, rule[0], true, 4, BreakState.Kind.KNOCKDOWN),
				]
			)
		)
	print("")
	print("  **뒤집히지 않는다.** 끊어도 모으는 쪽이 여전히 느리다.")
	print("  그러니 모으는 쪽의 손해는 「눕혀도 소용없어서」가 아니라")
	print("  **순전히 판정이 「전원」이기 때문**이다. 제일 늦은 하나가 전부를 정한다.")
	print("")
	print("  가장 가까운 것만 오히려 더 나빠진다 (패가 더 늦게 온다) —")
	print("  우리가 먼저 굳는 동안 아무도 안 때리는 셋째가 그대로 남아서다.")


## 적마다 쓰러짐 문턱을 넘은 시각. 안 넘었으면 INF.
func _knockdown_times(
	squad: int, enemies: int, rule: SparringField.TargetChoice, splash: bool, cells: int
) -> PackedFloat32Array:
	var tuning := BreakTuning.new()
	if splash:
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
		chains.append(_uniform_chain(cells))
	var bout := SparringBout.from_squad(chains, tuning, field, _sized(cells))
	bout.start()

	var times := PackedFloat32Array()
	for _index in enemies:
		times.append(INF)
	var clock := 0.0
	while clock < _MAX_SECONDS and bout.is_running():
		bout.tick(_STEP)
		clock += _STEP
		for index in enemies:
			if times[index] < INF:
				continue
			if not BreakState.is_worse(
				BreakState.Kind.KNOCKDOWN, bout.enemy_gauge(index).peak_state()
			):
				times[index] = clock
	return times


func _cell(
	squad: int,
	enemies: int,
	rule: SparringField.TargetChoice,
	splash: bool,
	cells: int = 1,
	cut: BreakState.Kind = BreakState.Kind.NONE
) -> String:
	var outcome := _fight(squad, enemies, rule, splash, cells, cut)
	var ours := outcome.x
	var theirs := outcome.y
	if theirs < INF and (ours == INF or theirs < ours):
		return "%.1f초" % theirs
	if ours < INF:
		return "패 %.1f초" % ours
	return "무승부"


## 한 판. [우리 전원이 쓰러진 시각, 적 전원이 쓰러진 시각]. 안 났으면 INF.
func _fight(
	squad: int,
	enemies: int,
	rule: SparringField.TargetChoice,
	splash: bool,
	cells: int = 1,
	cut: BreakState.Kind = BreakState.Kind.NONE
) -> Vector2:
	var tuning := BreakTuning.new()
	tuning.chain_cut_at = cut
	if splash:
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


## 그쪽 전원이 **쓰러짐 문턱을 한 번이라도 넘었나.**
func _all_down(bout: SparringBout, ours: bool, count: int) -> bool:
	for index in count:
		var gauge := bout.ally_gauge(index) if ours else bout.enemy_gauge(index)
		if BreakState.is_worse(BreakState.Kind.KNOCKDOWN, gauge.peak_state()):
			return false
	return true


# ---------------------------------------------------------------- 표본


## **양쪽이 같은 무기를 든다.** 재는 것은 무기가 아니라 고르는 규칙이다.
func _uniform_chain(cells: int = 1) -> Array[BackpackItem]:
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
