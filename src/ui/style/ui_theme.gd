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
## 그래서 Theme 은 **토큰의 함수**다.
##
## 쓰는 법 — 루트 Control 에 한 번만 물린다. Theme 은 자식에게 그대로 흘러내린다.
##
##     func _ready() -> void:
##         theme = UiTheme.get_theme()

## 위젯 이름 대신 쓰는 변형(variation) 이름들.
##
## 씬에서는 색•크기를 직접 적지 않고 **이름만 고른다.** 라벨마다 색을 손으로 칠하면
## 그 순간 위계 규칙이 씬 파일 안으로 흩어진다.
##
## 먹판(사실)과 별색판(과장)이 이름에서부터 갈려 있어야, 씬을 쓰는 사람이
## 실수로 논평을 먹으로 찍는 일이 없다.
const BANNER := "Banner"  ## 1면 톱. 인접 위험도 합
const DECK := "Deck"  ## 부제 크기의 숫자
const HEAD := "Head"  ## 기사 제목
const SUB := "Sub"  ## 지금 어디인가
const CAPTION := "Caption"  ## 사진 설명
const MICRO := "Micro"  ## 안 읽어도 되는 말
const SPOT_HEAD := "SpotHead"  ## **별색판 제목.** 렉카가 붙인 것
const HYPE := "Hype"  ## **별색판 본문.** 못 믿는 말
const ROOM_TILE := "RoomTile"  ## 직접 그리는 방 타일
const PROOF_PANEL := "ProofPanel"  ## 교정쇄 — 아직 안 나간 지면

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
	var font := project_font()
	if font != null:
		theme.default_font = font
	_build_label(theme)
	_build_button(theme)
	_build_panel(theme)
	_build_slider(theme)
	_build_scroll(theme)
	_build_variations(theme)
	return theme


## 프로젝트에 지정된 폰트. 경로를 여기 또 적으면 둘이 어긋난다.
##
## SongMyung 은 명조다 — 게임 UI 에서 드문 얼굴이고 **신문 제목의 얼굴**이다.
## 이 지면이 성립하는 이유의 절반이 폰트 하나뿐이라는 제약에서 나왔다.
static func project_font() -> Font:
	var path: String = ProjectSettings.get_setting("gui/theme/custom_font", "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Font


static func _build_label(theme: Theme) -> void:
	theme.set_color("font_color", "Label", UiTokens.INK)
	theme.set_font_size("font_size", "Label", UiTokens.TYPE_BODY)


## 버튼은 **활자 한 조각**이다.
##
## 평상시에는 종이 위에 괘선으로 갇혀 있고, 손이 올라가면 별색판이 먼저 어긋나 나타나고,
## 누르면 통째로 먹이 먹는다. 얇은 테두리를 두른 회색 사각형은 쓰지 않는다 —
## 어느 게임에나 있고, 그래서 이 게임의 것이 아니다.
static func _build_button(theme: Theme) -> void:
	var heavy := int(UiTokens.RULE_HEAVY)
	var text := int(UiTokens.RULE_TEXT)
	var normal := UiStyleBox.ruled(UiTokens.PAPER_HIGH, UiTokens.INK, 0, heavy, text, 0)
	var hover := UiStyleBox.ruled(UiTokens.PAPER_HIGH, UiTokens.SPOT, 0, heavy, text, 0)
	var pressed := UiStyleBox.flat(UiTokens.INK)
	var disabled := UiStyleBox.ruled(
		UiTokens.fade(UiTokens.PAPER_SHADE, 0.5), UiTokens.INK_FAINT, 0, text, 0, 0
	)
	var focus := UiStyleBox.boxed(Color(0.0, 0.0, 0.0, 0.0), UiTokens.SPOT, 1)
	for entry in [normal, hover, pressed, disabled, focus]:
		UiStyleBox.pad(entry as StyleBox, UiTokens.SPACE_STEP, UiTokens.SPACE_SNUG)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_color("font_color", "Button", UiTokens.INK)
	theme.set_color("font_hover_color", "Button", UiTokens.SPOT)
	theme.set_color("font_pressed_color", "Button", UiTokens.PAPER_HIGH)
	theme.set_color("font_focus_color", "Button", UiTokens.INK)
	theme.set_color("font_disabled_color", "Button", UiTokens.INK_FAINT)
	theme.set_font_size("font_size", "Button", UiTokens.TYPE_LABEL)


## 지면의 박스 기사. 위에 굵은 괘선, 아래에 가는 괘선.
static func _build_panel(theme: Theme) -> void:
	var panel := UiStyleBox.ruled(
		UiTokens.fade(UiTokens.PAPER_HIGH, 0.96),
		UiTokens.INK,
		int(UiTokens.RULE_BANNER),
		int(UiTokens.RULE_HAIR)
	)
	UiStyleBox.pad(panel, UiTokens.SPACE_STEP, UiTokens.SPACE_STEP)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)


## 슬라이더의 손잡이는 **그림 파일 없이** 만든다. 에셋을 늘리지 않는 것이 이 작업의 전제다.
static func _build_slider(theme: Theme) -> void:
	var track := UiStyleBox.flat(UiTokens.fade(UiTokens.INK, 0.18))
	track.content_margin_top = 2.0
	track.content_margin_bottom = 2.0
	var filled := UiStyleBox.flat(UiTokens.INK)
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)
	theme.set_icon("grabber", "HSlider", _slug_texture(UiTokens.INK))
	theme.set_icon("grabber_highlight", "HSlider", _slug_texture(UiTokens.SPOT))
	theme.set_icon("grabber_disabled", "HSlider", _slug_texture(UiTokens.INK_FAINT))


static func _build_scroll(theme: Theme) -> void:
	theme.set_stylebox("panel", "ScrollContainer", UiStyleBox.hollow())
	for type in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", type, UiStyleBox.flat(UiTokens.fade(UiTokens.INK, 0.12)))
		theme.set_stylebox("grabber", type, UiStyleBox.flat(UiTokens.INK_FAINT))
		theme.set_stylebox("grabber_highlight", type, UiStyleBox.flat(UiTokens.INK_MUTED))
		theme.set_stylebox("grabber_pressed", type, UiStyleBox.flat(UiTokens.SPOT))


## 글자의 위계. 크기와 판(먹인가 별색인가)이 짝으로 정해져 있다.
static func _build_variations(theme: Theme) -> void:
	_variation(theme, BANNER, "Label", UiTokens.TYPE_BANNER, UiTokens.INK)
	_variation(theme, DECK, "Label", UiTokens.TYPE_DECK, UiTokens.INK)
	_variation(theme, HEAD, "Label", UiTokens.TYPE_HEAD, UiTokens.INK)
	_variation(theme, SUB, "Label", UiTokens.TYPE_SUB, UiTokens.INK)
	_variation(theme, CAPTION, "Label", UiTokens.TYPE_LABEL, UiTokens.INK_MUTED)
	_variation(theme, MICRO, "Label", UiTokens.TYPE_MICRO, UiTokens.INK_MUTED)
	# 별색판. 먹판과 절대 섞이지 않는다 — 이 색이 붙은 글자는 못 믿는 글자다.
	_variation(theme, SPOT_HEAD, "Label", UiTokens.TYPE_HEAD, UiTokens.SPOT)
	_variation(theme, HYPE, "Label", UiTokens.TYPE_BODY, UiTokens.SPOT)

	# 방 타일은 전부 직접 그린다. 기본 버튼 그리기를 통째로 비운다.
	theme.set_type_variation(ROOM_TILE, "Button")
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		theme.set_stylebox(state, ROOM_TILE, UiStyleBox.hollow())

	# 교정쇄는 아직 인쇄기에 걸리지 않은 지면이다. 별색이 없고 제호도 없다.
	theme.set_type_variation(PROOF_PANEL, "PanelContainer")
	var proof := UiStyleBox.ruled(
		UiTokens.fade(UiTokens.PAPER_SHADE, 0.97), UiTokens.INK, 0, 0, int(UiTokens.RULE_HEAVY)
	)
	UiStyleBox.pad(proof, UiTokens.SPACE_GAP, UiTokens.SPACE_STEP)
	theme.set_stylebox("panel", PROOF_PANEL, proof)


static func _variation(theme: Theme, name: String, base: String, size: int, color: Color) -> void:
	theme.set_type_variation(name, base)
	theme.set_font_size("font_size", name, size)
	theme.set_color("font_color", name, color)


## 슬라이더 손잡이를 **활자 조각**으로 찍는다. 모서리를 굴리지도 자르지도 않는다.
##
## 이미지 파일을 추가하지 않겠다는 제약이 여기서는 오히려 이득이다 —
## 색을 바꾸려고 파일을 다시 그릴 일이 없다.
static func _slug_texture(color: Color) -> ImageTexture:
	var width := 11
	var height := 22
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(color)
	# 위아래에 종이색 홈을 하나씩 판다. 활자 옆면의 자리표시(닉)다.
	for x in width:
		image.set_pixel(x, height / 2, UiTokens.PAPER_HIGH)
	return ImageTexture.create_from_image(image)
