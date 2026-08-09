extends GutTest
## `LedgerForm` — 글 많은 화면 전용 형태.
##
## 여기서 잠그는 것은 이 묶음 전체의 계약 한 줄이다.
##
## > **글이 앉는 자리 안에는 세로 이음매가 없다.**
##
## 눈으로는 못 잡는다. 앞 판에서 「벌어지는 널」이 글줄을 네 번 잘랐는데
## **재는 쪽이 세로 넘침만 봐서 「들어간다」로 보고했다**(§20.13.1).
## 그래서 여기서는 판을 실제로 격자로 훑어 **주인이 바뀌는 자리**를 찾는다.

const SIZE := Vector2(596.0, 428.0)


## 두 열의 빈틈이 겹친다고 치고 넣는 이음매. 실전에서는 `LedgerLayout` 이 낸다.
##
## `const` 로 못 둔다 — `PackedFloat32Array(...)` 는 상수식이 아니라서 파서가 막는다.
## **`--import` 는 0 에러를 찍고 GUT 만 잡았다.**
func _cuts() -> PackedFloat32Array:
	return PackedFloat32Array([120.0, 214.0, 318.0])


func _reach() -> PackedFloat32Array:
	return PackedFloat32Array([300.0, 420.0, 260.0, 380.0, 340.0])


func _bands(kind: LedgerForm.Kind, event := Vector3.ZERO) -> Array[PackedVector2Array]:
	return LedgerForm.bands(kind, SIZE, _cuts(), _reach(), event)


## 점을 덮은 조각 중 **가장 나중에 그려진 것**. 뒤에 그린 것이 위에 온다.
func _owner(pieces: Array[PackedVector2Array], at: Vector2) -> int:
	for i in range(pieces.size() - 1, -1, -1):
		if Geometry2D.is_point_in_polygon(at, pieces[i]):
			return i
	return -1


## **이 묶음의 존재 이유.** 글 상자를 가로로 훑으면서 조각 주인이 바뀌면 그 자리에
## 세로 이음매가 있는 것이고, 그러면 낱말이 잘린다.
##
## 조각에서 **바깥으로** 나가는 것은 이음매가 아니라 판의 끝이다 — 「층계」가
## 그 자리를 쓴다. 글이 거기까지 안 가는 것은 `reach` 가 보장한다.
func test_no_vertical_seam_crosses_the_text() -> void:
	for kind in LedgerForm.count():
		var form := kind as LedgerForm.Kind
		var pieces := _bands(form)
		var box := LedgerForm.text_box(form, SIZE)
		var switched := 0
		var y := box.position.y + 3.0
		while y < box.end.y:
			var last := -1
			var x := box.position.x + 1.0
			while x < box.end.x:
				var who := _owner(pieces, Vector2(x, y))
				if who >= 0 and last >= 0 and who != last:
					switched += 1
				last = who
				x += 7.0
			y += 9.0
		assert_eq(switched, 0, "%s — 글 상자 안에서 조각 주인이 바뀌면 안 된다" % LedgerForm.label(form))


## 이음매가 하나도 없으면 층도 하나다. **자를 자리가 없으면 안 자른다.**
func test_no_cut_means_one_band() -> void:
	var pieces := LedgerForm.bands(
		LedgerForm.Kind.STRATA, SIZE, PackedFloat32Array(), _reach(), Vector3.ZERO
	)
	assert_eq(pieces.size(), 1, "빈틈이 없으면 통판이다")


func test_bands_follow_the_cuts_the_content_gave() -> void:
	var pieces := _bands(LedgerForm.Kind.STRATA)
	assert_eq(pieces.size(), _cuts().size() + 1, "이음매 셋이면 층은 넷이다")


func test_too_many_cuts_are_dropped_before_stripes_appear() -> void:
	var many := PackedFloat32Array([40.0, 80.0, 120.0, 160.0, 200.0, 240.0, 280.0])
	var pieces := LedgerForm.bands(LedgerForm.Kind.STRATA, SIZE, many, _reach(), Vector3.ZERO)
	assert_lte(pieces.size(), LedgerForm.MAX_BANDS, "층이 더 늘면 띠가 아니라 줄무늬가 된다")


## §20.10 — 사건이 둘이면 **같은 축의 양끝**을 써야 한다. 손이 닿으면 벌어지고
## 눌리면 모인다. 둘 다 벌어지면 두 사건이 같은 모양이 되어 구분이 사라진다.
func test_hover_spreads_and_press_gathers() -> void:
	var rest := absf(LedgerForm.band_shift(LedgerForm.Kind.STRATA, 1, 4, SIZE, Vector3.ZERO))
	var hover := absf(
		LedgerForm.band_shift(LedgerForm.Kind.STRATA, 1, 4, SIZE, Vector3(1.0, 0.0, 0.0))
	)
	var press := absf(
		LedgerForm.band_shift(LedgerForm.Kind.STRATA, 1, 4, SIZE, Vector3(1.0, 1.0, 0.0))
	)
	assert_gt(hover, rest, "손이 닿으면 층이 더 벌어진다")
	assert_lt(press, rest, "눌리면 층이 모인다 — 반대 방향이라야 두 사건이 갈린다")


## 이웃한 층이 같은 방향으로 같은 만큼 밀리면 어긋난 티가 안 난다. 나전이 죽은
## 자리고(§20.2), 해시로 위상을 뽑아 또 밟을 뻔한 자리다(§20.6.10 ③).
func test_neighbouring_bands_never_shift_alike() -> void:
	for i in 4:
		var here := LedgerForm.band_shift(LedgerForm.Kind.STRATA, i, 5, SIZE, Vector3.ZERO)
		var next := LedgerForm.band_shift(LedgerForm.Kind.STRATA, i + 1, 5, SIZE, Vector3.ZERO)
		assert_gt(absf(here - next), 2.0, "층 %d 와 %d 가 거의 같은 자리에 있다" % [i, i + 1])


## 층이 아무리 밀려도 글은 판 위에 있어야 한다. 밀림의 최대치를 글 상자가 알고 있다.
func test_text_stays_on_the_plate_at_full_sway() -> void:
	var event := Vector3(1.0, 0.0, 0.0)
	var pieces := _bands(LedgerForm.Kind.STRATA, event)
	var box := LedgerForm.text_box(LedgerForm.Kind.STRATA, SIZE)
	for i in pieces.size():
		var edge := PlateForm.bounds(pieces[i])
		assert_lte(edge.position.x, box.position.x, "층 %d 이 글 왼쪽을 덮지 못한다" % i)
		assert_gte(edge.end.x, box.end.x, "층 %d 이 글 오른쪽을 덮지 못한다" % i)


## 파편은 **여백에서만** 논다. 하나라도 글 상자에 들어오면 밀도 대비가 아니라 방해다.
func test_shards_never_enter_the_text_box() -> void:
	var box := LedgerForm.text_box(LedgerForm.Kind.RIM, SIZE)
	for event in [Vector3.ZERO, Vector3(1.0, 0.0, 0.0), Vector3(1.0, 1.0, 0.0)]:
		for shard in LedgerForm.shards(LedgerForm.Kind.RIM, SIZE, event):
			assert_lte(PlateForm.bounds(shard).end.x, box.position.x, "파편이 글 자리로 넘어왔다")


## 두루마리만 창을 갖는다. **창이 있어야 안에서 글이 흘러도 어디가 잘릴지 안다.**
func test_only_the_scroll_has_a_window() -> void:
	for kind in LedgerForm.count():
		var form := kind as LedgerForm.Kind
		var has := LedgerForm.window(form, SIZE).size.length() > 1.0
		assert_eq(has, form == LedgerForm.Kind.SCROLL, "%s 의 창" % LedgerForm.label(form))


func test_every_form_has_a_name_without_missing_glyphs() -> void:
	for kind in LedgerForm.count():
		var text := LedgerForm.label(kind as LedgerForm.Kind)
		assert_false(text.is_empty(), "이름 없는 형태가 있으면 화면에 빈칸이 찍힌다")
		assert_false(text.contains("·"), "SongMyung 에 없는 글자다")
		assert_false(text.contains("→"), "SongMyung 에 없는 글자다")


## **재는 자가 놓친 축이 또 나왔다.** 「층진 띠」의 실루엣은 층마다 **왼쪽 변**이
## 다른데 처음 만든 자는 오른쪽 변만 봤다. 그래서 스크롤로 층이 통째로 밀려도
## 흔들림이 0 으로 나왔다 — §20.13.1 과 같은 병이 새 자에 그대로 있었다.
func test_the_ruler_sees_the_side_that_actually_moves() -> void:
	var form := LedgerForm.Kind.STRATA
	# 두 이음매 묶음에서 **층 번호가 서로 다른** 높이를 골라야 한다. 같은 층이면
	# 밀린 거리가 같아서 자가 멀쩡해도 값이 안 갈린다.
	var at_y := 240.0
	var one := LedgerForm.edge_at(form, SIZE, _cuts(), _reach(), Vector3.ZERO, at_y)
	var other := LedgerForm.edge_at(
		form, SIZE, PackedFloat32Array([90.0, 260.0, 350.0]), _reach(), Vector3.ZERO, at_y
	)
	assert_ne(one.x, other.x, "층 경계가 움직였으면 왼쪽 변도 움직여야 하고 자가 그것을 봐야 한다")
	assert_almost_eq(
		LedgerForm.right_at(form, SIZE, _cuts(), _reach(), Vector3.ZERO, at_y),
		LedgerForm.right_at(
			form, SIZE, PackedFloat32Array([90.0, 260.0, 350.0]), _reach(), Vector3.ZERO, at_y
		),
		0.01,
		"오른쪽만 재면 이 형태의 움직임은 통째로 안 보인다 — 이 단언이 그 사실이다"
	)


## **스크롤을 견디는 형태와 못 견디는 형태를 가르는 것은 하나뿐이다** —
## 실루엣이 `cuts` 를 먹는가. 먹으면 글이 흐를 때 판이 춤춘다.
func test_forms_that_eat_cuts_are_the_ones_that_dance() -> void:
	var moved := PackedFloat32Array([90.0, 260.0, 350.0])
	for kind in LedgerForm.count():
		var form := kind as LedgerForm.Kind
		var still := true
		for i in 12:
			var y := 60.0 + float(i) * 28.0
			var a := LedgerForm.edge_at(form, SIZE, _cuts(), _reach(), Vector3.ZERO, y)
			var b := LedgerForm.edge_at(form, SIZE, moved, _reach(), Vector3.ZERO, y)
			if a.distance_to(b) > 0.5:
				still = false
		var eats := form in [LedgerForm.Kind.STRATA, LedgerForm.Kind.TERRACE, LedgerForm.Kind.DOCK]
		assert_eq(still, not eats, "%s — 흔들림과 「cuts 를 먹는가」가 갈라지면 안 된다" % LedgerForm.label(form))
