extends SceneTree
## 나이와 가족 관계도를 눈으로 확인하는 개발 도구.
##
## docs/design/24-npc-relations.md §24.22. **가족이 나이에서 나오므로 둘을 같이 본다** —
## 나이차가 말이 안 되면 가족이 「이유 없는 수치」가 된다.
##
## **수치는 전부 코드의 상수를 읽어서 계산한다.** 베껴 적으면 상수를 고쳤을 때 거짓말한다.
##
##   godot --headless --path . -s res://tools/survey_npc_kin.gd

const _POPULATION := 3000
const _SEED := 20260808
const _CHUNK := 250


func _initialize() -> void:
	var registry := _report_people()
	var graph := _report_kin(registry)
	_report_surnames(registry, graph)
	_report_ages(registry, graph)
	_report_genders(registry, graph)
	_report_dossier(registry, graph)
	quit()


func _report_people() -> PersonRegistry:
	print("== 인구 (%d명, 시드 %d) ==" % [_POPULATION, _SEED])
	var started := Time.get_ticks_usec()
	var registry := PersonGenerator.new(_SEED, _POPULATION).generate()
	print("%-26s %.2f ms" % ["인구 생성", float(Time.get_ticks_usec() - started) / 1000.0])

	var ages := PackedInt32Array()
	var seen := {}
	for person in registry.size():
		ages.append(registry.age_of(person))
		seen[registry.name_of(person)] = true
	ages.sort()
	print("%-26s %d" % ["중복 이름", registry.size() - seen.size()])
	print(
		(
			"%-26s %d / %d / %d / %d"
			% [
				"나이 최소/중위/90%/최대",
				ages[0],
				ages[ages.size() / 2],
				ages[ages.size() * 9 / 10],
				ages[ages.size() - 1],
			]
		)
	)
	print("%-26s %d ~ %d" % ["허용 범위", PersonGenerator.AGE_MIN, PersonGenerator.AGE_MAX])
	_print_age_bands(registry)
	_print_fame_by_age(registry)
	return registry


func _print_age_bands(registry: PersonRegistry) -> void:
	var bands := [20, 25, 30, 35, 40, 50, 99]
	var counts := PackedInt32Array()
	counts.resize(bands.size())
	for person in registry.size():
		for slot in bands.size():
			if registry.age_of(person) < int(bands[slot]):
				counts[slot] += 1
				break
	var text := PackedStringArray()
	for slot in bands.size():
		text.append(
			"~%d %.0f%%" % [int(bands[slot]), 100.0 * float(counts[slot]) / float(registry.size())]
		)
	print("%-26s %s" % ["나이대", " ".join(text)])


## 유명세가 나이를 타는가 (§24.22.4). 젊은 쪽 꼬리가 깎였는지 본다.
func _print_fame_by_age(registry: PersonRegistry) -> void:
	print("\n%-12s %8s %10s %10s" % ["나이대", "인원", "평균 유명세", "50 이상%"])
	var edges := [20, 25, 30, 35, 45, 99]
	var low := PersonGenerator.AGE_MIN
	for edge in edges:
		var count := 0
		var total := 0.0
		var known := 0
		for person in registry.size():
			var age := registry.age_of(person)
			if age < low or age >= int(edge):
				continue
			count += 1
			total += float(registry.fame_of(person))
			if registry.fame_of(person) >= 50:
				known += 1
		if count > 0:
			print(
				(
					"%-12s %8d %10.1f %9.1f%%"
					% [
						"%d~%d" % [low, int(edge) - 1],
						count,
						total / float(count),
						100.0 * float(known) / float(count),
					]
				)
			)
		low = int(edge)


func _report_kin(registry: PersonRegistry) -> RelationGraph:
	print("\n== 태생 관계 ==")
	var graph := RelationGraph.new(registry.size())
	var seeder := KinSeeder.new(_SEED, registry, graph)
	var worst := 0.0
	var total := 0.0
	while true:
		var started := Time.get_ticks_usec()
		var done := seeder.seed_chunk(_CHUNK)
		var spent := float(Time.get_ticks_usec() - started) / 1000.0
		total += spent
		worst = maxf(worst, spent)
		if done:
			break

	var kinds := PackedInt32Array()
	kinds.resize(RelationKind.count())
	var with_kin := 0
	var degrees := PackedInt32Array()
	for person in registry.size():
		var degree := graph.degree_of(person)
		degrees.append(degree)
		if degree > 0:
			with_kin += 1
		for other in graph.targets_of(person):
			kinds[int(graph.kind_of(person, other))] += 1
	degrees.sort()

	print("%-26s %.2f ms (조각 최대 %.2f ms)" % ["가족 심기", total, worst])
	print("%-26s %d" % ["방향 관계 총수", graph.size()])
	print(
		(
			"%-26s %.1f%% (목표 %.0f%%)"
			% [
				"가족이 있는 인물",
				100.0 * float(with_kin) / float(registry.size()),
				100.0 * (KinSeeder.KIN_CHANCE + KinSeeder.MASTER_CHANCE),
			]
		)
	)
	print(
		(
			"%-26s %d / %d / %d"
			% [
				"차수 중위/90%/최대",
				degrees[degrees.size() / 2],
				degrees[degrees.size() * 9 / 10],
				degrees[degrees.size() - 1],
			]
		)
	)
	var text := PackedStringArray()
	for kind in RelationKind.count():
		if kinds[kind] > 0:
			text.append("%s %d" % [RelationKind.label(kind as RelationKind.Kind), kinds[kind]])
	print("%-26s %s" % ["유형", " ".join(text)])
	return graph


## 성이 가족 안에서 같은가, 그리고 성이 같다고 가족인가 (§24.22.7).
func _report_surnames(registry: PersonRegistry, graph: RelationGraph) -> void:
	print("\n== 성 ==")
	var sizes := {}
	for person in registry.size():
		var surname := registry.surname_of(person)
		sizes[surname] = int(sizes.get(surname, 0)) + 1
	var counts := PackedInt32Array()
	for surname in sizes:
		counts.append(int(sizes[surname]))
	counts.sort()
	counts.reverse()

	var mismatched := 0
	var blood := 0
	for slot in graph.size():
		var kind := graph.slot_kind(slot)
		if not RelationKind.shares_surname(kind):
			continue
		blood += 1
		if registry.surname_of(graph.slot_from(slot)) != registry.surname_of(graph.slot_to(slot)):
			mismatched += 1

	print("%-26s %d" % ["성 가짓수", sizes.size()])
	print(
		(
			"%-26s %.1f%% / %.1f%% / %.1f%%"
			% [
				"1위/2위/3위 비율",
				100.0 * float(counts[0]) / float(registry.size()),
				100.0 * float(counts[1]) / float(registry.size()),
				100.0 * float(counts[2]) / float(registry.size()),
			]
		)
	)
	print("%-26s %d / %d" % ["혈연인데 성이 다름", mismatched, blood])
	print("%-26s %d" % ["성 하나가 쓸 이름 수", MemberNames.given_capacity()])
	print("%-26s %d명" % ["가장 흔한 성의 인원", counts[0]])

	# 성이 같다고 가족은 아니다 — 그것이 정보 게임과 맞는다 (§5.7).
	var pairs := 0
	for count in counts:
		pairs += count * (count - 1)
	print("%-26s %.2f%%" % ["같은 성 쌍 중 가족 비율", 100.0 * float(blood) / maxf(float(pairs), 1.0)])


## 나이차가 말이 되는가. **여기가 틀리면 가족이 이유 없는 수치가 된다.**
func _report_ages(registry: PersonRegistry, graph: RelationGraph) -> void:
	print("\n== 나이차 ==")
	print("%-12s %8s %10s %10s %s" % ["유형", "건수", "최소차", "최대차", "규칙"])
	# 사전 리터럴에 enum 키를 쓰면 gdformat 이 넘어진다. 나란한 배열로 둔다.
	var kinds: Array[RelationKind.Kind] = [
		RelationKind.Kind.PARENT, RelationKind.Kind.SIBLING, RelationKind.Kind.MASTER
	]
	var rules := PackedStringArray(
		[
			"%d~%d" % [KinSeeder.PARENT_GAP_MIN, KinSeeder.PARENT_GAP_MAX],
			"0~%d" % KinSeeder.SIBLING_GAP_MAX,
			"%d~%d" % [KinSeeder.MASTER_GAP_MIN, KinSeeder.MASTER_GAP_MAX],
		]
	)
	for index in kinds.size():
		var kind := kinds[index]
		var count := 0
		var low := 999
		var high := 0
		for slot in graph.size():
			if graph.slot_kind(slot) != kind:
				continue
			count += 1
			var gap := absi(
				registry.age_of(graph.slot_to(slot)) - registry.age_of(graph.slot_from(slot))
			)
			low = mini(low, gap)
			high = maxi(high, gap)
		if count > 0:
			print(
				(
					"%-12s %8d %10d %10d %s"
					% [RelationKind.label(kind), count, low, high, rules[index]]
				)
			)


## 성별이 계열마다 쏠렸는가. **초상 레인이 겪은 쏠림이 우리 쪽에도 있으면 안 된다.**
func _report_genders(registry: PersonRegistry, graph: RelationGraph) -> void:
	print("")
	print("== 성별 ==")
	print("%-10s %8s %8s %8s" % ["계열", "남", "여", "여 비율"])
	for kind in MemberDiscipline.count():
		var male := 0
		var female := 0
		for person in registry.size():
			if int(registry.discipline_of(person)) != kind:
				continue
			if registry.gender_of(person) == PersonGender.Kind.FEMALE:
				female += 1
			else:
				male += 1
		var total := maxf(float(male + female), 1.0)
		var row := (
			"%-10s %8d %8d %7.1f%%"
			% [
				MemberDiscipline.label(kind as MemberDiscipline.Kind),
				male,
				female,
				100.0 * float(female) / total,
			]
		)
		print(row)
	# 성이 부계라 부모는 아버지여야 한다 (설계 24.23).
	var mothers := 0
	var parents := 0
	for slot in graph.size():
		if graph.slot_kind(slot) != RelationKind.Kind.PARENT:
			continue
		parents += 1
		if registry.gender_of(graph.slot_to(slot)) != PersonGender.Kind.MALE:
			mothers += 1
	print("%-26s %d / %d" % ["부모인데 남자가 아님", mothers, parents])


## LLM 에 넣을 한 덩어리. **초상 레인이 받을 모양이 이것이다** (§24.22.6).
func _report_dossier(registry: PersonRegistry, graph: RelationGraph) -> void:
	var factions := FactionIndex.new(registry)
	var best := 0
	for person in registry.size():
		if graph.degree_of(person) > graph.degree_of(best):
			best = person
	print("\n== 설정 한 덩어리 (LLM 입력, 인물 %d) ==" % best)
	print(PersonDossier.text(registry, best, factions, graph))
