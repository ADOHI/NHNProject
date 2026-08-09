extends GutTest
## 영입 판정을 덮는다. **이것이 열려야 영입이 통째로 열린다.**
##
## docs/design/24-npc-relations.md §24.13 — 조건 셋은 **호감 · 유대 · 성향 궁합**이다.
##
## 이 파일이 지키는 것 —
##
## 1. **관계가 없으면 안 된다.** 자원으로 사는 영입은 설계 6.1 이 막았다
## 2. **실리형은 호감이 낮아도 온다.** 의리형은 사람을 보고 실리형은 조건을 본다
## 3. **자유형은 위계 강한 길드에 안 온다**

var _registry: PersonRegistry
var _graph: RelationGraph


func before_each() -> void:
	_registry = PersonRegistry.new()
	_graph = null


func _blank() -> PackedInt32Array:
	var traits := PackedInt32Array()
	traits.resize(NpcAxis.count())
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


func _ready_graph() -> void:
	_graph = RelationGraph.new(_registry.size())


func _standing(prospect: int, recruiter: int) -> RecruitStanding:
	return RecruitStanding.of(_registry, _graph, prospect, recruiter)


# ---------------------------------------------------------------- 관계가 있어야 한다


func test_strangers_cannot_be_recruited() -> void:
	_add(_blank())
	_add(_blank())
	_ready_graph()
	var standing := _standing(0, 1)
	assert_false(standing.can_recruit())
	assert_string_contains(standing.blocked_reason(), "모르는 사이")


func test_thin_bond_blocks() -> void:
	_add(_blank())
	_add(_blank())
	_ready_graph()
	_graph.link(0, 1, RelationKind.Kind.COMRADESHIP, 90, RecruitStanding.BOND_REQUIRED - 1)
	var standing := _standing(0, 1)
	assert_false(standing.can_recruit())
	assert_string_contains(standing.blocked_reason(), "얕다")


func test_enough_bond_and_affinity_opens_it() -> void:
	# **관계도가 붙기 전에는 이 시험이 성립하지 않았다** — 늘 거짓이었다.
	_add(_blank())
	_add(_blank())
	_ready_graph()
	_graph.link(0, 1, RelationKind.Kind.COMRADESHIP, 60, RecruitStanding.BOND_REQUIRED)
	assert_true(_standing(0, 1).can_recruit())
	assert_eq(_standing(0, 1).blocked_reason(), "")


func test_direction_matters() -> void:
	# 오는 것은 저쪽이다 — **후보가 나를 어떻게 보는가**가 조건이다 (§24.21.2).
	_add(_blank())
	_add(_blank())
	_ready_graph()
	_graph.link(1, 0, RelationKind.Kind.COMRADESHIP, 90, 90)
	assert_false(_standing(0, 1).can_recruit(), "내가 저 사람을 좋아하는 것은 영입과 무관하다")


# ---------------------------------------------------------------- 성향이 문턱을 민다


func test_pragmatic_asks_for_less_affection() -> void:
	# 설계 24.13 — *"실리형은 호감이 낮아도 조건이 좋으면 온다."*
	assert_lt(
		RecruitStanding.required_affinity_for(NpcAxis.MIN_VALUE),
		RecruitStanding.required_affinity_for(NpcAxis.MAX_VALUE)
	)


func test_the_same_affinity_splits_two_people() -> void:
	var loyal := _blank()
	loyal[int(NpcAxis.Kind.LOYAL)] = NpcAxis.MAX_VALUE
	var pragmatic := _blank()
	pragmatic[int(NpcAxis.Kind.LOYAL)] = NpcAxis.MIN_VALUE
	_add(loyal)
	_add(pragmatic)
	_add(_blank())
	_ready_graph()
	var middling := RecruitStanding.AFFINITY_BASE
	_graph.link(0, 2, RelationKind.Kind.COMRADESHIP, middling, 60)
	_graph.link(1, 2, RelationKind.Kind.COMRADESHIP, middling, 60)
	assert_false(_standing(0, 2).can_recruit(), "의리형은 더 요구한다")
	assert_true(_standing(1, 2).can_recruit(), "실리형은 이 정도로 온다")


func test_free_spirit_refuses_a_rigid_guild() -> void:
	# 설계 24.13 — *"자유형은 위계 강한 길드에 오지 않는다."*
	var free := _blank()
	free[int(NpcAxis.Kind.HIERARCHY)] = -80
	var rigid := _blank()
	rigid[int(NpcAxis.Kind.HIERARCHY)] = 80
	_add(free)
	_add(rigid)
	_ready_graph()
	_graph.link(0, 1, RelationKind.Kind.COMRADESHIP, 90, 90)
	var standing := _standing(0, 1)
	assert_false(standing.can_recruit())
	assert_string_contains(standing.blocked_reason(), "위계관")


func test_clash_needs_both_sides_to_be_extreme() -> void:
	# 한쪽만 극단이면 안 걸린다 — 걸리게 하면 자유형이 아무 데도 못 간다.
	var free := _blank()
	free[int(NpcAxis.Kind.HIERARCHY)] = -80
	_add(free)
	_add(_blank())
	_ready_graph()
	_graph.link(0, 1, RelationKind.Kind.COMRADESHIP, 90, 90)
	assert_true(_standing(0, 1).can_recruit())


func test_blocked_reason_names_the_pole_not_the_number() -> void:
	# 성향 값을 그대로 내면 읽는 쪽이 부호를 해석해야 한다 (§24.25).
	var free := _blank()
	free[int(NpcAxis.Kind.HIERARCHY)] = -80
	var rigid := _blank()
	rigid[int(NpcAxis.Kind.HIERARCHY)] = 80
	_add(free)
	_add(rigid)
	_ready_graph()
	_graph.link(0, 1, RelationKind.Kind.COMRADESHIP, 90, 90)
	var reason := _standing(0, 1).blocked_reason()
	assert_string_contains(reason, "자유")
	assert_string_contains(reason, "위계")


func test_self_is_never_a_prospect() -> void:
	_add(_blank())
	_ready_graph()
	assert_false(_standing(0, 0).can_recruit())


# ---------------------------------------------------------------- 후보가 이것을 든다


func test_prospect_without_a_standing_says_why() -> void:
	# 접선처는 아직 세계의 인물 번호를 모른다 (설계 24.1 의 2층).
	var prospect := RecruitProspect.new("p1", "김건규", MemberDiscipline.Kind.COMBAT)
	assert_false(prospect.can_recruit())
	assert_false(prospect.blocked_reason().is_empty())
	assert_string_contains(prospect.blocked_reason(), "미구현")


func test_prospect_with_a_standing_can_open() -> void:
	# **`can_recruit()` 이 더 이상 상수가 아니다.**
	_add(_blank())
	_add(_blank())
	_ready_graph()
	_graph.link(0, 1, RelationKind.Kind.COMRADESHIP, 60, RecruitStanding.BOND_REQUIRED)
	var prospect := RecruitProspect.new("p1", "김건규", MemberDiscipline.Kind.COMBAT)
	prospect.standing = _standing(0, 1)
	assert_true(prospect.can_recruit())
	assert_eq(prospect.blocked_reason(), "")
