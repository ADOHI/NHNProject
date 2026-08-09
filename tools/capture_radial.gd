extends SceneTree
## 원형 인물 배치와 홀로그램 창을 뽑는다.
##
##     godot --path . -s res://tools/capture_radial.gd -- .renders/36-radial-center still
##     godot --path . -s res://tools/capture_radial.gd -- .renders/rad film
##     python tools/make_gif.py .renders/rad .renders/36-radial-center.gif 0.33
##
## **접힘과 펴짐은 정지로 판정이 아예 안 된다.** GIF 가 판정 매체다.

const FPS: float = 20.0

## 태블릿 넷. 판 하나가 1280x720 이라 창 크기가 거짓말을 안 한다.
const SHEET := Vector2i(2620, 1760)

## 창이 다 펴진 순간.
const STILL_AT: float = 2.60
const SETTLE := 10

var _prefix := "res://.renders/radial"
var _film := false
var _stage: SubViewport
var _bench: RadialStage
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
	_bench = load("res://src/ui/kit/radial_stage.tscn").instantiate() as RadialStage
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
	if _saved < int(RadialStage.LOOP * FPS):
		return false
	print("프레임 %d 장: %s" % [_saved, _prefix])
	return true
