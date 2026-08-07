extends SceneTree
## 이동 프로토타입을 띄우고 조작을 주입한 뒤 화면을 PNG 로 남긴다. 그리고 인원별 프레임을 잰다.
##
## **자동 테스트는 손맛을 알려 주지 않는다.** 뭉침과 진동은 숫자로 통과해도 눈으로 보면
## 엉망일 수 있다. 그래서 실제로 굴려 보고 장면을 잡는다.
##
##     godot --path . -s res://tools/capture_unit_move.gd
##     godot --path . -s res://tools/capture_unit_move.gd -- bench 20 40 80 120 200
##
## 헤드리스로 돌리면 그림이 나오지 않는다(캡처는 창이 있어야 한다). 성능 측정도
## 그리기까지 포함해야 의미가 있으므로 둘 다 창을 띄운 채로 돌린다.

const _SCENE := "res://src/proto/unit_move/unit_move_proto.tscn"
const _OUT_DIR := "res://.captures"

## 각 인원에서 프레임을 재는 시간(프레임 수).
const _BENCH_FRAMES := 240

## 인원을 바꾼 뒤 측정을 시작하기까지 버리는 프레임. 첫 프레임은 자원 할당이 섞여 값이 튄다.
const _BENCH_WARMUP := 40

var _proto: Node2D
var _steps: Array[Dictionary] = []
var _step_index := 0
var _wait_frames := 0
var _bench_counts: PackedInt32Array = PackedInt32Array()
var _bench_index := -1
var _bench_frames := 0
var _bench_total := 0.0
var _bench_worst := 0.0
var _settle_budget := 0
var _bench_debug := false


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_OUT_DIR))
	_proto = load(_SCENE).instantiate()
	root.add_child(_proto)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] == "bench":
		for i in range(1, args.size()):
			_bench_counts.append(int(args[i]))
		if _bench_counts.is_empty():
			_bench_counts = PackedInt32Array([20, 40, 80, 120, 200, 300])
		_build_bench_steps()
	else:
		_build_capture_steps()


func _process(delta: float) -> bool:
	if _bench_index >= 0:
		_measure(delta)
	# 도착까지 기다리는 구간. 프레임 수로 세면 실행 속도에 따라 장면이 달라진다.
	if _settle_budget > 0:
		_settle_budget -= 1
		if _moving_count() > 0:
			return false
		_settle_budget = 0
	if _wait_frames > 0:
		_wait_frames -= 1
		return false
	if _step_index >= _steps.size():
		return true
	var step := _steps[_step_index]
	_step_index += 1
	(step["action"] as Callable).call()
	_wait_frames = int(step["frames"])
	_settle_budget = int(step.get("settle", 0))
	return false


func _moving_count() -> int:
	var field: Object = _proto.get("field")
	return 0 if field == null else int(field.call("moving_count"))


# ----------------------------------------------------------------- 장면 잡기


func _build_capture_steps() -> void:
	_add(30, func() -> void: _proto.call("set_debug_visible", false))
	# 1. 드래그 선택 중. 상자를 그은 채로 멈춰 세워야 그 순간이 잡힌다.
	_add(2, func() -> void: _press_left(Vector2(100, 350)))
	_add(2, func() -> void: _move_mouse(Vector2(220, 420)))
	_add(6, func() -> void: _move_mouse(Vector2(330, 520)))
	_add(4, _save.bind("01_drag_select.png"))
	_add(4, func() -> void: _release_left(Vector2(330, 520)))
	_add(4, func() -> void: _key(KEY_1, true, false))

	# 2. 여럿이 한 점으로 몰릴 때. 열린 곳으로 보내 서로 부딪히는 순간을 잡는다.
	_add(170, func() -> void: _right_click(Vector2(760, 520)))
	_add(4, _save.bind("02_converging.png"))

	# 3. 도착 직후. 자리를 나눠 서는지, 떨고 있는지가 여기서 보인다.
	#    프레임 수가 아니라 전원이 멎을 때까지 기다린다. 실행 속도가 달라도 같은 장면이 잡힌다.
	_add(6, func() -> void: pass, 2400)
	_add(4, _save.bind("03_arrived.png"))

	# 4. 좁은 문으로 몰아넣기. 뭉침 처리가 가장 크게 갈리는 상황이다.
	#    목적지가 조절판에 가려 우클릭으로 찍을 수 없어 같은 명령을 직접 부르고, 문이 보이게 화면을 옮긴다.
	_add(6, func() -> void: _proto.call("order_move_at", Vector2(1240, 560)))
	_add(230, func() -> void: _proto.call("focus_camera", Vector2(1000, 560)))
	_add(4, _save.bind("04_choke.png"))

	# 5. 부대 전환. 같은 숫자를 두 번 눌러 화면이 그 부대로 옮겨 가는 것을 잡는다.
	_add(6, func() -> void: pass, 2400)
	_add(6, func() -> void: _key(KEY_1, false, false))
	_add(10, func() -> void: _key(KEY_1, false, false))
	_add(4, _save.bind("05_group_jump.png"))

	# 6. 개발 정보 표시. 흐름장 · 대형 자리 · 힘 벡터 · 유닛 상태를 한 화면에 담는다.
	_add(6, func() -> void: _proto.call("set_debug_visible", true))
	_add(120, func() -> void: _proto.call("order_move_at", Vector2(1150, 780)))
	_add(4, _save.bind("06_debug_info.png"))

	# 7. 인원을 늘려 같은 점으로 몰아넣기. 뭉침 처리가 인원에 따라 어떻게 변하는지 본다.
	_add(20, func() -> void: _proto.call("set_unit_count", 80))
	_add(200, _crowd_order)
	_add(4, _save.bind("07_crowd_80.png"))
	_add(2, _report)


func _crowd_order() -> void:
	_proto.call("select_all")
	_proto.call("order_move_at", Vector2(700.0, 550.0))


func _add(frames: int, action: Callable, settle: int = 0) -> void:
	_steps.append({"frames": frames, "action": action, "settle": settle})


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	var path := "%s/%s" % [_OUT_DIR, file_name]
	var err := image.save_png(path)
	print("capture %s (err=%d)" % [ProjectSettings.globalize_path(path), err])


func _report() -> void:
	print(
		(
			"유닛 %d  이동 계산 평균 %.3f ms  최악 %.3f ms"
			% [
				_proto.call("unit_count"),
				_proto.call("average_step_ms"),
				_proto.call("worst_step_ms")
			]
		)
	)


# ----------------------------------------------------------------- 성능 측정


## 개발 표시를 끈 상태와 켠 상태를 함께 잰다. 개발 표시가 얼마나 무거운지도 알아야
## 프레임이 무너진 원인이 이동 계산인지 그리기인지 구분할 수 있다.
func _build_bench_steps() -> void:
	for count in _bench_counts:
		for debug in [false, true]:
			_add(_BENCH_WARMUP, _bench_prepare.bind(count, debug))
			_add(_BENCH_FRAMES, _bench_start.bind(count, debug))
			_add(2, _bench_finish)


## 인원을 맞추고 전원에게 반대편으로 가라고 시킨다. 가만히 선 유닛은 부하를 만들지 않는다.
func _bench_prepare(count: int, debug: bool) -> void:
	_proto.call("set_unit_count", count)
	_proto.call("set_debug_visible", debug)
	_proto.call("select_all")
	_proto.call("order_move_at", Vector2(1500.0, 550.0))
	_proto.call("reset_samples")


func _bench_start(count: int, debug: bool) -> void:
	_bench_index = count
	_bench_debug = debug
	_bench_frames = 0
	_bench_total = 0.0
	_bench_worst = 0.0


func _bench_finish() -> void:
	if _bench_frames == 0:
		return
	var average := _bench_total / float(_bench_frames)
	print(
		(
			"유닛 %4d  개발표시 %s  평균 %6.1f fps  최악 프레임 %6.2f ms  이동 계산 평균 %5.3f ms  최악 %5.3f ms"
			% [
				_bench_index,
				"켬" if _bench_debug else "끔",
				1.0 / maxf(average, 0.00001),
				_bench_worst * 1000.0,
				_proto.call("average_step_ms"),
				_proto.call("worst_step_ms")
			]
		)
	)
	_bench_index = -1


func _measure(delta: float) -> void:
	_bench_frames += 1
	_bench_total += delta
	_bench_worst = maxf(_bench_worst, delta)
	# 왕복시켜야 계속 움직인다. 도착해 버리면 가장 무거운 구간을 못 잰다.
	if _bench_frames % 90 == 0:
		var target := Vector2(1500.0, 550.0) if _bench_frames % 180 == 0 else Vector2(260.0, 550.0)
		_proto.call("select_all")
		_proto.call("order_move_at", target)


# ----------------------------------------------------------------- 입력 주입
##
## 상태를 직접 건드리지 않고 실제 입력 경로로 넣는다. 그래야 화면 조작까지 함께 검증된다.


func _world_to_screen(world: Vector2) -> Vector2:
	return _proto.get_viewport().get_canvas_transform() * world


func _press_left(world: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = _world_to_screen(world)
	root.push_input(event)


func _release_left(world: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = _world_to_screen(world)
	root.push_input(event)


func _move_mouse(world: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _world_to_screen(world)
	event.relative = Vector2.ZERO
	root.push_input(event)


func _right_click(world: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = _world_to_screen(world)
	root.push_input(event)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_RIGHT
	up.pressed = false
	up.position = event.position
	root.push_input(up)


func _key(keycode: Key, ctrl: bool, shift: bool) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.pressed = true
	down.ctrl_pressed = ctrl
	down.shift_pressed = shift
	root.push_input(down)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.pressed = false
	up.ctrl_pressed = ctrl
	up.shift_pressed = shift
	root.push_input(up)
