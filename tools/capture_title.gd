extends SceneTree
## 타이틀 화면을 **한 번 띄워서 전부** 뽑는다.
##
##   godot --path . --resolution 1280x720 -s res://tools/capture_title.gd -- .captures/title
##
## 띄우고 닫기를 반복하지 않는 이유가 있다. 창을 여는 Godot 실행은 드라이버를 타고,
## 실제로 한 세션에서 NVIDIA OpenGL 드라이버 안에서 두 번 죽은 적이 있다.
## **한 번 띄운 김에 등장 · 머무름 · 호버 · 눌림 · 전환을 다 뽑는다.**
##
## 모션은 정지 화면 한 장으로 증명되지 않는다. 그래서 각 대목을 **연속 프레임**으로 남기고,
## 프레임 수가 아니라 **시간 간격**으로 띄운다 — 창이 60Hz 인지 165Hz 인지에 따라
## 같은 프레임 수가 전혀 다른 길이가 되어 어떤 기계에서는 연출이 끝난 뒤만 찍힌다.

const _TITLE := "res://src/ui/title/title_stage.tscn"

## 화면이 자리를 잡기까지 두는 프레임. 등장을 찍어야 하므로 최소한만 둔다.
const _WARMUP := 3

## 프레임 시간을 재는 구간의 길이. 셰이더가 도는 화면은 몇 초는 봐야 튀는 값이 나온다.
const _PERF_FRAMES := 320

var _out := "res://.captures/title"
var _queue: Array = []
var _step := 0
var _clock := 0.0
var _warmed := 0
var _screen: Control
var _perf: Array[float] = []
var _measuring := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = "res://%s" % args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out).get_base_dir())
	_screen = load(_TITLE).instantiate()
	root.add_child(_screen)
	_plan()


## 무엇을 어떤 순서로 뽑는가. 이 배열이 곧 심사에 낼 필름이다.
func _plan() -> void:
	# 배치 — 겹이 제자리에 앉았는가. 한 장이면 된다.
	_shot("stage")
	# 머무름 — 아무도 안 건드려도 살아 있는가. 사람이 한 번에 하나씩 다가오는지 본다.
	_film("idle", 14, 0.45)
	# 커서 — 판이 커서를 밀어내며 기운다. 시차가 겹마다 다른지 본다.
	_call(func() -> void: _sway(Vector2(0.06, 0.12)))
	_wait(0.9)
	_shot("sway_left")
	_call(func() -> void: _sway(Vector2(0.94, 0.86)))
	_wait(0.9)
	_shot("sway_right")
	_call(_measure)


func _process(delta: float) -> bool:
	_warmed += 1
	if _warmed < _WARMUP:
		return false
	if _measuring:
		return _tick_perf(delta)
	if _step >= _queue.size():
		return true
	var job: Dictionary = _queue[_step]
	match job["kind"]:
		"wait":
			_clock += delta
			if _clock >= float(job["seconds"]):
				_advance()
		"call":
			(job["action"] as Callable).call()
			_advance()
		"film":
			_clock += delta
			var saved: int = job["saved"]
			if _clock >= float(job["gap"]) * float(saved + 1):
				_save("%s_%02d" % [job["tag"], saved + 1])
				job["saved"] = saved + 1
				if job["saved"] >= int(job["count"]):
					_advance()
	return false


func _advance() -> void:
	_clock = 0.0
	_step += 1


func _wait(seconds: float) -> void:
	_queue.append({"kind": "wait", "seconds": seconds})


func _call(action: Callable) -> void:
	_queue.append({"kind": "call", "action": action})


func _film(tag: String, count: int, gap: float) -> void:
	_queue.append({"kind": "film", "tag": tag, "count": count, "gap": gap, "saved": 0})


## 한 장만 필요할 때. 값이 화면에 반영될 시간을 조금 준다.
func _shot(tag: String) -> void:
	_wait(0.14)
	_film(tag, 1, 0.02)


## 커서를 그 자리(화면 비율)에 둔 것처럼 판을 기울인다.
##
## 실제 마우스 이벤트를 주입하지 않는다. SceneTree 스크립트에서 넣은 입력은
## 씬의 입력 처리까지 닿지 않는다(capture_scene.gd 가 같은 이유로 버튼을 직접 누른다).
func _sway(where: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = where * Vector2(_screen.size)
	_screen.call("_gui_input", event)


func _save(tag: String) -> void:
	var image := root.get_texture().get_image()
	var path := "%s_%s.png" % [_out, tag]
	var err := image.save_png(path)
	print("shot: %s (err=%d)" % [path, err])


## 프레임 시간. 웹은 단일 스레드라 평균만 보면 가끔 튀는 프레임을 놓친다.
func _measure() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_measuring = true


func _tick_perf(delta: float) -> bool:
	_perf.append(delta)
	if _perf.size() < _PERF_FRAMES:
		return false
	var total := 0.0
	var worst := 0.0
	for value in _perf:
		total += value
		worst = maxf(worst, value)
	var average := total / float(_perf.size())
	print(
		(
			"perf: frames=%d avg=%.3fms (%.0f fps) worst=%.3fms (%.0f fps)"
			% [
				_perf.size(),
				average * 1000.0,
				1.0 / maxf(average, 0.00001),
				worst * 1000.0,
				1.0 / maxf(worst, 0.00001),
			]
		)
	)
	return true
