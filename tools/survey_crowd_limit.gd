extends SceneTree
## **끝을 잰다.** 지금까지의 표가 적 여섯에서 멈춰 있었다.
##
##     godot --headless --path . -s res://tools/survey_crowd_limit.gd
##
## `docs/design/28-combat.md` §28.6 · §28.20.52.
##
## ## 이 도구는 **서 있는 판**을 잰다
##
## 2026-08-10 에 다가옴이 게임 기본값이 됐다 (§28.20.55). 이 도구는 **일부러 그것을 끈다** —
## 여기서 묻는 것이 **「한 번에 몇이 닿나」**이고, 걸어오면 그 물음이 성립하지 않는다.
## 걸어오는 판은 `tools/survey_queue_fill.gd` 가 잰다.
##
## ## 왜 끝인가
##
## §28.6 이 물량전 상한을 **56 / 72 / 100** 으로 실측해 뒀다 — 그런데 그것은
## **렌더와 브라우저**의 상한이다. 우리 전투 쪽 상한은 **한 번도 안 쟀다.**
## §28.20.36~49 의 표가 전부 **적 1~6** 이다.
##
## **조금씩 밀어서는 못 찾는다.** 앞줄이 안 비면 뒷줄과 싸울 일이 영영 없어서
## 적을 늘려도 어느 지점까지는 아무 일도 안 일어난다 — **계단이다. 끝을 먼저 본다.**
##
## ## 「쓰러진 적이 빠지나」가 여기서 전부다
##
## §28.10 이 *"몬스터는 죽고 사람은 제압"* 을 확정했으니 쓰러진 쪽은 판에서 빠진다.
## **그런데 대련장은 지금까지 아무도 안 치웠다** (§28.20.52).
## 적이 여섯까지는 그 차이가 작았는데 **물량전에서는 그것이 판 자체**다.

const SurveyClock := preload("res://tools/survey_clock.gd")
const _MAX_SECONDS := SurveyClock.SECONDS
const _STEP := 1.0 / 60.0
const _CELLS := 4
const _PER_RANK := 3
const _SQUAD := 4

## **끝부터 본다.** §28.6 의 56 / 72 / 100 을 그대로 넣었다.
const _ENEMY_SIZES: Array[int] = [4, 6, 10, 16, 25, 40, 56, 72, 100]

## 칸 수별로 한 번만 짓는 체인.
var _chains: Dictionary = {}


func _initialize() -> void:
	print("== 물량전의 전투 쪽 상한 ==")
	print("  대원 %d 명 · %d칸 무기 · 걸침 켬 · 「거의 눕은 놈을 마저」 — 지금 제일 나은 조합." % [_SQUAD, _CELLS])
	print("  적은 한 켜에 %d 명씩 줄지어 선다. 앞 켜만 서로 닿는다." % _PER_RANK)
	print("  §28.6 의 56 / 72 / 100 은 **렌더** 상한이다. 여기서 재는 것은 **전투** 상한이다.")
	print("")
	_report(false, "가. 쓰러져도 안 빠진다 (지금까지의 모든 표)")
	_report(true, "나. 쓰러지면 판에서 빠진다 (§28.10 확정대로)")
	_report(true, "다. 나와 같되 전진이 남는다 (§28.20.30 미정)", SparringField.AdvanceMode.STAY)
	_report_verdict()
	quit()


func _report(
	leave: bool,
	title: String,
	advance: SparringField.AdvanceMode = SparringField.AdvanceMode.RETURN
) -> void:
	print("== %s ==" % title)
	print("  %-10s %-16s %-16s %s" % ["적", "결과", "눕힌 적", "우리가 눕기까지"])
	for enemies in _ENEMY_SIZES:
		var run := _fight(enemies, leave, advance)
		print(
			(
				"  %-10s %-16s %-16s %s"
				% [
					"%d명" % enemies,
					run[2],
					"%d / %d" % [run[0], enemies],
					"안 눕음" if run[1] == INF else "%.1f초" % run[1],
				]
			)
		)
	print("")


## **끝에서 무엇이 갈렸는지를 지금 잰 값에서 짓는다** (§28.20.29).
func _report_verdict() -> void:
	var stuck := 0
	var cleared := 0
	var pushing := 0
	for enemies in _ENEMY_SIZES:
		if _fight(enemies, false)[0] >= enemies:
			stuck = enemies
		if _fight(enemies, true)[0] >= enemies:
			cleared = enemies
		if _fight(enemies, true, SparringField.AdvanceMode.STAY)[0] >= enemies:
			pushing = enemies
	print("== 어디가 끝인가 ==")
	print("  안 빠지는 판: **%d명**   빠지는 판: **%d명**   전진까지 남는 판: **%d명**" % [stuck, cleared, pushing])
	print("")
	if cleared > stuck:
		print("  「쓰러진 적이 빠지나」가 상한을 %d명에서 %d명으로 옮긴다." % [stuck, cleared])
	else:
		print("  **「쓰러진 적이 빠지나」는 상한을 안 움직인다** — 빠져도 %d명에서 막힌다." % cleared)
		print("  다만 **이기는 데 걸리는 시간은 통째로 달라진다** (위 두 표를 견줘라).")
	print("")
	if pushing > cleared:
		print("  **막고 있던 것은 전진이다.** 상한이 %d명에서 %d명으로 옮겨진다." % [cleared, pushing])
		print("  전진이 돌아오는 판에서는 앞 두 켜를 치우고 나면 **갈 데가 없다** —")
		print("  뒷줄은 리치 밖이고 리치는 무기가 정한다 (§28.20.38).")
		print("  **§28.20.30 의 「전진 뒤 남나 돌아오나」가 물량전의 상한을 쥐고 있다.**")
	else:
		print("  **전진도 상한을 안 움직인다** — %d명 그대로다. 오히려 더 나빠진다:" % pushing)
		print("  파고들면 **뒷줄이 우리에게 닿게 되어** 무승부가 패로 바뀐다 (위 표 10명부터).")
	print("")
	_report_cause(cleared)


## **막는 것에 이름을 붙인다.** 「또 다른 데 있다」로 끝내면 아무것도 안 알아낸 것이다.
func _report_cause(limit: int) -> void:
	var depth := SparringField.new().rank_depth
	var front := WeaponMotion.opening_gap_px()
	var reach := WeaponMotion.max_reach_px()

	# 켜 r 이 서는 거리 = front + r x depth. 그것이 리치 안이어야 닿는다.
	var ranks := 0
	while front + float(ranks) * depth <= reach:
		ranks += 1
	var reachable := ranks * _PER_RANK

	print("== 막고 있는 것 ==")
	print("  앞 켜 %.0f · 켜 간격 %.0f · 제일 긴 리치 %.0f" % [front, depth, reach])
	print("  -> **우리가 닿는 켜는 %d 개**이고 한 켜에 %d 명이다." % [ranks, _PER_RANK])
	if reachable == limit:
		print("  **동시에 닿는 %d 명이 그대로 상한(%d명)이다.**" % [reachable, limit])
	else:
		print("  동시에 닿는 것은 %d 명인데 상한은 %d 명이다 — **둘이 안 맞는다.**" % [reachable, limit])
		print("  맞지 않는 만큼은 아직 설명이 없다. 적어 두고 넘어간다.")
	print("")
	print("  **물량은 「몇이 나오나」가 아니라 「한 번에 몇이 닿나」로 막힌다.**")
	print("  그러니 상한 = 닿는 켜 수 x 켜당 인원이고, 둘 다 지금은 표본이다 —")
	print("  켜당 인원 %d 은 이 도구가 고른 수이지 잰 수가 아니다 (§28.20.39)." % _PER_RANK)
	print("")
	print("  그리고 §28.6 의 렌더 상한(56 / 72 / 100)과 견줘야 뜻이 생긴다 —")
	print("  전투가 먼저 막히면 렌더 상한은 쓸 일이 없고, 렌더가 먼저 막히면 그 반대다.")


# ---------------------------------------------------------------- 한 판


## [눕힌 적 수, 우리가 전원 눕은 시각, 결과 글자].
func _fight(
	enemies: int, leave: bool, advance: SparringField.AdvanceMode = SparringField.AdvanceMode.RETURN
) -> Array:
	var tuning := BreakTuning.new()
	tuning.splash_base = BreakTuning.VOLUME_SPLASH_BASE
	tuning.splash_per_cell = BreakTuning.VOLUME_SPLASH_PER_CELL

	var field := SparringField.new()
	field.stand_in_ranks(0.0, WeaponMotion.opening_gap_px(), _rank_counts(enemies))
	field.target_choice = SparringField.TargetChoice.FINISH_OFF
	field.downed_leave = leave
	field.advance_mode = advance
	# **이 도구는 서 있는 판을 재는 자다** (§28.20.52). 2026-08-10 에 다가옴이 게임
	# 기본값이 됐지만(§28.20.55) 여기서 켜면 「한 번에 몇이 닿나」를 못 잰다 —
	# 걸어오는 판은 `tools/survey_queue_fill.gd` 가 잰다.
	field.approach_speed = 0.0

	var chains: Array = []
	for _index in _SQUAD:
		chains.append(_uniform_chain(_CELLS))
	var bout := SparringBout.from_squad(chains, tuning, field, _sized(2))
	bout.start()

	var ours := PackedFloat32Array()
	for _index in _SQUAD:
		ours.append(INF)

	var clock := 0.0
	var our_end := INF
	while clock < _MAX_SECONDS and bout.is_running():
		bout.tick(_STEP)
		clock += _STEP
		for index in _SQUAD:
			if ours[index] == INF and _is_down(bout.ally_gauge(index)):
				ours[index] = clock
		if our_end == INF:
			our_end = VictoryRule.decided_at(VictoryRule.Kind.ALL_DOWN, ours, _SQUAD)
		if our_end < INF:
			break

	var downed := 0
	for index in enemies:
		if _is_down(bout.enemy_gauge(index)):
			downed += 1

	var verdict := "무승부"
	if downed >= enemies and our_end == INF:
		verdict = "이김 %.1f초" % clock
	elif our_end < INF:
		verdict = "패 %.1f초" % our_end
	return [downed, our_end, verdict]


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


## **판정 창을 다 쓸 만큼 긴 체인.** 길이를 손으로 박지 않는다 —
## 창만 넓히고 체인을 그대로 두면 체인이 먼저 떨어지고, 그 판이 표에 「무승부」로 찍혀
## **구조가 막은 것처럼 보인다** (§28.20.57).
##
## **한 번 짓고 돌려 쓴다.** 판마다 새로 지으면 그것이 제일 큰 비용이 된다 —
## `SparringBout` 이 어차피 자기 몫을 복사한다.
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
