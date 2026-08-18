extends SceneTree
## 방 종류 확인 화면을 컨셉 배색마다 한 장씩 뽑는다.
##
##     godot --path . --resolution 1180x620 -s res://tools/capture_rooms.gd -- .renders/rooms
##
## 창을 한 번만 띄우고 다섯 장을 몰아 찍는다. gl_compatibility 라 창을 띄울 때마다
## GL 컨텍스트를 새로 만들고, 그 반복이 드라이버를 흔든 전례가 있다.

const _CONCEPTS := ["slam", "shear", "hold", "squash", "afterimage"]

## `_initialize()` 안의 `add_child()` 는 `_ready()` 를 그 자리에서 부르지 않는다.
## 그래서 첫 프레임에는 아무것도 건드리지 않는다 (20-ui-kit.md §20.4).
const _SETTLE := 3

var _prefix := "res://.renders/rooms"
var _frames := 0
var _saved := 0
var _matrix: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = "res://%s" % args[0]
	_matrix = load("res://src/ui/kit/room_matrix.tscn").instantiate()
	root.add_child(_matrix)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < _SETTLE:
		return false
	if _saved >= _CONCEPTS.size():
		return true
	var name: String = _CONCEPTS[_saved]
	_matrix.call("set_concept", name)
	# 다시 그려질 시간을 한 프레임 준다.
	if _frames < _SETTLE + _saved * 2 + 1:
		return false
	var image := root.get_texture().get_image()
	var err := image.save_png("%s_%s.png" % [_prefix, name])
	print("capture: %s_%s.png (err=%d)" % [_prefix, name, err])
	_saved += 1
	return false
