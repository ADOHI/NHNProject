class_name ButtonBench
extends Control
## `ActionButton` 을 **실제 크기로** 놓고 보는 화면.
##
##     godot --path . res://src/ui/kit/button_bench.tscn
##
## | 조작 | 무엇 |
## | --- | --- |
## | 마우스 올림 · 클릭 | 위 두 줄은 진짜 버튼이다. 커서 · 눌림이 그대로 돈다 |
## | `Tab` | 키보드 초점을 옮긴다 |
## | `S` | 상시 모션 정지 — 정지 화면으로 판정할 때 |
## | `R` | 시계를 0 으로 |
##
## ## 이 화면이 묻는 것은 하나다 — **형태**
##
## 색도 거동도 네 개가 전부 같다. 다른 것은 `PlateForm.Kind` 하나뿐이라
## **무엇 때문에 달라 보이는지가 형태로 고정된다.**
##
## ## 왜 확대 줄이 없나
##
## 이 저장소에서 **확대하면 예쁜데 실제 크기에서 안 읽히는** 사고가 이미 났다
## (방 위젯이 58x30px 에서 숫자가 망점에 묻혔다, docs/design/20-ui-kit.md §20.7).
## 여기 있는 것은 전부 1280x720 에 앉는 크기다.

const MOTION_STATE := ActionButtonMotion.State

const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")

const INK := Color("#212a37")
const DIM := Color("#6d7681")
const FAINT := Color("#c2c8d1")
const SURFACE := Color("#eef1f5")
const BACKDROP := Color("#dee2e8")
const MARK := Color("#b0685c")

## 위 줄에 나란히 세우는 형태들. 마지막이 **일부러 과한 것**이다.
const FORMS: Array[PlateForm.Kind] = [
	PlateForm.Kind.SHARD,
	PlateForm.Kind.RIFT,
	PlateForm.Kind.LEAN,
	PlateForm.Kind.FANG,
	PlateForm.Kind.WIRE,
	PlateForm.Kind.SPLIT,
	PlateForm.Kind.BOIL,
	PlateForm.Kind.RIP,
	PlateForm.Kind.MESH,
	PlateForm.Kind.TALLY,
	PlateForm.Kind.GHOST,
	PlateForm.Kind.HOLE,
	PlateForm.Kind.VEIL,
]
const FORM_NAMES: Array[String] = [
	"쐐기",
	"어긋난 판 셋",
	"기운 판",
	"뿔 (과한 것)",
	"선만",
	"흩어진 조각",
	"끓는 윤곽",
	"찢어진 아래",
	"점망 (셰이더)",
	"눈금자",
	"겹인쇄",
	"구멍 뚫린 판",
	"흐르는 띠 (셰이더)",
]

## 한 줄에 넣을 수 있는 폭. 넘으면 다음 줄로 접는다.
const ROW_WIDTH: float = 1180.0

## 상태 넷을 펼쳐 볼 형태. 파격이 상태 구분을 깨지 않는지 보는 자리다.
const STATE_FORM: PlateForm.Kind = PlateForm.Kind.FANG

## 캡처 대본. 커서가 붙고 · 눌리고 · 떨어지는 시각이다.
const HOVER_AT: float = 0.90
const DOWN_AT: float = 1.62
const UP_AT: float = 1.90
const LEAVE_AT: float = 2.50
const LOOP: float = 3.60

var _live: Array[ActionButton] = []
var _previews: Array[ActionButton] = []
var _rank: Array[ActionButton] = []
var _states_top := 380.0
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
	var x := 64.0
	var y := 118.0
	var tallest := 0.0
	for i in FORMS.size():
		var button := _make("출격", FORMS[i])
		if x + button.size.x > ROW_WIDTH:
			x = 64.0
			y += tallest + 62.0
			tallest = 0.0
		button.position = Vector2(x, y)
		button.pressed.connect(_on_pressed.bind(FORM_NAMES[i]))
		_live.append(button)
		x += button.size.x + 58.0
		tallest = maxf(tallest, PlateForm.height(FORMS[i]))
	_states_top = y + tallest + 128.0

	var states: Array[ActionButtonMotion.State] = [
		MOTION_STATE.NORMAL,
		MOTION_STATE.HOVER,
		MOTION_STATE.PRESSED,
		MOTION_STATE.DISABLED,
	]
	x = 64.0
	for state in states:
		var button := _make("출격", STATE_FORM)
		button.position = Vector2(x, _states_top)
		button.disabled = state == MOTION_STATE.DISABLED
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.preview(state)
		_previews.append(button)
		x += button.size.x + 60.0


func _make(label: String, kind: PlateForm.Kind) -> ActionButton:
	var button := ActionButton.new()
	button.form = kind
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


## 캡처가 시각 `t` 의 화면을 앉힌다. 위 줄이 대본대로 움직이고 나머지는 상시 모션만 흐른다.
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
	for button in _live:
		button.pose(state, t, since_hover, since_down, since_up)
	for button in _rank:
		button.pose(state, t, since_hover, since_down, since_up)

	_previews[0].pose(MOTION_STATE.NORMAL, t, -1.0, -1.0, -1.0)
	_previews[1].pose(MOTION_STATE.HOVER, t, t + 0.9, -1.0, -1.0)
	_previews[2].pose(MOTION_STATE.PRESSED, t, t + 0.9, 0.05, -1.0)
	_previews[3].pose(MOTION_STATE.DISABLED, 0.0, -1.0, -1.0, -1.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP)
	_band("형태 — 색도 거동도 같다. 윤곽만 다르다", 52.0)
	for i in _live.size():
		var at := _live[i].position
		_label(FORM_NAMES[i], Vector2(at.x, at.y + PlateForm.height(FORMS[i]) + 24.0), 15, DIM)

	_band("상태 넷 — 파격이 상태 구분을 깨지 않는지", _states_top - 46.0)
	var names := ["평상", "커서 올림", "눌림", "비활성"]
	for i in _previews.size():
		var at := _previews[i].position
		_label(names[i], Vector2(at.x, at.y + PlateForm.height(STATE_FORM) + 26.0), 15, DIM)
	if not _last_pressed.is_empty():
		_label("마지막 입력  " + _last_pressed, Vector2(64.0, size.y - 24.0), 15, MARK)


func _band(title: String, y: float) -> void:
	draw_rect(Rect2(0.0, y - 26.0, size.x, 1.0), FAINT)
	_label(title, Vector2(64.0, y), 16, INK)


func _label(what: String, at: Vector2, size_px: int, color: Color) -> void:
	draw_string(FONT, at, what, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
