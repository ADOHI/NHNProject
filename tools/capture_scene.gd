extends SceneTree
## 임시 검증 도구. 메인 씬을 띄우고, 주어진 방들을 차례로 눌러 본 뒤 화면을 PNG 로 저장한다.
## 헤드리스로는 렌더링 결과를 볼 수 없어 눈으로 확인하기 위한 용도다.
##
##   godot --path . -s res://tools/capture_scene.gd -- out.png west_hall gallery shrine

const _WARMUP_FRAMES := 12

## 누른 뒤 캡처까지 두는 여유. 화면은 이번 프레임의 변경을 다음 프레임에 그린다.
const _SETTLE_FRAMES := 8

var _pressed := false
var _frames := 0
var _out_path := "res://.capture.png"
var _room_path: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_path = "res://%s" % args[0]
		_room_path = args.slice(1)
	root.add_child(load("res://src/main/main.tscn").instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < _WARMUP_FRAMES:
		return false
	if not _pressed:
		_pressed = true
		for room_id in _room_path:
			if room_id == "debug":
				_press_debug_button()
			else:
				_press_room(room_id)
		return false
	if _frames < _WARMUP_FRAMES + _SETTLE_FRAMES:
		return false
	_print_rooms()
	var image := root.get_texture().get_image()
	var err := image.save_png(_out_path)
	print("capture: %s (err=%d)" % [_out_path, err])
	return true


## 개발 패널을 켠 상태도 캡처할 수 있어야 한다.
##
## 키 입력을 주입하는 대신 버튼을 직접 누른다. SceneTree 스크립트에서 넣은 입력은
## 씬의 _unhandled_input 까지 닿지 않는다.
func _press_debug_button() -> void:
	for node in root.find_children("*", "Button", true, false):
		if node.get("room_id") == null and (node.text as String).begins_with("개발 정보"):
			node.pressed.emit()
			return
	push_warning("개발 정보 버튼을 찾지 못했습니다")


## 판 위 방들의 id 를 찍어 둔다.
##
## 생성된 판은 id 가 r0, r1 … 이라 화면만 봐서는 어느 방을 눌러야 하는지 알 수 없다.
## 이동 경로를 지정해 캡처하려면 이 목록이 필요하다.
func _print_rooms() -> void:
	for node in root.find_children("*", "Button", true, false):
		var room_id: Variant = node.get("room_id")
		if room_id == null:
			continue
		print("room %s = %s" % [room_id, node.get_child(0).get_child(0).text])


## 실제 버튼을 눌러 이동시킨다. 상태를 직접 건드리지 않아야 화면 경로까지 검증된다.
func _press_room(room_id: String) -> void:
	for node in root.find_children("*", "Button", true, false):
		if node.get("room_id") == room_id and not node.disabled:
			node.pressed.emit()
			return
	push_warning("누를 수 없는 방입니다: %s" % room_id)
