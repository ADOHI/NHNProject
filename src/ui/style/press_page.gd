class_name PressPage
extends Control
## **지면 그 자체.** 제호 • 괘선 • 판 맞춤표 • 하단 쪽수.
##
## 판이 놓인 곳은 화면이 아니라 **이번 턴의 호외 1면**이다
## (docs/design/18-visual-identity.md §18.2). 그 사실을 말하는 것은 판이 아니라
## 판을 둘러싼 것들이다 — 제호가 있고 괘선이 있고 귀퉁이에 맞춤표가 있으면
## 안에 무엇이 들어가든 그것은 인쇄물이 된다.
##
## 그래서 이 노드는 화면 하나에 붙는 장식이 아니라 **모든 화면이 공유하는 틀**이다.
## 판 화면도 쇼케이스도 같은 지면 위에 앉는다.
##
## 제호를 라벨이 아니라 draw_string 으로 찍는 이유는, 오른쪽 맞춤과 두 판 겹쳐찍기를
## 픽셀 단위로 잡아야 하는데 컨테이너 배치로는 그 통제가 안 되기 때문이다.

## 제호 띠의 높이.
const BAND_HEIGHT := 118.0

## 채널 이름. 이 지면을 누가 찍었는지가 화면에서 가장 먼저 보여야 한다
## (docs/design/19-rekka-voice.md §19.2 — 화자는 연출부 소속 렉카다).
@export var title: String = "지하 실황"

## 제호 옆에 붙는 판식. 정규 지면이 아니라 **급하게 찍은 호외**다.
@export var mark: String = "호 외"

@export var kicker: String = "연출부 유출 • 무단 전재 환영 • 조회수만이 진실이다"

## 오른쪽 위에 찍히는 판 번호. 별색판이라 어긋난다.
@export var edition: String = "":
	set = set_edition

## 아래쪽 여백에 찍히는 한 줄.
@export var folio: String = ""

var _font: Font
var _marks: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UiTheme.project_font()
	# 맞춤표만 매 프레임 다시 그린다. 제호까지 매 프레임 찍으면
	# 가만히 있어야 할 글자를 프레임마다 재조판하게 된다.
	_marks = Control.new()
	_marks.name = "RegisterMarks"
	_marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marks)
	_marks.draw.connect(_draw_register_marks)
	resized.connect(queue_redraw)


func _process(_delta: float) -> void:
	if _marks != null:
		_marks.queue_redraw()


func set_edition(value: String) -> void:
	edition = value
	queue_redraw()


func set_folio(value: String) -> void:
	folio = value
	queue_redraw()


func _draw() -> void:
	if _font == null or size.x < 200.0:
		return
	_draw_masthead()
	_draw_folio()


## 신문은 제호가 가장 크다. 그리고 제호 아래에는 반드시 굵은 괘선이 있다.
func _draw_masthead() -> void:
	draw_rect(Rect2(0.0, 0.0, size.x, BAND_HEIGHT), UiTokens.fade(UiTokens.PAPER_HIGH, 0.96))
	for band in UiShape.rule_stack(
		Vector2(34.0, 14.0),
		size.x - 68.0,
		PackedFloat32Array([UiTokens.RULE_HEAVY, UiTokens.RULE_HAIR]),
		4.0
	):
		draw_rect(band, UiTokens.INK)

	var baseline := Vector2(38.0, 82.0)
	_strike(baseline, title, UiTokens.TYPE_DECK, UiTokens.INK, UiTokens.SLIP_STORY)
	var title_width := _width(title, UiTokens.TYPE_DECK)
	draw_string(
		_font,
		baseline + Vector2(title_width + 26.0, -6.0),
		mark,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		UiTokens.TYPE_SUB,
		UiTokens.INK_MUTED
	)
	draw_string(
		_font,
		Vector2(40.0, 104.0),
		kicker,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		UiTokens.TYPE_MICRO,
		UiTokens.INK_MUTED
	)

	if not edition.is_empty():
		var right := Vector2(size.x - 38.0 - _width(edition, UiTokens.TYPE_HEAD), 78.0)
		_strike(right, edition, UiTokens.TYPE_HEAD, UiTokens.SPOT, UiTokens.SLIP_SHOUT)

	for band in UiShape.rule_stack(
		Vector2(34.0, BAND_HEIGHT - 12.0),
		size.x - 68.0,
		PackedFloat32Array([UiTokens.RULE_BANNER, UiTokens.RULE_HAIR]),
		3.0
	):
		draw_rect(band, UiTokens.INK)


## **판 맞춤표.** 인쇄판을 겹쳐 앉힐 때 쓰는 표적이 지면 귀퉁이에 남아 있다.
##
## 이 화면이 인쇄 중인 판이라는 사실을 말하는 표시이면서,
## 서명(두 판이 어긋난다)이 놓인 자리이기도 하다.
func _draw_register_marks() -> void:
	var inset := 40.0
	var top := BAND_HEIGHT + 34.0
	for center in [
		Vector2(inset, top),
		Vector2(size.x - inset, top),
		Vector2(inset, size.y - inset),
		Vector2(size.x - inset, size.y - inset),
	]:
		_draw_register(center as Vector2)


func _draw_register(center: Vector2) -> void:
	# 먹판의 표적. 제자리에 있다.
	var ink := UiTokens.fade(UiTokens.INK_MUTED, 0.65)
	for stroke in UiShape.register_mark(center, UiTokens.REGISTER_ARM, UiTokens.REGISTER_GAP):
		_marks.draw_polyline(stroke, ink, UiTokens.RULE_HAIR)
	_marks.draw_polyline(
		UiShape.register_ring(center, UiTokens.REGISTER_ARM * 0.5), ink, UiTokens.RULE_HAIR
	)
	# 별색판의 표적. **어긋나 있고, 미세하게 떠다닌다.** 정합이 맞는 인쇄기는 없다.
	var slipped := center + UiTokens.slip(UiTokens.SLIP_STORY) + UiMotion.register_drift(1.0)
	var spot := UiTokens.fade(UiTokens.SPOT, 0.55)
	for stroke in UiShape.register_mark(
		slipped, UiTokens.REGISTER_ARM * 0.8, UiTokens.REGISTER_GAP
	):
		_marks.draw_polyline(stroke, spot, UiTokens.RULE_HAIR)


func _draw_folio() -> void:
	if folio.is_empty():
		return
	draw_rect(
		Rect2(34.0, size.y - 74.0, size.x - 68.0, UiTokens.RULE_HAIR),
		UiTokens.fade(UiTokens.INK, 0.5)
	)
	draw_string(
		_font,
		Vector2(40.0, size.y - 54.0),
		folio,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		UiTokens.TYPE_MICRO,
		UiTokens.INK_FAINT
	)


## 두 판으로 찍는다. 별색이 먼저 어긋난 자리에, 먹이 제자리에.
func _strike(pos: Vector2, text: String, size_px: int, ink: Color, slip: float) -> void:
	var ghost := UiTokens.SPOT if ink != UiTokens.SPOT else UiTokens.INK
	draw_string(
		_font,
		pos + UiTokens.slip(slip),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		size_px,
		UiTokens.fade(ghost, 0.8)
	)
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, ink)


func _width(text: String, size_px: int) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
