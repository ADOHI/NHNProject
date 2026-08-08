extends GutTest
## 나전 키트 치수 체계의 단위 테스트.
##
## 규칙은 docs/design/20-ui-kit.md §20.3.2 · §20.3.3 이다.
## 노드가 하나도 나오지 않는다 — KitMetrics 는 순수 정적 클래스라 씬 없이 검증된다.

# ---------------------------------------------------------------- 규격


## 높이는 급마다 달라야 한다. 같으면 위계가 크기에 실리지 않는다.
func test_heights_rise_with_grade() -> void:
	var minor := KitMetrics.height_for(KitMetrics.Grade.MINOR)
	var main := KitMetrics.height_for(KitMetrics.Grade.MAIN)
	var grave := KitMetrics.height_for(KitMetrics.Grade.GRAVE)
	assert_lt(minor, main, "보조는 주 행동보다 낮아야 한다")
	assert_lt(main, grave, "주 행동은 결단보다 낮아야 한다")


## 모든 높이가 원자의 정수배여야 한다. 아니면 이음매가 자리를 못 잡는다.
func test_heights_are_multiples_of_unit() -> void:
	for grade in [KitMetrics.Grade.MINOR, KitMetrics.Grade.MAIN, KitMetrics.Grade.GRAVE]:
		var height := KitMetrics.height_for(grade)
		assert_almost_eq(fmod(height, KitMetrics.UNIT), 0.0, 0.001, "높이 %f 가 4px 배수가 아니다" % height)


## 글자 크기도 급을 따라 커져야 한다. 굵기 대비가 없으므로 크기가 위계의 절반이다.
func test_font_sizes_rise_with_grade() -> void:
	assert_lt(
		KitMetrics.font_size_for(KitMetrics.Grade.MINOR),
		KitMetrics.font_size_for(KitMetrics.Grade.MAIN)
	)
	assert_lt(
		KitMetrics.font_size_for(KitMetrics.Grade.MAIN),
		KitMetrics.font_size_for(KitMetrics.Grade.GRAVE)
	)


## 자간은 반대로 **작은 글자일수록 넓다.** 명조는 자간을 벌리면 격이 올라간다.
func test_tracking_falls_as_type_grows() -> void:
	assert_gt(
		KitMetrics.tracking_for(KitMetrics.Grade.MINOR),
		KitMetrics.tracking_for(KitMetrics.Grade.MAIN)
	)
	assert_gt(
		KitMetrics.tracking_for(KitMetrics.Grade.MAIN),
		KitMetrics.tracking_for(KitMetrics.Grade.GRAVE)
	)


# ---------------------------------------------------------------- 폭 맞춤


## 폭은 늘 원자의 정수배로 올림된다. 규격이 보이려면 셀 수 있어야 한다.
func test_fit_width_snaps_up_to_unit() -> void:
	for text_width in [0.0, 1.0, 13.5, 40.0, 77.3, 201.9]:
		var fitted := KitMetrics.fit_width(text_width, KitMetrics.Grade.MAIN)
		assert_almost_eq(fmod(fitted, KitMetrics.UNIT), 0.0, 0.001, "폭 %f 가 4px 배수가 아니다" % fitted)


## 올림이지 내림이 아니다. 글자가 잘리면 안 된다.
func test_fit_width_never_clips_the_text() -> void:
	var text_width := 100.0
	var fitted := KitMetrics.fit_width(text_width, KitMetrics.Grade.MAIN)
	var needed := text_width + KitMetrics.pad_x_for(KitMetrics.Grade.MAIN) * 2.0
	assert_gte(fitted, needed, "맞춘 폭이 글자와 여백의 합보다 좁다")


## 급이 높을수록 여백이 넓으므로 같은 글자라도 판이 커진다.
func test_higher_grade_gives_wider_plate() -> void:
	var minor := KitMetrics.fit_width(80.0, KitMetrics.Grade.MINOR)
	var grave := KitMetrics.fit_width(80.0, KitMetrics.Grade.GRAVE)
	assert_lt(minor, grave)


# ---------------------------------------------------------------- 간격


## 세 급은 반드시 갈라져 있어야 한다. 붙으면 "무엇이 이어지는가"가 무너진다.
func test_gaps_are_distinct_and_ordered() -> void:
	assert_lt(KitMetrics.GAP_ONE_BODY, KitMetrics.GAP_GROUP)
	assert_lt(KitMetrics.GAP_GROUP, KitMetrics.GAP_APART)


# ---------------------------------------------------------------- 상태 접근


## 붙는 것이 떨어지는 것보다 빨라야 한다. 반대면 굼떠 보인다.
func test_attack_is_faster_than_release() -> void:
	assert_lt(KitMetrics.HOVER_IN, KitMetrics.HOVER_OUT)
	assert_lt(KitMetrics.PRESS_IN, KitMetrics.PRESS_OUT)


## 접근은 목표를 지나치지 않는다. 지나치면 상태가 튕긴다.
func test_approach_never_overshoots() -> void:
	var value := 0.0
	for i in range(200):
		value = KitMetrics.approach(value, 1.0, 0.016, KitMetrics.HOVER_IN)
		assert_lte(value, 1.0, "접근이 목표를 넘어갔다")
	assert_almost_eq(value, 1.0, 0.001, "충분한 시간을 줬는데 도달하지 못했다")


## tau 초쯤이면 대부분 도달해 있어야 한다. 아니면 지정한 시간이 거짓말이 된다.
func test_approach_lands_within_tau() -> void:
	var value := 0.0
	var steps := int(KitMetrics.HOVER_IN / 0.016)
	for i in range(steps):
		value = KitMetrics.approach(value, 1.0, 0.016, KitMetrics.HOVER_IN)
	assert_gt(value, 0.9, "tau 만큼 돌았는데 90%%에도 못 미친다 (%f)" % value)


## 방향에 따라 다른 시간을 골라야 한다.
func test_approach_state_picks_direction() -> void:
	var rising := KitMetrics.approach_state(0.0, 1.0, 0.016, 0.05, 0.50)
	var falling := KitMetrics.approach_state(1.0, 0.0, 0.016, 0.05, 0.50)
	assert_gt(rising, 1.0 - falling, "붙는 쪽이 떨어지는 쪽보다 빨라야 한다")


## delta 가 0 이어도 터지지 않는다. 첫 프레임에서 실제로 들어온다.
func test_approach_survives_zero_delta() -> void:
	assert_eq(KitMetrics.approach(0.3, 1.0, 0.0, 0.1), 1.0)
	assert_eq(KitMetrics.approach(0.3, 1.0, 0.016, 0.0), 1.0)
