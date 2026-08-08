extends GutTest
## 균열 생성기 검증.
##
## 여기서 지키려는 것은 "그림이 예쁜가"가 아니라 **균열이 균열의 성질을 갖는가**다.
## 그 성질이 무너지면 화면은 금이 아니라 무늬가 된다
## (docs/design/21-title.md §21.4).

const BOUNDS := Rect2(Vector2.ZERO, Vector2.ONE)


func _field(seed_value: int = 7) -> CrackField:
	var field := CrackField.new(seed_value, BOUNDS)
	field.strike(Vector2(0.5, 0.5), 5)
	return field


func test_strike_grows_veins() -> void:
	assert_gt(_field().veins().size(), 0, "때렸으면 금이 가야 한다")


func test_same_seed_same_field() -> void:
	var first := _field(21)
	var second := _field(21)
	assert_eq(first.veins().size(), second.veins().size(), "같은 시드는 같은 균열망이다")
	assert_eq(first.veins()[0].points, second.veins()[0].points, "같은 시드는 같은 자리로 간다")


func test_different_seed_different_field() -> void:
	var first := _field(21)
	var second := _field(22)
	assert_ne(first.veins()[0].points, second.veins()[0].points, "시드가 다르면 그림도 다르다")


func test_tips_taper_to_nothing() -> void:
	# 균열의 끝이 뭉툭하면 그것은 금이 아니라 그어 놓은 선이다.
	for vein in _field().veins():
		assert_almost_eq(vein.widths[vein.widths.size() - 1], 0.0, 0.0001, "끝은 뾰족하다")


func test_width_never_grows_along_a_vein() -> void:
	# 에너지는 걸음마다 줄기만 하므로 굵기도 줄기만 해야 한다.
	for vein in _field().veins():
		for index in range(1, vein.widths.size()):
			assert_lte(vein.widths[index], vein.widths[index - 1] + 0.0001, "굵기는 늘지 않는다")


func test_arrivals_increase():  # gdlint:ignore = function-name
	for vein in _field().veins():
		for index in range(1, vein.arrivals.size()):
			assert_gt(vein.arrivals[index], vein.arrivals[index - 1], "전파 거리는 늘기만 한다")


func test_branches_are_shorter_than_their_parents() -> void:
	# 갈라지는 데 힘이 들기 때문에 가지는 부모보다 짧다. 이게 무너지면
	# 화면이 나뭇가지가 아니라 격자가 된다.
	var field := _field(5)
	var longest_by_generation := {}
	for vein in field.veins():
		var previous: float = longest_by_generation.get(vein.generation, 0.0)
		longest_by_generation[vein.generation] = maxf(previous, vein.length())
	var generations := longest_by_generation.keys()
	generations.sort()
	for index in range(1, generations.size()):
		assert_lte(
			longest_by_generation[generations[index]],
			longest_by_generation[generations[index - 1]],
			"뒷 세대가 앞 세대보다 길 수 없다"
		)


func test_stays_inside_bounds() -> void:
	for vein in _field().veins():
		for point in vein.points:
			assert_true(BOUNDS.grow(0.02).has_point(point), "균열이 판 밖으로 나가면 안 된다: %s" % point)


func test_junctions_sit_on_the_field() -> void:
	var field := _field()
	var spots := field.junctions()
	assert_gt(spots.size(), 2, "갈래점이 몇 개는 나와야 지도가 된다")
	for spot in spots:
		assert_true(BOUNDS.grow(0.02).has_point(spot), "갈래점도 판 안에 있어야 한다")


func test_junctions_do_not_pile_up() -> void:
	# 방이 겹쳐 앉으면 지도가 아니라 얼룩이다.
	var spots := _field().junctions(0.05)
	for outer in spots.size():
		for inner in range(outer + 1, spots.size()):
			assert_gte(spots[outer].distance_to(spots[inner]), 0.05, "갈래점끼리 겹치면 안 된다")


func test_advanced_grows_from_the_start() -> void:
	var vein := _field().veins()[0]
	var early := CrackField.advanced(vein, vein.length() * 0.25)
	var late := CrackField.advanced(vein, vein.length())
	assert_lt(early.size(), late.size(), "덜 번진 금이 더 짧아야 한다")
	assert_eq(early[0], late[0], "자라나는 방향은 시작점에서 끝으로다")


func test_advanced_at_zero_is_nothing() -> void:
	var vein := _field().veins()[0]
	assert_lt(CrackField.advanced(vein, 0.0).size(), 2, "아직 안 갔으면 그릴 것이 없다")


func test_ribbon_is_a_closed_band() -> void:
	var vein := _field().veins()[0]
	var band := CrackField.ribbon(vein, vein.length())
	var line := CrackField.advanced(vein, vein.length())
	assert_eq(band.size(), line.size() * 2, "띠는 양쪽 가장자리 두 벌이다")


func test_clear_empties_the_field() -> void:
	var field := _field()
	field.clear()
	assert_true(field.is_empty(), "지우면 비어야 한다")


func test_run_from_makes_a_single_trunk() -> void:
	var field := CrackField.new(3, BOUNDS)
	field.run_from(Vector2(0.02, 0.5), Vector2.RIGHT)
	var trunks := 0
	for vein in field.veins():
		if vein.generation == 0:
			trunks += 1
	assert_eq(trunks, 1, "한 방향으로 달리면 줄기는 하나다")


func test_span_covers_every_vein() -> void:
	var field := _field()
	for vein in field.veins():
		assert_lte(vein.length(), field.span() + 0.0001, "span 은 가장 늦게 도착한 값이다")
