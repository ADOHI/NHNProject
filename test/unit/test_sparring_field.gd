extends GutTest
## 대련장의 거리.
##
## `docs/design/28-combat.md` §28.20.27.
##
## **리치와 전진 값은 아직 없다** — 애니 레인이 낼 때까지 짐작으로 안 넣는다.
## 여기서 보는 것은 거리 자체가 제대로 서는가뿐이다.

const FieldScript := preload("res://src/core/combat/sparring_field.gd")


func test_gap_is_the_distance_between_them() -> void:
	assert_eq(FieldScript.new(0.0, 240.0).gap(), 240.0)
	assert_eq(FieldScript.new(100.0, 40.0).gap(), 60.0, "왼쪽에 있어도 거리는 양수다")


func test_facing_follows_the_target() -> void:
	assert_eq(FieldScript.new(0.0, 240.0).facing(), 1.0)
	assert_eq(FieldScript.new(240.0, 0.0).facing(), -1.0)


func test_advancing_closes_the_gap() -> void:
	var field := FieldScript.new(0.0, 240.0)
	field.advance(90.0)
	assert_eq(field.attacker_x, 90.0)
	assert_eq(field.gap(), 150.0, "다가간 만큼 거리가 준다")


func test_advancing_never_passes_the_target() -> void:
	# 지나치게 두면 전진이 쌓였을 때 대원이 적 뒤로 빠져 방향이 뒤집힌다.
	var field := FieldScript.new(0.0, 100.0)
	field.advance(999.0)
	assert_eq(field.attacker_x, 100.0)
	assert_eq(field.facing(), 1.0, "방향이 뒤집히면 안 된다")


func test_advancing_from_the_right_side_also_stops() -> void:
	var field := FieldScript.new(300.0, 100.0)
	field.advance(999.0)
	assert_eq(field.attacker_x, 100.0)


func test_advancing_backwards_does_nothing() -> void:
	var field := FieldScript.new(0.0, 240.0)
	field.advance(-50.0)
	assert_eq(field.attacker_x, 0.0)


func test_reset_puts_them_back() -> void:
	var field := FieldScript.new(0.0, 240.0)
	field.advance(100.0)
	field.reset(0.0, 240.0)
	assert_eq(field.attacker_x, 0.0)
	assert_eq(field.gap(), 240.0)


# ---------------------------------------------------------------- 전진 뒤 남나 돌아오나


func test_returning_is_the_default_and_leaves_no_ground_gained() -> void:
	# **미정이다.** 어느 쪽이 옳다는 것이 아니라 둘 다 되어야 한다는 것이 요점이다.
	var field := FieldScript.new(0.0, 240.0)
	field.advance_mode = SparringField.AdvanceMode.RETURN
	field.swing_advance(25.0)
	assert_eq(field.attacker_x, 0.0, "돌아오면 제자리다")


func test_staying_accumulates_across_swings() -> void:
	var field := FieldScript.new(0.0, 240.0)
	field.advance_mode = SparringField.AdvanceMode.STAY
	for _swing in 5:
		field.swing_advance(25.0)
	assert_eq(field.attacker_x, 125.0, "5타가 다섯 번 밀고 들어간다")
	assert_eq(field.gap(), 115.0)


func test_staying_still_never_passes_the_target() -> void:
	var field := FieldScript.new(0.0, 100.0)
	field.advance_mode = SparringField.AdvanceMode.STAY
	for _swing in 20:
		field.swing_advance(25.0)
	assert_eq(field.attacker_x, 100.0)
