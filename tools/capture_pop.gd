extends SceneTree
## P5 계열 안을 **움직이는 그림**으로 뽑는다.
##
##     godot --path . -s res://tools/capture_pop.gd -- .renders/pop-slash slash
##     godot --path . -s res://tools/capture_pop.gd -- .renders/46-tone slash stills
##     python tools/make_gif.py .renders/pop-slash .renders/43-pop-slash.gif 0.6
##
## 세 번째 낱말이 `stills` 면 **정지 컷만 뽑고 끝낸다.** 색을 판정하는 판에서는
## 편이 여든 장 필요 없고, 그 여든 장이 GL 컨텍스트를 그만큼 더 쥔다
## (CLAUDE.md — GPU 를 나눠 쓴다).
##
## docs/design/20-ui-kit.md §20.28.
##
## **움직임이 이 문법의 절반이다.** 미끄러져 들어와 탁 멈추고, 어긋나게 순차로 선다 —
## 정지 한 장으로는 「스냅」이 안 보인다. 그래서 GIF 가 판정 매체다.

const FPS := 20.0

## 대표 컷을 뽑을 시각. **고른 줄과 올린 줄이 서로 다른 줄에 나란히 있는 자리**다
## (§20.39.5 의 3.3~4.4 초). 둘이 같은 줄에 겹치는 시각을 고르면 정지 컷에서
## 「같은 축의 반」이 구분되는지를 못 본다.
const STILL_AT := 3.80

const SETTLE := 6

## GIF 로 뽑을 팔레트. 정지는 전부 뽑고 **움직이는 그림은 하나만** 뽑는다 —
## 네 편을 다 뽑으면 판정할 것이 네 배가 되고 그러면 아무도 안 본다.
##
## 「야시장」이다 — 마젠타 · 시안 · 주황이 **색상환에서 셋 다 멀고 셋 다 세서**
## 포인트를 셋으로 가른 것이 가장 또렷하게 보인다. 앞서 쓰던 「단청」(0번)은
## 여섯 벌 중 유일하게 얌전한 벌이라 **도발을 재는 편에는 안 맞는다** (§20.40.3).
const PICK := 3

var _prefix := "res://.renders/pop"
var _which := "slash"
var _stage: SubViewport
var _sheet: Control
var _waited := 0
var _saved := 0
var _posed := -1
var _still_done := false

## 정지 컷만 뽑고 끝낼 것인가.
var _stills_only := false

## 단 수를 1..5 로 훑어 한 장씩 뽑을 것인가. **몇 단이 한계인지는 나란히 놓아야 안다**
## (§20.43.2). 팔레트는 `PICK` 하나로 고정한다 — 재는 것이 색이 아니라 깊이다.
var _tier_sweep := false
var _tier := 1

## 강조를 **선명함만**으로 할 것인가, **선명함 + 자리**로 할 것인가를 나란히 뽑는다
## (§20.44.6). 확정된 「자리」와 새 컨셉이 같은 일을 하므로 견줘서 하나를 내린다.
var _place_sweep := false
var _place := 0

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
	if args.size() > 2:
		_stills_only = args[2] == "stills"
		_tier_sweep = args[2] == "tiers"
		_place_sweep = args[2] == "place"
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
	# **반환을 한 곳으로 모은다.** 갈래마다 돌려보내면 갈래가 늘 때마다
	# 반환문이 늘고, 그 수가 컨벤션(max-returns)에 걸린다.
	var made: Control = null
	match _which:
		"ring":
			_card = NoiseRadial.CARD
			_loop = NoiseRadial.LOOP
			made = NoiseRadial.new()
		"person":
			_card = NoiseDossier.CARD
			_loop = NoiseDossier.LOOP
			made = NoiseDossier.new()
		"noise":
			_card = NoiseSheet.CARD
			_loop = NoiseSheet.LOOP
			made = NoiseSheet.new()
		"slash":
			_card = SlashSheet.CARD
			_loop = SlashSheet.LOOP
			made = SlashSheet.new()
		"field":
			_card = FieldSheet.CARD
			_loop = FieldSheet.LOOP
			made = FieldSheet.new()
		"amber":
			_card = AmberSheet.CARD
			_loop = AmberSheet.LOOP
			made = AmberSheet.new()
	return made


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
	# **갈래마다 제 함수로 보낸다.** 한 함수 안에서 다 처리하면 반환문이
	# 아홉이 되고, 그 수가 컨벤션(max-returns)에 걸린다.
	_waited += 1
	if _waited <= SETTLE:
		_sheet.call("set_clock", 0.0)
		return false
	if _tier_sweep:
		return _tier_step()
	if _place_sweep:
		return _place_step()
	if not _still_done:
		_still_done = _stills()
		return false
	if _stills_only:
		print("정지 컷만: %s" % _prefix)
		return true
	return _frame_step()


## 단수를 하나씩 올려 가며 한 장씩. 다 돌았으면 참.
func _tier_step() -> bool:
	_sheet.set("palette", PICK)
	_sheet.call("set_clock", STILL_AT)
	_sheet.set("tiers", _tier)
	if _posed != 100 + _tier:
		_posed = 100 + _tier
		return false
	_stage.get_texture().get_image().save_png("%s_t%d.png" % [_prefix, _tier])
	print("%d 단: %s_t%d.png" % [_tier, _prefix, _tier])
	_tier += 1
	return _tier > 5


## 자리를 바꿔 가며 한 장씩. 다 돌았으면 참.
func _place_step() -> bool:
	_sheet.set("palette", PICK)
	_sheet.call("set_clock", STILL_AT)
	_sheet.set("place", _place == 1)
	if _posed != 200 + _place:
		_posed = 200 + _place
		return false
	_stage.get_texture().get_image().save_png("%s_p%d.png" % [_prefix, _place])
	print("자리 %d: %s_p%d.png" % [_place, _prefix, _place])
	_place += 1
	return _place > 1


## GIF 용 연속 프레임 한 장. 한 바퀴를 다 채웠으면 참.
func _frame_step() -> bool:
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
