extends GutTest
## `TabletPose` — 손에 든 기기로 읽히게 하는 계산.
##
## **태블릿감 자체는 아직 화면에 안 붙었다.** 계산만 서 있고, 그 계산이 옳은지는
## 화면 없이도 잴 수 있다.

const SCREEN := Vector2(1280.0, 720.0)


## **어파인으로는 누운 판이 안 된다.** 마주 보는 두 변이 평행하면 멀어지는 쪽이
## 안 좁아져서 「비뚤어진 평면」으로 보인다.
func test_the_far_edge_is_narrower_than_the_near_one() -> void:
	var corners := TabletPose.quad(SCREEN, 0.0, 1.0)
	var far := corners[0].distance_to(corners[1])
	var near := corners[3].distance_to(corners[2])
	assert_lt(far, near, "위 변이 아래 변보다 좁아야 누운 판이다")
	assert_gt(near / far, 1.1, "차이가 너무 작으면 눈에 안 보인다")


## 안 눕히면 반듯한 직사각형이다. **기본이 평면이라야 기울임이 선택이 된다.**
func test_no_tip_means_a_plain_rectangle() -> void:
	var corners := TabletPose.quad(SCREEN, 0.0, 0.0)
	assert_almost_eq(corners[0].distance_to(corners[1]), SCREEN.x, 0.01)
	assert_almost_eq(corners[3].distance_to(corners[2]), SCREEN.x, 0.01)


## 사영 변환이 네 귀퉁이를 정확히 맞춰야 한다. 여기가 어긋나면 텍스처가 밀린다.
func test_the_corners_land_exactly() -> void:
	var corners := TabletPose.quad(SCREEN, 0.4, 0.8)
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in 4:
		assert_lt(TabletPose.project(corners, uvs[i]).distance_to(corners[i]), 0.05, "귀퉁이 %d" % i)


## **원근이면 가운데가 한쪽으로 쏠린다.** 안 쏠리면 그건 어파인이다.
func test_the_middle_shifts_under_perspective() -> void:
	var corners := TabletPose.quad(SCREEN, 0.0, 1.0)
	var mid := TabletPose.project(corners, Vector2(0.5, 0.5))
	var flat := (corners[0] + corners[1] + corners[2] + corners[3]) * 0.25
	assert_gt(mid.distance_to(flat), 1.0, "가운데가 안 쏠리면 누운 판이 아니다")


## 격자 칸이 빈틈없이 이어져야 한다. 벌어지면 화면에 실금이 보인다.
func test_patches_share_their_edges() -> void:
	var corners := TabletPose.quad(SCREEN, 0.3, 0.7)
	var left: Array = TabletPose.patch(corners, Vector2i(3, 2))
	var right: Array = TabletPose.patch(corners, Vector2i(4, 2))
	var a: PackedVector2Array = left[0]
	var b: PackedVector2Array = right[0]
	assert_lt(a[1].distance_to(b[0]), 0.01, "오른쪽 위 모서리가 안 맞는다")
	assert_lt(a[2].distance_to(b[3]), 0.01, "오른쪽 아래 모서리가 안 맞는다")


## **미끄러지는 것은 연속이고 서는 곳은 이산이다.**
func test_inertia_carries_past_but_lands_on_a_notch() -> void:
	var landed := TabletPose.lands_on(2.0, 3.4)
	assert_eq(landed, roundf(landed), "칸이 아닌 데 서면 「가운데가 선택됨」이 깨진다")
	assert_gt(landed, 2.0, "손을 뗐는데 그 자리에 서면 그건 마우스다")
	assert_lt(TabletPose.lands_on(2.0, 0.1), 3.0, "살짝 민 것으로 여러 칸 가면 안 된다")


## 미끄러짐이 **점점 잦아든다.** 일정하게 감속하면 멈추는 순간이 딱 끊긴다.
func test_the_glide_eases_out() -> void:
	var first := TabletPose.glide(4.0, 0.1)
	var last := TabletPose.glide(4.0, 1.0) - TabletPose.glide(4.0, 0.9)
	assert_gt(first, last * 3.0, "뒤로 갈수록 훨씬 덜 가야 한다")
	assert_lt(TabletPose.glide(4.0, 99.0), TabletPose.reach(4.0) + 0.001, "총 거리를 안 넘는다")
	assert_gt(TabletPose.stop_time(4.0), 0.5, "너무 빨리 서면 관성이 없는 것과 같다")


## **당길수록 덜 늘어난다.** 끝에서 그냥 멈추면 화면이 고장난 것으로 보인다.
func test_the_rubber_band_never_snaps() -> void:
	var span := 60.0
	assert_lt(TabletPose.rubber(500.0, span), span, "아무리 당겨도 한계를 안 넘는다")
	assert_gt(TabletPose.rubber(20.0, span), 0.0, "조금 당기면 조금 늘어난다")
	assert_lt(
		TabletPose.rubber(200.0, span) - TabletPose.rubber(100.0, span),
		TabletPose.rubber(100.0, span) - TabletPose.rubber(0.0, span),
		"당길수록 늘어나는 몫이 줄어야 한다"
	)
	assert_almost_eq(TabletPose.rubber(-30.0, span), -TabletPose.rubber(30.0, span), 0.001)
