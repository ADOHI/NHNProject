extends Control
## 방향 스케치를 띄우는 틀.
##
## **머릿속으로 비교하면 첫 아이디어가 이긴다.** 그래서 세 방향을 각각 실제로 렌더해서
## 눈으로 나란히 놓고 고른다. 셋은 같은 방•같은 숫자•같은 문장을 쓴다 (sketch_stage.gd).
##
##     godot --path . -s res://tools/capture_scene.gd -- a.png sketch_a
##
## 채택되지 않은 것들은 비교용 스케치로 남는다. 지우지 않는 이유는,
## 나중에 "왜 이걸 골랐나"를 물었을 때 답이 화면으로 남아 있어야 하기 때문이다.
##
## **넷 중 하나(D)는 일부러 과하게 만들었다.** 쓸 만한 것 셋을 늘어놓고 고르면
## 결국 가장 안전한 것이 뽑힌다. 끝이 어디인지 봐야 가운데가 어디인지 알 수 있다.

const DIRECTIONS := {
	"a":
	{
		"scene": "res://src/ui/style/sketch/direction_a.gd",
		"title": "방향 A — 지하 실황 : 방송 그래픽 패키지",
		"note": "서명 = 12도 기울기. 예능 자막의 문법으로 판을 덮는다",
	},
	"b":
	{
		"scene": "res://src/ui/style/sketch/direction_b.gd",
		"title": "방향 B — 호외 : 인쇄된 판",
		"note": "서명 = 오정합. 검은 판은 사실, 붉은 판은 늦게 어긋나서 찍힌다",
	},
	"c":
	{
		"scene": "res://src/ui/style/sketch/direction_c.gd",
		"title": "방향 C — 썸네일 : 화면에 직접 그은 낙서",
		"note": "서명 = 손으로 그은 획. 강조는 전부 떨리는 펜으로 온다",
	},
	"d":
	{
		"scene": "res://src/ui/style/sketch/direction_d.gd",
		"title": "방향 D — 검열 : 지면을 먹으로 덮는다 (일부러 과한 쪽)",
		"note": "서명 = 먹칠 막대. 정보는 덮이다 만 틈으로만 새어 나온다",
	},
}

## 스케치를 그리는 기준 화면. 창 크기가 달라도 같은 그림이 나와야 비교가 성립한다.
const CANVAS := Vector2(1600.0, 900.0)

var direction := "b"

var _body: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var spec: Dictionary = DIRECTIONS.get(direction, DIRECTIONS["b"])
	_body = Control.new()
	_body.set_script(load(spec["scene"] as String))
	_body.size = CANVAS
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	_add_backdrop()
	get_viewport().size_changed.connect(_fit)
	_fit()
	_add_caption(spec)


## 기준 화면을 실제 화면에 맞춰 통째로 늘린다.
## 좌표를 화면 크기에 맞춰 다시 계산하면 방향마다 배치가 미묘하게 달라져 비교가 흐려진다.
##
## 자기 size 가 아니라 뷰포트 크기를 보는 이유는, 창의 자식으로 붙은 Control 의 size 는
## _ready 시점에 아직 0 이라 그대로 쓰면 배율이 0 이 되기 때문이다.
func _fit() -> void:
	if _body == null:
		return
	var view := get_viewport_rect().size
	if view.x < 1.0 or view.y < 1.0:
		return
	_body.scale = view / CANVAS


## 바탕면은 방향이 만들고 여기서 **본체보다 먼저** 깐다.
##
## 방향 스크립트가 스스로 자식으로 붙이면 안 된다. Control 의 자식은 부모의 _draw 보다
## 나중에 그려져서, 바탕면이 그림을 통째로 덮어 버린다. 한 번 걸린 함정이라 여기 적어 둔다.
func _add_backdrop() -> void:
	if not _body.has_method("background_material"):
		return
	var backdrop := ColorRect.new()
	backdrop.material = _body.call("background_material")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	move_child(backdrop, 0)


## 어느 스케치인지 화면에 적어 둔다. 셋을 나란히 놓고 볼 때 이름이 없으면 섞인다.
func _add_caption(spec: Dictionary) -> void:
	var font := SketchStage.font()
	var strip := Label.new()
	strip.text = "%s        %s" % [spec["title"], spec["note"]]
	strip.add_theme_font_override("font", font)
	strip.add_theme_font_size_override("font_size", 15)
	strip.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.92))
	strip.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	strip.add_theme_constant_override("outline_size", 6)
	strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_left = 12.0
	strip.offset_top = -26.0
	strip.offset_bottom = -4.0
	add_child(strip)
