extends GutTest
## 목격자 계산을 덮는다. **여기서만 성향이 작동한다** (설계 24.6 · 24.21.5).
##
## 설계 24.6 — *"목격자 계산이 이 시스템의 전부다. 나머지 둘은 사실 관계라 성향을 안 탄다."*
## 그래서 행위자 · 대상과 파일을 갈랐다.
##
## 지켜야 할 것 셋 —
##
## 1. **성향이 정반대면 반응도 정반대다.** 규칙 하나로 사람이 갈린다 (설계 24.4)
## 2. **유대가 안 오른다** — 그래서 한쪽만 아는 관계가 생기고, 그것이 화면에서
##    비대칭이 드러나는 유일한 자리다
## 3. **관여도가 크기를 정한다** — 남이면 무덤덤, 제 사람이면 크게

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


func test_opposite_witnesses_move_in_opposite_directions() -> void:
	# §24.4 의 예 그대로다 — 의리형은 "저 새끼 사람 버렸다", 실리형은 "나였어도".
	_world_with(
		[
			_blank(),
			_blank(),
			_axis(NpcAxis.Kind.LOYAL, 95),
			_axis(NpcAxis.Kind.LOYAL, -95),
		]
	)
	_entangle(2, 1, RelationGraph.BOND_MAX)
	_entangle(3, 1, RelationGraph.BOND_MAX)
	_resolve(RelationEvent.Kind.BETRAYAL, 0, 1, [2, 3])
	assert_lt(_graph.affinity(2, 0), 0, "의리형은 배신을 미워한다")
	assert_gt(_graph.affinity(3, 0), 0, "실리형은 배신을 이해한다")


func test_colourless_witness_leaves_no_relation() -> void:
	# 극이 없는 사람은 거의 안 움직이고, 안 움직이면 관계도 안 남는다 (§24.21.6).
	_resolve(RelationEvent.Kind.BETRAYAL, 0, 1, [2])
	assert_false(_graph.knows(2, 0), "아무 감정도 안 생긴 사람은 아는 사이가 아니다")


func test_witness_bond_stays_zero() -> void:
	# **보는 것은 엮이는 것이 아니다** (§24.21.5). 유대가 오르면 희소가 무너진다.
	_world_with([_blank(), _blank(), _axis(NpcAxis.Kind.LOYAL, 95)])
	_entangle(2, 1, RelationGraph.BOND_MAX)
	_resolve(RelationEvent.Kind.BETRAYAL, 0, 1, [2])
	assert_true(_graph.knows(2, 0))
	assert_eq(_graph.bond(2, 0), 0)


func test_witness_makes_a_one_way_relation() -> void:
	# **한쪽만 아는 관계는 사건만이 만든다.** 태생 관계는 늘 양방향이다 (§24.21.2).
	_world_with([_blank(), _blank(), _axis(NpcAxis.Kind.LOYAL, 95)])
	_entangle(2, 1, RelationGraph.BOND_MAX)
	_resolve(RelationEvent.Kind.BETRAYAL, 0, 1, [2])
	assert_true(_graph.knows(2, 0), "목격자는 행위자를 안다")
	assert_false(_graph.knows(0, 2), "행위자는 목격자를 모른다")


func test_witness_kind_follows_the_sign() -> void:
	_world_with(
		[
			_blank(),
			_blank(),
			_axis(NpcAxis.Kind.LOYAL, 95),
			_axis(NpcAxis.Kind.LOYAL, -95),
		]
	)
	_entangle(2, 1, RelationGraph.BOND_MAX)
	_entangle(3, 1, RelationGraph.BOND_MAX)
	_resolve(RelationEvent.Kind.BETRAYAL, 0, 1, [2, 3])
	assert_eq(_graph.kind_of(2, 0), RelationKind.Kind.GRUDGE)
	assert_eq(_graph.kind_of(3, 0), RelationKind.Kind.TRUST)


func test_witness_does_not_relabel_an_existing_relation() -> void:
	# 생사고락이 한 번 본 일로 「원한」이 되면 유형이 딱지 노릇을 못 한다 (§24.2).
	_world_with([_blank(), _blank(), _axis(NpcAxis.Kind.LOYAL, 95)])
	_graph.link(2, 0, RelationKind.Kind.COMRADESHIP, 40, 50)
	_resolve(RelationEvent.Kind.BETRAYAL, 0, 1, [2])
	assert_eq(_graph.kind_of(2, 0), RelationKind.Kind.COMRADESHIP)
	assert_lt(_graph.affinity(2, 0), 40, "호감은 움직인다")


func test_involvement_scales_with_bond() -> void:
	# **남이면 무덤덤, 제 사람이면 크게** (§24.6). 관여도가 그 말을 수치로 만든다.
	_world_with(
		[
			_blank(),
			_blank(),
			_axis(NpcAxis.Kind.LOYAL, 95),
			_axis(NpcAxis.Kind.LOYAL, 95),
		]
	)
	# 3 번만 대상과 깊이 엮여 있다.
	_graph.link(3, 1, RelationKind.Kind.SIBLING, 60, RelationGraph.BOND_MAX)
	_resolve(RelationEvent.Kind.BETRAYAL, 0, 1, [2, 3])
	assert_lt(_graph.affinity(3, 0), _graph.affinity(2, 0), "제 사람이 당하면 더 크게 흔들린다")


func test_witness_floor_keeps_strangers_reacting() -> void:
	# 바닥이 0 이면 남의 일에는 아무 반응이 없어서 세계가 안 퍼진다.
	assert_gt(RelationResolver.WITNESS_FLOOR, 0.0)
