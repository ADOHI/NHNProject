class_name UiStyleBox
extends RefCounted
## StyleBox 를 코드로 찍어 낸다. 에디터에서 손으로 만든 .tres 를 두지 않기 위한 공장이다.
##
## **이 화면에는 둥근 모서리가 없다. 잘린 모서리도 없다.**
## 인쇄물의 형태는 굴리거나 자르는 것이 아니라 **괘선으로 갇히거나 찢겨 나오는 것**이다
## (docs/design/18-visual-identity.md §18.4).
##
## 그래서 여기서 만드는 StyleBox 는 전부 corner_radius 가 0 이고,
## 위계는 **테두리의 굵기와 어느 변에 있는가**로만 만든다.


## 괘선으로 갇힌 면. 사방을 같은 굵기로 두르지 않는다 — 굵은 변이 어디인지가 곧 위계다.
static func ruled(
	fill: Color, rule: Color, top: int = 0, bottom: int = 0, left: int = 0, right: int = 0
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.corner_detail = 1
	box.set_corner_radius_all(0)
	box.border_color = rule
	box.border_width_top = top
	box.border_width_bottom = bottom
	box.border_width_left = left
	box.border_width_right = right
	return box


## 사방을 같은 굵기로 두른 상자. 도해의 사진 테두리처럼 **가둔다**는 뜻이 필요할 때만 쓴다.
static func boxed(fill: Color, rule: Color, weight: int) -> StyleBoxFlat:
	return ruled(fill, rule, weight, weight, weight, weight)


## 테두리 없는 면. 별색판을 얹거나 직접 그릴 때 바탕으로 쓴다.
static func flat(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.corner_detail = 1
	box.set_corner_radius_all(0)
	return box


## 안쪽 여백을 준다. 가로와 세로를 따로 받는 이유는 명조의 줄높이 때문에
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
