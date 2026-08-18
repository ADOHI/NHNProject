class_name NpcPlanner
extends RefCounted
## 판 위의 NPC 탐험가와 몬스터가 이번 턴에 낼 의도를 정한다 (M4).
##
## docs/design/05-rules.md §5.2.2 가 정한 것은 셋이다 — **이동 · 획득 · 탈출.**
## 나머지 칸은 *"미정"* 이고, 미정인 칸을 이 레인이 메우지 않는다.
##
## ## 왜 이것이 「절대 자르지 않는 여섯」에 있나
##
## docs/design/16-build-order.md §16.8 — 없으면 *"흔한 턴제 로그라이크가 된다"*.
## 몬스터는 배치된 장애물이지만 NPC 탐험가는 **같은 규칙 아래 같은 목표로 움직인다.**
## 그래서 던전의 귀중품이 유한해지고, 늦으면 이미 털려 있다.
##
## ## 그리고 이것이 위험도 숫자를 살린다
##
## docs/design/13-information-design.md §13.5 — *"숫자의 절대값은 위험을 알려 주고,
## 숫자의 변화량은 사람을 알려 준다."* 몬스터는 안 움직이므로 **변화량은 전부 사람이다.**
## 이 클래스가 하는 일은 NPC 를 움직이게 하는 것뿐이고, 숫자는 알아서 따라온다 —
## `Room.threat()` 이 이미 종류를 안 가리고 더하므로 **합산 로직을 새로 만들지 않는다.**
##
## **몬스터는 계속 STAY 를 낸다.** 이 전제가 깨지면 위 추론 전체가 무너진다
## (`Actor.is_mobile()` 의 주석이 같은 것을 적어 뒀다).

## 짐이 이만큼 차면 나간다. 성향이 이 값을 흔든다.
##
## §5.2.2 의 「목표 우선순위 — 미정」을 **최소로** 채운 값이다. 잠정이다.
const DEFAULT_TARGET_VALUE := 6

## 성향 한 축이 목표치를 흔드는 폭. 무모 +100 이면 +5, 신중 -100 이면 -5 다.
const TEMPERAMENT_SWING := 20

var _graph: DungeonGraph
var _loot: LootTable
var _haul: Haul

## 주체 id -> 성향 여섯 (`NpcAxis` 순서). 없으면 중립으로 읽는다.
var _temperaments: Dictionary = {}


func _init(graph: DungeonGraph, loot: LootTable, haul: Haul) -> void:
	_graph = graph
	_loot = loot
	_haul = haul


## 이 NPC 의 성향을 박는다. `NpcAxis.count()` 개가 아니면 무시한다.
##
## 모자란 배열을 받아 두면 세계가 조용히 반쪽 성향을 갖게 된다
## (`PersonRegistry` 가 같은 이유로 같은 검사를 한다).
func set_temperament(actor_id: String, traits: Array[int]) -> void:
	if traits.size() != NpcAxis.count():
		push_error("성향 축 수가 맞지 않습니다: %s" % actor_id)
		return
	_temperaments[actor_id] = traits.duplicate()


func temperament_of(actor_id: String) -> Array[int]:
	var traits: Array[int] = _temperaments.get(actor_id, [] as Array[int])
	if traits.size() == NpcAxis.count():
		return traits.duplicate()
	var neutral: Array[int] = []
	for _axis in NpcAxis.count():
		neutral.append(0)
	return neutral


## 플레이어를 뺀 모두의 의도. 계획 페이즈에 한 번 부른다.
##
## **한 프레임에 다 돌린다.** 방이 12~52 개이고 NPC 하나의 한 턴 비용은
## 너비 우선 탐색 한 번이라 끊을 이유가 없다. 재고 나서 그렇게 정했다
## (docs/design/33-turn-loop.md §33.5). NPC 가 수십이 되면 그 표부터 다시 재라.
func plan_all() -> Array[TurnIntent]:
	var intents: Array[TurnIntent] = []
	for room_id in _graph.room_ids():
		var room := _graph.get_room(room_id)
		if room == null:
			continue
		for actor in room.occupants():
			if actor.is_player():
				continue
			intents.append(plan_for(actor, room_id))
	return intents


## 한 주체의 의도.
##
##     짐이 목표치를 넘었나 -- 그렇다 --> 탈출구로 간다 --> 도착하면 버틴다
##             |
##             아니다
##             v
##     가장 가까운 귀중품 방으로 간다 --> 도착하면 뒤진다
##             |
##        (남은 곳이 없다)
##             v
##           탈출한다
func plan_for(actor: Actor, room_id: String) -> TurnIntent:
	if actor.kind == Actor.Kind.MONSTER:
		return TurnIntent.stay(actor.id)
	if _wants_out(actor):
		return _head_for_exit(actor, room_id)
	if _loot.has_loot(room_id):
		return TurnIntent.search(actor.id)
	var step := _first_step_toward(actor, room_id, _loot.remaining_room_ids())
	if step.is_empty():
		return _head_for_exit(actor, room_id)
	return _step_or_flinch(actor, step)


## 나갈 때가 됐는가. **성향이 정하는 유일한 판단이다.**
##
## docs/design/24-npc-relations.md §24.3 의 여섯 축 중 `RECKLESS` 하나만 쓴다.
## 나머지 다섯은 **말과 관계의 축**이라 조우 절차(§5.8)와 관계도(§5.10)의 것이고,
## 여기서 억지로 쓰면 그쪽에서 다시 정의된다.
func target_value_of(actor_id: String) -> int:
	var reckless := temperament_of(actor_id)[int(NpcAxis.Kind.RECKLESS)]
	return maxi(1, DEFAULT_TARGET_VALUE + reckless / TEMPERAMENT_SWING)


## 자기보다 큰 방 앞에서 멈추는가.
##
## 신중한 쪽(`RECKLESS` 가 음수)만 그렇다. 무모한 쪽은 그대로 걸어 들어간다 —
## 그것이 곧 렉카 기사의 소재가 된다.
func is_cautious(actor_id: String) -> bool:
	return temperament_of(actor_id)[int(NpcAxis.Kind.RECKLESS)] < 0


func _wants_out(actor: Actor) -> bool:
	return _haul.carried_by(actor.id) >= target_value_of(actor.id)


func _head_for_exit(actor: Actor, room_id: String) -> TurnIntent:
	var room := _graph.get_room(room_id)
	if room != null and room.kind == Room.Kind.EXIT:
		return TurnIntent.escape(actor.id)
	var step := _first_step_toward(actor, room_id, _rooms_of_kind(Room.Kind.EXIT))
	if step.is_empty():
		return TurnIntent.stay(actor.id)
	return _step_or_flinch(actor, step)


## 그 방으로 갈 것인가, 움츠릴 것인가.
##
## 신중한 NPC 는 **자기 전투력보다 큰 방에 들어가지 않는다.** 대신 제자리를 지킨다 —
## 다른 길로 돌게 만들면 판 위에서 왔다 갔다 하는 그림이 되고, 그건 회피가 아니라 소음이다.
func _step_or_flinch(actor: Actor, step_room_id: String) -> TurnIntent:
	if is_cautious(actor.id) and _graph.threat_at(step_room_id) > actor.threat:
		return TurnIntent.stay(actor.id)
	return TurnIntent.move(actor.id, step_room_id)


## 목표 방들 중 **가장 가까운 곳을 향한 첫 걸음.** 갈 수 없으면 빈 문자열.
##
## 너비 우선 탐색이고 간선은 **그 주체의 민첩으로 지날 수 있는 것만** 쓴다.
## 민첩을 무시하면 못 오르는 방을 목표로 잡고 매 턴 벽에 부딪힌다
## (docs/design/07-level-design.md §7.2.6).
func _first_step_toward(actor: Actor, from_id: String, targets: Array[String]) -> String:
	if targets.is_empty() or from_id.is_empty():
		return ""
	var goals: Dictionary = {}
	for target in targets:
		goals[target] = true

	var came: Dictionary = {from_id: ""}
	var queue: Array[String] = [from_id]
	var reached := ""
	while not queue.is_empty():
		var current: String = queue.pop_front()
		if current != from_id and goals.has(current):
			reached = current
			break
		for next_id in _graph.traversable_neighbors(current, actor.agility):
			if came.has(next_id):
				continue
			came[next_id] = current
			queue.append(next_id)
	if reached.is_empty():
		return ""

	var step := reached
	while str(came[step]) != from_id and not str(came[step]).is_empty():
		step = str(came[step])
	return step


func _rooms_of_kind(kind: Room.Kind) -> Array[String]:
	var found: Array[String] = []
	for room_id in _graph.room_ids():
		var room := _graph.get_room(room_id)
		if room != null and room.kind == kind:
			found.append(room_id)
	return found
