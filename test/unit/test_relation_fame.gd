extends GutTest
## 유명세가 사건으로 움직이는 것을 덮는다 — **설계 24.5 의 유명세 칸**.
##
## `test_relation_resolver.gd` 에서 갈라 나왔다 (gdlint 공개 메서드 20개, §24.35.3 · §24.35.7).
##
## 지켜야 할 것 셋 (docs/design/24-npc-relations.md §24.7 · §24.40) —
##
## 1. **행위자만 오른다.** 당한 것으로 유명해지면 유명세가 "무엇을 했는가" 가 아니게 된다
## 2. **성향을 안 탄다.** 사실 관계다
## 3. **천장을 안 넘는다.** 넘으면 소문이 설계에 없는 거리를 간다 (`_fame_reach`)

const _PEOPLE := 4

var _registry: PersonRegistry
var _graph: RelationGraph
var _ledger: RelationLedger
var _resolver: RelationResolver


func before_each() -> void:
	_world_with([_blank(), _blank(), _blank(), _blank()], false)


func _blank() -> PackedInt32Array:
	var traits := PackedInt32Array()
	traits.resize(NpcAxis.count())
	return traits


func _axis(kind: NpcAxis.Kind, value: int) -> PackedInt32Array:
	var traits := _blank()
	traits[int(kind)] = value
	return traits


func _add(traits: PackedInt32Array) -> int:
	return _registry.add(
		"시험%d" % _registry.size(),
		MemberDiscipline.Kind.COMBAT,
		1,
		1,
		PersonRegistry.NO_FACTION,
		0,
		30,
		PersonGender.Kind.MALE,
		traits
	)


func _world_with(traits: Array, spreads: bool = true) -> void:
	_registry = PersonRegistry.new()
	for entry in traits:
		_add(entry as PackedInt32Array)
	_graph = RelationGraph.new(_registry.size())
	_ledger = RelationLedger.new()
	_resolver = RelationResolver.new(_registry, _graph, _ledger, spreads)


func _resolve(kind: RelationEvent.Kind, actor: int, target: int, witnesses: Array = []) -> int:
	return _resolver.resolve(kind, actor, PackedInt32Array([target]), PackedInt32Array(witnesses))


func _entangle(one: int, other: int, bond: int, affinity: int = 0) -> void:
	_graph.link(one, other, RelationKind.Kind.SIBLING, affinity, bond)
	_graph.link(other, one, RelationKind.Kind.SIBLING, affinity, bond)


func test_only_the_actor_gets_famous() -> void:
	# 설계 24.6 — *"행위자: 평판이 그 방향으로 굳는다."* 대상과 목격자에게는 그 칸이 없다.
	# **당한 것으로 유명해지면 유명세가 「무엇을 했는가」가 아니게 된다** (§24.7).
	_world_with([_blank(), _blank(), _axis(NpcAxis.Kind.LOYAL, 95)], false)
	_entangle(2, 0, RelationGraph.BOND_MAX)
	var gain := RelationEvent.of(RelationEvent.Kind.BETRAYAL).fame_gain
	assert_gt(gain, 0, "배신은 유명세를 올리는 사건이다")
	_resolve(RelationEvent.Kind.BETRAYAL, 0, 1, [2])
	assert_eq(_registry.fame_of(0), gain)
	assert_eq(_registry.fame_of(1), 0, "당한 사람은 안 유명해진다")
	assert_eq(_registry.fame_of(2), 0, "본 사람도 안 유명해진다")


func test_fame_does_not_ride_the_traits() -> void:
	# **사실 관계다.** 성향이 갈리는 것은 목격자의 호감이지 행위자의 평판이 아니다.
	_world_with([_axis(NpcAxis.Kind.SHOWY, 95), _blank()], false)
	var showy := _registry.fame_of(0)
	_resolve(RelationEvent.Kind.BETRAYAL, 0, 1)
	var moved := _registry.fame_of(0) - showy
	_world_with([_axis(NpcAxis.Kind.SHOWY, -95), _blank()], false)
	_resolve(RelationEvent.Kind.BETRAYAL, 0, 1)
	assert_eq(_registry.fame_of(0), moved, "과시형이든 은둔형이든 같은 만큼 오른다")


func test_fame_stops_at_the_ceiling() -> void:
	# 천장을 넘으면 `_fame_reach` 가 2.0 을 넘어 소문이 설계에 없는 거리를 간다.
	_world_with([_blank(), _blank()], false)
	for _try in 200:
		_resolve(RelationEvent.Kind.HEADLINE, 0, 1)
	assert_eq(_registry.fame_of(0), PersonGenerator.FAME_MAX)


func test_a_quiet_event_leaves_fame_alone() -> void:
	_world_with([_blank(), _blank()], false)
	_resolve(RelationEvent.Kind.SNITCH, 0, 1)
	assert_eq(_registry.fame_of(0), 0, "밀고는 조용히 하는 일이다")
