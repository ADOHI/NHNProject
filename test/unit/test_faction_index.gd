extends GutTest
## 소속 크기와 순위를 덮는다.
##
## 화면에 번호만 적으면 지프 분포가 안 읽힌다 —
## `#12` 와 `#61` 이 같은 무게로 보인다 (docs/design/24-npc-relations.md §24.17.6).
## **인원과 순위가 그 무게를 만든다.**

const _SEED := 20260808


func _traits() -> PackedInt32Array:
	var packed := PackedInt32Array()
	for _axis in NpcAxis.count():
		packed.append(0)
	return packed


## 소속 배치를 그대로 지정한 인구. 생성기를 쓰면 무엇이 몇 명인지 시험이 모른다.
func _world(factions: Array) -> PersonRegistry:
	var registry := PersonRegistry.new()
	for slot in factions.size():
		registry.add(
			"표본%d" % slot, MemberDiscipline.Kind.COMBAT, 1, 1, int(factions[slot]), 0, _traits()
		)
	return registry


func test_counts_members_per_faction() -> void:
	var index := FactionIndex.new(_world([0, 0, 0, 1, 2, 2]))
	assert_eq(index.size_of(0), 3)
	assert_eq(index.size_of(1), 1)
	assert_eq(index.size_of(2), 2)


func test_unaffiliated_are_not_counted() -> void:
	var index := FactionIndex.new(_world([0, PersonRegistry.NO_FACTION, 0]))
	assert_eq(index.size_of(0), 2)
	assert_eq(index.size_of(PersonRegistry.NO_FACTION), 0)


func test_ranks_run_from_largest() -> void:
	var index := FactionIndex.new(_world([0, 1, 1, 2, 2, 2]))
	assert_eq(index.rank_of(2), 1, "가장 큰 소속이 1위")
	assert_eq(index.rank_of(1), 2)
	assert_eq(index.rank_of(0), 3)


func test_empty_factions_have_no_rank() -> void:
	# 번호가 비어 있는 소속이 순위를 차지하면 분모가 거짓이 된다.
	var index := FactionIndex.new(_world([0, 2]))
	assert_eq(index.rank_of(1), 0)
	assert_eq(index.populated_count(), 2)


func test_ties_fall_back_to_number() -> void:
	# 순위가 부를 때마다 달라지면 화면이 깜빡인다.
	var index := FactionIndex.new(_world([0, 1]))
	assert_eq(index.rank_of(0), 1)
	assert_eq(index.rank_of(1), 2)


func test_largest_size_is_the_bar_reference() -> void:
	var index := FactionIndex.new(_world([0, 0, 0, 1]))
	assert_eq(index.largest_size(), 3)


func test_describe_carries_number_size_and_rank() -> void:
	var index := FactionIndex.new(_world([0, 0, 1]))
	var text := index.describe(0)
	assert_string_contains(text, "#0")
	assert_string_contains(text, "2명")
	assert_string_contains(text, "1/2")


func test_describe_names_unaffiliated() -> void:
	assert_eq(FactionIndex.new(_world([0])).describe(PersonRegistry.NO_FACTION), "무소속")


func test_empty_world_does_not_break() -> void:
	var index := FactionIndex.new(PersonRegistry.new())
	assert_eq(index.populated_count(), 0)
	assert_eq(index.largest_size(), 0)
	assert_eq(index.size_of(0), 0)


func test_generated_world_spreads_by_zipf() -> void:
	# §24.16.5 의 지프 분포가 실제로 크기 차를 만드는지 — 이 열람기가 보여줄 것이 그것이다.
	var registry := PersonGenerator.new(_SEED, 3000).generate()
	var index := FactionIndex.new(registry)
	assert_gt(index.populated_count(), 1)
	var smallest := index.largest_size()
	for faction in index.populated_count():
		if index.rank_of(faction) > 0:
			smallest = mini(smallest, index.size_of(faction))
	assert_gt(index.largest_size(), smallest * 3, "대형 소속과 잔챙이가 갈려야 한다")
