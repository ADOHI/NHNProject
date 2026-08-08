extends GutTest
## `ActionButtonMotion` — 버튼의 거동.
##
## 여기서 보는 것은 「값이 맞나」가 아니라 **「지나쳤다 되돌아오나」**다.
## 앞 판이 지수 접근을 써서 목표를 지나칠 방법이 아예 없었고, 그래서 손맛이
## 원리적으로 불가능했다. 그 결함은 눈으로는 「좀 밋밋한데」로 넘어간다.


func _settled() -> ActionButtonMotion:
	var motion := ActionButtonMotion.new()
	motion.state = ActionButtonMotion.State.NORMAL
	return motion


func test_hover_geometry_overshoots_past_the_target() -> void:
	var motion := _settled()
	motion.state = ActionButtonMotion.State.HOVER
	motion.enter_hover()
	var peak := 0.0
	for i in 40:
		motion.advance(0.01)
		peak = maxf(peak, motion.rise())
	assert_gt(peak, 1.02, "커서가 붙을 때 판이 목표 높이를 지나쳐야 한다")
	assert_almost_eq(motion.rise(), 1.0, 0.001, "지나친 뒤에는 목표에 선다")


func test_hover_colour_never_overshoots() -> void:
	var motion := _settled()
	motion.state = ActionButtonMotion.State.HOVER
	motion.enter_hover()
	for i in 60:
		motion.advance(0.01)
		assert_between(motion.warmth(), 0.0, 1.0, "색이 목표를 지나치면 번쩍이는 결함이 된다")


func test_release_stretches_past_rest() -> void:
	var motion := _settled()
	motion.state = ActionButtonMotion.State.PRESSED
	motion.press()
	motion.advance(0.08)
	assert_almost_eq(motion.squeeze(), 1.0, 0.02, "누르고 있으면 끝까지 눌려 있다")
	motion.state = ActionButtonMotion.State.HOVER
	motion.release()
	var lowest := 0.0
	for i in 40:
		motion.advance(0.01)
		lowest = minf(lowest, motion.squeeze())
	assert_lt(lowest, -0.15, "손을 떼면 원래보다 늘어났다 돌아와야 한다")


## 20fps GIF 가 판정 매체다. 되튐이 표본 **한 장**에만 걸리면 눈에는 아무 일도
## 일어나지 않은 것이다 — 실제로 그 사고가 났다.
func test_release_bounce_lands_on_at_least_three_samples() -> void:
	var motion := _settled()
	motion.state = ActionButtonMotion.State.PRESSED
	motion.press()
	motion.advance(0.10)
	motion.state = ActionButtonMotion.State.HOVER
	motion.release()
	var seen := 0
	for i in 10:
		motion.advance(0.05)
		if absf(motion.squeeze()) > 0.05:
			seen += 1
	assert_gte(seen, 3, "0.05초 표본 서너 장에 걸쳐야 동작으로 읽힌다")


func test_press_sinks_the_plate_below_rest() -> void:
	var motion := _settled()
	motion.state = ActionButtonMotion.State.HOVER
	motion.enter_hover()
	motion.advance(0.30)
	var raised := motion.lift()
	motion.state = ActionButtonMotion.State.PRESSED
	motion.press()
	motion.advance(0.06)
	assert_lt(motion.lift(), raised - 3.0, "눌리면 떠 있던 높이보다 확실히 내려가야 한다")
	assert_lt(motion.lift(), 0.0, "눌린 판은 바닥 아래로 간다")


func test_disabled_freezes_every_clock() -> void:
	var motion := _settled()
	motion.enter_hover()
	motion.press()
	motion.disable()
	var before := motion.runner_at()
	for i in 30:
		motion.advance(0.05)
	assert_eq(motion.runner_at(), before, "비활성은 정지 화면이다")
	assert_eq(motion.warmth(), 0.0, "비활성에는 커서 상태가 없다")
	assert_eq(motion.lift(), 0.0, "비활성은 떠 있지 않다")
	assert_eq(motion.accent(), 0.0, "비활성에는 강세 띠가 없다")
	assert_eq(motion.impact(), -1.0, "비활성으로 넘어갈 때 남은 충격파를 지운다")


func test_disabled_does_not_keep_a_stale_press() -> void:
	var motion := _settled()
	motion.state = ActionButtonMotion.State.PRESSED
	motion.press()
	motion.advance(0.10)
	motion.disable()
	motion.state = ActionButtonMotion.State.NORMAL
	assert_eq(motion.squeeze(), 0.0, "다시 켰을 때 누르지도 않은 눌림이 남아 있으면 안 된다")
	assert_eq(motion.inversion(), 0.0, "반전도 같이 지워져야 한다")


func test_sheen_crosses_the_plate_and_wraps() -> void:
	var motion := _settled()
	var lowest := 9.0
	var highest := -9.0
	for i in 500:
		motion.advance(0.01)
		lowest = minf(lowest, motion.sheen_at())
		highest = maxf(highest, motion.sheen_at())
	assert_lt(lowest, 0.0, "광택은 판 왼쪽 밖에서 들어와야 한다")
	assert_gt(highest, 1.0, "광택은 판 오른쪽 밖으로 나가야 한다")


func test_hover_makes_the_sheen_much_faster() -> void:
	assert_lt(
		ActionButtonMotion.SHEEN_HOVER,
		ActionButtonMotion.SHEEN_IDLE * 0.25,
		"커서를 올렸을 때 광택이 확실히 빨라져야 상태가 갈린다"
	)


func test_sheen_stays_weak_enough_to_read_text_under() -> void:
	var motion := _settled()
	motion.state = ActionButtonMotion.State.HOVER
	motion.enter_hover()
	for i in 60:
		motion.advance(0.01)
		assert_lt(motion.sheen_strength(), 0.25, "광택이 진하면 글자를 먹는다")


func test_text_never_moves_more_than_a_pixel() -> void:
	var motion := _settled()
	motion.state = ActionButtonMotion.State.PRESSED
	motion.press()
	for i in 60:
		motion.advance(0.01)
		assert_lte(absf(motion.text_dip()), 1.0, "글자가 흔들리면 안 읽힌다")


func test_impact_expires() -> void:
	var motion := _settled()
	motion.press()
	motion.advance(0.01)
	assert_gt(motion.impact(), 0.0, "누른 직후에는 충격파가 있다")
	motion.advance(ActionButtonMotion.IMPACT_TIME)
	assert_eq(motion.impact(), -1.0, "충격파는 남지 않는다")


func test_pose_is_a_pure_function_of_the_clocks() -> void:
	var first := ActionButtonMotion.new()
	var second := ActionButtonMotion.new()
	first.state = ActionButtonMotion.State.HOVER
	second.state = ActionButtonMotion.State.HOVER
	# 첫 번째는 사건으로, 두 번째는 시각을 직접 앉혀서 같은 자리에 둔다.
	first.enter_hover()
	for i in 12:
		first.advance(0.01)
	second.pose(0.12, 0.12, -1.0, -1.0, -1.0)
	assert_almost_eq(second.rise(), first.rise(), 0.0001, "앉힌 시각이 흘린 시각과 같아야 한다")
	assert_almost_eq(second.sheen_at(), first.sheen_at(), 0.0001, "캡처가 재현되려면 순수해야 한다")
