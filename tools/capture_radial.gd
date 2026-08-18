extends SceneTree
## 원형 인물 배치 + 홀로그램 창 + 사건에 붙는 이펙트를 뽑는다.
##
##     godot --path . -s res://tools/capture_radial.gd -- .renders/38-radial-vfx still
##     godot --path . -s res://tools/capture_radial.gd -- .renders/rad film
##     python tools/make_gif.py .renders/rad .renders/38-radial-vfx.gif 0.33
##
## **접힘 · 펴짐 · 궤적 · 파문이 전부 사건이라 정지로는 판정이 안 된다.** GIF 가 판정 매체다.
##
## 그래도 정지를 **세 장** 낸다 — 이 킷의 논지가 **조용한 한 장과 터지는 한 장의 차이**라서
## 둘을 나란히 놓아야 「사건에만 붙는다」가 눈에 보인다.
## 창을 한 번 띄워 세 장을 몰아 뽑는다(`CLAUDE.md` GPU 규칙 3).

const FPS: float = 20.0

## 태블릿 넷. 판 하나가 1280x720 이라 창 크기가 거짓말을 안 한다.
const SHEET := Vector2i(2620, 1760)

## 정지 세 장 — 언제와 그때 무엇이 보이나.
##
## | 꼬리표 | 시각 | 무엇이 걸리나 |
## | --- | --- | --- |
## | (없음) | 2.60 | **조용한 한 장.** 창 다 펴짐 · 재료 다섯 · 신호 한 선 · 티끌 |
## | `-burst` | 2.98 | 누른 직후 — 파문과 섬광 |
## | `-turn` | 4.14 | 도는 중 — 접힘 · 흩어지는 조각 · 궤적 |
const STILLS := [["", 2.60], ["-burst", 2.98], ["-turn", 4.14]]

const SETTLE := 10

var _prefix := "res://.renders/radial"
var _film := false
var _stage: SubViewport
var _bench: RadialStage
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
	_bench = load("res://src/ui/kit/radial_stage.tscn").instantiate() as RadialStage
	_bench.drive_externally()
	_stage.add_child(_bench)
	_bench.size = Vector2(SHEET)


func _process(_delta: float) -> bool:
	_waited += 1
	if _waited <= SETTLE:
		_bench.set_clock(float(STILLS[0][1]) if not _film else 0.0)
		return false
	if not _film:
		return _still()
	if _posed != _saved:
		_bench.set_clock(float(_saved) / FPS)
		_posed = _saved
		return false
	_stage.get_texture().get_image().save_png("%s_f%03d.png" % [_prefix, _saved])
	_saved += 1
	if _saved < int(RadialStage.LOOP * FPS):
		return false
	print("프레임 %d 장: %s" % [_saved, _prefix])
	return true


## 정지 한 장. **시계를 꽂은 다음 프레임에 저장한다** — 같은 프레임에 저장하면
## 셰이더가 새 시각을 아직 안 받은 그림이 나온다.
func _still() -> bool:
	if _posed != _saved:
		_bench.set_clock(float(STILLS[_saved][1]))
		_posed = _saved
		return false
	var stem := _prefix.trim_suffix(".png")
	var path := "%s%s.png" % [stem, STILLS[_saved][0]]
	print("정지: %s (err=%d)" % [path, _stage.get_texture().get_image().save_png(path)])
	_saved += 1
	return _saved >= STILLS.size()
