extends SceneTree
## 버튼 화면을 **정지 한 장과 움직이는 그림으로 같이** 뽑는다.
##
##     godot --path . --resolution 1280x720 -s res://tools/capture_button.gd \
##       -- .renders/button still
##     godot --path . --resolution 1280x720 -s res://tools/capture_button.gd \
##       -- .renders/btn film
##     python tools/make_gif.py .renders/btn .renders/button.gif
##
## 시계를 `_process(delta)` 에 맡기면 창이 60Hz 인지 165Hz 인지에 따라 같은 프레임
## 번호가 다른 순간을 찍는다. 그래서 **프레임 번호에서 시각을 계산해** 밀어 넣는다.

## GIF 의 지연 단위가 1/100초라 20fps = 정확히 5 단위다. `make_gif.py` 와 같아야 한다.
const FPS: float = 20.0

## 정지 한 장을 뽑을 시각. 커서가 자리잡고 광택이 판 복판에 있는 순간이다.
const STILL_AT: float = 1.28

## `add_child()` 뒤에 `_ready()` 가 그 자리에서 돌지 않는다. 텍스처 로드와 첫
## 그리기가 끝날 시간을 준다 — **A 를 캡처했는데 B 가 나온** 사고가 여기서 났다.
const SETTLE := 6

var _prefix := "res://.renders/button"
var _film := false
var _bench: ButtonBench
var _waited := 0
var _saved := 0

## 지금 화면에 앉혀 둔 프레임 번호. `-1` 은 아직 아무것도 안 앉혔다는 뜻이다.
var _posed := -1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = "res://%s" % args[0]
	_film = args.size() > 1 and args[1] == "film"
	_bench = load("res://src/ui/kit/button_bench.tscn").instantiate() as ButtonBench
	# **`add_child()` 앞이어야 한다.** 뒤에서 끄면 나중에 도는 `_ready()` 가 켠다.
	_bench.drive_externally()
	root.add_child(_bench)


func _process(_delta: float) -> bool:
	_waited += 1
	if _waited <= SETTLE:
		_bench.set_clock(STILL_AT if not _film else 0.0)
		return false

	if not _film:
		_bench.set_clock(STILL_AT)
		var image := root.get_texture().get_image()
		var path := _prefix if _prefix.ends_with(".png") else _prefix + ".png"
		print("정지: %s (err=%d)" % [path, image.save_png(path)])
		return true

	# **자세를 앉힌 프레임을 그 자리에서 읽으면 한 칸 전 그림이 나온다.**
	# `_process` 는 그리기 **전**에 돌므로, 앉힌 다음 한 프레임을 흘려보내야 한다.
	if _posed != _saved:
		_bench.set_clock(float(_saved) / FPS)
		_posed = _saved
		return false
	root.get_texture().get_image().save_png("%s_f%03d.png" % [_prefix, _saved])
	_saved += 1
	if _saved < int(ButtonBench.LOOP * FPS):
		return false
	print("프레임 %d 장: %s" % [_saved, _prefix])
	return true
