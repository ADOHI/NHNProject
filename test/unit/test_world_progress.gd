extends GutTest
## 세계가 **걸어온 길**이 저장을 건너는가.
##
## docs/design/37-meta-loop.md §37.5.
##
## 이 시험이 막는 것은 하나다 — **껐다 켜면 지금까지 돈 틱이 없던 일이 되는 것.**
## 오류가 안 나고 화면도 멀쩡해서, 시험이 없으면 아무도 모른다
## ([36](36-settlement.md) §36.5.6 이 겪은 것과 같은 종류다).

const _SEED := 20260819

## 인구를 작게 쓴다. 여기서 볼 것은 3000명이 아니라 **되감기가 맞는가**다.
const _POPULATION := 400


func _world() -> NpcWorld:
	return NpcWorld.create(_SEED, _POPULATION)


func _guild(world: NpcWorld) -> Guild:
	return Guild.create_starting(_SEED, "시험 길드", world)


func _report(guild: Guild, outcome: ExpeditionReport.Outcome, number: int = 0) -> ExpeditionReport:
	var went: Array[String] = []
	var stayed: Array[String] = []
	for slot in guild.members.size():
		if slot < guild.members.size() - 1:
			went.append(guild.members[slot].id)
		else:
			stayed.append(guild.members[slot].id)
	return ExpeditionReport.new(
		"exp_%d" % number,
		Gate.new("gate_0", "붉은 회랑", GateRank.Kind.C, _SEED),
		outcome,
		5,
		went,
		stayed
	)


## 세계의 지문. 되감은 세계가 같은가를 이 셋으로 본다.
func _fingerprint(world: NpcWorld) -> Array[int]:
	var affinity := 0
	for slot in world.graph.size():
		affinity += world.graph.slot_affinity(slot)
	return [world.graph.size(), world.ledger.size(), affinity]


# ---------------------------------------------------------------- 한 틱


func test_a_step_round_trips() -> void:
	var step := WorldStep.new(7, PackedInt32Array([3, 9]), PackedInt32Array([11]), true, 4)
	var back := WorldStep.from_dict(step.to_dict())
	assert_eq(back.events, 7)
	assert_eq(Array(back.went), [3, 9])
	assert_eq(Array(back.stayed), [11])
	assert_true(back.downed)
	assert_eq(back.tick, 4)


func test_a_step_with_nobody_in_it_is_refused() -> void:
	# 그런 틱은 애초에 기록되지 않는다. 손으로 고친 파일이 되감기를 어긋내면 안 된다.
	assert_null(WorldStep.from_dict({}))
	assert_null(WorldStep.from_dict({"events": 10, "went": []}))


func test_a_step_survives_json() -> void:
	# **JSON 을 지나면 수가 전부 실수로 돌아온다.** 그것을 안 접으면 인물 번호가 깨진다.
	var step := WorldStep.new(10, PackedInt32Array([1, 2, 3]), PackedInt32Array(), false, 2)
	var text := JSON.stringify(step.to_dict())
	var back := WorldStep.from_dict(JSON.parse_string(text) as Dictionary)
	assert_eq(Array(back.went), [1, 2, 3])
	assert_eq(back.events, 10)


func test_a_step_does_nothing_to_an_unbuilt_world() -> void:
	var step := WorldStep.new(10, PackedInt32Array([0]), PackedInt32Array(), true, 0)
	assert_eq(step.apply_to(null), 0)
	assert_eq(step.apply_to(NpcWorld.new(_SEED, _POPULATION)), 0)


# ---------------------------------------------------------------- 걸어온 길


func test_settling_records_a_step() -> void:
	var world := _world()
	var guild := _guild(world)
	assert_true(guild.world_progress.is_empty())
	ExpeditionAftermath.apply(guild, _report(guild, ExpeditionReport.Outcome.ESCAPED))
	assert_eq(guild.world_progress.tick_count(), 1)
	assert_eq(guild.world_progress.events_rolled(), ExpeditionAftermath.WORLD_EVENTS)


func test_a_step_that_touches_nobody_is_not_recorded() -> void:
	# 세계 없이 만든 길드는 대원이 인물 번호를 안 갖는다.
	var guild := Guild.create_starting(_SEED, "세계 없는 길드")
	guild.world = _world()
	assert_eq(ExpeditionAftermath.apply(guild, _report(guild, ExpeditionReport.Outcome.DOWNED)), 0)
	assert_true(guild.world_progress.is_empty())


func test_replaying_rebuilds_the_same_world() -> void:
	var lived := _world()
	var guild := _guild(lived)
	for run in 4:
		var outcome := (
			ExpeditionReport.Outcome.DOWNED if run % 2 == 0 else ExpeditionReport.Outcome.ESCAPED
		)
		ExpeditionAftermath.apply(guild, _report(guild, outcome, run), run)

	var rebuilt := _world()
	assert_eq(guild.world_progress.replay(rebuilt), 4)
	assert_eq(_fingerprint(rebuilt), _fingerprint(lived))


func test_a_pristine_world_is_not_the_lived_one() -> void:
	# **되감기가 실제로 일을 한다는 증거다.** 이 단정이 없으면 위 시험이
	# 「아무것도 안 해도 통과」할 수 있다.
	var lived := _world()
	var guild := _guild(lived)
	ExpeditionAftermath.apply(guild, _report(guild, ExpeditionReport.Outcome.DOWNED))
	assert_ne(_fingerprint(_world()), _fingerprint(lived))


func test_progress_round_trips() -> void:
	var world := _world()
	var guild := _guild(world)
	ExpeditionAftermath.apply(guild, _report(guild, ExpeditionReport.Outcome.DOWNED), 0)
	ExpeditionAftermath.apply(guild, _report(guild, ExpeditionReport.Outcome.ESCAPED, 1), 1)

	var text := JSON.stringify(guild.world_progress.to_dict())
	var back := WorldProgress.from_dict(JSON.parse_string(text) as Dictionary)
	assert_eq(back.tick_count(), 2)
	assert_eq(back.events_rolled(), guild.world_progress.events_rolled())

	var rebuilt := _world()
	back.replay(rebuilt)
	assert_eq(_fingerprint(rebuilt), _fingerprint(world))


func test_an_empty_progress_leaves_the_world_alone() -> void:
	var world := _world()
	var before := _fingerprint(world)
	assert_eq(WorldProgress.new().replay(world), 0)
	assert_eq(_fingerprint(world), before)


# ---------------------------------------------------------------- 봉투 v2


func test_the_envelope_carries_the_world() -> void:
	var world := _world()
	var guild := _guild(world)
	for run in 3:
		ExpeditionAftermath.apply(guild, _report(guild, ExpeditionReport.Outcome.ESCAPED, run), run)

	var data := GameSave.capture(guild, _SEED)
	assert_eq(int(data[GameSave.KEY_VERSION]), 2)
	assert_true(data.has(GameSave.KEY_WORLD))

	# **인구를 봉투에 담지 않으므로** 갓 선 세계를 직접 준다. 진짜 불러오기는
	# 씨앗에서 3000명을 세우고, 여기서 볼 것은 되감기지 인구가 아니다.
	var text := JSON.stringify(data)
	var result := GameSave.restore(JSON.parse_string(text) as Dictionary, true, _world())
	assert_true(result.is_ok())
	assert_eq(result.guild.world_progress.tick_count(), 3)
	assert_eq(_fingerprint(result.world), _fingerprint(world))


func test_an_old_save_still_opens_with_a_pristine_world() -> void:
	# 봉투 v1 에는 걸어온 길이 없다. **그 파일을 버리지 않는다** (§34.4.3).
	var guild := _guild(_world())
	var data := GameSave.capture(guild, _SEED)
	data[GameSave.KEY_VERSION] = 1
	data.erase(GameSave.KEY_WORLD)
	var result := GameSave.restore(data, true, _world())
	assert_true(result.is_ok())
	assert_true(result.guild.world_progress.is_empty())
	assert_eq(_fingerprint(result.world), _fingerprint(_world()))


func test_a_save_from_a_newer_build_is_still_refused() -> void:
	var guild := _guild(_world())
	var data := GameSave.capture(guild, _SEED)
	data[GameSave.KEY_VERSION] = GameSave.VERSION + 1
	assert_eq(GameSave.restore(data, false).status, SaveResult.Status.VERSION_AHEAD)


func test_a_broken_world_block_does_not_kill_the_save() -> void:
	var guild := _guild(_world())
	var data := GameSave.capture(guild, _SEED)
	data[GameSave.KEY_WORLD] = {"steps": ["말이 아니다", 7, {"events": 3}]}
	var result := GameSave.restore(data, false)
	assert_true(result.is_ok())
	assert_true(result.guild.world_progress.is_empty())
