extends GutTest
## 방 종류 표시의 단위 테스트.
##
## 근거: docs/design/07-level-design.md §7.2.9 방 종류 여섯, §7.8 낮은 배율.
##
## 지키려는 것 둘.
##   **여섯 종류가 서로 다른 원자 조합을 갖는다** — 둘이 같으면 화면에서도 같다
##   **보스는 새 기호가 아니라 겹쳐 찍기다** — 위협 + 보상

## 배율 0.40 에서의 실측 크기. 여기서 구분돼야 답이 된 것이다.
const _CELL := Rect2(0.0, 0.0, 58.0, 30.0)

const _KINDS: Array[RoomMark.Kind] = [
	RoomMark.Kind.EMPTY,
	RoomMark.Kind.TREASURE,
	RoomMark.Kind.HAZARD,
	RoomMark.Kind.BOSS,
	RoomMark.Kind.ENTRANCE,
	RoomMark.Kind.EXIT,
]


func _signature(kind: RoomMark.Kind) -> String:
	return (
		"%s|%s|%d" % [RoomMark.has_wedge(kind), RoomMark.has_hatch(kind), RoomMark.notch_side(kind)]
	)


## 여섯 종류가 전부 다른 조합이어야 한다. 하나라도 겹치면 화면에서 구분되지 않는다.
func test_every_kind_has_a_distinct_signature() -> void:
	var seen: Dictionary = {}
	for kind in _KINDS:
		var key := _signature(kind)
		assert_false(
			seen.has(key), "%s 와 %s 가 같은 표시다" % [RoomMark.kind_name(kind), seen.get(key, "")]
		)
		seen[key] = RoomMark.kind_name(kind)
	assert_eq(seen.size(), 6)


## 빈방은 아무 표시도 없다. 판의 바탕 상태여야 나머지가 도드라진다.
func test_empty_room_is_unmarked() -> void:
	assert_false(RoomMark.has_wedge(RoomMark.Kind.EMPTY))
	assert_false(RoomMark.has_hatch(RoomMark.Kind.EMPTY))
	assert_eq(RoomMark.notch_side(RoomMark.Kind.EMPTY), 0)


## 보스는 위협과 보상을 **함께** 갖는다. 새 기호를 만들지 않는다.
func test_boss_is_threat_plus_reward() -> void:
	assert_true(RoomMark.has_wedge(RoomMark.Kind.BOSS), "보스에 보상 표시가 없다")
	assert_true(RoomMark.has_hatch(RoomMark.Kind.BOSS), "보스에 위협 표시가 없다")


## 귀중품은 보상만, 위험은 위협만. 하나씩이어야 보스의 겹쳐 찍기가 읽힌다.
func test_treasure_and_hazard_carry_one_atom_each() -> void:
	assert_true(RoomMark.has_wedge(RoomMark.Kind.TREASURE))
	assert_false(RoomMark.has_hatch(RoomMark.Kind.TREASURE))
	assert_true(RoomMark.has_hatch(RoomMark.Kind.HAZARD))
	assert_false(RoomMark.has_wedge(RoomMark.Kind.HAZARD))


## 입구와 탈출은 **반대쪽**이 파여야 한다. 같은 쪽이면 둘이 같아 보인다.
func test_entrance_and_exit_notch_opposite_sides() -> void:
	assert_eq(RoomMark.notch_side(RoomMark.Kind.ENTRANCE), -1)
	assert_eq(RoomMark.notch_side(RoomMark.Kind.EXIT), 1)


# ---------------------------------------------------------------- 기하


## 결손이 있는 방은 **꼭짓점이 더 많다.** 실루엣이 실제로 바뀌었다는 뜻이다.
func test_notched_plate_changes_the_silhouette() -> void:
	var plain := RoomMark.plate_polygon(_CELL, RoomMark.Kind.EMPTY)
	assert_eq(plain.size(), 4)
	for kind in [RoomMark.Kind.ENTRANCE, RoomMark.Kind.EXIT]:
		var notched := RoomMark.plate_polygon(_CELL, kind)
		assert_gt(notched.size(), plain.size(), "%s 의 윤곽이 안 바뀌었다" % RoomMark.kind_name(kind))


## 모든 판 다각형이 방 사각형 안에 있어야 한다. 삐져나오면 흠으로 보인다.
func test_plate_stays_inside_the_cell() -> void:
	var bounds := _CELL.grow(0.01)
	for kind in _KINDS:
		for point in RoomMark.plate_polygon(_CELL, kind):
			assert_true(bounds.has_point(point), "%s 의 윤곽이 밖으로 나갔다" % RoomMark.kind_name(kind))


## 쐐기는 오른쪽 위 모서리에 붙어 있어야 한다. 빗금 띠(아래)와 구역이 갈려야
## 보스방에서 둘이 함께 읽힌다.
func test_wedge_sits_in_the_top_right() -> void:
	var wedge := RoomMark.wedge_polygon(_CELL)
	assert_eq(wedge.size(), 3)
	for point in wedge:
		assert_gt(point.x, _CELL.size.x * 0.5, "쐐기가 왼쪽까지 내려왔다")
		assert_lt(point.y, _CELL.size.y * 0.6, "쐐기가 아래까지 내려왔다")


## 빗금은 아래 띠 안에만 있어야 한다. 숫자는 복판에 있으므로 자리가 겹치면 안 된다.
func test_hatch_stays_in_the_bottom_band() -> void:
	var segments := RoomMark.hatch_segments(_CELL)
	assert_gt(segments.size(), 3, "빗금이 너무 적어 무늬로 안 보인다")
	var band_top := _CELL.end.y - _CELL.size.y * RoomMark.HATCH_BAND_RATIO - 0.01
	for segment in segments:
		for point in segment:
			assert_gte(point.y, band_top, "빗금이 띠 위로 올라가 숫자를 가린다")
			assert_between(point.x, _CELL.position.x - 0.01, _CELL.end.x + 0.01, "빗금이 판 밖으로 나갔다")


## 빗금은 방 폭 전체에 걸쳐야 한다. 한구석에만 있으면 58x30 에서 안 보인다
## (처음에 실제로 그랬다).
func test_hatch_spans_the_whole_width() -> void:
	var leftmost := 999.0
	var rightmost := -999.0
	for segment in RoomMark.hatch_segments(_CELL):
		for point in segment:
			leftmost = minf(leftmost, point.x)
			rightmost = maxf(rightmost, point.x)
	assert_lt(leftmost, _CELL.size.x * 0.15, "빗금이 왼쪽 끝까지 안 간다")
	assert_gt(rightmost, _CELL.size.x * 0.85, "빗금이 오른쪽 끝까지 안 간다")


## 확대해도 빗금이 겹쳐 마름모가 되지 않아야 한다 — 띠가 비율이라야 한다.
func test_hatch_scales_without_collapsing() -> void:
	var big := Rect2(0.0, 0.0, 58.0 * 4.0, 30.0 * 4.0)
	var small_count := RoomMark.hatch_segments(_CELL).size()
	var big_count := RoomMark.hatch_segments(big).size()
	assert_almost_eq(float(big_count), float(small_count), 2.0, "확대하면 빗금 개수가 달라진다")


# ---------------------------------------------------------------- 토큰


## 못 가는 방은 **채우지 않는다.** 흐리게 칠하면 「덜 중요한 방」으로 읽히는데
## 못 가는 방의 위험도는 합에 그대로 들어간다 (07 §7.2.7).
func test_blocked_room_is_not_filled() -> void:
	var palette := RoomPalette.for_concept("slam")
	assert_eq(palette.fill_for(RoomPalette.State.BLOCKED).a, 0.0)
	assert_gt(palette.outline_for(RoomPalette.State.BLOCKED).a, 0.0, "채움도 선도 없으면 방이 사라진다")


## 갈 수 있는 방과 여기 있는 방은 채움이 달라야 한다.
func test_reachable_and_here_differ() -> void:
	var palette := RoomPalette.for_concept("slam")
	assert_ne(
		palette.fill_for(RoomPalette.State.REACHABLE), palette.fill_for(RoomPalette.State.HERE)
	)


## 보상과 위협은 **다른 색**이어야 한다. 같으면 보스방의 겹쳐 찍기가 안 보인다.
func test_reward_and_threat_never_share_a_colour() -> void:
	for name in ["slam", "shear", "hold", "squash", "afterimage"]:
		var palette := RoomPalette.for_concept(name)
		assert_ne(
			palette.reward_for(RoomPalette.State.REACHABLE),
			palette.threat_for(RoomPalette.State.REACHABLE),
			"%s 배색에서 보상과 위협이 같은 색이다" % name
		)


## 못 가는 방은 채움이 없으므로 선과 숫자가 **무대 위**에 놓인다.
## 다섯 배색 어디서도 무대에 묻혀 사라지면 안 된다 (밝은 판 컨셉에서 실제로 그랬다).
func test_blocked_room_stays_visible_on_the_stage() -> void:
	for name in ["slam", "shear", "hold", "squash", "afterimage"]:
		var palette := RoomPalette.for_concept(name)
		var stage := RoomPalette.STAGE.get_luminance()
		for token in [
			palette.outline_for(RoomPalette.State.BLOCKED),
			palette.number_for(RoomPalette.State.BLOCKED),
		]:
			var gap: float = absf(token.get_luminance() - stage)
			assert_gt(gap, 0.25, "%s 배색에서 못 가는 방이 무대에 묻힌다" % name)


## 다섯 컨셉 어디에 얹어도 숫자가 바탕과 구분돼야 한다.
func test_number_contrasts_with_the_plate_in_every_concept() -> void:
	for name in ["slam", "shear", "hold", "squash", "afterimage"]:
		var palette := RoomPalette.for_concept(name)
		for state in [RoomPalette.State.REACHABLE, RoomPalette.State.HERE]:
			var fill := palette.fill_for(state)
			var number := palette.number_for(state)
			var gap: float = absf(fill.get_luminance() - number.get_luminance())
			assert_gt(gap, 0.25, "%s 배색 %d 상태에서 숫자가 바탕에 묻힌다" % [name, state])
