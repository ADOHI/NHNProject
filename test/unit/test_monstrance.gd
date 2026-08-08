extends GutTest
## 방사 기하의 단위 테스트.
##
## 지키려는 것은 셋이다 — **광선마다 위상이 달라야 하고**(나전이 여기서 죽었다),
## **바깥 경계가 원호여서는 안 되고**(회전 원형 HUD 가 된다),
## **눌림은 목표를 지나쳐야 한다**(그래야 손맛이 있다).
## docs/design/20-ui-kit.md §20.6.6.

const COUNT := 24


func _make() -> Monstrance:
	return Monstrance.new(Vector2(980.0, 600.0), COUNT, -3.02, -0.62, 46.0, 1080.0, 54.0, 62.0)


func test_rays_fill_the_fan_in_order() -> void:
	var m := _make()
	var previous := m.ray_angle(0)
	for i in range(1, COUNT):
		var here := m.ray_angle(i)
		assert_gt(here, previous, "광선 각이 단조롭게 늘지 않는다 - 부채가 꼬인다")
		previous = here
	# 슬롯 가운데에 앉으므로 양끝이 부채 경계 안쪽에 있다.
	assert_gt(m.ray_angle(0), m.angle_from, "첫 광선이 부채 경계 밖에 있다")
	assert_lt(m.ray_angle(COUNT - 1), m.angle_to, "끝 광선이 부채 경계 밖에 있다")


func test_reach_is_not_a_clean_arc() -> void:
	var m := _make()
	# 벌 안에서 봐야 한다. 두 벌을 섞어 재면 벌 차이가 흔들림으로 잘못 읽힌다.
	for parity in [0, 1]:
		var lowest := INF
		var highest := 0.0
		for i in range(parity, COUNT, 2):
			var reach := m.ray_outer(i)
			lowest = minf(lowest, reach)
			highest = maxf(highest, reach)
		# 다 같으면 바깥 경계가 원호가 되고 그건 회전 원형 HUD 의 실루엣이다.
		assert_gt(highest - lowest, highest * 0.05, "한 벌 안의 리치가 거의 같다 - 경계가 원호가 된다")
	assert_lt(m.ray_outer(0), m.outer * 1.001, "긴 벌이 최대치를 넘었다")


func test_two_ranks_are_clearly_different() -> void:
	var m := _make()
	# 짧은 벌이 긴 벌의 절반보다 짧아야 두 벌로 읽힌다.
	assert_lt(m.ray_outer(1), m.ray_outer(0) * 0.55, "두 벌이 구별되지 않는다 - 겹이 안 생긴다")
	assert_true(m.is_long(0), "짝수 자리가 긴 벌이어야 한다")
	assert_false(m.is_long(1), "홀수 자리가 짧은 벌이어야 한다")


func test_ray_width_does_not_follow_reach() -> void:
	var m := _make()
	# 폭을 리치에 비례시키면 짧은 벌이 실처럼 얇아지고 긴 벌은 텍스처가 늘어난다.
	assert_gt(m.ray_half(1), m.ray_half(0) * 0.9, "짧은 벌이 긴 벌보다 훨씬 얇다 - 폭이 리치를 따라갔다")


func test_sheen_phase_differs_between_rays() -> void:
	var m := _make()
	var seen: Array[float] = []
	for i in range(COUNT):
		seen.append(m.sheen_at(i, 0.0))
	# 나전 판의 결함: 시간 uniform 에 상수를 곱해서 조각 전부가 같이 움직였다.
	var span := 0.0
	for a in seen:
		for b in seen:
			span = maxf(span, absf(a - b))
	assert_gt(span, 0.55, "광선들의 광택 위상이 거의 같다 - 한 몸으로 맥동한다")


func test_neighbouring_rays_are_not_in_phase() -> void:
	var m := _make()
	# 폭이 넓어도 **이웃끼리 같은 위상**이면 부채가 뭉텅이로 맥동한다.
	# 이 컨셉에서 움직임으로 읽히는 것은 이웃 사이의 어긋남이다.
	for i in range(COUNT - 1):
		var gap := absf(m.sheen_at(i, 0.0) - m.sheen_at(i + 1, 0.0))
		gap = minf(gap, 1.0 - gap)
		assert_gt(gap, 0.15, "광선 %d 와 %d 가 같은 위상이다" % [i, i + 1])


func test_sheen_travels_and_wraps() -> void:
	var m := _make()
	var start := m.sheen_at(3, 0.0)
	var later := m.sheen_at(3, Monstrance.SHEEN_PERIOD * 0.25)
	assert_ne(start, later, "광택이 제자리에 서 있다")
	assert_almost_eq(m.sheen_at(3, Monstrance.SHEEN_PERIOD), start, 0.0001)


func test_gild_runs_outward_in_order() -> void:
	var m := _make()
	# 개시 도중을 잡으면 안쪽 광선이 바깥 광선보다 더 차 있어야 한다.
	var mid := Monstrance.GILD_STAGGER * float(COUNT) * 0.5
	assert_gt(m.gild_progress(0, mid), m.gild_progress(COUNT - 1, mid), "금이 순서대로 찍히지 않는다")
	assert_eq(m.gild_progress(COUNT - 1, 0.0), 0.0, "개시 전에 이미 금이 있다")
	var done := Monstrance.GILD_STAGGER * float(COUNT) + Monstrance.GILD_RAY * 2.0
	for i in range(COUNT):
		assert_gt(m.gild_progress(i, done), 0.99, "개시가 끝났는데 안 찬 광선이 있다")


func test_press_sucks_in_then_overshoots() -> void:
	var m := _make()
	assert_almost_eq(m.press_reach(-1.0), 1.0, 0.0001)
	assert_almost_eq(m.press_reach(Monstrance.PRESS_TIME), 1.0, 0.0001)
	var lowest := 1.0
	var highest := 0.0
	for i in range(60):
		var v := m.press_reach(float(i) / 60.0 * Monstrance.PRESS_TIME)
		lowest = minf(lowest, v)
		highest = maxf(highest, v)
	assert_lt(lowest, 0.85, "눌림에 역류가 없다 - 방사가 안 빨려 든다")
	assert_gt(highest, 1.005, "되튐이 없다 - 목표를 지나치지 않으면 손맛이 안 난다")


func test_ray_rect_spans_inner_to_reach() -> void:
	var m := _make()
	var rect := m.ray_rect(0, 1.0)
	assert_almost_eq(rect.end.y, -m.inner, 0.001, "광선 뿌리가 안쪽 반지름에 없다")
	assert_almost_eq(rect.size.x, m.half_long * 2.0, 0.001, "긴 벌의 폭이 안 맞는다")
	assert_almost_eq(rect.position.y, -m.ray_outer(0), 0.001, "광선 끝이 리치에 없다")
	assert_gt(rect.size.x, 0.0)
	# 눌리면 짧아진다.
	assert_lt(m.ray_rect(0, 0.7).size.y, rect.size.y, "역류해도 광선 길이가 안 줄었다")
