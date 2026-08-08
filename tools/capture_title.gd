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

const _TITLE := "res://src/ui/title/title_screen.tscn"

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
var _glyph: FoilGlyph
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
	# 등장 — 종이가 찍히고 그 위에 박이 눌린다.
	_film("boot", 10, 0.075)
	# 머무름 — 붙으려다 어긋나는 한 바퀴(2.4 + 0.09 + 1.15 = 3.64초)를 통째로 덮는다.
	_wait(0.6)
	_film("idle", 12, 0.30)
	# 호버 — 빛이 커서를 따라 흐르는가. 자리를 옮겨 가며 세 장.
	_call(func() -> void: _light(Vector2(0.12, 0.10)))
	_shot("hover_1")
	_call(func() -> void: _light(Vector2(0.86, 0.24)))
	_shot("hover_2")
	_call(func() -> void: _light(Vector2(0.5, 1.05)))
	_shot("hover_3")
	# 눌림 — 그 자리의 박이 떨어져 나간다. 되돌아오지 않는 것을 보여야 한다.
	_call(func() -> void: _glyph.bruise_at(Vector2(0.38, 0.44)))
	_film("press", 8, 0.06)
	_wait(0.9)
	_shot("press_after")
	# 전환 — 두 조각이 끝내 갈라진다.
	_call(_tear)
	_film("descend", 10, 0.08)
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


func _light(where: Vector2) -> void:
	_find_glyph()
	if _glyph != null:
		_glyph.light_from(where)


func _tear() -> void:
	_find_glyph()
	if _glyph == null:
		return
	var tween := _glyph.create_tween()
	tween.tween_method(_glyph.tear_open, 0.0, 1.0, 0.8).set_ease(Tween.EASE_IN).set_trans(
		Tween.TRANS_EXPO
	)


func _find_glyph() -> void:
	if _glyph != null:
		return
	for node in root.find_children("*", "Control", true, false):
		if node is FoilGlyph:
			_glyph = node as FoilGlyph
			return


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
