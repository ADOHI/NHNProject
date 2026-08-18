extends GutTest
## SQUASH 컨셉의 단위 테스트.
##
## 지키려는 것은 하나다 — **부피가 언제나 1이다.** 세로로 눌린 만큼 가로로 정확히
## 넓어져야 한다. 이 불변식이 깨지면 그냥 「크기가 변하는 버튼」이 되고,
## 그러면 SLAM 을 부드럽게 한 판과 구별되지 않는다 (docs/design/20-ui-kit.md §20.3).


func _sample(
	time: float, hover_time: float, hovering: bool, press_time: float, pressing: bool
) -> PlateState:
	return SquashMotion.evaluate(time, hover_time, hovering, press_time, pressing, 3)


## 어느 순간에도 가로 x 세로 = 1 이다.
func test_volume_is_always_one() -> void:
	for step in range(240):
		var t := float(step) * 0.05
		for case in [
			_sample(t, 9.0, false, 9.0, false),
			_sample(t, t * 0.3, true, 9.0, false),
			_sample(t, 1.0, true, t * 0.2, true),
			_sample(t, 1.0, true, t * 0.2, false),
		]:
			var volume: float = case.scale.x * case.scale.y
			assert_almost_eq(volume, 1.0, 0.001, "부피가 %f 로 샜다" % volume)


## 눌리면 확실히 납작해지고, 그만큼 넓어진다.
func test_press_flattens_and_widens() -> void:
	var pressed := _sample(2.0, 1.0, true, 0.10, true)
	assert_lt(pressed.scale.y, 0.75, "눌렀는데 납작해지지 않는다")
	assert_gt(pressed.scale.x, 1.30, "납작해졌는데 옆으로 안 넓어졌다 - 부피가 사라졌다")


## 손을 떼면 **반대로** 길쭉해진다. 눌린 상태에서 곧장 제자리로 가면 덩어리가 아니다.
func test_release_rebounds_taller_than_rest() -> void:
	var tallest := 0.0
	for step in range(40):
		var case := _sample(2.0, 1.0, true, float(step) * 0.01, false)
		tallest = maxf(tallest, case.scale.y)
	assert_gt(tallest, 1.12, "뗀 뒤에 길쭉해지지 않는다")


## 되튐이 여러 번 보여야 한다. 한 번에 서면 그냥 크기 변화다.
func test_release_oscillates_more_than_once() -> void:
	var crossings := 0
	var previous := _sample(2.0, 1.0, true, 0.0, false).scale.y - 1.0
	for step in range(1, 160):
		var current := _sample(2.0, 1.0, true, float(step) * 0.006, false).scale.y - 1.0
		if (current >= 0.0) != (previous >= 0.0):
			crossings += 1
		previous = current
	assert_gt(crossings, 2, "되튐이 한 번뿐이라 덩어리로 안 보인다")


## **자리를 옮기지 않는다.** SLAM 이 자리를 움직이고 여기는 비율만 움직인다.
## 이 둘이 섞이면 넷 중 하나를 버리는 셈이 된다.
func test_plate_never_flies_in() -> void:
	for step in range(120):
		var t := float(step) * 0.05
		var case := _sample(t, t * 0.3, true, 9.0, false)
		assert_eq(case.offset, Vector2.ZERO, "SQUASH 가 자리를 옮겼다 - SLAM 과 겹친다")


## **색을 뒤집지 않는다.** 반전은 SLAM 과 HOLD 의 수단이다.
func test_colour_never_inverts() -> void:
	for step in range(120):
		var t := float(step) * 0.05
		var case := _sample(t, 1.0, true, t * 0.2, true)
		assert_eq(case.invert, 0.0, "SQUASH 가 색을 뒤집었다 - 다른 컨셉의 수단이다")


## 아래 모서리를 고정해야 「위에서 눌렸다」가 된다. 복판을 고정하면 공중에 뜬다.
func test_pivot_is_the_bottom_edge() -> void:
	assert_eq(_sample(1.0, 9.0, false, 9.0, false).pivot, Vector2(0.0, 0.5))


## 글자도 같이 찌그러지되 판보다는 덜 먹어야 읽힌다.
func test_ink_squashes_less_than_the_plate() -> void:
	var pressed := _sample(2.0, 1.0, true, 0.10, true)
	assert_lt(pressed.ink_squash.y, 1.0, "글자가 안 찌그러진다 - 고무판 위의 스티커다")
	assert_gt(pressed.ink_squash.y, pressed.scale.y, "글자가 판만큼 찌그러져 안 읽힌다")


## idle 에서도 죽지 않는다.
func test_idle_keeps_wobbling() -> void:
	var lowest := 9.0
	var highest := 0.0
	for step in range(400):
		var case := _sample(float(step) * 0.05, 9.0, false, 9.0, false)
		lowest = minf(lowest, case.scale.y)
		highest = maxf(highest, case.scale.y)
	assert_gt(highest - lowest, 0.03, "가만히 둘 때 사실상 정지해 있다")
