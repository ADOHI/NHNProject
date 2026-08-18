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
	assert_eq(motion.reveal(), 0.0, "비활성에는 커서 밀도가 없다")
	assert_eq(motion.flare(), 0.0, "비활성에는 섬광이 없다")
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


## 화려함은 요소를 더해서가 아니라 **밀도 대비**에서 나온다. 평상이 조용해야
## 커서에서 밀도가 오르는 것이 반응으로 읽힌다 — 평상까지 화려하게 만든 판이
## 「조잡」했고, 반대로 사건까지 조용한 판이 「허접」했다.
func test_resting_button_has_no_extra_density() -> void:
	var motion := _settled()
	for i in 200:
		motion.advance(0.01)
		assert_eq(motion.reveal(), 0.0, "평상에는 눈금도 모서리 표도 없다")
		assert_eq(motion.flare(), 0.0, "평상에는 섬광이 없다")


func test_hover_density_overshoots_then_settles() -> void:
	var motion := _settled()
	motion.state = ActionButtonMotion.State.HOVER
	motion.enter_hover()
	var peak := 0.0
	for i in 40:
		motion.advance(0.01)
		peak = maxf(peak, motion.reveal())
	assert_gt(peak, 1.02, "모서리 표가 제자리를 지나쳐 튀어 나가야 붙은 것으로 읽힌다")
	assert_almost_eq(motion.reveal(), 1.0, 0.001, "지나친 뒤에는 제자리에 선다")


func test_hover_density_arrives_fast_enough_to_feel_like_a_response() -> void:
	assert_lt(ActionButtonMotion.REVEAL_TIME, 0.25, "손이 닿고 늦게 반응하면 죽은 것으로 보인다")


## 하나만 번쩍이면 상태 표시고 여럿이 한 시각에 같이 번쩍여야 사건이다.
## 값이 하나뿐이라 따로 어긋날 자리가 없다는 것을 잠근다.
func test_flare_fires_at_once_and_dies() -> void:
	var motion := _settled()
	motion.state = ActionButtonMotion.State.PRESSED
	motion.press()
	assert_almost_eq(motion.flare(), 1.0, 0.001, "누른 그 순간이 가장 세다")
	var seen := 0
	for i in 6:
		motion.advance(0.05)
		if motion.flare() > 0.05:
			seen += 1
	assert_gte(seen, 2, "20fps 표본 두 장에는 걸려야 번쩍인 것으로 보인다")
	motion.advance(ActionButtonMotion.FLARE_TIME)
	assert_eq(motion.flare(), 0.0, "섬광은 남지 않는다")


func test_flare_is_shorter_than_the_shockwave() -> void:
	assert_lt(
		ActionButtonMotion.FLARE_TIME,
		ActionButtonMotion.IMPACT_TIME,
		"섬광이 먼저 꺼지고 파문이 뒤에 퍼져야 한 사건의 앞뒤가 생긴다"
	)


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
	assert_almost_eq(second.reveal(), first.reveal(), 0.0001, "캡처가 재현되려면 순수해야 한다")
