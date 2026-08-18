extends GutTest
## 무너짐 눈금 — **차오르고 시간이 지나면 빠지는가.**
##
## `docs/design/28-combat.md` §28.5.
##
## **여기 수치는 확정이 아니다** (§28.8 「무너짐 회복」은 미정). 그래서 특정 값이
## 나오는지가 아니라 **성질**을 본다 — 차오르는가, 빠지는가, 단계가 순서대로인가.

const GaugeScript := preload("res://src/core/combat/break_gauge.gd")
const TuningScript := preload("res://src/core/combat/break_tuning.gd")
const ItemScript := preload("res://src/core/combat/backpack_item.gd")


func _tuning(decay: float = 20.0) -> BreakTuning:
	return TuningScript.new(decay)


func _item(cells: int) -> BackpackItem:
	var shape: Array[Vector2i] = []
	for index in cells:
		shape.append(Vector2i(index, 0))
	return ItemScript.new(
		"w%d" % cells,
		"무기%d" % cells,
		BackpackItem.Kind.WEAPON,
		shape,
		Vector2i(0, 0),
		ChainDirection.Kind.RIGHT
	)


# ---------------------------------------------------------------- 차오른다


func test_hits_fill_the_gauge() -> void:
	var gauge := GaugeScript.new(_tuning())
	assert_eq(gauge.value(), 0.0)
	gauge.add(10.0)
	assert_eq(gauge.value(), 10.0)
	gauge.add(5.0)
	assert_eq(gauge.value(), 15.0)


func test_gauge_never_exceeds_its_maximum() -> void:
	var tuning := _tuning()
	var gauge := GaugeScript.new(tuning)
	gauge.add(tuning.max_value * 3.0)
	assert_eq(gauge.value(), tuning.max_value, "상한을 넘지 않는다")


func test_negative_hits_are_ignored() -> void:
	var gauge := GaugeScript.new(_tuning())
	gauge.add(10.0)
	gauge.add(-50.0)
	assert_eq(gauge.value(), 10.0, "때리는 것이 눈금을 내리지는 않는다")


# ---------------------------------------------------------------- 빠진다


func test_time_drains_the_gauge() -> void:
	var gauge := GaugeScript.new(_tuning(20.0))
	gauge.add(50.0)
	gauge.tick(1.0)
	assert_almost_eq(gauge.value(), 30.0, 0.001, "초당 20 이 빠진다")


func test_draining_stops_at_zero() -> void:
	var gauge := GaugeScript.new(_tuning(20.0))
	gauge.add(10.0)
	gauge.tick(100.0)
	assert_eq(gauge.value(), 0.0, "음수로 내려가지 않는다")


func test_zero_decay_keeps_everything() -> void:
	# 안 빠지는 설정도 성립해야 한다 — §28.8 이 회복 여부 자체를 미정으로 뒀다.
	var gauge := GaugeScript.new(_tuning(0.0))
	gauge.add(40.0)
	gauge.tick(10.0)
	assert_eq(gauge.value(), 40.0)


func test_peak_does_not_drain() -> void:
	# 한 번 띄웠는지를 알려면 순간값으로는 부족하다.
	var gauge := GaugeScript.new(_tuning(20.0))
	gauge.add(70.0)
	gauge.tick(10.0)
	assert_eq(gauge.value(), 0.0)
	assert_eq(gauge.peak(), 70.0, "최고 기록은 안 빠진다")
	assert_eq(gauge.peak_state(), BreakState.Kind.LAUNCH)


# ---------------------------------------------------------------- 단계


func test_states_come_in_order_as_the_gauge_fills() -> void:
	var tuning := _tuning()
	var gauge := GaugeScript.new(tuning)
	assert_eq(gauge.state(), BreakState.Kind.NONE)
	gauge.add(tuning.stagger_at)
	assert_eq(gauge.state(), BreakState.Kind.STAGGER)
	gauge.add(tuning.launch_at - tuning.stagger_at)
	assert_eq(gauge.state(), BreakState.Kind.LAUNCH)
	gauge.add(tuning.knockdown_at - tuning.launch_at)
	assert_eq(gauge.state(), BreakState.Kind.KNOCKDOWN)


func test_state_thresholds_are_ordered() -> void:
	var tuning := _tuning()
	assert_true(tuning.stagger_at < tuning.launch_at, "경직이 띄우기보다 앞이다")
	assert_true(tuning.launch_at <= tuning.knockdown_at, "띄우기가 쓰러짐보다 앞이다")


func test_every_state_has_a_label() -> void:
	for kind in BreakState.Kind.values():
		assert_false(BreakState.label(kind).is_empty(), "단계 %d 에 이름이 없다" % kind)


func test_worse_compares_by_meaning() -> void:
	assert_true(BreakState.is_worse(BreakState.Kind.KNOCKDOWN, BreakState.Kind.LAUNCH))
	assert_true(BreakState.is_worse(BreakState.Kind.STAGGER, BreakState.Kind.NONE))
	assert_false(BreakState.is_worse(BreakState.Kind.NONE, BreakState.Kind.STAGGER))
	assert_false(BreakState.is_worse(BreakState.Kind.LAUNCH, BreakState.Kind.LAUNCH))


# ---------------------------------------------------------------- 무기 무게


func test_bigger_weapons_hit_heavier() -> void:
	# 부피가 곧 한 방의 무게다. 큰 무기는 세게 치지만 칸을 먹어 체인을 짧게 만든다.
	var tuning := _tuning()
	var small := tuning.poise_for(_item(1))
	var large := tuning.poise_for(_item(4))
	assert_true(large > small, "큰 무기가 더 무겁다")


func test_hitting_with_an_item_uses_its_weight() -> void:
	var tuning := _tuning()
	var gauge := GaugeScript.new(tuning)
	var item := _item(2)
	gauge.hit_with(item)
	assert_almost_eq(gauge.value(), tuning.poise_for(item), 0.001)


# ---------------------------------------------------------------- 무너진 뒤는 정하지 않는다


func test_gauge_does_not_decide_what_happens_after_knockdown() -> void:
	# §28.8 이 「무너진 뒤 무엇이 되나」를 미정으로 뒀다.
	# 눈금은 알려 줄 뿐 스스로 리셋하거나 상태를 강제하지 않는다.
	var tuning := _tuning()
	var gauge := GaugeScript.new(tuning)
	gauge.add(tuning.knockdown_at)
	assert_eq(gauge.state(), BreakState.Kind.KNOCKDOWN)
	assert_eq(gauge.value(), tuning.knockdown_at, "스스로 0 으로 돌아가지 않는다")
