extends GutTest
## 배치 층과 계약 층 검증 (docs/design/29-sound.md §29.2, §29.3).
##
## 여기서 지키는 것은 **층이 안 섞였는가**다. 사건이 늘어도 계약이 안 바뀌고,
## 원천이 바뀌어도 사건이 안 바뀌는 것이 이 설계의 전부다.


func test_every_event_has_a_request() -> void:
	# 표에 빠진 사건이 있으면 그 순간만 조용해진다. 조용한 건 버그로 안 보인다.
	for event in SfxEvent.all():
		var request := SfxCatalog.request_for(event)
		assert_not_null(request, "%s 에 요청이 없다" % SfxEvent.label(event))
		assert_between(request.weight, SfxRequest.MIN_WEIGHT, SfxRequest.MAX_WEIGHT)


func test_every_event_has_a_label() -> void:
	# 프로토 화면이 목록을 그릴 때 빈 칸이 나오면 안 된다.
	for event in SfxEvent.all():
		assert_ne(SfxEvent.label(event), "알 수 없음", "%d 번 사건에 이름이 없다" % event)


func test_every_event_lands_in_exactly_one_group() -> void:
	var counted := 0
	for group in SfxEvent.Group.values():
		counted += SfxEvent.of_group(group).size()
	assert_eq(counted, SfxEvent.all().size(), "묶음 합계가 전체 사건 수와 달라졌다")


func test_bake_key_separates_different_gains() -> void:
	# 실제로 났던 사고다. gain 이 열쇠에 없어서 "대기" 와 "재개" 가 같은 열쇠로 묶였고,
	# 한쪽이 다른 쪽 음량으로 재생됐다. SfxSynth 가 정규화할 때 gain 을 곱하므로
	# gain 이 다르면 다른 파형이다.
	var quiet := SfxRequest.tick(SfxMaterial.Kind.WOOD, 1.0).with_gain(0.30)
	var loud := SfxRequest.tick(SfxMaterial.Kind.WOOD, 1.0).with_gain(0.40)
	assert_ne(quiet.bake_key(), loud.bake_key(), "음량이 다르면 다른 열쇠여야 한다")


func test_bake_key_ignores_the_variation_seed() -> void:
	# 씨까지 열쇠에 넣으면 캐시가 무한히 늘어난다. 씨는 굽는 단위가 아니다.
	var first := SfxRequest.impact(SfxMaterial.Kind.METAL, 2.0, 1)
	var second := SfxRequest.impact(SfxMaterial.Kind.METAL, 2.0, 99)
	assert_eq(first.bake_key(), second.bake_key(), "씨는 열쇠에 들어가면 안 된다")


func test_weight_driven_events_follow_the_weapon_cells() -> void:
	# 무기 칸 수가 소리에 실제로 닿는지. 안 닿으면 §29.4 축이 무의미해진다.
	for event in SfxCatalog.WEIGHT_DRIVEN:
		assert_true(SfxCatalog.is_weight_driven(event), "%s 가 무게를 안 받는다" % SfxEvent.label(event))
		var light := SfxVoice.resolve(SfxCatalog.request_for(event).with_weight(1.0))
		var heavy := SfxVoice.resolve(SfxCatalog.request_for(event).with_weight(4.0))
		assert_gt(heavy.duration, light.duration, "%s 가 무게에 반응하지 않는다" % SfxEvent.label(event))


func test_ui_events_do_not_take_weapon_weight() -> void:
	# 팝업에 "칸 수" 같은 것은 없다. 무게가 새 나가면 UI 가 무기처럼 들린다.
	for event in [SfxEvent.Kind.UI_PRESS, SfxEvent.Kind.UI_VEIL_IN, SfxEvent.Kind.GATE_SELECTED]:
		assert_false(
			SfxCatalog.is_weight_driven(event), "%s 는 무기 무게를 받으면 안 된다" % SfxEvent.label(event)
		)


func test_the_three_break_thresholds_form_one_staircase() -> void:
	# 경직 -> 띄우기 -> 쓰러짐은 계단이다 (break_state.gd 의 Kind, 문턱 30/60/100).
	# 셋이 재질까지 다르면 계단이 아니라 서로 다른 세 사건으로 들린다.
	var stagger := SfxCatalog.request_for(SfxEvent.Kind.BREAK_STAGGER)
	var launch := SfxCatalog.request_for(SfxEvent.Kind.BREAK_LAUNCH)
	var knockdown := SfxCatalog.request_for(SfxEvent.Kind.BREAK_KNOCKDOWN)
	assert_eq(stagger.material, launch.material, "문턱 셋은 같은 재질이어야 한다")
	assert_eq(launch.material, knockdown.material)
	assert_lt(stagger.weight, launch.weight, "무너질수록 무거워야 한다")
	assert_lt(launch.weight, knockdown.weight)


func test_chain_success_rises_and_failure_falls() -> void:
	# 체인이 멈추는 이유는 일곱인데 (chain_result.gd 의 StopReason),
	# 정상 종료는 NO_OUTPUT 하나뿐이다. 소리는 그 하나만 올라가야 한다.
	var ended := SfxVoice.resolve(SfxCatalog.request_for(SfxEvent.Kind.CHAIN_ENDED))
	var broke := SfxVoice.resolve(SfxCatalog.request_for(SfxEvent.Kind.CHAIN_BROKE))
	assert_lt(ended.pitch_drop, 0.0, "정상 종료는 올라가야 한다")
	assert_gt(broke.pitch_drop, 0.0, "실패는 내려가야 한다")


func test_popup_opening_and_closing_are_mirrored() -> void:
	# 뒤 · 판 · 내용 순서가 열림과 닫힘에서 뒤집힌다 (20-ui-kit.md §20.11.2).
	# 소리도 같은 재질로 방향만 뒤집혀야 짝으로 들린다.
	var pairs := [
		[SfxEvent.Kind.UI_CONTENT_IN, SfxEvent.Kind.UI_CONTENT_OUT],
		[SfxEvent.Kind.UI_VEIL_IN, SfxEvent.Kind.UI_VEIL_OUT],
		[SfxEvent.Kind.UI_PIECE_IN, SfxEvent.Kind.UI_PIECE_OUT],
	]
	for pair in pairs:
		var opening := SfxCatalog.request_for(pair[0])
		var closing := SfxCatalog.request_for(pair[1])
		assert_eq(
			opening.material,
			closing.material,
			"%s 와 %s 는 같은 재질이어야 한다" % [SfxEvent.label(pair[0]), SfxEvent.label(pair[1])]
		)
		assert_eq(opening.kind, closing.kind, "열림과 닫힘은 같은 종류여야 한다")


func test_the_request_stays_a_value_object() -> void:
	# with_* 는 사본을 만든다. 표의 원본이 바뀌면 다음 재생부터 소리가 달라진다.
	var original := SfxCatalog.request_for(SfxEvent.Kind.HIT_LANDED)
	var weight_before := original.weight
	var changed := original.with_weight(4.0)
	assert_eq(original.weight, weight_before, "원본이 바뀌었다")
	assert_eq(changed.weight, 4.0)
	assert_ne(original, changed, "사본이어야 한다")
