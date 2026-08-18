class_name PopupBench
extends Control
## 팝업 여섯을 **한 화면에 나란히** 놓고 여는 확인 화면.
##
##     godot --path . res://src/ui/kit/popup_bench.tscn
##
## | 조작 | 무엇 |
## | --- | --- |
## | `Space` 또는 클릭 | 여섯을 한꺼번에 **다시 연다** |
## | `C` | 닫는다 |
## | `S` | 시계 정지 |
##
## **정지 화면으로는 팝업의 좋고 나쁨을 못 본다.** 버튼은 커서와 눌림이 정지 상태로도
## 존재하지만 팝업의 사건은 **열림과 닫힘**이라 상태가 아니라 지나가는 일이다.
## 그래서 이 화면은 GIF 로 판정한다.
##
## 뒤가 있다는 것이 버튼 확인 화면과 다르다. 여섯이 **뒤 처리를 서로 다르게** 쓰므로
## 팝업 자체만이 아니라 그 축도 같이 본다.

const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")

const BACKDROP := Color("#dee2e8")
const SURFACE := Color("#eef1f5")
const FAINT := Color("#c2c8d1")
const INK := Color("#212a37")
const DIM := Color("#6d7681")
const ACCENT := Color("#c0705f")

const PANEL := Vector2(360.0, 200.0)

const FORMS: Array[PopupForm.Kind] = [
	PopupForm.Kind.SHUTTER,
	PopupForm.Kind.RIFT,
	PopupForm.Kind.GHOST,
	PopupForm.Kind.HOLE,
	PopupForm.Kind.TALLY,
	PopupForm.Kind.WIRE,
]
const NAMES: Array[String] = [
	"벌어지는 널",
	"어긋난 띠 셋",
	"겹인쇄 (큰 면적)",
	"구멍 뚫린 판",
	"계측기 틀",
	"선만 (위태로움)",
]
const BACK_NAMES: Array[String] = ["뒤: 어둡게", "뒤: 밀림", "뒤: 물듦", "뒤: 어둡게", "뒤: 가로줄", "뒤: 가로줄"]

## 한 바퀴. 열림 → 머무름 → 닫힘 → 빈 화면.
const OPEN_AT: float = 0.35
const CLOSE_AT: float = 2.30
const LOOP: float = 3.20

var _dialogs: Array[ActionDialog] = []
var _slots: Array[Rect2] = []
var _clock := 0.0
var _frozen := false
var _driven := false


func _ready() -> void:
	_build()
	if not _driven:
		set_process(true)


## 캡처 도구가 시계를 잡는다. **`add_child()` 앞에서 불러야 한다.**
func drive_externally() -> void:
	_driven = true
	set_process(false)


func _build() -> void:
	var titles := ["출격 확인", "계약 파기", "되돌릴 수 없음", "보급 요청", "게이트 계측", "기록 열람"]
	for i in FORMS.size():
		var at := Vector2(72.0 + float(i % 3) * 400.0, 130.0 + float(i / 3) * 300.0)
		_slots.append(Rect2(at, PANEL))
		var dialog := ActionDialog.new()
		dialog.form = FORMS[i]
		dialog.title = titles[i]
		if _driven:
			dialog.drive_externally()
		add_child(dialog)
		dialog.position = at
		dialog.size = PANEL
		_dialogs.append(dialog)


func _process(delta: float) -> void:
	if _driven:
		return
	if not _frozen:
		_clock += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode == KEY_SPACE:
			_replay()
		elif key.keycode == KEY_C:
			for dialog in _dialogs:
				dialog.dismiss()
		elif key.keycode == KEY_S:
			_frozen = not _frozen
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed:
		_replay()


func _replay() -> void:
	for dialog in _dialogs:
		dialog.replay()


## 캡처가 시각 `t` 의 화면을 앉힌다. 여섯이 같은 대본을 탄다 — 열림이 서로 어떻게
## 다른지 보려면 같은 시각에 같은 단계여야 한다.
func set_clock(t: float) -> void:
	_clock = t
	var phase := PopupMotion.Phase.SHUT
	var since_open := -1.0
	var since_close := -1.0
	if t >= OPEN_AT:
		since_open = t - OPEN_AT
		phase = PopupMotion.Phase.OPEN
		if since_open < PopupMotion.PIECE_TIME + PopupMotion.STAGGER * 5.0:
			phase = PopupMotion.Phase.OPENING
	if t >= CLOSE_AT:
		since_close = t - CLOSE_AT
		phase = PopupMotion.Phase.CLOSING
	for dialog in _dialogs:
		dialog.pose(phase, t, since_open, since_close)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP)
	_draw_pretend_screen()
	for i in _slots.size():
		_draw_backdrop(i)
	_label("팝업 여섯 — 뒤 처리가 서로 다르다", Vector2(72.0, 52.0), 17, INK)
	draw_rect(Rect2(0.0, 70.0, size.x, 1.0), FAINT)
	for i in _slots.size():
		var at := _slots[i].position
		_label(NAMES[i], Vector2(at.x, at.y - 30.0), 15, INK)
		_label(BACK_NAMES[i], Vector2(at.x, at.y - 12.0), 13, DIM)


## 팝업 뒤에 있을 화면을 흉내 낸다. 뒤가 없으면 뒤 처리가 무슨 일을 하는지 안 보인다.
func _draw_pretend_screen() -> void:
	for slot in _slots:
		var box := slot.grow(26.0)
		draw_rect(box, SURFACE)
		draw_rect(box, FAINT, false, 1.0)
		var y := box.position.y + 18.0
		while y < box.end.y - 10.0:
			draw_rect(Rect2(box.position.x + 16.0, y, box.size.x - 32.0, 6.0), FAINT)
			y += 16.0


## 뒤 처리 넷. **판보다 먼저 자리잡고 판보다 늦게 걷힌다.**
func _draw_backdrop(index: int) -> void:
	var dialog := _dialogs[index]
	var deep := dialog.veil_now()
	if deep <= 0.005:
		return
	var box := _slots[index].grow(26.0)
	match PopupForm.backdrop(FORMS[index]):
		PopupForm.Backdrop.COMB:
			draw_rect(box, Color(0.10, 0.12, 0.16, 0.34 * deep))
			var y := box.position.y
			while y < box.end.y:
				draw_rect(Rect2(box.position.x, y, box.size.x, 2.0), Color(BACKDROP, 0.85 * deep))
				y += 5.0
		PopupForm.Backdrop.SHOVE:
			# 뒤가 옆으로 밀려 자리를 비켜 준다.
			var push := 16.0 * deep
			draw_rect(
				Rect2(box.position.x - push, box.position.y, box.size.x, box.size.y),
				Color(0.10, 0.12, 0.16, 0.30 * deep)
			)
		PopupForm.Backdrop.STAIN:
			draw_rect(box, Color(ACCENT, 0.26 * deep))
			draw_rect(box, Color(0.10, 0.12, 0.16, 0.22 * deep))
		_:
			draw_rect(box, Color(0.10, 0.12, 0.16, 0.42 * deep))


func _label(what: String, at: Vector2, size_px: int, color: Color) -> void:
	draw_string(FONT, at, what, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
