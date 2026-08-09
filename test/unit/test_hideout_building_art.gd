extends GutTest
## 건물 그림 규격의 단위 테스트.
##
## **그림이 오기 전에 규격이 맞는지 확인하는 것이 이 파일의 전부다.**
## 그림이 도착한 날 안 맞는 것을 알게 되면 통째로 다시 뽑는다
## (docs/design/30-hideout.md §30.10).
##
## 가림(§30.10.3)은 눈으로 세면 틀린다. 여기서 **꼭짓점을 실제로 넣어 보고** 센다.

const ArtScript := preload("res://src/core/hideout/hideout_building_art.gd")
const IsoScript := preload("res://src/core/hideout/iso_projection.gd")
const BuildingScript := preload("res://src/core/hideout/hideout_building.gd")

# ------------------------------------------------------------------ 캔버스와 기준점


## 바닥 마름모는 발자국이 무엇이든 3:1 이다 — 타일 비가 정하기 때문이다.
func test_ground_is_always_three_to_one() -> void:
	for footprint in [Vector2i.ONE, Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 2)]:
		var ground := ArtScript.ground_size(footprint)
		assert_eq(ground.x, ground.y * 3, "%s 가 3:1 이 아니다" % footprint)


func test_the_two_by_two_ground_is_the_number_we_quoted() -> void:
	assert_eq(ArtScript.ground_size(Vector2i(2, 2)), Vector2i(192, 64))
	assert_eq(ArtScript.ground_size(Vector2i(2, 3)), Vector2i(240, 80))
	assert_eq(ArtScript.ground_size(Vector2i(3, 2)), Vector2i(240, 80))


## 캔버스는 바닥 + 솟는 높이 + 여백 양쪽이다.
func test_canvas_grows_by_one_cell_height_per_storey() -> void:
	var one := ArtScript.canvas_size(Vector2i(2, 2), 1)
	var two := ArtScript.canvas_size(Vector2i(2, 2), 2)
	assert_eq(two.y - one.y, int(IsoScript.CELL_HEIGHT_PX), "한 층은 칸 한 변 높이다")
	assert_eq(one.x, two.x, "층이 늘어도 가로는 그대로다")
	assert_eq(one, Vector2i(192 + 16, 64 + 64 + 16))


## 기준점은 바닥 마름모의 아래꼭짓점이고, **가운데가 아니다.**
func test_pivot_is_the_front_vertex_not_the_centre() -> void:
	var canvas := ArtScript.canvas_size(Vector2i(3, 2), 1)
	var anchor := ArtScript.pivot(Vector2i(3, 2), 1)
	assert_eq(anchor.y, canvas.y - ArtScript.MARGIN_PX, "세로로는 바닥에 붙는다")
	assert_ne(anchor.x, canvas.x / 2, "3x2 는 가운데가 아니다")
	assert_eq(anchor.x, ArtScript.MARGIN_PX + 48 * 3)


func test_square_footprints_do_land_on_the_centre() -> void:
	var canvas := ArtScript.canvas_size(Vector2i(2, 2), 1)
	assert_eq(ArtScript.pivot(Vector2i(2, 2), 1).x, canvas.x / 2, "정사각형만 가운데다")


## 그림이 위로 자라도 땅에 닿는 자리는 안 움직인다 — 파츠 레인이 겪은 그 문제다.
func test_taller_art_does_not_move_the_ground_contact() -> void:
	var one := ArtScript.ground_polygon(Vector2i(2, 2), 1)
	var two := ArtScript.ground_polygon(Vector2i(2, 2), 2)
	for index in one.size():
		var moved: Vector2 = two[index] - one[index]
		assert_eq(moved.y, 64.0, "캔버스가 커진 만큼만 내려간다 — 기준점 기준으로는 제자리")
		assert_eq(moved.x, 0.0)


func test_ground_polygon_sits_inside_the_canvas() -> void:
	var canvas := ArtScript.canvas_size(Vector2i(2, 3), 2)
	for point in ArtScript.ground_polygon(Vector2i(2, 3), 2):
		assert_between(point.x, 0.0, float(canvas.x))
		assert_between(point.y, 0.0, float(canvas.y))


# ------------------------------------------------------------------ 가림


## 건물이 쓸고 지나간 자리. 바닥 마름모를 위로 H 만큼 끌어올린 볼록 영역이다.
func _inside_silhouette(point: Vector2, centre: Vector2, half: Vector2, height: float) -> bool:
	var across := absf(point.x - centre.x) / half.x
	if across > 1.0:
		return false
	var reach := half.y * (1.0 - across)
	return (centre.y - reach - point.y) <= height and (centre.y + reach - point.y) >= 0.0


## **가림 개수를 꼭짓점으로 직접 세어 공식과 맞춘다.**
##
## 눈으로 세면 틀리고, 공식만 믿으면 공식이 틀렸을 때 아무도 모른다.
func test_hidden_count_matches_a_vertex_by_vertex_count() -> void:
	var iso: IsoProjection = IsoScript.new()
	var origin := Vector2i(7, 7)
	var footprint := Vector2i(2, 2)
	var base := iso.rect_polygon(origin, footprint)
	var centre := Vector2((base[1].x + base[3].x) * 0.5, (base[0].y + base[2].y) * 0.5)
	var half := Vector2((base[1].x - base[3].x) * 0.5, (base[2].y - base[0].y) * 0.5)

	for storeys in [1, 2]:
		var height := IsoScript.height_to_px(storeys * ArtScript.STOREY_CELLS)
		var counted := 0
		for step in range(1, 9):
			var cell := origin - Vector2i(step, step)
			var covered := true
			for point in iso.cell_polygon(cell):
				if not _inside_silhouette(point, centre, half, height):
					covered = false
					break
			if not covered:
				break
			counted += 1
		assert_eq(counted, ArtScript.hidden_cells_behind(storeys), "%d층" % storeys)


## N 층이 뒤 2N 칸을 가린다 — 이 한 줄이 높이 상한의 근거다.
func test_each_storey_costs_two_cells_of_sight() -> void:
	assert_eq(ArtScript.hidden_cells_behind(1), 2)
	assert_eq(ArtScript.hidden_cells_behind(2), 4)


func test_height_cap_is_enforced_where_it_is_used() -> void:
	var tall: HideoutBuilding = BuildingScript.new(
		"tall", Facility.Kind.WORKSHOP, Vector2i(2, 2), Vector2i.ZERO, 9
	)
	assert_eq(tall.storeys, ArtScript.MAX_STOREYS, "상한을 넘겨 지을 수 없다")
	assert_eq(tall.hidden_cells_behind(), 4)


func test_a_storey_is_exactly_one_cell_of_height() -> void:
	assert_eq(IsoScript.height_to_px(1.0), 64.0)
	var one: HideoutBuilding = BuildingScript.new(
		"one", Facility.Kind.WORKSHOP, Vector2i(2, 2), Vector2i.ZERO, 1
	)
	assert_eq(one.height_px(), 64.0)


# ------------------------------------------------------------------ 문


## 문은 한 방향뿐이다 — 카메라도 건물도 돌지 않는다.
##
## 보이는 벽은 둘(남서 · 남동)이고 문은 **남서쪽 벽**에 붙는다.
## 들어가는 칸이 그 벽에 붙어 있어야 그림과 규칙이 같은 곳을 가리킨다.
func test_the_entrance_touches_the_south_west_wall() -> void:
	for footprint in [Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 2)]:
		var building: HideoutBuilding = BuildingScript.new(
			"b", Facility.Kind.WORKSHOP, footprint, Vector2i(4, 4)
		)
		var door: Vector2i = building.entrance_cell()
		assert_eq(door.y, 4 + footprint.y, "남서쪽 벽 바로 바깥 줄이어야 한다")
		assert_between(door.x, 4, 4 + footprint.x - 1, "발자국의 가로 범위 안이어야 한다")
		assert_false(building.covers(door), "들어가는 칸은 건물 밖이다")
