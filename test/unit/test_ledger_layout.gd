extends GutTest
## `LedgerLayout` — 이음매를 놓아도 되는 자리.
##
## 여기서 잠그는 것은 **「열이 둘이면 가로 이음매도 안전하지 않다」**다.
## §20.13.2 는 *"가로 이음매는 줄 사이에 숨는다"* 로 끝났는데 그건 한 열짜리
## 이야기고, 두 열이면 왼쪽 열의 빈틈이 오른쪽 열에서는 글줄 한복판일 수 있다.
##
## 그리고 **자를 자리가 없으면 안 자른다**도 여기서 잠근다. 형태를 지키려고
## 아무 데나 자르는 순간 낱말이 잘린다.


func _line(top: float, tall: float = 14.0, wide: float = 100.0) -> Rect2:
	return Rect2(0.0, top, wide, tall)


func test_gaps_are_the_holes_between_lines() -> void:
	var lines: Array[Rect2] = [_line(0.0), _line(40.0), _line(60.0)]
	var holes := LedgerLayout.gaps(lines, 0.0, 100.0)
	assert_eq(holes.size(), 2, "14~40 과 74~100 두 자리가 빈다")
	assert_almost_eq(holes[0].x, 14.0, 0.01, "첫 빈틈은 첫 줄 아래에서 시작한다")
	assert_almost_eq(holes[0].y, 40.0, 0.01, "다음 줄 위에서 끝난다")


func test_narrow_holes_are_not_gaps() -> void:
	var lines: Array[Rect2] = [_line(0.0), _line(18.0)]
	var holes := LedgerLayout.gaps(lines, 0.0, 32.0)
	assert_eq(holes.size(), 0, "MIN_GAP 보다 좁은 틈은 이음매가 못 선다")


func test_unsorted_lines_still_give_the_same_gaps() -> void:
	var jumbled: Array[Rect2] = [_line(60.0), _line(0.0), _line(40.0)]
	var tidy: Array[Rect2] = [_line(0.0), _line(40.0), _line(60.0)]
	assert_eq(
		LedgerLayout.gaps(jumbled, 0.0, 100.0).size(),
		LedgerLayout.gaps(tidy, 0.0, 100.0).size(),
		"두 열을 한 배열로 넘겨도 되게 여기서 정렬한다"
	)


## **이 저장소가 배운 것을 잠그는 항목.** 왼쪽 열이 비어 있어도 오른쪽 열에 글이
## 있으면 그 자리는 이음매가 아니다.
func test_a_seam_needs_both_columns_to_be_empty() -> void:
	var left: Array[Rect2] = [_line(0.0), _line(60.0)]
	var right: Array[Rect2] = [_line(0.0), _line(30.0), _line(60.0)]
	var both := LedgerLayout.common(
		LedgerLayout.gaps(left, 0.0, 100.0), LedgerLayout.gaps(right, 0.0, 100.0)
	)
	for band in both:
		var middle := (band.x + band.y) * 0.5
		assert_true(middle < 30.0 or middle > 44.0, "오른쪽 열의 30~44 줄 위에는 이음매가 서면 안 된다")


func test_no_common_hole_means_no_cut() -> void:
	var left: Array[Rect2] = [_line(0.0, 100.0)]
	var right: Array[Rect2] = [_line(20.0), _line(50.0)]
	var both := LedgerLayout.common(
		LedgerLayout.gaps(left, 0.0, 100.0), LedgerLayout.gaps(right, 0.0, 100.0)
	)
	assert_eq(both.size(), 0, "한 열이 통째로 차 있으면 겹치는 빈틈이 없다")
	assert_eq(LedgerLayout.cuts(both, 4).size(), 0, "자를 자리가 없으면 안 자른다")


func test_cuts_take_the_widest_holes_first() -> void:
	var holes: Array[Vector2] = [Vector2(0.0, 8.0), Vector2(20.0, 60.0), Vector2(70.0, 80.0)]
	var at := LedgerLayout.cuts(holes, 2)
	assert_eq(at.size(), 2, "최대 개수만큼만 자른다")
	assert_almost_eq(at[0], 40.0, 0.01, "가장 넓은 20~60 의 한복판")
	assert_almost_eq(at[1], 75.0, 0.01, "그다음 넓은 70~80 의 한복판")
	assert_lt(at[0], at[1], "고른 뒤에는 y 오름차순으로 낸다")


func test_crossings_counts_words_that_got_cut() -> void:
	var lines: Array[Rect2] = [_line(0.0), _line(40.0)]
	assert_eq(LedgerLayout.crossings(lines, PackedFloat32Array([30.0])), 0, "빈틈은 안 자른다")
	assert_eq(LedgerLayout.crossings(lines, PackedFloat32Array([46.0])), 1, "줄 한복판은 자른다")


func test_reach_is_measured_per_band() -> void:
	var lines: Array[Rect2] = [Rect2(0.0, 0.0, 40.0, 14.0), Rect2(0.0, 50.0, 180.0, 14.0)]
	var far := LedgerLayout.reaches(lines, PackedFloat32Array([0.0, 30.0, 100.0]))
	assert_eq(far.size(), 2, "층 경계 셋이면 층은 둘이다")
	assert_almost_eq(far[0], 40.0, 0.01, "첫 층은 짧은 줄만 들었다")
	assert_almost_eq(far[1], 180.0, 0.01, "둘째 층이 넓다 — 계단의 디딤이 여기서 나온다")
