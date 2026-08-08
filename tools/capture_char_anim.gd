extends SceneTree
## 애니메이션 한 바퀴를 PNG 묶음으로 남긴다. `tools/make_gif.py` 가 GIF 로 잇는다.
##
##     godot --path . -s res://tools/capture_char_anim.gd -- .renders-char-anim/idle
##     godot --path . -s res://tools/capture_char_anim.gd -- .renders-char-anim/doll off
##
## 두 번째 인자로 조절판 축을 지정한다 — `off`(넷 다 끔) 또는 축 이름 하나
## (`delay` `arc` `squash` `asymmetry`)를 주면 **그 축만 켠** 상태를 찍는다.
## 무엇이 무엇을 만드는지 GIF 를 나란히 놓고 가르기 위한 것이다.
##
## **실시간을 안 기다린다.** 시각을 직접 넣는다(`§25.3`). 그래서
##
## * 이음매가 정확히 맞는다 — `t = 0` 과 `t = LOOP` 가 같은 포즈다
## * 프레임률이 튀어도 찍히는 내용이 안 변한다
## * 25 fps · 100 프레임이면 GIF 프레임 지연이 정확히 40 ms 라 시간이 안 밀린다
##
## **함정:** `_initialize()` 에서 `add_child()` 해도 `_ready()` 가 그 자리에서 안 돈다.
## 이 저장소에서 그 때문에 **A 를 캡처했는데 B 가 나온** 사고가 있었다. 그래서
## 파츠 뷰를 `_ready()` 에 의존하지 않게 직접 `setup()` 하고, 첫 장을 저장한 뒤
## **실제로 무엇이 찍혔는지 읽어서 확인한다**(§25.7.1).

const FPS := 25
const FRAMES := 100

## 캡처 화면. 캐릭터 키 146 을 배율 3.0 으로 보므로 438 px, 위아래 여백을 두어 520.
const VIEW_SIZE := Vector2i(400, 520)
const VIEW_SCALE := 3.0
const GROUND_Y := 476.0

const SKY_TOP := Color(0.478, 0.529, 0.573)
const SKY_BOTTOM := Color(0.353, 0.396, 0.439)
const FLOOR := Color(0.298, 0.333, 0.376)
const FLOOR_LINE := Color(0.239, 0.267, 0.302)
const SKY_BANDS := 28

## 창이 자리를 잡을 준비 프레임. 첫 장이 백지로 나오는 것을 막는다.
const WARMUP_FRAMES := 8

## 배경만 찍혔는지 판정할 때 요구하는 최소 색 수. 캐릭터가 있으면 훨씬 많다.
const MIN_DISTINCT_COLORS := 12

var _out_prefix := ".renders-char-anim/idle"
var _features := AnimFeatures.all_on()
var _clip: CharClip
var _viewport: SubViewport
var _view: CharPartsView
var _warmup := WARMUP_FRAMES
var _next_frame := 0
var _pending := -1
var _verified := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_prefix = args[0]
	if args.size() > 1:
		_features = _parse_features(args[1])

	# **`SubViewport` 에 그린다.** 창 크기를 바꾸는 방법은 안 통했다 — `get_root().size` 를
	# 400x520 으로 넣어도 찍히는 것은 1280x720 이었다(늘리기 설정이 이겼다). 자기 크기를
	# 스스로 정하는 `SubViewport` 는 OS 창과 무관하므로 어느 기계에서도 같은 그림이 나온다.
	_viewport = SubViewport.new()
	_viewport.size = VIEW_SIZE
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(_viewport)

	var rig := CharRig.new()
	_clip = CharIdleClip.new(rig)

	var stage := _make_stage()
	_viewport.add_child(stage)

	_view = CharPartsView.new()
	_view.position = Vector2(float(VIEW_SIZE.x) * 0.5, GROUND_Y)
	_view.scale = Vector2(VIEW_SCALE, VIEW_SCALE)
	stage.add_child(_view)
	# `_ready()` 를 기다리지 않는다 — 여기서 직접 세운다.
	_view.setup(rig)

	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(_out_prefix).get_base_dir()
	)
	print("캡처: %s  프레임 %d  %d fps" % [_out_prefix, FRAMES, FPS])
	print(
		(
			"조절판: 지연 %.1f 호 %.1f 배율 %.1f 비대칭 %.1f"
			% [_features.delay, _features.arc, _features.squash, _features.asymmetry]
		)
	)


func _process(_delta: float) -> bool:
	if _warmup > 0:
		_warmup -= 1
		return false

	# 앞 프레임에 넣은 포즈가 이제 그려져 있다. 그것을 저장한다.
	if _pending >= 0:
		if not _save(_pending):
			return true
		_pending = -1

	if _next_frame >= FRAMES:
		print("완료: %d 장" % FRAMES)
		return true

	# 시각을 직접 넣는다. 한 바퀴를 FRAMES 등분하므로 마지막 다음이 정확히 처음이다.
	var t := _clip.loop_seconds() * float(_next_frame) / float(FRAMES)
	_view.apply_pose(_clip.sample(t, _features))
	_pending = _next_frame
	_next_frame += 1
	return false


func _parse_features(spec: String) -> AnimFeatures:
	if spec == "off":
		return AnimFeatures.all_off()
	if spec == "on":
		return AnimFeatures.all_on()
	if spec in ["delay", "arc", "squash", "asymmetry"]:
		return AnimFeatures.only(spec)
	push_error("모르는 조절판 지정: %s" % spec)
	return AnimFeatures.all_on()


func _make_stage() -> Node2D:
	var stage := Node2D.new()
	stage.name = "Stage"
	stage.draw.connect(_draw_stage.bind(stage))
	return stage


func _draw_stage(stage: Node2D) -> void:
	var width := float(VIEW_SIZE.x)
	for i in SKY_BANDS:
		var u := float(i) / float(SKY_BANDS)
		var band := Rect2(0.0, GROUND_Y * u, width, GROUND_Y / float(SKY_BANDS) + 1.0)
		stage.draw_rect(band, SKY_TOP.lerp(SKY_BOTTOM, u))
	stage.draw_rect(Rect2(0.0, GROUND_Y, width, float(VIEW_SIZE.y) - GROUND_Y), FLOOR)
	stage.draw_line(Vector2(0.0, GROUND_Y), Vector2(width, GROUND_Y), FLOOR_LINE, 2.0)


## 한 장 저장. 첫 장에서만 **실제로 무엇이 찍혔는지 읽어서 확인한다.**
func _save(index: int) -> bool:
	var image := _viewport.get_texture().get_image()
	if not _verified:
		if not _verify(image):
			return false
		_verified = true
	var path := "%s_%03d.png" % [_out_prefix, index]
	var error := image.save_png(path)
	if error != OK:
		push_error("저장 실패: %s (%d)" % [path, error])
		return false
	return true


## 배경만 찍혔거나 백지가 나온 것을 잡는다. 캡처는 눈으로 확인하기 전까지 거짓말한다.
func _verify(image: Image) -> bool:
	if image.get_width() != VIEW_SIZE.x or image.get_height() != VIEW_SIZE.y:
		push_error(
			(
				"화면 크기가 요청과 다르다: %dx%d (요청 %dx%d)"
				% [image.get_width(), image.get_height(), VIEW_SIZE.x, VIEW_SIZE.y]
			)
		)
		return false
	var seen := {}
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			seen[image.get_pixel(x, y).to_rgba32()] = true
	if seen.size() < MIN_DISTINCT_COLORS:
		push_error("배경만 찍혔다 — 색이 %d 가지뿐이다. 캐릭터가 안 그려졌다" % seen.size())
		return false
	print("확인: %dx%d, 색 %d 가지" % [image.get_width(), image.get_height(), seen.size()])
	return true
