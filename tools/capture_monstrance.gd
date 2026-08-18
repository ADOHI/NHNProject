extends SceneTree
## 컨셉 「현시」를 **정지 한 장과 움직이는 그림으로 같이** 뽑는다.
##
##     godot --path . --resolution 1280x720 -s res://tools/capture_monstrance.gd \
##       -- .renders/monstrance still
##     godot --path . --resolution 1280x720 -s res://tools/capture_monstrance.gd \
##       -- .renders/mon film
##     python tools/make_gif.py .renders/mon .renders/monstrance.gif
##
## **정지만 내면 안 된다.** 4판은 정지 한 장으로 먼저 판정받았고 동적 요소가 아예
## 없는 상태를 보여 주게 됐다. 3판은 반대로 모션만 있고 정지 화면에 투자가 없었다.
## 둘을 같이 낸다 (docs/design/20-ui-kit.md §20.5).
##
## ## 시계를 엔진에 맡기지 않는다
##
## `_process(delta)` 로 흐르게 두면 창이 60Hz 인지 165Hz 인지에 따라 같은 프레임
## 번호가 다른 순간을 찍는다. 그러면 GIF 를 두 번 뽑아 비교할 수 없다.
## 그래서 `set_clock()` 으로 **프레임 번호에서 시각을 계산해** 밀어 넣는다.

## GIF 의 지연 단위가 1/100초라 20fps = 정확히 5 단위다. `make_gif.py` 와 같아야 한다.
const FPS: float = 20.0

## 한 바퀴. 개시(0.35초) → 상시 → 눌림 두 번이 다 들어가는 길이.
const LOOP: float = 3.0

## 눌림을 넣는 시각. 두 번 넣는 이유는 **한 번은 우연으로 보이기** 때문이다.
const PRESS_AT: Array[float] = [1.15, 2.20]

## 정지 한 장을 뽑을 시각. 개시가 끝나고 광택이 골고루 퍼진 순간이다.
const STILL_AT: float = 0.92

## `add_child()` 뒤에 `_ready()` 가 그 자리에서 돌지 않는다. 텍스처 로드와
## 첫 그리기가 끝날 시간을 준다 — **A 를 캡처했는데 B 가 나온** 사고가 여기서 났다.
const SETTLE := 6

var _prefix := "res://.renders/monstrance"
var _film := false
var _stage: MonstranceShowcase
var _waited := 0
var _saved := 0

## 지금 화면에 앉혀 둔 프레임 번호. `-1` 은 아직 아무것도 안 앉혔다는 뜻이다.
var _posed := -1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = "res://%s" % args[0]
	_film = args.size() > 1 and args[1] == "film"
	_stage = load("res://src/ui/kit/monstrance_showcase.tscn").instantiate() as MonstranceShowcase
	# **둘 다 `add_child()` 앞이어야 한다.** 뒤에서 `set_process(false)` 하면
	# 나중에 도는 `_ready()` 가 다시 켜 버리고, 그러면 시계가 두 군데서 흐른다
	# (`MonstranceShowcase._driven` 주석 — 실제로 그 사고가 났다).
	_stage.drive_externally()
	_stage.set_guide_visible(false)
	root.add_child(_stage)


## 시각 `t` 의 상태를 화면에 앉힌다. 눌림은 **가장 최근에 지나간 것**을 쓴다.
func _pose(t: float) -> void:
	var since_press := -1.0
	for at in PRESS_AT:
		var passed := t - at
		if passed >= 0.0 and passed < Monstrance.PRESS_TIME:
			since_press = passed
	_stage.set_clock(t, t, since_press)


func _process(_delta: float) -> bool:
	_waited += 1
	if _waited <= SETTLE:
		# 기다리는 동안에도 목표 자세를 잡아 둔다 — 첫 그리기가 빈 화면이면
		# 텍스처 로드 시점을 놓친다.
		_pose(STILL_AT if not _film else 0.0)
		return false

	if not _film:
		_pose(STILL_AT)
		var image := root.get_texture().get_image()
		var path := _prefix if _prefix.ends_with(".png") else _prefix + ".png"
		print("정지: %s (err=%d)" % [path, image.save_png(path)])
		return true

	# **자세를 앉힌 프레임을 그 자리에서 읽으면 한 칸 전 그림이 나온다.**
	# `_process` 는 그리기 **전**에 돌므로, 앉힌 다음 한 프레임을 흘려보내야 한다.
	if _posed != _saved:
		_pose(float(_saved) / FPS)
		_posed = _saved
		return false
	root.get_texture().get_image().save_png("%s_f%03d.png" % [_prefix, _saved])
	_saved += 1
	if _saved < int(LOOP * FPS):
		return false
	print("프레임 %d 장: %s" % [_saved, _prefix])
	return true
