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

## GIF 로 뽑을 팔레트. 정지는 전부 뽑고 **움직이는 그림은 하나만** 뽑는다 —
## 다섯 편을 다 뽑으면 판정할 것이 다섯 배가 되고 그러면 아무도 안 본다.
const PICK := 0

var _prefix := "res://.renders/pop"
var _which := "slash"
var _stage: SubViewport
var _sheet: Control
var _waited := 0
var _saved := 0
var _posed := -1
var _still_done := false

## 안마다 크기와 한 바퀴가 다르다. **여기서 하나로 정하면 안이 늘 때 조용히 잘린다.**
var _card := Vector2(660.0, 700.0)
var _loop := 4.0

## 지금까지 몇 번째 팔레트를 찍었나.
var _swatch := 0


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
	_stage.size = Vector2i(_card)
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_stage)
	_sheet.call("drive_externally")
	_stage.add_child(_sheet)
	_sheet.size = _card


func _pick() -> Control:
	match _which:
		"slash":
			_card = SlashSheet.CARD
			_loop = SlashSheet.LOOP
			return SlashSheet.new()
		"amber":
			_card = AmberSheet.CARD
			_loop = AmberSheet.LOOP
			return AmberSheet.new()
		_:
			return null


## 팔레트마다 대표 컷을 한 장씩, 그다음 GIF 용 팔레트로 한 장.
##
## **창을 한 번만 띄우고 다 뽑는다** (CLAUDE.md — GPU 를 나눠 쓴다).
## 다 끝났으면 참을 낸다.
func _stills() -> bool:
	_sheet.call("set_clock", STILL_AT)
	if _swatch < HoloPalette.count():
		_sheet.set("palette", _swatch)
		if _posed != -2 - _swatch:
			_posed = -2 - _swatch
			return false
		var slug: String = HoloPalette.slug(_swatch)
		_stage.get_texture().get_image().save_png("%s_%s.png" % [_prefix, slug])
		print("팔레트 %s: %s_%s.png" % [HoloPalette.name_of(_swatch), _prefix, slug])
		_swatch += 1
		return false
	_sheet.set("palette", PICK)
	if _posed != -99:
		_posed = -99
		return false
	_stage.get_texture().get_image().save_png("%s_still.png" % _prefix)
	print("대표 컷: %s_still.png" % _prefix)
	_posed = -1
	return true


func _process(_delta: float) -> bool:
	_waited += 1
	if _waited <= SETTLE:
		_sheet.call("set_clock", 0.0)
		return false
	if not _still_done:
		_still_done = _stills()
		return false

	if _posed != _saved:
		_sheet.call("set_clock", float(_saved) / FPS)
		_posed = _saved
		return false
	_stage.get_texture().get_image().save_png("%s_f%03d.png" % [_prefix, _saved])
	_saved += 1
	if _saved < int(_loop * FPS):
		return false
	print("프레임 %d 장: %s" % [_saved, _prefix])
	return true
