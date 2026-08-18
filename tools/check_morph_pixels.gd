extends SceneTree
## **화면에서 잰다** — 셰이더가 실제로 무엇을 그리는지.
##
##     godot --path . -s res://tools/check_morph_pixels.gd -- skin=<파츠폴더>
##
## `docs/design/31-soft-body.md` §31.5.3.
##
## ## 왜 단위 테스트로 못 하나
##
## 단위 테스트는 **uniform 까지만** 본다. 그 뒤는 GPU 안이라 헤드리스에서 안 보이고,
## `--headless` 는 `get_image()` 가 널을 준다. 그런데 이 레인이 조용히 틀릴 수 있는
## 자리 둘이 **정확히 그 안**에 있다.
##
## | 물음 | 왜 화면에서만 답할 수 있나 |
## | --- | --- |
## | **꺼짐이 진짜 꺼짐인가** | 여백 · 재질 · 표본 자리가 다 같아야 화소가 같다 |
## | **`COLOR` 를 곱한 것이 맞나** | `MODULATE` 가 이 판에 없어서 대신 쓴 것이다. 두 배로 곱해지면 **어두워질 뿐** 아무 오류도 안 난다 |
##
## 둘째가 §25.13 그 자체다 — **조용히 틀린다.** 그래서 잰다.
##
## ## 무엇을 재나
##
## 같은 자세를 **세 번** 그린다.
##
## | 판 | 무엇 |
## | --- | --- |
## | `off` | 흔들림 없음. 지금까지의 그림 |
## | `zero` | 흔들림 켜짐, 변위 0 — **`off` 와 화소가 같아야 한다** |
## | `push` | 변위를 상한까지 밀어 넣음 — **달라야 한다** |
##
## `off` 대 `zero` 가 곧 「꺼짐이 진짜 꺼짐」이고, 동시에 **`COLOR` 곱셈 검사**다 —
## 두 배로 곱해졌으면 `zero` 가 `off` 보다 어둡게 나온다.

const VIEW_SIZE := Vector2i(360, 420)
const VIEW_SCALE := 2.6
const GROUND_Y := 392.0
const BACKDROP := Color(0.298, 0.333, 0.376)

## 창이 자리를 잡을 준비 프레임. 첫 장이 백지로 나오는 것을 막는다 (§25.13.5).
const WARMUP_FRAMES := 8

## 화소가 「같다」고 볼 차이. 8 비트 한 칸이 `1/255 = 0.0039` 다.
const SAME := 0.004

## 밀어 넣을 때 상한의 몇 배까지 가나.
const PUSH := 1.0

var _skin_dir := ""
var _viewport: SubViewport
var _view: CharPartsView
var _rig: CharRig
var _pose: CharPose
var _shots: Array[Image] = []
var _plan: Array[String] = ["off", "zero", "push"]
var _step := 0
var _warmup := WARMUP_FRAMES


func _initialize() -> void:
	for token in OS.get_cmdline_user_args():
		if token.begins_with("skin="):
			_skin_dir = token.substr(5)
	if _skin_dir.is_empty():
		push_error("skin=<폴더> 가 필요하다 — 도형에는 UV 가 없어 잴 것이 없다")
		quit(1)
		return
	var skin := CharSkin.load_dir(_skin_dir)
	if skin.rig == null:
		push_error("파츠를 못 읽었다: %s" % str(skin.problems))
		quit(1)
		return
	_rig = skin.rig
	# **한 자세를 고정한다.** 자세가 움직이면 무엇 때문에 화소가 달라졌는지 못 가른다.
	var clip := CharIdleClip.new(_rig)
	_pose = clip.sample(0.0, AnimFeatures.all_on())

	_viewport = SubViewport.new()
	_viewport.size = VIEW_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(_viewport)

	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.size = Vector2(VIEW_SIZE)
	_viewport.add_child(backdrop)

	_view = CharPartsView.new()
	_view.skin = skin
	_view.position = Vector2(float(VIEW_SIZE.x) * 0.5, GROUND_Y)
	_view.scale = Vector2(VIEW_SCALE, VIEW_SCALE)
	_viewport.add_child(_view)
	_stage(_plan[0])


## 그 판을 세운다. **`setup()` 을 다시 부른다** — 재질을 붙이고 떼는 일이라서다.
func _stage(plan: String) -> void:
	_view.morph = null if plan == "off" else MorphRig.default_for(_rig)
	_view.setup(_rig)
	_view.apply_pose(_pose)
	if plan == "push":
		_push_to_the_limit()


## 변위를 **상한까지** 밀어 넣는다. 물리를 안 거친다 — 재는 것은 셰이더다.
func _push_to_the_limit() -> void:
	var morph := _view.morph
	var state := MorphState.rest(morph.anchors.size())
	for i in morph.anchors.size():
		var anchor := morph.anchors[i]
		state.shifts[i] = Vector2(anchor.limit * PUSH, anchor.limit * PUSH * 0.4)
		state.bulges[i] = anchor.bulge
	for part in CharPart.COUNT:
		var indices := morph.indices_of(part)
		if indices.is_empty():
			continue
		var sprite := _view.part_node(part) as CharPartSprite
		if sprite == null or not sprite.has_morph():
			continue
		var shifts := PackedVector2Array()
		var bulges := PackedFloat32Array()
		for i in indices:
			shifts.append(state.local_shift(i, part, _pose))
			bulges.append(state.bulges[i])
		sprite.apply_morph(shifts, bulges)


func _process(_delta: float) -> bool:
	if _warmup > 0:
		_warmup -= 1
		return false
	var shot := _viewport.get_texture().get_image()
	if shot == null:
		push_error("화면을 못 읽었다 — `--headless` 로는 못 돌린다")
		quit(1)
		return true
	_shots.append(shot)
	_step += 1
	if _step < _plan.size():
		_stage(_plan[_step])
		_warmup = 2
		return false
	return _report()


func _report() -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(".renders-char-anim"))
	for i in _plan.size():
		_shots[i].save_png(".renders-char-anim/morph_%s.png" % _plan[i])
	var off_zero := _difference(_shots[0], _shots[1])
	var off_push := _difference(_shots[0], _shots[2])
	print("판 셋을 .renders-char-anim/morph_*.png 에 남겼다")
	print("꺼짐 대 변위0  : 다른 화소 %d, 최대 차 %.5f" % [off_zero[0], off_zero[1]])
	print("꺼짐 대 밀어넣음: 다른 화소 %d, 최대 차 %.5f" % [off_push[0], off_push[1]])
	var failed := false
	if off_zero[1] > SAME:
		push_error(
			(
				"**꺼짐이 진짜 꺼짐이 아니다.** 변위 0 인데 화소가 다르다 (최대 차 %.5f). "
				+ "COLOR 를 두 번 곱했거나 여백 되돌리기가 어긋났다"
			) % off_zero[1]
		)
		failed = true
	if off_push[0] < 200:
		push_error("**밀어 넣었는데 화면이 안 바뀐다** — 셰이더가 아예 안 걸린 것이다")
		failed = true
	if not failed:
		print("통과: 꺼짐은 화소가 같고, 켜서 밀면 달라진다")
	quit(1 if failed else 0)
	return true


## 두 장의 차이. `[다른 화소 수, 최대 차]`.
func _difference(a: Image, b: Image) -> Array:
	var count := 0
	var worst := 0.0
	for y in a.get_height():
		for x in a.get_width():
			var pa := a.get_pixel(x, y)
			var pb := b.get_pixel(x, y)
			var gap := maxf(
				maxf(absf(pa.r - pb.r), absf(pa.g - pb.g)), maxf(absf(pa.b - pb.b), absf(pa.a - pb.a))
			)
			if gap > SAME:
				count += 1
			worst = maxf(worst, gap)
	return [count, worst]
