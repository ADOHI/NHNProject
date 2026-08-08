extends GutTest
## 원정 한 바퀴의 단위 테스트.
##
## 게이트 선택 -> 편성 -> 진입 -> 결과 -> 정산이 **실제로 이어지는지**를 본다.
## 조각들이 각자 옳아도 이어지지 않으면 아무것도 아니다
## (docs/design/22-guild-base.md §22.1).

const GuildScript := preload("res://src/core/guild/guild.gd")
const GateScript := preload("res://src/core/gate/gate.gd")
const ExpeditionScript := preload("res://src/core/guild/expedition.gd")

const _SEED := 31


func _guild() -> Guild:
	return GuildScript.create_starting(_SEED)


func _gate() -> Gate:
	return GateScript.new("gate_0", "무너진 지하도", GateRank.Kind.E, _SEED)


func _start(guild: Guild, deployed: Array[String]) -> Expedition:
	var expedition: Expedition = ExpeditionScript.new(guild, _gate())
	expedition.deploy(deployed)
	return expedition


# ---------------------------------------------------------------- 편성 단계


func test_cannot_enter_before_deploying() -> void:
	var expedition: Expedition = ExpeditionScript.new(_guild(), _gate())
	assert_null(expedition.enter(), "편성 없이 들어갈 수 없다")


func test_deploy_rejects_over_capacity() -> void:
	var guild := _guild()
	var expedition: Expedition = ExpeditionScript.new(guild, _gate())
	assert_false(expedition.deploy(guild.member_ids()), "전원 출전은 정원을 넘는다")


## 데려갈 자를 고르는 것이 곧 남길 자를 고르는 것이다.
func test_garrison_is_everyone_not_deployed() -> void:
	var guild := _guild()
	var deployed: Array[String] = [guild.members[0].id, guild.members[1].id]
	var expedition := _start(guild, deployed)
	var garrison := expedition.garrison_ids()
	assert_eq(garrison.size(), guild.members.size() - deployed.size())
	for member_id in deployed:
		assert_false(garrison.has(member_id))


# ---------------------------------------------------------------- 진입


## 판 위의 말은 하나이고, 그 말이 우리 스쿼드여야 한다.
func test_entering_swaps_in_the_formed_squad() -> void:
	var guild := _guild()
	var deployed: Array[String] = [guild.members[0].id, guild.members[1].id]
	var expedition := _start(guild, deployed)
	var run := expedition.enter()

	assert_not_null(run)
	assert_eq(run.player.threat, expedition.squad.threat(), "편성한 전투력이 판에 올라간다")
	assert_eq(run.player.agility, expedition.squad.agility(), "편성한 민첩이 판에 올라간다")
	assert_eq(int(run.player.kind), int(Actor.Kind.PLAYER_SQUAD))
	assert_eq(run.graph.find_actor_room(run.player), run.player_room_id())


func test_entering_starts_at_the_entrance() -> void:
	var guild := _guild()
	var expedition := _start(guild, [guild.members[0].id] as Array[String])
	var run := expedition.enter()
	assert_eq(int(run.player_room().kind), int(Room.Kind.ENTRANCE))


func test_only_one_player_actor_on_the_board() -> void:
	var guild := _guild()
	var expedition := _start(guild, [guild.members[0].id] as Array[String])
	var run := expedition.enter()
	var count := 0
	for room_id in run.graph.room_ids():
		for actor in run.graph.get_room(room_id).occupants():
			if actor.is_player():
				count += 1
	assert_eq(count, 1, "대원이 몇이든 판 위의 말은 하나다 (docs/design/14-squad.md §14.2)")


## 같은 게이트는 같은 판을 연다 — 편성이 달라도 구조는 그대로다.
func test_same_gate_gives_the_same_board_regardless_of_squad() -> void:
	var guild := _guild()
	var one := _start(guild, [guild.members[0].id] as Array[String]).enter()
	var other := _start(guild, [guild.members[1].id] as Array[String]).enter()
	assert_eq(one.blueprint.room_ids(), other.blueprint.room_ids())
	for id in one.blueprint.room_ids():
		assert_eq(one.blueprint.kind_of(id), other.blueprint.kind_of(id))


func test_cannot_deploy_twice() -> void:
	var guild := _guild()
	var expedition := _start(guild, [guild.members[0].id] as Array[String])
	expedition.enter()
	assert_false(expedition.deploy([guild.members[1].id] as Array[String]), "들어간 뒤에는 못 바꾼다")


# ---------------------------------------------------------------- 한 바퀴


func test_full_lap_changes_the_base() -> void:
	var guild := _guild()
	guild.assignment.assign(guild.members[2].id, Facility.Kind.WORKSHOP)
	guild.assignment.assign(guild.members[3].id, Facility.Kind.CONTACT_POINT)

	var before_funds := guild.funds
	var before_progress := guild.base_progress

	var expedition := _start(guild, [guild.members[0].id, guild.members[1].id] as Array[String])
	var run := expedition.enter()
	for room_id in run.reachable_room_ids():
		run.move_player(room_id)
		break

	var report := expedition.finish(ExpeditionReport.Outcome.ESCAPED)
	assert_not_null(report)
	assert_eq(report.turns, run.turn)

	var result := expedition.settle()
	assert_not_null(result)
	assert_true(guild.funds > before_funds, "갔다 오니 자금이 늘어 있다")
	assert_true(guild.base_progress > before_progress or guild.base_level > 1, "아지트가 달라져 있다")
	assert_eq(guild.prospects.size(), GuildBalance.PROSPECTS_PER_CONTACT_STAFF)
	assert_eq(int(expedition.stage), int(Expedition.Stage.SETTLED))


func test_settling_twice_does_nothing() -> void:
	var guild := _guild()
	var expedition := _start(guild, [guild.members[0].id] as Array[String])
	expedition.enter()
	expedition.finish(ExpeditionReport.Outcome.ESCAPED)
	expedition.settle()
	var funds := guild.funds
	assert_null(expedition.settle(), "두 번째 정산은 없다")
	assert_eq(guild.funds, funds)


func test_cannot_settle_before_finishing() -> void:
	var guild := _guild()
	var expedition := _start(guild, [guild.members[0].id] as Array[String])
	expedition.enter()
	assert_null(expedition.settle())


func test_cannot_finish_twice() -> void:
	var guild := _guild()
	var expedition := _start(guild, [guild.members[0].id] as Array[String])
	expedition.enter()
	expedition.finish(ExpeditionReport.Outcome.ESCAPED)
	assert_null(expedition.finish(ExpeditionReport.Outcome.DOWNED))


func test_each_expedition_gets_its_own_number() -> void:
	var guild := _guild()
	var one: Expedition = ExpeditionScript.new(guild, _gate())
	var other: Expedition = ExpeditionScript.new(guild, _gate())
	assert_ne(one.id, other.id, "같은 게이트에 두 번 가도 번호는 갈린다")


## 정보실 인원을 데려가면 다음 목록이 도로 흐려진다.
func test_taking_the_intel_staff_dims_the_next_board() -> void:
	var guild := _guild()
	guild.assignment.assign(guild.members[0].id, Facility.Kind.INTEL_ROOM)
	guild.assignment.assign(guild.members[1].id, Facility.Kind.INTEL_ROOM)
	assert_eq(guild.gate_disclosure(), GateDisclosure.Level.MAPPED)

	var expedition := _start(guild, [guild.members[0].id] as Array[String])
	assert_eq(
		guild.gate_disclosure(expedition.deployed_ids()),
		GateDisclosure.Level.SURVEYED,
		"한 명을 데려가면 한 단계 흐려진다"
	)


func test_failed_run_pays_nothing_but_still_advances() -> void:
	var guild := _guild()
	guild.assignment.assign(guild.members[2].id, Facility.Kind.WORKSHOP)
	var expedition := _start(guild, [guild.members[0].id] as Array[String])
	expedition.enter()
	expedition.finish(ExpeditionReport.Outcome.DOWNED)
	var result := expedition.settle()
	assert_eq(result.funds_gained, 0)
	assert_true(result.base_progress_gained > 0)
