class_name UiTheme
extends RefCounted
## 화면 전체의 Theme 을 **코드로** 만든다.
##
## 에디터에서 손으로 찍은 .tres 를 두지 않는 이유는 세 가지다.
##
##   1. 어떤 값이 왜 그런지 diff 에 남지 않는다. 이진 편집에 가까워 리뷰가 불가능하다
##   2. 토큰(design_tokens.gd)을 고쳐도 .tres 는 따라오지 않는다. 곧 둘이 어긋난다
##   3. 같은 규칙을 여러 화면에 퍼뜨릴 때 손으로 복사하게 된다
##
## 그래서 Theme 은 **토큰의 함수**다. 색을 바꾸려면 토큰 한 줄만 고치면 된다.
##
## 쓰는 법 — 루트 Control 에 한 번만 물린다. Theme 은 자식에게 그대로 흘러내린다.
##
##     func _ready() -> void:
##         theme = UiTheme.get_theme()

## 위젯 이름 대신 쓰는 변형(variation) 이름들.
##
## Godot 의 theme_type_variation 은 "이 Label 은 보통 Label 이 아니다"를 씬에서 선언하게 해 준다.
## 라벨마다 색·크기를 손으로 덮어쓰면 그 순간 위계 규칙이 씬 파일 안으로 흩어진다.
const DISPLAY := "Display"
const NUMERIC := "Numeric"
const TITLE := "Title"
const CAPTION := "Caption"
const MICRO := "Micro"
const HYPE := "Hype"
const ROOM_TILE := "RoomTile"
const TRUTH_PANEL := "TruthPanel"

static var _theme: Theme = null


## 한 번 만들어 두고 계속 쓴다. 화면마다 새로 만들면 같은 StyleBox 가 수십 벌 생긴다.
static func get_theme() -> Theme:
	if _theme == null:
		_theme = build()
	return _theme


## 새 Theme 을 만든다. 쇼케이스처럼 값을 바꿔 가며 볼 때만 직접 부른다.
static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = UiTokens.TYPE_BODY
	var font := _project_font()
	if font != null:
		theme.default_font = font
	_build_label(theme)
	_build_button(theme)
	_build_panel(theme)
	_build_slider(theme)
	_build_scroll(theme)
	_build_variations(theme)
	return theme


## 프로젝트에 지정된 폰트를 그대로 쓴다. 경로를 여기 또 적으면 둘이 어긋난다.
static func _project_font() -> Font:
	var path: String = ProjectSettings.get_setting("gui/theme/custom_font", "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Font


static func _build_label(theme: Theme) -> void:
	theme.set_color("font_color", "Label", UiTokens.INK)
	theme.set_font_size("font_size", "Label", UiTokens.TYPE_BODY)


## 버튼은 **시설의 조작반**이다. 눌리면 계측 색이 켜진다.
##
## 평상시에 테두리를 두르지 않는 것이 규칙이다. 얇은 테두리를 두른 회색 사각형은
## 어느 게임에나 있고, 그래서 이 게임의 것이 아니다.
static func _build_button(theme: Theme) -> void:
	var cuts := PackedFloat32Array([0.0, 0.0, UiTokens.CUT_BUTTON, 0.0])
	var normal := UiStyleBox.plate(UiTokens.PLATE_HIGH, cuts)
	var hover := UiStyleBox.plate(UiTokens.SIGNAL_GHOST, cuts, UiTokens.SIGNAL_DIM, 1)
	var pressed := UiStyleBox.plate(UiTokens.SIGNAL_DIM, cuts)
	var disabled := UiStyleBox.plate(UiTokens.fade(UiTokens.PLATE, 0.6), cuts)
	var focus := UiStyleBox.plate(Color(0.0, 0.0, 0.0, 0.0), cuts, UiTokens.SIGNAL, 1)
	for entry in [normal, hover, pressed, disabled, focus]:
		UiStyleBox.pad(entry as StyleBox, UiTokens.SPACE_STEP, UiTokens.SPACE_SNUG)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_color("font_color", "Button", UiTokens.INK_MUTED)
	theme.set_color("font_hover_color", "Button", UiTokens.SIGNAL_HOT)
	theme.set_color("font_pressed_color", "Button", UiTokens.SIGNAL_HOT)
	theme.set_color("font_focus_color", "Button", UiTokens.INK)
	theme.set_color("font_disabled_color", "Button", UiTokens.INK_FAINT)
	theme.set_font_size("font_size", "Button", UiTokens.TYPE_LABEL)


static func _build_panel(theme: Theme) -> void:
	var panel := UiStyleBox.plate(UiTokens.fade(UiTokens.PLATE, 0.94), UiTokens.panel_cuts())
	UiStyleBox.pad(panel, UiTokens.SPACE_STEP, UiTokens.SPACE_STEP)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)


## 슬라이더의 손잡이는 **그림 파일 없이** 만든다. 에셋을 늘리지 않는 것이 이 작업의 전제다.
static func _build_slider(theme: Theme) -> void:
	var track := UiStyleBox.plate(UiTokens.VOID, PackedFloat32Array([0.0, 0.0, 0.0, 0.0]))
	track.content_margin_top = 3.0
	track.content_margin_bottom = 3.0
	var filled := UiStyleBox.plate(UiTokens.SIGNAL_DIM, PackedFloat32Array([0.0, 0.0, 0.0, 0.0]))
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)
	var grabber := _grabber_texture(UiTokens.SIGNAL)
	theme.set_icon("grabber", "HSlider", grabber)
	theme.set_icon("grabber_highlight", "HSlider", _grabber_texture(UiTokens.SIGNAL_HOT))
	theme.set_icon("grabber_disabled", "HSlider", _grabber_texture(UiTokens.SIGNAL_DIM))


static func _build_scroll(theme: Theme) -> void:
	theme.set_stylebox("panel", "ScrollContainer", UiStyleBox.hollow())
	for type in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", type, UiStyleBox.plate(UiTokens.VOID, _no_cuts()))
		theme.set_stylebox("grabber", type, UiStyleBox.plate(UiTokens.SEAM, _no_cuts()))
		theme.set_stylebox(
			"grabber_highlight", type, UiStyleBox.plate(UiTokens.SIGNAL_DIM, _no_cuts())
		)
		theme.set_stylebox("grabber_pressed", type, UiStyleBox.plate(UiTokens.SIGNAL, _no_cuts()))


## 라벨의 위계. 크기와 색이 짝으로 정해져 있고, 씬에서는 이름만 고른다.
static func _build_variations(theme: Theme) -> void:
	_variation(theme, DISPLAY, "Label", UiTokens.TYPE_DISPLAY, UiTokens.SIGNAL)
	_variation(theme, NUMERIC, "Label", UiTokens.TYPE_NUMBER, UiTokens.SIGNAL)
	_variation(theme, TITLE, "Label", UiTokens.TYPE_TITLE, UiTokens.INK)
	_variation(theme, CAPTION, "Label", UiTokens.TYPE_LABEL, UiTokens.INK_MUTED)
	_variation(theme, MICRO, "Label", UiTokens.TYPE_MICRO, UiTokens.INK_FAINT)
	# 송출 레이어. 계측 색과 절대 섞이지 않는다 — 이 색이 붙은 글자는 못 믿는 글자다.
	_variation(theme, HYPE, "Label", UiTokens.TYPE_LABEL, UiTokens.ONAIR)

	# 방 타일은 전부 직접 그린다. 기본 버튼 그리기를 통째로 비운다.
	theme.set_type_variation(ROOM_TILE, "Button")
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		theme.set_stylebox(state, ROOM_TILE, UiStyleBox.hollow())

	# 개발 패널은 송출되지 않는 화면이다. 모서리를 자르지 않고 계측 선만 세운다.
	theme.set_type_variation(TRUTH_PANEL, "PanelContainer")
	var truth := UiStyleBox.edge_rule(
		UiTokens.fade(UiTokens.VOID, 0.96), UiTokens.SIGNAL_DIM, int(UiTokens.STROKE_RULE)
	)
	UiStyleBox.pad(truth, UiTokens.SPACE_STEP, UiTokens.SPACE_STEP)
	theme.set_stylebox("panel", TRUTH_PANEL, truth)


static func _variation(theme: Theme, name: String, base: String, size: int, color: Color) -> void:
	theme.set_type_variation(name, base)
	theme.set_font_size("font_size", name, size)
	theme.set_color("font_color", name, color)


static func _no_cuts() -> PackedFloat32Array:
	return PackedFloat32Array([0.0, 0.0, 0.0, 0.0])


## 잘린 모서리를 가진 작은 손잡이를 픽셀로 찍는다.
##
## 이미지 파일을 추가하지 않겠다는 제약이 여기서는 오히려 이득이다 —
## 색을 바꾸려고 파일을 다시 그릴 일이 없다.
static func _grabber_texture(color: Color) -> ImageTexture:
	var width := 13
	var height := 20
	var cut := 5
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in height:
		for x in width:
			# 좌상단만 잘라 낸다. 패널·타일과 같은 형태 규칙이다.
			if x + y < cut:
				continue
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
