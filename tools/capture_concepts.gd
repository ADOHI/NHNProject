extends SceneTree
## 컨셉 견본을 **움직이는 그림**으로 뽑는다.
##
##     godot --path . --resolution 960x540 -s res://tools/capture_concepts.gd -- .renders/slam
##
## 대본 한 바퀴(3.2초)를 25fps 로 찍어 `<앞머리>_f000.png` ... 로 저장한다.
## GIF 조립은 `tools/make_gif.py` 가 한다 — 엔진 안에서 팔레트를 짜는 것보다
## 파이썬 쪽이 훨씬 싸고, 실패해도 프레임은 남는다.
##
## **정지 스틸을 뽑지 않는다.** 「톡톡 튀는가」는 정지 화면으로 판단할 수 없다.

const FPS: float = 25.0
const LOOP: float = 3.2

## 첫 프레임이 도입부 찌꺼기를 찍지 않게 한 바퀴 미리 돌린다.
const WARMUP: float = 3.2

var _prefix := "res://.renders/concept"
var _clock := 0.0
var _saved := 0
var _total := int(LOOP * FPS)
var _stage: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = "res://%s" % args[0]
	_stage = load("res://src/ui/kit/concept_stage.tscn").instantiate()
	root.add_child(_stage)
	if args.size() > 1:
		_stage.call("set_concept", args[1])
	_stage.call("set_guide_visible", false)


func _process(delta: float) -> bool:
	_clock += delta
	if _clock < WARMUP:
		return false
	# 프레임 수가 아니라 **시간**으로 찍는다. 창이 60Hz 인지 165Hz 인지에 따라
	# 같은 프레임 수가 전혀 다른 길이가 되기 때문이다.
	var want := WARMUP + float(_saved) / FPS
	if _clock < want:
		return false
	var image := root.get_texture().get_image()
	image.save_png("%s_f%03d.png" % [_prefix, _saved])
	_saved += 1
	if _saved < _total:
		return false
	print("frames: %d at %s" % [_saved, _prefix])
	return true
