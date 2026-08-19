extends SceneTree
## 조우가 실제로 어떻게 풀리는지 재는 개발 도구. **헤드리스다 — 창을 안 띄운다.**
##
##     godot --headless --path . -s res://tools/survey_encounter.gd
##
## docs/design/35-encounter.md §35.4.4 · §35.7 의 표를 이 파일이 낸다
## (docs/conventions.md §6.3 — 표를 적으면 그 표를 내는 명령을 같이 적는다).
##
## ## 한 턴만 묻는 시험은 이어 도는 것을 못 본다
##
## 턴 루프 레인이 캡처로 여덟 턴을 걸어 보고서야 **신중한 NPC 가 멈춰 서는 것**을
## 잡았다 (docs/design/33-turn-loop.md §33.4). 시험은 "한 턴에 무엇을 내는가"를
## 묻고, 그 결함은 **여러 턴을 이어 보아야** 보인다.
##
## 조우는 여러 턴에 걸치는 것이 설계의 핵심이므로(§5.8 *"전투 지속"*)
## 여기서 재는 것도 **이어 돈 판**이다.
##
## ## 창을 안 띄우는 이유
##
## CLAUDE.md GPU 절 3 — 캡처마다 GL 컨텍스트를 새로 만든다. 조우 절차는 코어라
## 화면에 나올 것이 아직 없고, 그러면 헤드리스로 충분하다.

## 이어 돌리는 턴 수.
const TURNS := 14

## 판 크기와 시드. **박아 둔다** — 같은 명령이 같은 표를 내야 §6.3 의 규칙을 지킨다.
const BOARD_SIZE := 2
const BOARD_SEED := 4242

## 성향 표에서 축을 흔드는 값들.
const AXIS_STEPS := [-100, -50, 0, 50, 100]

## 도주 표에서 재는 짐.
const LOAD_STEPS := [0, 2, 4, 6, 8]


func _initialize() -> void:
	_report_run()
	_report_temperaments()
	_report_flight()
	quit()


# ---------------------------------------------------------------- 이어 돈 판


## 실제 판을 이어 돌린다. **플레이어도 성향을 갖고 스스로 고른다.**
##
## 사람이 조작하는 자리를 비워 두면 조우가 언제나 「대치 대 무엇」이 되어
## 분기 셋 중 하나만 재게 된다. 그래서 여기서는 플레이어도 `EncounterPlanner` 가 민다 —
## **화면이 앞으로 물어볼 것을 대신 고르는 것**이고, 그래서 태세는
## 도착할 방을 보고 정한다 (§35.1.2 — 상황을 모르는 채로 고른다).
func _report_run() -> void:
	var run := SampleDungeons.create_run(BOARD_SEED, BOARD_SIZE)
	run.planner.set_temperament(run.player.id, _temper(NpcAxis.Kind.RECKLESS, 60))
	_add_rival(run)

	print("== 이어 돈 판 (시드 %d, 크기 %d) ==" % [BOARD_SEED, BOARD_SIZE])
	print("%-4s %-14s %-6s %s" % ["턴", "스쿼드", "사건", "조우"])
	var seen := 0
	for step in TURNS:
		if run.finished:
			break
		_take_turn(run)
		var report := run.last_report
		if report == null:
			break
		seen += report.outcomes.size()
		print(
			(
				"%-4d %-14s %-6d %s"
				% [
					report.turn,
					_room_name(run, run.player_room_id()),
					report.events.size(),
					_outcome_text(report)
				]
			)
		)
	print("조우 %d 회 · 판이 끝났나: %s · 제압당했나: %s" % [seen, run.finished, run.defeated])
	print("")


## 한 턴을 건다. 의도는 NPC 와 같은 길로 뽑고, 태세만 따로 정한다.
func _take_turn(run: DungeonRun) -> void:
	var intent := run.planner.plan_for(run.player, run.player_room_id())
	var target := intent.target_room_id if intent.is_move() else run.player_room_id()
	intent.stance = _stance_for(run, target)
	run.submit_intent(intent)
	run.resolve_turn()


## 그 방에 갔을 때 무엇으로 맞을 것인가. **거기 있을 사람들을 보고 정한다.**
func _stance_for(run: DungeonRun, room_id: String) -> EncounterChoice.Kind:
	var room := run.graph.get_room(room_id)
	if room == null:
		return EncounterChoice.Kind.STAND
	var here := room.occupants()
	if not here.has(run.player):
		here.append(run.player)
	if not Encounter.is_encounter(here):
		return EncounterChoice.Kind.STAND
	var stakes := EncounterStakes.of(room.kind, run.loot.value_at(room_id))
	var plan := run.encounter_planner.plan_for(
		run.player, here, stakes, run.encounters.allies_of(run.player.id), 0
	)
	return plan.choice


## 경쟁자 하나를 스쿼드 옆에 더 놓는다.
##
## 표본 판은 경쟁자를 하나만 풀어 두는데(`SampleDungeons._populate`), 그러면
## **탐험가끼리의 조우가 판에 따라 아예 안 난다.** 재려는 것이 그것이므로 하나 더 놓는다.
func _add_rival(run: DungeonRun) -> void:
	var mate := Actor.new("shiv", "쥐새끼 신", Actor.Kind.NPC_EXPLORER, 5, 3)
	if run.graph.place_actor(mate, run.player_room_id()):
		run.planner.set_temperament(mate.id, _temper(NpcAxis.Kind.RECKLESS, -60))


func _outcome_text(report: TurnReport) -> String:
	var parts: Array[String] = []
	for outcome in report.outcomes:
		var choices: Array[String] = []
		for actor_id in outcome.choices:
			choices.append("%s=%s" % [actor_id, EncounterChoice.label(outcome.choice_of(actor_id))])
		var tail := ""
		if not outcome.subdued_ids.is_empty():
			tail += " 제압:%s" % ", ".join(outcome.subdued_ids)
		if not outcome.slain_ids.is_empty():
			tail += " 죽음:%s" % ", ".join(outcome.slain_ids)
		if not outcome.fled_ids.is_empty():
			tail += " 도주:%s" % ", ".join(outcome.fled_ids)
		parts.append("%s[%s]%s" % [outcome.room_name, " ".join(choices), tail])
	return "-" if parts.is_empty() else " / ".join(parts)


func _room_name(run: DungeonRun, room_id: String) -> String:
	var room := run.graph.get_room(room_id)
	return room.display_name if room != null else "?"


# ---------------------------------------------------------------- 성향


## 축 하나를 흔들면 무엇을 고르는가. **근거가 함께 나와야 손볼 수 있다** (§35.4.4).
func _report_temperaments() -> void:
	var run := _standoff()
	var rival := _rival_of(run)
	print("== 성향이 무엇을 고르는가 (금고 · 스쿼드 8 vs 경쟁자 6 · 판돈 4) ==")
	print("%-10s %6s %-6s %s" % ["축", "값", "고른 것", "근거"])
	for axis in [NpcAxis.Kind.RECKLESS, NpcAxis.Kind.GOOD, NpcAxis.Kind.LOYAL]:
		for value in AXIS_STEPS:
			run.planner.set_temperament(rival.id, _temper(axis, value))
			var plan := _plan_in(run, rival)
			print(
				(
					"%-10s %6d %-6s %s"
					% [NpcAxis.label(axis), value, EncounterChoice.label(plan.choice), plan.reason]
				)
			)
	print("")

	print("== 같은 축에 몬스터를 하나 더 놓으면 (사냥개 5) ==")
	run.graph.place_actor(Actor.new("hound", "사냥개", Actor.Kind.MONSTER, 5, 0), "vault")
	for value in AXIS_STEPS:
		run.planner.set_temperament(rival.id, _temper(NpcAxis.Kind.LOYAL, value))
		var plan := _plan_in(run, rival)
		print(
			(
				"%-10s %6d %-6s %s"
				% [
					NpcAxis.label(NpcAxis.Kind.LOYAL),
					value,
					EncounterChoice.label(plan.choice),
					plan.reason
				]
			)
		)
	print("")


func _plan_in(run: DungeonRun, actor: Actor) -> EncounterPlan:
	var room := run.graph.get_room("vault")
	var stakes := EncounterStakes.of(room.kind, run.loot.value_at("vault"))
	return run.encounter_planner.plan_for(actor, room.occupants(), stakes, [] as Array[String], 0)


# ---------------------------------------------------------------- 도주


## 짐과 방이 도주 확률을 어떻게 바꾸는가 (§35.2.2 · E5).
func _report_flight() -> void:
	var run := _standoff()
	var rival := _rival_of(run)
	var chasers: Array[Actor] = [_squad_of(run)]
	print("== 도주 성공 확률 (민첩 같음 · 쫓는 자 하나) ==")
	print("%-6s %8s %8s %8s" % ["짐", "보통 방", "함정방", "쫓는 자 없음"])
	var carried := 0
	for load in LOAD_STEPS:
		run.haul.add(rival.id, load - carried)
		carried = load
		var plain := EncounterStakes.of(Room.Kind.TREASURE, 0)
		var hazard := EncounterStakes.of(Room.Kind.HAZARD, 0)
		print(
			(
				"%-6d %8d %8d %8d"
				% [
					load,
					run.encounters.flight_chance(rival, chasers, plain),
					run.encounters.flight_chance(rival, chasers, hazard),
					run.encounters.flight_chance(rival, [] as Array[Actor], plain)
				]
			)
		)
	print("")


# ---------------------------------------------------------------- 판 세우기


## 금고에서 마주 선 둘. 성향과 도주를 재는 고정 판이다.
func _standoff() -> DungeonRun:
	var blueprint := DungeonBlueprint.new()
	blueprint.add_room("hall", "큰 방", 0, Room.Kind.ENTRANCE)
	blueprint.add_room("vault", "금고", 0, Room.Kind.TREASURE)
	blueprint.connect_rooms("hall", "vault")
	var graph := blueprint.build()
	var squad := Actor.new("squad", "우리 스쿼드", Actor.Kind.PLAYER_SQUAD, 8, 3)
	graph.place_actor(squad, "vault")
	graph.place_actor(Actor.new("rival", "칼날의 요한", Actor.Kind.NPC_EXPLORER, 6, 3), "vault")
	var run := DungeonRun.new(blueprint, graph, squad, BOARD_SEED)
	for room_id in graph.room_ids():
		run.loot.put(room_id, 0)
	run.loot.put("vault", 4)
	return run


func _rival_of(run: DungeonRun) -> Actor:
	for actor in run.graph.get_room("vault").occupants():
		if actor.id == "rival":
			return actor
	return null


func _squad_of(run: DungeonRun) -> Actor:
	return run.player


## 한 축만 세운 성향 여섯. 나머지는 중립이다.
func _temper(axis: NpcAxis.Kind, value: int) -> Array[int]:
	var traits: Array[int] = []
	for index in NpcAxis.count():
		traits.append(value if index == int(axis) else 0)
	return traits
