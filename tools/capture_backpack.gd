extends SceneTree
## 백팩 확인 화면을 띄우고 **한 번의 실행에서 여러 장**을 뽑는다.
##
##     godot --path . -s res://tools/capture_backpack.gd
##
## 우리는 `gl_compatibility` 라 창을 띄울 때마다 GL 컨텍스트를 새로 만든다.
## 그래서 띄우고 닫기를 반복하지 않고 **한 번 띄워 장면을 몰아서** 뽑는다 (CLAUDE.md).
##
## 화면을 눈으로 봐야 하는 이유: 좌표를 손으로 계산해 겹치지 않는 것을 확인해도
## **그림이 읽히는지는 봐야 안다.**

## 판이 자리를 잡을 시간. 씬을 붙인 뒤 `_ready` 가 그 자리에서 돌지 않는다.
const _WARMUP := 4

## 한 동작을 시킨 뒤 그릴 시간. 이 화면에는 트윈이 없어 몇 프레임이면 충분하다.
const _SETTLE := 3

var _screen: Control
var _board: BackpackBoard
var _frames := 0
var _index := 0
var _settle := 0
var _shots: Array = []


func _initialize() -> void:
	_screen = load("res://src/ui/backpack/backpack_screen.tscn").instantiate()
	root.add_child(_screen)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < _WARMUP:
		return false
	if _board == null:
		_board = _screen.get_node("%Board")
		_shots = _build_shots()
	if _settle > 0:
		_settle -= 1
		return false
	if _index >= _shots.size():
		return true

	var shot: Array = _shots[_index]
	if _settle == 0 and not bool(shot[2]):
		(shot[1] as Callable).call()
		shot[2] = true
		_settle = _SETTLE
		return false

	_save(shot[0] as String)
	_index += 1
	_settle = _SETTLE
	return false


## [이름, 동작, 이미 시켰나]
func _build_shots() -> Array:
	return [
		["01_default", func() -> void: pass, false],
		["02_drag_blocked", _hover_longsword_over_mace, false],
		["03_after_drop", _release, false],
		["04_gem_removed", _right_click_cell(Vector2i(5, 1)), false],
		["05_mace_moved", _drag_cell_to(Vector2i(1, 2), Vector2i(3, 4)), false],
		["06_start_empty", _right_click_cell(Vector2i(0, 0)), false],
	]


func _cell_point(cell: Vector2i) -> Vector2:
	return BackpackBoard.GRID_ORIGIN + (Vector2(cell) + Vector2(0.5, 0.5)) * BackpackBoard.CELL


func _send(event: InputEvent) -> void:
	_board._gui_input(event)


func _press(at: Vector2, button: int = MOUSE_BUTTON_LEFT, pressed: bool = true) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = at
	_send(event)


func _move(to: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	_send(event)


## 대기줄의 장검을 집어 철퇴 위로 가져간다. **놓을 수 없어 붉게 떠야 한다.**
func _hover_longsword_over_mace() -> void:
	_press(Vector2(BackpackBoard.TRAY_ORIGIN.x + 20.0, BackpackBoard.TRAY_ORIGIN.y + 70.0))
	_move(_cell_point(Vector2i(1, 2)))


func _release() -> void:
	_press(_cell_point(Vector2i(1, 2)), MOUSE_BUTTON_LEFT, false)


func _right_click_cell(cell: Vector2i) -> Callable:
	return func() -> void: _press(_cell_point(cell), MOUSE_BUTTON_RIGHT)


func _drag_cell_to(from: Vector2i, to: Vector2i) -> Callable:
	return func() -> void:
		_press(_cell_point(from))
		_move(_cell_point(to))
		_press(_cell_point(to), MOUSE_BUTTON_LEFT, false)


func _save(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := "res://.capture_backpack_%s.png" % name
	var err := image.save_png(path)
	print("capture: %s (err=%d)  |  %s" % [path, err, _chain_summary()])


## 사진과 함께 그때의 체인을 글자로도 남긴다. 그림과 논리가 어긋나면 여기서 걸린다.
func _chain_summary() -> String:
	var grid: BackpackGrid = _screen._grid
	var chains := ChainResolver.resolve_all(grid)
	var parts := PackedStringArray()
	for chain in chains:
		var verdict := "완주" if chain.is_complete() else "끊김"
		var line := "%d타 %s (%s)" % [chain.length(), verdict, chain.stop_label()]
		parts.append(line)
	return " / ".join(parts)
