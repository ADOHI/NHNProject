extends SceneTree
## 인물 3000명을 만들어 놓고 눈으로 확인하는 개발 도구.
##
## docs/design/24-npc-relations.md §24.16.8. **3000명을 만들어도 눈에 안 보이면 만든 것이 아니다.**
## 성향 분포가 어중간하면 §24.4 의 내적이 사람을 가르지 못하므로 그것부터 재야 한다.
##
## **여기 있는 수치는 전부 코드의 상수를 읽어서 계산한다.** 베껴 적으면
## 상수를 고쳤을 때 이 도구가 옛 수치로 조용히 거짓말한다.
##
##   godot --headless --path . -s res://tools/survey_npc_population.gd

## 목표 인구. docs/design/24-npc-relations.md §24.8 의 상한이다.
const _POPULATION := 3000

## 기준 시드. 같은 시드면 같은 세계가 나와야 한다 (§24.16.7).
const _SEED := 20260808

## 나눠 돌릴 때 한 번에 몇 명. 웹 한 프레임 예산 안에 들어가는지 보려는 값이다.
const _CHUNK := 250

## 웹 60fps 한 프레임 예산(밀리초).
const _FRAME_BUDGET_MSEC := 16.7

## 성향 히스토그램의 칸 수. -100~+100 을 균등하게 나눈다.
const _BUCKETS := 10

## 반응 진단에 쓰는 탐침 축. 사건 셋이 대체로 이 세 축을 건드린다 (§24.5).
##
## **이것은 사건이 아니다.** 사건 벡터는 다음 덩어리에서 정의된다.
## 여기서는 "축 셋을 같은 무게로 건드리면 인구가 어떻게 반응하나" 만 본다.
const _PROBE_AXES := [NpcAxis.Kind.GOOD, NpcAxis.Kind.LOYAL, NpcAxis.Kind.HONEST]


func _initialize() -> void:
	var registry := _report_generation()
	_report_names(registry)
	_report_axes(registry)
	_report_pole_counts(registry)
	_report_probe(registry)
	_report_factions(registry)
	_report_fame(registry)
	_report_samples(registry)
	_report_determinism()
	quit()


func _report_generation() -> PersonRegistry:
	print("== 인물 생성 (인구 %d, 시드 %d) ==" % [_POPULATION, _SEED])

	var before := OS.get_static_memory_usage()
	var started := Time.get_ticks_usec()
	var registry := PersonGenerator.new(_SEED, _POPULATION).generate()
	var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
	var used := OS.get_static_memory_usage() - before

	var chunked := _measure_chunks()
	print("%-24s %s" % ["인원", registry.size()])
	print("%-24s %.2f ms" % ["한 번에 생성", elapsed])
	print("%-24s %.3f ms" % ["1인당", elapsed / maxf(float(registry.size()), 1.0)])
	print("%-24s %.2f ms (조각 %d명)" % ["나눈 조각 최대", chunked, _CHUNK])
	print(
		(
			"%-24s %s (한 프레임 %.1f ms)"
			% [
				"한 프레임에 되는가",
				"된다" if elapsed <= _FRAME_BUDGET_MSEC else "안 된다 — 나눠 돌려야 한다",
				_FRAME_BUDGET_MSEC,
			]
		)
	)
	var per := float(used) / maxf(float(registry.size()), 1.0)
	print("%-24s %.1f KB (%.0f B/인)" % ["메모리", float(used) / 1024.0, per])
	print("%-24s %.1f KB" % ["인물당 Dictionary 였다면", _measure_dictionary_cost() / 1024.0])
	return registry


## 나눠 돌렸을 때 한 조각의 최대 시간. 분할 구조가 실제로 작동하는지도 여기서 본다.
func _measure_chunks() -> float:
	var generator := PersonGenerator.new(_SEED, _POPULATION)
	var registry := PersonRegistry.new()
	var worst := 0.0
	while true:
		var started := Time.get_ticks_usec()
		var done := generator.append_to(registry, _CHUNK)
		worst = maxf(worst, float(Time.get_ticks_usec() - started) / 1000.0)
		if done:
			break
	if registry.size() != _POPULATION:
		push_error("나눠 돌린 결과가 %d 명이다" % registry.size())
	return worst


## 인물당 Dictionary 를 만들었다면 얼마였을지. 버린 안의 비용을 실측으로 남긴다 (§24.16.1).
func _measure_dictionary_cost() -> float:
	var before := OS.get_static_memory_usage()
	var records: Array[Dictionary] = []
	for _index in _POPULATION:
		var record := {
			"name": "김지호",
			"discipline": 0,
			"threat": 4,
			"agility": 1,
			"faction": 12,
			"fame": 3,
			"traits": [0, 0, 0, 0, 0, 0],
		}
		records.append(record)
	var used := float(OS.get_static_memory_usage() - before)
	records.clear()
	return used


func _report_names(registry: PersonRegistry) -> void:
	print("\n== 이름 ==")
	var seen := {}
	var duplicates := 0
	var fallbacks := 0
	for person in registry.size():
		var name := registry.name_of(person)
		if seen.has(name):
			duplicates += 1
		seen[name] = true
		if name.begins_with("무명 "):
			fallbacks += 1

	var capacity := MemberNames.capacity()
	print("%-24s %d" % ["조합 가능 수", capacity])
	print("%-24s %.1f%%" % ["인구가 쓰는 비율", 100.0 * float(_POPULATION) / maxf(capacity, 1.0)])
	print("%-24s %d" % ["중복 이름", duplicates])
	print("%-24s %d" % ["무명 N 로 떨어진 수", fallbacks])


func _report_axes(registry: PersonRegistry) -> void:
	print("\n== 성향 6축 분포 (%d명) ==" % registry.size())
	print("%-11s %6s %6s %6s   %s" % ["축", "평균", "표준", "극%", "칸별 % (-100 -> +100, 칸 20)"])
	for axis in NpcAxis.count():
		_report_one_axis(registry, axis as NpcAxis.Kind)
	print("극의 경계는 절댓값 %d 이상 (TraitDistribution.POLE_MIN)" % TraitDistribution.POLE_MIN)
	# 칸별 비율이 거의 평평한 것은 **설계대로다.** 이 분포가 균등 난수와 다른 곳은
	# 축 하나의 모양이 아니라 축 여섯의 결합 구조다 — 아래 「뚜렷함」 표가 그것을 본다.
	print("칸이 평평한 것은 설계대로다. 차이는 아래 「뚜렷함」 표에 있다 (§24.16.3)")


func _report_one_axis(registry: PersonRegistry, axis: NpcAxis.Kind) -> void:
	var buckets := PackedInt32Array()
	buckets.resize(_BUCKETS)
	var total := 0.0
	var squares := 0.0
	var poles := 0
	for person in registry.size():
		var value := registry.trait_of(person, axis)
		total += float(value)
		squares += float(value) * float(value)
		if TraitDistribution.is_pole(value):
			poles += 1
		buckets[_bucket_of(value)] += 1

	var count := maxf(float(registry.size()), 1.0)
	var mean := total / count
	print(
		(
			"%-11s %6.1f %6.1f %5.1f%%   %s"
			% [
				NpcAxis.label(axis),
				mean,
				sqrt(maxf(squares / count - mean * mean, 0.0)),
				100.0 * float(poles) / count,
				_shares(buckets, registry.size()),
			]
		)
	)


func _report_pole_counts(registry: PersonRegistry) -> void:
	print("\n== 뚜렷함 — 인물당 극 축의 개수 ==")
	var found := PackedInt32Array()
	found.resize(NpcAxis.count() + 1)
	for person in registry.size():
		found[registry.pole_count_of(person)] += 1

	print("%-6s %8s %8s   %s" % ["극 수", "인원", "실측%", "기대%"])
	for count in found.size():
		print(
			(
				"%-6d %8d %7.1f%%   %6.1f%%"
				% [
					count,
					found[count],
					100.0 * float(found[count]) / maxf(float(registry.size()), 1.0),
					100.0 * TraitDistribution.expected_ratio(count),
				]
			)
		)
	print("인물당 극 축 기대값 %.2f 개" % TraitDistribution.expected_pole_count())


## 축 셋을 같은 무게로 건드리는 탐침에 인구가 어떻게 반응하나.
##
## **균등 난수 인구와 나란히 잰다.** §24.16.3 이 "반응의 세기는 거의 같다" 고 적었으므로
## 그 주장이 실제로 맞는지 이 표가 증거다. 틀리면 문서를 고쳐야 한다.
func _report_probe(registry: PersonRegistry) -> void:
	print("\n== 반응 진단 — 축 %d개 탐침 (사건이 아니다) ==" % _PROBE_AXES.size())
	var ours := _probe_values(registry)
	var flat := _probe_values(_uniform_registry())
	print("%-14s %8s %8s %8s %8s" % ["인구", "평균|반응|", "표준", "약함%", "강함%"])
	_print_probe_row("이 분포", ours)
	_print_probe_row("균등 난수", flat)
	print("반응은 최대치 대비 백분율이다. 약함 = 10% 미만, 강함 = 50% 이상")


func _print_probe_row(label: String, values: PackedFloat32Array) -> void:
	var total := 0.0
	var squares := 0.0
	var weak := 0
	var strong := 0
	for value in values:
		var size := absf(value)
		total += size
		squares += size * size
		if size < 10.0:
			weak += 1
		if size >= 50.0:
			strong += 1
	var count := maxf(float(values.size()), 1.0)
	var mean := total / count
	print(
		(
			"%-14s %7.1f%% %8.1f %7.1f%% %7.1f%%"
			% [
				label,
				mean,
				sqrt(maxf(squares / count - mean * mean, 0.0)),
				100.0 * float(weak) / count,
				100.0 * float(strong) / count,
			]
		)
	)


func _probe_values(registry: PersonRegistry) -> PackedFloat32Array:
	var scale := float(_PROBE_AXES.size() * NpcAxis.MAX_VALUE)
	var values := PackedFloat32Array()
	for person in registry.size():
		var sum := 0.0
		for axis in _PROBE_AXES:
			sum -= float(registry.trait_of(person, axis))
		values.append(100.0 * sum / scale)
	return values


## 비교용 인구. 축마다 균등 난수를 쓴다 — **버린 안이라 src 에 두지 않는다.**
func _uniform_registry() -> PersonRegistry:
	var rng := RandomNumberGenerator.new()
	rng.seed = _SEED
	var registry := PersonRegistry.new()
	for _person in _POPULATION:
		var traits := PackedInt32Array()
		for _axis in NpcAxis.count():
			traits.append(rng.randi_range(NpcAxis.MIN_VALUE, NpcAxis.MAX_VALUE))
		registry.add(
			"표본",
			MemberDiscipline.Kind.COMBAT,
			1,
			1,
			PersonRegistry.NO_FACTION,
			0,
			30,
			PersonGender.Kind.MALE,
			traits
		)
	return registry


func _report_factions(registry: PersonRegistry) -> void:
	print("\n== 소속 ==")
	var sizes := {}
	var unaffiliated := 0
	for person in registry.size():
		var faction := registry.faction_of(person)
		if faction == PersonRegistry.NO_FACTION:
			unaffiliated += 1
			continue
		sizes[faction] = int(sizes.get(faction, 0)) + 1

	var counts := PackedInt32Array()
	for faction in sizes:
		counts.append(int(sizes[faction]))
	counts.sort()

	var count := maxf(float(registry.size()), 1.0)
	print("%-24s %d" % ["소속 수 (인원 1명 이상)", counts.size()])
	print("%-24s %.1f%%" % ["무소속", 100.0 * float(unaffiliated) / count])
	if counts.is_empty():
		return
	print(
		(
			"%-24s %d / %d / %d"
			% ["최소 / 중위 / 최대", counts[0], counts[counts.size() / 2], counts[counts.size() - 1]]
		)
	)
	print("%-24s %d" % ["1명뿐인 소속", _count_below(counts, 2)])


func _report_fame(registry: PersonRegistry) -> void:
	print("\n== 유명세 ==")
	var values := PackedInt32Array()
	for person in registry.size():
		values.append(registry.fame_of(person))
	values.sort()
	var count := maxf(float(values.size()), 1.0)
	print("%-24s %d" % ["중위값", values[values.size() / 2]])
	print(
		"%-24s %.1f%%" % ["50 이상", 100.0 * float(values.size() - _count_below(values, 50)) / count]
	)
	print(
		"%-24s %.1f%%" % ["90 이상", 100.0 * float(values.size() - _count_below(values, 90)) / count]
	)
	print("%-24s %d" % ["최대", values[values.size() - 1]])


func _report_samples(registry: PersonRegistry) -> void:
	print("\n== 표본 — 유명세 상위 5명 ==")
	var order := PackedInt32Array()
	for person in registry.size():
		order.append(person)
	# 상위 몇 명만 보려는 것이라 전체 정렬 대신 최댓값을 다섯 번 고른다.
	var taken := {}
	for _slot in 5:
		var best := -1
		for person in order:
			if taken.has(person):
				continue
			if best < 0 or registry.fame_of(person) > registry.fame_of(best):
				best = person
		if best < 0:
			break
		taken[best] = true
		print("  %s" % registry.summary_of(best))

	print("== 표본 — 앞에서 5명 ==")
	for person in mini(5, registry.size()):
		print("  %s" % registry.summary_of(person))


func _report_determinism() -> void:
	print("\n== 결정론 ==")
	var one := PersonGenerator.new(_SEED, _POPULATION).generate()
	var two := PersonGenerator.new(_SEED, _POPULATION).generate()
	var other := PersonGenerator.new(_SEED + 1, _POPULATION).generate()
	print("%-24s %s" % ["같은 시드", "같다" if _same(one, two) else "다르다 — 버그다"])
	print("%-24s %s" % ["다른 시드", "다르다" if not _same(one, other) else "같다 — 버그다"])

	var split := PersonRegistry.new()
	var generator := PersonGenerator.new(_SEED, _POPULATION)
	while not generator.append_to(split, _CHUNK):
		pass
	print("%-24s %s" % ["나눠 돌린 결과", "같다" if _same(one, split) else "다르다 — 버그다"])


func _same(one: PersonRegistry, other: PersonRegistry) -> bool:
	if one.size() != other.size():
		return false
	for person in one.size():
		if one.name_of(person) != other.name_of(person):
			return false
		for axis in NpcAxis.count():
			if (
				one.trait_of(person, axis as NpcAxis.Kind)
				!= other.trait_of(person, axis as NpcAxis.Kind)
			):
				return false
		if one.faction_of(person) != other.faction_of(person):
			return false
		if one.fame_of(person) != other.fame_of(person):
			return false
	return true


func _bucket_of(value: int) -> int:
	var span := NpcAxis.MAX_VALUE - NpcAxis.MIN_VALUE + 1
	return clampi((value - NpcAxis.MIN_VALUE) * _BUCKETS / span, 0, _BUCKETS - 1)


## 칸마다 인구 비율(%). 막대 그림 대신 숫자를 낸다 —
## 이 분포는 칸별 비율이 거의 평평해서 막대로는 아무것도 읽히지 않고,
## 그러면 도구가 고장 난 것처럼 보인다.
func _shares(buckets: PackedInt32Array, total: int) -> String:
	var parts := PackedStringArray()
	for bucket in buckets:
		parts.append("%4.1f" % (100.0 * float(bucket) / maxf(float(total), 1.0)))
	return " ".join(parts)


func _count_below(values: PackedInt32Array, limit: int) -> int:
	var found := 0
	for value in values:
		if value >= limit:
			break
		found += 1
	return found
