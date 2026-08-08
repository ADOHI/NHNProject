extends GutTest
## 격자가 「무엇이 어디에 있는가」를 틀리지 않는가.
##
## `docs/design/28-combat.md` §28.20.1.
##
## 가장 잘 틀리는 것은 **자기 자신을 조금 옮기는 것**이다. 옛 자리를 겹침 검사에서
## 빼 두지 않으면 한 칸 옆으로도 못 움직인다.

const GridScript := preload("res://src/core/combat/backpack_grid.gd")
const ItemScript := preload("res://src/core/combat/backpack_item.gd")


func _grid() -> BackpackGrid:
	return GridScript.new(4, 4, [Vector2i(0, 0)] as Array[Vector2i])


func _block() -> BackpackItem:
	# 가로 2칸. 오른쪽 칸이 출력이고 오른쪽을 가리킨다.
	return ItemScript.new(
		"block",
		"덩어리",
		BackpackItem.Kind.WEAPON,
		[Vector2i(0, 0), Vector2i(1, 0)],
		Vector2i(1, 0),
		ChainDirection.Kind.RIGHT
	)


# ---------------------------------------------------------------- 놓기


func test_placing_fills_every_cell_it_covers() -> void:
	var grid := _grid()
	var placed := grid.place(_block(), Vector2i(1, 1))
	assert_not_null(placed)
	assert_eq(grid.placement_at(Vector2i(1, 1)), placed)
	assert_eq(grid.placement_at(Vector2i(2, 1)), placed)
	assert_null(grid.placement_at(Vector2i(3, 1)), "차지하지 않은 칸은 비어 있다")


func test_overlapping_placement_is_refused() -> void:
	var grid := _grid()
	assert_not_null(grid.place(_block(), Vector2i(0, 0)))
	assert_null(grid.place(_block(), Vector2i(1, 0)), "겹치면 못 놓는다")
	assert_eq(grid.placements().size(), 1, "실패한 배치가 목록에 남으면 안 된다")


func test_placement_outside_the_grid_is_refused() -> void:
	var grid := _grid()
	assert_null(grid.place(_block(), Vector2i(3, 0)), "오른쪽 칸이 격자 밖이다")
	assert_null(grid.place(_block(), Vector2i(-1, 0)))
	assert_true(grid.is_empty())


func test_removing_frees_the_cells() -> void:
	var grid := _grid()
	var placed := grid.place(_block(), Vector2i(0, 2))
	assert_true(grid.remove(placed))
	assert_null(grid.placement_at(Vector2i(0, 2)))
	assert_null(grid.placement_at(Vector2i(1, 2)))
	assert_true(grid.is_empty())
	assert_false(grid.remove(placed), "이미 뺀 것을 또 빼면 거짓이다")


# ---------------------------------------------------------------- 옮기기


func test_moving_onto_its_own_old_cells_succeeds() -> void:
	var grid := _grid()
	var placed := grid.place(_block(), Vector2i(0, 0))
	assert_true(grid.move(placed, Vector2i(1, 0)), "한 칸 옆은 자기 자신과만 겹친다")
	assert_eq(placed.origin, Vector2i(1, 0))
	assert_null(grid.placement_at(Vector2i(0, 0)), "떠난 칸은 비어야 한다")
	assert_eq(grid.placement_at(Vector2i(2, 0)), placed)


func test_failed_move_leaves_everything_where_it_was() -> void:
	var grid := _grid()
	var first := grid.place(_block(), Vector2i(0, 0))
	grid.place(_block(), Vector2i(2, 2))
	assert_false(grid.move(first, Vector2i(2, 2)), "남의 자리로는 못 간다")
	assert_eq(first.origin, Vector2i(0, 0))
	assert_eq(grid.placement_at(Vector2i(0, 0)), first, "실패해도 제자리에 남아 있어야 한다")
	assert_eq(grid.placements().size(), 2)


func test_move_keeps_the_same_placement_object() -> void:
	# 화면이 끌고 있는 객체와 격자 안의 객체가 갈라지면 드래그가 유령을 남긴다.
	var grid := _grid()
	var placed := grid.place(_block(), Vector2i(0, 0))
	grid.move(placed, Vector2i(0, 1))
	assert_eq(grid.placements()[0], placed)


# ---------------------------------------------------------------- 시작 노드


func test_start_nodes_are_a_list_not_a_single_cell() -> void:
	# 개수가 미정이라 목록으로 들고 있다 (§28.20.7).
	var grid := GridScript.new(4, 4, [Vector2i(0, 0), Vector2i(3, 3)] as Array[Vector2i])
	assert_eq(grid.start_nodes.size(), 2)
	assert_true(grid.is_start_node(Vector2i(3, 3)))
	assert_false(grid.is_start_node(Vector2i(1, 1)))


func test_bounds_check() -> void:
	var grid := _grid()
	assert_true(grid.contains(Vector2i(3, 3)))
	assert_false(grid.contains(Vector2i(4, 3)))
	assert_false(grid.contains(Vector2i(0, -1)))


# ---------------------------------------------------------------- 표본


func test_sample_layout_fits_the_sample_grid() -> void:
	var grid := SampleBackpack.create_grid()
	var leftover := SampleBackpack.fill(grid, SampleBackpack.create_items())
	assert_eq(
		grid.placements().size(), SampleBackpack.default_layout().size(), "기본 배치가 전부 격자에 들어가야 한다"
	)
	assert_false(leftover.is_empty(), "대기줄에도 아이템이 남아 있어야 만져 볼 수 있다")
