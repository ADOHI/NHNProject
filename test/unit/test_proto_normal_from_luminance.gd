extends GutTest
## 휘도 기울기 노멀맵의 단위 테스트.
##
## 노멀맵은 **눈으로 판정할 수 없다.** 파랗고 분홍한 그림이 나오면 다 그럴듯해 보이고,
## 부호가 뒤집혀 빛이 반대쪽에서 오는 것조차 「노멀이 약하다」와 똑같이 생긴다.
## 그래서 **방향을 숫자로 못 박는다.**
##
## 여기서 지키는 것 넷 — 크기가 유지되는가 · 평평한 그림은 평평한 노멀을 주는가 ·
## 기울기의 **방향과 부호**가 맞는가 · 세기 손잡이가 실제로 세기를 바꾸는가.


## 왼쪽이 검고 오른쪽이 흰 그림. 밝기가 오른쪽으로 오르는 경사면이다.
func _ramp_right(size: int = 8) -> Image:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var v := float(x) / float(size - 1)
			image.set_pixel(x, y, Color(v, v, v))
	return image


func _flat(size: int = 8, value: float = 0.5) -> Image:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	image.fill(Color(value, value, value))
	return image


func test_keeps_size_and_is_rgb() -> void:
	var out := ProtoNormalFromLuminance.build(_flat(6))
	assert_eq(out.get_width(), 6)
	assert_eq(out.get_height(), 6)


## 평평한 그림은 **정확히 평평한 노멀**을 준다. (0.5, 0.5, 1.0) 이 「똑바로 앞을 본다」다.
func test_flat_image_gives_flat_normal() -> void:
	var out := ProtoNormalFromLuminance.build(_flat(6))
	var c := out.get_pixel(3, 3)
	assert_almost_eq(c.r, 0.5, 0.01, "x 기울기가 없어야 한다")
	assert_almost_eq(c.g, 0.5, 0.01, "y 기울기가 없어야 한다")
	assert_gt(c.b, 0.99, "z 는 1 이어야 한다")


func test_flat_image_has_zero_tilt() -> void:
	assert_almost_eq(
		ProtoNormalFromLuminance.tilt_rms(ProtoNormalFromLuminance.build(_flat(6))), 0.0, 0.01
	)


## **부호가 이 테스트의 전부다.** 오른쪽으로 밝아지는 경사면은 오른쪽으로 기울어
## 오르는 면이므로, 법선은 **왼쪽(−x)** 을 향해야 한다 → 붉은 채널이 0.5 아래다.
##
## 이걸 안 박아 두면 부호가 뒤집힌 채로 "빛이 반대쪽에서 오는 것 같다" 를 며칠 쫓는다.
func test_right_ramp_tilts_normal_to_negative_x() -> void:
	var out := ProtoNormalFromLuminance.build(_ramp_right(8), 4.0)
	var c := out.get_pixel(4, 4)
	assert_lt(c.r, 0.49, "밝아지는 쪽의 반대로 기울어야 한다")
	assert_almost_eq(c.g, 0.5, 0.02, "가로 경사면은 y 기울기를 만들지 않는다")


## 세기 손잡이가 정말 세기를 바꾸는가. **아무것도 확인하지 않는 테스트**를 막기 위해
## 두 값을 실제로 비교한다.
func test_strength_increases_tilt() -> void:
	var weak := ProtoNormalFromLuminance.tilt_rms(
		ProtoNormalFromLuminance.build(_ramp_right(8), 1.0)
	)
	var strong := ProtoNormalFromLuminance.tilt_rms(
		ProtoNormalFromLuminance.build(_ramp_right(8), 8.0)
	)
	assert_gt(strong, weak, "세기를 올리면 기울기가 커져야 한다")
	assert_gt(weak, 0.0, "약해도 0 은 아니다")


## **바닥은 추정할 것이 없다.** 평면의 법선은 기하에서 나오므로 어디서나 같은 값이어야
## 한다. 값이 자리마다 다르면 그건 이미 추정이 섞인 것이다.
func test_plane_normal_is_constant_everywhere() -> void:
	var out := ProtoNormalFromLuminance.build_plane(8, 8, 60.0)
	var first := out.get_pixel(0, 0)
	for y in 8:
		for x in 8:
			assert_eq(out.get_pixel(x, y), first, "평면 법선은 자리에 따라 달라지지 않는다")


## 0 도는 화면을 정면으로 마주 본 면이다. 평평한 노멀과 같아야 한다.
func test_plane_zero_pitch_is_flat() -> void:
	var c := ProtoNormalFromLuminance.build_plane(4, 4, 0.0).get_pixel(1, 1)
	assert_almost_eq(c.r, 0.5, 0.01)
	assert_almost_eq(c.g, 0.5, 0.01)
	assert_gt(c.b, 0.99)


## 눕힐수록 기울어야 한다. **손잡이가 아무 일도 안 하는 것**을 막는다.
func test_plane_pitch_tilts_up_screen() -> void:
	var shallow := ProtoNormalFromLuminance.build_plane(4, 4, 20.0).get_pixel(1, 1)
	var steep := ProtoNormalFromLuminance.build_plane(4, 4, 70.0).get_pixel(1, 1)
	assert_gt(shallow.g, 0.5, "화면 위쪽으로 기운다 (g 가 0.5 위)")
	assert_gt(steep.g, shallow.g, "많이 눕힐수록 많이 기운다")
	assert_almost_eq(shallow.r, 0.5, 0.01, "좌우로는 안 기운다")


## 평면 위에 결을 얹으면 평면보다 자리마다 달라야 하고, 평평한 그림이면 평면 그대로여야 한다.
func test_plane_with_detail_falls_back_to_plane_on_flat_input() -> void:
	var plane := ProtoNormalFromLuminance.build_plane(6, 6, 45.0).get_pixel(3, 3)
	var blended := ProtoNormalFromLuminance.build_plane_with_detail(_flat(6), 45.0, 2.0).get_pixel(
		3, 3
	)
	assert_almost_eq(blended.r, plane.r, 0.01)
	assert_almost_eq(blended.g, plane.g, 0.01)


func test_plane_with_detail_adds_tilt_on_ramp() -> void:
	var plane_rms := ProtoNormalFromLuminance.tilt_rms(
		ProtoNormalFromLuminance.build_plane(8, 8, 45.0)
	)
	var blended := ProtoNormalFromLuminance.build_plane_with_detail(_ramp_right(8), 45.0, 4.0)
	assert_gt(ProtoNormalFromLuminance.tilt_rms(blended), plane_rms, "결이 얹히면 기울기가 커진다")
