extends SceneTree
## 팝업 화면을 정지 한 장과 움직이는 그림으로 뽑는다.
##
##     godot --path . --resolution 1280x760 -s res://tools/capture_popup.gd -- .renders/20-popups still
##     godot --path . --resolution 1280x760 -s res://tools/capture_popup.gd -- .renders/pop film
##
## **팝업은 정지 화면으로 판정할 수 없다.** 사건이 열림과 닫힘이라 상태가 아니라
## 지나가는 일이다. 정지 한 장은 「열린 뒤」를 보여 줄 뿐이고 판정은 GIF 로 한다.

const FPS: float = 20.0

## 정지 한 장을 뽑을 시각. 여섯이 다 열려 내용까지 든 뒤다.
const STILL_AT: float = 1.30

const SETTLE := 6

var _prefix := "res://.renders/popups"
var _film := false
var _bench: PopupBench
var _waited := 0
var _saved := 0
var _posed := -1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = "res://%s" % args[0]
	_film = args.size() > 1 and args[1] == "film"
	_bench = load("res://src/ui/kit/popup_bench.tscn").instantiate() as PopupBench
	_bench.drive_externally()
	root.add_child(_bench)


func _process(_delta: float) -> bool:
	_waited += 1
	if _waited <= SETTLE:
		_bench.set_clock(STILL_AT if not _film else 0.0)
		return false

	if not _film:
		_bench.set_clock(STILL_AT)
		var image := root.get_texture().get_image()
		var path := _prefix if _prefix.ends_with(".png") else _prefix + ".png"
		print("정지: %s (err=%d)" % [path, image.save_png(path)])
		return true

	if _posed != _saved:
		_bench.set_clock(float(_saved) / FPS)
		_posed = _saved
		return false
	root.get_texture().get_image().save_png("%s_f%03d.png" % [_prefix, _saved])
	_saved += 1
	if _saved < int(PopupBench.LOOP * FPS):
		return false
	print("프레임 %d 장: %s" % [_saved, _prefix])
	return true
