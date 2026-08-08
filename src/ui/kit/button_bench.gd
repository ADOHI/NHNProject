class_name ButtonBench
extends Control
## `ActionButton` 을 **실제 크기로, 실제 자리에** 놓고 보는 화면.
##
##     godot --path . res://src/ui/kit/button_bench.tscn
##
## | 조작 | 무엇 |
## | --- | --- |
## | 마우스 올림 · 클릭 | 위쪽 두 무리는 진짜 버튼이다. 커서 · 눌림이 그대로 돈다 |
## | `Tab` | 키보드 초점을 옮긴다 |
## | `S` | 상시 모션 정지 — 정지 화면으로 판정할 때 |
## | `R` | 시계를 0 으로 |
##
## ## 왜 확대 줄이 없나
##
## 이 저장소에서 **확대하면 예쁜데 실제 크기에서 안 읽히는** 사고가 이미 났다
## (방 위젯이 58x30px 에서 숫자가 망점에 묻혔다, docs/design/20-ui-kit.md §20.7).
## 그래서 여기에는 확대 줄을 두지 않는다. **1280x720 에 앉는 크기가 전부다.**
##
## 아래 줄의 네 개는 상태 넷을 나란히 세운 것이고 위의 두 무리는 실제로 눌린다.

const MOTION_STATE := ActionButtonMotion.State

const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")

const INK := Color("#f0e6d2")
const DIM := Color("#8b8577")
const FAINT := Color("#3a3730")
const SURFACE := Color("#15161a")
const BACKDROP := Color("#0b0c0f")
const GOLD := Color("#c1913c")

## 게이트 목록에 세우는 줄. 마지막 하나는 **갈 수 없는 게이트**라 비활성이다.
const GATES: Array[Array] = [
	["서초 3구역 균열", "위험도 12", false],
	["한남 지하 통로", "위험도 27", false],
	["잠실 붕괴 구간", "인원 부족", true],
]

## 캡처 대본. 커서가 붙고 · 눌리고 · 떨어지는 시각이다.
const HOVER_AT: float = 0.90
const DOWN_AT: float = 1.62
const UP_AT: float = 1.90
const LEAVE_AT: float = 2.50
const LOOP: float = 3.60

var _sortie: ActionButton
var _gate_buttons: Array[ActionButton] = []
var _previews: Array[ActionButton] = []
var _clock := 0.0
var _frozen := false
var _driven := false
var _last_pressed := ""


func _ready() -> void:
	_build()
	if not _driven:
		set_process(true)


## 캡처 도구가 시계를 잡는다. **`add_child()` 앞에서 불러야 한다** — 뒤에서 끄면
## 나중에 도는 `_ready()` 가 조용히 다시 켠다.
func drive_externally() -> void:
	_driven = true
	set_process(false)


func _build() -> void:
	_sortie = _make("출격")
	_sortie.position = Vector2(348.0, 288.0)
	_sortie.pressed.connect(_on_pressed.bind("출격"))

	var y := 196.0
	for gate in GATES:
		var button := _make("탐사 개시")
		button.position = Vector2(1200.0 - button.size.x, y)
		button.disabled = gate[2]
		button.pressed.connect(_on_pressed.bind(gate[0]))
		_gate_buttons.append(button)
		y += 74.0

	var states: Array[ActionButtonMotion.State] = [
		MOTION_STATE.NORMAL,
		MOTION_STATE.HOVER,
		MOTION_STATE.PRESSED,
		MOTION_STATE.DISABLED,
	]
	var x := 96.0
	for state in states:
		var button := _make("출격")
		button.position = Vector2(x, 592.0)
		button.disabled = state == MOTION_STATE.DISABLED
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.preview(state)
		_previews.append(button)
		x += button.size.x + 46.0


func _make(label: String) -> ActionButton:
	var button := ActionButton.new()
	button.text = label
	if _driven:
		button.drive_externally()
	add_child(button)
	button.size = button.custom_minimum_size
	return button


func _on_pressed(what: String) -> void:
	_last_pressed = what
	queue_redraw()


func _process(delta: float) -> void:
	if _driven:
		return
	if not _frozen:
		_clock += delta
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_S:
		_frozen = not _frozen
	elif key.keycode == KEY_R:
		_clock = 0.0


## 캡처가 시각 `t` 의 화면을 앉힌다. 위쪽 「출격」이 대본대로 움직이고
## 나머지는 상시 모션만 흐른다.
func set_clock(t: float) -> void:
	_clock = t
	var hovering := t >= HOVER_AT and t < LEAVE_AT
	var since_hover := t - HOVER_AT if hovering else -1.0
	var since_down := t - DOWN_AT if t >= DOWN_AT else -1.0
	var since_up := t - UP_AT if t >= UP_AT else -1.0
	var state := MOTION_STATE.NORMAL
	if t >= DOWN_AT and t < UP_AT:
		state = MOTION_STATE.PRESSED
	elif hovering:
		state = MOTION_STATE.HOVER
	_sortie.pose(state, t, since_hover, since_down, since_up)

	for button in _gate_buttons:
		if button.disabled:
			button.pose(MOTION_STATE.DISABLED, 0.0, -1.0, -1.0, -1.0)
		else:
			button.pose(MOTION_STATE.NORMAL, t, -1.0, -1.0, -1.0)

	_previews[0].pose(MOTION_STATE.NORMAL, t, -1.0, -1.0, -1.0)
	_previews[1].pose(MOTION_STATE.HOVER, t, t + 0.9, -1.0, -1.0)
	_previews[2].pose(MOTION_STATE.PRESSED, t, t + 0.9, ActionButtonMotion.IMPACT_TIME + 0.05, -1.0)
	_previews[3].pose(MOTION_STATE.DISABLED, 0.0, -1.0, -1.0, -1.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP)
	_draw_agit()
	_draw_gate_list()
	_draw_state_row()


## 왼쪽 — 아지트 화면. 버튼이 앉을 진짜 자리를 흉내 낸다.
func _draw_agit() -> void:
	var box := Rect2(56.0, 96.0, 496.0, 280.0)
	draw_rect(box, SURFACE)
	draw_rect(box, FAINT, false, 1.0)
	_label("아지트", Vector2(box.position.x + 24.0, box.position.y + 42.0), 24, INK)
	draw_line(
		Vector2(box.position.x + 24.0, box.position.y + 58.0),
		Vector2(box.end.x - 24.0, box.position.y + 58.0),
		FAINT,
		1.0
	)
	var rows := [["대기 인원", "4 명"], ["보급품", "12"], ["다음 게이트", "3 일 뒤"]]
	var y := box.position.y + 96.0
	for row in rows:
		_label(row[0], Vector2(box.position.x + 24.0, y), 17, DIM)
		_label(row[1], Vector2(box.position.x + 190.0, y), 17, INK)
		y += 30.0
	if not _last_pressed.is_empty():
		_label("마지막 입력  " + _last_pressed, Vector2(56.0, 408.0), 15, GOLD)


## 오른쪽 — 게이트 목록. 같은 버튼이 줄줄이 앉았을 때를 본다.
func _draw_gate_list() -> void:
	var box := Rect2(600.0, 96.0, 624.0, 336.0)
	draw_rect(box, SURFACE)
	draw_rect(box, FAINT, false, 1.0)
	_label("게이트 목록", Vector2(box.position.x + 24.0, box.position.y + 42.0), 24, INK)
	draw_line(
		Vector2(box.position.x + 24.0, box.position.y + 58.0),
		Vector2(box.end.x - 24.0, box.position.y + 58.0),
		FAINT,
		1.0
	)
	var y := 196.0
	for gate in GATES:
		var faded := gate[2] as bool
		_label(gate[0], Vector2(box.position.x + 24.0, y + 24.0), 19, DIM if faded else INK)
		_label(gate[1], Vector2(box.position.x + 24.0, y + 46.0), 15, DIM)
		y += 74.0


## 아래 — 상태 넷을 나란히. **확대하지 않는다.**
func _draw_state_row() -> void:
	draw_line(Vector2(56.0, 540.0), Vector2(1224.0, 540.0), FAINT, 1.0)
	_label("상태 넷 — 실제 크기", Vector2(56.0, 572.0), 15, DIM)
	var names := ["평상", "커서 올림", "눌림", "비활성"]
	for i in _previews.size():
		var button := _previews[i]
		_label(names[i], Vector2(button.position.x, 678.0), 16, DIM)


func _label(what: String, at: Vector2, size_px: int, color: Color) -> void:
	draw_string(FONT, at, what, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
