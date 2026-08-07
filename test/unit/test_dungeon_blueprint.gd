extends GutTest
## DungeonBlueprint 의 단위 테스트.
##
## 설계도는 재사용되고 판은 소모된다. build() 가 매번 독립된 판을 만드는지가 핵심이다.

const BlueprintScript := preload("res://src/core/dungeon/dungeon_blueprint.gd")
const ActorScript := preload("res://src/core/dungeon/actor.gd")


func _make_pair() -> DungeonBlueprint:
	var blueprint: DungeonBlueprint = BlueprintScript.new()
	blueprint.add_room("a", "가", Vector2(10, 20))
	blueprint.add_room("b", "나", Vector2(30, 40))
	blueprint.connect_rooms("a", "b")
	return blueprint


func test_build_creates_rooms_and_links() -> void:
	var graph := _make_pair().build()
	assert_true(graph.has_room("a"))
	assert_true(graph.has_room("b"))
	assert_true(graph.are_connected("a", "b"))
	assert_true(graph.are_connected("b", "a"))


func test_build_carries_display_names() -> void:
	var graph := _make_pair().build()
	assert_eq(graph.get_room("a").display_name, "가")


func test_layout_position_is_kept_out_of_the_graph() -> void:
	# 좌표는 판의 규칙이 아니라 표현이다. 그래서 설계도만 안다.
	var blueprint := _make_pair()
	assert_eq(blueprint.position_of("a"), Vector2(10, 20))
	assert_eq(blueprint.position_of("nowhere"), Vector2.ZERO)


func test_each_build_is_independent() -> void:
	# 설계도는 재사용된다. 한 판에 놓은 존재가 다음 판에 남아 있으면 안 된다.
	var blueprint := _make_pair()
	var first := blueprint.build()
	first.place_actor(ActorScript.new("mob", "몹", Actor.Kind.MONSTER, 5), "a")

	var second := blueprint.build()
	assert_eq(first.threat_at("a"), 5)
	assert_eq(second.threat_at("a"), 0, "새 판에 이전 판의 존재가 남아 있다")


func test_duplicate_room_is_rejected() -> void:
	var blueprint: DungeonBlueprint = BlueprintScript.new()
	blueprint.add_room("a", "가", Vector2.ZERO)
	blueprint.add_room("a", "다시 가", Vector2.ONE)
	assert_eq(blueprint.room_ids().size(), 1)
	assert_push_error_count(1)


func test_connecting_unknown_room_is_rejected() -> void:
	var blueprint: DungeonBlueprint = BlueprintScript.new()
	blueprint.add_room("a", "가", Vector2.ZERO)
	blueprint.connect_rooms("a", "nowhere")
	assert_eq(blueprint.connections().size(), 0)
	assert_push_error_count(1)


func test_add_room_is_chainable() -> void:
	var blueprint: DungeonBlueprint = BlueprintScript.new()
	var returned := blueprint.add_room("a", "가", Vector2.ZERO).add_room("b", "나", Vector2.ONE)
	assert_eq(returned.room_ids().size(), 2)
