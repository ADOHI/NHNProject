class_name LushPlate
extends ColorRect
## 층이 쌓인 판 하나. **셰이더가 실루엣까지 만든다.**
##
## docs/design/20-ui-kit.md §20.27.
##
## ## 왜 노드 하나에 재료 하나인가
##
## `_draw()` 원시 도형은 **CanvasItem 하나에 재료가 하나**다. 그래서 판마다 층을
## 다르게 쌓으려면 판이 자기 노드를 가져야 한다. 앞 판(§20.26)이 담백했던 진짜 이유가
## 이것이다 — 한 캔버스에 다 그리려니 **재료를 하나로 줄일 수밖에 없었다.**
##
## ## 노드가 판보다 크다
##
## 번짐(bloom)이 판 **밖으로** 나가야 한다. 도형으로 그리면 못 하는 것이고,
## 그래서 노드를 `BLEED` 만큼 키우고 셰이더가 그 안에서 실루엣을 만든다.
##
## ## 왜 `Control` 이 아니라 `ColorRect` 인가
##
## **빈 `Control` 은 픽셀을 하나도 안 덮는다.** 셰이더는 그려진 픽셀 위에서만 도므로
## 재료를 붙여도 아무것도 안 나온다 — 실제로 첫 판이 그렇게 나왔다(글자만 있는 화면).
## `ColorRect` 는 노드 전체를 덮는 사각형과 **0..1 UV** 를 준다. 셰이더가 UV 로
## 실루엣을 만드니 그 둘이 있어야 한다.
##
## ## 상태는 값이지 그림이 아니다
##
## 기본 · 올림 · 눌림 · 비활성이 **같은 셰이더의 다른 값**이다. 넷을 따로 그리면
## 「올림」이 「기본」과 다른 재료가 되어 버린다 — 그러면 손맛이 아니라 교체가 된다.

const BLEED := 26.0

## 판의 크기(번짐 여백을 뺀 것). 이 값을 주면 노드 크기가 따라온다.
var plate_size := Vector2(160.0, 46.0):
	set(value):
		plate_size = value
		size = value + Vector2(BLEED, BLEED) * 2.0
		_push()

var radius := 6.0:
	set(value):
		radius = value
		_push()

## 0..1 셋. 캡처와 진짜 마우스가 **같은 값**을 민다.
var hover := 0.0:
	set(value):
		hover = clampf(value, 0.0, 1.0)
		_push()

var press := 0.0:
	set(value):
		press = clampf(value, 0.0, 1.0)
		_push()

var dim := 0.0:
	set(value):
		dim = clampf(value, 0.0, 1.0)
		_push()

var clock := 0.0:
	set(value):
		clock = value
		_push()

## 불티를 낼 것인가. **작은 판에서는 끈다** — 입자가 글자보다 커진다.
var embers := true:
	set(value):
		embers = value
		_push()

var _shader: ShaderMaterial


func _init(source: Shader = null) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 셰이더가 COLOR 를 통째로 쓰므로 이 색은 안 보인다. 덮개일 뿐이다.
	color = Color.WHITE
	_shader = ShaderMaterial.new()
	_shader.shader = source
	material = _shader
	_push()


## 판을 놓는다. **좌표는 판 기준이고 번짐 여백은 여기서 뺀다** —
## 부르는 쪽이 여백을 알면 자리 계산이 안마다 달라진다.
func place(box: Rect2) -> void:
	plate_size = box.size
	position = box.position - Vector2(BLEED, BLEED)


## 이 판이 덮는 판 영역(번짐 제외). 글자를 얹을 때 쓴다.
func plate_rect() -> Rect2:
	return Rect2(position + Vector2(BLEED, BLEED), plate_size)


func palette(hot: Color, warm: Color, base: Color, edge: Color) -> void:
	if _shader == null:
		return
	_shader.set_shader_parameter("core_hot", hot)
	_shader.set_shader_parameter("core_warm", warm)
	_shader.set_shader_parameter("shell", base)
	_shader.set_shader_parameter("rim", edge)


func _push() -> void:
	if _shader == null:
		return
	_shader.set_shader_parameter("plate", plate_size)
	_shader.set_shader_parameter("radius", radius)
	_shader.set_shader_parameter("bleed", BLEED)
	_shader.set_shader_parameter("hover", hover)
	_shader.set_shader_parameter("press", press)
	_shader.set_shader_parameter("dim", dim)
	_shader.set_shader_parameter("clock", clock)
	_shader.set_shader_parameter("embers", 1.0 if embers else 0.0)
