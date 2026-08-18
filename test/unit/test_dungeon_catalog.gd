extends GutTest
## 던전 성격의 단위 테스트.
##
## 여기서 지키는 것은 **값이 아니라 규칙**이다. 다섯의 이름과 수치는 기획이라 뒤집히지만,
## 아래 규칙이 깨지면 성격이 성격으로 읽히지 않는다
## (docs/design/17-dungeon-generation.md §17.16.4).
##
## | 규칙 | 왜 |
## | --- | --- |
## | 한 던전에 축 둘까지 | 셋 이상이면 어느 것이 그 던전의 성격인지 안 읽힌다 |
## | 잡음 축은 쓰지 않는다 | 시드가 더 크게 흔드는 축은 「운이 나빴다」로 읽힌다 |
## | 성격이 방 개수를 건드리지 않는다 | 크기는 게이트 등급의 축이다. 덮어쓰면 등급이 뜻을 잃는다 |
## | 성격마다 판이 실제로 다르다 | 같은 시드에서 같은 판이 나오면 성격이 아니다 |

const CatalogScript := preload("res://src/core/dungeon/dungeon_catalog.gd")
const GeneratorScript := preload("res://src/core/dungeon/dungeon_generator.gd")

## 신호대잡음이 이 아래인 축은 성격으로 쓰지 않는다 (§17.16.4 R2).
const _NOISY_AXES := ["elevation_amplitude", "elevation_frequency"]

## 한 던전이 흔들 수 있는 축의 수 (§17.16.4 R1).
const _AXIS_LIMIT := 2


func test_every_character_shakes_at_most_two_axes() -> void:
	for character in CatalogScript.all():
		assert_lte(
			character.axes.size(),
			_AXIS_LIMIT,
			"%s 이 축을 %d 개 흔든다" % [character.display_name, character.axes.size()]
		)


func test_no_character_shakes_a_noisy_axis() -> void:
	# 시드가 더 크게 흔드는 축을 쓰면 플레이어는 그것을 운으로 돌린다.
	for character in CatalogScript.all():
		for field in character.axes:
			assert_false(
				_NOISY_AXES.has(String(field)),
				"%s 이 잡음 축 %s 를 흔든다" % [character.display_name, field]
			)


func test_no_character_touches_the_room_count() -> void:
	# 방 개수는 게이트 등급의 축이다. 성격이 덮어쓰면 등급이 뜻을 잃는다.
	for character in CatalogScript.all():
		assert_false(character.axes.has("room_count"), "%s 이 방 개수를 건드린다" % character.display_name)


func test_the_character_leaves_the_room_count_alone() -> void:
	for index in CatalogScript.count():
		var params := DungeonGenerator.Params.new()
		params.room_count = 33
		CatalogScript.apply(params, index)
		assert_eq(params.room_count, 33, "%s 이 방 개수를 바꿨다" % CatalogScript.name_of(index))


func test_every_character_has_a_name_and_a_summary() -> void:
	# 요약은 「판에서 무엇으로 읽히나」다. 없으면 그 성격은 화면에서 확인할 수 없다.
	var seen := {}
	for character in CatalogScript.all():
		assert_false(character.display_name.is_empty(), "이름 없는 성격이 있다")
		assert_false(character.summary.is_empty(), "%s 에 요약이 없다" % character.display_name)
		assert_false(seen.has(character.id), "성격 id 가 겹친다: %s" % character.id)
		seen[character.id] = true


func test_characters_actually_make_different_boards() -> void:
	# 같은 시드에서 같은 판이 나오면 성격이 아니라 이름표일 뿐이다.
	var signatures := {}
	for index in CatalogScript.count():
		var params := DungeonGenerator.Params.new()
		params.room_count = 30
		CatalogScript.apply(params, index)
		var blueprint := GeneratorScript.new(7, params).generate()
		var signature := "%d/%d" % [blueprint.room_ids().size(), blueprint.connections().size()]
		signatures[CatalogScript.name_of(index)] = signature

	# 다섯이 전부 다를 필요는 없지만(축이 방 종류만 건드리는 성격도 있다)
	# 적어도 절반은 갈려야 한다.
	var distinct := {}
	for name in signatures:
		distinct[signatures[name]] = true
	assert_gte(distinct.size(), 3, "성격 다섯이 만드는 판이 %d 가지뿐이다" % distinct.size())


func test_the_same_character_and_seed_give_the_same_board() -> void:
	for index in CatalogScript.count():
		var first := _signature(index)
		var second := _signature(index)
		assert_eq(first, second, "%s 이 같은 시드에서 다른 판을 만든다" % CatalogScript.name_of(index))


func test_the_index_wraps_instead_of_dying() -> void:
	# 아웃게임이 아직 성격을 고르지 않으므로 아무 수나 들어올 수 있다.
	assert_eq(CatalogScript.wrapped(-1), CatalogScript.count() - 1, "음수 색인이 접히지 않는다")
	assert_eq(CatalogScript.wrapped(CatalogScript.count()), 0, "범위 밖 색인이 접히지 않는다")
	assert_false(CatalogScript.name_of(99).is_empty(), "범위 밖 이름이 비어 있다")


func _signature(index: int) -> String:
	var params := DungeonGenerator.Params.new()
	params.room_count = 24
	CatalogScript.apply(params, index)
	var blueprint := GeneratorScript.new(3, params).generate()
	var parts: Array[String] = []
	for id in blueprint.room_ids():
		parts.append("%s:%d" % [id, blueprint.elevation_of(id)])
	return "|".join(parts)


func test_every_axis_name_is_a_real_parameter() -> void:
	# `Params.set()` 은 없는 이름을 말없이 삼킨다. 오타가 나면 그 축이 죽는데
	# **그래프만 보는 테스트로는 방 종류 축의 죽음이 원리적으로 안 잡힌다** —
	# 귀중품·위험방·탈출구 거리를 꺼도 판의 서명이 바이트 단위로 같다.
	# 그래서 이름 자체를 확인한다.
	assert_eq(CatalogScript.unknown_axes(), [] as Array[String], "없는 축을 흔드는 성격이 있다")


func test_a_typo_in_an_axis_name_is_caught() -> void:
	# 검사가 실제로 잡는지 본다. 아무것도 못 잡는 검사기면 위 시험은 늘 통과한다.
	var params := DungeonGenerator.Params.new()
	assert_null(params.get("treasure_ratio_TYPO"), "없는 이름인데 값이 나온다")
	assert_not_null(params.get("treasure_ratio"), "있는 이름인데 값이 없다")
