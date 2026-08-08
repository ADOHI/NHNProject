extends SceneTree
## 나전 UI 키트 캡처 도구. `src/ui/kit/kit_showcase.tscn` 만 띄운다.
##
##     godot --path . -s res://tools/capture_kit.gd -- .renders/r1 [perf]
##
## **한 번 띄워서 전부 뽑는다.**
##
##     <앞머리>_still.png          정지 화면 (심사 · 조형용)
##     <앞머리>_film_01..10.png    같은 화면의 연속 10프레임 (0.11초 간격, 심사 · 모션용)
##
## `perf` 를 붙이면 대신 프레임 시간만 잰다.
##
## 한 장씩 따로 띄우지 않는 이유가 있다. 이 프로젝트는 gl_compatibility(OpenGL)를 쓰고
## 창을 띄울 때마다 GL 컨텍스트를 새로 만드는데, 그 반복이 NVIDIA 드라이버를 흔들어
## 실제로 프로세스가 통째로 죽은 적이 있다. **창은 적게 띄우고 많이 뽑는다.**
##
## 정지 화면 한 장으로는 이 키트를 판단할 수 없다. 편광은 늘 돌고 조각은 표류하며
## 포커스의 황동은 멈추지 않는다. 그 셋은 연속 프레임으로만 증명된다.

## 상태 보간이 **끝까지 도달할** 시간. 짧게 잡으면 첫 장이 전환 도중의 찌꺼기를 찍어
## 있지도 않은 결함처럼 보인다.
const _WARMUP_FRAMES := 60

const _FILM_FRAMES := 10

## 프레임 수가 아니라 **시간**으로 띄운다. 창이 60Hz 인지 165Hz 인지에 따라
## 같은 프레임 수가 전혀 다른 길이가 되기 때문이다.
const _FILM_INTERVAL := 0.11

const _PERF_FRAMES := 400

var _prefix := "res://.kit"
var _perf := false
var _filming := false
var _frames := 0
var _film_saved := 0
var _film_clock := 0.0
var _frame_times: Array[float] = []
var _showcase: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = "res://%s" % args[0]
	_perf = args.has("perf")
	if _perf:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_showcase = load("res://src/ui/kit/kit_showcase.tscn").instantiate()
	root.add_child(_showcase)
	# 씬을 직접 띄웠을 때 뜨는 조작 안내는 조형이 아니다. 심사에 나가는 그림에서는 뺀다.
	_showcase.call("set_guide_visible", false)


func _process(delta: float) -> bool:
	_frames += 1
	if _perf:
		return _measure(delta)
	if _filming:
		return _capture_film(delta)
	if _frames < _WARMUP_FRAMES:
		return false
	_save("%s_still.png" % _prefix)
	_filming = true
	_film_saved = 0
	_film_clock = 0.0
	return false


## 연속 캡처. 정지 화면 여러 장이라야 "가만히 있을 때도 살아 있는가"를 증명한다.
func _capture_film(delta: float) -> bool:
	_film_clock += delta
	if _film_clock < _FILM_INTERVAL * float(_film_saved + 1):
		return false
	_save("%s_film_%02d.png" % [_prefix, _film_saved + 1])
	_film_saved += 1
	return _film_saved >= _FILM_FRAMES


func _save(path: String) -> void:
	var image := root.get_texture().get_image()
	var err := image.save_png(path)
	print("capture: %s (err=%d)" % [path, err])


## 웹은 단일 스레드다. 평균이 아니라 최악 프레임이 60fps 여유를 정한다.
func _measure(delta: float) -> bool:
	if _frames < _WARMUP_FRAMES:
		return false
	_frame_times.append(delta)
	if _frame_times.size() < _PERF_FRAMES:
		return false
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
	return true
