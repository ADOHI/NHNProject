extends GutTest
## 배회의 단위 테스트.
##
## **§30.3.2 의 계약 셋이 그대로 이 파일의 목록이다.**
##
## 1. 서 있는 동안 좌표가 바뀌지 않는다 (밀림 0)
## 2. 다시 움직이는 이유는 자기 결정뿐이다
## 3. 막히면 그 자리에 선다. 뚫지 않는다
##
## 이동 레인의 «정지밀림 0» 을 그대로 못 물려받아 새로 쓴 계약이라(배회에는 «제 자리» 가 없다)
## **지키는 것도 여기서 새로 지켜야 한다.**

const GridScript := preload("res://src/core/hideout/hideout_grid.gd")
const BuildingScript := preload("res://src/core/hideout/hideout_building.gd")
const CrowdScript := preload("res://src/core/hideout/hideout_crowd.gd")

var _grid: HideoutGrid
var _crowd: HideoutCrowd


func before_each() -> void:
	_grid = GridScript.new(14, 14)
	_crowd = CrowdScript.new(_grid, 1234)


func _run(seconds: float, step: float = 1.0 / 60.0) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		_crowd.tick(step)
		elapsed += step


func _positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for index in _crowd.count():
		out.append(_crowd.person(index)["at"])
	return out


# ------------------------------------------------------------------ 세우기


func test_spawning_needs_walkable_ground() -> void:
	assert_true(_crowd.spawn("a", Vector2i(3, 3)))
	assert_eq(_crowd.count(), 1)
	assert_false(_crowd.spawn("b", Vector2i(99, 99)), "판 밖에는 못 선다")


func test_cannot_stand_on_a_building() -> void:
	var shop: HideoutBuilding = BuildingScript.new(
		"shop", Facility.Kind.WORKSHOP, Vector2i(2, 2), Vector2i(4, 4)
	)
	_grid.place(shop)
	assert_false(_crowd.spawn("a", Vector2i(4, 4)), "건물 위에는 못 선다")


func test_scattered_spawn_finds_room_for_everyone() -> void:
	var names: Array[String] = ["a", "b", "c", "d", "e", "f"]
	assert_eq(_crowd.spawn_scattered(names), 6)
	assert_eq(_crowd.count(), 6)


# ------------------------------------------------------------------ 계약 1 · 2


## 서 있는 동안에는 좌표가 안 바뀐다. 남이 밀어서 움직이는 일은 없다.
func test_standing_people_do_not_drift() -> void:
	_crowd.spawn("a", Vector2i(3, 3))
	var person := _crowd.person(0)
	person["wait"] = 999.0
	var was: Vector2 = person["at"]
	_run(5.0)
	assert_eq(_crowd.person(0)["at"], was, "서 있는데 움직였다")
	assert_eq(_crowd.person(0)["state"], HideoutCrowd.State.STANDING)


## 기다리는 시간이 지나기 전에는 스스로도 안 움직인다 — 움직이는 이유는 자기 결정뿐이다.
func test_nobody_leaves_before_their_own_pause_is_over() -> void:
	_crowd.spawn("a", Vector2i(3, 3))
	_crowd.person(0)["wait"] = 2.0
	_run(1.0)
	assert_eq(_crowd.person(0)["state"], HideoutCrowd.State.STANDING)
	_run(2.0)
	assert_eq(_crowd.person(0)["state"], HideoutCrowd.State.WALKING, "제 시간이 지나면 간다")


func test_people_actually_wander() -> void:
	_crowd.spawn_scattered(["a", "b", "c", "d"] as Array[String])
	var before := _positions()
	_run(12.0)
	var moved := 0
	for index in _crowd.count():
		if _crowd.person(index)["at"].distance_to(before[index]) > 0.5:
			moved += 1
	assert_gt(moved, 0, "아무도 안 움직이면 배회가 아니다")


# ------------------------------------------------------------------ 계약 3


## 막히면 선다. 뚫지도 돌아가지도 않는다 — 그래서 길찾기가 없어도 성립한다.
func test_walkers_never_end_up_inside_a_building() -> void:
	var shop: HideoutBuilding = BuildingScript.new(
		"shop", Facility.Kind.WORKSHOP, Vector2i(4, 4), Vector2i(5, 5)
	)
	_grid.place(shop)
	_crowd.spawn_scattered(["a", "b", "c", "d", "e", "f"] as Array[String])
	_run(40.0)
	for index in _crowd.count():
		var cell := Vector2i(_crowd.person(index)["at"].round())
		assert_true(_grid.is_walkable(cell), "%d 번이 건물 안에 들어갔다: %s" % [index, cell])


func test_nobody_leaves_the_board() -> void:
	_crowd.spawn_scattered(["a", "b", "c", "d", "e", "f"] as Array[String])
	_run(40.0)
	for index in _crowd.count():
		assert_true(_grid.in_bounds(Vector2i(_crowd.person(index)["at"].round())))


## 판이 건물로 가득 차면 목적지가 없다. 그때 얼어붙지 말고 그냥 서 있어야 한다.
func test_a_full_board_does_not_hang() -> void:
	var grid: HideoutGrid = GridScript.new(3, 3)
	var crowd: HideoutCrowd = CrowdScript.new(grid, 7)
	crowd.spawn("a", Vector2i(1, 1))
	var wall: HideoutBuilding = BuildingScript.new(
		"wall", HideoutBuilding.NOT_A_FACILITY, Vector2i(3, 3), Vector2i.ZERO
	)
	grid.place(wall)
	for _step in 600:
		crowd.tick(1.0 / 60.0)
	assert_eq(crowd.count(), 1, "멈추지 않고 돌아왔다")


# ------------------------------------------------------------------ 되풀이 · 집기


## 씨앗이 같으면 같은 판이 나온다. 캡처를 견주려면 이것이 필요하다.
func test_same_seed_gives_the_same_wander() -> void:
	var names: Array[String] = ["a", "b", "c"]
	_crowd.spawn_scattered(names)
	_run(6.0)
	var first := _positions()

	var twin: HideoutCrowd = CrowdScript.new(GridScript.new(14, 14), 1234)
	twin.spawn_scattered(names)
	var elapsed := 0.0
	while elapsed < 6.0:
		twin.tick(1.0 / 60.0)
		elapsed += 1.0 / 60.0
	for index in first.size():
		assert_eq(twin.person(index)["at"], first[index], "씨앗이 같은데 갈렸다")


## ⑤(클릭 -> 말풍선)가 쓸 문. 지금은 집히는지만 본다.
func test_person_at_finds_who_is_standing_there() -> void:
	_crowd.spawn("a", Vector2i(6, 6))
	_crowd.person(0)["wait"] = 999.0
	assert_eq(_crowd.person_at(Vector2i(6, 6)), 0)
	assert_eq(_crowd.person_at(Vector2i(0, 0)), -1, "아무도 없으면 -1")
