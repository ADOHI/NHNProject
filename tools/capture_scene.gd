extends SceneTree
## 임시 검증 도구. 메인 씬을 띄우고, 주어진 방들을 차례로 눌러 본 뒤 화면을 PNG 로 저장한다.
## 헤드리스로는 렌더링 결과를 볼 수 없어 눈으로 확인하기 위한 용도다.
##
##   godot --path . -s res://tools/capture_scene.gd -- out.png west_hall gallery shrine
##
## 인자는 순서대로 처리한다.
##
##   <방 id>    그 방을 눌러 이동한다
##   zoom3      휠을 3번 굴린다 (음수면 축소: zoom-3)
##   debug      개발 정보 패널을 켠다
##   showcase   메인 씬 대신 스타일 확인용 씬을 띄운다
##   sketch_a   방향 스케치를 띄운다 (a / b / c)
##   perf       수직동기를 끄고 프레임 시간을 잰다 (웹 60fps 제약 확인용)

const _WARMUP_FRAMES := 12

## 누른 뒤 캡처까지 두는 여유. 화면은 이번 프레임의 변경을 다음 프레임에 그린다.
const _SETTLE_FRAMES := 8

## perf 모드에서 재는 프레임 수. 셰이더가 도는 화면에서 몇 초는 봐야 튀는 값이 드러난다.
const _PERF_FRAMES := 400

var _pressed := false
var _frames := 0
var _out_path := "res://.capture.png"
var _room_path: Array = []
var _perf := false
var _frame_times: Array[float] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_path = "res://%s" % args[0]
		_room_path = args.slice(1)
	var scene := "res://src/main/main.tscn"
	if _room_path.has("showcase"):
		scene = "res://src/ui/style/style_showcase.tscn"
	if _room_path.has("perf"):
		_perf = true
		# 수직동기가 켜져 있으면 화면 주사율이 그대로 측정값이 되어 여유를 알 수 없다.
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var sketch := _sketch_direction()
	if not sketch.is_empty():
		var node := Control.new()
		node.set_script(load("res://src/ui/style/sketch/direction_sketch.gd"))
		node.set("direction", sketch)
		root.add_child(node)
		return
	root.add_child(load(scene).instantiate())


## sketch_a / sketch_b / sketch_c 인자에서 방향 글자만 뽑는다.
func _sketch_direction() -> String:
	for argument in _room_path:
		var text := argument as String
		if text.begins_with("sketch_"):
			return text.substr(7)
	return ""


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < _WARMUP_FRAMES:
		return false
	if _perf and _pressed and _frame_times.size() < _PERF_FRAMES:
		_frame_times.append(_delta)
		return false
	if _perf and not _frame_times.is_empty():
		_report_frame_times()
		_frame_times.clear()
	if not _pressed:
		_pressed = true
		for room_id in _room_path:
			if room_id == "debug":
				_press_debug_button()
			elif room_id == "showcase" or room_id.begins_with("sketch_"):
				continue
			elif room_id.begins_with("zoom"):
				_zoom_board(int(room_id.substr(4)))
			else:
				_press_room(room_id)
		return false
	if _frames < _WARMUP_FRAMES + _SETTLE_FRAMES:
		return false
	_print_board_state()
	_print_rooms()
	var image := root.get_texture().get_image()
	var err := image.save_png(_out_path)
	print("capture: %s (err=%d)" % [_out_path, err])
	return true


## 프레임 시간 통계.
##
## 웹 빌드는 단일 스레드라 프레임을 잡아먹는 효과는 아름다워도 탈락이다.
## 평균만 보면 가끔 튀는 프레임을 놓치므로 최댓값을 함께 찍는다.
func _report_frame_times() -> void:
	var total := 0.0
	var worst := 0.0
	for value in _frame_times:
		total += value
		worst = maxf(worst, value)
	var average := total / float(_frame_times.size())
	print(
		(
			"perf: frames=%d  avg=%.3fms (%.0f fps)  worst=%.3fms (%.0f fps)"
			% [
				_frame_times.size(),
				average * 1000.0,
				1.0 / maxf(average, 0.00001),
				worst * 1000.0,
				1.0 / maxf(worst, 0.00001),
			]
		)
	)


## 확대·축소한 상태도 캡처할 수 있어야 한다. 인자는 휠을 굴린 횟수다(음수면 축소).
func _zoom_board(steps: int) -> void:
	for node in root.find_children("*", "DungeonBoard", true, false):
		var event := InputEventMouseButton.new()
		event.button_index = (MOUSE_BUTTON_WHEEL_UP if steps > 0 else MOUSE_BUTTON_WHEEL_DOWN)
		event.pressed = true
		event.position = (node as Control).size * 0.5
		for i in absi(steps):
			node.call("_gui_input", event)
		return


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
func _print_board_state() -> void:
	for node in root.find_children("*", "DungeonBoard", true, false):
		print(
			(
				"board size=%s zoom=%.2f pan=%s"
				% [(node as Control).size, node.get("_zoom"), node.get("_pan")]
			)
		)
		return


## 방 위젯의 자식 구성은 바뀔 수 있으므로 이름으로 찾는다.
## 인덱스로 찾으면 위젯을 손볼 때마다 이 도구가 조용히 깨진다.
func _print_rooms() -> void:
	for node in root.find_children("*", "Button", true, false):
		var room_id: Variant = node.get("room_id")
		if room_id == null:
			continue
		var label := node.find_child("NameLabel", true, false) as Label
		print("room %s = %s" % [room_id, "?" if label == null else label.text])


## 실제 버튼을 눌러 이동시킨다. 상태를 직접 건드리지 않아야 화면 경로까지 검증된다.
func _press_room(room_id: String) -> void:
	for node in root.find_children("*", "Button", true, false):
		if node.get("room_id") == room_id and not node.disabled:
			node.pressed.emit()
			return
	push_warning("누를 수 없는 방입니다: %s" % room_id)
