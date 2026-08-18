extends SceneTree
## 창의 재료를 뽑는다.
##
##     godot --path . -s res://tools/capture_material.gd -- .renders/37-material still
##     godot --path . -s res://tools/capture_material.gd -- .renders/mat film
##
## **흐르는 무늬는 정지로 판정이 안 된다.** 「장」과 「금속」이 특히 그렇다.
##
## 창에 셰이더가 걸려 있으므로 **헤드리스로는 안 나온다** — 창을 띄워 뽑는다.

const FPS: float = 20.0
const SHEET := Vector2i(1240, 1560)
const STILL_AT: float = 1.30
const SETTLE := 12

var _prefix := "res://.renders/material"
var _film := false
var _stage: SubViewport
var _bench: MaterialBench
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
	_bench = load("res://src/ui/kit/material_bench.tscn").instantiate() as MaterialBench
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
	if _saved < int(MaterialBench.LOOP * FPS):
		return false
	print("프레임 %d 장: %s" % [_saved, _prefix])
	return true
