extends SceneTree
## 사건이 관계를 어떻게 바꾸는지 눈으로 확인하는 개발 도구.
##
## docs/design/24-npc-relations.md §24.21.8 이 *"사건이 붙을 때 판정할 것"* 으로
## 적어 둔 둘을 그대로 낸다 —
##
## 1. **사건 하나를 굴린 전후 표** — 성향이 정반대인 두 목격자와 무색한 사람을 나란히
## 2. **배신의 호감과 유대를 같이** — 호감만 무너지는 것이 한 줄에서 보인다
##
## **수치는 전부 코드의 상수를 읽어서 계산한다.** 베껴 적으면 상수를 고쳤을 때 거짓말한다.
##
##   godot --headless --path . -s res://tools/survey_npc_events.gd

const _POPULATION := 3000
const _SEED := 20260808
const _CHUNK := 250

## 탐침에 쓸 가상 인물의 성향 세기. 극(TraitDistribution.POLE_MIN) 위쪽이다.
const _PROBE_STRENGTH := 90


func _initialize() -> void:
	_report_vectors()
	_report_probe()
	var world := _build_world()
	_report_graph(world)
	_report_labels(world)
	_report_rumors(world)
	_report_asymmetry(world)
	_report_recruit(world)
	_report_person(world)
	quit()


## 사건 셋의 벡터. **극 이름으로 읽는다** — 부호로 내면 읽는 쪽이 축 순서를 알아야 한다.
func _report_vectors() -> void:
	print("== 사건 벡터 (설계 24.21.4) ==")
	print("%-6s %-34s %6s %8s %6s" % ["사건", "성향 벡터", "강도", "대상 호감", "유대"])
	for kind in RelationEvent.count():
		var event := RelationEvent.of(kind as RelationEvent.Kind)
		print(
			(
				"%-6s %-34s %6d %8d %6d"
				% [
					RelationEvent.label(kind as RelationEvent.Kind),
					event.vector_text(),
					event.strength,
					event.target_affinity,
					event.bond_gain,
				]
			)
		)
	_report_axis_use()


## **성향 6축 중 실제로 밟히는 것은 몇인가** (설계 24.36.2).
##
## 축이 인물 화면에 나오는데 아무 사건도 안 건드리면 **그 축은 세계에서 아무 일도 안 한다** —
## 인물마다 값이 있고 LLM 입력에도 실려 가는데 관계는 한 번도 안 움직인다.
## **사건 표만 읽어서는 안 보인다.** 없는 것을 세는 일이라 여기서 세어 준다.
func _report_axis_use() -> void:
	var kinds := PackedInt32Array()
	var share := PackedFloat32Array()
	kinds.resize(NpcAxis.count())
	share.resize(NpcAxis.count())
	var total := 0
	for weight in EventSeeder.KIND_WEIGHTS:
		total += int(weight)

	for kind in RelationEvent.count():
		var event := RelationEvent.of(kind as RelationEvent.Kind)
		for axis in NpcAxis.count():
			if event.axis(axis as NpcAxis.Kind) == 0:
				continue
			kinds[axis] += 1
			share[axis] += float(EventSeeder.KIND_WEIGHTS[kind]) / float(maxi(total, 1))

	print("\n%-12s %8s %10s" % ["축", "밟는 사건", "사건의 비율"])
	for axis in NpcAxis.count():
		print(
			(
				"%-12s %8d %9.0f%%"
				% [NpcAxis.label(axis as NpcAxis.Kind), kinds[axis], 100.0 * share[axis]]
			)
		)


## 사건 하나를 굴린 전후. **성향이 정반대인 목격자 둘과 무색한 사람을 나란히 놓는다.**
##
## 인구에서 고르지 않고 성향을 지어낸 이유는 *"정반대"* 가 정확히 필요해서다 —
## 실제 인구에서 고르면 축 여섯이 어긋난 사람이 걸려 비교가 흐려진다.
func _report_probe() -> void:
	print("\n== 사건 하나의 전후 (목격자 셋) ==")
	print("관여도는 1.0 (제 사람이 당했다) 로 두고 강도만 본다.")
	for kind in RelationEvent.count():
		var event := RelationEvent.of(kind as RelationEvent.Kind)
		print(
			(
				"\n%s — %s (강도 %d)"
				% [
					RelationEvent.label(kind as RelationEvent.Kind),
					event.vector_text(),
					event.strength
				]
			)
		)
		print("%-24s %8s %10s" % ["목격자", "내적", "호감 변화"])
		var probes := [
			["벡터와 같은 쪽", _probe(event, 1)],
			["벡터와 반대 쪽", _probe(event, -1)],
			["무색 (극이 없다)", PackedInt32Array([0, 0, 0, 0, 0, 0])],
		]
		for probe in probes:
			var traits: PackedInt32Array = probe[1]
			var alignment := event.alignment(traits)
			print(
				(
					"%-24s %8.2f %10d"
					% [str(probe[0]), alignment, roundi(alignment * float(event.strength))]
				)
			)


## 사건 벡터를 그대로 따르는(또는 거스르는) 성향. 건드리지 않는 축은 0 이다.
func _probe(event: RelationEvent, sign: int) -> PackedInt32Array:
	var traits := PackedInt32Array()
	for axis in NpcAxis.count():
		var value := event.axis(axis as NpcAxis.Kind)
		traits.append(0 if value == 0 else sign * signi(value) * _PROBE_STRENGTH)
	return traits


## 인구 · 태생 관계 · 사건까지 세운 세계 하나.
##
## **조각으로 돌린다.** 화면이 그렇게 하고 있고, 조각마다 걸린 시간을 재야
## 프레임 예산 판정이 거짓말을 안 한다 (설계 24.16.2).
func _build_world() -> Array:
	print("\n== 세계 (%d명, 시드 %d) ==" % [_POPULATION, _SEED])
	var world := NpcWorld.new(_SEED, _POPULATION)
	var worst := 0.0
	var total := 0.0
	var inborn := 0
	while true:
		var started := Time.get_ticks_usec()
		var done := world.build_chunk()
		var spent := float(Time.get_ticks_usec() - started) / 1000.0
		total += spent
		# 사건 단계로 넘어간 직후가 태생 관계만 있는 상태다.
		if inborn == 0 and world.stage() == NpcWorld.Stage.EVENTS:
			inborn = world.graph.size()
		if world.stage() == NpcWorld.Stage.EVENTS:
			worst = maxf(worst, spent)
		if done:
			break

	print("%-26s %d" % ["태생 관계 (사건 전)", inborn])
	print("%-26s %d건" % ["굴린 사건", world.ledger.size()])
	print("%-26s %.2f ms" % ["세계 세우기 (전부)", total])
	print("%-26s %.2f ms" % ["사건 조각 %d건 최대" % NpcWorld.EVENT_CHUNK, worst])
	return [world.registry, world.graph, world.ledger, inborn]


func _report_graph(world: Array) -> void:
	var graph: RelationGraph = world[1]
	var ledger: RelationLedger = world[2]
	var inborn: int = world[3]

	var kinds := PackedInt32Array()
	kinds.resize(RelationKind.count())
	var degrees := PackedInt32Array()
	var known := 0
	for person in graph.person_count():
		var degree := graph.degree_of(person)
		degrees.append(degree)
		if degree > 0:
			known += 1
	for slot in graph.size():
		kinds[int(graph.slot_kind(slot))] += 1
	degrees.sort()

	print("%-26s %d (사건이 더한 것 %d)" % ["방향 관계 총수", graph.size(), graph.size() - inborn])
	print("%-26s %.1f%%" % ["관계가 있는 인물", 100.0 * float(known) / float(graph.person_count())])
	print(
		(
			"%-26s %d / %d / %d / %d"
			% [
				"차수 중위/90%/99%/최대",
				degrees[degrees.size() / 2],
				degrees[degrees.size() * 9 / 10],
				degrees[degrees.size() * 99 / 100],
				degrees[degrees.size() - 1],
			]
		)
	)
	var text := PackedStringArray()
	for kind in RelationKind.count():
		if kinds[kind] > 0:
			text.append("%s %d" % [RelationKind.label(kind as RelationKind.Kind), kinds[kind]])
	print("%-26s %s" % ["유형", " ".join(text)])

	var rolled := PackedInt32Array()
	rolled.resize(RelationEvent.count())
	for cause in ledger.size():
		rolled[int(ledger.kind_of(cause))] += 1
	var mix := PackedStringArray()
	for kind in RelationEvent.count():
		mix.append("%s %d" % [RelationEvent.label(kind as RelationEvent.Kind), rolled[kind]])
	print("%-26s %s" % ["사건 종류", " ".join(mix)])


## **사건 수와 화면에 뜨는 딱지 수가 왜 다른가** (설계 24.36.5).
##
## 「동료 유기가 너무 드물다」를 가중치 탓으로 읽으면 가중치를 올려도 딱지가 안 는다.
## 진짜 원인은 **태생 관계는 유형이 안 바뀌는 것**이다 (설계 24.18) —
## 사건이 가족을 대상으로 고르면 「유기당함」이 아니라 「형제」로 남는다.
##
## 그러므로 **사건마다 「굴린 수」와 「딱지가 남은 수」를 같이 내야** 어느 쪽인지 갈린다.
func _report_labels(world: Array) -> void:
	var graph: RelationGraph = world[1]
	var ledger: RelationLedger = world[2]

	print("\n== 사건이 남긴 딱지 (설계 24.36.5) ==")
	print("%-10s %8s %10s %10s" % ["사건", "굴린 수", "태생에 떨어짐", "딱지가 남음"])
	var rolled := PackedInt32Array()
	var onto_inborn := PackedInt32Array()
	var kept := PackedInt32Array()
	rolled.resize(RelationEvent.count())
	onto_inborn.resize(RelationEvent.count())
	kept.resize(RelationEvent.count())

	for cause in ledger.size():
		var kind := ledger.kind_of(cause)
		rolled[int(kind)] += 1
		var wanted := RelationEvent.of(kind).target_kind
		if wanted == RelationKind.Kind.NONE:
			continue
		for target in ledger.targets_of(cause):
			var got := graph.kind_of(target, ledger.actor_of(cause))
			if RelationKind.is_inborn(got):
				onto_inborn[int(kind)] += 1
			elif got == wanted:
				kept[int(kind)] += 1

	for kind in RelationEvent.count():
		if rolled[kind] == 0:
			continue
		print(
			(
				"%-10s %8d %10d %10d"
				% [
					RelationEvent.label(kind as RelationEvent.Kind),
					rolled[kind],
					onto_inborn[kind],
					kept[kind],
				]
			)
		)


## **전파가 성김을 죽이지 않았는가** (설계 24.10 · 24.28.3).
##
## **같은 시드로 소문 없는 세계를 하나 더 세워 나란히 놓는다.** 소문이 만든 관계만
## 세면 안 되는 이유가 있다 — 소문이 만든 관계를 **뒤의 사건이 다시 읽어서**
## 누구를 대상으로 고를지가 달라진다. 세계는 되먹임 고리라 한쪽만 봐서는 못 잰다.
func _report_rumors(world: Array) -> void:
	var graph: RelationGraph = world[1]
	var registry: PersonRegistry = world[0]
	var quiet := NpcWorld.create(_SEED, _POPULATION, false)

	print("\n== 전파 1홉 (설계 24.10) ==")
	print(
		(
			"%-26s 감쇠 %.2f  문턱 %d  상한 %d"
			% [
				"설정",
				RelationResolver.RUMOR_DECAY,
				RelationResolver.RUMOR_MARK_MIN,
				RelationResolver.RUMOR_MAX,
			]
		)
	)
	print("\n%-14s %10s %10s %12s %10s" % ["", "관계", "한쪽만", "차수 중위/90%", "최대"])
	_print_sparsity("소문 없음", quiet.graph)
	_print_sparsity("소문 있음", graph)

	var heard := 0
	var strongest := 0
	var famous := 0
	for slot in graph.size():
		if not graph.slot_is_heard(slot):
			continue
		heard += 1
		strongest = maxi(strongest, absi(graph.slot_affinity(slot)))
		if registry.fame_of(graph.slot_to(slot)) >= 50:
			famous += 1
	print("\n%-26s %d" % ["소문이 만든 관계", heard])
	print("%-26s %d" % ["소문 관계의 최대 호감", strongest])
	# 유명세 50 이상은 인구의 7.8% 다 (설계 24.16.9). 그보다 높으면 유명세가 값을 한 것이다.
	print(
		(
			"%-26s %.0f%% (인구에서는 7.8%%)"
			% ["소문의 대상이 유명한 비율", 100.0 * float(famous) / maxf(float(heard), 1.0)]
		)
	)


## 성김 한 줄. **차수가 안 늘어야 설계 24.2 의 예산이 지켜진다.**
func _print_sparsity(label: String, graph: RelationGraph) -> void:
	var one_way := 0
	var degrees := PackedInt32Array()
	for person in graph.person_count():
		degrees.append(graph.degree_of(person))
	for slot in graph.size():
		if not graph.knows(graph.slot_to(slot), graph.slot_from(slot)):
			one_way += 1
	degrees.sort()
	print(
		(
			"%-14s %10d %9.1f%% %6d / %-5d %10d"
			% [
				label,
				graph.size(),
				100.0 * float(one_way) / maxf(float(graph.size()), 1.0),
				degrees[degrees.size() / 2],
				degrees[degrees.size() * 9 / 10],
				degrees[degrees.size() - 1],
			]
		)
	)


## **비대칭이 실제로 생겼는가.** 태생 관계는 늘 양방향이라 사건만이 한쪽 관계를 만든다.
func _report_asymmetry(world: Array) -> void:
	var registry: PersonRegistry = world[0]
	var graph: RelationGraph = world[1]
	var ledger: RelationLedger = world[2]

	print("\n== 비대칭 (설계 24.21.2) ==")
	var one_way := 0
	var betrayals := PackedInt32Array()
	for slot in graph.size():
		var from := graph.slot_from(slot)
		var to := graph.slot_to(slot)
		if not graph.knows(to, from):
			one_way += 1
		if graph.slot_kind(slot) == RelationKind.Kind.BETRAYED:
			betrayals.append(slot)
	print(
		(
			"%-26s %d (%.1f%%)"
			% ["한쪽만 아는 관계", one_way, 100.0 * float(one_way) / maxf(float(graph.size()), 1.0)]
		)
	)

	# 배신 — 호감과 유대를 같이 낸다. **호감만 무너지는 것이 한 줄에서 보인다** (§24.21.8).
	print("\n%-24s %8s %8s %s" % ["배신당한 사람", "호감", "유대", "근거 사건"])
	for slot in betrayals.slice(0, 5):
		var victim := graph.slot_from(slot)
		print(
			(
				"%-24s %8d %8d %s"
				% [
					registry.name_of(victim),
					graph.slot_affinity(slot),
					graph.slot_bond(slot),
					ledger.describe(graph.cause_of(victim, graph.slot_to(slot)), registry),
				]
			)
		)

	# 목격자가 만든 한쪽 관계 — **A 가 B 를 아는데 B 는 A 를 모른다.**
	print("\n%-24s %-24s %8s %8s" % ["아는 쪽", "모르는 쪽", "호감", "유대"])
	var shown := 0
	for slot in graph.size():
		if shown >= 5:
			break
		var kind := graph.slot_kind(slot)
		if kind != RelationKind.Kind.TRUST and kind != RelationKind.Kind.GRUDGE:
			continue
		var from := graph.slot_from(slot)
		var to := graph.slot_to(slot)
		if graph.knows(to, from):
			continue
		shown += 1
		print(
			(
				"%-24s %-24s %8d %8d"
				% [
					"%s (%s)" % [registry.name_of(from), RelationKind.label(kind)],
					registry.name_of(to),
					graph.slot_affinity(slot),
					graph.slot_bond(slot),
				]
			)
		)


## 영입이 실제로 열리는가 (설계 24.13). **관계도가 없을 때는 이 표가 전부 0 이었다.**
func _report_recruit(world: Array) -> void:
	var registry: PersonRegistry = world[0]
	var graph: RelationGraph = world[1]

	print("\n== 영입 판정 (설계 24.13) ==")
	var pairs := 0
	var open := 0
	var blocked := {}
	for from in graph.person_count():
		for to in graph.targets_of(from):
			pairs += 1
			var standing := RecruitStanding.of(registry, graph, from, to)
			if standing.can_recruit():
				open += 1
			else:
				var reason := standing.blocked_reason().split(" (")[0]
				blocked[reason] = int(blocked.get(reason, 0)) + 1
	print(
		(
			"%-26s %d / %d (%.1f%%)"
			% ["영입 가능한 쌍", open, pairs, 100.0 * float(open) / maxf(float(pairs), 1.0)]
		)
	)
	for reason in blocked:
		print("%-26s %d" % [str(reason), int(blocked[reason])])
	print(
		(
			"%-26s 의리 +100 -> %d, 실리 -100 -> %d"
			% [
				"요구 호감",
				RecruitStanding.required_affinity_for(NpcAxis.MAX_VALUE),
				RecruitStanding.required_affinity_for(NpcAxis.MIN_VALUE),
			]
		)
	)


## 인물 둘의 화면. **상세 화면이 실제로 무엇을 내는지**를 글로 본다.
##
## 가장 엮인 사람과 **소문으로 누군가를 알게 된 사람**을 같이 낸다 —
## 「봤다」와 「들었다」가 화면에서 갈리는지는 후자에서만 보인다 (설계 24.28.4).
func _report_person(world: Array) -> void:
	var registry: PersonRegistry = world[0]
	var graph: RelationGraph = world[1]

	var best := 0
	for person in registry.size():
		if graph.degree_of(person) > graph.degree_of(best):
			best = person
	_print_sheet(world, best, "가장 엮인 인물")

	for slot in graph.size():
		if graph.slot_is_heard(slot):
			_print_sheet(world, graph.slot_from(slot), "소문으로 누군가를 알게 된 인물")
			return


func _print_sheet(world: Array, person: int, note: String) -> void:
	var registry: PersonRegistry = world[0]
	print("\n== %s — 인물 %d ==" % [note, person])
	print(registry.summary_of(person))
	var sections := PersonSheet.build(
		registry, person, FactionIndex.new(registry), SheetDisclosure.Level.DEV, world[1], world[2]
	)
	for title in ["관계", "인물 열전"]:
		print("-- %s" % title)
		for field in PersonSheet.section_of(sections, title).fields:
			print("   %-14s %s" % [field.label, field.display_text()])
