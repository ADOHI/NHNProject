extends GutTest
## 소지품과 정산. **docs/design/05-rules.md §5.3.**
##
## | 구분 | 사망 시 | 탈출 시 |
## | --- | --- | --- |
## | 던전에서 주운 전리품 | **상실** | 획득 확정 |
##
## **잃는 것은 물건뿐이다. 사람은 잃지 않는다** (§14.6).
##
## 사망 정산은 규칙만 서 있고 부르는 곳이 없다 — 전투 판정(§5.5)이 미정이라
## *"언제 죽는가"* 가 없기 때문이다. 규칙을 여기서 잠가 두면 전투가 붙을 때
## 정산을 다시 설계하지 않아도 된다.


func test_nothing_carried_at_the_start() -> void:
	var haul := Haul.new()

	assert_eq(haul.carried_by("squad"), 0)
	assert_false(haul.is_carrying("squad"))


func test_what_you_pick_up_stacks() -> void:
	var haul := Haul.new()
	haul.add("squad", 3)
	haul.add("squad", 4)

	assert_eq(haul.carried_by("squad"), 7)


func test_nothing_is_not_a_pickup() -> void:
	# 빈 방을 뒤진 것이 소지품 0 짜리 항목으로 남으면 셈이 흐려진다.
	var haul := Haul.new()
	haul.add("squad", 0)

	assert_false(haul.is_carrying("squad"))


func test_getting_out_makes_it_yours() -> void:
	var haul := Haul.new()
	haul.add("squad", 6)

	assert_eq(haul.settle_escape("squad"), 6)
	assert_eq(haul.banked_by("squad"), 6)
	assert_eq(haul.carried_by("squad"), 0, "확정된 것이 아직 들려 있다")


func test_going_down_loses_what_you_held() -> void:
	var haul := Haul.new()
	haul.add("squad", 6)

	assert_eq(haul.settle_death("squad"), 6)
	assert_eq(haul.carried_by("squad"), 0)


func test_going_down_does_not_touch_what_was_already_banked() -> void:
	# 이미 지켜 낸 것은 지난 판의 결과다. 이번 판의 사고가 그것까지 가져가면
	# 익스트랙션이 아니라 벌칙이 된다.
	var haul := Haul.new()
	haul.add("squad", 6)
	haul.settle_escape("squad")
	haul.add("squad", 4)
	haul.settle_death("squad")

	assert_eq(haul.banked_by("squad"), 6)


func test_everyone_is_counted_the_same_way() -> void:
	# NPC 탐험가도 같은 규칙 아래 줍고 나간다 (§5.2.2).
	var haul := Haul.new()
	haul.add("squad", 3)
	haul.add("rival", 5)

	assert_eq(haul.total_carried(), 8)
	assert_eq(haul.carried_by("rival"), 5)
