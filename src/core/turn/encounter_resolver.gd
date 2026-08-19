class_name EncounterResolver
extends RefCounted
## **조우 절차 본체** (M5). 마주친 사람들의 선택을 모아 **동시에** 푼다.
##
## docs/design/05-rules.md §5.8 · docs/design/35-encounter.md.
##
## ## 선택을 전부 모은 뒤에 판정을 시작한다
##
## §5.8 이 *"각자 행동 결정 — 동시 · 상대의 선택을 모름"* 이라고 못 박았다.
## **이 한 줄이 조우를 게임으로 만든다.** 상대의 선택을 알고 고르면 계산이지 심리전이 아니다.
##
## 그래서 `_collect_choices()` 가 끝나기 전에는 아무 판정도 시작하지 않는다.
## 판정 도중에 선택이 바뀌지도 않는다 — `outcome.choices` 는 한 번 채워지고 읽히기만 한다.
##
## ## 한 턴에 결판나지 않는다
##
## §5.8 의 분기 판정 첫 줄이 *"전투 지속 -> 다음 턴에도 조우 상태"* 다.
## 한 턴에 끝내면 §5.8 이 얻으려던 것이 통째로 사라진다 —
## *"버티면 기회가 생긴다"* · *"도망다니는 장면이 가장 방송적인 그림이다"*.
##
## 그래서 한 턴의 전투는 **밀림(pressure)** 만 쌓는다. 모양을
## docs/design/28-combat.md §28.5 의 무너짐 눈금에 맞춰 두었다 —
## 실시간 전투가 나중에 붙을 때 **눈금을 그대로 이어받을 수 있어야** 한다 (§35.6).
##
## ## 판에서 치우지 않는다
##
## 제압과 죽음을 여기서 처리하면 해결 순서 3단계 도중에 주체가 사라지고,
## 같은 단계의 뒷부분이 없는 주체를 훑게 된다. **누가 무너졌는지만 적어 보내고**
## 실제 정산은 4단계(`TurnResolver._settle_results()`)가 한다 (§33.1).
## 예외는 도주뿐이다 — 도주는 정산이 아니라 **이동**이라 3단계의 일이다.

## 밀림이 이만큼 쌓이면 무너진다. **잠정** (§35.7).
##
## 전투력 차 4 인 싸움이 3턴이면 결판난다. 그 사이에 제3자가 오거나 도망칠 수 있어야
## §5.8 의 *"버티면 기회가 생긴다"* 가 성립한다. 굴려 보고 정한다.
const BREAK_PRESSURE := 12

## 조우에 안 낀 턴에 빠지는 밀림. docs/design/28-combat.md §28.20.35 의 감쇠와 같은 뜻이다.
const PRESSURE_RECOVERY := 6

## 도주 성공 확률의 기본값(%). **쫓는 자가 있을 때만 쓴다** — 없으면 무조건 성공한다.
const FLIGHT_BASE := 50

## 민첩 1 차이가 도주 확률을 흔드는 폭(%p).
const FLIGHT_PER_AGILITY := 10

## 짐 1 이 도주 확률을 깎는 폭(%p). §5.9 가 탈출에 대해 적은 것과 같은 논리다 —
## 챙긴 것이 발을 묶어야 *"다 챙기고 문 앞에서 죽는 것"* 이 성립한다.
const FLIGHT_PER_LOAD := 3

## 확률의 아래위 한계. **확신을 주지 않는다** —
## docs/design/05-rules.md §5.10 이 *"플레이어가 확률의 방향을 읽을 수 있어야"* 라고 적었지
## 확정을 주라고 적지 않았다.
const FLIGHT_MIN := 5
const FLIGHT_MAX := 95

## 힘을 셀 때 쓰는 눈금. 태세 계수가 백분율이라 힘도 100 배로 센다.
const WEIGHT_SCALE := 100

var _graph: DungeonGraph
var _loot: LootTable
var _haul: Haul
var _planner: EncounterPlanner
var _rng := RandomNumberGenerator.new()

## 주체 id -> 쌓인 밀림.
var _pressure: Dictionary = {}

## 주체 id -> 이번 판에 무너진 횟수. **부상의 자리다** (§35.7).
var _downs: Dictionary = {}

## 주체 id -> **직전 턴에** 함께한 자들. 배신(E8)이 이것을 본다.
var _allies: Dictionary = {}

## 이번 턴에 함께한 자들. 턴이 끝날 때 위로 옮겨 간다.
var _allies_next: Dictionary = {}


func _init(
	graph: DungeonGraph,
	loot: LootTable,
	haul: Haul,
	planner: EncounterPlanner,
	resolver_seed: int = 0
) -> void:
	_graph = graph
	_loot = loot
	_haul = haul
	_planner = planner
	_rng.seed = resolver_seed


## 조우 하나를 푼다. **이 함수의 본문이 곧 §5.8 의 흐름도다.**
##
## `stances` 는 주체 id -> 태세이고, `retreats` 는 주체 id -> 이번 턴에 떠나온 방이다.
## 떠나온 방을 받는 이유는 도주가 **온 곳으로** 가기 때문이다 (§35.2.2).
func resolve(
	turn: int, encounter: Encounter, here: Array[Actor], stances: Dictionary, retreats: Dictionary
) -> EncounterOutcome:
	var outcome := EncounterOutcome.new(turn, encounter)
	var room := _graph.get_room(encounter.room_id)
	var kind := room.kind if room != null else Room.Kind.EMPTY
	outcome.stakes = EncounterStakes.of(kind, _loot.value_at(encounter.room_id))

	_collect_choices(outcome, here, stances, encounter.has_monsters())
	_resolve_negotiation(outcome, here, room)
	_resolve_flight(outcome, here, retreats, room)
	_resolve_fight(outcome, here, room)
	_mark_relations(outcome, here)
	_remember_allies(outcome)
	outcome.continues = _still_standing(outcome, here)
	return outcome


## 턴을 닫는다. **조우에 안 낀 자의 밀림이 빠지고**, 이번 턴의 동료가 직전 턴이 된다.
##
## 해결기가 조우마다 불리므로 이것을 `resolve()` 안에서 할 수 없다 —
## 한 턴에 조우가 둘이면 첫 조우가 둘째 조우의 참가자를 「없는 사람」으로 읽는다.
func end_turn(present_ids: Array[String]) -> void:
	var present: Dictionary = {}
	for actor_id in present_ids:
		present[actor_id] = true
	for actor_id in _pressure.keys():
		if present.has(actor_id):
			continue
		var left := pressure_of(actor_id) - PRESSURE_RECOVERY
		if left <= 0:
			_pressure.erase(actor_id)
		else:
			_pressure[actor_id] = left
	_allies = _allies_next
	_allies_next = {}


func pressure_of(actor_id: String) -> int:
	return int(_pressure.get(actor_id, 0))


func downs_of(actor_id: String) -> int:
	return int(_downs.get(actor_id, 0))


## 직전 턴에 함께한 자들. 배신 판정과 시험이 읽는다.
func allies_of(actor_id: String) -> Array[String]:
	var found: Array[String] = []
	for id in _allies.get(actor_id, [] as Array[String]):
		found.append(str(id))
	return found


## 그 주체가 도망칠 확률(%). **화면이 이것을 읽어도 된다.**
##
## docs/design/05-rules.md §5.10 이 *"플레이어가 확률의 방향을 읽을 수 있어야"* 라고 적었다.
## 정확한 수치가 아니어도 「지금은 무겁다」 정도는 드러나야 하고,
## 그러려면 판정과 **같은 함수**가 그 값을 내야 한다. 화면이 따로 세면 둘이 갈린다.
func flight_chance(actor: Actor, chasers: Array[Actor], stakes: EncounterStakes) -> int:
	if chasers.is_empty():
		return 100
	var fastest := 0
	for chaser in chasers:
		fastest = maxi(fastest, chaser.agility)
	var chance := FLIGHT_BASE + (actor.agility - fastest) * FLIGHT_PER_AGILITY
	chance -= _haul.carried_by(actor.id) * FLIGHT_PER_LOAD
	chance += stakes.flight_bonus
	return clampi(chance, FLIGHT_MIN, FLIGHT_MAX)


# ---------------------------------------------------------------- 선택


## 누가 무엇을 골랐는가. **여기가 끝나기 전에는 아무 판정도 시작하지 않는다.**
##
## 태세가 대치(STAND)라는 것은 **안 골랐다**는 뜻이다 (`EncounterChoice` 주석).
## 그때 누가 대신 고르는지가 주체마다 다르다.
##
## | 주체 | 안 골랐으면 |
## | --- | --- |
## | 몬스터 | **언제나 전투.** 말을 걸 상대가 아니다 |
## | NPC 탐험가 | `EncounterPlanner` 가 성향 x 상황으로 고른다 (§35.4) |
## | 플레이어 | **대치.** 화면이 안 물어봤으면 아무것도 안 한 것이다 |
func _collect_choices(
	outcome: EncounterOutcome, here: Array[Actor], stances: Dictionary, has_monsters: bool
) -> void:
	for actor in here:
		var chosen: EncounterChoice.Kind = stances.get(actor.id, EncounterChoice.Kind.STAND)
		if actor.kind == Actor.Kind.MONSTER:
			chosen = EncounterChoice.Kind.FIGHT
		elif chosen == EncounterChoice.Kind.STAND and not actor.is_player():
			var plan := _planner.plan_for(
				actor, here, outcome.stakes, allies_of(actor.id), downs_of(actor.id)
			)
			outcome.plans.append(plan)
			chosen = plan.choice
		outcome.choices[actor.id] = EncounterChoice.settle(chosen, has_monsters)


# ---------------------------------------------------------------- 협상


## **양쪽이 다 골라야 성립한다. 난수가 없다** (§35.2.1).
##
## §5.10 이 *"협상 성립 확률"* 을 적었지만 확률은 **NPC 가 무엇을 고를까**에만 둔다.
## 성립을 확률로 하면 **옳게 읽고도 실패한다** — docs/design/03-core-loop.md §3.4 가
## *"확률은 내 탓을 흐릴 수 있다"* 고 경고한 바로 그 자리다.
##
## 성립하면 **방에 남은 귀중품을 나눈다.** 그것이 거래의 내용이고,
## 귀중품방에서 협상이 실제로 값을 갖게 하는 유일한 장치다 (E5 · §35.3.2).
func _resolve_negotiation(outcome: EncounterOutcome, here: Array[Actor], room: Room) -> void:
	var talkers := _who_chose(outcome, here, EncounterChoice.Kind.NEGOTIATE)
	if talkers.size() < 2:
		return
	for actor in talkers:
		outcome.negotiated_ids.append(actor.id)

	var share := outcome.stakes.share_for(talkers.size())
	if share > 0:
		_loot.take(outcome.room_id)
		_loot.put(outcome.room_id, outcome.stakes.remainder_for(talkers.size()))
		for actor in talkers:
			_haul.add(actor.id, share)
			outcome.spoils[actor.id] = share
	var lead: Actor = talkers[0]
	outcome.events.append(
		GameEvent.new(
			outcome.turn,
			GameEvent.Kind.NEGOTIATED,
			lead,
			room,
			share,
			_ids_except(talkers, lead.id)
		)
	)


# ---------------------------------------------------------------- 도주


## **쫓는 자가 없으면 무조건 성공한다** (§35.2.2).
##
## 이것이 있어야 동시 선택이 실제로 무겁다 — 상대가 도망칠 것 같으면 안 쫓아도 되고,
## 쫓기로 했는데 상대가 이미 없으면 헛수고를 한 것이다.
##
## 성공하면 **온 곳으로** 간다. 아무 방향이 아니라 온 곳인 이유는,
## 도망친 곳을 플레이어가 알 수 있어야 추격이 성립하기 때문이다.
## 사라지는 것은 연출이 아니라 **정보의 손실**이다.
func _resolve_flight(
	outcome: EncounterOutcome, here: Array[Actor], retreats: Dictionary, room: Room
) -> void:
	var chasers := _who_means_harm(outcome, here)
	for actor in here:
		if outcome.choice_of(actor.id) != EncounterChoice.Kind.FLEE:
			continue
		var target := _retreat_room(actor, str(retreats.get(actor.id, "")))
		if target.is_empty():
			# 갈 데가 없다. **갇힌 것이지 안 도망친 것이 아니다.**
			outcome.failed_flight_ids.append(actor.id)
			continue
		if _rng.randi_range(1, 100) > flight_chance(actor, chasers, outcome.stakes):
			outcome.failed_flight_ids.append(actor.id)
			continue
		if not _graph.move_actor(actor, target):
			outcome.failed_flight_ids.append(actor.id)
			continue
		outcome.fled_ids.append(actor.id)
		if outcome.stakes.flight_clears_escape:
			# **E5 — 탈출 지점에서 물러나면 처음부터다** (§35.3.2).
			outcome.escape_reset_ids.append(actor.id)
		outcome.events.append(
			GameEvent.new(
				outcome.turn, GameEvent.Kind.FLED, actor, room, 0, _ids_except(chasers, actor.id)
			)
		)


## 어디로 물러나는가. 온 곳으로 갈 수 있으면 그리로, 아니면 **가장 덜 위험한 이웃**으로.
##
## 사방이 다 막혔으면 빈 문자열이고 그것이 곧 도주 실패다.
func _retreat_room(actor: Actor, came_from: String) -> String:
	var from_id := _graph.find_actor_room(actor)
	if from_id.is_empty():
		return ""
	var options := _graph.traversable_neighbors(from_id, actor.agility)
	if options.is_empty():
		return ""
	if options.has(came_from):
		return came_from
	var best := ""
	var best_threat := 0
	for room_id in options:
		var threat := _graph.threat_at(room_id)
		if best.is_empty() or threat < best_threat:
			best = room_id
			best_threat = threat
	return best


# ---------------------------------------------------------------- 전투


## 편을 갈라 힘을 견주고 **밀림을 쌓는다.** 결판은 밀림이 문턱을 넘을 때만 난다.
##
## **E3 의 답이 여기 있다** — 태세 계수가 곱해질 뿐 「먼저 쳤다」는 항이 없다.
## 둘 다 전투를 골랐으면 둘 다 1.0 이라 힘 대 힘이고, 한쪽만 쳤을 때만 차이가 난다
## (§35.3.1).
func _resolve_fight(outcome: EncounterOutcome, here: Array[Actor], room: Room) -> void:
	var sides := _form_sides(outcome, here)
	if sides.size() < 2:
		return
	var forces: Dictionary = {}
	var top := 0
	for key in sides:
		var members: Array[Actor] = sides[key]
		var force := _force_of(outcome, members)
		forces[key] = force
		top = maxi(top, force)

	# **교착이면 아무도 안 이겼다.** 힘이 모두 같으면 밀림도 안 쌓이고
	# 조우는 다음 턴으로 이어진다 — §5.8 의 *"전투 지속"* 이 그것이다.
	var victors: Array[Actor] = []
	var pressed := false
	for key in sides:
		var members: Array[Actor] = sides[key]
		if int(forces[key]) == top:
			victors.append_array(members)
			continue
		pressed = true
		var gain := maxi(1, (top - int(forces[key])) / WEIGHT_SCALE)
		for actor in members:
			_press(outcome, actor, gain)
	if not pressed:
		return
	for actor in victors:
		outcome.victor_ids.append(actor.id)
	_note_fight(outcome, victors, room)


## 누가 누구와 한 편인가.
##
## | 편 | 언제 |
## | --- | --- |
## | 몬스터 | 언제나 하나. **몬스터끼리는 안 싸운다** |
## | 연합 | 둘 이상이 협력을 골랐을 때 (E9) |
## | 협상 | 협상이 성립한 자들. **서로 안 치기로 했으므로 한 편이다** |
## | 그 밖 | 각자 혼자 |
func _form_sides(outcome: EncounterOutcome, here: Array[Actor]) -> Dictionary:
	var cooperators := _who_chose(outcome, here, EncounterChoice.Kind.COOPERATE)
	var allied := cooperators.size() >= 2
	if allied:
		for actor in cooperators:
			outcome.allied_ids.append(actor.id)

	var sides: Dictionary = {}
	for actor in here:
		if outcome.fled_ids.has(actor.id):
			continue
		var key := actor.id
		if actor.kind == Actor.Kind.MONSTER:
			key = "*monsters"
		elif allied and outcome.choice_of(actor.id) == EncounterChoice.Kind.COOPERATE:
			key = "*allied"
		elif outcome.negotiated_ids.has(actor.id):
			key = "*talked"
		if not sides.has(key):
			sides[key] = [] as Array[Actor]
		var members: Array[Actor] = sides[key]
		members.append(actor)
	return sides


func _force_of(outcome: EncounterOutcome, members: Array[Actor]) -> int:
	var force := 0
	for actor in members:
		force += actor.threat * EncounterChoice.weight_of(outcome.choice_of(actor.id))
	return force


func _press(outcome: EncounterOutcome, actor: Actor, gain: int) -> void:
	var total := pressure_of(actor.id) + gain
	outcome.pressure_dealt[actor.id] = gain
	if total < BREAK_PRESSURE:
		_pressure[actor.id] = total
		return
	# 무너졌다. **판에서 치우는 것은 4단계의 일이다** — 여기서는 적어 보내기만 한다.
	_pressure.erase(actor.id)
	_downs[actor.id] = downs_of(actor.id) + 1
	if actor.kind == Actor.Kind.MONSTER:
		outcome.slain_ids.append(actor.id)
	else:
		outcome.subdued_ids.append(actor.id)


## 싸움이 있었다는 것을 남긴다. **magnitude 는 이번 턴에 민 힘의 크기다.**
##
## 진실만 담는다. 과장은 기사를 만드는 단계에서만 일어난다
## (docs/design/13-information-design.md §13.3.1).
func _note_fight(outcome: EncounterOutcome, victors: Array[Actor], room: Room) -> void:
	if victors.is_empty():
		return
	var pushed := 0
	for actor_id in outcome.pressure_dealt:
		pushed += int(outcome.pressure_dealt[actor_id])
	if pushed <= 0:
		return
	var lead: Actor = victors[0]
	var losers: Array[String] = []
	for actor_id in outcome.pressure_dealt:
		losers.append(str(actor_id))
	outcome.events.append(
		GameEvent.new(outcome.turn, GameEvent.Kind.FOUGHT, lead, room, pushed, losers)
	)


# ---------------------------------------------------------------- 관계도


## 관계도로 나갈 표시를 남긴다 (§35.4.2).
##
## **몬스터와의 일은 관계도가 아니다.** 탐험가가 둘 이상일 때만 남는다.
func _mark_relations(outcome: EncounterOutcome, here: Array[Actor]) -> void:
	var explorers := _explorers(here)
	if explorers.size() < 2:
		return
	if outcome.negotiated_ids.size() >= 2:
		_mark(outcome, RelationEvent.Kind.BARGAIN, outcome.negotiated_ids)
	if outcome.allied_ids.size() >= 2:
		_mark(outcome, RelationEvent.Kind.COOPERATION, outcome.allied_ids)
	_mark_strikes(outcome, explorers)
	if not outcome.subdued_ids.is_empty() and not outcome.victor_ids.is_empty():
		outcome.marks.append(
			EncounterMark.new(
				RelationEvent.Kind.PLUNDER, outcome.victor_ids[0], outcome.subdued_ids
			)
		)
	if outcome.marks.is_empty() and outcome.was_bloodless():
		# **못 본 척 지나감** — §5.10 이 친밀도 변화를 미정으로 남긴 칸이다.
		# 아무 일도 안 일어난 것 자체가 사건이라는 것은 §24.5 가 이미 정해 뒀다.
		_mark(outcome, RelationEvent.Kind.PASS_BY, _ids_of(explorers))


## 한쪽만 친 경우를 남긴다. **선제 공격**, 그리고 어제의 동료였다면 **배신**.
func _mark_strikes(outcome: EncounterOutcome, explorers: Array[Actor]) -> void:
	var unarmed: Array[String] = []
	for actor in explorers:
		if not EncounterChoice.means_harm(outcome.choice_of(actor.id)):
			unarmed.append(actor.id)
	for actor in explorers:
		if not EncounterChoice.means_harm(outcome.choice_of(actor.id)):
			continue
		var betrayed := _intersect(allies_of(actor.id), _ids_of(explorers), actor.id)
		if not betrayed.is_empty():
			outcome.marks.append(EncounterMark.new(RelationEvent.Kind.BETRAYAL, actor.id, betrayed))
			continue
		var struck := _ids_except_list(unarmed, actor.id)
		if not struck.is_empty():
			outcome.marks.append(EncounterMark.new(RelationEvent.Kind.AMBUSH, actor.id, struck))


func _mark(outcome: EncounterOutcome, kind: RelationEvent.Kind, ids: Array[String]) -> void:
	if ids.size() < 2:
		return
	outcome.marks.append(EncounterMark.new(kind, ids[0], _ids_except_list(ids, ids[0])))


## 이번 턴에 함께한 자들을 적어 둔다. **다음 턴의 배신이 이것을 본다.**
func _remember_allies(outcome: EncounterOutcome) -> void:
	_note_group(outcome.negotiated_ids)
	_note_group(outcome.allied_ids)


func _note_group(ids: Array[String]) -> void:
	if ids.size() < 2:
		return
	for actor_id in ids:
		var mates: Array[String] = _allies_next.get(actor_id, [] as Array[String])
		for other in ids:
			if other != actor_id and not mates.has(other):
				mates.append(other)
		_allies_next[actor_id] = mates


# ---------------------------------------------------------------- 훑기


## 이번 턴이 끝나고도 조우가 성립하는가. **§5.8 의 *"전투 지속"* 이 이 값이다.**
func _still_standing(outcome: EncounterOutcome, here: Array[Actor]) -> bool:
	var left: Array[Actor] = []
	for actor in here:
		if outcome.fled_ids.has(actor.id):
			continue
		if outcome.subdued_ids.has(actor.id) or outcome.slain_ids.has(actor.id):
			continue
		left.append(actor)
	return Encounter.is_encounter(left)


func _who_chose(
	outcome: EncounterOutcome, here: Array[Actor], kind: EncounterChoice.Kind
) -> Array[Actor]:
	var found: Array[Actor] = []
	for actor in here:
		if actor.kind != Actor.Kind.MONSTER and outcome.choice_of(actor.id) == kind:
			found.append(actor)
	return found


func _who_means_harm(outcome: EncounterOutcome, here: Array[Actor]) -> Array[Actor]:
	var found: Array[Actor] = []
	for actor in here:
		if EncounterChoice.means_harm(outcome.choice_of(actor.id)):
			found.append(actor)
	return found


func _explorers(here: Array[Actor]) -> Array[Actor]:
	var found: Array[Actor] = []
	for actor in here:
		if actor.kind != Actor.Kind.MONSTER:
			found.append(actor)
	return found


func _ids_of(actors: Array[Actor]) -> Array[String]:
	var ids: Array[String] = []
	for actor in actors:
		ids.append(actor.id)
	return ids


func _ids_except(actors: Array[Actor], actor_id: String) -> Array[String]:
	return _ids_except_list(_ids_of(actors), actor_id)


func _ids_except_list(ids: Array[String], actor_id: String) -> Array[String]:
	var found: Array[String] = []
	for id in ids:
		if id != actor_id:
			found.append(id)
	return found


func _intersect(left: Array[String], right: Array[String], skip: String) -> Array[String]:
	var found: Array[String] = []
	for id in left:
		if id != skip and right.has(id):
			found.append(id)
	return found
