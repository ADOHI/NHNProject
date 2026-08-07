extends GutTest
## 코드로 만드는 Theme(src/ui/style/ui_theme.gd) 검증.
##
## 여기서 지키려는 것은 "예쁜가"가 아니라 **규칙이 실제로 살아 있는가**다.
##
##   둥근 모서리를 쓰지 않는다 — corner_detail 이 1 이어야 챔퍼가 된다
##   위계는 토큰에서 나온다 — 변형마다 크기와 색이 붙어 있어야 한다
##
## 이 둘이 깨지면 화면은 조용히 Godot 기본 테마로 되돌아간다.


func test_theme_is_cached() -> void:
	assert_same(UiTheme.get_theme(), UiTheme.get_theme(), "Theme 은 한 벌만 만든다")


func test_button_corners_are_chamfered_not_rounded() -> void:
	var box := UiTheme.build().get_stylebox("normal", "Button") as StyleBoxFlat
	assert_not_null(box)
	# corner_detail 이 1 이면 원호가 직선 한 토막이 된다 = 잘린 모서리.
	assert_eq(box.corner_detail, 1, "모서리는 굴리지 않고 자른다")
	assert_gt(box.corner_radius_bottom_right, 0, "자르는 자리는 우하단이다")
	assert_eq(box.corner_radius_top_left, 0, "네 귀퉁이를 똑같이 처리하지 않는다")


func test_label_variations_carry_size_and_color() -> void:
	var theme := UiTheme.build()
	for variation in [UiTheme.DISPLAY, UiTheme.NUMERIC, UiTheme.TITLE, UiTheme.CAPTION]:
		assert_true(theme.has_font_size("font_size", variation), "%s 에 크기가 있다" % variation)
		assert_true(theme.has_color("font_color", variation), "%s 에 색이 있다" % variation)


func test_display_is_larger_than_body() -> void:
	var theme := UiTheme.build()
	var display := theme.get_font_size("font_size", UiTheme.DISPLAY)
	var micro := theme.get_font_size("font_size", UiTheme.MICRO)
	assert_gt(display, micro * 3, "판단의 숫자와 곁들이는 말은 확실히 갈려야 한다")


func test_hype_variation_uses_the_broadcast_color() -> void:
	var theme := UiTheme.build()
	# 송출 레이어의 글자는 계측 색을 쓰지 않는다. 이 구분이 정보 설계의 근간이다.
	assert_eq(theme.get_color("font_color", UiTheme.HYPE), UiTokens.ONAIR)
	assert_eq(theme.get_color("font_color", UiTheme.NUMERIC), UiTokens.SIGNAL)


func test_room_tile_variation_draws_nothing_by_itself() -> void:
	var theme := UiTheme.build()
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := theme.get_stylebox(state, UiTheme.ROOM_TILE)
		assert_true(box is StyleBoxEmpty, "방 타일은 전부 직접 그린다")


func test_tokens_expose_distinct_cut_profiles() -> void:
	# 역할마다 자르는 모서리가 달라야 한다. 같으면 전부 같은 도형으로 보인다.
	assert_ne(UiTokens.tile_cuts(), UiTokens.panel_cuts())
	assert_ne(UiTokens.panel_cuts(), UiTokens.chip_cuts())


func test_fade_keeps_the_hue() -> void:
	var faded := UiTokens.fade(UiTokens.SIGNAL, 0.4)
	assert_eq(Color(faded.r, faded.g, faded.b), UiTokens.SIGNAL)
	assert_almost_eq(faded.a, 0.4, 0.001)
