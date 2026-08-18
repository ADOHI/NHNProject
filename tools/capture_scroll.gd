extends SceneTree
## 긴 열전을 흘렸을 때 형태 여섯이 어떻게 되는지 뽑는다. **손으로 굴려서 뽑는다.**
##
##     godot --path . -s res://tools/capture_scroll.gd -- .renders/32-scroll still
##     godot --path . -s res://tools/capture_scroll.gd -- .renders/scr film
##     python tools/make_gif.py .renders/scr .renders/32-scroll.gif 0.46
##
## **정지 한 장으로는 절반도 안 된다.** 여기서 보려는 것이 「글이 흐르는 동안 형태가
## 흔들리는가」라서 GIF 가 판정 매체다. 정지는 흐르는 도중 한 장일 뿐이다.
##
## ## 시계가 굴리던 것을 손이 굴린다 (설계 20.24)
##
## 예전에는 `set_clock()` 하나가 **여는 것과 굴리는 것을 둘 다** 했다. 그런데
## §20.22.5 가 `ScrollBench.wheel()` 을 붙이면서 갈랐다 —
##
## > **시계는 늘 같은 속도로 같은 데까지만 굴린다. 그리고 한 번도 멈추지 않는다.
## > 사람은 한 칸 굴리고 읽는다.** 흔들림은 **멈춰 있는 동안** 읽히는 값이다.
##
## 그래서 굴리는 것만 `wheel()` 로 옮겼다. **여는 것은 시계가 그대로 맡는다** —
## 창이 열리는 것에는 사람이 하는 조작이 없기 때문이다. 그것이 이 저장소가
## 「대역」과 「설계」를 가르는 선이다.

const FPS: float = 20.0

## 창과 무관한 좌표계. `--resolution` 을 쓰면 창이 화면 높이에 잘리고
## `stretch/mode="canvas_items"` 때문에 배율까지 바뀐다(`capture_ledger.gd` 참고).
const SHEET := Vector2i(1280, 1600)

## 언제 휠을 한 칸 내리나. **띄엄띄엄이다** — 사람은 굴리고 멈춰서 읽는다.
## 그 멈춤이 흔들림을 읽는 자리다.
##
## 이 대본이 글 끝까지 닿는지는 `test_scroll_bench_hand.gd` 가 **창 없이** 잰다.
## 칸 수는 **글 분량이 정한다.** 인물 상세를 다시 짤 때마다 바뀌었다 —
## 아홉 → 여덟 → 열. 눈으로 맞추지 않고 `test_scroll_bench_hand.gd` 가
## **창 없이** 「끝까지 닿나 · 남는 칸이 없나」를 재서 잡아 준다.
##
## 띄엄띄엄인 이유는 §20.24.3 이다 — 사람은 굴리고 멈춰서 읽는다.
const SCRIPT_AT := [0.60, 0.85, 1.10, 1.60, 1.85, 2.10, 2.55, 2.80, 3.05, 3.45]

## 절반쯤 흘러간 순간.
const STILL_AT: float = 2.20
const SETTLE := 8

var _prefix := "res://.renders/scroll"
var _film := false
var _stage: SubViewport
var _bench: ScrollBench
var _waited := 0
var _saved := 0
var _posed := -1
var _did := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = "res://%s" % args[0]
	_film = args.size() > 1 and args[1] == "film"

	_stage = SubViewport.new()
	_stage.size = SHEET
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_stage)

	_bench = load("res://src/ui/kit/scroll_bench.tscn").instantiate() as ScrollBench
	_bench.drive_externally()
	_stage.add_child(_bench)
	_bench.size = Vector2(SHEET)


func _process(_delta: float) -> bool:
	_waited += 1
	if _waited <= SETTLE:
		# **정지는 자리를 잡아 둔 채로 가라앉혀야 한다.** 여기서 시계를 0 으로 두면
		# 마지막으로 그려진 프레임이 **창이 닫힌 상태**가 되고, 그대로 찍혀 빈 판이 나온다.
		# 실제로 그 그림을 한 장 뽑았다 — 카드 여섯이 전부 비어 있었다.
		if _film:
			_bench.set_clock(0.0)
		else:
			_pose(STILL_AT)
		return false
	if not _film:
		_pose(STILL_AT)
		var path := _prefix if _prefix.ends_with(".png") else _prefix + ".png"
		print("정지: %s (err=%d)" % [path, _stage.get_texture().get_image().save_png(path)])
		return true
	if _posed != _saved:
		_pose(float(_saved) / FPS)
		_posed = _saved
		return false
	_stage.get_texture().get_image().save_png("%s_f%03d.png" % [_prefix, _saved])
	_saved += 1
	if _saved < int(ScrollBench.LOOP * FPS):
		return false
	print("프레임 %d 장: %s" % [_saved, _prefix])
	return true


## 시각 `now` 의 화면을 앉힌다. **시계를 꽂은 다음에 손짓을 낸다** —
## 손짓은 그 시각의 자리에서 이어받는다.
func _pose(now: float) -> void:
	_bench.set_clock(now)
	while _did < SCRIPT_AT.size() and float(SCRIPT_AT[_did]) <= now:
		_bench.wheel(-1)
		_did += 1
