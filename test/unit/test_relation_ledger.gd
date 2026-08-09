extends GutTest
## 사건 기록을 덮는다.
##
## docs/design/24-npc-relations.md §24.2 · §24.19.
##
## **수치 옆에 사연이 있어야 한다** — 설계 24.2 가
## *"수치를 보여주지 않고 사연을 보여주면 방향이 읽힌다"* 라고 했다.
## 여기가 그 사연을 들고 있고, 관계는 정수 하나로 그것을 가리킨다.

var _registry: PersonRegistry
var _ledger: RelationLedger


func before_each() -> void:
	_registry = PersonRegistry.new()
	# 받침이 있는 이름과 없는 이름을 섞는다 — 조사가 갈리는 자리다.
	for person_name in ["김건규", "양은담", "최윤호"]:
		var traits := PackedInt32Array()
		traits.resize(NpcAxis.count())
		_registry.add(
			person_name,
			MemberDiscipline.Kind.COMBAT,
			1,
			1,
			PersonRegistry.NO_FACTION,
			0,
			30,
			PersonGender.Kind.MALE,
			traits
		)
	_ledger = RelationLedger.new()


func test_ids_run_in_order() -> void:
	assert_eq(_ledger.record(RelationEvent.Kind.COOPERATION, 0, PackedInt32Array([1])), 0)
	assert_eq(_ledger.record(RelationEvent.Kind.BETRAYAL, 1, PackedInt32Array([2])), 1)
	assert_eq(_ledger.size(), 2)


func test_targets_stay_with_their_event() -> void:
	# 대상은 평평한 배열에 눕혀 있다. 시작점이 어긋나면 남의 대상이 나온다.
	_ledger.record(RelationEvent.Kind.WIPEOUT, 0, PackedInt32Array([1, 2]))
	_ledger.record(RelationEvent.Kind.BETRAYAL, 1, PackedInt32Array([0]))
	assert_eq(Array(_ledger.targets_of(0)), [1, 2])
	assert_eq(Array(_ledger.targets_of(1)), [0])


func test_roles_are_told_apart() -> void:
	var cause := _ledger.record(RelationEvent.Kind.BETRAYAL, 0, PackedInt32Array([1]))
	assert_eq(_ledger.role_of(cause, 0), "행위자")
	assert_eq(_ledger.role_of(cause, 1), "대상")
	assert_eq(_ledger.role_of(cause, 2), "목격자")


func test_role_phrase_picks_the_right_ending() -> void:
	# `대상였다` 가 나오면 화면이 한국어를 못 쓰는 것으로 읽힌다.
	var cause := _ledger.record(RelationEvent.Kind.BETRAYAL, 0, PackedInt32Array([1]))
	assert_eq(_ledger.role_phrase(cause, 1), "대상이었다")
	assert_eq(_ledger.role_phrase(cause, 0), "행위자였다")


func test_description_picks_particles_by_final_consonant() -> void:
	# 받침 있는 이름과 없는 이름이 다른 조사를 받아야 한다.
	var open_name := _ledger.record(RelationEvent.Kind.BETRAYAL, 0, PackedInt32Array([1]))
	assert_string_contains(_ledger.describe(open_name, _registry), "김건규가")
	assert_string_contains(_ledger.describe(open_name, _registry), "양은담을")
	var closed_name := _ledger.record(RelationEvent.Kind.BETRAYAL, 1, PackedInt32Array([2]))
	assert_string_contains(_ledger.describe(closed_name, _registry), "양은담이")
	assert_string_contains(_ledger.describe(closed_name, _registry), "최윤호를")


func test_description_names_the_event() -> void:
	for kind in RelationEvent.count():
		var cause := _ledger.record(kind as RelationEvent.Kind, 0, PackedInt32Array([1]))
		assert_string_contains(
			_ledger.describe(cause, _registry), RelationEvent.label(kind as RelationEvent.Kind)
		)


func test_a_targetless_event_has_no_object() -> void:
	# 길드 이탈은 대상이 없다 (§24.36.1). 목적어 없는 문장이 나와야 한다.
	var cause := _ledger.record(RelationEvent.Kind.DEFECT, 0, PackedInt32Array())
	var text := _ledger.describe(cause, _registry)
	assert_string_contains(text, "소속을 버렸다")
	assert_false(text.contains("양은담"), "대상 이름이 들어가면 안 된다")


func test_a_new_event_never_gets_written_as_cooperation() -> void:
	# **arm 을 안 받은 사건이 조용히 협력으로 적히던 자리다.** 화면에서 진짜 협력과
	# 구별되지 않으므로 기본값이 라벨이어야 한다.
	for kind in RelationEvent.count():
		if kind == int(RelationEvent.Kind.COOPERATION):
			continue
		var cause := _ledger.record(kind as RelationEvent.Kind, 0, PackedInt32Array([1]))
		assert_false(
			_ledger.describe(cause, _registry).begins_with("협력"),
			RelationEvent.label(kind as RelationEvent.Kind)
		)


func test_wipeout_description_counts_the_dead() -> void:
	var cause := _ledger.record(RelationEvent.Kind.WIPEOUT, 0, PackedInt32Array([1, 2]))
	assert_string_contains(_ledger.describe(cause, _registry), "2명")


func test_unknown_cause_says_nothing() -> void:
	assert_eq(_ledger.describe(RelationLedger.NO_CAUSE, _registry), "")
	assert_eq(_ledger.role_of(99, 0), "")


func test_history_comes_from_the_relations() -> void:
	# **인물별 색인을 따로 두지 않는다** — 관계가 근거 사건을 이미 들고 있다.
	var graph := RelationGraph.new(_registry.size())
	var resolver := RelationResolver.new(_registry, graph, _ledger)
	var first := resolver.resolve(
		RelationEvent.Kind.COOPERATION, 0, PackedInt32Array([1]), PackedInt32Array()
	)
	var second := resolver.resolve(
		RelationEvent.Kind.BETRAYAL, 0, PackedInt32Array([2]), PackedInt32Array()
	)
	assert_eq(Array(_ledger.causes_of(graph, 0)), [first, second])
	assert_eq(Array(_ledger.causes_of(graph, 1)), [first])


func test_history_has_no_duplicates() -> void:
	var graph := RelationGraph.new(_registry.size())
	var resolver := RelationResolver.new(_registry, graph, _ledger)
	var cause := resolver.resolve(
		RelationEvent.Kind.WIPEOUT, 0, PackedInt32Array([1, 2]), PackedInt32Array()
	)
	assert_eq(Array(_ledger.causes_of(graph, 0)), [cause], "두 대상이 같은 사건을 가리킨다")
