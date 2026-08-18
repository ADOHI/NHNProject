extends GutTest
## 아이템의 「한 블럭과 방향」이 제대로 서 있는가.
##
## `docs/design/28-combat.md` §28.20.2 · §28.20.8.
##
## 여기서 가장 잘 틀리는 것은 **회전**이다. 모양 · 출력 블럭 · 출력 방향 셋이
## 함께 돌지 않으면 돌린 무기가 엉뚱한 데를 가리키는데, 화면으로는 잘 안 보인다.

const ItemScript := preload("res://src/core/combat/backpack_item.gd")


func _dagger() -> BackpackItem:
	# 세로 2칸. 아래 칸이 출력이고 아래를 가리킨다.
	return ItemScript.new(
		"dagger",
		"단검",
		BackpackItem.Kind.WEAPON,
		[Vector2i(0, 0), Vector2i(0, 1)],
		Vector2i(0, 1),
		ChainDirection.Kind.DOWN
	)


# ---------------------------------------------------------------- 모양


func test_shape_is_normalized_to_top_left() -> void:
	var item := ItemScript.new(
		"offset",
		"치우친 것",
		BackpackItem.Kind.WEAPON,
		[Vector2i(3, 5), Vector2i(4, 5)],
		Vector2i(4, 5),
		ChainDirection.Kind.RIGHT
	)
	assert_eq(item.shape, [Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i])
	assert_eq(item.output_cell, Vector2i(1, 0), "출력 블럭도 같이 옮겨진다")


func test_cells_at_translates_shape() -> void:
	var cells := _dagger().cells_at(Vector2i(2, 3))
	assert_eq(cells, [Vector2i(2, 3), Vector2i(2, 4)] as Array[Vector2i])


func test_bounds_size_covers_every_cell() -> void:
	var axe := ItemScript.new(
		"axe",
		"도끼",
		BackpackItem.Kind.WEAPON,
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
		Vector2i(1, 1),
		ChainDirection.Kind.DOWN
	)
	assert_eq(axe.bounds_size(), Vector2i(2, 2))


# ---------------------------------------------------------------- 출력


func test_output_target_steps_one_cell() -> void:
	# 단검이 (2, 3) 에 놓이면 출력 블럭은 (2, 4), 아래 한 칸은 (2, 5).
	assert_eq(_dagger().output_cell_at(Vector2i(2, 3)), Vector2i(2, 4))
	assert_eq(_dagger().output_target_at(Vector2i(2, 3)), Vector2i(2, 5))


func test_loot_has_no_output() -> void:
	var gem := ItemScript.new("gem", "원석", BackpackItem.Kind.LOOT, [Vector2i(0, 0)])
	assert_false(gem.has_output(), "전리품은 체인을 이어 가지 못한다")
	assert_eq(gem.output_direction, ChainDirection.Kind.NONE)


func test_weapon_has_output() -> void:
	assert_true(_dagger().has_output())


# ---------------------------------------------------------------- 회전


func test_rotation_turns_shape_and_direction_together() -> void:
	# 세로 2칸 + 아래 방향  ->  시계 90도  ->  가로 2칸 + 왼쪽 방향.
	var turned := _dagger().rotated()
	assert_eq(turned.shape.size(), 2)
	assert_eq(turned.bounds_size(), Vector2i(2, 1), "세로가 가로가 된다")
	assert_eq(turned.output_direction, ChainDirection.Kind.LEFT)


func test_rotation_keeps_output_cell_inside_shape() -> void:
	var item := _dagger()
	for _turn in 4:
		item = item.rotated()
		assert_true(item.shape.has(item.output_cell), "회전해도 출력 블럭은 아이템 안에 있어야 한다")


func test_four_rotations_return_to_start() -> void:
	var original := _dagger()
	var item := original.rotated().rotated().rotated().rotated()
	assert_eq(item.shape, original.shape)
	assert_eq(item.output_cell, original.output_cell)
	assert_eq(item.output_direction, original.output_direction)


func test_rotation_leaves_the_original_alone() -> void:
	# 같은 아이템이 격자와 대기줄 양쪽에서 참조될 수 있다. 한쪽에서 돌렸다고
	# 다른 쪽이 같이 돌면 안 된다.
	var original := _dagger()
	var before := original.output_direction
	original.rotated()
	assert_eq(original.output_direction, before)


func test_rotate_offset_lands_inside_the_rotated_shape() -> void:
	# 화면이 집은 지점이 회전 뒤에도 아이템 안에 있어야 손가락 밑에 남는다.
	var axe := ItemScript.new(
		"axe",
		"도끼",
		BackpackItem.Kind.WEAPON,
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
		Vector2i(1, 1),
		ChainDirection.Kind.DOWN
	)
	var turned := axe.rotated()
	for cell in axe.shape:
		assert_true(turned.shape.has(axe.rotate_offset(cell)), "%s 가 회전 뒤 모양 밖으로 나갔다" % cell)


func test_rotate_offset_agrees_with_rotated_output_cell() -> void:
	# 같은 회전 규칙을 두 곳에서 쓰므로 결과가 갈리면 안 된다.
	var item := _dagger()
	assert_eq(item.rotate_offset(item.output_cell), item.rotated().output_cell)


func test_rotated_loot_still_has_no_output() -> void:
	var gem := ItemScript.new("gem", "원석", BackpackItem.Kind.LOOT, [Vector2i(0, 0)])
	assert_false(gem.rotated().has_output())


# ---------------------------------------------------------------- 방향 표


func test_direction_vectors_match_screen_coordinates() -> void:
	assert_eq(ChainDirection.to_vector(ChainDirection.Kind.UP), Vector2i(0, -1), "y 는 아래로 는다")
	assert_eq(ChainDirection.to_vector(ChainDirection.Kind.DOWN), Vector2i(0, 1))
	assert_eq(ChainDirection.to_vector(ChainDirection.Kind.NONE), Vector2i.ZERO)


func test_direction_rotation_agrees_with_cell_rotation() -> void:
	# 두 회전 규칙이 어긋나면 돌린 무기가 엉뚱한 데를 가리킨다.
	for kind in [
		ChainDirection.Kind.UP,
		ChainDirection.Kind.RIGHT,
		ChainDirection.Kind.DOWN,
		ChainDirection.Kind.LEFT
	]:
		var by_direction := ChainDirection.to_vector(ChainDirection.rotated_cw(kind))
		var by_cell := ChainDirection.rotate_cell_cw(ChainDirection.to_vector(kind))
		assert_eq(by_direction, by_cell, "%s 에서 두 규칙이 갈렸다" % ChainDirection.label(kind))
