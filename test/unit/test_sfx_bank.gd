extends GutTest
## 굽기와 캐시 검증 (docs/design/29-sound.md §29.5).
##
## 웹 단일 스레드에서 시작할 때 내는 값이 여기서 정해진다. 캐시가 새면
## 같은 소리를 몇 번씩 굽게 되고, 그건 그대로 로딩 지연이다.

var _bank: SfxBank


func before_each() -> void:
	_bank = SfxBank.new()


func test_the_same_request_is_baked_once() -> void:
	var request := SfxRequest.impact(SfxMaterial.Kind.METAL, 2.0)
	var first := _bank.streams_for(request)
	var second := _bank.streams_for(request)
	assert_eq(first[0], second[0], "같은 요청을 두 번 구웠다")
	assert_eq(_bank.baked_count(), 1)


func test_asking_for_more_variations_does_not_return_the_single_bake() -> void:
	# 실제로 났던 사고다. 벌 수가 열쇠에 없어서, 한 벌짜리로 먼저 캐시된 요청이
	# 나중에 네 벌을 달라고 해도 한 벌만 돌려줬다. 변주가 조용히 사라진다.
	var request := SfxRequest.impact(SfxMaterial.Kind.METAL, 2.0)
	_bank.streams_for(request, 1)
	var many := _bank.streams_for(request, SfxBank.VARIATION_COUNT)
	assert_eq(many.size(), SfxBank.VARIATION_COUNT, "네 벌을 달라고 했는데 덜 왔다")


func test_repeating_events_get_several_variations() -> void:
	# 체인은 0.35초 간격으로 5타가 나간다. 한 벌만 구우면 기계로 들린다 (§29.6).
	for event in SfxBank.REPEATING:
		var bank := SfxBank.new()
		bank.stream_for(event)
		assert_eq(
			bank.baked_count(),
			SfxBank.VARIATION_COUNT,
			"%s 는 반복 사건이라 여러 벌이어야 한다" % SfxEvent.label(event)
		)


func test_one_off_events_are_baked_once() -> void:
	# 게이트 입장은 한 번 나고 만다. 네 벌 구우면 낭비다.
	_bank.stream_for(SfxEvent.Kind.GATE_ENTERED)
	assert_eq(_bank.baked_count(), 1)


func test_variations_are_actually_different_streams() -> void:
	var streams := _bank.streams_for(
		SfxRequest.impact(SfxMaterial.Kind.METAL, 3.0), SfxBank.VARIATION_COUNT
	)
	for index in range(1, streams.size()):
		assert_ne(streams[index].data, streams[0].data, "%d 번째 벌이 첫 벌과 같다" % index)


func test_weight_reaches_the_baked_stream() -> void:
	# 무기 칸 수가 실제 파형까지 닿는지. 표만 바뀌고 소리가 그대로면 축이 끊긴 것이다.
	var light := _bank.stream_for(SfxEvent.Kind.HIT_LANDED, 1.0)
	var heavy := _bank.stream_for(SfxEvent.Kind.HIT_LANDED, 4.0)
	assert_gt(heavy.get_length(), light.get_length(), "4칸이 1칸보다 길어야 한다")


func test_weight_is_ignored_where_the_table_says_so() -> void:
	var first := _bank.stream_for(SfxEvent.Kind.UI_PRESS, 1.0)
	var second := _bank.stream_for(SfxEvent.Kind.UI_PRESS, 4.0)
	assert_eq(first.data, second.data, "UI 는 무기 무게를 받으면 안 된다")


func test_warming_every_event_stays_within_the_web_budget() -> void:
	# 웹은 단일 스레드다. 시작할 때 여기서 멈추면 그게 그대로 이탈 지점이다
	# (01-constraints.md §1.2). 실측 기준선을 회귀 테스트로 박아 둔다.
	var elapsed := _bank.warm()
	assert_lt(elapsed, 1000.0, "전체 굽기가 1초를 넘으면 로딩이 눈에 띈다")
	assert_gt(_bank.baked_count(), 0)
	gut.p(
		(
			"전체 굽기 %.1f ms / %d 벌 / %.1f KB"
			% [elapsed, _bank.baked_count(), _bank.baked_bytes() / 1024.0]
		)
	)


func test_warming_twice_costs_almost_nothing() -> void:
	_bank.warm()
	var baked := _bank.baked_count()
	_bank.warm()
	assert_eq(_bank.baked_count(), baked, "두 번째 warm 이 다시 구웠다")


func test_clearing_releases_everything() -> void:
	_bank.warm([SfxEvent.Kind.HIT_LANDED])
	_bank.clear()
	assert_eq(_bank.baked_count(), 0)
	assert_eq(_bank.baked_bytes(), 0)
