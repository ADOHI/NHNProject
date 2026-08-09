extends SceneTree
## **나이가 세계에서 무엇을 하나.** 그리고 초상의 나이 띠와 맞나.
##
## docs/design/24-npc-relations.md §24.22 · §24.38.
##
## 인물 축의 나이 띠와 세계의 나이 범위가 맞나 —
## **두 자가 다르면 초상이 있는데 그 나이의 인물이 없거나, 인물이 있는데 초상이 없다.**
## 그것은 각 문서만 읽어서는 안 보이고 **여기서만 보인다.**
##
## 그리고 사건이 나이를 보나 — **안 본다면 그것이 실측으로 나와야** 고칠지 말지를 정한다.
##
##   godot --headless --path . -s res://tools/survey_npc_age.gd

const _POPULATION := 3000
const _SEED := 20260808

## 조우를 몇 번 굴려 상대 스쿼드의 나이를 보나.
const _ENCOUNTERS := 200

## 초상 파이프라인이 그리는 나이 띠 (LANE-RULES §5 「인물 축」).
##
## **이 목록은 다른 레인의 것이다.** 여기서 고치지 말고, 어긋나면 어긋났다고 적는다.
## **여덟 띠였던 것이 여섯이 됐다** (설계 24.39.3) — 여덟 살 · 열두 살 · 60대 · 80대는
## 세계에 0명이었고 인구의 26.4% 는 어느 띠에도 안 들었다. 이 도구가 그것을 냈고
## 사용자가 *"던전에 너무 어리거나 너무 노인은 당연히 못 들어간다"* 로 판정했다.
const _PORTRAIT_BANDS := [
	["16~17세", 16, 17],
	["18~19세", 18, 19],
	["20대", 20, 29],
	["30대", 30, 39],
	["40대", 40, 49],
	["50대", 50, 59],
]


func _initialize() -> void:
	print("== 나이 (인구 %d, 시드 %d) ==" % [_POPULATION, _SEED])
	var world := NpcWorld.create(_SEED, _POPULATION)
	_report_bands(world)
	_report_events(world)
	_report_who_stands_out(world)
	quit()


## **초상의 띠 여덟에 실제로 몇 명이 드나.** 빈 띠는 그리고도 안 쓰는 띠다.
func _report_bands(world: NpcWorld) -> void:
	var registry := world.registry
	print(
		(
			"\n생성 범위는 %d~%d 다 (PersonGenerator). 초상 띠는 여덟이다."
			% [PersonGenerator.AGE_MIN, PersonGenerator.AGE_MAX, _PORTRAIT_BANDS.size()]
		)
	)
	print("\n%-12s %8s %8s" % ["초상 띠", "인원", "비율"])
	var covered := 0
	for band in _PORTRAIT_BANDS:
		var low := int(band[1])
		var high := int(band[2])
		var count := 0
		for person in registry.size():
			var age := registry.age_of(person)
			if age >= low and age <= high:
				count += 1
		covered += count
		print(
			(
				"%-12s %8d %7.1f%%"
				% [str(band[0]), count, 100.0 * float(count) / float(registry.size())]
			)
		)
	print(
		(
			"%-12s %8d %7.1f%%"
			% [
				"띠가 없다",
				registry.size() - covered,
				100.0 * float(registry.size() - covered) / float(registry.size()),
			]
		)
	)
	_report_gap()


## 어느 나이가 초상 없이 남나. **띠 사이의 구멍을 이름으로 낸다.**
func _report_gap() -> void:
	var gaps := PackedStringArray()
	var age := PersonGenerator.AGE_MIN
	while age <= PersonGenerator.AGE_MAX:
		var found := false
		for band in _PORTRAIT_BANDS:
			if age >= int(band[1]) and age <= int(band[2]):
				found = true
				break
		if not found:
			gaps.append(str(age))
		age += 1
	if gaps.is_empty():
		print("\n생성 범위 안에 초상 없는 나이 없음.")
		return
	print("\n초상 띠가 없는 나이 %d개 — %s" % [gaps.size(), " ".join(gaps)])


## **사건이 나이를 보나.** 본다면 사건마다 행위자의 나이 중위가 갈려야 한다.
##
## 갈리지 않으면 **여든 살이 선제공격을 하고 열여섯 살이 밀고를 하는** 세계다.
## 그것이 옳은지는 설계가 정하지만, **옳은지 묻기 전에 실제로 그런지부터 재야 한다.**
func _report_events(world: NpcWorld) -> void:
	var registry := world.registry
	var ledger := world.ledger
	print("\n%-10s %8s %10s %8s %8s" % ["사건", "굴린 수", "행위자 나이 중위", "최소", "최대"])

	# 값이 `Array` 인 이유는 `EventSeeder._by_faction` 과 같다 —
	# **`PackedInt32Array` 는 사전에서 꺼낼 때 복사본이 나와 append 가 사전에 안 남는다.**
	var ages := {}
	for cause in ledger.size():
		var kind := int(ledger.kind_of(cause))
		if not ages.has(kind):
			ages[kind] = ([] as Array[int])
		(ages[kind] as Array[int]).append(registry.age_of(ledger.actor_of(cause)))

	var keys := ages.keys()
	keys.sort()
	for kind in keys:
		var found := PackedInt32Array(ages[kind] as Array[int])
		found.sort()
		print(
			(
				"%-10s %8d %10d %8d %8d"
				% [
					RelationEvent.label(kind as RelationEvent.Kind),
					found.size(),
					found[found.size() / 2],
					found[0],
					found[found.size() - 1],
				]
			)
		)

	var all := PackedInt32Array()
	for person in registry.size():
		all.append(registry.age_of(person))
	all.sort()
	print("%-10s %8d %10d %8d %8d" % ["(인구)", all.size(), all[all.size() / 2], all[0], all[-1]])


## **누가 앞에 서나.** 길드 대표 · 대원 · 상대 스쿼드 여섯의 나이다.
##
## 나이를 아무도 안 보면 **가장 흔한 나이가 그대로 대표가 된다** — 세계가 젊은 쪽으로
## 치우쳐 있으므로(§24.22.2) 앞에 서는 사람도 같이 젊어진다.
func _report_who_stands_out(world: NpcWorld) -> void:
	var registry := world.registry
	var guild := Guild.create_starting(_SEED, "새벽 길드", world)
	print("\n== 앞에 서는 사람의 나이 ==")

	var ours := PackedInt32Array()
	var mine := PackedStringArray()
	for member in guild.members:
		if not member.is_in_world():
			continue
		ours.append(member.person)
		mine.append("%d세" % registry.age_of(member.person))
	print("%-22s %s" % ["내 대원", " ".join(mine)])

	var rng := RandomNumberGenerator.new()
	rng.seed = _SEED
	var met := PackedInt32Array()

	for _trial in _ENCOUNTERS:
		for person in RivalSquad.draw(world, rng, ours).members:
			met.append(registry.age_of(person))

	met.sort()
	print(
		(
			"%-22s 중위 %d세 · 최소 %d세 · 최대 %d세"
			% ["조우한 상대 %d명" % met.size(), met[met.size() / 2], met[0], met[met.size() - 1]]
		)
	)

	var teens := 0
	for age in met:
		if age < 20:
			teens += 1
	print("%-22s %.1f%%" % ["그중 스무 살 미만", 100.0 * float(teens) / maxf(float(met.size()), 1.0)])
