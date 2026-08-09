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
