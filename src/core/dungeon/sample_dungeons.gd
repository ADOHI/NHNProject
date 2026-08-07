class_name SampleDungeons
extends RefCounted
## 개발용 표본 던전. 나중에 .tres 데이터로 대체된다 (conventions.md §3.2).
##
## 지금 이것이 코드인 이유는 판이 아직 굴러가는지 확인하는 단계이기 때문이다.
## 배치 규칙과 던전 성격은 구현 5단계에서 데이터로 뺀다
## (docs/design/07-level-design.md §7.3).


## 표본 던전의 배치 의도 — 이 판은 **위험도의 모호함을 눈으로 보여 주기 위해** 짜였다.
##
##   봉인된 금고 : 위험도 6 짜리 하나
##   사육장      : 위험도 2 짜리 셋 = 합 6
##
## 무너진 제단에 서면 두 방의 인접 합에 같은 6 이 섞여 들어온다.
## 숫자만으로는 어느 쪽이 보스이고 어느 쪽이 무리인지 알 수 없다
## (docs/design/07-level-design.md §7.2.1).
static func first_blueprint() -> DungeonBlueprint:
	var blueprint := DungeonBlueprint.new()
	blueprint.add_room("entrance", "입구 광장", Vector2(170, 520))
	blueprint.add_room("west_hall", "서쪽 회랑", Vector2(170, 300))
	blueprint.add_room("gallery", "부서진 전시실", Vector2(390, 200))
	blueprint.add_room("cistern", "물 고인 저수조", Vector2(390, 480))
	blueprint.add_room("shrine", "무너진 제단", Vector2(610, 340))
	blueprint.add_room("vault", "봉인된 금고", Vector2(830, 200))
	blueprint.add_room("kennel", "사육장", Vector2(830, 480))
	blueprint.add_room("exit_gate", "탈출 승강기", Vector2(1030, 340))

	blueprint.connect_rooms("entrance", "west_hall")
	blueprint.connect_rooms("entrance", "cistern")
	blueprint.connect_rooms("west_hall", "gallery")
	blueprint.connect_rooms("gallery", "shrine")
	blueprint.connect_rooms("cistern", "shrine")
	blueprint.connect_rooms("shrine", "vault")
	blueprint.connect_rooms("shrine", "kennel")
	blueprint.connect_rooms("vault", "exit_gate")
	blueprint.connect_rooms("kennel", "exit_gate")
	return blueprint


## 표본 던전에 몬스터와 경쟁자를 놓는다.
static func populate_first(graph: DungeonGraph) -> void:
	_place(graph, "gallery", "dust_wraith", "먼지 망령", Actor.Kind.MONSTER, 2)

	# 저수조는 합 2 이지만 개체가 둘이다. 전시실(합 2, 개체 1)과 숫자로는 구분되지 않는다.
	_place(graph, "cistern", "drowned_1", "물귀신", Actor.Kind.MONSTER, 1)
	_place(graph, "cistern", "drowned_2", "물귀신", Actor.Kind.MONSTER, 1)

	_place(graph, "shrine", "altar_guard", "제단 수호자", Actor.Kind.MONSTER, 5)

	# 금고와 사육장이 이 던전의 핵심 대비다. 합은 둘 다 6, 구성은 정반대.
	_place(graph, "vault", "vault_warden", "금고 파수꾼", Actor.Kind.MONSTER, 6)
	for i in 3:
		_place(graph, "kennel", "hound_%d" % i, "사냥개", Actor.Kind.MONSTER, 2)

	_place(graph, "west_hall", "johan", "칼날의 요한", Actor.Kind.NPC_EXPLORER, 4)


## 표본 던전 한 판을 통째로 만든다.
static func create_first_run() -> DungeonRun:
	var blueprint := first_blueprint()
	var graph := blueprint.build()
	populate_first(graph)

	var squad := Actor.new("player_squad", "우리 스쿼드", Actor.Kind.PLAYER_SQUAD, 8)
	graph.place_actor(squad, "entrance")
	return DungeonRun.new(blueprint, graph, squad)


static func _place(
	graph: DungeonGraph, room_id: String, id: String, name: String, kind: Actor.Kind, threat: int
) -> void:
	graph.place_actor(Actor.new(id, name, kind, threat), room_id)
