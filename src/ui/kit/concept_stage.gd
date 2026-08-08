class_name ConceptStage
extends Control
## 컨셉 견본 무대. **버튼만 있다.** 모든 컨셉이 같은 배치·같은 글자를 쓴다.
##
## 무대가 **대본**을 갖고 있는 이유: 「톡톡 튀는가」는 정지 화면으로 판단할 수 없고,
## GIF 를 만들려면 idle · 올림 · 눌림이 **정해진 시각에** 일어나야 한다.
## 사람이 직접 만질 때는 대본을 끄면 (`S`) 그냥 버튼이 된다.

const LABELS := ["탐사 개시", "보급", "설정"]

## 대본 한 바퀴. 이 길이가 곧 GIF 한 바퀴다.
const LOOP: float = 3.2

var _plates: Array[ConceptPlate] = []
var _guide: Label
var _time: float = 0.0
var _scripted: bool = true
var _concept: ConceptPlate.Concept = ConceptPlate.Concept.SLAM
var _guide_wanted: bool = true


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_plates()
	_build_guide()


func _process(delta: float) -> void:
	_time += delta
	if _scripted:
		_run_script()


## 무대 시계를 대본으로 읽는다.
##
##   0.00~0.70  idle — 아무도 안 건드린다
##   0.70       커서가 닿는다
##   1.60       누른다
##   1.85       뗀다
##   2.50       커서가 떠난다
##   ~3.20      다시 idle
##
## 판 하나만 대본을 받는다. 나머지는 idle 로 남아 **가만히 있을 때도 죽지 않았는지**를
## 같은 그림 안에서 보여 준다.
func _run_script() -> void:
	if _plates.is_empty():
		return
	var t := fposmod(_time, LOOP)
	var hover := 1.0 if (t >= 0.70 and t < 2.50) else 0.0
	var press := 1.0 if (t >= 1.60 and t < 1.85) else 0.0
	_plates[0].scripted_hover = hover
	_plates[0].scripted_press = press


## 컨셉을 갈아 끼운다. 배치와 글자는 그대로 두고 **움직임만** 바뀌어야
## 넷을 나란히 놓았을 때 무엇 때문에 달라 보이는지 알 수 있다.
func set_concept(name: String) -> void:
	match name.to_lower():
		"shear":
			_concept = ConceptPlate.Concept.SHEAR
		"hold":
			_concept = ConceptPlate.Concept.HOLD
		_:
			_concept = ConceptPlate.Concept.SLAM
	# 판이 아직 없을 수 있다 (위 설명 참고). 그때는 `_build_plates()` 가 집어 간다.
	for plate in _plates:
		plate.concept = _concept
	if _guide != null:
		_guide.text = _guide_text()


func stage_time() -> float:
	return _time


## 캡처가 안내 글자를 끈다. 조작 안내가 그림에 남으면 조형이 아니라 스크린샷을 보게 된다.
##
## **`_ready()` 보다 먼저 불릴 수 있다.** SceneTree 스크립트의 `_initialize()` 안에서
## `add_child()` 해도 `_ready()` 는 그 자리에서 돌지 않는다 — 실제로 이걸 몰라서
## 컨셉 전환이 통째로 먹히지 않았고 안내 글자가 캡처에 남았다.
## 그래서 뜻만 받아 두고 실제 적용은 `_ready()` 가 한다.
func set_guide_visible(shown: bool) -> void:
	_guide_wanted = shown
	if _guide != null:
		_guide.visible = shown


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	match (event as InputEventKey).keycode:
		KEY_1:
			set_concept("slam")
		KEY_2:
			set_concept("shear")
		KEY_3:
			set_concept("hold")
		KEY_S:
			_set_scripted(not _scripted)
		KEY_H:
			_guide.visible = not _guide.visible
		KEY_ESCAPE:
			get_tree().quit()


func _set_scripted(on: bool) -> void:
	_scripted = on
	for plate in _plates:
		plate.scripted_hover = -1.0
		plate.scripted_press = -1.0
	_guide.text = _guide_text()


func _build_background() -> void:
	var back := ColorRect.new()
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.color = Color(0.086, 0.086, 0.094)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)


func _build_plates() -> void:
	var at := Vector2(300.0, 210.0)
	for i in range(LABELS.size()):
		var plate := ConceptPlate.new()
		plate.text = LABELS[i]
		plate.font_size = 22 if i == 0 else 18
		plate.concept = _concept
		plate.position = at + Vector2(float(i) * 34.0, float(i) * 104.0)
		plate.size = Vector2(300.0 if i == 0 else 236.0, 68.0 if i == 0 else 56.0)
		add_child(plate)
		_plates.append(plate)


func _build_guide() -> void:
	_guide = Label.new()
	var variation := FontVariation.new()
	variation.base_font = ConceptPlate.FONT
	_guide.add_theme_font_override("font", variation)
	_guide.add_theme_font_size_override("font_size", 13)
	_guide.add_theme_color_override("font_color", Color(0.62, 0.62, 0.60))
	_guide.position = Vector2(28.0, 668.0)
	_guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide.text = _guide_text()
	_guide.visible = _guide_wanted
	add_child(_guide)


## 지금 어느 컨셉을 보고 있는지 화면에 박아 둔다. 넷을 키로 넘기며 견주다 보면
## 몇 번째를 보고 있는지 금방 잃어버린다.
func _guide_text() -> String:
	var mode := "대본 켬" if _scripted else "대본 끔 (직접 조작)"
	return "[%s]   1 SLAM  2 SHEAR  3 HOLD   S %s   H 안내 숨김   Esc 닫기" % [_concept_name(), mode]


func _concept_name() -> String:
	match _concept:
		ConceptPlate.Concept.SHEAR:
			return "SHEAR 베여서 어긋난다"
		ConceptPlate.Concept.HOLD:
			return "HOLD 시간이 끊긴다"
		_:
			return "SLAM 들이받는다"
