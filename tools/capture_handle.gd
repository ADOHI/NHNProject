extends SceneTree
## 형태가 자리를 말하는지 뽑는다.
##
##     godot --path . -s res://tools/capture_handle.gd -- .renders/34-scroll-handle
##
## **정지 한 장이 판정 매체다.** 자리 표시는 위치의 함수지 시간의 함수가 아니라서,
## 같은 형태를 처음 | 중간 | 끝 세 자리에 나란히 놓은 한 장이 GIF 보다 낫다.
## 움직이는 판본은 `.renders/32-scroll.gif` 에 있다.

## 카드 아홉(형태 셋 x 자리 셋). 카드는 596x428 그대로라 배율 1.0 에서 실제 크기다.
const SHEET := Vector2i(1888, 1660)
const SETTLE := 8

var _prefix := "res://.renders/34-scroll-handle"
var _stage: SubViewport
var _bench: HandleBench
var _waited := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = "res://%s" % args[0]
	_stage = SubViewport.new()
	_stage.size = SHEET
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_stage)
	_bench = load("res://src/ui/kit/handle_bench.tscn").instantiate() as HandleBench
	_bench.drive_externally()
	_stage.add_child(_bench)
	_bench.size = Vector2(SHEET)


func _process(_delta: float) -> bool:
	_waited += 1
	if _waited <= SETTLE:
		_bench.set_clock(0.0)
		return false
	var path := _prefix if _prefix.ends_with(".png") else _prefix + ".png"
	print("정지: %s (err=%d)" % [path, _stage.get_texture().get_image().save_png(path)])
	return true
