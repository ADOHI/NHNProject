extends GutTest
## `HoloSpark` — 사건에 붙는 것들.
##
## > **화려함은 사건의 성질이다.** 정지에서 화려하면 시끄럽다.
##
## 여기서 잠그는 것 둘.
##
## 1. **멈춰 있을 때 조용한가.** 이펙트가 정지 화면에 남으면 그건 사건이 아니라 장식이다
## 2. **「없음」이 진짜로 없는가.** 하나라도 새면 세기 넷의 비교가 통째로 뜻을 잃는다
##
## 그리고 자를 만들 때마다 묻는다 — **「이 값이 틀렸다고 치면 이 자가 그것을 잡나?」**
## (§20.15.4 · §20.16.5). 그래서 「없음」 검사는 이펙트 목록을 손으로 적지 않고
## **`Effect` 를 훑는다** — 새 이펙트를 넣으면 검사도 저절로 늘어난다.

const BOX := Rect2(100.0, 60.0, 300.0, 128.0)


## **표에 줄이 없는 이펙트가 있으면 안 된다.** 이 검사가 「없음」 관문의 뿌리다 —
## 목록이 새면 아래의 「없음」 검사가 그 이펙트를 건너뛴다.
func test_every_effect_has_a_row() -> void:
	assert_eq(HoloSpark.COUNTS.size(), HoloSpark.Effect.size(), "이펙트를 넣고 표에 줄을 안 더했다")
	for row in HoloSpark.COUNTS:
		assert_eq(row.size(), HoloSpark.levels(), "세기 넷이 다 있어야 비교가 된다")
	assert_eq(HoloSpark.STUFF_AT.size(), HoloSpark.levels())


## **「없음」은 진짜로 없다.** 하나라도 새면 나머지 셋이 무엇 때문에 시끄러운지 못 가른다.
func test_level_none_is_really_nothing() -> void:
	for what in HoloSpark.Effect.values():
		assert_eq(HoloSpark.many(what, HoloSpark.Level.NONE), 0, "이펙트 %d 이 「없음」에서 샌다" % what)
	assert_almost_eq(HoloSpark.stuff_strength(HoloSpark.Level.NONE), 0.0, 0.001, "셰이더도 안 건다")
	assert_false(HoloSpark.spreads(HoloSpark.Level.NONE))


## **셋은 실제로 갈려 있어야 한다.** 앞 단언이 늘 참이면 뜻이 없다(§20.16.5).
func test_the_other_three_actually_differ() -> void:
	for what in HoloSpark.Effect.values():
		assert_gt(HoloSpark.many(what, HoloSpark.Level.SOFT), 0, "「약」이 비면 세기가 셋이다")
		assert_true(
			(
				HoloSpark.many(what, HoloSpark.Level.TOO_MUCH)
				>= HoloSpark.many(what, HoloSpark.Level.STRONG)
			),
			"「과」가 「세」보다 적으면 순서가 뒤집힌 것이다"
		)
	assert_gt(HoloSpark.stuff_strength(HoloSpark.Level.TOO_MUCH), 1.0)


## **「과」가 시끄러운 원인은 양이 아니라 골고루다.** 그 성질은 「과」 하나뿐이다.
func test_only_too_much_spreads_everywhere() -> void:
	assert_false(HoloSpark.spreads(HoloSpark.Level.SOFT))
	assert_false(HoloSpark.spreads(HoloSpark.Level.STRONG), "「세」가 골고루면 밀도 대비가 죽는다")
	assert_true(HoloSpark.spreads(HoloSpark.Level.TOO_MUCH))
	# 개수만 키운 것이 아니라는 것 — 「세」와 「과」의 신호 점 수는 같다.
	assert_eq(
		HoloSpark.many(HoloSpark.Effect.SIGNAL, HoloSpark.Level.STRONG),
		HoloSpark.many(HoloSpark.Effect.SIGNAL, HoloSpark.Level.TOO_MUCH),
		"「과」의 신호는 점이 많아진 게 아니라 선이 많아진 것이다"
	)


## **한 번에 한 선.** 다섯 줄 다 흘리면 1 판의 「무슨 수학 같음」이 돌아온다.
func test_the_live_line_moves_one_at_a_time() -> void:
	var seen := {}
	var t := 0.0
	while t < HoloSpark.DWELL * 5.0:
		seen[HoloSpark.live_line(t, 5)] = true
		t += HoloSpark.DWELL * 0.25
	assert_eq(seen.size(), 5, "차례로 다섯 선을 다 훑어야 「스캔 중」으로 읽힌다")
	# 한 시각에는 답이 하나뿐이다 — 이 함수가 배열을 내면 「한 번에 하나」가 깨진다.
	assert_eq(HoloSpark.live_line(0.0, 5), HoloSpark.live_line(HoloSpark.DWELL * 0.5, 5))
	assert_ne(HoloSpark.live_line(0.0, 5), HoloSpark.live_line(HoloSpark.DWELL * 1.5, 5))
	assert_eq(HoloSpark.live_line(3.7, 0), 0, "선이 없으면 나눗셈이 터지면 안 된다")


## **다 붙고 나면 사라진다.** 남아 있으면 장식이 된다.
func test_shards_exist_only_while_the_window_opens() -> void:
	assert_almost_eq(HoloSpark.shard_alpha(0.0), 0.0, 0.001, "열리기 전에는 없다")
	assert_almost_eq(HoloSpark.shard_alpha(1.0), 0.0, 0.001, "다 열리면 사라진다")
	assert_gt(HoloSpark.shard_alpha(0.5), 0.5, "여는 동안에만 있다")


## **조각은 자기 창에서 나온다.** 아무 데서나 날아오면 상관없는 것이 붙는 것으로 보인다.
func test_shards_fly_in_from_outside_and_land_on_the_window() -> void:
	for i in HoloSpark.many(HoloSpark.Effect.SHARD, HoloSpark.Level.TOO_MUCH):
		var far := HoloSpark.shard(i, BOX, 0.0)
		var home := HoloSpark.shard(i, BOX, 1.0)
		assert_false(BOX.has_point(far.get_center()), "출발점은 창 밖이다")
		assert_true(BOX.grow(6.0).has_point(home.get_center()), "도착점은 창 위다")
		# 출발점이 도착점의 바깥 방향 연장이라야 「이 창의 조각」으로 읽힌다.
		var out_dir := (home.get_center() - BOX.get_center()).normalized()
		var fly_dir := (far.get_center() - home.get_center()).normalized()
		assert_gt(out_dir.dot(fly_dir), 0.5, "조각 %d 이 엉뚱한 데서 온다" % i)


## **신호는 몸에서 창 쪽으로만 간다.** 반대로 가면 뜻이 뒤집힌다.
func test_signals_run_one_way_and_fade_at_both_ends() -> void:
	var many := HoloSpark.many(HoloSpark.Effect.SIGNAL, HoloSpark.Level.STRONG)
	assert_gt(HoloSpark.signal_at(0, many, 0.3), HoloSpark.signal_at(0, many, 0.0), "신호가 뒤로 간다")
	assert_almost_eq(HoloSpark.signal_alpha(0.0), 0.0, 0.001, "선 끝에서 불쑥 나타나면 튄다")
	assert_almost_eq(HoloSpark.signal_alpha(1.0), 0.0, 0.001)
	assert_gt(HoloSpark.signal_alpha(0.5), 0.9, "가운데가 가장 진하다")
	# 점끼리 고르게 벌어져 있어야 한 줄로 흐르는 것으로 보인다.
	var seen := []
	for i in many:
		seen.append(HoloSpark.signal_at(i, many, 0.0))
	seen.sort()
	for i in range(1, seen.size()):
		assert_almost_eq(seen[i] - seen[i - 1], 1.0 / float(many), 0.001)


## **멈춰 있으면 자국이 없다.** 그리고 자국은 돌던 방향의 뒤쪽에만 남는다.
##
## **`picked` 를 정수로 넣고 재면 아무것도 안 잡힌다** — 그 순간에는 지나간 것도
## 다가오는 것도 없어서 앞뒤가 다 0 이고, 그러면 「뒤쪽에만」이 참인지 거짓인지
## 알 수 없는 값으로 통과한다(§20.20.8). 도는 **중간**에서 재야 한다.
func test_the_wake_only_exists_while_turning_and_only_behind() -> void:
	for i in 6:
		assert_almost_eq(HoloSpark.wake(i, 6, 2.3, 0.0), 0.0, 0.001, "멈추면 자국이 없다")
	# 자국은 아무리 진해도 0.55 다 — 잔상이 본체만큼 진하면 둘 중 어느 쪽이 본체인지 모른다.
	assert_gt(HoloSpark.wake(2, 6, 2.3, 1.0), 0.25, "가운데를 막 지나간 하나에 자국이 남는다")
	assert_almost_eq(HoloSpark.wake(3, 6, 2.3, 1.0), 0.0, 0.001, "앞쪽에 남으면 잔상이 아니라 후광이다")
	assert_almost_eq(HoloSpark.wake(1, 6, 2.3, 1.0), 0.0, 0.001, "한 칸을 넘게 지나갔으면 꺼진 것이다")
	# 여섯 중 자국이 붙는 것은 한 명뿐이다 — 밀도 대비가 여기서도 기능이다.
	var lit := 0
	for i in 6:
		if HoloSpark.wake(i, 6, 2.3, 1.0) > 0.001:
			lit += 1
	assert_eq(lit, 1, "골고루 남으면 「돌았다」가 아니라 「전부 흐리다」가 된다")
	# 겹이 깊을수록 더 옛날이라야 잔상이 꼬리로 읽힌다.
	assert_gt(HoloSpark.ghost_back(1), HoloSpark.ghost_back(0), "둘째 겹이 더 뒤에 있어야 한다")


## **파문은 한 번 지나가고 끝난다.**
func test_the_ripple_passes_once() -> void:
	assert_almost_eq(HoloSpark.ripple(0.0, 90.0), 0.0, 0.001)
	# 들이받는 도착이라 정확히 닿지는 않는다. 1% 안쪽이면 「다 퍼졌다」로 읽힌다.
	assert_almost_eq(HoloSpark.ripple(1.0, 90.0), 90.0, 1.0, "다 퍼지면 정해진 크기다")
	assert_gt(HoloSpark.ripple_alpha(0.0), 0.5, "누른 순간이 가장 진하다")
	assert_almost_eq(HoloSpark.ripple_alpha(1.0), 0.0, 0.001, "남으면 얼룩이다")
	var early := HoloSpark.ripple(0.3, 90.0)
	var late := HoloSpark.ripple(1.0, 90.0) - HoloSpark.ripple(0.7, 90.0)
	assert_gt(early, late, "퍼지다 잦아들어야 파문이다")


## 고리가 여럿이면 **뒤 고리가 늦게 나간다.** 같이 나가면 두꺼운 고리 하나로 보인다.
func test_extra_rings_leave_later() -> void:
	assert_lt(HoloSpark.ripple(0.4, 90.0, 1), HoloSpark.ripple(0.4, 90.0, 0), "둘째 고리가 뒤에 있다")
	assert_almost_eq(HoloSpark.ripple(0.1, 90.0, 2), 0.0, 0.001, "셋째 고리는 아직 안 나갔다")


## **섬광은 파문보다 훨씬 짧다.** 길면 화면이 밝아진 것으로 읽힌다.
func test_the_flare_is_much_shorter_than_the_ripple() -> void:
	assert_gt(HoloSpark.flare(0.0), 0.9, "누른 순간이 가장 밝다")
	assert_almost_eq(HoloSpark.flare(0.25), 0.0, 0.001, "파문이 절반도 안 갔을 때 섬광은 끝나 있다")
	assert_gt(HoloSpark.ripple_alpha(0.25), 0.3, "그때 파문은 아직 살아 있다")


## 티끌은 가운데 인물 둘레에서만 돈다. **모두에게 주면 밀도 대비가 죽는다.**
func test_motes_orbit_the_one_they_belong_to() -> void:
	var around := Rect2(500.0, 200.0, 220.0, 320.0)
	for i in 8:
		var at := HoloSpark.mote(i, 8, around, 1.7)
		assert_lt(at.distance_to(around.get_center()), around.size.y, "티끌 %d 이 너무 멀리 나간다" % i)
	# 시간이 가면 돈다. 안 움직이면 점이 박힌 것이다.
	assert_gt(HoloSpark.mote(0, 8, around, 0.0).distance_to(HoloSpark.mote(0, 8, around, 1.2)), 4.0)
	# 깜빡인다. 다 같은 밝기면 점을 뿌린 것이 된다.
	assert_ne(HoloSpark.mote_alpha(0, 0.0), HoloSpark.mote_alpha(0, 0.9))
	for i in 8:
		var lit := HoloSpark.mote_alpha(i, 2.3)
		assert_between(lit, 0.0, 1.0, "티끌 %d 의 진하기가 범위를 넘는다" % i)
