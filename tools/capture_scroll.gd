extends SceneTree
## 긴 열전을 흘렸을 때 형태 여섯이 어떻게 되는지 뽑는다.
##
##     godot --path . -s res://tools/capture_scroll.gd -- .renders/32-scroll still
##     godot --path . -s res://tools/capture_scroll.gd -- .renders/scr film
##     python tools/make_gif.py .renders/scr .renders/32-scroll.gif 0.46
##
## **정지 한 장으로는 절반도 안 된다.** 여기서 보려는 것이 「글이 흐르는 동안 형태가
## 흔들리는가」라서 GIF 가 판정 매체다. 정지는 흐르는 도중 한 장일 뿐이다.

const FPS: float = 20.0

## 창과 무관한 좌표계. `--resolution` 을 쓰면 창이 화면 높이에 잘리고
## `stretch/mode="canvas_items"` 때문에 배율까지 바뀐다(`capture_ledger.gd` 참고).
const SHEET := Vector2i(1280, 1600)

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
		_bench.set_clock(STILL_AT if not _film else 0.0)
		return false
	if not _film:
		_bench.set_clock(STILL_AT)
		var path := _prefix if _prefix.ends_with(".png") else _prefix + ".png"
		print("정지: %s (err=%d)" % [path, _stage.get_texture().get_image().save_png(path)])
		return true
	if _posed != _saved:
		_bench.set_clock(float(_saved) / FPS)
		_posed = _saved
		return false
	_stage.get_texture().get_image().save_png("%s_f%03d.png" % [_prefix, _saved])
	_saved += 1
	if _saved < int(ScrollBench.LOOP * FPS):
		return false
	print("프레임 %d 장: %s" % [_saved, _prefix])
	return true
