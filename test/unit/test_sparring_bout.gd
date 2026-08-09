extends GutTest
## 실시간으로 굴러가는 대련 한 판.
##
## `docs/design/28-combat.md` §28.4 · §28.5.
##
## **가장 중요한 것은 계산기와 어긋나지 않는 것이다.**
## 화면이 보여 주는 결과와 측정 도구가 재는 결과가 갈리면 둘 다 못 믿는다.

const BoutScript := preload("res://src/core/combat/sparring_bout.gd")
const SimScript := preload("res://src/core/combat/chain_break_sim.gd")
const TuningScript := preload("res://src/core/combat/break_tuning.gd")
const ItemScript := preload("res://src/core/combat/backpack_item.gd")
const GridScript := preload("res://src/core/combat/backpack_grid.gd")


func _tuning(decay: float = 20.0) -> BreakTuning:
	return TuningScript.new(decay)


func _pip(id: String) -> BackpackItem:
	return ItemScript.new(
		id,
		id,
		BackpackItem.Kind.WEAPON,
		[Vector2i(0, 0)],
		Vector2i(0, 0),
		ChainDirection.Kind.RIGHT
	)


func _items(count: int) -> Array[BackpackItem]:
	var items: Array[BackpackItem] = []
	for index in count:
		items.append(_pip("w%d" % index))
	return items


## 판이 끝날 때까지 잘게 돌린다.
func _run_to_end(bout: SparringBout, step: float = 1.0 / 120.0) -> void:
	for _frame in 20000:
		if not bout.is_running():
			return
		bout.tick(step)


# ---------------------------------------------------------------- 시간이 흐른다


func test_a_bout_does_nothing_until_started() -> void:
	var bout := BoutScript.new(_items(5), _tuning())
	assert_eq(bout.phase(), SparringBout.Phase.READY)
	bout.tick(10.0)
	assert_eq(bout.landed(), 0, "시작 전에는 아무것도 안 나간다")
	assert_eq(bout.gauge_value(), 0.0)


func test_hits_land_one_at_a_time() -> void:
	var tuning := _tuning()
	var bout := BoutScript.new(_items(4), tuning)
	bout.start()
	assert_eq(bout.landed(), 0, "시작만 하고 시간이 안 흘렀으면 아직이다")

	bout.tick(0.001)
	assert_eq(bout.landed(), 1, "첫 타는 곧바로 나간다")

	bout.tick(tuning.seconds_per_hit)
	assert_eq(bout.landed(), 2, "타 간격마다 하나씩")


func test_hits_do_not_all_land_at_once() -> void:
	var tuning := _tuning()
	var bout := BoutScript.new(_items(6), tuning)
	bout.start()
	bout.tick(tuning.seconds_per_hit * 2.5)
	assert_true(bout.landed() < 6, "한 번에 다 나가면 실시간이 아니다")
	assert_eq(bout.landed(), 3)


func test_it_reports_how_long_the_chain_takes() -> void:
	# 타 간격이 사람이 느끼는 속도가 되는 지점이다.
	var tuning := _tuning()
	var bout := BoutScript.new(_items(5), tuning)
	assert_almost_eq(bout.swing_seconds(), tuning.seconds_per_hit * 4.0, 0.001)


func test_a_single_hit_chain_takes_no_time() -> void:
	assert_eq(BoutScript.new(_items(1), _tuning()).swing_seconds(), 0.0)


# ---------------------------------------------------------------- 계산기와 같아야 한다


func test_a_finished_bout_matches_the_simulator() -> void:
	# **이 테스트가 화면과 측정 도구를 붙들어 둔다.**
	for count in [2, 5, 9]:
		var tuning := _tuning()
		var expected := SimScript.run_items(_items(count), tuning)
		var bout := BoutScript.new(_items(count), tuning)
		bout.start()
		_run_to_end(bout)
		assert_almost_eq(bout.peak(), expected.peak, 0.5, "%d타에서 최고 눈금이 계산기와 달랐다" % count)
		assert_eq(bout.peak_state(), expected.highest, "%d타에서 단계가 달랐다" % count)


func test_it_matches_even_when_frames_are_lumpy() -> void:
	# 프레임이 튀는 날에만 결과가 달라지면 아무도 못 잡는다.
	var tuning := _tuning()
	var expected := SimScript.run_items(_items(8), tuning)

	var lumpy := BoutScript.new(_items(8), tuning)
	lumpy.start()
	# 타 간격보다 긴 프레임을 일부러 준다.
	for _frame in 200:
		if not lumpy.is_running():
			break
		lumpy.tick(tuning.seconds_per_hit * 2.7)

	assert_eq(lumpy.landed(), 8, "타가 사라지면 안 된다")
	assert_almost_eq(lumpy.peak(), expected.peak, 0.5, "프레임이 튀어도 결과가 같아야 한다")


# ---------------------------------------------------------------- 눈금이 빠지는 것이 보인다


func test_the_gauge_drains_after_the_last_hit() -> void:
	var tuning := _tuning(20.0)
	var bout := BoutScript.new(_items(6), tuning)
	bout.start()
	# **마지막 타가 떨어진 직후**에 재야 한다. 더 돌리면 이미 다 빠진 뒤라
	# "안 빠졌다" 와 "다 빠졌다" 를 구분 못 한다.
	for _frame in 6000:
		if bout.landed() >= bout.total_hits():
			break
		bout.tick(1.0 / 240.0)
	var at_end := bout.gauge_value()
	assert_true(at_end > 0.0, "다 친 직후에는 눈금이 차 있어야 한다")

	_run_to_end(bout)
	assert_true(bout.gauge_value() < at_end, "다 친 뒤에는 눈금이 빠진다")
	assert_true(bout.peak() >= at_end, "최고 기록은 안 빠진다")


func test_a_bout_finishes() -> void:
	var bout := BoutScript.new(_items(4), _tuning())
	bout.start()
	_run_to_end(bout)
	assert_eq(bout.phase(), SparringBout.Phase.DONE)
	assert_false(bout.is_running())


func test_finished_fires_once() -> void:
	var bout := BoutScript.new(_items(3), _tuning())
	watch_signals(bout)
	bout.start()
	_run_to_end(bout)
	assert_signal_emit_count(bout, "finished", 1)


func test_every_hit_is_announced() -> void:
	var bout := BoutScript.new(_items(5), _tuning())
	watch_signals(bout)
	bout.start()
	_run_to_end(bout)
	assert_signal_emit_count(bout, "hit_landed", 5)


func test_an_empty_chain_finishes_immediately() -> void:
	var bout := BoutScript.new([] as Array[BackpackItem], _tuning())
	bout.start()
	assert_eq(bout.phase(), SparringBout.Phase.DONE)
	assert_eq(bout.total_hits(), 0)


# ---------------------------------------------------------------- 백팩에서 곧바로


func test_a_bout_can_be_built_from_a_backpack_chain() -> void:
	var grid := GridScript.new(5, 5, [Vector2i(0, 0)] as Array[Vector2i])
	grid.place(_pip("a"), Vector2i(0, 0))
	grid.place(_pip("b"), Vector2i(1, 0))
	grid.place(_pip("c"), Vector2i(2, 0))
	var chain := ChainResolver.resolve_from(grid, Vector2i(0, 0))

	var bout := BoutScript.from_chain(chain, _tuning())
	assert_eq(bout.total_hits(), chain.length(), "체인 길이만큼 친다")
	bout.start()
	_run_to_end(bout)
	assert_eq(bout.landed(), chain.length())


func test_restarting_clears_the_previous_run() -> void:
	var bout := BoutScript.new(_items(5), _tuning())
	bout.start()
	_run_to_end(bout)
	var first_peak := bout.peak()
	bout.start()
	assert_eq(bout.landed(), 0, "다시 시작하면 처음부터다")
	assert_eq(bout.gauge_value(), 0.0)
	assert_eq(bout.peak(), 0.0, "최고 기록도 초기화된다")
	assert_true(first_peak > 0.0, "전제 확인")
