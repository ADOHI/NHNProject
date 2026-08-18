extends SceneTree
## 층을 쌓은 안을 **움직이는 그림**으로 뽑는다.
##
##     godot --path . -s res://tools/capture_lush.gd -- .renders/lush-molten molten
##     python tools/make_gif.py .renders/lush-molten .renders/42-lush-molten.gif
##
## docs/design/20-ui-kit.md §20.27.
##
## ## 정지로는 절반도 안 보인다
##
## 사용자가 말한 「화려하게」가 **그림체 · 쉐이더 · VFX** 인데 **VFX 는 정지 화면에 없다.**
## 그래서 이 도구는 정지를 안 낸다 — 프레임을 내고 GIF 가 판정 매체다.
##
## 마지막 한 장(`_still.png`)만 따로 남긴다. 문서에 박을 대표 컷이다.

const FPS := 20.0

## 대표 컷을 뽑을 시각. 올림과 눌림이 둘 다 살아 있는 자리다.
const STILL_AT := 1.15

const SETTLE := 8

var _prefix := "res://.renders/lush"
var _which := "molten"
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
	_stage.size = Vector2i(MoltenSheet.CARD)
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_stage)
	_sheet.call("drive_externally")
	_stage.add_child(_sheet)
	_sheet.size = MoltenSheet.CARD


func _pick() -> Control:
	match _which:
		"molten":
			return MoltenSheet.new()
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
	if _saved < int(MoltenSheet.LOOP * FPS):
		return false
	print("프레임 %d 장: %s" % [_saved, _prefix])
	return true
