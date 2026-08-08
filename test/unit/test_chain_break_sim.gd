extends GutTest
## **긴 체인이 짧은 체인보다 무엇이 나은가** — 그 답이 여기 있다.
##
## `docs/design/28-combat.md` §28.5.
##
## 그 전까지 체인은 길이만 있고 결과가 없었다. 이 파일이 지키는 것은
## **길이가 상태 변화로 바뀐다**는 것이다.

const SimScript := preload("res://src/core/combat/chain_break_sim.gd")
const TuningScript := preload("res://src/core/combat/break_tuning.gd")
const ItemScript := preload("res://src/core/combat/backpack_item.gd")
const GridScript := preload("res://src/core/combat/backpack_grid.gd")


func _tuning(decay: float = 20.0) -> BreakTuning:
	return TuningScript.new(decay)


func _pip(id: String, direction: ChainDirection.Kind) -> BackpackItem:
	return ItemScript.new(
		id, id, BackpackItem.Kind.WEAPON, [Vector2i(0, 0)], Vector2i(0, 0), direction
	)


func _items(count: int) -> Array[BackpackItem]:
	var items: Array[BackpackItem] = []
	for index in count:
		items.append(_pip("w%d" % index, ChainDirection.Kind.RIGHT))
	return items


# ---------------------------------------------------------------- 길이가 값을 한다


func test_a_longer_chain_reaches_a_worse_state() -> void:
	# **이 테스트가 「10타가 왜 좋은가」를 지킨다.**
	var tuning := _tuning()
	var short_chain := SimScript.run_items(_items(2), tuning)
	var long_chain := SimScript.run_items(_items(10), tuning)
	assert_true(long_chain.peak > short_chain.peak, "긴 체인이 눈금을 더 올린다")
	assert_true(BreakState.is_worse(long_chain.highest, short_chain.highest), "긴 체인이 더 심하게 무너뜨린다")


func test_one_hit_does_not_break_anything() -> void:
	var outcome := SimScript.run_items(_items(1), _tuning())
	assert_eq(outcome.hits(), 1)
	assert_eq(outcome.highest, BreakState.Kind.NONE, "한 대로는 안 무너진다")


func test_empty_chain_does_nothing() -> void:
	var outcome := SimScript.run_items([] as Array[BackpackItem], _tuning())
	assert_eq(outcome.hits(), 0)
	assert_eq(outcome.peak, 0.0)
	assert_eq(outcome.highest, BreakState.Kind.NONE)
	assert_eq(outcome.summary_line(), "친 것이 없다")


func test_it_records_every_hit() -> void:
	var outcome := SimScript.run_items(_items(5), _tuning())
	assert_eq(outcome.values.size(), 5)
	assert_eq(outcome.states.size(), 5, "타마다 눈금과 단계가 함께 남는다")


# ---------------------------------------------------------------- 몇 타부터인가


func test_it_reports_which_hit_first_reached_a_state() -> void:
	var outcome := SimScript.run_items(_items(12), _tuning())
	var step := outcome.first_step_reaching(BreakState.Kind.STAGGER)
	assert_true(step > 0, "경직에 닿은 타 번호를 알려 준다")
	assert_true(outcome.values[step - 1] >= _tuning().stagger_at, "그 타에서 실제로 문턱을 넘었어야 한다")


func test_a_state_never_reached_reports_minus_one() -> void:
	var outcome := SimScript.run_items(_items(1), _tuning())
	assert_eq(outcome.first_step_reaching(BreakState.Kind.KNOCKDOWN), -1)


func test_reached_answers_by_severity() -> void:
	var outcome := SimScript.run_items(_items(10), _tuning())
	assert_true(outcome.reached(BreakState.Kind.NONE), "더 심한 데까지 갔으면 그 아래도 지난 것이다")
	assert_true(outcome.reached(outcome.highest))


# ---------------------------------------------------------------- 빠짐 속도가 전부를 정한다


func test_faster_decay_makes_the_same_chain_weaker() -> void:
	var slow := SimScript.run_items(_items(8), _tuning(0.0))
	var fast := SimScript.run_items(_items(8), _tuning(200.0))
	assert_true(slow.peak > fast.peak, "빨리 빠지면 같은 체인도 덜 무너뜨린다")


func test_with_no_decay_hits_simply_accumulate() -> void:
	var tuning := _tuning(0.0)
	var outcome := SimScript.run_items(_items(3), tuning)
	var one_hit := tuning.poise_for(_pip("x", ChainDirection.Kind.RIGHT))
	assert_almost_eq(outcome.peak, one_hit * 3.0, 0.001)


func test_very_fast_decay_stops_a_chain_from_ever_building() -> void:
	# 눈금이 한 타 사이에 다 빠지면 체인이 이어질 이유가 없어진다.
	var outcome := SimScript.run_items(_items(20), _tuning(100000.0))
	assert_eq(outcome.highest, BreakState.Kind.NONE, "아무리 쳐도 안 쌓인다")


func test_the_last_hit_is_not_followed_by_decay() -> void:
	# 체인이 끝난 순간의 눈금이 그 체인의 성과다.
	var tuning := _tuning(0.0)
	var outcome := SimScript.run_items(_items(2), tuning)
	var one_hit := tuning.poise_for(_pip("x", ChainDirection.Kind.RIGHT))
	assert_almost_eq(outcome.values[1], one_hit * 2.0, 0.001)


# ---------------------------------------------------------------- 백팩과 이어진다


func test_a_chain_from_the_grid_runs_through_the_gauge() -> void:
	var grid := GridScript.new(5, 5, [Vector2i(0, 0)] as Array[Vector2i])
	grid.place(_pip("a", ChainDirection.Kind.RIGHT), Vector2i(0, 0))
	grid.place(_pip("b", ChainDirection.Kind.RIGHT), Vector2i(1, 0))
	grid.place(_pip("c", ChainDirection.Kind.RIGHT), Vector2i(2, 0))

	var chain := ChainResolver.resolve_from(grid, Vector2i(0, 0))
	var outcome := SimScript.run(chain, _tuning())
	assert_eq(outcome.hits(), chain.length(), "체인 길이만큼 친다")
	assert_true(outcome.peak > 0.0)


func test_rearranging_the_backpack_changes_the_outcome() -> void:
	# **배치 -> 체인 -> 무너짐** 이 한 줄로 이어진다는 것.
	var grid := GridScript.new(5, 5, [Vector2i(0, 0)] as Array[Vector2i])
	grid.place(_pip("a", ChainDirection.Kind.RIGHT), Vector2i(0, 0))
	grid.place(_pip("b", ChainDirection.Kind.RIGHT), Vector2i(1, 0))
	var moved := grid.place(_pip("c", ChainDirection.Kind.RIGHT), Vector2i(2, 0))

	var before := SimScript.run(ChainResolver.resolve_from(grid, Vector2i(0, 0)), _tuning())
	assert_true(grid.move(moved, Vector2i(4, 4)), "루트에서 하나를 빼낸다")
	var after := SimScript.run(ChainResolver.resolve_from(grid, Vector2i(0, 0)), _tuning())

	assert_true(after.peak < before.peak, "배치를 흐트러뜨리면 덜 무너뜨린다")
