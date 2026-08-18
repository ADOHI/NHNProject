extends GutTest
## 게이트의 단위 테스트.
##
## 가장 중요한 것은 **같은 게이트가 같은 던전을 낸다**는 것이다.
## 이것이 깨지면 정보실이 미리 보여 준 것이 거짓말이 되고,
## "이 게이트를 고른다" 는 결정이 도박이 된다 (docs/design/22-guild-base.md §22.5).

const GateScript := preload("res://src/core/gate/gate.gd")
const BoardScript := preload("res://src/core/gate/gate_board.gd")

const _SEED := 20260808


func _make_gate(seed_value: int = _SEED) -> Gate:
	return GateScript.new("gate_0", "잿빛 지하도", GateRank.Kind.E, seed_value)


# ---------------------------------------------------------------- 등급


func test_rank_maps_to_size_and_reward() -> void:
	assert_eq(GateRank.dungeon_size(GateRank.Kind.E), 1)
	assert_eq(GateRank.dungeon_size(GateRank.Kind.A), 5)
	assert_true(
		GateRank.reward_multiplier(GateRank.Kind.A) > GateRank.reward_multiplier(GateRank.Kind.E),
		"높은 등급이 더 많이 준다"
	)


func test_rank_access_follows_guild_rank() -> void:
	assert_true(GateRank.is_open_to(GateRank.Kind.E, 1), "1등급 길드는 E급에 들어간다")
	assert_false(GateRank.is_open_to(GateRank.Kind.D, 1), "1등급 길드는 D급에 못 들어간다")
	assert_true(GateRank.is_open_to(GateRank.Kind.D, 2))


# ---------------------------------------------------------------- 공개 수준


func test_disclosure_rises_with_intel_staff() -> void:
	assert_eq(GateDisclosure.level_for(0, 1, 2), GateDisclosure.Level.RUMOR)
	assert_eq(GateDisclosure.level_for(1, 1, 2), GateDisclosure.Level.SURVEYED)
	assert_eq(GateDisclosure.level_for(3, 1, 2), GateDisclosure.Level.MAPPED)


func test_preview_grows_with_disclosure() -> void:
	var gate := _make_gate()
	var rumor := gate.preview_lines(GateDisclosure.Level.RUMOR)
	var surveyed := gate.preview_lines(GateDisclosure.Level.SURVEYED)
	var mapped := gate.preview_lines(GateDisclosure.Level.MAPPED)
	assert_eq(rumor.size(), 1, "소문 수준은 등급만 보여 준다")
	assert_true(surveyed.size() > rumor.size(), "정찰이 소문보다 많이 보여 준다")
	assert_true(mapped.size() > surveyed.size(), "해부가 정찰보다 많이 보여 준다")


func test_blueprint_is_only_needed_when_mapped() -> void:
	assert_false(GateDisclosure.needs_blueprint(GateDisclosure.Level.RUMOR))
	assert_false(GateDisclosure.needs_blueprint(GateDisclosure.Level.SURVEYED))
	assert_true(GateDisclosure.needs_blueprint(GateDisclosure.Level.MAPPED))


# ---------------------------------------------------------------- 씨앗 고정


## 같은 게이트를 두 번 열면 같은 던전이 나와야 한다.
func test_same_gate_opens_the_same_dungeon() -> void:
	var gate := _make_gate()
	var first := gate.create_run()
	var second := gate.create_run()

	var first_ids := first.blueprint.room_ids()
	var second_ids := second.blueprint.room_ids()
	assert_eq(first_ids, second_ids, "방 목록이 같아야 한다")
	for id in first_ids:
		assert_eq(first.blueprint.kind_of(id), second.blueprint.kind_of(id), "방 종류가 같아야 한다")
		assert_eq(first.blueprint.elevation_of(id), second.blueprint.elevation_of(id), "고도가 같아야 한다")
		assert_eq(first.graph.threat_at(id), second.graph.threat_at(id), "배치된 위험도가 같아야 한다")


## 씨앗이 다르면 판도 달라야 한다. 같으면 씨앗이 쓰이지 않고 있다는 뜻이다.
func test_different_seed_opens_a_different_dungeon() -> void:
	var one := _make_gate(1).create_run()
	var other := _make_gate(2).create_run()
	var same := true
	var ids := one.blueprint.room_ids()
	if ids.size() != other.blueprint.room_ids().size():
		same = false
	else:
		for id in ids:
			if one.blueprint.elevation_of(id) != other.blueprint.elevation_of(id):
				same = false
				break
	assert_false(same, "씨앗이 다르면 판이 달라야 한다")


func test_blueprint_is_cached() -> void:
	var gate := _make_gate()
	assert_eq(gate.blueprint(), gate.blueprint(), "설계도는 한 번만 만든다")


# ---------------------------------------------------------------- 목록


func test_board_is_reproducible() -> void:
	var first := BoardScript.create(_SEED, 3, 4)
	var second := BoardScript.create(_SEED, 3, 4)
	assert_eq(first.size(), 4)
	for index in first.size():
		assert_eq(first[index].display_name, second[index].display_name)
		assert_eq(int(first[index].rank), int(second[index].rank))
		assert_eq(first[index].dungeon_seed, second[index].dungeon_seed)


func test_board_respects_guild_rank() -> void:
	for gate in BoardScript.create(_SEED, 1, 6):
		assert_eq(int(gate.rank), int(GateRank.Kind.E), "1등급 길드에게는 E급만 열린다")
	for gate in BoardScript.create(_SEED, 3, 6):
		assert_true(GateRank.is_open_to(gate.rank, 3), "등급 상한을 넘는 게이트가 없어야 한다")


func test_board_names_do_not_repeat() -> void:
	var seen := {}
	for gate in BoardScript.create(_SEED, 5, 8):
		assert_false(seen.has(gate.display_name), "이름이 겹치면 게이트를 구분할 수 없다")
		seen[gate.display_name] = true


func test_board_slots_get_distinct_seeds() -> void:
	var seeds := {}
	for gate in BoardScript.create(_SEED, 5, 8):
		assert_false(seeds.has(gate.dungeon_seed), "자리마다 다른 씨앗이어야 한다")
		seeds[gate.dungeon_seed] = true


func test_the_board_is_not_four_of_the_same_gate() -> void:
	# 길드 등급 1 에서는 E급만 열 수 있어 등급으로는 목록이 갈리지 않는다.
	# 그때 넷이 전부 같은 판이면 "어느 걸 갈까" 가 성립하지 않는다 - 첫 판에서 보는 화면이다.
	for board_seed in [1, 2, 3, 7, 11]:
		var gates := GateBoard.create(board_seed, 1, 4)
		var flavours := {}
		for gate in gates:
			flavours["%d/%d" % [gate.dungeon_character, gate.size_offset]] = true
		assert_gte(flavours.size(), 3, "목록 시드 %d 에서 게이트가 다 비슷하다" % board_seed)


func test_gates_on_one_board_differ_in_what_the_player_reads() -> void:
	# 성격이 달라도 화면에 나오는 등급이 같으면 플레이어에게는 같은 게이트다.
	for board_seed in [1, 2, 3]:
		var seen := {}
		for gate in GateBoard.create(board_seed, 1, 4):
			var grade := DungeonGrade.of(gate.blueprint())
			seen["%d/%d/%d" % [grade["scale"], grade["complexity"], grade["hardship"]]] = true
		assert_gte(seen.size(), 3, "목록 시드 %d 의 게이트 등급이 겹친다" % board_seed)


func test_the_rank_size_axis_matches_the_dungeon_size_axis() -> void:
	# GateRank._SIZES 주석이 "SampleDungeons.SIZE_MIN ~ SIZE_MAX 와 같은 축" 이라 적어 놓고
	# 상호 참조가 없다. 축이 넓어지면 게이트만 옛 범위에 남고 아무도 안 알려 준다 —
	# `params_for_size` 가 범위 밖을 말없이 접기 때문이다.
	var sizes: Array[int] = []
	for kind in GateRank.count():
		sizes.append(GateRank.dungeon_size(kind as GateRank.Kind))
	assert_eq(sizes.min(), SampleDungeons.SIZE_MIN, "게이트 최소 크기가 던전 축과 다르다")
	assert_eq(sizes.max(), SampleDungeons.SIZE_MAX, "게이트 최대 크기가 던전 축과 다르다")
	assert_eq(
		GateRank.count(),
		SampleDungeons.SIZE_MAX - SampleDungeons.SIZE_MIN + 1,
		"등급 수와 크기 단계 수가 다르다"
	)


# ---------------------------------------------------------------- 입장 민첩


## **기본 민첩으로 목록이 살아 있어야 한다.**
##
## 입장 제한(§17.40)이 놓은 구멍은 판 하나가 아니라 **목록 하나**에 있다.
## 넷이 다 막히면 그 판에서 할 수 있는 일이 없다 — 막다른 상태다.
##
## 실측(§17.42)으로는 민첩 2 에서 막다른 목록이 200 판 중 **0** 이고,
## 민첩 1 에서는 **71~80%** 다. 벼랑이 정확히 2 에 있고, 그 2 는
## `Params.elevation_gain` 기본값이다 — **그 값을 올리면 이 자가 먼저 빨개진다.**
func test_a_board_always_has_somewhere_to_go_at_the_default_agility() -> void:
	for guild_rank in [1, 3, 5]:
		for board_seed in 12:
			var gates := BoardScript.create(board_seed * 7919 + guild_rank, guild_rank, 4)
			var open := 0
			for gate in gates:
				if gate.can_enter(SampleDungeons.SQUAD_AGILITY):
					open += 1
			assert_gt(
				open,
				0,
				(
					"등급 %d · 목록 %d: 넷 다 못 들어간다 (필요 민첩 %s)"
					% [
						guild_rank,
						board_seed,
						str(gates.map(func(gate: Gate) -> int: return gate.required_agility())),
					]
				)
			)


## **막는 값은 「끝낼 수 있나」지 「다 볼 수 있나」가 아니다.**
##
## 둘을 헷갈려 `full_agility` 로 막으면 민첩 2 가 판의 55% 에서 거절당하고
## 수직 회랑이 통째로 사라진다 (§17.40.1). 그 혼동을 자로 못 박는다.
func test_clearing_is_cheaper_than_seeing_it_all() -> void:
	var cheaper := 0
	for character in DungeonCatalog.count():
		for seed_value in [5, 17, 41]:
			var gate := _make_gate(seed_value)
			gate.dungeon_character = character
			assert_true(gate.full_agility() >= gate.required_agility(), "다 보는 값이 더 싸다")
			if gate.full_agility() > gate.required_agility():
				cheaper += 1
	assert_gt(cheaper, 0, "둘이 언제나 같으면 값을 둘로 나눈 이유가 없다")
