class_name SampleDungeons
extends RefCounted
## 던전 한 판을 만들어 세우는 조립 지점.
##
## 구조는 DungeonGenerator 가 절차적으로 만들고(docs/design/17-dungeon-generation.md),
## 여기서는 그 위에 몬스터와 NPC 를 놓아 실제로 굴릴 수 있는 판으로 만든다.
##
## 존재 배치 수치는 전부 잠정이다. 굴려 보고 정한다 (§17.8).

## 스쿼드의 기본 능력. 편성 시스템이 붙기 전까지 쓰는 값이다.
##
## 편성이 생기면 SquadStats 로 대원들에게서 계산된다
## (전투력은 합, 민첩은 평균 — docs/design/14-squad.md §14.3.1).
const SQUAD_THREAT := 8
const SQUAD_AGILITY := 2

## 입구 인접 위험도 상한. 판단할 기회도 없이 죽는 배치를 막는다 (§17.5 V4).
const ENTRANCE_THREAT_MAX := 4


## 판 하나를 통째로 만든다.
static func create_run(seed_value: int = 0) -> DungeonRun:
	var generator := DungeonGenerator.new(seed_value)
	var blueprint := generator.generate()
	var graph := blueprint.build()

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var entrance := _entrance_of(blueprint)
	_populate(graph, blueprint, entrance, rng)

	var squad := Actor.new(
		"player_squad", "우리 스쿼드", Actor.Kind.PLAYER_SQUAD, SQUAD_THREAT, SQUAD_AGILITY
	)
	graph.place_actor(squad, entrance)
	return DungeonRun.new(blueprint, graph, squad)


static func _entrance_of(blueprint: DungeonBlueprint) -> String:
	var entrances := blueprint.rooms_of_kind(Room.Kind.ENTRANCE)
	return entrances[0] if not entrances.is_empty() else blueprint.room_ids()[0]


## 방 종류에 따라 몬스터를 놓고, 경쟁자 하나를 풀어 둔다.
##
## 종류별로 위험도의 **구성**을 다르게 만드는 것이 중요하다.
## 보스방은 큰 하나, 위험방은 작은 여럿 — 같은 합이 서로 다른 구성에서 나와야
## 인접 합이 모호해진다 (docs/design/17-dungeon-generation.md §17.5 V6).
static func _populate(
	graph: DungeonGraph, blueprint: DungeonBlueprint, entrance: String, rng: RandomNumberGenerator
) -> void:
	var index := 0
	for id in blueprint.room_ids():
		if id == entrance:
			continue
		match blueprint.kind_of(id):
			Room.Kind.BOSS:
				_place(graph, id, "boss_%d" % index, "심부의 파수꾼", 6, 2)
			Room.Kind.TREASURE:
				# 큰 하나. 같은 합을 만드는 위험방과 대비된다.
				_place(graph, id, "warden_%d" % index, "금고 파수꾼", 4, 1)
			Room.Kind.HAZARD:
				# 작은 여럿. 합은 비슷하지만 개체 수가 다르다.
				for i in 3:
					_place(graph, id, "hound_%d_%d" % [index, i], "사냥개", 2, 1)
			Room.Kind.EMPTY:
				if rng.randf() < 0.45:
					_place(graph, id, "wraith_%d" % index, "먼지 망령", rng.randi_range(1, 2), 0)
		index += 1

	_trim_entrance_threat(graph, entrance)
	_ensure_entrance_has_something_to_read(graph, blueprint, entrance)

	var rival_room := _pick_rival_room(graph, blueprint, entrance, rng)
	if not rival_room.is_empty():
		_place(graph, rival_room, "johan", "칼날의 요한", 4, 3, Actor.Kind.NPC_EXPLORER)


## 입구 인접 위험도가 상한을 넘으면 가장 강한 것부터 덜어 낸다.
##
## 생성 단계에서 이 조건까지 맞추려 하면 재시도가 폭증한다.
## 구조는 생성기가 보장하고, 배치는 여기서 다듬는 편이 싸다.
static func _trim_entrance_threat(graph: DungeonGraph, entrance: String) -> void:
	while graph.adjacent_threat(entrance) > ENTRANCE_THREAT_MAX:
		var strongest: Actor = null
		for neighbor_id in graph.neighbors_of(entrance):
			for actor in graph.get_room(neighbor_id).occupants():
				if strongest == null or actor.threat > strongest.threat:
					strongest = actor
		if strongest == null:
			return
		graph.remove_actor(strongest)


## 입구에서 보이는 숫자가 0 이면 첫 턴에 읽을 것이 없다.
##
## 0 도 "주변이 안전하다"는 정보이긴 하지만, 시작하자마자 그러면
## 이 게임이 무엇을 하는 게임인지 드러나지 않는다.
## 첫 화면에서 숫자 하나는 보여야 한다 (docs/design/06-progression.md §6.4).
static func _ensure_entrance_has_something_to_read(
	graph: DungeonGraph, blueprint: DungeonBlueprint, entrance: String
) -> void:
	if graph.adjacent_threat(entrance) > 0:
		return
	for neighbor_id in graph.neighbors_of(entrance):
		# 탈출구는 비워 둔다. 나가는 길을 지키게 하면 첫 판부터 가둬 놓는 셈이다.
		if blueprint.kind_of(neighbor_id) == Room.Kind.EXIT:
			continue
		_place(graph, neighbor_id, "stray", "떠도는 것", 2, 0)
		return


## 경쟁자는 입구에서 떨어진 곳에서 시작해야 조우가 사건이 된다
## (docs/design/07-level-design.md §7.6).
static func _pick_rival_room(
	graph: DungeonGraph, blueprint: DungeonBlueprint, entrance: String, rng: RandomNumberGenerator
) -> String:
	var far: Array[String] = []
	var neighbors := graph.neighbors_of(entrance)
	for id in blueprint.room_ids():
		if id != entrance and not neighbors.has(id):
			far.append(id)
	if far.is_empty():
		return ""
	return far[rng.randi() % far.size()]


static func _place(
	graph: DungeonGraph,
	room_id: String,
	id: String,
	name: String,
	threat: int,
	agility: int,
	kind: Actor.Kind = Actor.Kind.MONSTER
) -> void:
	graph.place_actor(Actor.new(id, name, kind, threat, agility), room_id)
