extends GutTest
## 겹 배치표 검증.
##
## 그림이 아직 없어도 **배치는 검사할 수 있다.** 그림이 바뀌어도 이 규칙은 남는다
## (docs/design/21-title.md §21.13).

const SCREEN := Vector2(1280.0, 720.0)


func _plan() -> Array:
	return TitleLayers.plan()


func test_every_id_is_unique() -> void:
	var seen := {}
	for spec in _plan():
		assert_false(seen.has(spec.id), "겹 이름이 겹치면 안 된다: %s" % spec.id)
		seen[spec.id] = true


func test_drawing_order_runs_back_to_front() -> void:
	# 배열 순서가 곧 그리는 순서다. 깊이가 뒤섞이면 앞의 것이 뒤에 그려진다.
	var previous := -1.0
	for spec in _plan():
		assert_gte(spec.depth, previous, "깊이는 뒤에서 앞으로 늘기만 해야 한다: %s" % spec.id)
		previous = spec.depth


func test_backdrop_is_furthest_and_foreground_is_nearest() -> void:
	var specs := _plan()
	assert_eq(specs[0].id, "backdrop", "맨 뒤는 배경이다")
	assert_eq(specs[specs.size() - 1].id, "foreground", "맨 앞은 전경이다")


func test_demons_sit_behind_every_hunter() -> void:
	# 이름은 원경이지만 화면에서는 인간 뒤 • 배경 앞이다.
	# 악마가 인간을 내려다보려면 인간보다 뒤에 있어야 한다.
	var deepest_demon := 0.0
	var shallowest_hunter := 1.0
	for spec in _plan():
		if spec.role == TitleLayers.Role.DEMON:
			deepest_demon = maxf(deepest_demon, spec.depth)
		elif spec.role == TitleLayers.Role.HUNTER:
			shallowest_hunter = minf(shallowest_hunter, spec.depth)
	assert_lt(deepest_demon, shallowest_hunter, "악마는 전부 인간보다 뒤에 있어야 한다")


func test_demons_are_in_the_upper_half() -> void:
	for spec in _plan():
		if spec.role == TitleLayers.Role.DEMON:
			assert_lt(spec.anchor.y, 0.5, "악마는 내려다본다: %s" % spec.id)


func test_hoard_is_the_centre() -> void:
	var hoard := TitleLayers.find(_plan(), "hoard")
	assert_not_null(hoard, "금이 없으면 화면이 성립하지 않는다")
	assert_almost_eq(hoard.anchor.x, 0.5, 0.02, "금은 가로 한가운데다")


func test_there_are_four_hunters_from_four_directions() -> void:
	var hunters: Array = []
	for spec in _plan():
		if spec.role == TitleLayers.Role.HUNTER:
			hunters.append(spec)
	assert_eq(hunters.size(), 4, "사방에서 온다")
	# 전부 같은 자리에 몰리면 사방이 아니다. 가로로 흩어져 있어야 한다.
	var left := 0
	var right := 0
	for spec in hunters:
		if spec.anchor.x < 0.45:
			left += 1
		elif spec.anchor.x > 0.55:
			right += 1
	assert_gt(left, 0, "왼쪽에서 오는 사람이 있어야 한다")
	assert_gt(right, 0, "오른쪽에서 오는 사람이 있어야 한다")


func test_the_nearest_hunter_is_the_one_seen_from_behind() -> void:
	# 뒷모습이 가장 앞에 와야 "구경하는 그림" 이 아니라 "내가 그 자리에 있는 그림" 이 된다.
	var nearest: TitleLayers.Spec = null
	for spec in _plan():
		if spec.role == TitleLayers.Role.HUNTER:
			if nearest == null or spec.depth > nearest.depth:
				nearest = spec
	assert_eq(nearest.id, "hunter_back", "가장 가까운 사람은 뒷모습이다")


func test_every_hunter_watches_the_gold() -> void:
	# 시선의 사슬 — 사람은 금을 본다.
	for spec in _plan():
		if spec.role == TitleLayers.Role.HUNTER:
			assert_eq(spec.watching, "hoard", "%s 는 금을 봐야 한다" % spec.id)


func test_every_demon_watches_a_human_not_the_gold() -> void:
	# 시선의 사슬 — 악마는 금이 아니라 **사람**을 본다. 구경거리는 사람이다.
	var specs := _plan()
	for spec in specs:
		if spec.role != TitleLayers.Role.DEMON:
			continue
		assert_ne(spec.watching, "hoard", "%s 가 금을 보면 안 된다" % spec.id)
		var target := TitleLayers.find(specs, spec.watching)
		assert_not_null(target, "%s 가 보는 대상이 실제로 있어야 한다" % spec.id)
		assert_eq(target.role, TitleLayers.Role.HUNTER, "악마는 사람을 본다")


func test_full_bleed_layers_overscan_past_the_screen() -> void:
	# 시차로 흘러도 가장자리가 드러나면 안 된다.
	for id in ["backdrop", "foreground"]:
		var box := TitleLayers.rect_of(TitleLayers.find(_plan(), id), SCREEN, 1.0)
		assert_gt(box.size.x, SCREEN.x, "%s 는 화면보다 넓어야 한다" % id)
		assert_lt(box.position.x, 0.0, "%s 는 화면 왼쪽 밖에서 시작해야 한다" % id)


func test_sized_layers_do_not_stretch_with_the_screen() -> void:
	# 화면이 가로로 길어져도 인물이 늘어나면 안 된다. 짧은 변으로 잰다.
	var spec := TitleLayers.find(_plan(), "hunter_back")
	var wide := TitleLayers.rect_of(spec, Vector2(1920.0, 720.0), 1.0)
	var square := TitleLayers.rect_of(spec, Vector2(720.0, 720.0), 1.0)
	assert_almost_eq(wide.size.y, square.size.y, 0.5, "짧은 변이 같으면 크기도 같다")


func test_drift_grows_with_depth() -> void:
	var specs := _plan()
	var back := TitleLayers.drift_of(TitleLayers.find(specs, "backdrop"), Vector2(100.0, 0.0))
	var front := TitleLayers.drift_of(TitleLayers.find(specs, "foreground"), Vector2(100.0, 0.0))
	assert_lt(back.x, front.x, "앞의 것이 더 빨리 흐른다")


func test_backdrop_still_drifts_a_little() -> void:
	# 완전히 고정된 배경 앞에서 다른 겹만 움직이면 배경이 벽지로 보인다.
	var back := TitleLayers.drift_of(TitleLayers.find(_plan(), "backdrop"), Vector2(100.0, 0.0))
	assert_gt(back.x, 0.0, "배경도 조금은 따라와야 공간이 된다")
