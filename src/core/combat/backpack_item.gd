class_name BackpackItem
extends RefCounted
## 백팩에 들어가는 물건 하나. **여러 칸을 차지하고, 그중 한 칸이 출력 방향을 가진다.**
##
## `docs/design/28-combat.md` §28.2 · §28.20.2 를 그대로 옮긴 것이다.
##
## ## 출력이 없는 아이템이 있다
##
## 전리품이 그렇다. 칸은 먹는데 다음으로 넘길 곳이 없어서 **체인이 거기서 끝난다.**
## 이것이 §28.3 의 칸 압박이 규칙 없이 성립하는 자리다 —
## 루팅한 물건을 콤보 루트 위에 놓으면 그 배치가 스스로 약해진다.
##
## ## 아이템은 불변이다
##
## 회전은 이 자리에서 값을 고치지 않고 **새 아이템을 만들어 돌려준다**(`rotated`).
## 같은 아이템이 격자와 대기줄 양쪽에서 참조될 수 있으므로, 한쪽에서 돌렸더니
## 다른 쪽이 같이 도는 사고를 구조로 막는다.

enum Kind {
	WEAPON,  ## 출력 블럭을 가진다. 체인을 이어 간다
	LOOT,  ## 출력이 없다. 칸만 먹고 체인을 끊는다
}

var id: String
var display_name: String
var kind: Kind

## 원점 기준 오프셋 목록. **_init 에서 좌상단이 (0, 0) 이 되도록 정규화된다.**
## 그래서 밖에서 넘긴 좌표가 그대로 남아 있지 않을 수 있다 (`output_cell` 도 같이 옮겨진다).
var shape: Array[Vector2i]

## `shape` 의 원소 중 하나. 출력이 없으면(`Kind.LOOT`) 의미가 없다.
var output_cell: Vector2i

var output_direction: ChainDirection.Kind


func _init(
	p_id: String,
	p_display_name: String,
	p_kind: Kind,
	p_shape: Array[Vector2i],
	p_output_cell: Vector2i = Vector2i.ZERO,
	p_output_direction: ChainDirection.Kind = ChainDirection.Kind.NONE
) -> void:
	assert(not p_shape.is_empty(), "아이템은 최소 한 칸을 차지한다: %s" % p_id)
	id = p_id
	display_name = p_display_name
	kind = p_kind
	output_direction = p_output_direction

	var offset := _top_left(p_shape)
	shape = []
	for cell in p_shape:
		shape.append(cell - offset)
	output_cell = p_output_cell - offset

	assert(
		output_direction == ChainDirection.Kind.NONE or shape.has(output_cell),
		"출력 블럭은 아이템이 차지한 칸이어야 한다: %s" % p_id
	)


## 체인을 이어 갈 수 있는가. 출력이 없으면 여기서 끝난다.
func has_output() -> bool:
	return output_direction != ChainDirection.Kind.NONE


## 격자 위 `origin` 에 놓였을 때 실제로 차지하는 칸들.
func cells_at(origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in shape:
		result.append(origin + cell)
	return result


## 격자 위 `origin` 에 놓였을 때 출력 블럭이 있는 칸.
func output_cell_at(origin: Vector2i) -> Vector2i:
	return origin + output_cell


## 출력 블럭에서 **한 칸 딛은** 자리. 체인이 다음 아이템을 찾는 곳이다.
##
## 「그 방향으로 쭉 훑기」가 아니라 「한 칸」인 이유는 §28.20.4 에 있다.
func output_target_at(origin: Vector2i) -> Vector2i:
	return output_cell_at(origin) + ChainDirection.to_vector(output_direction)


## 감싸는 상자의 크기. 대기줄에 그릴 때 쓴다.
func bounds_size() -> Vector2i:
	var max_cell := shape[0]
	for cell in shape:
		max_cell = Vector2i(maxi(max_cell.x, cell.x), maxi(max_cell.y, cell.y))
	return max_cell + Vector2i.ONE


## 시계 방향으로 90도 돌린 **새 아이템**.
##
## 모양 · 출력 블럭 · 출력 방향이 **함께** 돈다. 셋 중 하나라도 빠지면
## 돌린 무기가 엉뚱한 데를 가리킨다.
##
## **회전을 게임에서 허용할지는 미정이다** (§28.20.8). 확인 화면이 루트를 여러 개
## 시험해 보려고 쓰는 것이지 규칙이 정해진 것이 아니다.
func rotated() -> BackpackItem:
	var turned: Array[Vector2i] = []
	for cell in shape:
		turned.append(ChainDirection.rotate_cell_cw(cell))
	return BackpackItem.new(
		id,
		display_name,
		kind,
		turned,
		ChainDirection.rotate_cell_cw(output_cell),
		ChainDirection.rotated_cw(output_direction)
	)


## 이 아이템을 `rotated()` 로 돌렸을 때 **모양 안의 한 칸이 어디로 가는가.**
##
## 회전은 정규화를 포함하므로 `ChainDirection.rotate_cell_cw` 만 써서는 어긋난다.
## 화면이 아이템을 집은 지점을 회전 뒤에도 손가락 밑에 두려면 이 변환이 필요하다.
##
## **회전 규칙을 화면에 두 번째로 적지 않으려고** 여기에 둔다 — 두 곳에 적으면
## 한쪽만 고쳤을 때 조용히 어긋난다.
func rotate_offset(offset: Vector2i) -> Vector2i:
	var turned: Array[Vector2i] = []
	for cell in shape:
		turned.append(ChainDirection.rotate_cell_cw(cell))
	return ChainDirection.rotate_cell_cw(offset) - _top_left(turned)


static func _top_left(cells: Array[Vector2i]) -> Vector2i:
	var result := cells[0]
	for cell in cells:
		result = Vector2i(mini(result.x, cell.x), mini(result.y, cell.y))
	return result
