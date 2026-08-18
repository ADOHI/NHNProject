extends SceneTree
## **손이 닿은 화면을 뽑는다.** 명세 넷이 실제로 되는지 한 편으로 보인다.
##
##     godot --path . -s res://tools/capture_play.gd -- .renders/play film
##     python tools/make_gif.py .renders/play .renders/39-radial-play.gif 0.72
##
## | 명세 | 이 편의 어디 |
## | --- | --- |
## | 원형 배치 + **휠로 회전** | 0.6s · 1.6s — 휠 두 번 |
## | **접혔다 펴진다** | 그 회전 중에. 접힌 모양이 그 창의 종류다 |
## | 선 연결 | 내내 — 몸의 자리마다 창이 하나씩 물려 있다 |
## | **클릭하면 확대** | 2.9s — 「성향」 창을 누른다 |
## | 확대한 뒤 **줌** | 4.2s · 4.7s — 휠이 여기서는 줌이다. 판도 글도 같은 배로 커진다 |
## | 되돌아옴 | 5.6s — 바깥을 누른다 |
##
## **판 하나만 그린다**(`only_panel`). 넷을 나란히 놓는 것은 세기를 비교할 때 쓰고,
## 「되는가」를 보일 때는 **화면 한 장이 크게 보여야** 한다.

const FPS: float = 20.0
const SHEET := Vector2i(1280, 720)

## 어느 세기로 보이나. **「세」가 이 킷이 쓰려는 자리다.**
const LEVEL: int = 2

const TOUR_TIME: float = 6.60
const SETTLE := 12

## 언제 무엇을 하나. `["wheel", 방향]` 또는 `["tap", x, y]`.
##
## **손짓에 시각을 박아 둔다.** 그래야 캡처가 몇 번을 돌아도 같은 편이 나온다 —
## 사람이 눌러 뽑으면 판정할 때마다 다른 것을 보게 된다.
const SCRIPT_AT := [
	[0.60, "wheel", -1],
	[1.60, "wheel", -1],
	[2.90, "tap", 1010.0, 360.0],
	[4.20, "wheel", 1],
	[4.70, "wheel", 1],
	[5.60, "tap", 120.0, 650.0],
]

var _prefix := "res://.renders/play"
var _stage: SubViewport
var _bench: RadialStage
var _waited := 0
var _saved := 0
var _posed := -1
var _did := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = "res://%s" % args[0]
	_stage = SubViewport.new()
	_stage.size = SHEET
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_stage)
	_bench = load("res://src/ui/kit/radial_stage.tscn").instantiate() as RadialStage
	_bench.only_panel = LEVEL
	_bench.drive_externally()
	_stage.add_child(_bench)
	_bench.size = Vector2(SHEET)


func _process(_delta: float) -> bool:
	_waited += 1
	if _waited <= SETTLE:
		_bench.set_clock(0.0)
		return false
	if _posed != _saved:
		var now := float(_saved) / FPS
		_bench.set_clock(now)
		# **시계를 꽂은 다음에 손짓을 낸다.** 손짓은 그 시각을 사건의 시작으로 적는다.
		while _did < SCRIPT_AT.size() and float(SCRIPT_AT[_did][0]) <= now:
			_act(SCRIPT_AT[_did])
			_did += 1
		_posed = _saved
		return false
	_stage.get_texture().get_image().save_png("%s_f%03d.png" % [_prefix, _saved])
	_saved += 1
	if _saved < int(TOUR_TIME * FPS):
		return false
	print("프레임 %d 장: %s" % [_saved, _prefix])
	return true


func _act(step: Array) -> void:
	if step[1] == "wheel":
		_bench.wheel(int(step[2]))
		return
	_bench.tap(Vector2(float(step[2]), float(step[3])))
