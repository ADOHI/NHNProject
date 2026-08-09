extends GutTest
## 대련의 **박자** — 검이 언제 닿고, 맞은 순간 얼마나 멈추는가.
##
## `docs/design/28-combat.md` §28.20.25 · §28.20.28.
##
## `test_sparring_bout.gd` 에서 갈라져 나왔다. 한 파일에 스무 개가 넘어가서이기도 하고,
## **여기 값들은 캐릭터 애니 레인이 옮길 수 있는 것들**이라 한곳에 모아 두는 편이 낫다.

const BoutScript := preload("res://src/core/combat/sparring_bout.gd")
const SimScript := preload("res://src/core/combat/chain_break_sim.gd")
const TuningScript := preload("res://src/core/combat/break_tuning.gd")
const ItemScript := preload("res://src/core/combat/backpack_item.gd")


func _tuning(decay: float = 20.0) -> BreakTuning:
	return TuningScript.new(decay)


## 그 무기 한 번 휘두르는 데 걸리는 시간. 테스트가 상수를 따로 안 적는다.
func _strike(tuning: BreakTuning, cells: int = 1) -> float:
	return tuning.strike_seconds_for(_sized(cells))


func _sized(cells: int) -> BackpackItem:
	var shape: Array[Vector2i] = []
	for index in cells:
		shape.append(Vector2i(index, 0))
	return ItemScript.new(
		"s%d" % cells,
		"무기%d" % cells,
		BackpackItem.Kind.WEAPON,
		shape,
		Vector2i(0, 0),
		ChainDirection.Kind.RIGHT
	)


func _items(count: int) -> Array[BackpackItem]:
	var items: Array[BackpackItem] = []
	for index in count:
		items.append(_sized(1))
	return items


## 판이 끝날 때까지 잘게 돌린다.
func _run_to_end(bout: SparringBout, step: float = 1.0 / 120.0) -> void:
	for _frame in 20000:
		if not bout.is_running():
			return
		bout.tick(step)


func test_it_reports_how_long_the_chain_takes() -> void:
	# 타 간격이 사람이 느끼는 속도가 되는 지점이다.
	var tuning := _tuning()
	var bout := BoutScript.new(_items(5), tuning)
	assert_almost_eq(bout.swing_seconds(), _strike(tuning) * 5.0, 0.001)


func test_a_heavy_chain_takes_longer_than_a_light_one() -> void:
	# **무거운 것이 느리다.** 4칸 철퇴가 1칸 단검과 같은 박자로 때리면 안 된다.
	var tuning := _tuning()
	var light: Array[BackpackItem] = []
	var heavy: Array[BackpackItem] = []
	for _index in 5:
		light.append(_sized(1))
		heavy.append(_sized(4))
	var light_bout := BoutScript.new(light, tuning)
	var heavy_bout := BoutScript.new(heavy, tuning)
	assert_true(
		heavy_bout.swing_seconds() > light_bout.swing_seconds() * 2.0,
		"4칸 다섯 타가 1칸 다섯 타의 두 배는 넘게 걸려야 한다"
	)


func test_strike_time_grows_with_volume() -> void:
	# **여기는 성질만 본다.** 구체적인 실측값은 애니 레인이 옮길 수 있으므로
	# test_strike_times_match_the_animation_lane 한 곳에서만 붙든다.
	var tuning := _tuning()
	assert_true(
		tuning.strike_seconds_for(_sized(2)) < tuning.strike_seconds_for(_sized(3)),
		"칸이 늘면 단조롭게 느려진다"
	)
	assert_true(
		tuning.strike_seconds_for(_sized(1)) < tuning.strike_seconds_for(_sized(4)), "1칸이 4칸보다 빠르다"
	)


func test_a_mixed_chain_sums_each_weapons_own_time() -> void:
	var tuning := _tuning()
	var mixed: Array[BackpackItem] = [_sized(1), _sized(4), _sized(2)]
	var bout := BoutScript.new(mixed, tuning)
	var expected := (
		tuning.strike_seconds_for(_sized(1))
		+ tuning.strike_seconds_for(_sized(4))
		+ tuning.strike_seconds_for(_sized(2))
	)
	assert_almost_eq(bout.swing_seconds(), expected, 0.001)


func test_hitstop_freezes_the_gauge() -> void:
	# **눈금이 안 멈추면 히트스톱이 연출이 아니라 페널티가 된다** —
	# 무거운 무기일수록 멈춤이 길어서 그동안 더 빠지기 때문이다.
	var tuning := _tuning(20.0)
	var heavy: Array[BackpackItem] = [_sized(4)]
	var bout := BoutScript.new(heavy, tuning)
	bout.start()
	# 첫 타가 닿을 때까지.
	for _frame in 6000:
		if bout.landed() >= 1:
			break
		bout.tick(1.0 / 480.0)
	var right_after := bout.gauge_value()
	assert_true(right_after > 0.0, "전제 확인")

	# 히트스톱 길이만큼 흘려도 눈금이 그대로여야 한다.
	bout.tick(tuning.hitstop_seconds_for(_sized(4)) * 0.9)
	assert_almost_eq(bout.gauge_value(), right_after, 0.001, "멈춘 동안에는 안 빠진다")


func test_hitstop_does_not_change_the_outcome() -> void:
	# 멈춤은 눈금도 일정도 함께 세우므로 결과는 그대로여야 한다.
	# 계산기(ChainBreakSim)는 히트스톱을 모르는데도 같은 값이 나와야 맞다.
	var tuning := _tuning()
	var expected := SimScript.run_items(_items(7), tuning)
	var bout := BoutScript.new(_items(7), tuning)
	bout.start()
	_run_to_end(bout)
	assert_almost_eq(bout.peak(), expected.peak, 0.5, "히트스톱이 결과를 바꾸면 안 된다")


func test_hitstop_makes_the_chain_feel_longer() -> void:
	var tuning := _tuning()
	var bout := BoutScript.new(_items(5), tuning)
	assert_true(bout.felt_seconds() > bout.swing_seconds(), "멈춤을 더하면 체감 길이가 늘어난다")


func test_heavier_weapons_stop_longer() -> void:
	var tuning := _tuning()
	assert_true(
		tuning.hitstop_seconds_for(_sized(4)) > tuning.hitstop_seconds_for(_sized(1)),
		"무거운 것이 더 오래 멈춘다"
	)
	assert_almost_eq(tuning.hitstop_seconds_for(_sized(1)), 0.02, 0.005)
	assert_almost_eq(tuning.hitstop_seconds_for(_sized(4)), 0.125, 0.005)


func test_strike_times_match_the_animation_lane() -> void:
	# 애니 레인이 값을 옮기면 여기서 걸린다 (1칸 0.27 -> 0.355 로 실제로 옮겨졌다).
	var tuning := _tuning()
	assert_almost_eq(tuning.strike_seconds_for(_sized(1)), 0.355, 0.005)
	assert_almost_eq(tuning.strike_seconds_for(_sized(4)), 1.018, 0.005)
