extends SceneTree
## **재료마다 얼마나 무거운가.** 안 재고 「가벼울 것이다」 쓰지 않는다.
##
##     godot --path . -s res://tools/measure_shader_cost.gd
##
## 웹 빌드는 `gl_compatibility`(WebGL 2) 단일 스레드다. **전체 화면 셰이더는 채움률을
## 먹고 창이 여섯이면 셰이더도 여섯이다.** 그래서 재는 단위를 **창 여섯 장 넓이**로
## 잡는다 — 실제로 화면에 뜰 모양 그대로다.
##
## 벽시계로 잰다. 절대값은 이 기계의 것이고, **재료끼리의 비가 옮겨 갈 수 있는 값**이다.

## **채움률을 재는 것이라 넓이가 곧 부하다.** 창 여섯 장으로는 프레임 상한에 걸려
## 다섯 재료가 전부 같은 값이 나왔다 — **재는 값이 상한보다 작으면 상한을 잰 것이다.**
## 그래서 화면을 덮을 만큼 늘리고 프레임 상한을 푼다.
const PANES: int = 24
const PANE := Vector2(460.0, 300.0)
const FRAMES: int = 120
const WARMUP: int = 30

var _stage: SubViewport
var _panes: Array[HoloPane] = []
var _which := 0
var _frame := 0
var _began := 0
var _plain := 0.0
var _lines: Array[String] = []


func _initialize() -> void:
	_stage = SubViewport.new()
	# 프레임 상한을 푼다. 안 풀면 셰이더가 아니라 상한을 재게 된다.
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_stage.size = Vector2i(1920, 1080)
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_stage)
	for i in PANES:
		var pane := HoloPane.new()
		_stage.add_child(pane)
		pane.position = Vector2(float(i % 4) * 470.0, float(i / 4) * 175.0)
		pane.size = PANE
		_panes.append(pane)
	_which = -1
	_dress(-1)
	print(
		(
			"창 %d 장 x %s px = %.1f 배 화면 넓이, %d 프레임"
			% [PANES, PANE, float(PANES) * PANE.x * PANE.y / (1920.0 * 1080.0), FRAMES]
		)
	)


## `which` 가 -1 이면 셰이더를 뗀다. **셰이더의 몫이 얼마인지는 뗀 것과 비교해야 안다.**
func _dress(which: int) -> void:
	for pane in _panes:
		if which < 0:
			pane.material = null
			pane.queue_redraw()
		else:
			pane.set_stuff(which as HoloPane.Stuff, 1.0)


func _process(_delta: float) -> bool:
	_frame += 1
	for pane in _panes:
		pane.set_clock(float(_frame) * 0.05)
	if _frame == WARMUP:
		_began = Time.get_ticks_usec()
	if _frame < WARMUP + FRAMES:
		return false
	var spent := float(Time.get_ticks_usec() - _began) / 1000.0
	var each := spent / float(FRAMES)
	if _which < 0:
		_plain = each
	var who := "셰이더 없음" if _which < 0 else HoloPane.label(_which as HoloPane.Stuff)
	var against := (
		"기준"
		if _which < 0
		else "맨판의 %.2f 배 (+%.3f ms)" % [each / maxf(_plain, 0.0001), each - _plain]
	)
	_lines.append("%-7s %7.3f ms/프레임   %s" % [who, each, against])
	_which += 1
	if _which >= HoloPane.count():
		for line in _lines:
			print(line)
		return true
	_dress(_which)
	_frame = 0
	return false
