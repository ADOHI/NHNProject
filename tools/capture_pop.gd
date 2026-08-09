extends SceneTree
## P5 계열 안을 **움직이는 그림**으로 뽑는다.
##
##     godot --path . -s res://tools/capture_pop.gd -- .renders/pop-slash slash
##     python tools/make_gif.py .renders/pop-slash .renders/43-pop-slash.gif 0.6
##
## docs/design/20-ui-kit.md §20.28.
##
## **움직임이 이 문법의 절반이다.** 미끄러져 들어와 탁 멈추고, 어긋나게 순차로 선다 —
## 정지 한 장으로는 「스냅」이 안 보인다. 그래서 GIF 가 판정 매체다.

const FPS := 20.0

## 대표 컷을 뽑을 시각. 전부 들어와 서 있고 팝업이 찢어져 열린 자리다.
const STILL_AT := 2.45

const SETTLE := 6

var _prefix := "res://.renders/pop"
var _which := "slash"
var _stage: SubViewport
var _sheet: Control
var _waited := 0
var _saved := 0
var _posed := -1
var _still_done := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = "res://%s" % args[0]
	if args.size() > 1:
		_which = args[1]
	_sheet = _pick()
	if _sheet == null:
		push_error("모르는 안: %s" % _which)
		quit(1)
		return
	_stage = SubViewport.new()
	_stage.size = Vector2i(SlashSheet.CARD)
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_stage)
	_sheet.call("drive_externally")
	_stage.add_child(_sheet)
	_sheet.size = SlashSheet.CARD


func _pick() -> Control:
	match _which:
		"slash":
			return SlashSheet.new()
		_:
			return null


func _process(_delta: float) -> bool:
	_waited += 1
	if _waited <= SETTLE:
		_sheet.call("set_clock", 0.0)
		return false
	if not _still_done:
		_sheet.call("set_clock", STILL_AT)
		if _posed != -2:
			_posed = -2
			return false
		_stage.get_texture().get_image().save_png("%s_still.png" % _prefix)
		print("대표 컷: %s_still.png" % _prefix)
		_still_done = true
		_posed = -1
		return false
	if _posed != _saved:
		_sheet.call("set_clock", float(_saved) / FPS)
		_posed = _saved
		return false
	_stage.get_texture().get_image().save_png("%s_f%03d.png" % [_prefix, _saved])
	_saved += 1
	if _saved < int(SlashSheet.LOOP * FPS):
		return false
	print("프레임 %d 장: %s" % [_saved, _prefix])
	return true
