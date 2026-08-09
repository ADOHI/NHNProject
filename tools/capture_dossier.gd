extends SceneTree
## 인물 상세를 형태 넷에 얹은 화면을 뽑는다.
##
##     godot --path . --resolution 1280x640 \
##         -s res://tools/capture_dossier.gd -- .renders/30-dossier still
##     godot --path . --resolution 1280x640 -s res://tools/capture_dossier.gd -- .renders/dos film
##
## **넘침 표시가 이 캡처의 결과물이다.** 형태가 예쁜지가 아니라 글이 들어가는지를 본다.

const FPS: float = 20.0
const STILL_AT: float = 1.20
const SETTLE := 8

var _prefix := "res://.renders/dossier"
var _film := false
var _bench: DossierBench
var _waited := 0
var _saved := 0
var _posed := -1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = "res://%s" % args[0]
	_film = args.size() > 1 and args[1] == "film"
	_bench = load("res://src/ui/kit/dossier_bench.tscn").instantiate() as DossierBench
	_bench.drive_externally()
	root.add_child(_bench)


func _process(_delta: float) -> bool:
	_waited += 1
	if _waited <= SETTLE:
		_bench.set_clock(STILL_AT if not _film else 0.0)
		return false
	if not _film:
		_bench.set_clock(STILL_AT)
		var path := _prefix if _prefix.ends_with(".png") else _prefix + ".png"
		print("정지: %s (err=%d)" % [path, root.get_texture().get_image().save_png(path)])
		return true
	if _posed != _saved:
		_bench.set_clock(float(_saved) / FPS)
		_posed = _saved
		return false
	root.get_texture().get_image().save_png("%s_f%03d.png" % [_prefix, _saved])
	_saved += 1
	if _saved < int(DossierBench.LOOP * FPS):
		return false
	print("프레임 %d 장: %s" % [_saved, _prefix])
	return true
