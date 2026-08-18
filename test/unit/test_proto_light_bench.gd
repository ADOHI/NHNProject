extends GutTest
## 측정 도구 자체의 단위 테스트.
##
## **측정 도구가 거짓말하면 그 위의 판단이 전부 무효다.** 이 저장소에서 실제로
## 세 번 일어났다 — 검사기가 `[o]` 를 띄우며 2 위를 1 위라고 찍었고, 매니페스트가
## 무시된 값을 적었고, 이동 레인의 지표가 가지도 않은 거리를 갔다고 셌다.
##
## 그래서 분위수와 「예산 넘침」 판정을 **아는 답으로** 못 박는다.


func _stats_with(values: Array[float]) -> ProtoLightBenchStats:
	var stats := ProtoLightBenchStats.new()
	for v in values:
		stats.add(v, 0.0)
	return stats


func test_empty_is_zero_not_error() -> void:
	var stats := ProtoLightBenchStats.new()
	assert_eq(stats.count(), 0)
	assert_eq(stats.frame_at(0.95), 0.0)


func test_median_and_p95_pick_the_right_sample() -> void:
	var values: Array[float] = []
	for i in 100:
		values.append(float(i + 1))
	var stats := _stats_with(values)
	assert_eq(stats.count(), 100)
	assert_almost_eq(stats.frame_at(0.50), 50.0, 1.5)
	assert_almost_eq(stats.frame_at(0.95), 95.0, 1.5)
	assert_eq(stats.frame_at(1.0), 100.0)


## 순서가 뒤섞여 들어와도 같은 답이어야 한다. 들어온 순서대로 읽으면
## 「95 분위」가 그냥 「95 번째 프레임」이 된다.
func test_order_does_not_matter() -> void:
	var ascending := _stats_with([1.0, 2.0, 3.0, 4.0, 5.0] as Array[float])
	var shuffled := _stats_with([4.0, 1.0, 5.0, 3.0, 2.0] as Array[float])
	assert_eq(ascending.frame_at(0.5), shuffled.frame_at(0.5))
	assert_eq(ascending.frame_at(1.0), shuffled.frame_at(1.0))


## 예산은 16.7ms 다. 경계에서 세는 방향이 틀리면 「넘침 0」이 조용히 나온다.
func test_over_budget_counts_only_above() -> void:
	var stats := _stats_with([16.0, 16.7, 16.8, 40.0] as Array[float])
	assert_eq(stats.over_budget(), 2, "16.7 자체는 넘긴 것이 아니다")


## 넘친 프레임 중 **렌더가 절반 넘게 쓴 것**만 우리 탓이다.
## 프레임이 26 밀리초인데 렌더가 3 밀리초면 남은 23 은 우리가 만든 것이 아니다.
func test_render_heavy_split() -> void:
	var stats := ProtoLightBenchStats.new()
	stats.add(30.0, 1.0)  # 넘쳤지만 렌더는 가볍다 → 남의 탓
	stats.add(30.0, 12.0)  # 넘쳤고 렌더가 무겁다 → 우리 탓
	stats.add(5.0, 12.0)  # 렌더는 무겁지만 프레임은 예산 안이다
	assert_eq(stats.over_budget(), 2)
	assert_eq(stats.over_and_render_heavy(), 1)


func test_reset_clears() -> void:
	var stats := _stats_with([1.0, 2.0] as Array[float])
	stats.reset()
	assert_eq(stats.count(), 0)


## 판 정의에 적지 않은 열은 기본값이 되어야 한다. **같은 기본값을 판마다 되풀이해
## 적으면 언젠가 하나가 어긋난다** — 그래서 기본값이 한 곳에만 있는지 확인한다.
func test_plan_defaults_fill_missing_columns() -> void:
	var bare := {"lights": 1}
	assert_eq(ProtoLightBenchPlan.value(bare, "occluders"), 8)
	assert_eq(ProtoLightBenchPlan.value(bare, "layers"), 1)
	assert_eq(ProtoLightBenchPlan.value({"layers": 6}, "layers"), 6)


## 판이 **싼 것부터** 늘어서 있어야 한다. 웹은 데워진 정도가 배수를 만들므로
## 비싼 판을 먼저 돌리면 뒤의 싼 판이 데워진 상태에서 재어진다.
func test_stages_are_ordered_cheap_to_expensive() -> void:
	var previous := -1
	for stage in ProtoLightBenchPlan.STAGES:
		var lights: int = stage["lights"]
		assert_true(lights >= previous, "빛 개수가 줄어드는 판이 있으면 안 된다")
		previous = lights
	assert_gt(ProtoLightBenchPlan.STAGES.size(), 3, "판이 최소한 몇 개는 있어야 한다")


## 한 물건에 닿을 수 있는 빛은 16 개다 (`gl_compatibility` 의 `MAX_LIGHTS_PER_ITEM`).
## 그보다 많이 켜는 판을 만들면 조용히 사라지는 빛을 재게 된다.
func test_no_stage_exceeds_the_per_item_light_cap() -> void:
	for stage in ProtoLightBenchPlan.STAGES:
		assert_lte(stage["lights"] as int, 16, "%s 가 상한을 넘는다" % stage["name"])
