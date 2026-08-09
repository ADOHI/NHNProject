extends GutTest
## 사건이 관계를 어떻게 바꾸는지를 덮는다. **이 시스템의 본체다.**
##
## docs/design/24-npc-relations.md §24.4 · §24.6 · §24.21.5.
##
## 여기서 안 되면 구조가 틀린 것이 셋 있다 —
##
## 1. **배신은 호감만 무너뜨리고 유대는 올린다.** 설계 24.15 가
##    *"여기서 안 되면 구조가 틀린 것"* 이라고 직접 못 박았다
## 2. **대상은 성향을 안 탄다** — 당한 것은 당한 것이다
## 3. **태생 관계는 사건이 유대와 유형을 못 건드린다**
##
## **목격자 계산은 `test_relation_witness.gd` 가 덮는다** — 설계 24.6 이
## *"목격자 계산이 이 시스템의 전부"* 라고 한 만큼 분량이 따로 선다.

## 시험 인구. 인덱스로 부르므로 이름이 필요 없다.
const _PEOPLE := 8

var _registry: PersonRegistry
var _graph: RelationGraph
var _ledger: RelationLedger
var _resolver: RelationResolver


func before_each() -> void:
	_registry = PersonRegistry.new()
	for slot in _PEOPLE:
		_add(_blank())
	_graph = RelationGraph.new(_registry.size())
	_ledger = RelationLedger.new()
	_resolver = RelationResolver.new(_registry, _graph, _ledger)


func _blank() -> PackedInt32Array:
	var traits := PackedInt32Array()
	traits.resize(NpcAxis.count())
	return traits


## 축 하나만 세운 성향. `_axis(NpcAxis.Kind.LOYAL, 90)` 이면 의리 쪽으로 90 이다.
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


## 인물의 성향을 갈아 끼운다. 등록 뒤에 바꿀 방법이 없어서 새로 만든다.
func _world_with(traits: Array) -> void:
	_registry = PersonRegistry.new()
	for entry in traits:
		_add(entry as PackedInt32Array)
	_graph = RelationGraph.new(_registry.size())
	_ledger = RelationLedger.new()
	_resolver = RelationResolver.new(_registry, _graph, _ledger)


func _resolve(kind: RelationEvent.Kind, actor: int, target: int, witnesses: Array = []) -> int:
	return _resolver.resolve(kind, actor, PackedInt32Array([target]), PackedInt32Array(witnesses))


## 둘을 양방향으로 엮는다. **관여도가 바닥(WITNESS_FLOOR)이면 목격자가 거의 안 움직이고**
## 그러면 관계가 아예 안 남는다 (WITNESS_MARK_MIN) — 목격자 시험은 제 사람이 당해야 성립한다.
##
## 유대를 한쪽에만 걸면 전멸의 훑기가 못 찾는다. KinSeeder 도 양쪽에 심는다.
func _entangle(one: int, other: int, bond: int, affinity: int = 0) -> void:
	_graph.link(one, other, RelationKind.Kind.SIBLING, affinity, bond)
	_graph.link(other, one, RelationKind.Kind.SIBLING, affinity, bond)


# ---------------------------------------------------------------- 배신


func test_betrayal_breaks_affinity_and_raises_bond() -> void:
	# **설계의 핵심이다** (§24.5) — 깊이 엮인 채로 증오하는 사이가 남는다.
	var event := RelationEvent.of(RelationEvent.Kind.BETRAYAL)
	_resolve(RelationEvent.Kind.BETRAYAL, 0, 1)
	assert_eq(_graph.affinity(1, 0), event.target_affinity)
	assert_eq(_graph.bond(1, 0), event.bond_gain)
	assert_eq(_graph.kind_of(1, 0), RelationKind.Kind.BETRAYED)


func test_betrayal_is_written_on_both_sides_with_different_labels() -> void:
	# 유형을 한쪽에만 두면 같은 사건이 가해자의 화면에서 사라진다.
	_resolve(RelationEvent.Kind.BETRAYAL, 0, 1)
	assert_eq(_graph.kind_of(0, 1), RelationKind.Kind.BETRAYER)
	assert_eq(_graph.kind_of(1, 0), RelationKind.Kind.BETRAYED)


func test_a_second_betrayal_stacks_the_bond() -> void:
	# 유대는 계속 오른다 — 두 번 배신한 사이는 더 무겁다.
	var event := RelationEvent.of(RelationEvent.Kind.BETRAYAL)
	_resolve(RelationEvent.Kind.BETRAYAL, 0, 1)
	_resolve(RelationEvent.Kind.BETRAYAL, 0, 1)
	assert_eq(_graph.bond(1, 0), event.bond_gain * 2)
	assert_eq(_graph.affinity(1, 0), maxi(event.target_affinity * 2, RelationGraph.AFFINITY_MIN))


# ---------------------------------------------------------------- 대상은 성향을 안 탄다


func test_target_affinity_ignores_traits() -> void:
	# **당한 것은 당한 것이다** (§24.6). 의리형이든 실리형이든 같은 값을 맞는다.
	_world_with(
		[
			_blank(),
			_axis(NpcAxis.Kind.LOYAL, 95),
			_axis(NpcAxis.Kind.LOYAL, -95),
		]
	)
	_resolve(RelationEvent.Kind.BETRAYAL, 0, 1)
	_resolve(RelationEvent.Kind.BETRAYAL, 0, 2)
	assert_eq(_graph.affinity(1, 0), _graph.affinity(2, 0))


func test_actor_gains_bond_but_no_affinity() -> void:
	# 행위자는 유대만. 평판이 굳는 것은 유명세 쪽이고 아직 없다 (§24.21.5).
	_resolve(RelationEvent.Kind.COOPERATION, 0, 1)
	assert_eq(_graph.affinity(0, 1), 0)
	assert_gt(_graph.bond(0, 1), 0)


# ---------------------------------------------------------------- 태생은 안 깎인다


func test_betraying_a_sibling_keeps_the_kin_bond() -> void:
	# **배신해도 혈연은 혈연이다** (§24.18). 원수가 된 가족이 여기서 나온다.
	_graph.link(1, 0, RelationKind.Kind.SIBLING, 40, 80)
	_resolve(RelationEvent.Kind.BETRAYAL, 0, 1)
	assert_eq(_graph.kind_of(1, 0), RelationKind.Kind.SIBLING)
	assert_eq(_graph.bond(1, 0), 80, "태생 유대는 사건이 못 건드린다")
	assert_lt(_graph.affinity(1, 0), 0, "호감은 무너진다")


# ---------------------------------------------------------------- 전멸


func test_wipeout_reaches_the_bonded_without_being_told() -> void:
	# **죽은 자들과 유대 높은 사람 전원에게 사건이 간다** (§24.5 B).
	# 목격자로 넘기지 않았는데도 닿아야 한다.
	_world_with([_blank(), _blank(), _axis(NpcAxis.Kind.RECKLESS, -95)])
	_entangle(2, 1, RelationResolver.SWEEP_BOND_MIN + 10, 60)
	_resolver.resolve(RelationEvent.Kind.WIPEOUT, 0, PackedInt32Array([1]), PackedInt32Array())
	assert_true(_graph.knows(2, 0), "유족이 이끈 사람을 알게 된다")
	assert_lt(_graph.affinity(2, 0), 0, "신중형은 무모한 인솔을 미워한다")


func test_wipeout_skips_the_thinly_bonded() -> void:
	# 유대가 얕은 사람까지 훑으면 사건 하나가 세계의 절반을 흔든다.
	_world_with([_blank(), _blank(), _axis(NpcAxis.Kind.RECKLESS, -95)])
	_entangle(2, 1, RelationResolver.SWEEP_BOND_MIN - 1, 10)
	_resolver.resolve(RelationEvent.Kind.WIPEOUT, 0, PackedInt32Array([1]), PackedInt32Array())
	assert_false(_graph.knows(2, 0))


func test_wipeout_leaves_the_dead_untouched() -> void:
	# 사망은 관계를 동결한다 (§24.5 D) — 죽은 쪽 슬롯이 아예 안 생긴다.
	_resolver.resolve(RelationEvent.Kind.WIPEOUT, 0, PackedInt32Array([1, 2]), PackedInt32Array())
	assert_false(_graph.knows(1, 0))
	assert_true(_graph.knows(0, 1), "이끈 사람에게는 기록이 남는다")


func test_wipeout_takes_several_dead() -> void:
	var cause := _resolver.resolve(
		RelationEvent.Kind.WIPEOUT, 0, PackedInt32Array([1, 2, 3]), PackedInt32Array()
	)
	assert_eq(_ledger.targets_of(cause).size(), 3)


# ---------------------------------------------------------------- 근거 사건


func test_every_touched_relation_remembers_the_cause() -> void:
	# 근거가 없으면 화면이 "왜 그런지" 를 못 말한다 (§24.2).
	_world_with([_blank(), _blank(), _axis(NpcAxis.Kind.LOYAL, 95)])
	_entangle(2, 1, RelationGraph.BOND_MAX)
	var cause := _resolve(RelationEvent.Kind.BETRAYAL, 0, 1, [2])
	assert_eq(_graph.cause_of(1, 0), cause)
	assert_eq(_graph.cause_of(0, 1), cause)
	assert_eq(_graph.cause_of(2, 0), cause)


func test_bad_input_changes_nothing() -> void:
	assert_eq(
		_resolver.resolve(
			RelationEvent.Kind.BETRAYAL, 0, PackedInt32Array([0]), PackedInt32Array()
		),
		RelationLedger.NO_CAUSE,
		"자기 자신을 배신할 수 없다"
	)
	assert_eq(_graph.size(), 0)
	assert_eq(_ledger.size(), 0)


func test_witnesses_never_include_the_parties() -> void:
	# 당사자가 목격자로도 계산되면 호감이 두 번 움직인다.
	var event := RelationEvent.of(RelationEvent.Kind.BETRAYAL)
	_world_with([_axis(NpcAxis.Kind.LOYAL, 95), _axis(NpcAxis.Kind.LOYAL, 95)])
	_resolve(RelationEvent.Kind.BETRAYAL, 0, 1, [0, 1, 1])
	assert_eq(_graph.affinity(1, 0), event.target_affinity)
	assert_eq(_graph.affinity(0, 1), 0)
