extends GutTest
## 다가오는 순서 검증.
##
## 이 게임은 턴제라 타이틀의 중경도 턴제여야 한다. 지켜야 할 것은 둘이고,
## 둘 다 그림이 아니라 **규칙**이라 씬 없이 검사된다 (docs/design/21-title.md §21.4).

const _WATCHERS := 4


func test_one_round_visits_everyone() -> void:
	# 아무도 잊히지 않는다. 난수가 한 명만 계속 고르면 나머지가 굳어 버리고,
	# 그건 "멈춰 있는 사람들" 이 아니라 고장 난 화면으로 보인다.
	var plan := ApproachPlan.new(_WATCHERS, 9)
	var seen := {}
	for _step in _WATCHERS:
		seen[plan.next()] = true
	assert_eq(seen.size(), _WATCHERS, "한 바퀴 안에 전부 한 번씩 움직여야 한다")


func test_never_moves_the_same_one_twice_in_a_row() -> void:
	# 연달아 두 번 움직이면 그 사람만 살아 있는 것으로 보인다.
	var plan := ApproachPlan.new(_WATCHERS, 3)
	var previous := -1
	for _step in _WATCHERS * 8:
		var pick := plan.next()
		assert_ne(pick, previous, "같은 사람이 연달아 움직이면 안 된다")
		previous = pick


func test_rounds_repeat_forever() -> void:
	var plan := ApproachPlan.new(_WATCHERS, 11)
	var tally := {}
	for _step in _WATCHERS * 5:
		var pick := plan.next()
		tally[pick] = int(tally.get(pick, 0)) + 1
	for index in _WATCHERS:
		assert_eq(tally.get(index, 0), 5, "다섯 바퀴면 다섯 번씩이다")


func test_remaining_counts_down_within_a_round() -> void:
	var plan := ApproachPlan.new(_WATCHERS, 5)
	plan.next()
	assert_eq(plan.remaining(), _WATCHERS - 1, "한 명 움직였으면 남은 사람이 하나 줄어든다")


func test_wait_is_long_enough_to_read_as_stillness() -> void:
	# 걸음(0.52초)보다 훨씬 길어야 "재고 있다"로 읽힌다.
	var plan := ApproachPlan.new(_WATCHERS, 7)
	for _step in 40:
		var gap := plan.wait()
		assert_gte(gap, 0.75, "너무 잦으면 달려드는 것으로 보인다")
		assert_lte(gap, 2.3, "너무 뜸하면 화면이 죽는다")


func test_wait_is_not_a_metronome() -> void:
	var plan := ApproachPlan.new(_WATCHERS, 13)
	var first := plan.wait()
	var varied := false
	for _step in 12:
		if not is_equal_approx(plan.wait(), first):
			varied = true
	assert_true(varied, "간격이 일정하면 메트로놈이 된다")


func test_same_seed_same_order() -> void:
	var first := ApproachPlan.new(_WATCHERS, 42)
	var second := ApproachPlan.new(_WATCHERS, 42)
	for _step in 12:
		assert_eq(first.next(), second.next(), "같은 시드는 같은 순서다")


func test_empty_plan_picks_nobody() -> void:
	assert_eq(ApproachPlan.new(0, 1).next(), -1, "아무도 없으면 고를 것도 없다")


func test_single_watcher_always_picks_itself() -> void:
	# 한 명뿐이면 "연달아 금지" 규칙보다 "아무도 잊지 않기" 가 우선이다.
	var plan := ApproachPlan.new(1, 2)
	for _step in 5:
		assert_eq(plan.next(), 0, "한 명뿐이면 그 사람이 움직인다")
