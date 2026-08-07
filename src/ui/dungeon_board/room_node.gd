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
## 숨겨야 하는 것은 "방 안에 뭐가 있나"이지 "저기가 얼마나 높나"가 아니다
## (docs/design/07-level-design.md §7.2.6).
##
## ---
##
## **생김새는 전부 그려 낸다.** 기본 버튼 그리기를 비우고(RoomTile 변형)
## 셰이더가 신호면을, _draw 가 형태를 맡는다.
## 근거와 규칙은 docs/design/18-visual-identity.md 에 있다.
##
##   좌상단이 잘려 있다 — 신호가 들어오는 자리. 방향이 생겨 타일이 도형이 아니라 장비가 된다
##   숫자는 오른쪽 아래 — 시선이 마지막에 닿는 곳에 가장 큰 정보를 둔다
##   잡음의 양 = 모르는 정도 — 내가 선 방은 신호가 잠기고, 먼 방은 흐른다
##   숫자가 바뀌면 움직인다 — 변화량이 사람을 알려 준다 (design/13 §13.5.1)

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

const _TILE_SHADER := preload("res://src/ui/style/shaders/signal_tile.gdshader")

## 경고 사선의 간격과 굵기.
const _STRIPE_PITCH := 13.0
const _STRIPE_WIDTH := 4.0

## 아직 아무것도 모른다는 표시. 이 글자가 있으면 잡음이 걷히지 않는다.
const _UNKNOWN := "?"

var room_id: String

var _state: State = State.DISTANT
var _detail: Detail = Detail.FULL
var _climb_text := ""
var _last_value := ""
var _material: ShaderMaterial

@onready var _surface: ColorRect = %Surface
@onready var _overlay: Control = %Overlay
@onready var _name_label: Label = %NameLabel
@onready var _value_label: Label = %ValueLabel
@onready var _climb_label: Label = %ClimbLabel
@onready var _delta_label: Label = %DeltaLabel


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = _TILE_SHADER
	_material.set_shader_parameter("tile_size", UiTokens.tile_size())
	_material.set_shader_parameter("cuts", _cuts_vector())
	_material.set_shader_parameter("signal_color", UiTokens.SIGNAL)
	_material.set_shader_parameter("heat_color", UiTokens.ONAIR)
	_surface.material = _material
	_delta_label.visible = false
	_overlay.draw.connect(_draw_overlay)
	pressed.connect(func() -> void: room_selected.emit(room_id))
	mouse_entered.connect(_overlay.queue_redraw)
	mouse_exited.connect(_overlay.queue_redraw)


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
	_state = state
	_detail = detail
	_climb_text = climb_text
	_name_label.text = display_name
	_climb_label.text = climb_text
	_name_label.visible = detail != Detail.MINIMAL
	_climb_label.visible = detail == Detail.FULL and not climb_text.is_empty()

	_report_change(value_text)
	_value_label.text = value_text
	_apply_typography()
	_apply_colors()
	_apply_surface(value_text)

	# 막힌 방도 누를 수 없다. 색과 사선으로 "길은 있으나 못 오른다"를 구분해 보여 준다.
	disabled = state != State.CURRENT and state != State.REACHABLE
	_overlay.queue_redraw()


## 숫자가 바뀌었으면 그 사실을 화면에 남긴다.
##
## **이 게임에서 변화량은 사람의 움직임을 알려 주는 유일한 단서다**
## (docs/design/13-information-design.md §13.5.1). 그런데 플레이어에게 이전 값을
## 외우게 하면 재미가 아니라 노동이 된다(같은 문서 §13.7). 그래서 화면이 대신 기억한다.
##
## 부호는 ASCII 로 적는다. 삼각형 기호는 폰트에 없어 웹에서 두부가 된다.
func _report_change(value_text: String) -> void:
	var previous := _last_value
	_last_value = value_text
	if not value_text.is_valid_int() or not previous.is_valid_int():
		return
	var difference := int(value_text) - int(previous)
	if difference == 0:
		return
	_delta_label.text = ("+%d" % difference) if difference > 0 else str(difference)
	_delta_label.add_theme_color_override("font_color", UiTokens.SIGNAL_HOT)
	_delta_label.visible = true
	UiMotion.rise_and_fade(_delta_label, UiTokens.SPACE_STEP)
	UiMotion.flash_color(_value_label, Color(1.6, 1.6, 1.6), Color(1.0, 1.0, 1.0))


## 배율이 낮아지면 숫자만 남는다. 그때는 정렬도 바뀐다.
##
## 이름이 사라진 타일에서 숫자를 오른쪽에 붙여 두면 왼쪽이 텅 빈 채로 남는다.
## **낮은 배율은 판의 모양과 색을 읽는 배율**이므로(design/07 §7.8),
## 숫자가 타일의 무게중심에 있어야 판 전체가 하나의 무늬로 읽힌다.
func _apply_typography() -> void:
	var minimal := _detail == Detail.MINIMAL
	_value_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER if minimal else HORIZONTAL_ALIGNMENT_RIGHT
	)
	_value_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER if minimal else VERTICAL_ALIGNMENT_BOTTOM
	)
	_value_label.offset_left = 0.0 if minimal else 46.0
	_value_label.offset_top = 0.0 if minimal else 24.0
	var big := _state == State.CURRENT
	_value_label.add_theme_font_size_override(
		"font_size", UiTokens.TYPE_NUMBER if big else UiTokens.TYPE_TITLE
	)


func _apply_colors() -> void:
	_name_label.add_theme_color_override("font_color", _name_color())
	_value_label.add_theme_color_override("font_color", _value_color())
	_climb_label.add_theme_color_override("font_color", _climb_color())


func _apply_surface(value_text: String) -> void:
	var certainty := _certainty()
	# 개발 모드에서는 실제 값이 드러난다. 정보가 있으면 잡음이 걷혀야 앞뒤가 맞는다.
	if value_text != _UNKNOWN and _state != State.CURRENT:
		certainty = maxf(certainty, 0.7)
	_material.set_shader_parameter("certainty", certainty)
	_material.set_shader_parameter("heat", 1.0 if _state == State.CURRENT else 0.0)
	_material.set_shader_parameter("fill_color", _fill_color())


## 지금 서 있는 방만 확신이고, 나머지는 모른다.
func _certainty() -> float:
	match _state:
		State.CURRENT:
			return 1.0
		State.REACHABLE:
			return 0.5
		State.BLOCKED:
			return 0.42
		_:
			return 0.0


func _fill_color() -> Color:
	match _state:
		State.CURRENT:
			return UiTokens.PLATE_HIGH
		State.BLOCKED:
			return UiTokens.fade(UiTokens.PLATE, 0.94)
		State.DISTANT:
			return UiTokens.fade(UiTokens.FLOOR, 0.88)
		_:
			return UiTokens.PLATE


## 윤곽선. 여기서만 **상태가 색으로 갈린다.**
##
## 위험도는 사실이므로 계측 색이고, 못 가는 것은 시설의 물리적 금지이므로 안전 표지 색이다.
## 붉은 송출 색은 절대 여기 오지 않는다 — 그건 렉카의 색이지 판의 색이 아니다.
func _outline_color() -> Color:
	if is_hovered() and not disabled:
		return UiTokens.SIGNAL_HOT
	match _state:
		State.CURRENT:
			return UiTokens.SIGNAL
		State.REACHABLE:
			return UiTokens.SIGNAL_DIM
		State.BLOCKED:
			return UiTokens.HAZARD_DIM
		_:
			return UiTokens.SEAM


func _outline_width() -> float:
	if _state == State.CURRENT:
		return UiTokens.STROKE_RULE
	return UiTokens.STROKE_HAIR


func _name_color() -> Color:
	if _state == State.DISTANT:
		return UiTokens.INK_FAINT
	return UiTokens.INK_MUTED


func _value_color() -> Color:
	match _state:
		State.CURRENT:
			return UiTokens.SIGNAL_HOT
		State.REACHABLE:
			return UiTokens.INK
		State.BLOCKED:
			return UiTokens.HAZARD
		_:
			return UiTokens.INK_FAINT


func _climb_color() -> Color:
	if _state == State.BLOCKED:
		return UiTokens.HAZARD
	return UiTokens.INK_FAINT


func _cuts_vector() -> Vector4:
	var cuts := UiTokens.tile_cuts()
	return Vector4(cuts[0], cuts[1], cuts[2], cuts[3])


## 타일의 **형태**. 셰이더는 질감만 맡고, 선과 표시는 전부 여기서 절차적으로 그린다
## (src/ui/style/shape.gd).
func _draw_overlay() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var polygon := UiShape.chamfer_polygon(rect, UiTokens.tile_cuts())
	if _state == State.BLOCKED:
		for piece in UiShape.hazard_stripes(rect, _STRIPE_PITCH, _STRIPE_WIDTH, polygon):
			_overlay.draw_colored_polygon(piece, UiTokens.fade(UiTokens.HAZARD, 0.13))
	_overlay.draw_polyline(
		UiShape.closed_outline(polygon), _outline_color(), _outline_width(), true
	)
	# 네 귀퉁이가 저마다 다른 일을 한다. 이게 이 타일의 구성 규칙이다.
	#   좌상 — 잘린 면. 신호가 들어오는 자리
	#   우상 — 신호 세기. 이 방을 얼마나 아는가
	#   좌하 — 오르내림 표시
	#   우하 — 숫자를 감싸는 프레임
	_draw_signal_bars()
	_overlay.draw_polyline(
		UiShape.bracket(rect, UiShape.Corner.BOTTOM_RIGHT, UiTokens.BRACKET_ARM),
		UiTokens.fade(_outline_color(), 0.8),
		UiTokens.STROKE_RULE
	)
	if _state == State.CURRENT:
		_draw_onair_beam()
	if _climb_label.visible:
		_draw_climb_mark()


## 이 방을 **얼마나 아는가**를 칸으로 보여 준다.
##
## 이 게임의 공짜 정보는 전부 결함이 있다 (docs/design/13-information-design.md §13.6).
## 그렇다면 결함의 크기도 화면에 있어야 한다. 안 그러면 플레이어는 모든 숫자를
## 같은 무게로 읽고, 그 순간 정보 설계가 무너진다.
func _draw_signal_bars() -> void:
	var bar := Vector2(3.0, 9.0)
	var origin := Vector2(size.x - 12.0 - 3.0 * bar.x - 4.0, 7.0)
	var known := _known_bars()
	var lit := _outline_color()
	var dark := UiTokens.fade(UiTokens.SEAM, 0.75)
	var slots := UiShape.signal_bars(origin, 3, bar, 2.0)
	for index in slots.size():
		_overlay.draw_rect(slots[index], lit if index < known else dark)


## 몇 칸이 차는가. 상태가 곧 아는 정도다.
func _known_bars() -> int:
	match _state:
		State.CURRENT:
			return 3
		State.REACHABLE:
			return 2
		State.BLOCKED:
			return 2
		_:
			return 1


## 지금 중계되고 있는 방이라는 표시. **화면에서 유일하게 붉은 것**이다.
##
## 송출 레이어의 색은 판 위에 이 한 줄로만 들어온다. 여기가 지금 그림이 나오는 곳이고,
## 그래서 여기서 벌어지는 일은 곧 기사가 된다 (docs/design/08-ui-ux.md §8.3.4).
func _draw_onair_beam() -> void:
	var start := Vector2(UiTokens.CUT_TILE + 3.0, UiTokens.STROKE_RULE)
	var finish := Vector2(size.x * 0.44, UiTokens.STROKE_RULE)
	_overlay.draw_line(start, finish, UiTokens.ONAIR, UiTokens.STROKE_BEAM)


## 오르내림 표시. 폰트에 화살표 글리프가 없어 직접 그린다 (docs/conventions.md §5.1).
func _draw_climb_mark() -> void:
	var center := Vector2(13.0, size.y - 13.5)
	var color := _climb_color()
	if _climb_text.begins_with("오름"):
		_overlay.draw_polyline(UiShape.chevron(center, 5.0, 5.0, true), color, UiTokens.STROKE_RULE)
	elif _climb_text.begins_with("내림"):
		_overlay.draw_polyline(
			UiShape.chevron(center, 5.0, 5.0, false), color, UiTokens.STROKE_RULE
		)
	elif _climb_text.begins_with("평지"):
		_overlay.draw_line(
			center - Vector2(5.0, 0.0), center + Vector2(5.0, 0.0), color, UiTokens.STROKE_RULE
		)
	else:
		# 인접하지 않은 방은 절대 고도를 적는다. 계측값이라는 뜻으로 네모 눈금을 세운다.
		_overlay.draw_rect(Rect2(center - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), color)
