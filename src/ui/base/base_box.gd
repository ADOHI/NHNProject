class_name BaseBox
extends PanelContainer
## 제목 한 줄이 붙은 사각형 하나. **이 화면의 유일한 조형이다.**
##
## 칸 하나가 곧 정보 한 덩어리다 — 길드 상태, 시설 하나, 대원 하나, 게이트 하나.
## 켜진 칸만 테두리가 밝아진다. 색을 더 쓰지 않는 이유는
## 조형이 다른 레인에서 오기 때문이다 (docs/design/22-guild-base.md §22.8).

## 칸 안에 쌓이는 줄들. 바깥에서 직접 붙여도 된다.
var body: VBoxContainer


func _init(title_text: String = "", accent: bool = false) -> void:
	var border := BaseWidgets.LINE_ON if accent else BaseWidgets.LINE
	add_theme_stylebox_override("panel", BaseWidgets.frame(border))
	body = BaseWidgets.column()
	add_child(body)
	if not title_text.is_empty():
		body.add_child(BaseWidgets.label(title_text, BaseWidgets.SIZE_HEAD))


## 한 줄 적는다.
func line(text: String, color: Color = BaseWidgets.INK) -> Label:
	var node := BaseWidgets.label(text, BaseWidgets.SIZE_BODY, color)
	body.add_child(node)
	return node
