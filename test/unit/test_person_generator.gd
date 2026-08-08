extends GutTest
## 인물 절차 생성을 덮는다.
##
## 여기서 지켜야 할 것은 셋이다 (docs/design/24-npc-relations.md §24.16) —
##
## 1. **같은 시드면 같은 세계.** 재현이 안 되면 이상한 세계를 다시 볼 수 없다
## 2. **나눠 돌려도 같은 세계.** 웹 단일 스레드라 언젠가 나눠 돌려야 하는데,
##    그때 결과가 달라지면 분할이 기능 변경이 된다
## 3. **이름이 겹치지 않는다.** 겹치면 §24.2 의 「기억되는 인물」이 죽는다

## 규모 감각을 재는 인구. 3000명 전체는 도구가 잰다 (tools/survey_npc_population.gd).
const _POPULATION := 600

const _SEED := 20260808


func _generate(population: int = _POPULATION, seed_value: int = _SEED) -> PersonRegistry:
	return PersonGenerator.new(seed_value, population).generate()


## 세계 하나를 문자열 목록으로 굳힌다. 두 세계가 같은지 비교하는 유일한 기준이다.
##
## Packed 배열이 아니라 Array 로 돌려준다 — GUT 의 깊은 비교가 어느 인물에서
## 갈렸는지 알려 주고, 그게 없으면 "다르다" 만 알고 원인을 못 찾는다.
func _fingerprint(registry: PersonRegistry) -> Array[String]:
	var lines: Array[String] = []
	for person in registry.size():
		lines.append(registry.summary_of(person))
	return lines


# ---------------------------------------------------------------- 규모


func test_generates_the_requested_population() -> void:
	assert_eq(_generate().size(), _POPULATION)


func test_zero_population_is_allowed() -> void:
	# 세계 없이 화면을 여는 경로가 생기면 여기서 터지지 않아야 한다.
	assert_eq(_generate(0).size(), 0)


func test_every_person_has_every_axis() -> void:
	var registry := _generate()
	for person in registry.size():
		assert_eq(registry.traits_of(person).size(), NpcAxis.count())


func test_stats_stay_usable() -> void:
	# 전투력 0 인 대원은 스쿼드 합(docs/design/14-squad.md §14.3)에 아무것도 더하지 않는다.
	var registry := _generate()
	for person in registry.size():
		assert_gt(registry.threat_of(person), 0)
		assert_gt(registry.agility_of(person), 0)


func test_stats_stay_near_the_discipline_baseline() -> void:
	# 계열 기본값을 베끼지 않고 MemberDiscipline 에 물어본다 — 상수를 복제하면
	# 계열 밸런스를 고쳤을 때 세계만 옛 수치로 남는다.
	var registry := _generate()
	for person in registry.size():
		var kind := registry.discipline_of(person)
		var gap := absi(registry.threat_of(person) - MemberDiscipline.base_threat(kind))
		assert_lte(gap, PersonGenerator.STAT_SPREAD, "전투력이 계열에서 너무 멀다")


func test_all_disciplines_appear() -> void:
	var registry := _generate()
	var seen := {}
	for person in registry.size():
		seen[int(registry.discipline_of(person))] = true
	assert_eq(seen.size(), MemberDiscipline.count())


# ---------------------------------------------------------------- 이름


func test_names_never_repeat() -> void:
	var registry := _generate()
	var seen := {}
	for person in registry.size():
		var name := registry.name_of(person)
		assert_false(seen.has(name), "이름이 겹치면 기사에서 누구 얘기인지 알 수 없다")
		seen[name] = true


func test_names_never_fall_back() -> void:
	# 「무명 N」 이 나오면 이름 풀이 인구를 못 감당한다는 신호다.
	var registry := _generate()
	for person in registry.size():
		assert_false(registry.name_of(person).begins_with("무명 "))


func test_name_capacity_covers_the_target_population() -> void:
	# docs/design/24-npc-relations.md §24.8 의 상한이 3000명이다.
	assert_true(PersonGenerator.new(_SEED, 3000).has_name_capacity())


# ---------------------------------------------------------------- 소속과 유명세


func test_faction_count_scales_with_population() -> void:
	var generator := PersonGenerator.new(_SEED, 3000)
	assert_eq(generator.faction_count(), 3000 / PersonGenerator.PEOPLE_PER_FACTION)


func test_tiny_population_still_has_one_faction() -> void:
	assert_eq(PersonGenerator.new(_SEED, 3).faction_count(), 1)


func test_factions_stay_in_range() -> void:
	var generator := PersonGenerator.new(_SEED, _POPULATION)
	var registry := generator.generate()
	for person in registry.size():
		var faction := registry.faction_of(person)
		if faction == PersonRegistry.NO_FACTION:
			continue
		assert_between(faction, 0, generator.faction_count() - 1)


func test_some_people_belong_nowhere() -> void:
	# §24.2 의 "기본은 모르는 사이" 와 같은 이유다 — 아무 데도 안 걸린 사람이 있어야
	# 소속이 뜻을 갖는다.
	var registry := _generate()
	var loose := 0
	for person in registry.size():
		if registry.faction_of(person) == PersonRegistry.NO_FACTION:
			loose += 1
	assert_gt(loose, 0)
	assert_lt(loose, registry.size(), "전원이 무소속이면 소속이 없는 것과 같다")


func test_faction_sizes_are_uneven() -> void:
	# 크기가 고르면 다음 덩어리에서 관계 덩어리가 전부 같은 크기로 나온다 (§24.16.5).
	var registry := PersonGenerator.new(_SEED, 3000).generate()
	var sizes := {}
	for person in registry.size():
		var faction := registry.faction_of(person)
		if faction != PersonRegistry.NO_FACTION:
			sizes[faction] = int(sizes.get(faction, 0)) + 1
	var smallest := 999999
	var largest := 0
	for faction in sizes:
		smallest = mini(smallest, int(sizes[faction]))
		largest = maxi(largest, int(sizes[faction]))
	assert_gt(largest, smallest * 3, "대형 소속과 잔챙이가 갈려야 한다")


func test_most_people_are_unknown() -> void:
	# §24.7 — "무명인 사람 얘기는 아무도 보지 않는다". 유명세가 고르게 퍼지면
	# 렉카의 기사 선정이 아무 일도 하지 않는다.
	var registry := _generate()
	var known := 0
	for person in registry.size():
		assert_between(registry.fame_of(person), 0, PersonGenerator.FAME_MAX)
		if registry.fame_of(person) >= 50:
			known += 1
	assert_lt(float(known) / float(registry.size()), 0.25, "유명한 사람이 흔하면 유명세가 뜻이 없다")


# ---------------------------------------------------------------- 결정론


func test_same_seed_gives_the_same_world() -> void:
	assert_eq(_fingerprint(_generate()), _fingerprint(_generate()))


func test_different_seed_gives_a_different_world() -> void:
	assert_ne(_fingerprint(_generate()), _fingerprint(_generate(_POPULATION, _SEED + 1)))


func test_split_generation_gives_the_same_world() -> void:
	# 웹은 단일 스레드다. 나눠 돌리는 것이 기능 변경이 되면 안 된다 (§24.16.2).
	var registry := PersonRegistry.new()
	var generator := PersonGenerator.new(_SEED, _POPULATION)
	var rounds := 0
	while not generator.append_to(registry, 37):
		rounds += 1
		assert_lt(rounds, _POPULATION, "조각 생성이 끝나지 않는다")
	assert_gt(rounds, 1, "실제로 여러 조각으로 나뉘어야 하는 시험이다")
	assert_eq(_fingerprint(registry), _fingerprint(_generate()))


func test_progress_is_visible_while_splitting() -> void:
	var generator := PersonGenerator.new(_SEED, _POPULATION)
	assert_eq(generator.made(), 0)
	generator.append_to(PersonRegistry.new(), 10)
	assert_eq(generator.made(), 10)
	assert_eq(generator.population(), _POPULATION)


func test_append_stops_at_the_target_population() -> void:
	var registry := PersonRegistry.new()
	var generator := PersonGenerator.new(_SEED, 5)
	assert_true(generator.append_to(registry, 500), "목표를 넘겨 달라고 해도 끝나야 한다")
	assert_eq(registry.size(), 5)
