extends GutTest
## **이 시스템의 심장을 덮는 테스트다** — 백팩 배치가 콤보 루트를 정하는가.
##
## `docs/design/28-combat.md` §28.2 · §28.20.4 · §28.20.5.
##
## 여기서 제일 중요한 것은 `test_moving_one_item_rewrites_the_chain` 이다.
## 그것이 깨지면 §28.2 의 *"백팩 정리가 곧 콤보 루트 설계다"* 가 거짓이 된다.

const GridScript := preload("res://src/core/combat/backpack_grid.gd")
const ItemScript := preload("res://src/core/combat/backpack_item.gd")
const ResolverScript := preload("res://src/core/combat/chain_resolver.gd")


## 아무것도 잇지 못하게 하는 조건. §28.2.2 의 자리가 실제로 열려 있는지 본다.
class RefuseEverything:
	extends ChainLinkRule

	func can_link(_from: BackpackPlacement, _to: BackpackPlacement) -> bool:
		return false


## 전리품으로는 못 잇는 조건. 「깐깐한 조건」의 한 가지 모양을 흉내 낸 것이다.
class RefuseLoot:
	extends ChainLinkRule

	func can_link(_from: BackpackPlacement, to: BackpackPlacement) -> bool:
		return to.item.kind != BackpackItem.Kind.LOOT


func _grid(width: int = 5, height: int = 5) -> BackpackGrid:
	return GridScript.new(width, height, [Vector2i(0, 0)] as Array[Vector2i])


## 한 칸짜리 무기. 방향만 다르게 여러 개 만든다.
func _pip(id: String, direction: ChainDirection.Kind) -> BackpackItem:
	return ItemScript.new(
		id, id, BackpackItem.Kind.WEAPON, [Vector2i(0, 0)], Vector2i(0, 0), direction
	)


func _loot(id: String) -> BackpackItem:
	return ItemScript.new(id, id, BackpackItem.Kind.LOOT, [Vector2i(0, 0)])


# ---------------------------------------------------------------- 기본 진행


func test_chain_follows_the_output_direction() -> void:
	var grid := _grid()
	grid.place(_pip("a", ChainDirection.Kind.RIGHT), Vector2i(0, 0))
	grid.place(_pip("b", ChainDirection.Kind.DOWN), Vector2i(1, 0))
	grid.place(_loot("c"), Vector2i(1, 1))

	var chain := ResolverScript.resolve_from(grid, Vector2i(0, 0))
	assert_eq(Array(chain.item_names()), ["a", "b", "c"])
	assert_eq(chain.length(), 3)
	assert_true(chain.is_complete(), "전리품에 닿아 끝난 것은 정상 종료다")
	assert_eq(chain.stop_reason, ChainResult.StopReason.NO_OUTPUT)


func test_diagonal_neighbours_do_not_connect() -> void:
	# 방향은 네 갈래뿐이다. 대각선으로 붙여 놓아도 이어지지 않는다.
	var grid := _grid()
	grid.place(_pip("a", ChainDirection.Kind.RIGHT), Vector2i(0, 0))
	grid.place(_pip("b", ChainDirection.Kind.DOWN), Vector2i(1, 1))

	var chain := ResolverScript.resolve_from(grid, Vector2i(0, 0))
	assert_eq(chain.length(), 1)
	assert_eq(chain.stop_reason, ChainResult.StopReason.EMPTY_CELL)


func test_chain_steps_one_cell_and_does_not_scan_the_ray() -> void:
	# §28.20.4 — 「그 방향으로 쭉 훑기」가 아니라 「한 칸」이다.
	# 한 칸 띄워 두면 저 너머에 아이템이 있어도 이어지지 않아야 한다.
	var grid := _grid()
	grid.place(_pip("a", ChainDirection.Kind.RIGHT), Vector2i(0, 0))
	grid.place(_pip("far", ChainDirection.Kind.DOWN), Vector2i(3, 0))

	var chain := ResolverScript.resolve_from(grid, Vector2i(0, 0))
	assert_eq(chain.length(), 1, "한 칸 건너뛴 것은 붙은 것이 아니다")
	assert_eq(chain.stop_reason, ChainResult.StopReason.EMPTY_CELL)
	assert_eq(chain.break_cell, Vector2i(1, 0), "끊긴 자리를 알려 줘야 한다")


func test_multi_cell_item_chains_from_its_output_block_only() -> void:
	# 창은 가로 3칸인데 출력은 맨 오른쪽 칸 하나뿐이고 위를 가리킨다.
	# 왼쪽 칸 위에 아이템을 놓아도 이어지면 안 된다.
	var grid := _grid()
	var spear := ItemScript.new(
		"spear",
		"창",
		BackpackItem.Kind.WEAPON,
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
		Vector2i(2, 0),
		ChainDirection.Kind.UP
	)
	grid.place(spear, Vector2i(0, 1))
	grid.place(_loot("wrong"), Vector2i(0, 0))
	grid.place(_loot("right"), Vector2i(2, 0))

	var chain := ResolverScript.resolve_from(grid, Vector2i(0, 1))
	assert_eq(Array(chain.item_names()), ["창", "right"], "출력 블럭이 가리킨 쪽으로만 간다")


# ---------------------------------------------------------------- 멈추는 이유


func test_empty_start_node_yields_no_chain() -> void:
	var chain := ResolverScript.resolve_from(_grid(), Vector2i(0, 0))
	assert_eq(chain.length(), 0)
	assert_eq(chain.stop_reason, ChainResult.StopReason.NO_START_ITEM)
	assert_false(chain.is_complete())


func test_pointing_off_the_grid_stops_the_chain() -> void:
	var grid := _grid()
	grid.place(_pip("a", ChainDirection.Kind.UP), Vector2i(0, 0))

	var chain := ResolverScript.resolve_from(grid, Vector2i(0, 0))
	assert_eq(chain.length(), 1)
	assert_eq(chain.stop_reason, ChainResult.StopReason.OUT_OF_BOUNDS)


func test_a_loop_stops_instead_of_spinning_forever() -> void:
	var grid := _grid()
	grid.place(_pip("a", ChainDirection.Kind.RIGHT), Vector2i(0, 0))
	grid.place(_pip("b", ChainDirection.Kind.LEFT), Vector2i(1, 0))

	var chain := ResolverScript.resolve_from(grid, Vector2i(0, 0))
	assert_eq(Array(chain.item_names()), ["a", "b"], "고리는 한 바퀴만 돈다")
	assert_eq(chain.stop_reason, ChainResult.StopReason.ALREADY_CHAINED)
	assert_false(chain.is_complete(), "고리는 정상 종료가 아니다")


func test_item_pointing_into_itself_stops() -> void:
	var grid := _grid()
	var folded := ItemScript.new(
		"folded",
		"접힌 것",
		BackpackItem.Kind.WEAPON,
		[Vector2i(0, 0), Vector2i(1, 0)],
		Vector2i(1, 0),
		ChainDirection.Kind.LEFT
	)
	grid.place(folded, Vector2i(0, 0))

	var chain := ResolverScript.resolve_from(grid, Vector2i(0, 0))
	assert_eq(chain.length(), 1)
	assert_eq(chain.stop_reason, ChainResult.StopReason.ALREADY_CHAINED)


func test_every_stop_reason_has_a_readable_label() -> void:
	for reason in ChainResult.StopReason.values():
		assert_false(ChainResult.reason_label(reason).is_empty(), "멈춘 이유 %d 에 이름이 없다" % reason)


# ---------------------------------------------------------------- 갈아 끼울 조건 (§28.2.2)


func test_default_rule_connects_everything_that_points_correctly() -> void:
	var grid := _grid()
	grid.place(_pip("a", ChainDirection.Kind.RIGHT), Vector2i(0, 0))
	grid.place(_loot("b"), Vector2i(1, 0))
	assert_eq(ResolverScript.resolve_from(grid, Vector2i(0, 0)).length(), 2)


func test_a_stricter_rule_can_cut_the_chain() -> void:
	var grid := _grid()
	grid.place(_pip("a", ChainDirection.Kind.RIGHT), Vector2i(0, 0))
	grid.place(_pip("b", ChainDirection.Kind.RIGHT), Vector2i(1, 0))

	var chain := ResolverScript.resolve_from(grid, Vector2i(0, 0), RefuseEverything.new())
	assert_eq(chain.length(), 1, "조건이 거절하면 시작 아이템만 남는다")
	assert_eq(chain.stop_reason, ChainResult.StopReason.LINK_REJECTED)


func test_a_rule_can_look_at_what_the_items_are() -> void:
	var grid := _grid()
	grid.place(_pip("a", ChainDirection.Kind.RIGHT), Vector2i(0, 0))
	grid.place(_pip("b", ChainDirection.Kind.RIGHT), Vector2i(1, 0))
	grid.place(_loot("gem"), Vector2i(2, 0))

	var loose := ResolverScript.resolve_from(grid, Vector2i(0, 0))
	var strict := ResolverScript.resolve_from(grid, Vector2i(0, 0), RefuseLoot.new())
	assert_eq(Array(loose.item_names()), ["a", "b", "gem"])
	assert_eq(Array(strict.item_names()), ["a", "b"], "전리품을 막는 조건이 실제로 먹는다")
	assert_eq(strict.stop_reason, ChainResult.StopReason.LINK_REJECTED)


# ---------------------------------------------------------------- 시작 노드 여럿 (§28.20.7)


func test_every_start_node_produces_its_own_chain() -> void:
	var grid := GridScript.new(5, 5, [Vector2i(0, 0), Vector2i(4, 4)] as Array[Vector2i])
	grid.place(_pip("a", ChainDirection.Kind.RIGHT), Vector2i(0, 0))
	grid.place(_loot("b"), Vector2i(1, 0))
	grid.place(_pip("c", ChainDirection.Kind.LEFT), Vector2i(4, 4))
	grid.place(_loot("d"), Vector2i(3, 4))

	var chains := ResolverScript.resolve_all(grid)
	assert_eq(chains.size(), 2, "시작 노드마다 체인이 하나씩 나온다")
	assert_eq(Array(chains[0].item_names()), ["a", "b"])
	assert_eq(Array(chains[1].item_names()), ["c", "d"])


func test_resolve_all_on_a_single_start_node_grid() -> void:
	var chains := ResolverScript.resolve_all(_grid())
	assert_eq(chains.size(), 1)
	assert_eq(chains[0].start_node, Vector2i(0, 0))


# ---------------------------------------------------------------- 배치가 루트를 정한다


func test_moving_one_item_rewrites_the_chain() -> void:
	# **이 테스트가 §28.2 의 "백팩 정리가 곧 콤보 루트 설계다" 를 지킨다.**
	var grid := _grid()
	grid.place(_pip("start", ChainDirection.Kind.RIGHT), Vector2i(0, 0))
	var swing := grid.place(_pip("swing", ChainDirection.Kind.DOWN), Vector2i(1, 0))
	grid.place(_loot("finish"), Vector2i(1, 1))

	var before := ResolverScript.resolve_from(grid, Vector2i(0, 0))
	assert_eq(Array(before.item_names()), ["start", "swing", "finish"])

	# 딱 한 칸 아래로 내렸을 뿐인데 시작 아이템이 더는 그것을 가리키지 못한다.
	assert_true(grid.move(swing, Vector2i(1, 2)))

	var after := ResolverScript.resolve_from(grid, Vector2i(0, 0))
	assert_eq(Array(after.item_names()), ["start"], "배치를 바꾸면 체인이 바뀐다")
	assert_eq(after.stop_reason, ChainResult.StopReason.EMPTY_CELL)


func test_loot_on_the_route_cuts_the_combo_short() -> void:
	# §28.20.3 — 칸 압박이 규칙 없이 격자에서 나온다.
	var grid := _grid()
	grid.place(_pip("start", ChainDirection.Kind.RIGHT), Vector2i(0, 0))
	grid.place(_pip("second", ChainDirection.Kind.RIGHT), Vector2i(1, 0))
	grid.place(_pip("third", ChainDirection.Kind.RIGHT), Vector2i(2, 0))
	var long_chain := ResolverScript.resolve_from(grid, Vector2i(0, 0))
	assert_eq(long_chain.length(), 3)

	# 루팅한 물건을 루트 한복판에 끼워 넣는다.
	grid.remove(grid.placement_at(Vector2i(1, 0)))
	grid.place(_loot("plunder"), Vector2i(1, 0))

	var cut := ResolverScript.resolve_from(grid, Vector2i(0, 0))
	assert_eq(Array(cut.item_names()), ["start", "plunder"], "전리품이 루트를 막는다")
	assert_true(cut.length() < long_chain.length())


# ---------------------------------------------------------------- 표본


func test_sample_backpack_opens_with_a_readable_chain() -> void:
	var grid := SampleBackpack.create_grid()
	SampleBackpack.fill(grid, SampleBackpack.create_items())

	var chains := ResolverScript.resolve_all(grid)
	assert_eq(chains.size(), 1)
	assert_eq(Array(chains[0].item_names()), ["단검", "건틀릿", "철퇴", "창", "원석"])
	assert_true(chains[0].is_complete(), "표본은 전리품에 닿아 끝난다 (§28.20.3)")
