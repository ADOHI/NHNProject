extends GutTest
## 길드와 편성의 단위 테스트.
##
## 여기서 지켜야 할 규칙은 하나다 —
## **스쿼드 정원 < 직업 계열 수** (docs/design/14-squad.md §14.4.3).
## 이것이 깨지면 전부 데려갈 수 있게 되고, 편성도 배치도 결정이 아니게 된다.

const GuildScript := preload("res://src/core/guild/guild.gd")
const MemberScript := preload("res://src/core/guild/guild_member.gd")

const _SEED := 7


func _starting_guild() -> Guild:
	return GuildScript.create_starting(_SEED)


# ---------------------------------------------------------------- 시작 상태


func test_starting_guild_has_one_of_each_discipline() -> void:
	var guild := _starting_guild()
	assert_eq(guild.members.size(), MemberDiscipline.count(), "계열 하나씩 있어야 한다")
	var seen := {}
	for member in guild.members:
		seen[int(member.discipline)] = true
	assert_eq(seen.size(), MemberDiscipline.count())


func test_starting_names_do_not_repeat() -> void:
	var seen := {}
	for member in _starting_guild().members:
		assert_false(seen.has(member.display_name), "이름이 겹치면 기사에서 구분되지 않는다")
		seen[member.display_name] = true


func test_starting_guild_is_reproducible() -> void:
	var first := GuildScript.create_starting(_SEED)
	var second := GuildScript.create_starting(_SEED)
	for index in first.members.size():
		assert_eq(first.members[index].display_name, second.members[index].display_name)


# ---------------------------------------------------------------- 정원


func test_capacity_is_smaller_than_discipline_count() -> void:
	var guild := _starting_guild()
	assert_true(guild.squad_capacity() < MemberDiscipline.count(), "정원은 계열 수보다 작아야 한다")


func test_capacity_grows_with_base_level_but_never_reaches_discipline_count() -> void:
	var guild := _starting_guild()
	var before := guild.squad_capacity()
	guild.base_level = GuildBalance.BASE_LEVEL_MAX
	var after := guild.squad_capacity()
	assert_true(after > before, "아지트가 오르면 정원이 는다")
	assert_true(after < MemberDiscipline.count(), "그래도 계열 수는 넘지 않는다")


# ---------------------------------------------------------------- 편성


func test_form_squad_rejects_over_capacity() -> void:
	var guild := _starting_guild()
	assert_null(guild.form_squad(guild.member_ids()), "전원 출전은 정원을 넘는다")


func test_form_squad_rejects_unknown_and_duplicate() -> void:
	var guild := _starting_guild()
	assert_null(guild.form_squad(["없는놈"] as Array[String]))
	var first := guild.members[0].id
	assert_null(guild.form_squad([first, first] as Array[String]), "같은 대원을 두 번 넣을 수 없다")


func test_form_squad_rejects_empty() -> void:
	assert_null(_starting_guild().form_squad([] as Array[String]))


## 대원들이 Actor 하나로 접힌다 — 판 위의 말은 하나다 (§14.2).
func test_squad_folds_into_a_single_actor() -> void:
	var guild := _starting_guild()
	var ids: Array[String] = [guild.members[0].id, guild.members[1].id]
	var squad := guild.form_squad(ids)
	assert_not_null(squad)

	var actor := squad.to_actor()
	assert_eq(int(actor.kind), int(Actor.Kind.PLAYER_SQUAD))
	assert_eq(actor.threat, guild.members[0].threat + guild.members[1].threat, "전투력은 합이다 (§14.3)")
	assert_eq(
		actor.agility,
		(guild.members[0].agility + guild.members[1].agility) / 2,
		"민첩은 평균 내림이다 (§14.3.1)"
	)


func test_squad_reports_disciplines_without_duplicates() -> void:
	var guild := _starting_guild()
	var ids: Array[String] = [guild.members[0].id, guild.members[1].id]
	assert_eq(guild.form_squad(ids).disciplines().size(), 2)


# ---------------------------------------------------------------- 아지트


func test_base_progress_levels_up_and_keeps_remainder() -> void:
	var guild := _starting_guild()
	var gained := guild.add_base_progress(GuildBalance.BASE_PROGRESS_TO_LEVEL + 1)
	assert_eq(gained, 1)
	assert_eq(guild.base_level, GuildBalance.STARTING_BASE_LEVEL + 1)
	assert_eq(guild.base_progress, 1, "남은 진척은 다음 레벨로 넘어간다")


func test_base_level_stops_at_max() -> void:
	var guild := _starting_guild()
	guild.add_base_progress(GuildBalance.BASE_PROGRESS_TO_LEVEL * 40)
	assert_eq(guild.base_level, GuildBalance.BASE_LEVEL_MAX)
	assert_eq(guild.base_progress, 0, "상한에 닿으면 진척을 쌓아 두지 않는다")


func test_rank_follows_base_level() -> void:
	var guild := _starting_guild()
	guild.base_level = 4
	assert_eq(guild.rank(), 4, "길드 등급과 아지트 레벨은 지금 같은 값이다 (§22.10)")


# ---------------------------------------------------------------- 게이트 목록


## 게이트는 만료된다 — 한 바퀴를 돌면 목록이 갈린다 (§22.0).
func test_board_seed_changes_after_each_expedition() -> void:
	var guild := _starting_guild()
	var before := guild.board_seed_for(_SEED)
	guild.mark_settled("exp_1")
	assert_ne(guild.board_seed_for(_SEED), before, "정산이 끝나면 목록이 갈린다")


func test_open_gates_uses_guild_rank() -> void:
	var guild := _starting_guild()
	for gate in guild.open_gates(_SEED):
		assert_true(GateRank.is_open_to(gate.rank, guild.rank()))


# ---------------------------------------------------------------- 대원 관리


func test_removing_member_clears_assignment() -> void:
	var guild := _starting_guild()
	var member_id := guild.members[0].id
	guild.assignment.assign(member_id, Facility.Kind.WORKSHOP)
	guild.remove_member(member_id)
	assert_false(guild.assignment.is_assigned(member_id))


func test_add_member_ignores_duplicate_id() -> void:
	var guild := _starting_guild()
	var count := guild.members.size()
	guild.add_member(MemberScript.new(guild.members[0].id, "복제", MemberDiscipline.Kind.COMBAT))
	assert_eq(guild.members.size(), count)
