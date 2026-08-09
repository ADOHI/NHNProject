extends SceneTree
## 애니메이션 한 바퀴를 PNG 묶음으로 남긴다. `tools/make_gif.py` 가 GIF 로 잇는다.
##
##     godot --path . -s res://tools/capture_char_anim.gd -- .renders-char-anim/idle
##     godot --path . -s res://tools/capture_char_anim.gd -- .renders-char-anim/walk walk
##     godot --path . -s res://tools/capture_char_anim.gd -- .renders-char-anim/skate walk noplant
##
## 첫 인자가 저장 접두사이고, 나머지는 **순서에 상관없는 낱말**이다.
##
## * **`skin=<폴더>`** — 자리표시자 도형 대신 **진짜 파츠 그림**으로 찍는다.
##   리그 치수도 그 그림에서 나온다 (§25.41). 안 주면 지금까지와 같다
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

## 파츠 그림이 있는 폴더. 비어 있으면 자리표시자 도형이다 (§25.41).
var _skin_dir := ""

## **무너짐 눈금.** `hit` 이 어디까지 갈지를 정한다 (§25.12.6).
var _stagger := CharHitClip.FALL_AT

## **때리는 중에 맞는 것**을 보여 주려고 미리 충격을 심어 둔다 (`hitat0.35` 처럼).
var _reaction: CharReaction = null

## 밀림 자국을 그릴까. 판정용이다.
var _want_marker := false

## **화면 연출** — 속도선 · 임팩트 · 카메라 (§25.28).
var _fx := CharScreenFx.new()
var _fx_layer: CharScreenFxLayer = null
var _fx_back: CharScreenFxLayer = null

## 밀리기 전 제자리. 뿌리 이동을 여기서 잰다.
var _home := Vector2.ZERO

## 밀림을 눈에 보이게 하는 자국. `mark` 를 줄 때만 생긴다.
var _marker: PushMarker = null
var _stage: Node2D = null


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_prefix = args[0]
	var clip_name := "idle"
	for token: String in args.slice(1):
		if token in CLIPS:
			clip_name = token
		elif token.begins_with("lines") or token.begins_with("impact") or token.begins_with("cam"):
			# `lines=strong` · `impact=over` · `cam=weak` 처럼 축마다 눈금을 준다.
			var pair := token.split("=")
			var level := CharScreenFx.level_from(pair[1] if pair.size() > 1 else "strong")
			if token.begins_with("lines"):
				_fx.speed_lines = level
			elif token.begins_with("impact"):
				_fx.impact = level
			else:
				_fx.camera = level
		elif token.begins_with("fxall"):
			var pair2 := token.split("=")
			_fx = CharScreenFx.all_at(
				CharScreenFx.level_from(pair2[1] if pair2.size() > 1 else "strong")
			)
		elif token == "mark":
			_want_marker = true
		elif token.begins_with("hitat"):
			# `hitat0.35,0.5` 처럼 「그 시각에 세기 얼마로 맞는다」를 심는다.
			var when := token.substr(5).split(",")
			if _reaction == null:
				_reaction = CharReaction.new()
			_reaction.strike(float(when[0]), float(when[1]) if when.size() > 1 else 0.9)
		elif token in CharFlourish.preset_names():
			# `arc_hard` 처럼 연출 장치를 고른다. 장치마다 약/세/과 셋이 있다 (§25.23).
			_flourish = token
		elif token.begins_with("stagger"):
			# `stagger45` 처럼 **무너짐 눈금**을 준다 — 경직 30 · 띄우기 60 · 쓰러짐 100 (§28.5).
			# 눈금이 구간을 정하므로 셋을 나란히 놓으려면 이 낱말 하나면 된다.
			_stagger = float(token.substr(7))
		elif token.begins_with("skin="):
			# `skin=<폴더>` — **자리표시자 도형 대신 진짜 파츠 그림으로 찍는다** (§25.41).
			# 리그도 그 그림에서 나온다. 안 주면 지금까지처럼 도형이다.
			_skin_dir = token.substr(5)
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

	# **파츠 그림이 있으면 리그가 거기서 나온다.** 없으면 자리표시자 치수다.
	var skin: CharSkin = null
	var rig := CharRig.new()
	if not _skin_dir.is_empty():
		skin = CharSkin.load_dir(_skin_dir)
		if skin.rig == null:
			push_error("파츠를 못 읽었다: %s" % str(skin.problems))
			quit(1)
			return
		for problem in skin.problems:
			print("파츠 경고: %s" % problem)
		rig = skin.rig
	_clip = _make_clip(clip_name, rig)

	var stage := _make_stage()
	_viewport.add_child(stage)
	_stage = stage

	_view = CharPartsView.new()
	# **`setup()` 전에 넣어야 한다.** `_make_part()` 가 이 값을 보고 도형이냐 그림이냐를 가른다.
	_view.skin = skin
	_view.weapon = CharWeapon.new(_cells, _span)
	_view.flourish = CharFlourish.preset(_flourish)
	# **가운데가 아니라 왼쪽에 세운다.** 내려치기에서 머리와 검이 앞으로 크게 나가는데
	# 가운데에 두면 오른쪽 변에 잘린다 — 실제로 머리가 잘려 나갔다.
	_home = Vector2(float(VIEW_SIZE.x) * 0.34, GROUND_Y)
	_view.position = _home
	_view.scale = Vector2(VIEW_SCALE, VIEW_SCALE)
	stage.add_child(_view)
	# `_ready()` 를 기다리지 않는다 — 여기서 직접 세운다.
	_view.setup(rig)
	if _want_marker:
		_marker = PushMarker.new()
		_marker.z_index = 90
		stage.add_child(_marker)
	# **속도선은 배경 위, 캐릭터 뒤다** (§25.28.2).
	#
	# 무대 밖에 두면 **배경 칠에 가려 아예 안 보인다** — 처음에 그렇게 했다가 선이 사라졌다.
	# 그래서 무대의 자식으로 넣고 캐릭터를 그 위로 올린다.
	_fx_back = CharScreenFxLayer.new()
	_fx_back.fx = _fx
	_fx_back.setup(Vector2(VIEW_SIZE), false)
	_stage.add_child(_fx_back)
	_view.z_index = 10
	_fx_layer = CharScreenFxLayer.new()
	_fx_layer.fx = _fx
	_fx_layer.setup(Vector2(VIEW_SIZE), true)
	_viewport.add_child(_fx_layer)

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
	# **히트스톱: 맞는 순간 동작 진행 자체가 멈춘다** (§25.27.2).
	var play_t := t - _reaction.stalled(t) if _reaction != null else t
	_view.show_at(_clip, play_t, impact, _reaction, t)
	# **뿌리가 통째로 밀린다.** 이게 가장 크게 읽힌다.
	if _reaction != null:
		_view.position = _home + _reaction.root_offset(t)
	_apply_screen_fx(play_t, impact)
	_mark_push()
	_pending = _next_frame
	_next_frame += 1
	return false


## 장수는 **한 바퀴 × fps** 로 정한다. 고정값으로 두면 클립마다 재생 속도가 달라지는데
## 그것을 알아챌 방법이 없다 — idle(4.0 s)은 100 장으로 전과 같고 walk(1.2 s)는 30 장이다.
## 카메라는 **무대를 옮기고**, 속도선·임팩트는 **그 위에 덮는다.**
func _apply_screen_fx(t: float, impact: float) -> void:
	if _fx.is_idle():
		return
	var focus := _view.position + Vector2(0.0, -110.0)
	_stage.transform = _fx.camera_transform(t, impact, focus)
	var heading := _view.blade_heading(_clip, t)
	_fx_back.show_at(t, impact, focus, heading)
	_fx_layer.show_at(t, impact, focus, heading)


## **판정용 표시.** 뿌리가 얼마나 밀렸는지 제자리에 자국을 남긴다.
##
## 캡처에만 그린다 — 밀림이 눈에 보여야 「맞았다」를 판정할 수 있기 때문이다.
func _mark_push() -> void:
	if _marker == null:
		return
	_marker.shift = _view.position.x - _home.x
	_marker.home = _home
	_marker.queue_redraw()


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
		"hit": func() -> CharClip: return _make_hit(rig),
		"die": func() -> CharClip: return CharDieClip.new(rig),
		"front": func() -> CharClip: return CharFrontIdleClip.new(rig),
	}
	if name in makers:
		return (makers[name] as Callable).call()
	return CharIdleClip.new(rig)


## 눈금이 구간을 정한다. **문턱은 전투가 정하고 구간은 이쪽이 자른다** (§25.18.2).
func _make_hit(rig: CharRig) -> CharClip:
	var clip := CharHitClip.new(rig)
	clip.depth = CharHitClip.depth_for(_stagger)
	return clip


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


## **밀림을 눈에 보이게 하는 자국.** 제자리에 세로선을 긋고 밀린 만큼 화살을 그린다.
##
## **판정용이라 캡처에만 나온다.** 게임에는 안 들어간다.
class PushMarker:
	extends Node2D

	const HOME := Color(1.0, 1.0, 1.0, 0.30)
	const ARROW := Color(1.0, 0.42, 0.36, 0.95)

	var shift := 0.0
	var home := Vector2.ZERO

	func _draw() -> void:
		var y := home.y + 8.0
		draw_line(Vector2(home.x, y - 190.0), Vector2(home.x, y), HOME, 2.0)
		if absf(shift) < 0.6:
			return
		var tip := Vector2(home.x + shift, y)
		draw_line(Vector2(home.x, y), tip, ARROW, 4.0)
		var back := signf(shift) * -8.0
		draw_line(tip, tip + Vector2(back, -6.0), ARROW, 4.0)
		draw_line(tip, tip + Vector2(back, 6.0), ARROW, 4.0)
