extends SceneTree
## UI 키트 확인용 캡처 도구. `src/ui/kit/kit_showcase.tscn` 만 띄운다.
##
##     godot --path . -s res://tools/capture_kit.gd -- .renders/r5 [perf]
##
## **한 번 띄워서 전부 뽑는다.** 인자는 파일 이름 앞머리 하나뿐이고, 한 실행 안에서
## 조형 방향 셋(terrain · facet · grain)을 차례로 갈아 끼우며
##
##     <앞머리>_<방향>_states.png        다섯 상태의 정지 화면
##     <앞머리>_<방향>_film_01..08.png   같은 화면의 연속 8프레임 (0.09초 간격)
##     <앞머리>_terrain_popup.png        팝업이 뜬 정지 화면
##
## 를 저장한다. `perf` 를 붙이면 대신 프레임 시간만 잰다.
##
## 한 장씩 따로 띄우지 않는 이유가 있다. 이 프로젝트는 gl_compatibility(OpenGL)를 쓰고
## 창을 띄울 때마다 GL 컨텍스트를 새로 만드는데, 그 반복이 NVIDIA 드라이버를 흔들어
## 실제로 프로세스가 통째로 죽은 적이 있다. **창은 적게 띄우고 많이 뽑는다.**
##
## 정지 화면 한 장으로는 이 키트를 판단할 수 없다. 바탕은 늘 움직이고 포커스는
## 멈추지 않는다. 그 둘은 연속 프레임으로만 증명된다.

## 방향을 갈아 끼운 뒤 상태 보간이 **끝까지 도달할** 시간.
## 짧게 잡으면 첫 장이 전환 도중의 찌꺼기를 찍어, 있지도 않은 결함처럼 보인다.
const _WARMUP_FRAMES := 45

const _FILM_FRAMES := 8
const _FILM_INTERVAL := 0.09

## 상시 도는 셰이더라 몇 초는 봐야 튀는 프레임이 드러난다.
const _PERF_FRAMES := 400

const _VARIANTS := ["terrain", "facet", "grain"]

var _prefix := "res://.kit"
var _perf := false
var _variant := 0
var _filming := false
var _frames := 0
var _film_saved := 0
var _film_clock := 0.0
var _popup_done := false
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
	# 방향은 씬이 완전히 자리를 잡은 뒤에 건다. _initialize 안에서 걸면
	# 아직 만들어지기 전이라 조용히 빗나간다.
	if _frames == 2:
		_showcase.call("apply_variant", _VARIANTS[_variant])
	if _perf:
		return _measure(delta)
	if _filming:
		return _capture_film(delta)
	if _frames < _WARMUP_FRAMES:
		return false
	if _popup_done:
		_save("%s_terrain_popup.png" % _prefix)
		return true
	_save("%s_%s_states.png" % [_prefix, _VARIANTS[_variant]])
	_filming = true
	_film_saved = 0
	_film_clock = 0.0
	return false


## 연속 캡처 한 장. 정지 화면 여러 장이라야 "가만히 있을 때도 살아 있는가"를 증명한다.
func _capture_film(delta: float) -> bool:
	_film_clock += delta
	if _film_clock < _FILM_INTERVAL * float(_film_saved + 1):
		return false
	_save("%s_%s_film_%02d.png" % [_prefix, _VARIANTS[_variant], _film_saved + 1])
	_film_saved += 1
	if _film_saved < _FILM_FRAMES:
		return false
	_filming = false
	_frames = 0
	_variant += 1
	if _variant < _VARIANTS.size():
		_showcase.call("apply_variant", _VARIANTS[_variant])
		return false
	# 마지막으로 팝업 한 장. 방향은 처음 것으로 되돌린다.
	_variant = 0
	_popup_done = true
	_showcase.call("apply_variant", "terrain")
	_showcase.call("apply_scenario", "popup")
	return false


func _save(path: String) -> void:
	var image := root.get_texture().get_image()
	var err := image.save_png(path)
	print("capture: %s (err=%d)" % [path, err])


## 웹은 단일 스레드다. 평균이 아니라 최악 프레임이 60fps 여유를 정한다.
## 가장 무거운 방향(알갱이 — 픽셀마다 이웃 아홉 칸)을 기준으로 잰다.
func _measure(delta: float) -> bool:
	if _frames == _WARMUP_FRAMES:
		_showcase.call("apply_variant", "grain")
	if _frames < _WARMUP_FRAMES * 2:
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
