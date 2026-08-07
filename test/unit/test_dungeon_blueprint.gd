extends GutTest
## DungeonBlueprint 의 단위 테스트.
##
## 설계도는 재사용되고 판은 소모된다. build() 가 매번 독립된 판을 만드는지가 핵심이다.

const BlueprintScript := preload("res://src/core/dungeon/dungeon_blueprint.gd")
const ActorScript := preload("res://src/core/dungeon/actor.gd")


func _make_pair() -> DungeonBlueprint:
	var blueprint: DungeonBlueprint = BlueprintScript.new()
	blueprint.add_room("a", "가")
	blueprint.add_room("b", "나")
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


func test_layout_is_derived_from_elevation() -> void:
	# 좌표는 저장하지 않고 고도에서 만들어 낸다. 판의 규칙이 아니라 표현이기 때문이다.
	var blueprint: DungeonBlueprint = BlueprintScript.new()
	blueprint.add_room("bottom", "아래", 0)
	blueprint.add_room("top", "위", 5)
	blueprint.connect_rooms("bottom", "top")

	var positions := blueprint.layout(Rect2(0, 0, 400, 200))
	assert_true(positions["top"].y < positions["bottom"].y, "높은 방이 위로 가야 한다")


func test_layout_of_a_flat_dungeon_does_not_divide_by_zero() -> void:
	var blueprint: DungeonBlueprint = BlueprintScript.new()
	blueprint.add_room("a", "가", 0)
	blueprint.add_room("b", "나", 0)
	var positions := blueprint.layout(Rect2(0, 0, 400, 200))
	assert_eq(positions.size(), 2)


func test_elevation_and_kind_are_carried_into_the_graph() -> void:
	var blueprint: DungeonBlueprint = BlueprintScript.new()
	blueprint.add_room("vault", "금고", 6, Room.Kind.TREASURE)
	var room := blueprint.build().get_room("vault")
	assert_eq(room.elevation, 6)
	assert_eq(room.kind, Room.Kind.TREASURE)


func test_rooms_of_kind_filters() -> void:
	var blueprint: DungeonBlueprint = BlueprintScript.new()
	blueprint.add_room("in", "입구", 0, Room.Kind.ENTRANCE)
	blueprint.add_room("out", "출구", 0, Room.Kind.EXIT)
	blueprint.add_room("hall", "회랑", 0)
	assert_eq(blueprint.rooms_of_kind(Room.Kind.ENTRANCE), ["in"] as Array[String])
	assert_eq(blueprint.rooms_of_kind(Room.Kind.EMPTY), ["hall"] as Array[String])


func test_duplicate_connection_is_ignored() -> void:
	var blueprint := _make_pair()
	blueprint.connect_rooms("a", "b")
	blueprint.connect_rooms("b", "a")
	assert_eq(blueprint.connections().size(), 1, "같은 간선이 여러 번 들어갔다")


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
	blueprint.add_room("a", "가")
	blueprint.add_room("a", "다시 가")
	assert_eq(blueprint.room_ids().size(), 1)
	assert_push_error_count(1)


func test_connecting_unknown_room_is_rejected() -> void:
	var blueprint: DungeonBlueprint = BlueprintScript.new()
	blueprint.add_room("a", "가")
	blueprint.connect_rooms("a", "nowhere")
	assert_eq(blueprint.connections().size(), 0)
	assert_push_error_count(1)


func test_add_room_is_chainable() -> void:
	var blueprint: DungeonBlueprint = BlueprintScript.new()
	var returned := blueprint.add_room("a", "가").add_room("b", "나", 3)
	assert_eq(returned.room_ids().size(), 2)
