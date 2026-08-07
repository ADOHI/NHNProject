class_name RoomNode
extends Button
## 지면에 실린 **사진 한 칸**. 판 위의 방 하나다.
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
## 셰이더가 망점을, _draw 가 괘선과 표시를 맡는다.
## 근거와 규칙은 docs/design/18-visual-identity.md 에 있다.
##
##   망점의 굵기 = 모르는 정도 — 원판이 없는 방은 뭉개 찍힌다
##   이름은 검은 띠에 흰 글씨 — 신문 도해의 캡션 그대로다
##   숫자는 오른쪽 아래 — 시선이 마지막에 닿는 곳에 가장 큰 정보를 둔다
##   숫자가 바뀌면 별색판이 튄다 — 변화량이 사람을 알려 준다 (design/13 §13.5.1)

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

const _CELL_SHADER := preload("res://src/ui/style/shaders/halftone_cell.gdshader")

## 오커 겹쳐찍기의 간격과 굵기.
const _OVERPRINT_PITCH := 12.0
const _OVERPRINT_WIDTH := 5.0

## 송출 표시가 왼쪽 틀 밖으로 나가는 거리. **조각이 자기 칸을 뚫고 나간다.**
const _TAB_OVERHANG := 14.0

## 아직 아무것도 모른다는 표시. 이 글자가 있으면 원판이 없다는 뜻이다.
const _UNKNOWN := "?"

var room_id: String

var _state: State = State.DISTANT
var _detail: Detail = Detail.FULL
var _climb_text := ""
var _last_value := ""
var _material: ShaderMaterial
var _font: Font

## 커서가 올라가 있는가. disabled 버튼은 is_hovered() 가 거짓이라 직접 센다.
var _hover := false

## 커서에 대한 이 칸의 **태도**. -1 이면 밀어내고 +1 이면 또렷해진다.
## 0 에서 목표값으로 트윈되고, 그 값이 선수•괘선•기울기를 한꺼번에 움직인다.
var _mood := 0.0
var _mood_tween: Tween
var _lean_tween: Tween
var _plate_tween: Tween

## 교정쇄가 켜져 실제 값이 드러나 있는가. 드러났으면 원판이 생긴 것이므로 곱게 찍힌다.
var _revealed := false

@onready var _surface: ColorRect = %Surface
@onready var _underlay: Control = %Underlay
@onready var _overlay: Control = %Overlay
@onready var _name_label: Label = %NameLabel
@onready var _value_label: Label = %ValueLabel
@onready var _value_ghost: Label = %ValueGhost
@onready var _climb_label: Label = %ClimbLabel
@onready var _delta_label: Label = %DeltaLabel


func _ready() -> void:
	_font = UiTheme.project_font()
	_material = ShaderMaterial.new()
	_material.shader = _CELL_SHADER
	_material.set_shader_parameter("cell_size", UiTokens.tile_size())
	_material.set_shader_parameter("paper_color", UiTokens.PAPER_HIGH)
	_material.set_shader_parameter("ink_color", UiTokens.INK)
	_material.set_shader_parameter("spot_color", UiTokens.SPOT)
	_material.set_shader_parameter("screen_fine", UiTokens.SCREEN_FINE)
	_material.set_shader_parameter("screen_coarse", UiTokens.SCREEN_COARSE)
	_material.set_shader_parameter("slip", UiTokens.SLIP)
	_material.set_shader_parameter("press_period", UiTokens.TIME_PRESS)
	_surface.material = _material
	_delta_label.visible = false
	_underlay.draw.connect(_draw_underlay)
	_overlay.draw.connect(_draw_overlay)
	pivot_offset = UiTokens.tile_size() * 0.5
	pressed.connect(func() -> void: room_selected.emit(room_id))
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))


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
	_value_ghost.text = value_text
	_apply_typography()
	_apply_colors()
	_apply_cell(value_text)

	# 막힌 방도 누를 수 없다. 오커 겹쳐찍기로 "길은 있으나 못 오른다"를 구분해 보여 준다.
	disabled = state != State.CURRENT and state != State.REACHABLE
	_redraw_marks()


## 이 칸을 다시 찍는다. 판이 통째로 새로 나올 때 상위가 부른다.
##
## 먹판이 먼저 때리고 별색판이 늦게 따라붙는다. 두 판이 같은 순간에 오면
## 그냥 한 장이 나타난 것이고, 시간차가 있어야 **두 번 찍힌 것**으로 읽힌다.
func reprint() -> void:
	UiMotion.slam(self, _slam_angle())
	UiMotion.misprint(_value_ghost, _ghost_home(), UiTokens.SLIP_STORY)
	_resolve_plate()


## **면이 반응한다.** 이 칸의 그림이 굵은 점에서 시작해 제 선수로 자라난다.
##
## 밝기를 올렸다 내리는 것이 아니라 **인쇄 품질 자체가 회복되는 것**이라,
## 무엇이 일어났는지가 색이 아니라 형태로 보인다.
func _resolve_plate() -> void:
	if _material == null:
		return
	if _plate_tween != null and _plate_tween.is_valid():
		_plate_tween.kill()
	_plate_tween = create_tween()
	(
		_plate_tween
		. tween_method(_set_plate, 0.0, _shown_certainty(), UiTokens.TIME_RESOLVE)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_EXPO)
	)


func _set_plate(value: float) -> void:
	_material.set_shader_parameter("certainty", value)


## 이 칸이 어느 쪽으로 기울었다가 앉는가.
##
## 전부 같은 방향으로 앉으면 도장 찍기가 되고, 칸마다 다르면 조판이 된다.
## 자리에서 각도를 뽑으므로 같은 칸은 늘 같은 방향으로 앉는다.
func _slam_angle() -> float:
	return UiShape.wiggle(float(room_id.hash() % 997)) * 7.0


## **커서에 대한 태도.** 여기가 이 게임의 반응 규칙이 사는 자리다.
##
## 올리면 밝아지는 것은 웹 버튼이지 이 게임이 아니다.
## 갈 수 있는 칸과 못 가는 칸은 **다르게 저항해야** 한다.
##
##   갈 수 있는 칸   원판이 또렷해진다. 들여다보면 그림이 선명해진다
##   못 오르는 칸    더 뭉개진다. 몸을 틀어 밀어낸다. 겹쳐찍기가 두꺼워진다
##   먼 칸           아무 반응도 없다. 내 것이 아니다
func _on_hover(entered: bool) -> void:
	_hover = entered
	var target := 0.0
	if entered:
		match _state:
			State.REACHABLE:
				target = 1.0
			State.BLOCKED:
				target = -1.0
			State.CURRENT:
				target = 0.45
			_:
				target = 0.0
	_tween_mood(target)
	if entered and _state == State.BLOCKED:
		_shrug()
	_redraw_marks()


func _tween_mood(target: float) -> void:
	if _mood_tween != null and _mood_tween.is_valid():
		_mood_tween.kill()
	_mood_tween = create_tween()
	(
		_mood_tween
		. tween_method(_set_mood, _mood, target, UiTokens.TIME_CHASE)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_QUINT)
	)


func _set_mood(value: float) -> void:
	_mood = value
	if _material != null:
		_material.set_shader_parameter("certainty", _shown_certainty())
	_redraw_marks()


## 못 오르는 칸은 **몸을 튼다.** 눌러도 소용없다는 것을 형태로 말한다.
func _shrug() -> void:
	if _lean_tween != null and _lean_tween.is_valid():
		_lean_tween.kill()
	_lean_tween = create_tween()
	(
		_lean_tween
		. tween_property(self, "rotation", deg_to_rad(-3.2), UiTokens.TIME_STRIKE * 1.4)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_lean_tween
		. tween_property(self, "rotation", 0.0, UiTokens.TIME_CHASE * 1.6)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_ELASTIC)
	)


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
	_delta_label.add_theme_color_override("font_color", UiTokens.SPOT)
	_delta_label.visible = true
	UiMotion.rise_and_fade(_delta_label, UiTokens.SPACE_STEP)
	# 값이 바뀌면 별색판이 크게 어긋났다 돌아온다. 화면 전체가 쓰는 그 서명이다.
	UiMotion.misprint(_value_ghost, _ghost_home(), UiTokens.SLIP_STORY)
	UiMotion.bleed(_value_label, Color(0.4, 0.4, 0.4), Color(1.0, 1.0, 1.0))


## 배율이 낮아지면 숫자만 남는다. 그때는 정렬도 바뀐다.
##
## 이름이 사라진 칸에서 숫자를 오른쪽에 붙여 두면 왼쪽이 텅 빈 채로 남는다.
## **낮은 배율은 판의 모양과 색을 읽는 배율**이므로(design/07 §7.8),
## 숫자가 칸의 무게중심에 있어야 판 전체가 하나의 무늬로 읽힌다.
func _apply_typography() -> void:
	var minimal := _detail == Detail.MINIMAL
	var big := _state == State.CURRENT
	var size := UiTokens.TYPE_HEAD if big else UiTokens.TYPE_SUB
	for label in [_value_label, _value_ghost]:
		var text_label := label as Label
		text_label.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER if minimal else HORIZONTAL_ALIGNMENT_RIGHT
		)
		text_label.vertical_alignment = (
			VERTICAL_ALIGNMENT_CENTER if minimal else VERTICAL_ALIGNMENT_BOTTOM
		)
		text_label.add_theme_font_size_override("font_size", size)
	_value_ghost.position = _ghost_home()


## 별색판이 앉는 자리. 내가 선 방만 어긋남이 보인다 — 거기만 이야기가 붙기 때문이다.
func _ghost_home() -> Vector2:
	if _state != State.CURRENT:
		return Vector2.ZERO
	return UiTokens.slip(UiTokens.SLIP_STORY * 0.6)


func _apply_colors() -> void:
	_name_label.add_theme_color_override("font_color", _name_color())
	_value_label.add_theme_color_override("font_color", _value_color())
	_climb_label.add_theme_color_override("font_color", _climb_color())
	_value_ghost.add_theme_color_override("font_color", UiTokens.fade(UiTokens.SPOT, 0.75))
	_value_ghost.visible = _state == State.CURRENT


func _apply_cell(value_text: String) -> void:
	# 개발 모드에서는 실제 값이 드러난다. 원판이 생겼으면 곱게 찍혀야 앞뒤가 맞는다.
	_revealed = value_text != _UNKNOWN and _state != State.CURRENT
	_material.set_shader_parameter("certainty", _shown_certainty())
	_material.set_shader_parameter("onair", 1.0 if _state == State.CURRENT else 0.0)


## 지금 화면에 실제로 실릴 확신. 상태에 커서의 태도가 더해진다.
##
## 태도가 음수면 원판이 **더 나빠진다.** 못 가는 칸을 들여다볼수록 뭉개지는 것이
## "여긴 네가 볼 데가 아니다"를 형태로 말하는 방법이다.
func _shown_certainty() -> float:
	var base := _certainty()
	if _revealed:
		base = maxf(base, 0.75)
	return clampf(base + _mood * 0.35, 0.0, 1.0)


## 지금 서 있는 방만 원판이 있고, 나머지는 없다.
func _certainty() -> float:
	match _state:
		State.CURRENT:
			return 1.0
		State.REACHABLE:
			return 0.5
		State.BLOCKED:
			return 0.45
		_:
			return 0.0


## 이 칸을 가두는 괘선. 여기서만 **상태가 굵기로 갈린다.**
func _rule_weight() -> float:
	var gain := 1.0 + absf(_mood) * 0.9
	match _state:
		State.CURRENT:
			return UiTokens.RULE_HEAVY
		State.REACHABLE:
			return UiTokens.RULE_TEXT * gain
		State.BLOCKED:
			return UiTokens.RULE_TEXT * gain
		_:
			return UiTokens.RULE_HAIR


## 괘선의 색. 위험도는 사실이므로 먹이고, 못 가는 것은 시설의 물리적 금지라 오커다.
## **별색 붉은판은 절대 여기 오지 않는다** — 그건 렉카의 판이지 계측의 판이 아니다.
func _rule_color() -> Color:
	if _hover and not disabled:
		return UiTokens.SPOT
	match _state:
		State.CURRENT:
			return UiTokens.INK
		State.REACHABLE:
			return UiTokens.INK_MUTED
		State.BLOCKED:
			return UiTokens.MARK_DEEP
		_:
			return UiTokens.fade(UiTokens.INK_FAINT, 0.7)


func _name_color() -> Color:
	return UiTokens.PAPER_HIGH


func _value_color() -> Color:
	match _state:
		State.CURRENT:
			return UiTokens.INK
		State.REACHABLE:
			return UiTokens.INK
		State.BLOCKED:
			return UiTokens.MARK_DEEP
		_:
			return UiTokens.INK_MUTED


func _climb_color() -> Color:
	if _state == State.BLOCKED:
		return UiTokens.MARK_DEEP
	return UiTokens.INK_MUTED


func _redraw_marks() -> void:
	_underlay.queue_redraw()
	_overlay.queue_redraw()


## 글자 **아래**에 깔리는 것. 캡션 띠와 겹쳐찍기다.
func _draw_underlay() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if _state == State.BLOCKED:
		# 밀어내는 중이면 겹쳐찍기가 두꺼워진다. 저항이 세질수록 지면이 더 막힌다.
		var thickness := _OVERPRINT_WIDTH * (1.0 + maxf(-_mood, 0.0) * 1.1)
		var clip := UiShape.rect_polygon(rect)
		for piece in UiShape.hazard_stripes(rect, _OVERPRINT_PITCH, thickness, clip):
			_underlay.draw_colored_polygon(piece, UiTokens.fade(UiTokens.MARK, 0.8))
	_draw_knockout()
	if _detail == Detail.MINIMAL:
		return
	# 이름은 사진 위에 얹힌 검은 띠에 종이색 글씨로 찍는다. 신문 도해의 캡션 그대로다.
	_underlay.draw_rect(
		Rect2(Vector2.ZERO, Vector2(size.x, UiTokens.caption_bar_height())), UiTokens.INK
	)


## 숫자가 앉을 자리를 **하얗게 뚫는다.**
##
## 사진 위에 숫자를 그냥 얹으면 망점이 굵은 칸에서 글자가 묻힌다. 그런데 여기서
## 묻히면 안 되는 이유가 있다 — 원판이 나쁜 것과 값이 없는 것은 다른 뜻이고,
## 플레이어는 그 둘을 구분해야 한다. 신문도 사진 위 숫자는 흰 박스로 뚫어 앉힌다.
func _draw_knockout() -> void:
	if _font == null or _value_label == null or _value_label.text.is_empty():
		return
	var font_size := UiTokens.TYPE_HEAD if _state == State.CURRENT else UiTokens.TYPE_SUB
	var text := _value_label.text
	var extent := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var box := Vector2(extent.x + 14.0, float(font_size) + 8.0)
	var origin := Vector2(size.x - 8.0 - box.x, size.y - 5.0 - box.y)
	if _detail == Detail.MINIMAL:
		origin = (size - box) * 0.5
	_underlay.draw_rect(Rect2(origin, box), UiTokens.fade(UiTokens.PAPER_HIGH, 0.94))
	if not _climb_label.visible:
		return
	var climb := _font.get_string_size(
		_climb_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.TYPE_MICRO
	)
	_underlay.draw_rect(
		Rect2(Vector2(4.0, size.y - 26.0), Vector2(climb.x + 26.0, 20.0)),
		UiTokens.fade(UiTokens.PAPER_HIGH, 0.92)
	)


## 글자 **위**에 얹히는 것. 괘선 • 판독률 • 송출 깃발 • 오르내림.
func _draw_overlay() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	_overlay.draw_rect(rect, _rule_color(), false, _rule_weight())
	_draw_gauge()
	if _state == State.CURRENT:
		_draw_onair_tab()
	if _climb_label.visible:
		_draw_climb_mark()


## **판독률.** 이 방의 원판이 얼마나 쓸 만한가를 칸으로 보여 준다.
##
## 이 게임의 공짜 정보는 전부 결함이 있다 (docs/design/13-information-design.md §13.6).
## 그렇다면 결함의 크기도 화면에 있어야 한다. 안 그러면 플레이어는 모든 숫자를
## 같은 무게로 읽고, 그 순간 정보 설계가 무너진다.
func _draw_gauge() -> void:
	var bar := Vector2(3.0, 11.0)
	var top := 6.0 if _detail != Detail.MINIMAL else size.y - bar.y - 6.0
	var origin := Vector2(size.x - 10.0 - 3.0 * bar.x - 4.0, top)
	var known := _known_bars()
	var lit := UiTokens.PAPER_HIGH if _detail != Detail.MINIMAL else UiTokens.INK
	var dark := UiTokens.fade(lit, 0.28)
	var slots := UiShape.gauge_bars(origin, 3, bar, 2.0)
	for index in slots.size():
		_overlay.draw_rect(slots[index], lit if index < known else dark)


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


## 지금 그림이 나가는 방이라는 표시. **화면의 판 위에서 유일하게 별색인 것**이다.
##
## 깃발이 칸의 왼쪽 틀을 뚫고 나간다. 사실은 틀 안에 갇히고 이야기는 틀을 넘는다
## (docs/design/18-visual-identity.md §18.4).
func _draw_onair_tab() -> void:
	var tab := Rect2(Vector2(-_TAB_OVERHANG, size.y - 30.0), Vector2(_TAB_OVERHANG + 52.0, 21.0))
	var beat := UiMotion.press_beat()
	_overlay.draw_colored_polygon(
		UiShape.pennant(tab, 7.0), UiTokens.fade(UiTokens.SPOT, 0.72 + 0.28 * beat)
	)
	if _font == null:
		return
	_overlay.draw_string(
		_font,
		tab.position + Vector2(6.0, 16.0),
		"송출중",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		UiTokens.TYPE_MICRO,
		UiTokens.PAPER_HIGH
	)


## 오르내림 표시. 폰트에 화살표 글리프가 없어 직접 그린다 (docs/conventions.md §5.1).
func _draw_climb_mark() -> void:
	var center := Vector2(12.0, size.y - 14.0)
	var color := _climb_color()
	if _climb_text.begins_with("오름"):
		_overlay.draw_polyline(UiShape.chevron(center, 5.0, 5.0, true), color, UiTokens.RULE_TEXT)
	elif _climb_text.begins_with("내림"):
		_overlay.draw_polyline(UiShape.chevron(center, 5.0, 5.0, false), color, UiTokens.RULE_TEXT)
	elif _climb_text.begins_with("평지"):
		_overlay.draw_line(
			center - Vector2(5.0, 0.0), center + Vector2(5.0, 0.0), color, UiTokens.RULE_TEXT
		)
	else:
		# 인접하지 않은 방은 절대 고도를 적는다. 잰 값이라는 뜻으로 네모 눈금을 세운다.
		_overlay.draw_rect(Rect2(center - Vector2(2.5, 2.5), Vector2(5.0, 5.0)), color)
