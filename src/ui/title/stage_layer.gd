class_name StageLayer
extends Control
## **겹 한 장.** 그림 하나를 자기 자리에 놓고, 자기 역할대로만 움직인다.
##
## 그림이 **아직 없어도 돌아간다.** 파일이 없으면 그 자리에 표를 그린다 —
## 배치와 움직임은 그림 없이도 짤 수 있어야 하고, 실제로 생성 순번을 기다리는
## 동안 그렇게 만들었다(docs/design/21-title.md §21.13).

## 그림이 없을 때 자리 표시에 쓰는 색. 역할마다 다르게 해서 배치를 눈으로 검사한다.
const _MARK: Dictionary = {
	TitleLayers.Role.BACKDROP: Color(0.16, 0.20, 0.24, 1.0),
	TitleLayers.Role.HOARD: Color(0.86, 0.66, 0.18, 1.0),
	TitleLayers.Role.HUNTER: Color(0.20, 0.24, 0.28, 1.0),
	TitleLayers.Role.DEMON: Color(0.44, 0.16, 0.22, 1.0),
	TitleLayers.Role.FOREGROUND: Color(0.08, 0.10, 0.12, 1.0),
}

var spec: TitleLayers.Spec = null
var texture: Texture2D = null

## 이 겹이 제자리에서 얼마나 밀려 있는가(px). 시차와 자기 움직임이 여기 더해진다.
var offset := Vector2.ZERO

## 다가온 정도(0~1). 인간만 쓴다 — 금 쪽으로 이만큼 다가와 있다.
##
## `set` 을 붙인 이유는 트윈이 이 값을 직접 물기 때문이다. 값만 바뀌고
## 다시 그리지 않으면 다가오는 것이 화면에 안 나타난다.
var closed := 0.0:
	set(value):
		closed = value
		queue_redraw()

var _home := Rect2()
var _aspect := 1.0
var _toward := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	# 다가온 만큼 금 쪽으로 옮겨 앉는다. 크기는 건드리지 않는다 —
	# 다가오면서 커지면 화면 쪽으로 오는 것이 되고, 이 사람들은 **가운데로** 간다.
	var box := Rect2(_home.position + offset + _toward * closed - position, _home.size)
	if texture != null:
		# 원경은 근경만큼 또렷하면 안 된다. 아주 조금 차갑게, 아주 조금 옅게 —
		# 배경의 청록 쪽으로 밀리면서 뒤로 물러난다. 가장자리를 물리는 것과 짝이다
		# (docs/design/21-title.md §21.13.10).
		var tone := Color.WHITE
		if spec.role == TitleLayers.Role.DEMON:
			tone = TitleLayers.DEMON_HAZE
		elif spec.role == TitleLayers.Role.FOREGROUND:
			tone = TitleLayers.FOREGROUND_SHADE
		draw_texture_rect(texture, box, false, tone)
		return
	# 그림이 아직 없다. 자리와 크기만 표로 남긴다.
	var tint: Color = _MARK.get(spec.role, Color.MAGENTA)
	draw_rect(box, Color(tint.r, tint.g, tint.b, 0.55), true)
	draw_rect(box, tint, false, 2.0)


## 화면 크기가 정해졌다. 제자리와 **다가갈 방향**을 다시 잰다.
func lay_out(screen: Vector2, toward: Vector2 = Vector2.ZERO) -> void:
	_home = TitleLayers.rect_of(spec, screen, _aspect)
	# 다가갈 방향은 제자리에서 목표를 향하는 벡터다. 길이는 화면 기준으로 잰다.
	_toward = Vector2.ZERO
	if toward != Vector2.ZERO:
		_toward = (toward * screen - _home.get_center())
	# 크기를 직접 넣지 않는다. 이 겹은 화면에 꽉 차게 앵커되어 있어서
	# 엔진이 어차피 덮어쓰고, 그때 경고가 난다. 그릴 자리는 `_home` 이 안다.
	queue_redraw()


## 그림을 물린다. 그림의 가로세로비를 따라가야 인물이 눌리지 않는다.
func adopt(value: Texture2D) -> void:
	texture = value
	if value != null and value.get_height() > 0:
		_aspect = float(value.get_width()) / float(value.get_height())
	queue_redraw()


## 제자리. 다가온 만큼은 여기서 빼지 않는다 — 그건 offset 이 진다.
func home() -> Rect2:
	return _home
