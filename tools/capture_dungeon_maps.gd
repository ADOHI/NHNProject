extends SceneTree
## 여러 시드 · 크기의 판을 차례로 PNG 로 뽑는 개발 도구.
##
## 헤드리스 테스트는 "교차가 없다"까지만 말해 준다. **판이 읽히는지는 눈으로 봐야 한다.**
## 한 장만 뽑으면 우연히 잘 나온 판을 보게 되므로 여러 시드를 한 번에 뽑는다.
##
##   godot --path . -s res://tools/capture_dungeon_maps.gd
##
## capture_scene.gd 와 나누어 둔 이유는 목적이 다르기 때문이다.
## 그쪽은 "이 방들을 눌러 본 결과"를 찍고, 이쪽은 "생성기가 뽑는 판들"을 찍는다.
##
## 파일 이름을 .capture 로 시작하는 것은 .gitignore 규칙에 맞추기 위해서다.
## 검증용 캡처는 커밋하지 않는다.

## 찍을 판 목록. [시드, 맵 크기].
const _SHOTS := [[1, 3], [7, 3], [42, 5], [99, 5], [314, 1], [2718, 4], [12345, 5]]

## 판을 세우고 화면이 자리를 잡을 때까지 기다릴 프레임 수.
##
## 화면은 이번 프레임의 변경을 다음 프레임에 그리고, 카메라 중앙 정렬은
## 배치가 끝난 뒤로 미뤄져 있다 (dungeon_board.gd setup).
const _SETTLE_FRAMES := 8

## 축소 단계. 큰 판은 배율 1 에서 화면에 다 들어오지 않는다.
const _ZOOM_OUT_STEPS := 8

var _prefix := ".capture_map"
var _main: Node
var _index := -1
var _phase := 0
var _wait := _SETTLE_FRAMES


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = args[0]
	_main = load("res://src/ui/dungeon_board/dungeon_screen.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	match _phase:
		0:
			_index += 1
			if _index >= _SHOTS.size():
				return true
			_build(_SHOTS[_index][0], _SHOTS[_index][1])
		1:
			_zoom_out()
		2:
			_save(_SHOTS[_index][0], _SHOTS[_index][1])
	_phase = (_phase + 1) % 3
	_wait = _SETTLE_FRAMES
	return false


func _build(seed_value: int, size: int) -> void:
	var slider := _main.find_child("SizeSlider", true, false)
	if slider != null:
		(slider as Range).value = float(size)
	_main.set("_seed", seed_value)
	_main.call("_build_run")


## 휠을 굴려 축소한 뒤 판 전체가 화면 가운데 오도록 옮긴다.
##
## 플레이 중에는 스쿼드가 화면 가운데 있는 것이 맞지만, 판의 구조를 확인하려면
## 판 전체가 한 장에 들어와야 한다.
func _zoom_out() -> void:
	for node in root.find_children("*", "DungeonBoard", true, false):
		var board := node as Control
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_WHEEL_DOWN
		event.pressed = true
		event.position = board.size * 0.5
		for step in _ZOOM_OUT_STEPS:
			board.call("_gui_input", event)
		_center_on_map(board)
		return


func _center_on_map(board: Control) -> void:
	var positions: Dictionary = board.get("_positions")
	if positions.is_empty():
		return
	var lowest := Vector2.INF
	var highest := -Vector2.INF
	for position in positions.values():
		lowest = lowest.min(position as Vector2)
		highest = highest.max(position as Vector2)
	var zoom: float = board.get("_zoom")
	board.set("_pan", board.size * 0.5 - (lowest + highest) * 0.5 * zoom)
	board.call("_reposition")


func _save(seed_value: int, size: int) -> void:
	var path := "res://%s_seed%d_size%d.png" % [_prefix, seed_value, size]
	var error := root.get_texture().get_image().save_png(path)
	print("capture: %s (err=%d)" % [ProjectSettings.globalize_path(path), error])
