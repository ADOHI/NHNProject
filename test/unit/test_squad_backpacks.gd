extends GutTest
## 백팩이 대원마다 하나인가, 그리고 **실패하면 통째로 잃는가.**
##
## `docs/design/28-combat.md` §28.1-5 · §28.10.
##
## 여기서 지켜야 할 것은 둘이다 — **전부 잃는다**는 것과 **대원은 안 잃는다**는 것.

const BackpacksScript := preload("res://src/core/combat/squad_backpacks.gd")
const ItemScript := preload("res://src/core/combat/backpack_item.gd")

var _packs: SquadBackpacks


func before_each() -> void:
	_packs = BackpacksScript.new()


func _loot(id: String) -> BackpackItem:
	return ItemScript.new(id, id, BackpackItem.Kind.LOOT, [Vector2i(0, 0)])


## 대원 하나에게 백팩을 주고 전리품 몇 개를 채운다.
func _member_with(member_id: String, count: int) -> BackpackGrid:
	var grid := BackpackGrid.new(4, 4, [Vector2i(0, 0)] as Array[Vector2i])
	for index in count:
		grid.place(_loot("%s_%d" % [member_id, index]), Vector2i(index, 0))
	_packs.assign(member_id, grid)
	return grid


# ---------------------------------------------------------------- 대원마다 하나


func test_each_member_carries_their_own_backpack() -> void:
	var first := _member_with("hana", 2)
	var second := _member_with("dul", 1)
	assert_eq(_packs.member_count(), 2)
	assert_eq(_packs.for_member("hana"), first)
	assert_eq(_packs.for_member("dul"), second)
	assert_ne(_packs.for_member("hana"), _packs.for_member("dul"), "백팩이 섞이면 안 된다")


func test_unknown_member_has_no_backpack() -> void:
	assert_false(_packs.has("nobody"))
	assert_null(_packs.for_member("nobody"))
	assert_true(_packs.items_of("nobody").is_empty())


func test_member_order_is_kept() -> void:
	_member_with("hana", 0)
	_member_with("dul", 0)
	_member_with("set", 0)
	assert_eq(_packs.member_ids(), ["hana", "dul", "set"] as Array[String])


func test_reassigning_does_not_duplicate_the_member() -> void:
	_member_with("hana", 1)
	var replacement := BackpackGrid.new(2, 2, [Vector2i(0, 0)] as Array[Vector2i])
	_packs.assign("hana", replacement)
	assert_eq(_packs.member_count(), 1)
	assert_eq(_packs.for_member("hana"), replacement)


func test_total_items_counts_the_whole_squad() -> void:
	_member_with("hana", 2)
	_member_with("dul", 3)
	assert_eq(_packs.total_items(), 5)
	assert_false(_packs.is_empty())


# ---------------------------------------------------------------- 실패 — 통째로 잃는다


func test_failing_loses_every_backpack() -> void:
	_member_with("hana", 2)
	_member_with("dul", 3)

	var lost := _packs.lose_everything()

	assert_eq(lost.size(), 5, "전부 잃는다 (§28.10)")
	assert_eq(_packs.total_items(), 0, "격자가 비어야 한다")
	assert_true(_packs.is_empty())


func test_losing_returns_what_was_lost_for_later_recovery() -> void:
	# §28.10 이 「일부 복구 · 되찾기」를 추후로 미뤘다. 그 자리가 이 반환값이다.
	_member_with("hana", 2)
	var lost := _packs.lose_everything()
	var names := PackedStringArray()
	for item in lost:
		names.append(item.id)
	assert_eq(Array(names), ["hana_0", "hana_1"], "무엇을 잃었는지 알 수 있어야 한다")


func test_losing_keeps_the_members_themselves() -> void:
	# **대원은 잃지 않는다** (§28.10 · 02-overview.md §2.6.1.5 — 몸은 복제된 것이다).
	_member_with("hana", 2)
	_member_with("dul", 1)

	_packs.lose_everything()

	assert_eq(_packs.member_count(), 2, "대원이 사라지면 안 된다")
	assert_eq(_packs.member_ids(), ["hana", "dul"] as Array[String])
	assert_true(_packs.has("hana"))
	assert_not_null(_packs.for_member("hana"), "백팩은 비었을 뿐 없어진 것이 아니다")


func test_the_emptied_backpack_can_be_filled_again() -> void:
	# 실패가 재시작이 아니라 손실이다 — 루프가 계속 돈다 (§28.10).
	var grid := _member_with("hana", 2)
	_packs.lose_everything()
	assert_not_null(grid.place(_loot("new"), Vector2i(0, 0)), "다음 판에 또 채운다")
	assert_eq(_packs.total_items(), 1)


func test_losing_nothing_is_not_an_error() -> void:
	_member_with("hana", 0)
	assert_true(_packs.lose_everything().is_empty())
	assert_eq(_packs.member_count(), 1)


func test_losing_an_empty_squad_is_not_an_error() -> void:
	assert_true(_packs.lose_everything().is_empty())
	assert_eq(_packs.total_items(), 0)
