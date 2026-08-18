extends GutTest
## **싸움이 언제 끝나는가.** 값이 아니라 손잡이다.
##
## `docs/design/28-combat.md` §28.20.43.
##
## 지금까지의 표 스무 개가 전부 「전원 눕히기」 위에 서 있었고
## **그 조건을 아무도 정한 적이 없다.** 그래서 넷을 다 만들어 두고 아무것도 안 고른다.

const RuleScript := preload("res://src/core/combat/victory_rule.gd")


func test_all_down_needs_everyone() -> void:
	assert_eq(RuleScript.needed(VictoryRule.Kind.ALL_DOWN, 4), 4)
	assert_eq(RuleScript.needed(VictoryRule.Kind.ALL_DOWN, 1), 1)


func test_any_one_needs_one() -> void:
	assert_eq(RuleScript.needed(VictoryRule.Kind.ANY_ONE, 6), 1)


func test_majority_is_more_than_half() -> void:
	# 넷이면 셋이어야 과반이다 — 둘은 반이지 과반이 아니다.
	assert_eq(RuleScript.needed(VictoryRule.Kind.MAJORITY, 4), 3)
	assert_eq(RuleScript.needed(VictoryRule.Kind.MAJORITY, 5), 3)
	assert_eq(RuleScript.needed(VictoryRule.Kind.MAJORITY, 1), 1)


func test_nobody_means_nothing_to_beat() -> void:
	assert_eq(RuleScript.needed(VictoryRule.Kind.ALL_DOWN, 0), 0)
	assert_eq(RuleScript.decided_at(VictoryRule.Kind.ALL_DOWN, PackedFloat32Array(), 0), INF)


func test_decided_at_takes_the_nth_to_fall() -> void:
	# 받는 목록이 정렬돼 있지 않아도 된다.
	var times := PackedFloat32Array([9.0, 2.0, 5.0])
	assert_eq(RuleScript.decided_at(VictoryRule.Kind.ANY_ONE, times, 3), 2.0)
	assert_eq(RuleScript.decided_at(VictoryRule.Kind.MAJORITY, times, 3), 5.0)
	assert_eq(RuleScript.decided_at(VictoryRule.Kind.ALL_DOWN, times, 3), 9.0)


func test_not_enough_have_fallen_yet() -> void:
	# **안 누운 쪽은 INF 로 들어온다.** 그것이 정렬되어 뒤로 가면 조건도 INF 다.
	var times := PackedFloat32Array([3.0, INF, INF])
	assert_eq(RuleScript.decided_at(VictoryRule.Kind.ANY_ONE, times, 3), 3.0)
	assert_eq(RuleScript.decided_at(VictoryRule.Kind.ALL_DOWN, times, 3), INF)


func test_a_shorter_list_than_the_headcount_never_decides() -> void:
	# 아직 아무도 안 센 판이 「전원 눕혔다」로 읽히면 안 된다.
	assert_eq(RuleScript.decided_at(VictoryRule.Kind.ALL_DOWN, PackedFloat32Array([1.0]), 3), INF)


func test_every_condition_has_a_name() -> void:
	for kind: VictoryRule.Kind in [
		VictoryRule.Kind.ALL_DOWN,
		VictoryRule.Kind.MAJORITY,
		VictoryRule.Kind.ANY_ONE,
		VictoryRule.Kind.TIMED
	]:
		assert_false(RuleScript.label(kind).is_empty())


# ---------------------------------------------------------------- 우두머리와 섞인 판


func test_a_leader_is_a_particular_one() -> void:
	# **`ANY_ONE`(아무나 하나)과 다르다** — 그 하나가 누워야 한다 (§28.10 · §28.20.44).
	var times := PackedFloat32Array([2.0, 9.0, 5.0])
	assert_eq(RuleScript.leader_decided_at(times, 1), 9.0, "우두머리가 누운 시각이다")
	assert_eq(RuleScript.decided_at(VictoryRule.Kind.ANY_ONE, times, 3), 2.0, "아무나 하나와 다르다")


func test_a_group_without_a_leader_never_decides_that_way() -> void:
	# 몬스터 무리에는 우두머리가 없다. 그 무리는 다른 조건으로 판정한다.
	var times := PackedFloat32Array([2.0, 9.0])
	assert_eq(RuleScript.leader_decided_at(times, -1), INF)
	assert_eq(RuleScript.leader_decided_at(times, 5), INF, "범위를 벗어나도 마찬가지다")


func test_every_group_waits_for_the_slowest() -> void:
	var groups := PackedFloat32Array([3.0, 8.0])
	assert_eq(RuleScript.mixed_decided_at(VictoryRule.Mixed.EVERY_GROUP, groups), 8.0)


func test_any_group_takes_the_first() -> void:
	var groups := PackedFloat32Array([3.0, 8.0])
	assert_eq(RuleScript.mixed_decided_at(VictoryRule.Mixed.ANY_GROUP, groups), 3.0)


func test_an_unfinished_group_holds_everything_up() -> void:
	# **몬스터 전원이 발목을 잡는다** — 사람 쪽 지름길이 값을 잃는 자리다 (§28.20.44).
	var groups := PackedFloat32Array([INF, 4.0])
	assert_eq(RuleScript.mixed_decided_at(VictoryRule.Mixed.EVERY_GROUP, groups), INF)
	assert_eq(RuleScript.mixed_decided_at(VictoryRule.Mixed.ANY_GROUP, groups), 4.0)


func test_no_groups_at_all() -> void:
	assert_eq(RuleScript.mixed_decided_at(VictoryRule.Mixed.EVERY_GROUP, PackedFloat32Array()), INF)
