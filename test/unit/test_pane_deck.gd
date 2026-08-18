extends GutTest
## `PaneDeck` — 떠 있는 창 여럿, 그리고 **좁은 창에서 두 열이 되는가.**
##
## 마지막 항목이 정보 설계에 직접 걸린다. 창이 여럿이면 창 하나가 좁아지고,
## 좁은 창에서 두 열을 시키면 **열이 아니라 줄이 두 배가 된다.**


func _sheet() -> Array[SheetSection]:
	var registry := PersonGenerator.new(20260809, 60).generate()
	return PersonSheet.build(registry, 0, FactionIndex.new(registry))


func test_every_pane_stays_on_the_screen() -> void:
	var screen := Rect2(Vector2.ZERO, PaneDeck.SCREEN)
	for kind in PaneDeck.count():
		for pane in PaneDeck.panes(kind as PaneDeck.Kind):
			assert_true(screen.encloses(pane), "%s — 창이 화면 밖으로 나갔다" % PaneDeck.label(kind))


## 배치 갈래가 서로 달라야 넷을 만든 뜻이 있다. **겹치는 것과 안 겹치는 것이 둘 다 있어야 한다.**
func test_tiles_never_overlap_and_cascades_always_do() -> void:
	var tiles := PaneDeck.panes(PaneDeck.Kind.TILE)
	for i in tiles.size():
		for j in range(i + 1, tiles.size()):
			assert_false(tiles[i].intersects(tiles[j]), "갈라 붙인 창은 겹치지 않는다")
	var stack := PaneDeck.panes(PaneDeck.Kind.CASCADE)
	for i in range(1, stack.size()):
		assert_true(stack[i].intersects(stack[i - 1]), "층진 창은 겹친다")


func test_body_sits_under_the_title_bar_and_inside_the_pane() -> void:
	for kind in PaneDeck.count():
		for pane in PaneDeck.panes(kind as PaneDeck.Kind):
			var box := PaneDeck.body(pane)
			assert_true(pane.encloses(box), "글이 창 밖으로 나간다")
			assert_gte(box.position.y, PaneDeck.title_bar(pane).end.y, "글이 제목 띠를 밟는다")


## §20.12 — **모따기는 손이 닿는 크기라 절대값이다.** 창이 커진다고 더 깎이면 안 된다.
func test_chamfer_does_not_grow_with_the_pane() -> void:
	var small := PaneDeck.outline(Rect2(0.0, 0.0, 300.0, 200.0))
	var large := PaneDeck.outline(Rect2(0.0, 0.0, 900.0, 700.0))
	assert_almost_eq(small[0].x, large[0].x, 0.01, "왼쪽 위 모따기가 크기를 따라갔다")
	assert_almost_eq(small[0].x, PaneDeck.CHAMFER, 0.01, "모따기는 상수 그대로다")


## §20.10 — 앞으로 나오는 것과 뒤로 가는 것은 **같은 축의 양끝**이라야 한다.
func test_rising_overshoots_and_sinking_does_not() -> void:
	var peak := 0.0
	for i in 20:
		peak = maxf(peak, PaneDeck.rise(float(i) / 19.0))
	assert_gt(peak, 1.0, "앞으로 오는 창은 지나쳤다 되돌아온다")
	for i in 20:
		assert_lte(PaneDeck.sink(float(i) / 19.0), 1.0, "뒤로 가는 창은 지나치지 않는다")


func test_every_pane_carries_something_and_the_names_are_printable() -> void:
	for kind in PaneDeck.count():
		var here := kind as PaneDeck.Kind
		assert_eq(
			PaneDeck.cargo(here).size(),
			PaneDeck.panes(here).size(),
			"%s — 창 수와 실은 것 수가 어긋나면 배정이 조용히 밀린다" % PaneDeck.label(here)
		)
		for i in PaneDeck.panes(here).size():
			var name_here := PaneDeck.title_of(here, i)
			assert_false(name_here.is_empty(), "이름 없는 창")
			assert_false(name_here.contains("·"), "SongMyung 에 없는 글자다")
			assert_false(name_here.contains("→"), "SongMyung 에 없는 글자다")


func test_covers_only_when_it_really_hides_it() -> void:
	var big := Rect2(0.0, 0.0, 400.0, 300.0)
	assert_true(PaneDeck.covers(big, Rect2(20.0, 20.0, 100.0, 100.0)), "안에 든 창은 가려진다")
	assert_false(PaneDeck.covers(big, Rect2(380.0, 20.0, 100.0, 100.0)), "삐져나온 창은 안 가려진다")


## **이 항목이 정보 설계를 바꾼다.** 「끝에 물린 창」의 도킹 창이 256px 이다.
func test_a_narrow_window_is_not_two_columns() -> void:
	var ink := SheetPainter.new()
	ink.sections = _sheet()
	var rail := PaneDeck.body(PaneDeck.panes(PaneDeck.Kind.RAIL)[0])
	assert_false(ink.fits(rail, 2), "256px 창에서 두 열은 열이 아니라 줄이 두 배가 되는 것이다")
	assert_true(ink.fits(rail, 1), "한 열은 된다")


## **재는 자가 무슨 폭이든 통과시키던 자리다.** `paged` 를 켠 채로 재면 넘친 줄이
## 애초에 안 그려져 `bottom` 이 상자를 못 넘는다 — 256px 창이 두 열로 통과했다.
func test_the_column_ruler_ignores_paging() -> void:
	var ink := SheetPainter.new()
	ink.sections = _sheet()
	var rail := PaneDeck.body(PaneDeck.panes(PaneDeck.Kind.RAIL)[0])
	ink.paged = true
	assert_false(ink.fits(rail, 2), "줄을 잘라 내는 설정이 자를 무디게 하면 안 된다")
	assert_true(ink.paged, "재고 나서 설정을 원래대로 돌려놓는다")


func test_a_wide_window_does_take_two_columns() -> void:
	var ink := SheetPainter.new()
	ink.sections = _sheet()
	var main := PaneDeck.body(PaneDeck.panes(PaneDeck.Kind.RAIL)[1])
	assert_true(ink.fits(main, 2), "700px 창은 두 열이 된다 — 아니면 위 단언이 늘 참이라 뜻이 없다")
