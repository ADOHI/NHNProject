extends GutTest
## 도착 곡선의 단위 테스트.
##
## 지키려는 것은 하나다 — **도착은 목표를 지나칠 수 있어야 한다.**
## 앞 판은 상태를 목표값으로 지수 접근시켜서 오버슛이 원천적으로 불가능했고,
## 그래서 타격감이 나오지 않았다 (docs/design/20-ui-kit.md §20.2).


func test_out_back_actually_overshoots() -> void:
	var highest := 0.0
	for i in range(101):
		highest = maxf(highest, KitEase.out_back(float(i) / 100.0))
	assert_gt(highest, 1.05, "되튀는 곡선이 목표를 지나치지 않는다 - 타격감이 안 나온다")


func test_out_back_starts_and_lands() -> void:
	assert_almost_eq(KitEase.out_back(0.0), 0.0, 0.001)
	assert_almost_eq(KitEase.out_back(1.0), 1.0, 0.001)


## 범위를 벗어난 입력에도 끝값을 준다. 사건 시계는 1 을 훌쩍 넘겨서 들어온다.
func test_curves_clamp_outside_range() -> void:
	assert_almost_eq(KitEase.out_back(4.0), 1.0, 0.001)
	assert_almost_eq(KitEase.out_elastic(4.0), 1.0, 0.001)
	assert_almost_eq(KitEase.out_expo(-1.0), 0.0, 0.001)


func test_elastic_wobbles_more_than_once() -> void:
	var crossings := 0
	var previous := KitEase.out_elastic(0.001) - 1.0
	for i in range(1, 400):
		var current := KitEase.out_elastic(float(i) / 400.0) - 1.0
		if (current >= 0.0) != (previous >= 0.0):
			crossings += 1
		previous = current
	assert_gt(crossings, 2, "탄성 곡선이 한 번밖에 안 넘나든다 - 되튐으로 안 보인다")


## 충격의 잔떨림은 0 에서 시작해 0 으로 잦아든다.
func test_shiver_starts_and_dies() -> void:
	assert_almost_eq(KitEase.shiver(0.0, 6.0, 9.0), 0.0, 0.001)
	assert_lt(absf(KitEase.shiver(3.0, 6.0, 9.0)), 0.001, "잔떨림이 안 잦아든다")
	var peak := 0.0
	for i in range(200):
		peak = maxf(peak, absf(KitEase.shiver(float(i) / 200.0, 6.0, 9.0)))
	assert_gt(peak, 0.1, "잔떨림이 사실상 없다")


# ---------------------------------------------------------------- 계단


## 시간을 칸칸이 끊는다. 사이값이 없어야 SHEAR 가 덜컥거린다.
func test_hold_quantises_time() -> void:
	assert_almost_eq(KitEase.hold(0.30, 4.0), 0.25, 0.0001)
	assert_almost_eq(KitEase.hold(0.49, 4.0), 0.25, 0.0001)
	assert_almost_eq(KitEase.hold(0.51, 4.0), 0.50, 0.0001)


## 같은 칸 안에서는 값이 **완전히 같아야** 한다. 조금이라도 다르면 부드러워진다.
func test_hold_is_flat_inside_a_step() -> void:
	var first := KitEase.hold(1.00, 3.0)
	for i in range(30):
		assert_eq(KitEase.hold(1.00 + float(i) * 0.001, 3.0), first)


func test_hold_passes_through_when_disabled() -> void:
	assert_almost_eq(KitEase.hold(0.37, 0.0), 0.37, 0.0001)


# ---------------------------------------------------------------- 결정적 난수


## 난수를 쓰면 캡처마다 화면이 달라져 컨셉끼리 견줄 수 없다.
func test_hash_is_stable_and_bounded() -> void:
	for i in range(200):
		var value := KitEase.hash01(i)
		assert_between(value, 0.0, 1.0, "해시가 범위를 벗어났다")
		assert_eq(value, KitEase.hash01(i), "같은 입력에 다른 값이 나온다")


## 이웃한 씨앗이 비슷한 값을 주면 판 셋이 한 박자로 움직인다.
func test_hash_spreads_neighbours() -> void:
	var same := 0
	for i in range(200):
		if absf(KitEase.hash01(i) - KitEase.hash01(i + 1)) < 0.02:
			same += 1
	assert_lt(same, 20, "이웃 씨앗이 너무 자주 붙어 나온다")
