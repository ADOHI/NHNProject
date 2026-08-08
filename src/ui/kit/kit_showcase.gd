extends Control
## 키트 확인용 화면. **버튼과 팝업만 있다.**
##
## 게임 화면이 아니다. 방도 위험도도 나오지 않는다. 여기서 보려는 것은 셋뿐이다.
##   급(規格)  고도 1·2·3 단이 만드는 세 가지 크기
##   사이      붙은 둘과 떨어진 둘이 지형에서 어떻게 달라지는가
##   상태      평상 · 호버 · 눌림 · 포커스 · 비활성
##
## 세 무리를 **한 줄씩 쌓아 놓지 않는다.** 나란한 세 줄과 회색 소제목은 디자인
## 시스템 명세서의 생김새이지 지형의 생김새가 아니다. 장 위에 흩어진 봉우리로 둔다.

## 무리마다 다른 자리. 규격표가 아니라 지형으로 읽히게 하는 유일한 장치다.
const _SPOT_SIZES := Vector2(360.0, 150.0)
const _SPOT_GAPS := Vector2(880.0, 330.0)
const _SPOT_STATES := Vector2(600.0, 552.0)

var _state_row: Array[KitButton] = []
var _all_buttons: Array[KitButton] = []
var _popup: KitPopup

@onready var _stage: Control = %Stage
@onready var _field: KitField = %Field


func _ready() -> void:
	_build_size_group()
	_build_gap_group()
	_build_state_group()
	_build_popup()
	apply_scenario("rest")


## 조형 방향을 갈아 끼운다. **요소는 그대로 두고 그리는 법만 바꾼다.**
## 세 방향을 견주려면 같은 배치·같은 상태 위에서 비교해야 한다.
func apply_variant(name: String) -> void:
	match name:
		"facet":
			_field.set_variant(KitField.Variant.FACET)
			_set_label_color(KitTokens.TEXT)
		"grain":
			_field.set_variant(KitField.Variant.GRAIN)
			# 알갱이가 뭉쳐 밝은 판이 되므로 글자는 **파낸 자국**이어야 읽힌다.
			_set_label_color(KitTokens.GROUND)
		_:
			_field.set_variant(KitField.Variant.TERRAIN)
			_set_label_color(KitTokens.TEXT)


func _set_label_color(color: Color) -> void:
	for button in _all_buttons:
		button.add_theme_color_override("font_color", color)
		button.add_theme_color_override("font_hover_color", color)
		button.add_theme_color_override("font_focus_color", color)


## 캡처 도구가 부르는 진입점. 화면을 특정 상황으로 몰아넣는다.
func apply_scenario(name: String) -> void:
	if _popup == null:
		return
	match name:
		"popup":
			_popup.visible = true
			_popup.open_focus()
		"rest", _:
			_popup.visible = false
			if _state_row.size() > 3:
				_state_row[3].grab_focus()


## 고도 1·2·3 단. 크기가 임의로 정해진 세 개가 아니라 고도에서 유도된 세 개임을 보인다.
## 서로 떨어뜨린다 — 급을 견주려면 각자 닫힌 고리를 가져야 한다.
func _build_size_group() -> void:
	var plan: Array = [
		["보조", KitTokens.ELEVATION_SUB, KitTokens.GAP_APART],
		["주 행동", KitTokens.ELEVATION_MAIN, KitTokens.GAP_APART],
		["결단", KitTokens.ELEVATION_KEY, 0.0],
	]
	_lay_group(plan, _SPOT_SIZES)


## 왼쪽 둘은 붙이고 오른쪽 둘은 떼어 놓는다.
## **대조가 없으면 아무것도 증명되지 않는다** — 붙은 예만 둘 있으면 그냥 붙은 것이다.
func _build_gap_group() -> void:
	var plan: Array = [
		["잇기", KitTokens.ELEVATION_MAIN, KitTokens.GAP_JOINED],
		["끊기", KitTokens.ELEVATION_MAIN, KitTokens.GAP_APART * 2.4],
		["담기", KitTokens.ELEVATION_MAIN, KitTokens.GAP_APART],
		["버리기", KitTokens.ELEVATION_MAIN, 0.0],
	]
	_lay_group(plan, _SPOT_GAPS)


## 다섯 상태를 나란히 둔다. 정지 화면 한 장으로 상태 전부를 견줄 수 있어야 한다.
func _build_state_group() -> void:
	var plan: Array = [
		["평상", KitTokens.ELEVATION_MAIN, KitTokens.GAP_GROUPED],
		["닿음", KitTokens.ELEVATION_MAIN, KitTokens.GAP_GROUPED],
		["누름", KitTokens.ELEVATION_MAIN, KitTokens.GAP_GROUPED],
		["겨눔", KitTokens.ELEVATION_MAIN, KitTokens.GAP_GROUPED],
		["잠김", KitTokens.ELEVATION_MAIN, 0.0],
	]
	_state_row = _lay_group(plan, _SPOT_STATES)
	_state_row[1].mouse_entered.emit()
	_state_row[2].mouse_entered.emit()
	_state_row[2].button_down.emit()
	_state_row[4].disabled = true


## 한 무리를 주어진 중심에 놓는다. 간격은 계획표에 적힌 값 그대로 — 균등 분배하지 않는다.
## 간격 자체가 이 키트의 규칙이므로 자동 배치에 맡기면 규칙이 보이지 않는다.
func _lay_group(plan: Array, center: Vector2) -> Array[KitButton]:
	var buttons: Array[KitButton] = []
	var total := 0.0
	for entry in plan:
		var button := _make_button(entry[0] as String, entry[1] as float)
		buttons.append(button)
		total += button.size.x + (entry[2] as float)
	var x := center.x - total * 0.5
	for i in buttons.size():
		var button := buttons[i]
		# 한 줄에 자로 잰 듯 늘어놓으면 명세서가 된다. 무리 안에서도 높이를 어긋내
		# 지형의 등고선을 따라 앉은 것처럼 보이게 한다.
		var drift := sin(float(i) * 1.9 + center.x * 0.011) * KitTokens.UNIT * 1.5
		button.position = Vector2(x, center.y - button.size.y * 0.5 + drift)
		x += button.size.x + (plan[i][2] as float)
	return buttons


func _build_popup() -> void:
	_popup = KitPopup.new()
	_popup.title_text = "되돌릴 수 없다"
	_popup.body_text = "여기서 물러나면 지금까지의 자취는 남지 않는다."
	_popup.visible = false
	_stage.add_child(_popup)


func _make_button(label: String, elevation: float) -> KitButton:
	var button := KitButton.new()
	button.elevation = elevation
	button.text = label
	_stage.add_child(button)
	button.fit_to_text()
	_all_buttons.append(button)
	return button
