extends SceneTree
## 애니메이션 한 바퀴를 PNG 묶음으로 남긴다. `tools/make_gif.py` 가 GIF 로 잇는다.
##
##     godot --path . -s res://tools/capture_char_anim.gd -- .renders-char-anim/idle
##     godot --path . -s res://tools/capture_char_anim.gd -- .renders-char-anim/walk walk
##     godot --path . -s res://tools/capture_char_anim.gd -- .renders-char-anim/skate walk noplant
##
## 첫 인자가 저장 접두사이고, 나머지는 **순서에 상관없는 낱말**이다.
##
## * 클립: `idle`(기본) · `walk` · `front`(정면 문법 대조군)
## * 조절판: `off`(다 끔) · `on`(다 켬) · 축 이름 하나면 **그 축만 켠** 상태 ·
##   `no<축>` 이면 **그 축만 끈** 상태 (`noplant` 처럼)
##
## 무엇이 무엇을 만드는지 GIF 를 나란히 놓고 가르기 위한 것이다.
##
## **`--headless` 로는 못 돌린다.** 렌더러가 없어 `get_image()` 가 널을 준다.
##
## **실시간을 안 기다린다.** 시각을 직접 넣는다(`§25.3`). 그래서
##
## * 이음매가 정확히 맞는다 — `t = 0` 과 `t = LOOP` 가 같은 포즈다
## * 프레임률이 튀어도 찍히는 내용이 안 변한다
## * 25 fps 면 GIF 프레임 지연이 정확히 40 ms 라 시간이 안 밀린다
##
## **함정:** `_initialize()` 에서 `add_child()` 해도 `_ready()` 가 그 자리에서 안 돈다.
## 이 저장소에서 그 때문에 **A 를 캡처했는데 B 가 나온** 사고가 있었다. 그래서
## 파츠 뷰를 `_ready()` 에 의존하지 않게 직접 `setup()` 하고, 첫 장을 저장한 뒤
## **실제로 무엇이 찍혔는지 읽어서 확인한다**(§25.7.1).

const FPS := 25

## 캡처 화면. 캐릭터 키 146 을 배율 3.0 으로 보므로 438 px, 위아래 여백을 두어 520.
##
## **가로를 400 에서 480 으로 넓혔다.** 무기가 손에서 앞으로 뻗으면서 날 끝이
## 오른쪽 변에 잘렸다. 무기는 캐릭터 폭 밖으로 나가는 유일한 것이라 여백이 더 필요하다.
const VIEW_SIZE := Vector2i(480, 520)
const VIEW_SCALE := 3.0
const GROUND_Y := 476.0

const SKY_TOP := Color(0.478, 0.529, 0.573)
const SKY_BOTTOM := Color(0.353, 0.396, 0.439)
const FLOOR := Color(0.298, 0.333, 0.376)
const FLOOR_LINE := Color(0.239, 0.267, 0.302)
const SKY_BANDS := 28

## 창이 자리를 잡을 준비 프레임. 첫 장이 백지로 나오는 것을 막는다.
const WARMUP_FRAMES := 8

## 캐릭터가 덮어야 하는 최소 화면 비율.
##
## **색 가짓수로 세다가 속았다.** 파츠가 하나도 안 그려진 판(스크립트가 컴파일 실패해
## 트랜스폼이 전부 튕긴 상태)에서 배경 그라데이션만으로 33 색이 나왔고, 기준이 12 색이라
## 그대로 통과했다. 배경이 화려하면 색 수는 아무것도 증명하지 않는다.
const MIN_SUBJECT_RATIO := 0.03

## 낱말로 고를 수 있는 클립과 조절판 축.
const CLIPS: Array[String] = [
	"idle",
	"walk",
	"front",
	"swing",
	"swingup",
	"swinghome",
	"hit",
	"run",
	"jump",
	"die",
]
const AXES: Array[String] = ["delay", "arc", "squash", "asymmetry", "depth", "plant"]

var _out_prefix := ".renders-char-anim/idle"
var _features := AnimFeatures.all_on()
var _clip: CharClip
var _viewport: SubViewport
var _view: CharPartsView
var _warmup := WARMUP_FRAMES
var _next_frame := 0
var _pending := -1
var _verified := false
var _frames := 0
var _cells := 1
var _span := 1
var _flourish := "none"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_prefix = args[0]
	var clip_name := "idle"
	for token: String in args.slice(1):
		if token in CLIPS:
			clip_name = token
		elif token in CharFlourish.preset_names():
			# `arc_hard` 처럼 연출 장치를 고른다. 장치마다 약/세/과 셋이 있다 (§25.23).
			_flourish = token
		elif token.begins_with("cells"):
			# `cells3` 은 3 칸 곧은 것, `cells4x2` 는 총 4 칸에 긴 쪽 2 칸(철퇴).
			# 길이와 무게를 따로 줘야 창과 철퇴가 갈린다 (§25.20).
			var spec := token.substr(5).split("x")
			_cells = int(spec[0])
			_span = int(spec[1]) if spec.size() > 1 else _cells
		else:
			_features = _parse_features(token)

	# **`SubViewport` 에 그린다.** 창 크기를 바꾸는 방법은 안 통했다 — `get_root().size` 를
	# 400x520 으로 넣어도 찍히는 것은 1280x720 이었다(늘리기 설정이 이겼다). 자기 크기를
	# 스스로 정하는 `SubViewport` 는 OS 창과 무관하므로 어느 기계에서도 같은 그림이 나온다.
	_viewport = SubViewport.new()
	_viewport.size = VIEW_SIZE
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(_viewport)

	var rig := CharRig.new()
	_clip = _make_clip(clip_name, rig)

	var stage := _make_stage()
	_viewport.add_child(stage)

	_view = CharPartsView.new()
	_view.weapon = CharWeapon.new(_cells, _span)
	_view.flourish = CharFlourish.preset(_flourish)
	_view.position = Vector2(float(VIEW_SIZE.x) * 0.5, GROUND_Y)
	_view.scale = Vector2(VIEW_SCALE, VIEW_SCALE)
	stage.add_child(_view)
	# `_ready()` 를 기다리지 않는다 — 여기서 직접 세운다.
	_view.setup(rig)

	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(_out_prefix).get_base_dir()
	)
	_frames = frame_count(_clip.loop_seconds())
	print("캡처: %s  프레임 %d  %d fps  한 바퀴 %.2f 초" % [_out_prefix, _frames, FPS, _clip.loop_seconds()])
	print(
		(
			"클립 %s [%s] / 지연 %.1f 호 %.1f 배율 %.1f 비대칭 %.1f 앞뒤 %.1f 디딤 %.1f"
			% [
				_clip.clip_name(),
				_flourish,
				_features.delay,
				_features.arc,
				_features.squash,
				_features.asymmetry,
				_features.depth,
				_features.plant,
			]
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

	if _next_frame >= _frames:
		print("완료: %d 장" % _frames)
		return true

	# 시각을 직접 넣는다. 한 바퀴를 장수로 등분하므로 마지막 다음이 정확히 처음이다.
	var t := _clip.loop_seconds() * float(_next_frame) / float(_frames)
	var swing := _clip as CharSwingClip
	var impact := -1.0 if swing == null else swing.anticipate + swing.still + swing.strike
	_view.show_at(_clip, t, impact)
	_pending = _next_frame
	_next_frame += 1
	return false


## 장수는 **한 바퀴 × fps** 로 정한다. 고정값으로 두면 클립마다 재생 속도가 달라지는데
## 그것을 알아챌 방법이 없다 — idle(4.0 s)은 100 장으로 전과 같고 walk(1.2 s)는 30 장이다.
static func frame_count(loop_seconds: float) -> int:
	return maxi(1, int(roundf(loop_seconds * float(FPS))))


## 낱말에서 클립을 만든다. **표로 두면 클립이 늘어도 분기가 안 늘어난다.**
func _make_clip(name: String, rig: CharRig) -> CharClip:
	var weapon := CharWeapon.new(_cells, _span)
	var swings: Dictionary[String, Array] = {
		"swing": [WeaponGuard.Id.HIGH, WeaponGuard.Id.LOW],
		"swingup": [WeaponGuard.Id.LOW, WeaponGuard.Id.HIGH],
		"swinghome": [WeaponGuard.Id.HIGH, WeaponGuard.Id.LOW],
	}
	if name in swings:
		var pair: Array = swings[name]
		var swing := CharSwingClip.new(rig, pair[0], pair[1], weapon)
		# `swinghome` 은 제자리로 돌아온다. 「남는다 / 돌아온다」를 나란히 보려는 것이다.
		swing.returns_home = name == "swinghome"
		return swing
	var makers: Dictionary[String, Callable] = {
		"walk": func() -> CharClip: return CharWalkClip.new(rig),
		"run": func() -> CharClip: return CharRunClip.new(rig),
		"jump": func() -> CharClip: return CharJumpClip.new(rig),
		"hit": func() -> CharClip: return CharHitClip.new(rig),
		"die": func() -> CharClip: return CharDieClip.new(rig),
		"front": func() -> CharClip: return CharFrontIdleClip.new(rig),
	}
	if name in makers:
		return (makers[name] as Callable).call()
	return CharIdleClip.new(rig)


func _parse_features(spec: String) -> AnimFeatures:
	if spec == "off":
		return AnimFeatures.all_off()
	if spec == "on":
		return AnimFeatures.all_on()
	if spec in AXES:
		return AnimFeatures.only(spec)
	# `no<축>` 은 그 축 **하나만** 끈다. 「있음 / 없음」을 나란히 놓을 때 쓴다.
	if spec.begins_with("no") and spec.substr(2) in AXES:
		return AnimFeatures.without(spec.substr(2))
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
	# **배경은 가로줄마다 단색이다**(가로 띠 그라데이션). 그래서 어느 줄에서든 왼쪽 끝과
	# 다른 화소는 전부 캐릭터다. 배경을 따로 렌더해 빼지 않아도 피사체만 정확히 셀 수 있다.
	var sampled := 0
	var subject := 0
	for y in range(0, image.get_height(), 2):
		var background := image.get_pixel(0, y)
		for x in range(0, image.get_width(), 2):
			sampled += 1
			if not image.get_pixel(x, y).is_equal_approx(background):
				subject += 1
	var ratio := float(subject) / float(maxi(sampled, 1))
	if ratio < MIN_SUBJECT_RATIO:
		push_error(
			(
				"캐릭터가 안 그려졌다 — 화면의 %.2f %% 만 배경과 다르다 (최소 %.2f %%)"
				% [ratio * 100.0, MIN_SUBJECT_RATIO * 100.0]
			)
		)
		return false
	print("확인: %dx%d, 캐릭터가 화면의 %.1f %%" % [image.get_width(), image.get_height(), ratio * 100.0])
	return true
