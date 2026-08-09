class_name HoloPane
extends Control
## **창 한 장이 무엇으로 되어 있나.** 재료를 셰이더가 칠한다.
##
## ## 실루엣은 꼭짓점이, 안쪽은 셰이더가
##
## 프래그먼트 셰이더는 **가장자리까지의 거리를 모른다** — 자기 좌표만 안다.
## 그래서 모따기와 접힘 같은 **가장자리에서 일어나는 일은 도형이 만든다.**
## 셰이더는 그 안쪽만 칠하고, UV 안에서의 거리로 「가장자리 가까움」을 얻는다.
## 깎인 모서리는 이미 도형이 잘라 냈으므로 그것으로 충분하다.
##
## ## 왜 노드를 따로 두나
##
## `ShaderMaterial` 은 캔버스 항목 하나에 걸린다. 부모가 즉시 그리기로 전부 그리면
## **글자까지 같은 셰이더를 먹는다.** 그래서 **재료는 이 노드가, 글은 부모가** 그린다 —
## 유리와 그 위의 잉크가 다른 것과 같다.

## 창이 무엇으로 되어 있나.
enum Stuff { GLASS, LIGHT, METAL, FIELD, PRINT }

const STUFF_NAMES := ["유리", "빛", "금속", "장", "판화"]

const SHADERS := [
	"res://assets/shaders/holo_glass.gdshader",
	"res://assets/shaders/holo_light.gdshader",
	"res://assets/shaders/holo_metal.gdshader",
	"res://assets/shaders/holo_field.gdshader",
	"res://assets/shaders/holo_print.gdshader",
]

## 세기 셋. **과하게를 반드시 만든다** — 경계를 알려면 넘어가 본 것이 있어야 한다.
const STEP_NAMES := ["약", "세", "과"]
const STEPS := [0.45, 1.0, 2.0]

@export var stuff: Stuff = Stuff.GLASS
@export var strength: float = 1.0

## 창의 실루엣. 부모가 넣어 준다. 비면 제 상자 그대로다.
var shape := PackedVector2Array()

var _clock := 0.0


static func label(what: Stuff) -> String:
	return STUFF_NAMES[int(what)]


static func count() -> int:
	return STUFF_NAMES.size()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dress()


## 재료를 갈아 끼운다. 셰이더가 노드마다 하나라 재료가 바뀌면 물질도 새로 만든다.
func _dress() -> void:
	var stuff_material := ShaderMaterial.new()
	stuff_material.shader = load(SHADERS[int(stuff)])
	material = stuff_material
	_push()


func set_stuff(what: Stuff, how_strong: float) -> void:
	stuff = what
	strength = how_strong
	_dress()
	queue_redraw()


func set_clock(t: float) -> void:
	_clock = t
	_push()
	queue_redraw()


func _push() -> void:
	var stuff_material := material as ShaderMaterial
	if stuff_material == null:
		return
	stuff_material.set_shader_parameter("strength", strength)
	stuff_material.set_shader_parameter("clock", _clock)
	# 가로세로 비를 넘겨야 「가장자리까지의 거리」가 위아래와 좌우에서 같은 뜻이 된다.
	stuff_material.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	var points := shape
	if points.is_empty():
		points = PackedVector2Array(
			[
				box.position,
				Vector2(box.end.x, box.position.y),
				box.end,
				Vector2(box.position.x, box.end.y)
			]
		)
	# UV 를 상자 안 자리로 낸다. 셰이더가 이걸로 가장자리 가까움을 얻는다.
	var uvs := PackedVector2Array()
	for point in points:
		uvs.append(Vector2(point.x / maxf(size.x, 1.0), point.y / maxf(size.y, 1.0)))
	draw_colored_polygon(points, Color.WHITE, uvs)
