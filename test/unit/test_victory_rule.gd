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
