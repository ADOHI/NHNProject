class_name LushInk
extends Control
## 글자와 가는 선을 **판 위에** 얹는 덮개.
##
## docs/design/20-ui-kit.md §20.27.
##
## ## 왜 따로 노드인가
##
## Godot 는 **자기를 먼저 그리고 자식을 그 위에 그린다.** 그래서 화면이 자기
## `_draw()` 에 글자를 쓰면 뒤에 붙는 판들이 그 글자를 덮는다 — 첫 판이 그랬다.
##
## 그리고 판마다 재료(ShaderMaterial)가 붙어 있으므로 **글자가 판과 같은 노드에 있으면
## 글자에도 재료가 걸린다.** 글자가 일렁이고 번지면 그건 화려한 게 아니라 안 읽히는 것이다.
##
## > **재료는 판에, 글자는 그 위 맨 앞에.**

## 무엇을 그릴지. 화면이 자기 메서드를 넘긴다.
var painter: Callable


func _init(who: Callable) -> void:
	painter = who
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if painter.is_valid():
		painter.call(self)
