class_name UiStyleBox
extends RefCounted
## StyleBox 를 코드로 찍어 낸다. 에디터에서 손으로 만든 .tres 를 두지 않기 위한 공장이다.
##
## **잘린 모서리를 StyleBoxFlat 으로 내는 방법이 하나 있다.**
## corner_radius 를 준 뒤 corner_detail 을 1 로 내리면, 곡선을 만들 분할이 하나뿐이라
## 원호가 직선 한 토막이 된다 — 즉 챔퍼가 된다.
## 그래서 둥근 모서리를 쓰지 않으면서도 Godot 기본 위젯(Button, Slider)의
## 그리기 경로를 그대로 쓸 수 있다. 위젯마다 _draw 를 새로 짤 필요가 없다.


## 잘린 모서리를 가진 면. cuts 는 [좌상, 우상, 우하, 좌하] 순서다.
static func plate(
	fill: Color,
	cuts: PackedFloat32Array,
	border: Color = Color(0.0, 0.0, 0.0, 0.0),
	border_width: int = 0
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	# 1 이면 원호가 직선 한 토막이 된다. 이 한 줄이 이 프로젝트의 모서리 규칙 전부다.
	box.corner_detail = 1
	box.corner_radius_top_left = int(cuts[0])
	box.corner_radius_top_right = int(cuts[1])
	box.corner_radius_bottom_right = int(cuts[2])
	box.corner_radius_bottom_left = int(cuts[3])
	if border_width > 0:
		box.set_border_width_all(border_width)
		box.border_color = border
	return box


## 안쪽 여백을 준다. 가로와 세로를 따로 받는 이유는 글자 줄높이 때문에
## 세로를 늘 좁게 잡아야 균형이 맞기 때문이다.
static func pad(box: StyleBox, horizontal: int, vertical: int) -> StyleBox:
	box.content_margin_left = float(horizontal)
	box.content_margin_right = float(horizontal)
	box.content_margin_top = float(vertical)
	box.content_margin_bottom = float(vertical)
	return box


## 그리지 않고 자리만 차지하는 면. 직접 그리는 위젯(방 타일 등)에 물린다.
static func hollow(horizontal: int = 0, vertical: int = 0) -> StyleBoxEmpty:
	var box := StyleBoxEmpty.new()
	box.content_margin_left = float(horizontal)
	box.content_margin_right = float(horizontal)
	box.content_margin_top = float(vertical)
	box.content_margin_bottom = float(vertical)
	return box


## 한쪽 변에만 굵은 선을 둔 면. 계측 장비의 옆면 표시다.
##
## 네 변을 두르지 않는 이유는, 얇은 흰 테두리를 두른 회색 패널이야말로
## 어느 게임에 붙여도 말이 되는 형태이기 때문이다 (docs/design/18-visual-identity.md §18.4).
static func edge_rule(fill: Color, rule: Color, width: int, left: bool = true) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = rule
	if left:
		box.border_width_left = width
	else:
		box.border_width_top = width
	return box
