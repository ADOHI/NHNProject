extends SceneTree
## 컨셉 견본 정지 화면 한 장.
##
##     godot --path . --resolution 1280x720 -s res://tools/capture_guide.gd -- .renders/guide.png
##
## 모션을 얹기 전에 **정지 화면 한 장으로 먼저 판정받는다.**
## 모션은 정지 화면을 구원하지 못하고 그 반대는 성립한다 (20-ui-kit.md §20.3).

## `_initialize()` 안의 `add_child()` 는 `_ready()` 를 그 자리에서 부르지 않는다.
## 텍스처 로드와 첫 그리기가 끝날 시간을 준다 (§20.4).
const _SETTLE := 6

var _path := "res://.renders/guide.png"
var _frames := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_path = "res://%s" % args[0]
	root.add_child(load("res://src/ui/kit/terminal_guide.tscn").instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < _SETTLE:
		return false
	var image := root.get_texture().get_image()
	print("capture: %s (err=%d)" % [_path, image.save_png(_path)])
	return true
