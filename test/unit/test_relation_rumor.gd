extends GutTest
## 소문 — 전파 1홉을 덮는다.
##
## docs/design/24-npc-relations.md §24.10 · §24.28.
##
## *"친구의 원수는 나의 원수."* 그 자리에 없던 사람도 *"그 사람이 배신했다더라"* 를 안다.
##
## 지켜야 할 것 넷 —
##
## 1. **닿는다.** 목격자가 아는 사람에게 사건이 전해진다
## 2. **약하다.** 소문이 목격만큼 세면 목격이 뜻을 잃는다
## 3. **화면이 「들었다」와 「봤다」를 가른다.** 안 가르면 모두가 모든 걸 목격한 것처럼 보인다
## 4. **성김을 안 죽인다.** 유대 없는 사람에게는 안 가고, 문턱 아래는 관계를 안 만든다

var _registry: PersonRegistry
var _graph: RelationGraph
var _ledger: RelationLedger
var _resolver: RelationResolver


func before_each() -> void:
	_build([_blank(), _blank(), _blank(), _blank()])


func _blank() -> PackedInt32Array:
	var traits := PackedInt32Array()
	traits.resize(NpcAxis.count())
	return traits


## 배신 벡터와 완전히 같은(또는 반대) 쪽 성향.
##
## **축 하나만 세우면 내적이 0.36 밖에 안 나온다.** 소문은 목격의 35% 라
## 그 정도로는 문턱(RUMOR_MARK_MIN)을 못 넘고, 그러면 시험이
## **아무것도 안 일어난 것을 통과로 읽는다.** 실제로 그렇게 썼다가 잡았다.
func _reacts(sign: int) -> PackedInt32Array:
	var traits := _blank()
	var event := RelationEvent.of(RelationEvent.Kind.BETRAYAL)
	for axis in NpcAxis.count():
		var value := event.axis(axis as NpcAxis.Kind)
		if value != 0:
			traits[axis] = sign * signi(value) * 95
	return traits


## 배신을 미워하는 사람. 사건 벡터와 반대 쪽이라 내적이 음수다.
func _hates_betrayal() -> PackedInt32Array:
	return _reacts(-1)


## 배신을 이해하는 사람. 실리 · 기만 쪽이라 내적이 양수다.
func _understands_betrayal() -> PackedInt32Array:
	return _reacts(1)


func _build(traits: Array, fames: Array = [], spreads: bool = true) -> void:
	_registry = PersonRegistry.new()
	for slot in traits.size():
		_registry.add(
			"시험%d" % slot,
			MemberDiscipline.Kind.COMBAT,
			1,
			1,
			PersonRegistry.NO_FACTION,
			int(fames[slot]) if slot < fames.size() else 0,
			30,
			PersonGender.Kind.MALE,
			traits[slot] as PackedInt32Array
		)
	_graph = RelationGraph.new(_registry.size())
	_ledger = RelationLedger.new()
	_resolver = RelationResolver.new(_registry, _graph, _ledger, spreads)


## 둘을 양방향으로 엮는다. 소문은 **서로 아는 사이**로만 흐른다.
func _entangle(one: int, other: int, bond: int) -> void:
	_graph.link(one, other, RelationKind.Kind.SIBLING, 0, bond)
	_graph.link(other, one, RelationKind.Kind.SIBLING, 0, bond)


func _betray(actor: int, target: int, witnesses: Array = []) -> int:
	return _resolver.resolve(
		RelationEvent.Kind.BETRAYAL, actor, PackedInt32Array([target]), PackedInt32Array(witnesses)
	)


# ---------------------------------------------------------------- 닿는다


func test_a_rumour_reaches_someone_who_was_not_there() -> void:
	# 3 번은 그 자리에 없었다. 2 번(목격자)과 엮여 있어서 듣는다.
	_build([_blank(), _blank(), _hates_betrayal(), _hates_betrayal()])
	_entangle(2, 1, RelationGraph.BOND_MAX)
	_entangle(3, 2, RelationGraph.BOND_MAX)
	_betray(0, 1, [2])
	assert_true(_graph.knows(3, 0), "듣고 나서 그 사람을 알게 된다")
	assert_lt(_graph.affinity(3, 0), 0, "의리형은 들어도 미워한다")


func test_the_hearer_judges_with_their_own_traits() -> void:
	# 규칙이 하나뿐인 것이 소문에서도 값을 한다 (설계 24.4) —
	# 같은 이야기를 듣고 의리형과 실리형이 갈린다.
	_build(
		[
			_blank(),
			_blank(),
			_blank(),
			_hates_betrayal(),
			_understands_betrayal(),
		]
	)
	_entangle(2, 1, RelationGraph.BOND_MAX)
	_entangle(3, 2, RelationGraph.BOND_MAX)
	_entangle(4, 2, RelationGraph.BOND_MAX)
	_betray(0, 1, [2])
	assert_lt(_graph.affinity(3, 0), 0)
	assert_gt(_graph.affinity(4, 0), 0)


func test_a_past_victim_hears_about_the_next_one() -> void:
	# **이 시험이 전파의 값을 가장 잘 보여 준다.** 한 번 당한 사람이
	# 그자가 또 배신했다는 소식을 듣고 더 미워한다.
	_build([_blank(), _hates_betrayal(), _blank()])
	_betray(0, 1)
	var after_first := _graph.affinity(1, 0)
	_betray(0, 2)
	assert_lt(_graph.affinity(1, 0), after_first)


# ---------------------------------------------------------------- 약하다


func test_a_rumour_moves_less_than_witnessing() -> void:
	# 소문이 목격만큼 세면 **목격이 뜻을 잃는다.**
	_build([_blank(), _blank(), _hates_betrayal(), _hates_betrayal()])
	_entangle(2, 1, RelationGraph.BOND_MAX)
	_entangle(3, 2, RelationGraph.BOND_MAX)
	_betray(0, 1, [2])
	assert_lt(absi(_graph.affinity(3, 0)), absi(_graph.affinity(2, 0)))


func test_a_rumour_raises_no_bond() -> void:
	# 듣는 것은 엮이는 것이 아니다. 목격보다 더 그렇다.
	_build([_blank(), _blank(), _hates_betrayal(), _hates_betrayal()])
	_entangle(2, 1, RelationGraph.BOND_MAX)
	_entangle(3, 2, RelationGraph.BOND_MAX)
	_betray(0, 1, [2])
	assert_eq(_graph.bond(3, 0), 0)


func test_strangers_hear_nothing() -> void:
	# **소문은 서로 아는 사이로만 흐른다.** 아니면 사건 하나가 세계 전체에 닿는다.
	_build([_blank(), _blank(), _hates_betrayal(), _hates_betrayal()])
	_entangle(2, 1, RelationGraph.BOND_MAX)
	_betray(0, 1, [2])
	assert_false(_graph.knows(3, 0), "아무와도 안 엮인 사람은 못 듣는다")


func test_a_thin_bond_carries_no_rumour() -> void:
	# 남의 말은 그 사람만큼만 무겁다. 얕게 엮인 사이로는 문턱을 못 넘는다.
	_build([_blank(), _blank(), _hates_betrayal(), _hates_betrayal()])
	_entangle(2, 1, RelationGraph.BOND_MAX)
	_entangle(3, 2, 5)
	_betray(0, 1, [2])
	assert_false(_graph.knows(3, 0))


# ---------------------------------------------------------------- 유명세가 거리를 정한다


func test_a_famous_actor_travels_further() -> void:
	# 설계 24.7 — *"무명인 사람 얘기는 아무도 보지 않는다."*
	# 같은 세계, 같은 사건, 다른 것은 행위자의 유명세뿐이다.
	var traits := [_blank(), _blank(), _hates_betrayal(), _hates_betrayal()]
	_build(traits, [0, 0, 0, 0])
	_entangle(2, 1, RelationGraph.BOND_MAX)
	_entangle(3, 2, 30)
	_betray(0, 1, [2])
	var unknown := _graph.affinity(3, 0)

	_build(traits, [PersonGenerator.FAME_MAX, 0, 0, 0])
	_entangle(2, 1, RelationGraph.BOND_MAX)
	_entangle(3, 2, 30)
	_betray(0, 1, [2])
	assert_lt(_graph.affinity(3, 0), unknown, "유명한 사람의 사건이 더 멀리 간다")


# ---------------------------------------------------------------- 봤나 들었나


func test_a_heard_relation_is_marked() -> void:
	# 안 가르면 화면이 **모두가 모든 것을 목격한 것처럼** 말한다.
	_build([_blank(), _blank(), _hates_betrayal(), _hates_betrayal()])
	_entangle(2, 1, RelationGraph.BOND_MAX)
	_entangle(3, 2, RelationGraph.BOND_MAX)
	var cause := _betray(0, 1, [2])
	assert_true(_graph.is_heard(3, 0), "들은 것")
	assert_false(_graph.is_heard(2, 0), "본 것")
	assert_eq(_ledger.role_phrase(cause, 3, true), "전해 들었다")
	assert_eq(_ledger.role_phrase(cause, 2, false), "목격자였다")


func test_seeing_it_yourself_clears_the_mark() -> void:
	# 소문으로 알던 사람을 직접 보면 더 이상 들은 이야기가 아니다.
	_build([_blank(), _blank(), _hates_betrayal(), _hates_betrayal()])
	_entangle(2, 1, RelationGraph.BOND_MAX)
	_entangle(3, 2, RelationGraph.BOND_MAX)
	_betray(0, 1, [2])
	assert_true(_graph.is_heard(3, 0))
	_entangle(3, 1, RelationGraph.BOND_MAX)
	_betray(0, 1, [3])
	assert_false(_graph.is_heard(3, 0), "이번에는 직접 봤다")


func test_the_ledger_finds_the_mark_through_the_relations() -> void:
	_build([_blank(), _blank(), _hates_betrayal(), _hates_betrayal()])
	_entangle(2, 1, RelationGraph.BOND_MAX)
	_entangle(3, 2, RelationGraph.BOND_MAX)
	var cause := _betray(0, 1, [2])
	assert_true(_ledger.heard_by(_graph, 3, cause))
	assert_false(_ledger.heard_by(_graph, 2, cause))


# ---------------------------------------------------------------- 끌 수 있다


func test_switching_it_off_stops_every_rumour() -> void:
	# 도구가 이것으로 전파 전후를 나란히 잰다 (설계 24.28.3).
	_build([_blank(), _blank(), _hates_betrayal(), _hates_betrayal()], [], false)
	_entangle(2, 1, RelationGraph.BOND_MAX)
	_entangle(3, 2, RelationGraph.BOND_MAX)
	_betray(0, 1, [2])
	assert_true(_graph.knows(2, 0), "목격은 그대로다")
	assert_false(_graph.knows(3, 0), "소문은 없다")
