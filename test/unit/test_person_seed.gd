extends GutTest
## 생성 난수 흐름을 **동결한다.**
##
## docs/design/24-npc-relations.md §24.24.
##
## ## 이 파일이 지키는 것
##
## **같은 시드의 같은 인덱스는 영원히 같은 사람이다.**
## 초상 레인이 밤새 배치를 돌리는 동안 인구가 바뀌면 아침에 그 인물이 없다.
## 실제로 두 번 그랬다 — 성(`924fab1`)과 성별(`91fd59b`)이 RNG 흐름에 끼어들면서
## 뒤의 뽑기가 전부 밀렸다.
##
## **이 시험이 깨졌다면 인구가 바뀐 것이다.** 값을 고쳐 통과시키기 전에
## 초상 레인에 먼저 알려라 — 골라 둔 캐스트가 사라진다.

## 동결한 세계.
const _SEED := 20260808
const _POPULATION := 3000

## 인덱스 -> [이름, 나이, 성별, 계열, 소속, 유명세].
##
## **이 표를 마음대로 고치지 마라.** 고쳐야 한다면 인구가 바뀐 것이고,
## 그것은 초상 레인의 배치를 무효로 만든다.
const _FROZEN := [
	[0, "김건규", 35, 1, 1, 15, 0],
	[13, "양은담", 43, 1, 1, -1, 0],
	[1500, "권수한", 23, 0, 4, 35, 0],
	[2999, "윤라윤", 46, 0, 4, -1, 0],
]


func _world() -> PersonRegistry:
	return PersonGenerator.new(_SEED, _POPULATION).generate()


func test_frozen_people_never_change() -> void:
	var registry := _world()
	for row in _FROZEN:
		var person: int = row[0]
		assert_eq(registry.name_of(person), row[1], "인덱스 %d 의 이름" % person)
		assert_eq(registry.age_of(person), row[2], "인덱스 %d 의 나이" % person)
		assert_eq(int(registry.gender_of(person)), row[3], "인덱스 %d 의 성별" % person)
		assert_eq(int(registry.discipline_of(person)), row[4], "인덱스 %d 의 계열" % person)
		assert_eq(registry.faction_of(person), row[5], "인덱스 %d 의 소속" % person)
		assert_eq(registry.fame_of(person), row[6], "인덱스 %d 의 유명세" % person)


func test_population_size_does_not_shift_earlier_people() -> void:
	# 인구를 늘려도 앞 인물이 그대로여야 한다 — 인덱스가 흐름에 직접 들어가므로.
	var small := PersonGenerator.new(_SEED, 200).generate()
	var large := _world()
	for person in small.size():
		assert_eq(small.name_of(person), large.name_of(person), "인덱스 %d" % person)
		assert_eq(small.age_of(person), large.age_of(person))
		assert_eq(small.gender_of(person), large.gender_of(person))


# ---------------------------------------------------------------- 흐름 자체


func test_streams_differ_by_field() -> void:
	# 필드가 같은 흐름을 쓰면 나이와 유명세가 붙어 움직인다.
	var seen := {}
	for field in PersonSeed.Field.size():
		seen[PersonSeed.stream(_SEED, field as PersonSeed.Field, 7)] = true
	assert_eq(seen.size(), PersonSeed.Field.size())


func test_streams_differ_by_person() -> void:
	var seen := {}
	for person in 200:
		seen[PersonSeed.stream(_SEED, PersonSeed.Field.NAME, person)] = true
	assert_eq(seen.size(), 200, "인물마다 흐름이 갈려야 한다")


func test_streams_differ_by_world_seed() -> void:
	assert_ne(
		PersonSeed.stream(1, PersonSeed.Field.NAME, 5),
		PersonSeed.stream(2, PersonSeed.Field.NAME, 5)
	)


func test_stream_is_repeatable() -> void:
	assert_eq(
		PersonSeed.stream(_SEED, PersonSeed.Field.AGE, 42),
		PersonSeed.stream(_SEED, PersonSeed.Field.AGE, 42)
	)


func test_event_stream_exists_and_is_separate() -> void:
	# 사건은 생성과 다른 흐름을 써야 한다 — 사건을 더해도 인물이 안 바뀌게 (§24.24).
	var generation: Array[PersonSeed.Field] = [
		PersonSeed.Field.NAME,
		PersonSeed.Field.DISCIPLINE,
		PersonSeed.Field.THREAT,
		PersonSeed.Field.AGILITY,
		PersonSeed.Field.FACTION,
		PersonSeed.Field.FAME,
		PersonSeed.Field.AGE,
		PersonSeed.Field.GENDER,
		PersonSeed.Field.TRAITS,
		PersonSeed.Field.KIN,
	]
	var event := PersonSeed.stream(_SEED, PersonSeed.Field.EVENT, 3)
	for field in generation:
		assert_ne(PersonSeed.stream(_SEED, field, 3), event, str(field))


func test_apply_seeds_the_generator() -> void:
	var one := RandomNumberGenerator.new()
	var other := RandomNumberGenerator.new()
	PersonSeed.apply(one, _SEED, PersonSeed.Field.TRAITS, 11)
	PersonSeed.apply(other, _SEED, PersonSeed.Field.TRAITS, 11)
	assert_eq(one.randi(), other.randi())


func test_families_are_frozen_too() -> void:
	var registry := _world()
	var graph := RelationGraph.new(registry.size())
	KinSeeder.new(_SEED, registry, graph).seed_all()
	var again := RelationGraph.new(registry.size())
	KinSeeder.new(_SEED, registry, again).seed_all()
	assert_eq(graph.size(), again.size())
	for slot in graph.size():
		assert_eq(graph.slot_to(slot), again.slot_to(slot))
