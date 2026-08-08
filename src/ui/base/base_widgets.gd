class_name BaseWidgets
extends RefCounted
## 임시 아지트 화면이 쓰는 부품 공장. **사각형과 선과 글자뿐이다.**
##
## ## 조형을 만들지 않는 것이 이 화면의 규칙이다
##
## 다른 레인이 src/ui/kit/ 에서 버튼과 팝업의 조형을 찾고 있고, 그것이 나오면
## 여기 있는 표현은 전부 버려진다 (docs/design/22-guild-base.md §22.8).
## 그래서 값은 배치가 읽히는 최소로만 둔다.
##
## ## src/ui/style/ 의 토큰을 쓰지 않았다
##
## 그쪽은 지금 다른 레인의 작업 중이라 이름이 갈리면 이 화면이 같이 깨진다.
## **어차피 버려질 화면이 살아 있는 코드를 붙잡고 있으면 안 된다** (§22.8.5).

## 글자색. 흐린 쪽은 "지금 일하지 않는다" 를 뜻한다.
const INK := Color(0.88, 0.88, 0.86)
const INK_DIM := Color(0.50, 0.52, 0.56)

## 지금 상태가 달라졌다는 표시. 출전 중인 대원과 고른 게이트에 쓴다.
const INK_MARK := Color(0.86, 0.74, 0.40)

## 테두리. 켜진 칸만 밝다.
const LINE := Color(0.28, 0.30, 0.34)
const LINE_ON := Color(0.80, 0.70, 0.38)

## 칸 안쪽과 바탕.
const FILL := Color(0.12, 0.13, 0.16)
const BACKDROP := Color(0.07, 0.08, 0.10)

const SIZE_TITLE := 17
const SIZE_HEAD := 13
const SIZE_BODY := 12

## 칸 사이 간격과 칸 안쪽 여백.
const GAP := 4
const PAD := 7


## 사각형 하나의 테두리.
static func frame(border: Color, fill: Color = FILL) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_content_margin_all(PAD)
	return box


## 글자 하나. **줄바꿈은 켜지 않는다.**
##
## 켜 두면 줄 안에 놓인 짧은 글자가 폭을 못 받아 한 글자씩 세로로 쌓인다.
## 폭이 정해진 본문 줄만 wrap() 으로 따로 연다.
static func label(text: String, size: int = SIZE_BODY, color: Color = INK) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node


## 칸 폭에 맞춰 접히는 본문 줄. 게이트 미리보기와 기록처럼 긴 문장에 쓴다.
static func wrap(node: Label) -> Label:
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


## 버튼 하나. 포커스 테두리를 끄는 이유는 한 화면에 버튼이 스무 개 넘게 놓이기 때문이다.
static func button(text: String, enabled: bool = true) -> Button:
	var node := Button.new()
	node.text = text
	node.disabled = not enabled
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_size_override("font_size", SIZE_BODY)
	return node


static func row(separation: int = GAP) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node


static func column(separation: int = GAP) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node


## 칸을 비운다. **트리에서 먼저 떼어 낸다** — queue_free 는 이번 프레임 끝에 도는데,
## 그 사이에 새 자식을 붙이면 지워질 것들 뒤에 놓여 순서가 뒤집힌다.
static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
