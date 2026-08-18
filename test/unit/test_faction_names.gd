extends GutTest
## 소속 이름을 덮는다.
##
## docs/design/24-npc-relations.md §24.33.
##
## 지켜야 할 것 셋 —
##
## 1. **안 겹친다.** 두 소속이 같은 이름이면 조우에서 "또 그 길드다" 가 거짓말이 된다
## 2. **번호 순서가 이름에 안 비친다** — 비치면 읽는 사람이 이름 대신 번호를 본다
## 3. **같은 시드는 같은 이름이다.** 판을 다시 열어도 그 길드는 그 이름이다

const _SEED := 20260808


func _all(count: int) -> PackedInt32Array:
	var found := PackedInt32Array()
	for faction in count:
		found.append(faction)
	return found


func test_names_do_not_collide() -> void:
	var names := FactionNames.assign(_SEED, _all(75))
	var seen := {}
	for faction in names:
		var name: String = names[faction]
		assert_false(seen.has(name), name)
		seen[name] = true


func test_nobody_goes_unnamed_at_the_real_load() -> void:
	# 소속이 75개고 용량이 수백이라 거절 표집이 시도를 다 태울 일이 없다.
	assert_gt(FactionNames.capacity(), 75 * 4)
	for faction in FactionNames.assign(_SEED, _all(75)).values():
		assert_ne(faction, FactionNames.UNNAMED)


func test_the_number_does_not_show_through() -> void:
	# `#1 무쇠 문` · `#2 무쇠 손` 처럼 나오면 이름이 번호의 딱지가 된다.
	var names := FactionNames.assign(_SEED, _all(40))
	var shared := 0
	for faction in range(1, 40):
		var here: String = names[faction]
		var before: String = names[faction - 1]
		if here.get_slice(" ", 0) == before.get_slice(" ", 0):
			shared += 1
	assert_lt(shared, 6, "이웃한 번호가 이웃한 이름을 받으면 안 된다")


func test_the_same_seed_names_the_same_guild() -> void:
	assert_eq(FactionNames.assign(_SEED, _all(20)), FactionNames.assign(_SEED, _all(20)))


func test_another_seed_names_them_differently() -> void:
	assert_ne(FactionNames.assign(_SEED, _all(20)), FactionNames.assign(_SEED + 1, _all(20)))


func test_the_index_shows_the_name_instead_of_the_number() -> void:
	# **번호와 이름을 같이 내면 화면이 둘 다 읽으라고 시킨다** (§24.17.6 의 규율).
	var world := NpcWorld.create(_SEED, 400)
	var faction := -1
	for person in world.registry.size():
		if world.registry.faction_of(person) != PersonRegistry.NO_FACTION:
			faction = world.registry.faction_of(person)
			break
	assert_gte(faction, 0)
	var line := world.factions.describe(faction)
	assert_string_contains(line, world.factions.name_of(faction))
	assert_false(line.contains("#"), "이름이 있으면 번호는 안 나간다")
	# 크기와 순위는 그대로 나간다 — 이름이 정보를 안 나르므로 숫자가 그 일을 한다.
	assert_string_contains(line, "%d명" % world.factions.size_of(faction))


func test_without_a_seed_the_number_stays() -> void:
	var registry := PersonGenerator.new(_SEED, 200).generate()
	var index := FactionIndex.new(registry)
	assert_eq(index.name_of(0), "")
	assert_string_contains(index.describe(0), "#0")
