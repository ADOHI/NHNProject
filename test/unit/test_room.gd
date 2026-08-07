extends GutTest
## Room 의 단위 테스트.

const ActorScript := preload("res://src/core/dungeon/actor.gd")
const RoomScript := preload("res://src/core/dungeon/room.gd")


func _make_actor(id: String, threat: int) -> Actor:
	return ActorScript.new(id, id, Actor.Kind.MONSTER, threat)


func test_empty_room_has_zero_threat() -> void:
	var room: Room = RoomScript.new("cell")
	assert_eq(room.threat(), 0)
	assert_eq(room.occupant_count(), 0)


func test_threat_is_the_sum_of_occupants() -> void:
	var room: Room = RoomScript.new("cell")
	room.add_occupant(_make_actor("a", 2))
	room.add_occupant(_make_actor("b", 3))
	assert_eq(room.threat(), 5)
	assert_eq(room.occupant_count(), 2)


func test_same_actor_is_not_counted_twice() -> void:
	# 중복되면 위험도가 부풀려져 판이 거짓말을 한다.
	var room: Room = RoomScript.new("cell")
	var actor := _make_actor("a", 4)
	room.add_occupant(actor)
	room.add_occupant(actor)
	assert_eq(room.occupant_count(), 1)
	assert_eq(room.threat(), 4)


func test_remove_occupant_lowers_threat() -> void:
	var room: Room = RoomScript.new("cell")
	var actor := _make_actor("a", 4)
	room.add_occupant(actor)
	room.remove_occupant(actor)
	assert_eq(room.threat(), 0)
	assert_false(room.has_occupant(actor))


func test_occupants_returns_a_copy() -> void:
	# 외부에서 내부 배열을 직접 건드리면 방의 위험도가 조용히 어긋난다.
	var room: Room = RoomScript.new("cell")
	room.add_occupant(_make_actor("a", 4))
	var listed := room.occupants()
	listed.clear()
	assert_eq(room.occupant_count(), 1)


func test_display_name_falls_back_to_id() -> void:
	# 기사에서 장소는 사실이어야 하므로 이름이 비어 있으면 안 된다.
	var room: Room = RoomScript.new("west_hall")
	assert_eq(room.display_name, "west_hall")


func test_display_name_is_used_when_given() -> void:
	var room: Room = RoomScript.new("west_hall", "서쪽 회랑")
	assert_eq(room.display_name, "서쪽 회랑")


func test_negative_threat_is_clamped_to_zero() -> void:
	# 음수 전투력은 인접 합을 깎아 다른 방을 숨겨 준다. 판독이 무너진다.
	var room: Room = RoomScript.new("cell")
	room.add_occupant(_make_actor("odd", -5))
	assert_eq(room.threat(), 0)
