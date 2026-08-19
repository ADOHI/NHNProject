extends RefCounted
## 턴 루프 시험이 함께 쓰는 판. **테스트 전용이다.**
##
## `docs/design/33-turn-loop.md`.
##
## 턴 시험은 여러 파일로 갈라져 있다 — 해결기 · 조우(E1~E9) · 탈출 · NPC · 판 루프.
## 갈라 놓고 같은 판을 파일마다 세우면 한쪽만 고쳤을 때 **같은 이름으로 다른 판**을
## 쓰게 된다. 판은 여기 한 벌만 둔다.
##
## 파일 이름이 test_ 로 시작하지 않으므로 GUT 은 이 파일을 테스트로 실행하지 않는다.
##
##     관문(EXIT) --- 큰 방(입구) --- 금고(귀중품) --- 심부(보스)
##
## **고도가 전부 0 이다.** 민첩이 판정에 끼어들면 조우 시험이
## "왜 안 갔는가"를 둘 이상의 이유로 설명하게 된다. 고도는 다른 시험이 맡는다.

## 금고에 놓이는 값. 생성 난수를 쓰지 않고 못 박는다.
const VAULT_VALUE := 5

## 스쿼드의 능력. 통로 하나를 오갈 수 있으면 충분하다.
const SQUAD_THREAT := 8
const SQUAD_AGILITY := 3


static func board() -> DungeonBlueprint:
	var blueprint := DungeonBlueprint.new()
	blueprint.add_room("gate", "관문", 0, Room.Kind.EXIT)
	blueprint.add_room("hall", "큰 방", 0, Room.Kind.ENTRANCE)
	blueprint.add_room("vault", "금고", 0, Room.Kind.TREASURE)
	blueprint.add_room("deep", "심부", 0, Room.Kind.BOSS)
	blueprint.connect_rooms("gate", "hall")
	blueprint.connect_rooms("hall", "vault")
	blueprint.connect_rooms("vault", "deep")
	return blueprint


## 판 하나. 스쿼드는 `start_id` 에 서 있고 귀중품은 금고에만 있다.
##
## 생성 난수가 놓은 값을 지우고 다시 박는 이유는, 시험이 **정확히 얼마를 주웠는지**를
## 단언해야 하기 때문이다. 난수 시드를 믿으면 값이 바뀔 때 시험이 조용히 다른 것을 잰다.
static func run(start_id: String = "hall") -> DungeonRun:
	var blueprint := board()
	var graph := blueprint.build()
	var squad := Actor.new("squad", "우리 스쿼드", Actor.Kind.PLAYER_SQUAD, SQUAD_THREAT, SQUAD_AGILITY)
	graph.place_actor(squad, start_id)
	var made := DungeonRun.new(blueprint, graph, squad)
	for room_id in graph.room_ids():
		made.loot.put(room_id, 0)
	made.loot.put("vault", VAULT_VALUE)
	return made


## 경쟁자 하나를 판에 놓는다. 이름은 기사에 그대로 나가므로 비우지 않는다
## (docs/design/05-rules.md §5.2.2).
static func rival(
	made: DungeonRun, room_id: String, id: String = "rival", threat: int = 4, agility: int = 3
) -> Actor:
	var actor := Actor.new(id, "칼날의 " + id, Actor.Kind.NPC_EXPLORER, threat, agility)
	made.graph.place_actor(actor, room_id)
	return actor


static func monster(
	made: DungeonRun, room_id: String, id: String = "beast", threat: int = 3
) -> Actor:
	var actor := Actor.new(id, "먼지 망령", Actor.Kind.MONSTER, threat, 0)
	made.graph.place_actor(actor, room_id)
	return actor


## 태세를 붙인 제자리 의도를 낸다.
##
## 조우가 이어지는 턴에는 갈 곳도 뒤질 것도 없이 **고르기만** 한다
## (docs/design/05-rules.md §5.8 *"전투 지속 -> 다음 턴에도 조우 상태"*).
static func hold(made: DungeonRun, actor_id: String, stance: EncounterChoice.Kind) -> void:
	made.submit_intent(TurnIntent.stay(actor_id).facing(stance))


## 판 위에서 그 id 를 찾는다. 조우 시험이 참가자를 손으로 집을 때 쓴다.
static func actor(made: DungeonRun, actor_id: String) -> Actor:
	for room_id in made.graph.room_ids():
		for found in made.graph.get_room(room_id).occupants():
			if found.id == actor_id:
				return found
	return null


## 성향 여섯을 한 축만 세워 만든다. 나머지는 중립이다.
##
## 행동에 쓰이는 축은 `RECKLESS` 하나뿐이므로(§33.4), 시험도 그것만 흔든다.
static func temper(axis: NpcAxis.Kind, value: int) -> Array[int]:
	var traits: Array[int] = []
	for index in NpcAxis.count():
		traits.append(value if index == int(axis) else 0)
	return traits
