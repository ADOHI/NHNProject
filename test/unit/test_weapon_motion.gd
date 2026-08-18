extends GutTest
## 무기가 얼마나 나가고 얼마나 닿는가 — **캐릭터 애니 레인 실측표.**
##
## `docs/design/28-combat.md` §28.20.30.
##
## **여기는 표가 제대로 읽히는지만 본다.** 값 자체는 저쪽 것이고, 저쪽이 옮기면
## 이 파일이 걸린다. 그게 걸리라고 둔 것이다.

const ItemScript := preload("res://src/core/combat/backpack_item.gd")


func _shaped(width: int, height: int) -> BackpackItem:
	var shape: Array[Vector2i] = []
	for x in width:
		for y in height:
			shape.append(Vector2i(x, y))
	return ItemScript.new(
		"w%dx%d" % [width, height],
		"%dx%d" % [width, height],
		BackpackItem.Kind.WEAPON,
		shape,
		Vector2i(0, 0),
		ChainDirection.Kind.RIGHT
	)


# ---------------------------------------------------------------- 실측표


func test_the_measured_shapes_match_the_animation_lane() -> void:
	assert_almost_eq(WeaponMotion.advance_px(_shaped(1, 1)), 25.0, 0.01)
	assert_almost_eq(WeaponMotion.reach_px(_shaped(1, 1)), 104.0, 0.01)
	assert_almost_eq(WeaponMotion.advance_px(_shaped(3, 1)), 10.7, 0.01)
	assert_almost_eq(WeaponMotion.advance_px(_shaped(2, 2)), 22.0, 0.01)
	assert_almost_eq(WeaponMotion.reach_px(_shaped(4, 1)), 118.0, 0.01)


func test_orientation_does_not_matter() -> void:
	# 감싸는 상자로 찾으므로 세워 놓든 눕혀 놓든 같은 무기다.
	assert_eq(WeaponMotion.advance_px(_shaped(3, 1)), WeaponMotion.advance_px(_shaped(1, 3)))
	assert_eq(WeaponMotion.reach_px(_shaped(3, 1)), WeaponMotion.reach_px(_shaped(1, 3)))


func test_shape_matters_not_just_cell_count() -> void:
	# **창은 안 나가고 철퇴는 파고든다.** 칸 수로 뽑으면 이 차이가 사라진다.
	var spear := _shaped(3, 1)
	var mace := _shaped(2, 2)
	assert_true(
		WeaponMotion.advance_px(mace) > WeaponMotion.advance_px(spear) * 2.0,
		"4칸 철퇴가 3칸 창보다 두 배 넘게 파고든다"
	)


func test_reach_includes_the_advance() -> void:
	# 빼고 재면 단검이 실제보다 훨씬 짧은 무기가 된다.
	var dagger := _shaped(1, 1)
	assert_almost_eq(
		WeaponMotion.static_reach_px(dagger),
		WeaponMotion.reach_px(dagger) - WeaponMotion.advance_px(dagger),
		0.01
	)


func test_static_reach_depends_only_on_the_long_side() -> void:
	# 2x1 과 2x2 는 팔+무기 길이가 똑같이 91 이다.
	assert_almost_eq(
		WeaponMotion.static_reach_px(_shaped(2, 1)),
		WeaponMotion.static_reach_px(_shaped(2, 2)),
		0.01
	)


func test_longer_weapons_reach_further() -> void:
	var previous := 0.0
	for length in [1, 2, 3, 4]:
		var reach := WeaponMotion.static_reach_px(_shaped(length, 1))
		assert_true(reach > previous, "%d칸 길이에서 사거리가 안 늘었다" % length)
		previous = reach


func test_shorter_weapons_advance_further() -> void:
	# 전진은 무기 길이의 역함수다 — 짧은 무기가 더 파고든다.
	assert_true(
		WeaponMotion.advance_px(_shaped(1, 1)) > WeaponMotion.advance_px(_shaped(3, 1)),
		"단검이 창보다 많이 파고든다"
	)


# ---------------------------------------------------------------- 표에 없는 모양


func test_unmeasured_shapes_fall_back_and_say_so() -> void:
	var odd := _shaped(3, 2)
	assert_false(WeaponMotion.is_measured(odd), "3x2 는 표에 없다")
	assert_true(WeaponMotion.is_measured(_shaped(2, 2)), "2x2 는 표에 있다")
	assert_almost_eq(WeaponMotion.advance_px(odd), WeaponMotion.advance_px(_shaped(3, 1)), 0.01)


func test_every_sample_item_gets_a_value() -> void:
	for item in SampleBackpack.create_items():
		assert_true(WeaponMotion.reach_px(item) > 0.0, "%s 에 리치가 없다" % item.id)
		assert_true(WeaponMotion.advance_px(item) >= 0.0)
