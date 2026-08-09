extends GutTest
## `RadialDeck` — 원형 배치와 홀로그램 창.
##
## **여기서 잠그는 것은 선이 엉키지 않는가다.** 창이 넷 다섯이면 연결선이 교차하는
## 것이 정보 디자인의 고전 문제인데, 이 배치는 규칙 하나로 그것을 아예 없앤다 —
## **같은 쪽 창은 붙는 자리의 위아래 순서 그대로 쌓는다.**
##
## 그 규칙이 실제로 성립하는지는 **논증과 무관한 방법**으로 확인한다.
## `test/support/segment_crossing.gd` 로 화면에 그려질 선분끼리 직접 비교한다 —
## 던전 레인이 평면성을 확인하던 그 자다.

const Crossing := preload("res://test/support/segment_crossing.gd")

const SCREEN := Vector2(1280.0, 720.0)


func _figure() -> Rect2:
	return Rect2(SCREEN.x * 0.5 - 130.0, 150.0, 260.0, 400.0)


func _lines(unfold: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for slot in RadialDeck.count():
		out.append(RadialDeck.tether(slot as RadialDeck.Slot, _figure(), SCREEN, unfold))
	return out


## **접히고 펴지면 선이 움직인다.** 그러니 중간 상태에서도 돌아야 한다.
func test_tethers_never_cross_at_any_fold() -> void:
	for step in 21:
		var unfold := float(step) / 20.0
		var lines := _lines(unfold)
		for i in lines.size():
			for j in range(i + 1, lines.size()):
				assert_false(
					Crossing.crosses(lines[i][0], lines[i][1], lines[j][0], lines[j][1]),
					"펴짐 %.2f 에서 선 %d 과 %d 이 엉킨다" % [unfold, i, j]
				)


## 규칙의 근거를 직접 잠근다 — **같은 쪽 창은 앵커 순서 그대로 쌓인다.**
func test_windows_on_a_side_stack_in_anchor_order() -> void:
	for which in [-1, 1]:
		var mates := RadialDeck.on_side(which)
		var last_anchor := -1.0
		var last_top := -99999.0
		for slot in mates:
			assert_gt(RadialDeck.anchor(slot), last_anchor, "앵커가 오름차순이어야 한다")
			var box := RadialDeck.slot_rect(slot, _figure(), SCREEN, 1.0)
			assert_gt(box.position.y, last_top, "창도 같은 순서로 내려가야 한다")
			last_anchor = RadialDeck.anchor(slot)
			last_top = box.position.y


func test_both_sides_are_used() -> void:
	assert_gt(RadialDeck.on_side(1).size(), 0, "오른쪽이 비면 한쪽으로 쏠린다")
	assert_gt(RadialDeck.on_side(-1).size(), 0, "왼쪽도 써야 한다")


## 창은 **좌우로만** 선다. 전신 일러스트가 세로로 길어 위아래에는 자리가 없다.
func test_windows_stay_clear_of_the_figure() -> void:
	var figure := _figure()
	for slot in RadialDeck.count():
		var box := RadialDeck.slot_rect(slot as RadialDeck.Slot, figure, SCREEN, 1.0)
		assert_false(box.intersects(figure), "%s 창이 인물을 덮는다" % RadialDeck.label(slot))


## §20.10 — **접힘과 펴짐은 같은 축의 양끝이다.** 역재생이면 싸구려로 읽힌다.
func test_folding_and_unfolding_are_not_the_same_curve() -> void:
	var slot := RadialDeck.Slot.CHRONICLE
	var same := 0
	for step in 11:
		var u := float(step) / 10.0
		if is_equal_approx(
			RadialDeck.open_amount(slot, u, false),
			1.0 - RadialDeck.open_amount(slot, 1.0 - u, true)
		):
			same += 1
	assert_lt(same, 8, "펴짐이 접힘의 역재생이면 두 사건이 한 몸이 된다")


## 펴짐만 지나쳤다 되돌아온다. 접힘이 지나치면 창이 음수 높이가 된다.
func test_only_unfolding_overshoots() -> void:
	var peak := 0.0
	var dip := 1.0
	for step in 41:
		var u := float(step) / 40.0
		peak = maxf(peak, RadialDeck.open_amount(RadialDeck.Slot.IDENTITY, u, false))
		dip = minf(dip, RadialDeck.open_amount(RadialDeck.Slot.IDENTITY, u, true))
	assert_gt(peak, 1.0, "펴질 때는 지나쳤다 되돌아온다")
	assert_gte(dip, -0.001, "접힐 때는 0 아래로 안 간다")


## 접힘은 바깥부터, 펴짐은 안쪽부터. **순서가 같으면 방향만 뒤집힌 같은 사건이다.**
func test_folding_starts_outside_and_unfolding_starts_inside() -> void:
	var outer := RadialDeck.Slot.TIES
	var inner := RadialDeck.Slot.IDENTITY
	assert_lt(
		RadialDeck.open_amount(outer, 0.3, true),
		RadialDeck.open_amount(inner, 0.3, true),
		"접힐 때는 바깥 창이 먼저 닫힌다"
	)
	assert_gt(
		RadialDeck.open_amount(inner, 0.3, false),
		RadialDeck.open_amount(outer, 0.3, false),
		"펴질 때는 안쪽 창이 먼저 열린다"
	)


## 접힌 모양이 그 창의 종류를 말한다. **다 같은 막대면 접힌 뒤에 무엇인지 모른다.**
func test_folded_marks_differ_between_slots() -> void:
	var box := Rect2(0.0, 0.0, 200.0, RadialDeck.FOLDED_H)
	var shapes := {}
	for slot in RadialDeck.count():
		var marks := RadialDeck.folded_marks(slot as RadialDeck.Slot, box)
		assert_gt(marks.size(), 0, "접힌 창에 아무 표식도 없으면 사라진 것이다")
		var key := "%d:%d" % [marks.size(), int(marks[0].size.x)]
		shapes[key] = true
	assert_gt(shapes.size(), 2, "접힌 표식이 서로 구별돼야 한다")


## **배율이 곧 정보 층위다.** 층 경계가 뒤집히면 화면이 무엇을 하는 중인지 안 읽힌다.
func test_zoom_thresholds_climb_in_order() -> void:
	assert_eq(RadialDeck.layer_at(0.0), RadialDeck.Layer.SQUAD)
	assert_eq(RadialDeck.layer_at(1.0), RadialDeck.Layer.ONE)
	assert_eq(RadialDeck.layer_at(2.0), RadialDeck.Layer.WINDOW)
	assert_false(RadialDeck.shows_text(0.2), "멀리서는 글이 안 보인다")
	assert_true(RadialDeck.shows_text(1.0), "가까이서는 보인다")
	assert_true(RadialDeck.shows_threat(0.1), "멀리서는 위협 신호가 보인다")
	assert_false(RadialDeck.shows_threat(1.2), "가까이서는 위협 신호가 물러난다")


## 원형과 펼침 사이가 **연속**이어야 한다. 끊기면 「같은 공간」이 아니다.
func test_ring_unrolls_without_a_jump() -> void:
	var last := RadialDeck.stand(0, 6, 0.0, 0.0, SCREEN)
	for step in range(1, 26):
		var here := RadialDeck.stand(0, 6, 0.0, float(step) / 25.0 * RadialDeck.TO_ONE, SCREEN)
		assert_lt(last.distance_to(here), 60.0, "배율 한 칸에 자리가 튀면 안 된다")
		last = here


## **가운데가 곧 선택됨이다.** 고른 번호를 주면 그 인물이 정확히 가운데 앞에 서야 한다.
func test_the_picked_one_stands_dead_centre() -> void:
	for total in [3, 6, 8]:
		for who in total:
			var here := RadialDeck.spot(who, total, float(who), Vector2(640.0, 400.0), 300.0)
			assert_almost_eq(here.x, 640.0, 0.01, "%d 중 %d — 가로 한복판이 아니다" % [total, who])
			assert_gt(here.y, 400.0, "고른 인물은 화면 아래쪽, 즉 앞에 선다")
			assert_almost_eq(
				RadialDeck.nearness(who, total, float(who)), 1.0, 0.001, "고른 인물이 맨 앞이다"
			)


## **인원수는 시험값이다.** 셋이든 여덟이든 같은 식이 돌아야 한다.
func test_any_headcount_makes_a_ring() -> void:
	for total in [3, 4, 5, 6, 8, 11]:
		var seen := {}
		for i in total:
			var here := RadialDeck.spot(i, total, 0.0, Vector2(640.0, 400.0), 300.0)
			seen["%d:%d" % [int(here.x), int(here.y)]] = true
		assert_eq(seen.size(), total, "%d 명 — 두 사람이 같은 자리에 겹친다" % total)


## **한 바퀴가 이어진다.** 끝에서 처음으로 넘어가는 자리를 따로 만들지 않았다.
func test_the_ring_wraps_around() -> void:
	var start := RadialDeck.spot(0, 6, 0.0, Vector2(640.0, 400.0), 300.0)
	var round_trip := RadialDeck.spot(0, 6, 6.0, Vector2(640.0, 400.0), 300.0)
	assert_lt(start.distance_to(round_trip), 0.01, "여섯 칸을 돌면 제자리다")
	assert_eq(RadialDeck.front_index(6, 5.6), 0, "5 다음이 0 이다")
	assert_eq(RadialDeck.front_index(6, -0.4), 0, "거꾸로 돌아도 이어진다")


func test_the_front_figure_is_the_nearest_one() -> void:
	for step in 24:
		var picked := float(step) / 24.0 * 6.0
		var front := RadialDeck.front_index(6, picked)
		for i in 6:
			assert_lte(
				RadialDeck.nearness(i, 6, picked), RadialDeck.nearness(front, 6, picked) + 0.001
			)


## **가운데만 크다.** 옆 사람이 비슷하게 크면 누가 골렸는지 안 읽힌다.
func test_only_the_centre_is_big() -> void:
	var front := RadialDeck.figure_scale(2, 6, 2.0, 1.0)
	for i in 6:
		if i == 2:
			continue
		assert_lt(
			RadialDeck.figure_scale(i, 6, 2.0, 1.0) * 1.25, front, "%d 번이 가운데와 너무 비슷하게 크다" % i
		)


## **가운데가 바뀌는 순간이 접힘과 펴짐의 경계다.** 그래서 창이 옮겨 붙는 것을 볼 일이 없다.
func test_windows_are_folded_exactly_when_the_centre_changes() -> void:
	assert_almost_eq(RadialDeck.settled(2.0), 1.0, 0.001, "멈춰 있으면 다 펴진다")
	assert_almost_eq(RadialDeck.settled(2.5), 0.0, 0.001, "반 칸에서 완전히 접힌다")
	assert_lt(RadialDeck.settled(2.25), 0.6, "도는 중에는 접혀 있다")
	# 반 칸을 지나면 주인이 바뀐다 — 그때 창은 이미 접혀 있다.
	assert_eq(RadialDeck.front_index(6, 2.4), 2)
	assert_eq(RadialDeck.front_index(6, 2.6), 3)


func test_slot_names_are_printable() -> void:
	for slot in RadialDeck.count():
		var text := RadialDeck.label(slot as RadialDeck.Slot)
		assert_false(text.is_empty())
		assert_false(text.contains("·"), "SongMyung 에 없는 글자다")
		assert_false(text.contains("→"), "SongMyung 에 없는 글자다")
