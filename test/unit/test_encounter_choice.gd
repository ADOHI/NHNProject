extends GutTest
## 조우에서 고를 수 있는 것과 그 무게. **docs/design/05-rules.md §5.8 · §5.6 E3.**
##
## 여기서 잠기는 것은 하나다 — **E3 의 답이 계수표라는 것.**
##
## §5.6 E3 은 *"서로를 동시에 공격"* 을 보류로 남기며 *"전투는 주고받기식이 아니다"* 라고
## 적었다. docs/design/35-encounter.md §35.3.1 이 그것을 그대로 답으로 삼았다 —
## **동시 공격에 보정을 얹지 않고, 치지 않은 쪽에 벌점을 준다.**
##
## 그래서 이 파일이 지켜야 하는 것은 *"전투와 전투가 같은 계수"* 하나다.
## 그것이 깨지면 심리전이 뒤집힌다.

# ---------------------------------------------------------------- E3


func test_e3_two_who_both_strike_stand_on_equal_footing() -> void:
	# **동시 공격은 예외가 아니라 전투의 기본형이다.** 보정이 없다.
	assert_eq(
		EncounterChoice.weight_of(EncounterChoice.Kind.FIGHT),
		EncounterChoice.weight_of(EncounterChoice.Kind.FIGHT),
		"같은 태세끼리 계수가 갈렸다"
	)
	assert_eq(EncounterChoice.weight_of(EncounterChoice.Kind.FIGHT), EncounterChoice.WEIGHT_FULL)


func test_e3_helping_against_a_monster_is_just_as_committed() -> void:
	# 협력도 치는 것이다. 몬스터를 향할 뿐이다.
	assert_eq(
		EncounterChoice.weight_of(EncounterChoice.Kind.COOPERATE), EncounterChoice.WEIGHT_FULL
	)


func test_e3_the_one_who_did_not_strike_pays_for_it() -> void:
	# 말을 걸다 맞았다 · 등을 보였다 · 준비가 덜 됐다. 셋 다 전투보다 가볍다.
	for kind in [
		EncounterChoice.Kind.STAND, EncounterChoice.Kind.NEGOTIATE, EncounterChoice.Kind.FLEE
	]:
		assert_true(
			EncounterChoice.weight_of(kind) < EncounterChoice.WEIGHT_FULL,
			"안 친 태세가 친 태세와 같은 무게다: %s" % EncounterChoice.label(kind)
		)


func test_talking_and_running_are_the_most_exposed() -> void:
	# 대치는 그래도 상대를 보고 있다. 말을 걸거나 등을 보인 쪽이 더 취약하다.
	assert_true(
		(
			EncounterChoice.weight_of(EncounterChoice.Kind.NEGOTIATE)
			< EncounterChoice.weight_of(EncounterChoice.Kind.STAND)
		)
	)
	assert_eq(
		EncounterChoice.weight_of(EncounterChoice.Kind.FLEE),
		EncounterChoice.weight_of(EncounterChoice.Kind.NEGOTIATE)
	)


# ---------------------------------------------------------------- 무엇이 열리나


func test_cooperation_needs_a_monster_not_a_room() -> void:
	# **방이 아니라 몬스터가 연다** (§35.3.2). 방 종류로 열면 몬스터가 이미 죽은
	# 몬스터방에서도 열리고, 그러면 무엇과 협력한다는 말인가.
	assert_true(EncounterChoice.is_open(EncounterChoice.Kind.COOPERATE, true))
	assert_false(EncounterChoice.is_open(EncounterChoice.Kind.COOPERATE, false))


func test_the_other_three_are_always_open() -> void:
	for kind in [
		EncounterChoice.Kind.FIGHT, EncounterChoice.Kind.NEGOTIATE, EncounterChoice.Kind.FLEE
	]:
		assert_true(EncounterChoice.is_open(kind, false), EncounterChoice.label(kind))


func test_cooperation_without_a_monster_becomes_a_fight() -> void:
	# 거절하지 않고 가장 가까운 것으로 내린다. 낼 때는 몬스터가 있을지 알 수 없다.
	assert_eq(
		EncounterChoice.settle(EncounterChoice.Kind.COOPERATE, false),
		EncounterChoice.Kind.FIGHT,
		"협력할 상대가 없는데 협력으로 남았다"
	)
	assert_eq(
		EncounterChoice.settle(EncounterChoice.Kind.COOPERATE, true), EncounterChoice.Kind.COOPERATE
	)


func test_settling_leaves_the_other_choices_alone() -> void:
	for kind in [
		EncounterChoice.Kind.STAND,
		EncounterChoice.Kind.FIGHT,
		EncounterChoice.Kind.NEGOTIATE,
		EncounterChoice.Kind.FLEE
	]:
		assert_eq(EncounterChoice.settle(kind, false), kind, EncounterChoice.label(kind))


# ---------------------------------------------------------------- 누가 치는가


func test_only_fighting_and_cooperating_mean_harm() -> void:
	# **도주 판정이 이것 하나만 본다** — 쫓는 자가 없으면 무조건 성공한다 (§35.2.2).
	assert_true(EncounterChoice.means_harm(EncounterChoice.Kind.FIGHT))
	assert_true(EncounterChoice.means_harm(EncounterChoice.Kind.COOPERATE))
	assert_false(EncounterChoice.means_harm(EncounterChoice.Kind.STAND))
	assert_false(EncounterChoice.means_harm(EncounterChoice.Kind.NEGOTIATE))
	assert_false(EncounterChoice.means_harm(EncounterChoice.Kind.FLEE))


func test_every_choice_has_a_name() -> void:
	# 이름이 없으면 개발 도구의 표가 번호로 나오고, 그러면 아무도 안 읽는다.
	assert_eq(EncounterChoice.count(), 5)
	for slot in EncounterChoice.count():
		assert_false(
			EncounterChoice.label(slot as EncounterChoice.Kind).is_empty(), "이름이 빈 선택지: %d" % slot
		)
