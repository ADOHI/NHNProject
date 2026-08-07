extends GutTest
## 코드로 만드는 Theme(src/ui/style/ui_theme.gd)과 토큰 검증.
##
## 여기서 지키려는 것은 "예쁜가"가 아니라 **규칙이 실제로 살아 있는가**다.
##
##   둥근 모서리도 잘린 모서리도 쓰지 않는다 — 인쇄물의 상자는 각지고 괘선으로 갇힌다
##   위계는 토큰에서 나온다 — 변형마다 크기와 색이 붙어 있어야 한다
##   먹판과 별색판은 절대 섞이지 않는다 — 이 구분이 정보 설계의 근간이다
##
## 이 셋이 깨지면 화면은 조용히 Godot 기본 테마로 되돌아간다.


func test_theme_is_cached() -> void:
	assert_same(UiTheme.get_theme(), UiTheme.get_theme(), "Theme 은 한 벌만 만든다")


func test_button_corners_are_square() -> void:
	var box := UiTheme.build().get_stylebox("normal", "Button") as StyleBoxFlat
	assert_not_null(box)
	for radius in [
		box.corner_radius_top_left,
		box.corner_radius_top_right,
		box.corner_radius_bottom_right,
		box.corner_radius_bottom_left,
	]:
		assert_eq(radius, 0, "인쇄물에는 둥근 모서리도 잘린 모서리도 없다")


func test_button_is_held_by_rules_not_a_full_border() -> void:
	var box := UiTheme.build().get_stylebox("normal", "Button") as StyleBoxFlat
	# 사방을 같은 굵기로 두르면 어느 게임에나 있는 회색 사각형이 된다.
	assert_gt(box.border_width_bottom, box.border_width_top, "굵은 변이 어디인지가 곧 위계다")
	assert_eq(box.border_width_right, 0)


func test_pressed_button_is_fully_inked() -> void:
	var theme := UiTheme.build()
	var pressed := theme.get_stylebox("pressed", "Button") as StyleBoxFlat
	assert_eq(pressed.bg_color, UiTokens.INK, "누르면 활자가 먹을 먹는다")
	assert_eq(theme.get_color("font_pressed_color", "Button"), UiTokens.PAPER_HIGH)


func test_label_variations_carry_size_and_color() -> void:
	var theme := UiTheme.build()
	for variation in [UiTheme.BANNER, UiTheme.DECK, UiTheme.HEAD, UiTheme.SUB, UiTheme.CAPTION]:
		assert_true(theme.has_font_size("font_size", variation), "%s 에 크기가 있다" % variation)
		assert_true(theme.has_color("font_color", variation), "%s 에 색이 있다" % variation)


func test_banner_dwarfs_everything_else() -> void:
	var theme := UiTheme.build()
	var banner := theme.get_font_size("font_size", UiTheme.BANNER)
	var deck := theme.get_font_size("font_size", UiTheme.DECK)
	var micro := theme.get_font_size("font_size", UiTheme.MICRO)
	# 매 턴 "더 갈까 나갈까"를 묻는 게임이면 그 판단의 근거가 1면 톱이어야 한다.
	assert_gte(banner, deck * 2, "인접 위험도 합은 제호보다도 크다")
	assert_gt(banner, micro * 8, "가장 큰 것과 가장 작은 것이 확실히 갈린다")


func test_spot_variations_never_use_the_ink_plate() -> void:
	var theme := UiTheme.build()
	# 별색이 붙은 글자는 못 믿는 글자다. 먹으로 적힌 논평이 생기면 이 규칙이 무너진다.
	assert_eq(theme.get_color("font_color", UiTheme.HYPE), UiTokens.SPOT)
	assert_eq(theme.get_color("font_color", UiTheme.SPOT_HEAD), UiTokens.SPOT)
	assert_eq(theme.get_color("font_color", UiTheme.BANNER), UiTokens.INK)
	assert_eq(theme.get_color("font_color", UiTheme.SUB), UiTokens.INK)


func test_room_tile_variation_draws_nothing_by_itself() -> void:
	var theme := UiTheme.build()
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := theme.get_stylebox(state, UiTheme.ROOM_TILE)
		assert_true(box is StyleBoxEmpty, "방 타일은 전부 직접 그린다")


func test_slip_grows_with_the_story() -> void:
	# 서명 — 어긋난 크기가 곧 부풀린 크기다. 사실은 어긋나지 않는다.
	assert_eq(UiTokens.slip(UiTokens.SLIP_TRUE), Vector2.ZERO)
	assert_lt(
		UiTokens.slip(UiTokens.SLIP_STORY).length(), UiTokens.slip(UiTokens.SLIP_SHOUT).length()
	)


func test_slip_keeps_one_direction() -> void:
	# 어긋나는 방향이 요소마다 다르면 한 대의 인쇄기로 찍은 지면이 아니다.
	var story := UiTokens.slip(UiTokens.SLIP_STORY).normalized()
	var shout := UiTokens.slip(UiTokens.SLIP_SHOUT).normalized()
	assert_almost_eq(story.dot(shout), 1.0, 0.001)


func test_screen_pitch_gets_coarser_as_we_know_less() -> void:
	# 망점의 굵기가 곧 모르는 정도다. 이 순서가 뒤집히면 정보 설계가 거꾸로 간다.
	assert_lt(UiTokens.SCREEN_FINE, UiTokens.SCREEN_MID)
	assert_lt(UiTokens.SCREEN_MID, UiTokens.SCREEN_COARSE)


func test_fade_keeps_the_hue() -> void:
	var faded := UiTokens.fade(UiTokens.SPOT, 0.4)
	assert_eq(Color(faded.r, faded.g, faded.b), UiTokens.SPOT)
	assert_almost_eq(faded.a, 0.4, 0.001)
