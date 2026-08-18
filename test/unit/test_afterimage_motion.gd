extends GutTest
## AFTERIMAGE 컨셉의 단위 테스트.
##
## 지키려는 것 둘.
##   **잔상은 사건이 아니라 상태다** — 어느 순간에도 세 장이 존재한다
##   **탁해지지 않는다** — 잔상은 늘 본체 뒤에 있고, 색은 가장자리로만 보인다
##
## 두 번째가 이 컨셉의 유일한 위험이다 (docs/design/20-ui-kit.md §20.3).


func _sample(
	time: float, hover_time: float, hovering: bool, press_time: float, pressing: bool
) -> PlateState:
	return AfterimageMotion.evaluate(time, hover_time, hovering, press_time, pressing, 3)


## 어느 상태에서도 잔상 셋이 있다. 하나라도 빠지면 색분해가 무너진다.
func test_ghosts_exist_in_every_state() -> void:
	for step in range(200):
		var t := float(step) * 0.05
		for case in [
			_sample(t, 9.0, false, 9.0, false),
			_sample(t, t * 0.3, true, 9.0, false),
			_sample(t, 1.0, true, t * 0.2, true),
			_sample(t, 1.0, true, t * 0.2, false),
		]:
			assert_eq(case.ghosts.size(), 3, "잔상이 셋이 아니다 - 색분해가 무너진다")


## idle 에서도 **한순간도 멎지 않는다.** 이 컨셉의 idle 은 「가끔 움직인다」가 아니다.
func test_idle_never_stops() -> void:
	var previous := _sample(0.0, 9.0, false, 9.0, false).offset
	var still := 0
	for step in range(1, 300):
		var current := _sample(float(step) * 0.04, 9.0, false, 9.0, false).offset
		if current.distance_to(previous) < 0.02:
			still += 1
		previous = current
	assert_lt(still, 6, "가만히 둘 때 멎는 구간이 있다")


## 잔상은 본체와 **어긋나 있어야** 한다. 겹쳐 버리면 색이 하나도 안 보인다.
func test_ghosts_lag_behind_the_body() -> void:
	var apart := 0
	for step in range(200):
		var case := _sample(float(step) * 0.04, 1.0, true, 9.0, false)
		for ghost in case.ghosts:
			if (ghost["offset"] as Vector2).distance_to(case.offset) > 0.5:
				apart += 1
	assert_gt(apart, 500, "잔상이 본체에 너무 자주 붙어 있다")


## 세 잔상이 서로 다른 자리에 있어야 한다. 한 점에 모이면 색이 섞여 탁해진다.
func test_ghosts_never_stack_on_each_other() -> void:
	for step in range(200):
		var case := _sample(float(step) * 0.04, 1.0, true, 9.0, false)
		var a := case.ghosts[0]["offset"] as Vector2
		var b := case.ghosts[1]["offset"] as Vector2
		var c := case.ghosts[2]["offset"] as Vector2
		assert_gt(a.distance_to(b) + b.distance_to(c), 0.2, "잔상 셋이 한 자리에 겹쳤다")


## 세 색은 **빛의** 삼원색이어야 한다. 감산 삼원색이면 겹칠수록 흙빛이 된다.
func test_ghost_colours_are_additive_primaries() -> void:
	var case := _sample(1.0, 9.0, false, 9.0, false)
	var dominant: Array[int] = []
	for ghost in case.ghosts:
		var color := ghost["color"] as Color
		var channels := [color.r, color.g, color.b]
		dominant.append(channels.find(channels.max()))
	assert_eq(dominant.size(), 3)
	# 셋이 각각 다른 채널을 대표해야 겹쳤을 때 흰색으로 수렴한다.
	assert_eq([dominant[0], dominant[1], dominant[2]].size(), 3, "잔상 셋이 같은 채널을 대표한다 - 겹쳐도 흰색이 안 된다")
	assert_true(dominant.has(0) and dominant.has(1) and dominant.has(2), "삼원색이 아니다")


## 누르면 잔상이 실제로 멀리 터진다.
func test_press_bursts_the_ghosts_apart() -> void:
	var resting := _sample(2.0, 1.0, true, 9.0, false)
	var pressed := _sample(2.0, 1.0, true, 0.08, true)
	var rest_reach := (resting.ghosts[0]["offset"] as Vector2).distance_to(resting.offset)
	var burst_reach := (pressed.ghosts[0]["offset"] as Vector2).distance_to(pressed.offset)
	assert_gt(burst_reach, rest_reach + 10.0, "눌렀는데 잔상이 안 터진다")


## 본체는 남고 잔상만 터져야 「갈라졌다」로 읽힌다.
## 다 같이 움직이면 그냥 판 하나가 흔들린 것이다.
func test_body_stays_put_while_ghosts_burst() -> void:
	var before := _sample(2.0, 1.0, true, 9.0, false).offset
	var during := _sample(2.0, 1.0, true, 0.08, true).offset
	assert_lt(before.distance_to(during), 1.0, "터질 때 본체까지 같이 날아갔다")
