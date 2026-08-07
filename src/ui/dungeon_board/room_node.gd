class_name RoomNode
extends Button
## 판 위의 방 하나를 나타내는 위젯.
##
## 이 위젯은 판을 모른다. 무엇을 표시할지는 DungeonBoard 가 정해서 넘긴다.
## 위젯이 스스로 판을 조회하기 시작하면 "무엇이 보이는가"라는 규칙이
## 화면 곳곳으로 흩어진다. 이 게임에서 그 규칙은 재미 그 자체다.
##
## 방이 보여 주는 것은 두 가지이고 성격이 다르다.
##
##   위험도 — **숨겨진 정보.** 내가 선 방에서만, 그것도 인접한 것들의 합만 보인다
##   고도   — **드러난 정보.** 지형은 숨길 이유가 없다
##
## 숨겨야 하는 것은 "방 안에 뭐가 있나"이지 "저기가 얼마나 높나"가 아니다.
## 고도가 늘 보여야 "민첩이 얼마 더 있으면 저기 간다"는 계획이 선다
## (docs/design/07-level-design.md §7.2.6).

## 이 방이 눌렸다. 이동 가능 여부 판단은 상위가 한다.
signal room_selected(room_id: String)

## 얼마나 자세히 보여 줄지. 확대 배율에 따라 상위가 정한다.
##
## 축소하면 글자가 같이 작아져 못 읽게 된다. 그때는 **읽히지 않을 글자를 지우는 편이**
## 남겨 두는 것보다 낫다. 작게 뭉갠 글자는 정보가 아니라 잡음이다.
enum Detail {
	MINIMAL,  ## 숫자만. 판의 모양과 색만 읽는 배율
	NORMAL,  ## 이름 + 숫자
	FULL,  ## 이름 + 숫자 + 고도
}

## 방의 표시 상태. 무엇을 보여 줄지가 여기서 갈린다.
enum State {
	CURRENT,  ## 플레이어가 서 있는 방 — 인접 위험도 합을 보여 준다
	REACHABLE,  ## 지금 갈 수 있는 방 — 안은 모른다
	BLOCKED,  ## 인접하지만 민첩이 모자라 못 오르는 방
	DISTANT,  ## 인접하지 않은 방 — 안은 모른다
}

const _COLOR_CURRENT := Color(0.98, 0.86, 0.42)
const _COLOR_REACHABLE := Color(0.86, 0.90, 0.96)
const _COLOR_BLOCKED := Color(0.85, 0.52, 0.50)
const _COLOR_DISTANT := Color(0.45, 0.48, 0.55)

## 고도 표시는 위험도보다 한 단계 죽인다. 늘 보이는 정보라
## 위험도 숫자만큼 눈에 띄면 판이 시끄러워진다.
const _COLOR_CLIMB := Color(0.55, 0.60, 0.70)
const _COLOR_CLIMB_BLOCKED := Color(0.88, 0.55, 0.45)

var room_id: String

@onready var _name_label: Label = %NameLabel
@onready var _value_label: Label = %ValueLabel
@onready var _climb_label: Label = %ClimbLabel


func _ready() -> void:
	pressed.connect(func() -> void: room_selected.emit(room_id))


## 표시 내용을 통째로 갱신한다.
##
## value_text 와 climb_text 를 상위에서 받는 이유는, 방이 자기 상태를 아는 것과
## 플레이어가 그것을 보는 것이 전혀 다른 문제이기 때문이다.
func display(
	id: String,
	display_name: String,
	value_text: String,
	state: State,
	climb_text: String = "",
	detail: Detail = Detail.FULL
) -> void:
	room_id = id
	_name_label.text = display_name
	_value_label.text = value_text
	_climb_label.text = climb_text
	_name_label.visible = detail != Detail.MINIMAL
	_climb_label.visible = detail == Detail.FULL and not climb_text.is_empty()

	# 막힌 방도 누를 수 없다. 다만 색과 값으로 "길은 있으나 못 오른다"를 구분해 보여 준다.
	disabled = state != State.CURRENT and state != State.REACHABLE
	match state:
		State.CURRENT:
			_apply_color(_COLOR_CURRENT, _COLOR_CLIMB)
		State.REACHABLE:
			_apply_color(_COLOR_REACHABLE, _COLOR_CLIMB)
		State.BLOCKED:
			_apply_color(_COLOR_BLOCKED, _COLOR_CLIMB_BLOCKED)
		State.DISTANT:
			_apply_color(_COLOR_DISTANT, _COLOR_CLIMB)


func _apply_color(color: Color, climb_color: Color) -> void:
	_name_label.add_theme_color_override("font_color", color)
	_value_label.add_theme_color_override("font_color", color)
	_climb_label.add_theme_color_override("font_color", climb_color)
