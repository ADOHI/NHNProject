extends SceneTree
## **상한 여섯을 무엇이 옮기나.** 적이 다가오는 것과 몸집이 다른 것.
##
##     godot --headless --path . -s res://tools/survey_scale_and_approach.gd
##
## `docs/design/28-combat.md` §28.20.52 · §28.20.53.
##
## ## 둘 다 §28.20.52 에서 나왔다
##
## 그 절이 물량전 상한을 **여섯**으로 재고 까닭을 **「한 번에 몇이 닿나」**로 짚었다.
##
## | 재는 것 | 왜 |
## | --- | --- |
## | **적이 다가온다** | 그 절이 상한을 옮길 후보 넷 중 **제일 자연스럽다**고 적었다 |
## | **몸집이 다르다** | 인물이 여덟 살~여든 살이다. **리치 118 이 상한 6 을 만들었으니 짧아지면 내려간다** |
##
## ## 끝부터 본다
##
## §28.20.52 가 계단이라는 것을 이미 봤다. 그래서 **0(제자리)과 아주 빠름을 먼저 재고**
## 그 사이를 채운다. 조금씩 밀면 아무 일도 안 일어나는 구간에서 헤맨다.

const SurveyClock := preload("res://tools/survey_clock.gd")
const _MAX_SECONDS := SurveyClock.SECONDS
const _STEP := 1.0 / 60.0
const _CELLS := 4
const _PER_RANK := 3
const _SQUAD := 4

const _ENEMY_SIZES: Array[int] = [6, 10, 16, 25, 56, 100]

## 끝 둘을 먼저 두고 사이를 채운다. 0 은 지금, 400 은 사실상 즉시 붙는 것이다.
const _SPEEDS: Array[float] = [0.0, 400.0, 10.0, 40.0]

## 여덟 살~여든 살. **표본이지 실측이 아니다** — 애니 레인 값이 오면 바뀐다.
const _SCALES: Array[float] = [0.70, 0.85, 1.00, 1.15]

## 칸 수별로 한 번만 짓는 체인.
var _chains: Dictionary = {}


func _initialize() -> void:
	print("== 상한 여섯을 무엇이 옮기나 ==")
	print("  대원 %d 명 · %d칸 무기 · 걸침 켬 · 「거의 눕은 놈을 마저」 · 쓰러지면 빠진다." % [_SQUAD, _CELLS])
	print("")
	_report_approach()
	_report_scale_reach()
	_report_mixed_squad()
	quit()


# ---------------------------------------------------------------- 적이 다가온다


func _report_approach() -> void:
	print("== 적이 다가오면 상한이 오르나 (끝부터) ==")
	print("  %-16s %-16s %s" % ["다가오는 속력", "전원 눕힌 최대 적", "100명일 때"])
	for speed in _SPEEDS:
		var limit := 0
		var hundred: Array = []
		for enemies in _ENEMY_SIZES:
			var run := _fight(enemies, speed, _flat_scales())
			if run[0] >= enemies:
				limit = enemies
			if enemies == 100:
				hundred = run
		print(
			(
				"  %-16s %-16s %s"
				% ["초당 %.0f" % speed, "%d명" % limit, "%d명 눕힘 / %s" % [hundred[0], hundred[1]]]
			)
		)
	print("")
	print("  **줄이 메워지면 여섯이 계속 갈린다** — 우리가 상대하는 수는 그대로인데")
	print("  판이 안 끝나는 대신 계속 돌아간다. 상한이 「동시에」가 아니라 「끝까지」로 바뀐다.")
	print("")
	print("  > **재미있는가는 여기서 못 답한다.** 여섯이 줄 서서 오는 것과")
	print("  > 스무 명이 몰려오는 것 중 무엇이 이 게임인지는 **기획 물음**이다.")
	print("  > 수가 말해 주는 것은 「줄을 메우면 100명이 판에 들어올 길이 생긴다」까지다.")
	print("")


# ---------------------------------------------------------------- 몸집


## **리치 118 이 상한 6 을 만들었다.** 몸집이 곱해지면 그 수가 통째로 움직인다.
func _report_scale_reach() -> void:
	var front := WeaponMotion.opening_gap_px()
	print("== 몸집이 다르면 애초에 닿나 (앞 켜 %.0f) ==" % front)
	print("  %-12s %-14s %-14s %s" % ["몸집", "1칸 리치", "4칸 리치", "앞 켜에 닿나"])
	for scale in _SCALES:
		var short_reach := WeaponMotion.reach_px(_sized(1)) * scale
		var long_reach := WeaponMotion.reach_px(_sized(4)) * scale
		var verdict := "둘 다 닿는다"
		if long_reach < front:
			verdict = "**아무 무기로도 못 닿는다**"
		elif short_reach < front:
			verdict = "큰 무기만 닿는다"
		print(
			(
				"  %-12s %-14s %-14s %s"
				% ["x%.2f" % scale, "%.0f" % short_reach, "%.0f" % long_reach, verdict]
			)
		)
	print("")
	print("  **작은 몸은 싸움에 못 낀다** — 못 때리는 것이 아니라 **닿을 자리에 못 선다.**")
	print("  앞 켜 거리는 어른 리치에서 뽑은 것이라(§28.20.50) 아이가 서면 그 밖이다.")
	print("")


# ---------------------------------------------------------------- 섞인 스쿼드


func _report_mixed_squad() -> void:
	print("== 몸집이 다른 대원이 섞이면 상한이 어떻게 되나 (적이 안 다가오는 판) ==")
	print("  %-24s %-16s %s" % ["스쿼드", "전원 눕힌 최대 적", "여섯을 눕히는 시간"])
	var cases: Array = [
		[_flat_scales(), "넷 다 어른 (x1.00)"],
		[_mixed(1), "아이 하나 (x0.70)"],
		[_mixed(2), "아이 둘"],
		[_mixed(3), "아이 셋"],
		[PackedFloat32Array([0.85, 0.85, 1.0, 1.15]), "섞임 (0.85 x2 · 1.00 · 1.15)"],
	]
	for entry in cases:
		var scales: PackedFloat32Array = entry[0]
		var limit := 0
		var six: Array = []
		for enemies in _ENEMY_SIZES:
			var run := _fight(enemies, 0.0, scales)
			if run[0] >= enemies:
				limit = enemies
			if enemies == 6:
				six = run
		print("  %-24s %-16s %s" % [entry[1], "%d명" % limit, six[1]])
	print("")
	print("  **상한(수)은 잘 안 움직이고 시간이 움직인다** — 못 닿는 대원은 화력에서 빠질 뿐")
	print("  닿는 대원이 남아 있는 한 줄은 결국 정리된다.")
	print("  **한 명도 못 닿는 판이 되면 그때 무승부가 된다.**")


func _flat_scales() -> PackedFloat32Array:
	var scales := PackedFloat32Array()
	for _index in _SQUAD:
		scales.append(1.0)
	return scales


func _mixed(children: int) -> PackedFloat32Array:
	var scales := PackedFloat32Array()
	for index in _SQUAD:
		scales.append(0.70 if index < children else 1.0)
	return scales


# ---------------------------------------------------------------- 한 판


## [눕힌 적 수, 결과 글자].
func _fight(enemies: int, speed: float, scales: PackedFloat32Array) -> Array:
	var tuning := BreakTuning.new()
	tuning.splash_base = BreakTuning.VOLUME_SPLASH_BASE
	tuning.splash_per_cell = BreakTuning.VOLUME_SPLASH_PER_CELL

	var field := SparringField.new()
	field.stand_in_ranks(0.0, WeaponMotion.opening_gap_px(), _rank_counts(enemies))
	field.target_choice = SparringField.TargetChoice.FINISH_OFF
	field.downed_leave = true
	field.approach_speed = speed

	var chains: Array = []
	for _index in _SQUAD:
		chains.append(_uniform_chain(_CELLS))
	var bout := SparringBout.from_squad(chains, tuning, field, _sized(2), scales)
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
	return [downed, verdict]


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
