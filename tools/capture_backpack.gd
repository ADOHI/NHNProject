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

## 발사한 뒤 흐른 시간(초). **프레임이 아니라 시간으로 기다린다** —
## 창의 주사율에 따라 같은 프레임 수가 전혀 다른 길이가 된다
## (tools/capture_scene.gd 가 같은 함정에 걸렸던 자리다).
var _since_fire := 0.0
var _wait_until := -1.0


func _initialize() -> void:
	_screen = load("res://src/ui/backpack/backpack_screen.tscn").instantiate()
	root.add_child(_screen)


func _process(delta: float) -> bool:
	_frames += 1
	_since_fire += delta
	if _frames < _WARMUP:
		return false
	if _board == null:
		_board = _screen.get_node("%Board")
		_shots = _build_shots()
	if _wait_until >= 0.0:
		if _since_fire < _wait_until:
			return false
		_wait_until = -1.0
	if _settle > 0:
		_settle -= 1
		return false
	if _index >= _shots.size():
		return true

	var shot: Array = _shots[_index]
	if _settle == 0 and not bool(shot[2]):
		(shot[1] as Callable).call()
		shot[2] = true
		# 대련 장면은 시간이 흘러야 볼 수 있다. 장면마다 **발사 뒤 몇 초인지**를 준다.
		if shot.size() > 3:
			_wait_until = float(shot[3])
			_settle = 0
		else:
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
		["07_out_of_bounds", _stage_out_of_bounds, false],
		["08_loop", _stage_loop, false],
		["09_heavy_ready", _stage_heavy_chain, false],
		["10_bout_early", _fire, false, 0.5],
		["11_bout_mid", _wait, false, 1.6],
		["12_bout_launch", _wait, false, 3.0],
		["13_bout_settled", _wait, false, 6.5],
	]


## 1칸 무기를 뱀처럼 길게 이어 붙인다. 표본 5타는 경직까지밖에 안 가서
## **띄우기가 화면에서 어떻게 보이는지**를 못 본다.
##
## **처음에는 2x2 무거운 무기로 짰는데 띄우기에 못 닿았다.** 휘두르는 시간을
## 부피에서 뽑고 나니(§28.20.25) 4칸은 한 방 22 에 0.71초가 걸려 **초당 31** 이고,
## 초당 20 이 빠지는 판에서는 다섯 타로 53 까지밖에 안 찬다.
## 1칸은 **초당 43** 으로 오히려 세다.
##
## **이 장면이 뒤집힌 절벽의 증거다.**
func _stage_heavy_chain() -> void:
	var grid: BackpackGrid = _screen._grid
	grid.clear()
	var index := 0
	for row in 3:
		var going_right := row % 2 == 0
		for column in grid.width:
			var x := column if going_right else grid.width - 1 - column
			var direction := ChainDirection.Kind.DOWN
			if column < grid.width - 1:
				direction = (ChainDirection.Kind.RIGHT if going_right else ChainDirection.Kind.LEFT)
			index += 1
			grid.place(_weapon("검%d" % index, direction), Vector2i(x, row))
	_screen._refresh()


func _fire() -> void:
	_since_fire = 0.0
	_screen._fire()


func _wait() -> void:
	pass


## 시작 아이템이 격자 밖을 가리키는 상황. 「빈 칸」과 다르게 보여야 한다.
func _stage_out_of_bounds() -> void:
	var grid: BackpackGrid = _screen._grid
	grid.clear()
	grid.place(_weapon("칼", ChainDirection.Kind.UP), Vector2i(0, 0))
	_screen._refresh()


## 두 아이템이 서로를 가리키는 고리. 가위표가 아니라 동그라미로 보여야 한다.
func _stage_loop() -> void:
	var grid: BackpackGrid = _screen._grid
	grid.clear()
	grid.place(_weapon("칼", ChainDirection.Kind.RIGHT), Vector2i(0, 0))
	grid.place(_weapon("도끼", ChainDirection.Kind.LEFT), Vector2i(1, 0))
	_screen._refresh()


func _weapon(name: String, direction: ChainDirection.Kind) -> BackpackItem:
	return BackpackItem.new(
		name, name, BackpackItem.Kind.WEAPON, [Vector2i(0, 0)], Vector2i(0, 0), direction
	)


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
