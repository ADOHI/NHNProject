class_name BackpackPlacement
extends RefCounted
## 아이템 하나가 격자의 **어느 자리에** 놓였는가.
##
## 아이템 자체(`BackpackItem`)는 자기가 어디 놓였는지 모른다. 같은 무기를 두 자루
## 들고 다닐 수 있어야 하므로 「무엇인가」와 「어디인가」를 갈라 둔다.

var item: BackpackItem
var origin: Vector2i


func _init(p_item: BackpackItem, p_origin: Vector2i) -> void:
	item = p_item
	origin = p_origin


func cells() -> Array[Vector2i]:
	return item.cells_at(origin)


func output_cell() -> Vector2i:
	return item.output_cell_at(origin)


## 체인이 다음 아이템을 찾을 칸. 출력이 없으면 의미가 없다.
func output_target() -> Vector2i:
	return item.output_target_at(origin)


func has_output() -> bool:
	return item.has_output()
