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


## 1칸 무기 한 번 휘두르는 데 걸리는 시간. 테스트가 상수를 따로 안 적는다.
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
	assert_eq(bout.landed(), 0, "휘두르는 시간이 지나야 닿는다")

	bout.tick(_strike(tuning))
	assert_eq(bout.landed(), 1, "한 번 휘두른 만큼 지나면 첫 타가 닿는다")

	# **다음 타까지는 휘두르는 시간 + 히트스톱이다.** 멈춰 있는 동안 일정도 선다.
	bout.tick(_strike(tuning) + tuning.hitstop_seconds_for(_sized(1)))
	assert_eq(bout.landed(), 2)


func test_hits_do_not_all_land_at_once() -> void:
	var tuning := _tuning()
	var bout := BoutScript.new(_items(6), tuning)
	bout.start()
	bout.tick((_strike(tuning) + tuning.hitstop_seconds_for(_sized(1))) * 3.5)
	assert_true(bout.landed() < 6, "한 번에 다 나가면 실시간이 아니다")
	assert_eq(bout.landed(), 3)


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
		lumpy.tick(_strike(tuning) * 2.7)

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


# ---------------------------------------------------------------- 닿지 않는다


func _reaching_field(gap: float) -> SparringField:
	return SparringField.new(0.0, gap)


func test_a_chain_stops_when_the_weapon_cannot_reach() -> void:
	# **백팩에서는 이어지는데 필드에서 못 나간다.** 격자 이유와 다른 층이다.
	var far := _reaching_field(400.0)
	var bout := BoutScript.new(_items(5), _tuning(), far)
	bout.start()
	_run_to_end(bout)
	assert_eq(bout.landed(), 0, "한 대도 못 닿는다")
	assert_true(bout.was_out_of_reach())
	assert_eq(bout.stop_reason(), SparringBout.Stop.OUT_OF_REACH)


func test_a_chain_completes_when_in_range() -> void:
	var close := _reaching_field(60.0)
	var bout := BoutScript.new(_items(5), _tuning(), close)
	bout.start()
	_run_to_end(bout)
	assert_eq(bout.landed(), 5)
	assert_eq(bout.stop_reason(), SparringBout.Stop.COMPLETED)
	assert_false(bout.was_out_of_reach())


func test_without_a_field_there_is_no_distance_judgement() -> void:
	# 눈금만 보던 옛 사용처가 그대로 돌아야 한다.
	var bout := BoutScript.new(_items(4), _tuning())
	bout.start()
	_run_to_end(bout)
	assert_eq(bout.landed(), 4)
	assert_false(bout.was_out_of_reach())


func test_staying_forward_closes_the_gap_while_it_lands() -> void:
	# 닿는 거리 안에서 시작하면 때릴 때마다 파고든다.
	var field := _reaching_field(100.0)
	field.advance_mode = SparringField.AdvanceMode.STAY
	var bout := BoutScript.new(_items(6), _tuning(), field)
	bout.start()
	_run_to_end(bout)
	assert_eq(bout.landed(), 6, "닿는 데서 시작하면 계속 닿는다")
	assert_true(field.gap() < 100.0, "간격이 줄어 있어야 한다")


func test_out_of_reach_can_never_close_by_itself() -> void:
	# **전진은 때려야 생긴다.** 그래서 못 닿으면 영영 못 붙는다 —
	# 붙는 것은 이 대련장 밖(§28.4 의 RTS 자동 이동)의 일이다.
	var field := _reaching_field(140.0)
	field.advance_mode = SparringField.AdvanceMode.STAY
	var bout := BoutScript.new(_items(12), _tuning(), field)
	bout.start()
	_run_to_end(bout)
	assert_eq(bout.landed(), 0)
	assert_eq(field.gap(), 140.0, "한 발짝도 못 나간다")
	assert_true(bout.was_out_of_reach())


func test_a_long_weapon_opens_where_a_short_one_cannot() -> void:
	# **큰 무기가 받는 값은 「멀리서 시작할 수 있다」다.**
	var gap := 112.0
	var dagger := BoutScript.new(_items(3), _tuning(), _reaching_field(gap))
	var long_blade: Array[BackpackItem] = [_sized(4), _sized(4), _sized(4)]
	var reaching := BoutScript.new(long_blade, _tuning(), _reaching_field(gap))
	dagger.start()
	reaching.start()
	_run_to_end(dagger)
	_run_to_end(reaching)
	assert_eq(dagger.landed(), 0, "단검은 이 거리에서 못 연다")
	assert_true(reaching.landed() > 0, "대검은 같은 거리에서 연다")
