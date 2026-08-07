class_name RoomNode
extends Button
## 판 위의 방 하나를 나타내는 위젯.
##
## 이 위젯은 판을 모른다. 무엇을 표시할지는 DungeonBoard 가 정해서 넘긴다.
## 위젯이 스스로 판을 조회하기 시작하면 "무엇이 보이는가"라는 규칙이
## 화면 곳곳으로 흩어진다. 이 게임에서 그 규칙은 재미 그 자체다.

## 이 방이 눌렸다. 이동 가능 여부 판단은 상위가 한다.
signal room_selected(room_id: String)

## 방의 표시 상태. 무엇을 보여 줄지가 여기서 갈린다.
enum State {
	CURRENT,  ## 플레이어가 서 있는 방 — 인접 위험도 합을 보여 준다
	REACHABLE,  ## 갈 수 있는 방 — 안은 모른다
	DISTANT,  ## 갈 수 없는 방 — 안은 모른다
}

const _COLOR_CURRENT := Color(0.98, 0.86, 0.42)
const _COLOR_REACHABLE := Color(0.86, 0.90, 0.96)
const _COLOR_DISTANT := Color(0.45, 0.48, 0.55)

var room_id: String

@onready var _name_label: Label = %NameLabel
@onready var _value_label: Label = %ValueLabel


func _ready() -> void:
	pressed.connect(func() -> void: room_selected.emit(room_id))


## 표시 내용을 통째로 갱신한다.
##
## value_text 를 상위에서 받는 이유는, 방이 자기 위험도를 아는 것과
## 플레이어가 그것을 보는 것이 전혀 다른 문제이기 때문이다.
func display(id: String, display_name: String, value_text: String, state: State) -> void:
	room_id = id
	_name_label.text = display_name
	_value_label.text = value_text
	disabled = state == State.DISTANT
	match state:
		State.CURRENT:
			_apply_color(_COLOR_CURRENT)
		State.REACHABLE:
			_apply_color(_COLOR_REACHABLE)
		State.DISTANT:
			_apply_color(_COLOR_DISTANT)


func _apply_color(color: Color) -> void:
	_name_label.add_theme_color_override("font_color", color)
	_value_label.add_theme_color_override("font_color", color)
