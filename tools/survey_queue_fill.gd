extends SceneTree
## **줄이 메워지는 판.** 사용자가 정했다 — 적이 다가오고, 무리를 한꺼번에 상대한다.
##
##     godot --headless --path . -s res://tools/survey_queue_fill.gd
##
## `docs/design/28-combat.md` §28.20.55.
##
## ## 무엇이 정해졌나
##
## > *"전투 물량은 적이 다가오는 거 + 고도화된 AI 좀 있다 적용, 그리고 무리 만나면 한꺼번에 상대."*
##
## §28.20.52 · §28.20.53 이 재 둔 것 위에 사용자 답이 얹혔다.
## **상한 6 은 이제 「동시에 닿는 수」일 뿐이고 판의 크기가 아니다.**
##
## ## 그래서 세 가지를 묻는다
##
## | 물음 | 왜 |
## | --- | --- |
## | **다가옴만으로 되나** | §28.20.53 은 **빠짐을 켠 채로** 쟀다. 둘을 갈라 본 적이 없다 |
## | **끝까지 몇 초 걸리나** | 「상한 56」은 구조가 아니라 **내가 정한 180초**였다 (§28.20.53) |
## | **몸집이 섞이면** | 제자리 판에서 아이 셋이 34.0초였다. 줄이 메워지면 그 셋 배가 어디로 가나 |
##
## ## 시간 제한을 크게 잡는다
##
## 다른 도구는 60초 · 180초에서 끊는다. **여기서는 그 제한이 재는 대상이라** 600초까지 둔다.
## 끊긴 것과 끝난 것을 표에서 갈라 적는다 — 둘을 섞으면 §28.20.53 의 실수를 또 한다.

const _CHAIN_HITS := 2000
const _SHORT_SECONDS := 180.0
const _LONG_SECONDS := 600.0
const _STEP := 1.0 / 60.0
const _CELLS := 4
const _PER_RANK := 3
const _SQUAD := 4

const _ENEMY_SIZES: Array[int] = [6, 10, 16, 25, 56, 100]

## **이동 레인의 실제 값**이다 — `ProtoMoveTuning` 의 `max_speed` 기본값.
## §28.20.53 이 잰 계단(0 과 0 아닌 것 사이에서 갈린다)에서 평평한 쪽에 있는지 확인한다.
const _SPEEDS: Array[float] = [10.0, 40.0, 230.0, 400.0]

## **던전에 들어가는 나이는 16~58 이다** — `PersonGenerator.AGE_MIN` · `AGE_MAX`.
## 사용자 답: *"던전에 너무 어리거나 너무 노인은 당연히 못 들어가니까."*
##
## 그래서 **몸집을 가르는 축이 나이가 아니라 개인차**가 됐다. 아래 셋은 그 폭의 표본이다 —
## **잰 수가 아니다.** 애니 레인이 실측을 내면 바뀐다.
const _SMALL := 0.88
const _BIG := 1.14

## **게임에 안 나오는 판.** 여덟 살 몸집이다 — 표를 지우지 않고 표시만 해 둔다 (§28.20.56).
const _OUT_OF_GAME := 0.70


func _initialize() -> void:
	print("== 줄이 메워지는 판 ==")
	print("  대원 %d 명 · %d칸 무기 · 걸침 켬 · 「거의 눕은 놈을 마저」." % [_SQUAD, _CELLS])
	print("  이동 레인의 실제 유닛 속도는 초당 %.0f 다 (ProtoMoveTuning.max_speed)." % _game_speed())
	print("")
	_report_two_knobs()
	_report_speed_is_flat()
	_report_how_long()
	_report_scale_thresholds()
	_report_mixed_squad()
	quit()


func _game_speed() -> float:
	return ProtoMoveTuning.new().default_of("max_speed")


# ---------------------------------------------------------------- 손잡이 둘


## **다가옴과 빠짐을 갈라 본다.** §28.20.53 은 둘을 같이 켠 채로만 쟀다.
func _report_two_knobs() -> void:
	print("== 다가옴과 빠짐 — 어느 쪽이 줄을 메우나 (%.0f초 제한) ==" % _SHORT_SECONDS)
	print("  %-14s %-12s %-16s %s" % ["다가옴", "쓰러지면", "전원 눕힌 최대 적", "100명일 때"])
	for speed in [0.0, _game_speed()]:
		for leave in [false, true]:
			var limit := 0
			var hundred: Array = []
			for enemies in _ENEMY_SIZES:
				var run := _fight(enemies, speed, leave, _flat_scales(), _SHORT_SECONDS)
				if run[0] >= enemies:
					limit = enemies
				if enemies == 100:
					hundred = run
			print(
				(
					"  %-14s %-12s %-16s %s"
					% [
						"초당 %.0f" % speed,
						"빠진다" if leave else "안 빠진다",
						"%d명" % limit,
						"%d명 눕힘 / %s" % [hundred[0], hundred[1]],
					]
				)
			)
	print("")
	print("  **둘 다 있어야 줄이 메워진다.** 앞줄이 안 비면 뒤가 들어올 자리가 없고,")
	print("  자리가 비어도 아무도 안 걸어오면 그 자리는 계속 빈 채다.")
	print("")


## **게임 값이 계단의 평평한 쪽에 있나.** 있으면 수를 지어낼 필요가 없다.
func _report_speed_is_flat() -> void:
	print("== 속력을 이동 레인 값으로 잡아도 되나 (100명 · %.0f초 제한) ==" % _SHORT_SECONDS)
	print("  %-14s %-16s %s" % ["다가오는 속력", "눕힌 적", "결과"])
	for speed in _SPEEDS:
		var run := _fight(100, speed, true, _flat_scales(), _SHORT_SECONDS)
		print("  %-14s %-16s %s" % ["초당 %.0f" % speed, "%d명" % run[0], run[1]])
	print("")
	print("  **수를 지어내지 않는다** — 이동 레인의 `max_speed` 를 그대로 쓴다 (§28.20.50).")
	print("  값이 옮겨지면 여기도 같이 옮겨진다.")
	print("")


# ---------------------------------------------------------------- 몇 초짜리 싸움인가


## **「상한 56」은 구조가 아니라 시간 제한이었다.** 제한을 걷고 끝까지 재 본다.
func _report_how_long() -> void:
	print("== 무리를 한꺼번에 상대하면 몇 초짜리 싸움인가 (%.0f초까지 둔다) ==" % _LONG_SECONDS)
	print("  %-10s %-18s %s" % ["적", "결과", "초당 몇 명을 눕히나"])
	for enemies in _ENEMY_SIZES:
		var run := _fight(enemies, _game_speed(), true, _flat_scales(), _LONG_SECONDS)
		var seconds: float = run[2]
		var rate := "-" if seconds <= 0.0 else "%.2f명" % (float(run[0]) / seconds)
		print("  %-10s %-18s %s" % ["%d명" % enemies, run[1], rate])
	print("")
	print("  **이것이 「전투가 몇 초까지 가도 되나」의 재료다.** 수가 답을 못 준다 —")
	print("  다만 **한 판에 무엇을 세우면 몇 초가 되는지**는 이제 표에 있다.")
	print("")


# ---------------------------------------------------------------- 몸집


## **문턱을 표본에서 찾지 않고 수에서 뽑는다.**
##
## §28.20.53 은 몸집 넷을 찍어 보고 「x0.70 은 못 닿는다」를 읽었다. 그런데 나이 띠가
## 16~58 로 좁혀지면서 **그 표본이 게임에 안 나오는 값**이 됐다.
## 표본을 다시 고르는 대신 **닿는 경계 자체를 계산한다** — 그러면 어느 범위가 오든 답이 있다.
func _report_scale_thresholds() -> void:
	var front := WeaponMotion.opening_gap_px()
	var short_reach := WeaponMotion.reach_px(_sized(1))
	var long_reach := WeaponMotion.reach_px(_sized(4))
	var picky := front / short_reach
	var floor_scale := front / long_reach

	print("== 몸집이 얼마 밑이면 못 닿나 (앞 켜 %.0f · 1칸 %.0f · 4칸 %.0f) ==" % [front, short_reach, long_reach])
	print("  %-28s %s" % ["작은 무기가 못 닿기 시작하는 몸집", "**x%.2f**" % picky])
	print("  %-28s %s" % ["아무 무기로도 못 닿는 몸집", "**x%.2f**" % floor_scale])
	print("")
	print("  던전에 들어가는 나이는 **16~58** 이다 (`PersonGenerator.AGE_MIN` · `AGE_MAX`).")
	print("  그 띠에서는 몸집을 나이가 아니라 **개인차**가 가른다.")
	print("")
	print("  %-14s %-14s %-14s %s" % ["몸집", "1칸 리치", "4칸 리치", "앞 켜에 닿나"])
	for scale in [_OUT_OF_GAME, floor_scale, _SMALL, picky, 1.0, _BIG]:
		var note := ""
		if is_equal_approx(scale, _OUT_OF_GAME):
			note = "  <- **게임에 안 나온다** (여덟 살 몸집)"
		print(
			(
				"  %-14s %-14s %-14s %s%s"
				% [
					"x%.2f" % scale,
					"%.0f" % (short_reach * scale),
					"%.0f" % (long_reach * scale),
					_verdict_for(scale * short_reach, scale * long_reach, front),
					note,
				]
			)
		)
	print("")
	print("  **「아무 무기로도 못 닿는다」는 x%.2f 밑이라 16~58 띠에서는 안 나온다.**" % floor_scale)
	print("  **「큰 무기만 닿는다」는 x%.2f 밑이라 실제로 나온다** — 작은 어른이 그 자리다." % picky)
	print("")


func _verdict_for(short_reach: float, long_reach: float, front: float) -> String:
	if long_reach < front:
		return "**아무 무기로도 못 닿는다**"
	if short_reach < front:
		return "큰 무기만 닿는다"
	return "둘 다 닿는다"


## §28.20.53 이 제자리 판에서 **아이 셋 34.0초**를 쟀다. 줄이 메워지면, 그리고 몸집 범위가
## 16~58 로 좁혀지면 어떻게 되나.
func _report_mixed_squad() -> void:
	print("== 몸집이 섞이면 (줄이 메워지는 판) ==")
	print("  %-30s %-20s %s" % ["스쿼드", "적 6명", "적 25명"])
	var cases: Array = [
		[_flat_scales(), "넷 다 x1.00"],
		[_mixed(1, _SMALL), "작은 대원 하나 (x%.2f)" % _SMALL],
		[_mixed(2, _SMALL), "작은 대원 둘"],
		[_mixed(4, _SMALL), "넷 다 작다"],
		[_mixed(4, _BIG), "넷 다 크다 (x%.2f)" % _BIG],
		[PackedFloat32Array([_SMALL, _SMALL, 1.0, _BIG]), "실제 섞임 (0.88 x2 · 1.00 · 1.14)"],
		# **작은 대원 하나가 왜 더 빠른가**를 가르는 줄이다 (§28.20.39 — 설명도 그럴듯해 보인다).
		# 어른 셋과 값이 같으면 몸집 때문이 아니라 **넷째가 낭비하고 있던 것**이다.
		[_adults(3), "대원 셋만 (대조군)"],
		[_adults(2), "대원 둘만 (대조군)"],
		[_mixed(1, _OUT_OF_GAME), "**게임에 안 나옴** — x0.70 하나"],
		[_mixed(4, _OUT_OF_GAME), "**게임에 안 나옴** — 넷 다 x0.70"],
	]
	for entry in cases:
		var scales: PackedFloat32Array = entry[0]
		var six := _fight(6, _game_speed(), true, scales, _LONG_SECONDS)
		var many := _fight(25, _game_speed(), true, scales, _LONG_SECONDS)
		print("  %-30s %-20s %s" % [entry[1], six[1], many[1]])
	print("")
	print(
		(
			"  **닿는 대원이 하나도 없으면 그때 무승부다** — 그런데 그 판은 x%.2f 밑이라"
			% (WeaponMotion.opening_gap_px() / WeaponMotion.reach_px(_sized(4)))
		)
	)
	print("  **16~58 띠에서는 안 나온다.** x0.70 줄이 그 판이고, 근거로만 남겨 둔다.")


func _flat_scales() -> PackedFloat32Array:
	var scales := PackedFloat32Array()
	for _index in _SQUAD:
		scales.append(1.0)
	return scales


## 앞의 `count` 명만 그 몸집이고 나머지는 x1.00.
func _mixed(count: int, scale: float) -> PackedFloat32Array:
	var scales := PackedFloat32Array()
	for index in _SQUAD:
		scales.append(scale if index < count else 1.0)
	return scales


## 어른만 그만큼. **스쿼드 인원이 줄어든 판**이지 몸집이 작은 판이 아니다.
func _adults(count: int) -> PackedFloat32Array:
	var scales := PackedFloat32Array()
	for _index in count:
		scales.append(1.0)
	return scales


# ---------------------------------------------------------------- 한 판


## [눕힌 적 수, 결과 글자, 걸린 초]. 끊긴 판은 걸린 초가 0 이다.
func _fight(
	enemies: int, speed: float, leave: bool, scales: PackedFloat32Array, cap: float
) -> Array:
	var tuning := BreakTuning.new()
	tuning.splash_base = BreakTuning.VOLUME_SPLASH_BASE
	tuning.splash_per_cell = BreakTuning.VOLUME_SPLASH_PER_CELL

	var field := SparringField.new()
	field.stand_in_ranks(0.0, WeaponMotion.opening_gap_px(), _rank_counts(enemies))
	field.target_choice = SparringField.TargetChoice.FINISH_OFF
	field.downed_leave = leave
	field.approach_speed = speed

	# **스쿼드 인원은 `scales` 가 정한다.** 몸집을 재는 판과 인원을 재는 판이 같은 자 위에
	# 서야 「아이 하나」와 「어른 셋」을 견줄 수 있다.
	var squad := scales.size()
	var chains: Array = []
	for _index in squad:
		chains.append(_uniform_chain(_CELLS))
	var bout := SparringBout.from_squad(chains, tuning, field, _sized(2), scales)
	bout.start()

	var ours := PackedFloat32Array()
	for _index in squad:
		ours.append(INF)

	var clock := 0.0
	var our_end := INF
	var won_at := 0.0
	while clock < cap and bout.is_running():
		bout.tick(_STEP)
		clock += _STEP
		for index in squad:
			if ours[index] == INF and _is_down(bout.ally_gauge(index)):
				ours[index] = clock
		our_end = VictoryRule.decided_at(VictoryRule.Kind.ALL_DOWN, ours, squad)
		if our_end < INF:
			break
		if _downed_count(bout, enemies) >= enemies:
			won_at = clock
			break

	var downed := _downed_count(bout, enemies)
	if our_end < INF:
		return [downed, "패 %.1f초" % our_end, our_end]
	if won_at > 0.0:
		return [downed, "이김 %.1f초" % won_at, won_at]
	# **끊긴 까닭을 갈라 적는다.** 시간 제한에 걸린 것과 체인이 떨어진 것은 다른 일이다 —
	# 섞어 적으면 「상한 56」을 구조로 읽었던 §28.20.53 의 실수를 또 한다.
	if bout.is_running():
		return [downed, "시간 초과 (%.0f초)" % clock, 0.0]
	# 체인이 `_CHAIN_HITS` 타라 이 시간 안에 떨어질 수 없다. **멈췄다면 칠 것이 없어서다** —
	# 리치 밖이거나(작은 몸) 닿는 켜가 다 비었거나(뒤가 안 온다).
	return [downed, "닿지 못함 (%.0f초)" % clock, 0.0]


func _downed_count(bout: SparringBout, enemies: int) -> int:
	var downed := 0
	for index in enemies:
		if _is_down(bout.enemy_gauge(index)):
			downed += 1
	return downed


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
