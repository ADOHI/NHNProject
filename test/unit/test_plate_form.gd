extends GutTest
## `PlateForm` — 판의 형태.
##
## 여기서 잠그는 것은 치수가 아니라 **「형태가 사건에 변하는가」**다.
## 「겹인쇄」에서 어긋난 양이 커서와 눌림에 벌어지는 것이 값싸고 세다는 걸 알고 나서
## 그 방식을 형태 전부에 열었다. 그 전까지 형태는 정지해 있고 사건은 색과 표식만
## 건드렸다 — 눈으로는 「좀 밋밋한데」로 넘어갈 차이다.

const BOX := Vector2(200.0, 60.0)

const REST := Vector3.ZERO
const HOVER := Vector3(1.0, 0.0, 0.0)
const PRESSED := Vector3(1.0, 1.0, 1.0)


func _spread(points: PackedVector2Array) -> float:
	return PlateForm.bounds(points).size.length()


func test_every_kind_makes_a_usable_outline() -> void:
	for kind in PlateForm.Kind.values():
		var shape := PlateForm.outline(kind, BOX)
		assert_gte(shape.size(), 3, "형태 %d 가 다각형이 아니다" % kind)
		assert_gt(_spread(shape), 60.0, "형태 %d 가 너무 작아 누를 수 없다" % kind)


func test_every_kind_is_wide_enough_to_press() -> void:
	for kind in PlateForm.Kind.values():
		var box := PlateForm.hull(kind, BOX)
		assert_gte(box.size.y, 40.0, "형태 %d 의 높이가 손가락보다 작다" % kind)


## 옆구리에 물어낸 자리가 커서에서 벌어진다.
func test_hole_opens_when_the_cursor_arrives() -> void:
	var rest := PlateForm.animate(
		PlateForm.Kind.HOLE, PlateForm.outline(PlateForm.Kind.HOLE, BOX), 0.0, REST
	)
	var open_now := PlateForm.animate(
		PlateForm.Kind.HOLE, PlateForm.outline(PlateForm.Kind.HOLE, BOX), 0.0, HOVER
	)
	assert_gt(open_now[5].x - rest[5].x, 10.0, "구멍이 눈에 띄게 열려야 반응으로 읽힌다")


## 눌리면 더 찢어진다.
func test_rip_tears_deeper_when_pressed() -> void:
	var kind := PlateForm.Kind.RIP
	var base := PlateForm.outline(kind, BOX)
	var calm := PlateForm.animate(kind, base, 0.0, REST)
	var hit := PlateForm.animate(kind, base, 0.0, PRESSED)
	assert_gt(
		PlateForm.bounds(hit).size.y,
		PlateForm.bounds(calm).size.y + 3.0,
		"눌린 순간 톱니가 더 깊어져야 형태가 사건에 참여한다"
	)


## 조각은 커서에서 흩어지고 눌리면 모인다. **방향이 반대여야** 두 사건이 갈린다.
func test_split_scatters_on_hover_and_gathers_on_press() -> void:
	var kind := PlateForm.Kind.SPLIT
	var calm := PlateForm.extras(kind, BOX, REST)
	var blown := PlateForm.extras(kind, BOX, HOVER)
	var pulled := PlateForm.extras(kind, BOX, Vector3(0.0, 1.0, 0.0))
	assert_gt(_spread(blown[0]), _spread(calm[0]) * 0.999, "커서에서는 흩어진다")
	assert_lt(
		PlateForm.bounds(pulled[3]).get_center().distance_to(BOX * 0.5),
		PlateForm.bounds(calm[3]).get_center().distance_to(BOX * 0.5),
		"눌리면 조각이 판으로 모여야 한다"
	)


## 널은 **평상에서 실루엣이 그대로**여야 한다. 사건에서만 형태가 생긴다.
func test_shutter_hides_completely_at_rest() -> void:
	var kind := PlateForm.Kind.SHUTTER
	assert_eq(PlateForm.extras(kind, BOX, REST).size(), 0, "평상에는 널이 안 보인다")
	assert_gt(PlateForm.extras(kind, BOX, HOVER).size(), 0, "커서가 붙으면 널이 벌어진다")


func test_shutter_fans_wider_on_press_than_on_hover() -> void:
	var kind := PlateForm.Kind.SHUTTER
	var hover_box := PlateForm.bounds(PlateForm.extras(kind, BOX, HOVER)[0])
	var press_box := PlateForm.bounds(PlateForm.extras(kind, BOX, PRESSED)[0])
	assert_gt(press_box.position.distance_to(hover_box.position), 2.0, "눌림이 커서보다 세야 두 사건의 크기가 갈린다")


## 기운 판은 눌리면 더 눕는다.
func test_lean_angle_kicks_on_press() -> void:
	var calm := PlateForm.tilt_at(PlateForm.Kind.LEAN, REST)
	var hit := PlateForm.tilt_at(PlateForm.Kind.LEAN, PRESSED)
	assert_lt(hit, calm - 0.05, "눌리면 각이 더 눕는다")


func test_flat_forms_do_not_tilt() -> void:
	for kind in [PlateForm.Kind.SLAB, PlateForm.Kind.TALLY, PlateForm.Kind.SHUTTER]:
		assert_eq(PlateForm.tilt_at(kind, PRESSED), 0.0, "안 기운 형태는 사건에도 안 기운다")


## 겹인쇄만 두 번 찍는다. 나머지에 붙으면 전부 같은 인상이 된다.
func test_only_the_misprint_form_prints_twice() -> void:
	for kind in PlateForm.Kind.values():
		var slip: Vector3 = PlateForm.misprint(kind)
		if kind == PlateForm.Kind.GHOST:
			assert_ne(slip, Vector3.ZERO, "겹인쇄는 어긋나 찍힌다")
		else:
			assert_eq(slip, Vector3.ZERO, "형태 %d 는 한 번만 찍힌다" % kind)


## 끓는 윤곽은 **시각이 다르면 다른 모양**이어야 한다. 안 그러면 그냥 우툴두툴한 판이다.
func test_boil_changes_shape_over_time() -> void:
	var kind := PlateForm.Kind.BOIL
	var base := PlateForm.outline(kind, BOX)
	var early := PlateForm.animate(kind, base, 0.0, REST)
	var later := PlateForm.animate(kind, base, 0.35, REST)
	var moved := 0.0
	for i in mini(early.size(), later.size()):
		moved = maxf(moved, early[i].distance_to(later[i]))
	assert_gt(moved, 0.8, "시각이 흐르면 윤곽이 움직여야 끓는 것이다")


func test_boil_is_the_same_shape_for_the_same_clock() -> void:
	var kind := PlateForm.Kind.BOIL
	var base := PlateForm.outline(kind, BOX)
	var once := PlateForm.animate(kind, base, 0.7, REST)
	var twice := PlateForm.animate(kind, base, 0.7, REST)
	assert_eq(once, twice, "난수를 쓰면 캡처를 두 번 뽑아 비교할 수 없다")


func test_shrink_pulls_every_side_in_by_the_same_amount() -> void:
	var shape := PlateForm.outline(PlateForm.Kind.SLAB, BOX)
	var inner := PlateForm.shrink(shape, 4.0)
	var box := PlateForm.bounds(shape)
	var small := PlateForm.bounds(inner)
	assert_almost_eq(small.position.x - box.position.x, 4.0, 0.01)
	assert_almost_eq(box.end.y - small.end.y, 4.0, 0.01)


func test_hull_covers_the_scattered_pieces() -> void:
	var kind := PlateForm.Kind.SPLIT
	var box := PlateForm.hull(kind, BOX)
	# `has_point` 는 오른쪽·아래 변을 뺀다. 조각의 극점은 정확히 그 변 위에 앉으므로
	# 점이 아니라 **상자가 상자를 감싸는지**로 본다.
	for piece in PlateForm.extras(kind, BOX, REST):
		assert_true(box.encloses(PlateForm.bounds(piece)), "모서리 표가 조각을 다 감싸야 한다")


func test_only_two_forms_carry_a_shader() -> void:
	var shaded := 0
	for kind in PlateForm.Kind.values():
		if not PlateForm.shader_name(kind).is_empty():
			shaded += 1
	assert_eq(shaded, 2, "안 쓰는 셰이더를 전부에 달면 그리기 묶음이 형태마다 쪼개진다")
