extends GutTest
## 관계 저장을 덮는다.
##
## **비대칭이고 희소하다** (docs/design/24-npc-relations.md §24.2 · §24.21).
## 그리고 **태생 관계는 사건이 유대를 못 깎는다** — §24.18 이 밝힌 자리이고
## 여기서 안 되면 "원수가 된 가족" 이 "남이 된 가족" 으로 납작해진다.

const _PEOPLE := 6


func _graph() -> RelationGraph:
	return RelationGraph.new(_PEOPLE)


func test_starts_with_nobody_knowing_anybody() -> void:
	# 기본은 「모르는 사이」다. 관계는 명시적으로 만든 것만 존재한다 (§24.2).
	var graph := _graph()
	assert_eq(graph.size(), 0)
	assert_false(graph.knows(0, 1))
	assert_eq(graph.affinity(0, 1), 0)
	assert_eq(graph.bond(0, 1), 0)


func test_link_is_one_directional() -> void:
	var graph := _graph()
	graph.link(0, 1, RelationKind.Kind.COMRADESHIP, 40, 30)
	assert_true(graph.knows(0, 1))
	assert_false(graph.knows(1, 0), "내가 아는 사람이 나를 모를 수 있다")


func test_directions_hold_different_values() -> void:
	var graph := _graph()
	graph.link(0, 1, RelationKind.Kind.SIBLING, 80, 70)
	graph.link(1, 0, RelationKind.Kind.SIBLING, -30, 70)
	assert_eq(graph.affinity(0, 1), 80)
	assert_eq(graph.affinity(1, 0), -30, "배신은 본질적으로 비대칭이다 (§24.2)")


func test_self_relation_is_refused() -> void:
	assert_eq(_graph().link(0, 0, RelationKind.Kind.SIBLING, 50, 50), RelationGraph.NO_RELATION)


func test_link_twice_keeps_the_first() -> void:
	var graph := _graph()
	graph.link(0, 1, RelationKind.Kind.SIBLING, 50, 60)
	graph.link(0, 1, RelationKind.Kind.BETRAYED, -90, 10)
	assert_eq(graph.affinity(0, 1), 50)
	assert_eq(graph.size(), 1)


func test_values_are_clamped() -> void:
	var graph := _graph()
	graph.link(0, 1, RelationKind.Kind.SIBLING, 900, 900)
	assert_eq(graph.affinity(0, 1), RelationGraph.AFFINITY_MAX)
	assert_eq(graph.bond(0, 1), RelationGraph.BOND_MAX)
	graph.link(1, 0, RelationKind.Kind.SIBLING, -900, -900)
	assert_eq(graph.affinity(1, 0), RelationGraph.AFFINITY_MIN)
	assert_eq(graph.bond(1, 0), RelationGraph.BOND_MIN)


func test_neighbours_are_listed() -> void:
	var graph := _graph()
	graph.link(0, 1, RelationKind.Kind.SIBLING, 10, 10)
	graph.link(0, 2, RelationKind.Kind.MASTER, 10, 10)
	assert_eq(graph.degree_of(0), 2)
	var targets := Array(graph.targets_of(0))
	assert_true(targets.has(1) and targets.has(2))


func test_lookup_is_stable_with_many_neighbours() -> void:
	# 조회가 차수만큼 걷는다 (§24.21.1). 고리가 끊기면 여기서 잡힌다.
	var graph := RelationGraph.new(40)
	for other in range(1, 40):
		graph.link(0, other, RelationKind.Kind.COMRADESHIP, other, other)
	for other in range(1, 40):
		assert_eq(graph.affinity(0, other), other)
	assert_eq(graph.degree_of(0), 39)


# ---------------------------------------------------------------- 사건이 움직인다


func test_adjust_creates_when_missing() -> void:
	# 관계는 사건의 찌꺼기다 (§24.5).
	var graph := _graph()
	graph.adjust(0, 1, -40, 5, RelationKind.Kind.BETRAYED, 7)
	assert_true(graph.knows(0, 1))
	assert_eq(graph.affinity(0, 1), -40)
	assert_eq(graph.kind_of(0, 1), RelationKind.Kind.BETRAYED)
	assert_eq(graph.cause_of(0, 1), 7)


func test_adjust_moves_both_axes() -> void:
	var graph := _graph()
	graph.link(0, 1, RelationKind.Kind.COMRADESHIP, 20, 30)
	graph.adjust(0, 1, -50, 10, RelationKind.Kind.BETRAYED, 3)
	assert_eq(graph.affinity(0, 1), -30)
	assert_eq(graph.bond(0, 1), 40)


# ---------------------------------------------------------------- 태생은 안 깎인다


func test_a_relation_never_disappears() -> void:
	# **한 번 생긴 선은 안 사라진다** (사용자, §24.37.1). 이 클래스에는 지우는 함수가
	# 아예 없고, 그것이 이 시스템의 안전 장치다 — 관계도가 흔들리면 그 위에 얹힌
	# 화면 · 영입 판정 · 렉카 입력이 다 흔들린다.
	#
	# **바닥을 쳐도 남는다.** 호감 −100 · 유대 0 은 「모르는 사이」와 다르다 —
	# 모르는 사이는 슬롯이 없고, 이쪽은 슬롯이 있고 근거 사건이 붙어 있다.
	var graph := RelationGraph.new(3)
	graph.link(0, 1, RelationKind.Kind.COMRADESHIP, 60, 40, 7)
	for _try in 20:
		graph.adjust(0, 1, -100, -100, RelationKind.Kind.NONE)
	assert_true(graph.knows(0, 1), "값이 바닥을 쳐도 선은 남는다")
	assert_eq(graph.size(), 1)
	assert_eq(graph.affinity(0, 1), RelationGraph.AFFINITY_MIN)
	assert_eq(graph.bond(0, 1), RelationGraph.BOND_MIN)
	assert_eq(graph.cause_of(0, 1), 7, "근거 사건도 안 지워진다")


func test_inborn_bond_survives_a_betrayal() -> void:
	# §24.18 의 핵심 — 배신해도 혈연은 혈연이다.
	var graph := _graph()
	graph.link(0, 1, RelationKind.Kind.SIBLING, 60, 80)
	graph.adjust(0, 1, -140, -60, RelationKind.Kind.BETRAYED, 1)
	assert_eq(graph.bond(0, 1), 80, "태생 관계는 유대가 안 깎인다")
	assert_eq(graph.affinity(0, 1), -80, "호감은 무너진다")


func test_inborn_kind_does_not_change() -> void:
	# 유형이 갈리면 "원수가 된 가족" 이 "남이 된 가족" 으로 납작해진다.
	var graph := _graph()
	graph.link(0, 1, RelationKind.Kind.PARENT, 60, 80)
	graph.adjust(0, 1, -100, -50, RelationKind.Kind.BETRAYED, 1)
	assert_eq(graph.kind_of(0, 1), RelationKind.Kind.PARENT)


func test_inborn_still_records_the_cause() -> void:
	# 바뀌는 것은 호감과 근거 사건이다.
	var graph := _graph()
	graph.link(0, 1, RelationKind.Kind.SIBLING, 60, 80)
	graph.adjust(0, 1, -30, 0, RelationKind.Kind.BETRAYED, 42)
	assert_eq(graph.cause_of(0, 1), 42)


func test_earned_bond_can_be_cut() -> void:
	var graph := _graph()
	graph.link(0, 1, RelationKind.Kind.COMRADESHIP, 60, 80)
	graph.adjust(0, 1, 0, -50, RelationKind.Kind.NONE, 1)
	assert_eq(graph.bond(0, 1), 30)
	assert_eq(graph.kind_of(0, 1), RelationKind.Kind.COMRADESHIP, "NONE 은 유형을 안 지운다")


func test_every_inborn_kind_is_protected() -> void:
	for kind in RelationKind.count():
		var value := kind as RelationKind.Kind
		if not RelationKind.is_inborn(value):
			continue
		var graph := _graph()
		graph.link(0, 1, value, 0, 50)
		graph.adjust(0, 1, 0, -50, RelationKind.Kind.BETRAYED, 1)
		assert_eq(graph.bond(0, 1), 50, RelationKind.label(value))


func test_opposite_pairs_up() -> void:
	assert_eq(RelationKind.opposite(RelationKind.Kind.PARENT), RelationKind.Kind.CHILD)
	assert_eq(RelationKind.opposite(RelationKind.Kind.CHILD), RelationKind.Kind.PARENT)
	assert_eq(RelationKind.opposite(RelationKind.Kind.SIBLING), RelationKind.Kind.SIBLING)
	assert_eq(RelationKind.opposite(RelationKind.Kind.MASTER), RelationKind.Kind.STUDENT)
