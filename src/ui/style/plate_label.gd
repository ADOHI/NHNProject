class_name PlateLabel
extends Control
## **두 판으로 찍힌 글자.** 이 화면의 서명을 부품으로 만든 것이다.
##
## 같은 글자를 두 번 찍는다 — 별색판이 어긋난 자리에 먼저 놓이고, 먹판이 제자리에 놓인다.
##
##   slip_amount 0    사실이다. 두 판이 정확히 겹쳐 어긋남이 보이지 않는다
##   slip_amount 1    렉카가 옮긴 말이다. 눈에 띄게 어긋난다
##   slip_amount 2.6  제목이다. 가장 크게 부풀린 자리다
##
## **어긋난 크기가 곧 부풀린 크기다** (docs/design/13-information-design.md §13.3).
## 플레이어는 문장을 읽기 전에 어긋남의 크기로 신뢰도를 안다.
##
## 값이 바뀌면 별색판이 크게 튀어 나갔다가 되튀어 돌아온다 (UiMotion.misprint).
## 이 게임에서 가장 중요한 사건이 "숫자가 바뀌었다"이므로,
## 서명이 가장 크게 드러나는 순간도 거기여야 한다.
##
## 라벨을 두 장 겹치는 대신 셰이더로 처리하지 않는 이유는, 글자는 폰트 렌더러가 그리고
## 그 결과를 셰이더에서 두 번 뽑을 수 없기 때문이다. 노드 두 장이 가장 싸다.

## 어느 판으로 찍힌 글자인가. 먹판이 사실이고 별색판이 이야기다.
enum Plate {
	INK,  ## 시설이 잰 값 • 방 이름 • 고도
	SPOT,  ## 렉카가 붙인 제목 • 논평 • 화제성
}

@export var text: String = "":
	set = set_text

## 먹판 글자에 물릴 Theme 변형 이름. 크기와 색이 거기서 나온다.
@export var variation: String = UiTheme.HEAD:
	set = set_variation

@export var plate: Plate = Plate.INK

## 두 판이 어긋난 정도. UiTokens.SLIP 에 곱해진다.
@export var slip_amount: float = UiTokens.SLIP_STORY

## 정합이 미세하게 떠다닌다. **인쇄기는 멈추지 않는다.**
## 매 프레임 자리를 다시 잡으므로 화면에서 몇 개만 켠다.
@export var drift: bool = false

var _ghost: Label
var _ink: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost = _make_label(_ghost_color())
	_ink = _make_label(Color(1.0, 1.0, 1.0, 1.0))
	_ink.theme_type_variation = variation
	_apply_text()
	set_process(drift)


func _process(_delta: float) -> void:
	if _ghost == null:
		return
	_ghost.position = _home() + UiMotion.register_drift(0.5 + slip_amount)


func set_text(value: String) -> void:
	var changed := value != text
	text = value
	if _ink == null:
		return
	_apply_text()
	if changed:
		_reprint()


func set_variation(value: String) -> void:
	variation = value
	if _ink != null:
		_ink.theme_type_variation = value
		_apply_text()


## 값을 바꾸지 않고 다시 찍는다. 화면 전환이나 등장에서 쓴다.
func reprint() -> void:
	_reprint()


func _reprint() -> void:
	# 별색판이 크게 튀어 나갔다 돌아오고, 먹판은 비뚤게 앉았다가 바로잡힌다.
	UiMotion.misprint(_ghost, _home(), maxf(slip_amount, 0.35))
	UiMotion.slam(_ink, 2.6 + slip_amount * 1.4)


func _make_label(color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate = color
	add_child(label)
	return label


## 별색판이 앉는 자리. 먹판은 늘 원점이고 별색판만 어긋난다.
func _home() -> Vector2:
	return UiTokens.slip(slip_amount)


func _ghost_color() -> Color:
	return Color(1.0, 1.0, 1.0, 1.0) if plate == Plate.SPOT else UiTokens.fade(Color.WHITE, 0.9)


## 두 라벨을 같은 글자•같은 크기로 맞추고, 색만 판에 따라 가른다.
##
## 별색판 글자를 먹판보다 조금 흐리게 두는 이유는, 실제 인쇄에서 두 번째 판이
## 종이에 덜 먹기 때문이다. 같은 농도로 찍으면 어긋남이 아니라 겹글자로 보인다.
func _apply_text() -> void:
	var ink_color := UiTokens.SPOT if plate == Plate.SPOT else UiTokens.INK
	var ghost_color := UiTokens.INK if plate == Plate.SPOT else UiTokens.SPOT
	for label in [_ghost, _ink]:
		(label as Label).text = text
		(label as Label).theme_type_variation = variation
	_ink.add_theme_color_override("font_color", ink_color)
	_ghost.add_theme_color_override("font_color", UiTokens.fade(ghost_color, 0.85))
	_ghost.position = _home()
	custom_minimum_size = _ink.get_combined_minimum_size()
	_ink.size = custom_minimum_size
	_ghost.size = custom_minimum_size
