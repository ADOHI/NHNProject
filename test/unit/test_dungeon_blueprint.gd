extends GutTest
## DungeonBlueprint 의 단위 테스트.
##
## 설계도는 재사용되고 판은 소모된다. build() 가 매번 독립된 판을 만드는지가 핵심이다.

const BlueprintScript := preload("res://src/core/dungeon/dungeon_blueprint.gd")
const ActorScript := preload("res://src/core/dungeon/actor.gd")


## 방 n 개를 고리 모양으로 이은 판. 자리를 고를 여지가 있어야 배치를 검사할 수 있다.
func _make_ring(count: int) -> DungeonBlueprint:
	var blueprint: DungeonBlueprint = BlueprintScript.new()
	for i in count:
		blueprint.add_room("r%d" % i, "방 %d" % i)
	for i in count:
		blueprint.connect_rooms("r%d" % i, "r%d" % ((i + 1) % count))
	return blueprint


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


func test_layout_ignores_elevation() -> void:
	# 탑뷰다. 위에서 내려다보면 높이는 평면 위치와 무관하다.
	# 고도를 눈으로 보여 주는 것은 나중에 측면뷰가 맡는다.
	var flat: DungeonBlueprint = BlueprintScript.new()
	flat.add_room("a", "가", 0)
	flat.add_room("b", "나", 0)
	flat.connect_rooms("a", "b")

	var stepped: DungeonBlueprint = BlueprintScript.new()
	stepped.add_room("a", "가", 0)
	stepped.add_room("b", "나", 9)
	stepped.connect_rooms("a", "b")

	assert_eq(flat.layout(7), stepped.layout(7), "고도가 배치를 바꿨다")


func test_layout_is_deterministic() -> void:
	# 배치가 매번 달라지면 "아까 그 판"을 다시 볼 수 없다.
	var blueprint := _make_pair()
	assert_eq(blueprint.layout(3), blueprint.layout(3))


func test_layout_differs_by_seed() -> void:
	# 방이 둘뿐이면 어느 시드로 시작하든 같은 대칭 위치로 수렴한다.
	# 시드가 의미를 갖는 것은 자리를 고를 여지가 있을 때다.
	var blueprint := _make_ring(8)
	assert_ne(blueprint.layout(1), blueprint.layout(2))


func test_layout_keeps_rooms_apart() -> void:
	# 방이 겹치면 이름도 숫자도 못 읽는다.
	var blueprint := _make_ring(8)
	var spacing := 200.0
	var positions := blueprint.layout(5, spacing)
	var ids := positions.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var gap: float = (positions[ids[i]] as Vector2).distance_to(positions[ids[j]])
			assert_gt(gap, spacing * 0.85, "%s 와 %s 가 너무 가깝다" % [ids[i], ids[j]])


func test_layout_starts_at_positive_coordinates() -> void:
	# 좌상단을 기준으로 정규화해 두면 화면에 올릴 때 계산이 단순해진다.
	var blueprint := _make_pair()
	for position in blueprint.layout(4).values():
		assert_gt((position as Vector2).x, 0.0)
		assert_gt((position as Vector2).y, 0.0)


func test_layout_of_empty_blueprint_is_empty() -> void:
	var blueprint: DungeonBlueprint = BlueprintScript.new()
	assert_eq(blueprint.layout(1).size(), 0)


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
