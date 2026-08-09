class_name CharPartsView
extends Node2D
## 파츠 여섯을 `Node2D` 로 만들고 포즈를 **트랜스폼에 그대로 넣는다.**
##
## 이 클래스가 하는 일은 그것뿐이다 — 애니메이션 판단이 하나도 없다.
## 파츠가 진짜 노드인 이유는 나중에 각각을 `Sprite2D` 로 바꿀 자리이기 때문이다.
##
## 그림자는 여기서 그린다. 포즈에서 파생되는 값이라 코어에 둘 것이 아니고,
## **떠 있는 파츠에 접지감을 주는 가장 값싼 수단**이라 뺄 것도 아니다.
##
## 무기도 여기서 붙인다 — **든 손의 자식**이라 손의 트랜스폼을 그대로 물려받는다.

const SHADOW := Color(0.145, 0.161, 0.196, 0.28)

## 잔상 색. 캐릭터보다 차갑게 빼서 「지나간 것」으로 읽히게 한다.
const ECHO := Color(0.639, 0.749, 0.839)

## 호의 안쪽과 바깥쪽 색. 바깥이 밝아야 날이 지나간 것으로 보인다.
const ARC_INNER := Color(0.741, 0.827, 0.898, 0.10)
const ARC_OUTER := Color(0.965, 0.980, 1.0, 0.55)

## 호를 몇 조각으로 쪼개나. 적으면 각이 지고 많으면 그리는 값이 는다.
const ARC_STEPS := 10

## 몸이 1 px 오를 때 그림자가 줄어드는 비율. 이 값이 크면 그림자가 따로 노는 것으로 보인다.
const SHADOW_LIFT_RESPONSE := 0.030

var rig: CharRig

## 든 무기. **칸 수가 길이 · 두께를 정하고 그것이 다시 동작을 정한다** (§25.16).
var weapon := CharWeapon.new(1)

## 얹는 연출 장치들. `null` 이면 아무것도 안 얹는다.
var flourish := CharFlourish.none()

var _shapes: Array[CharPartShape] = []
var _weapon: CharWeaponShape
var _shadow_scale := 1.0
var _shadow_offset := 0.0

## 과거 자세들. **기록이 아니라 `sample(t - Δ)` 로 받은 것**이다 (§25.3).
var _echoes: Array[CharPose] = []
var _arc: PackedVector2Array = PackedVector2Array()
var _flash := 0.0


func setup(p_rig: CharRig) -> void:
	rig = p_rig
	for shape in _shapes:
		shape.queue_free()
	_shapes.clear()
	_shapes.resize(CharPart.COUNT)
	# 뒤에서 앞으로 붙인다 — 자식 순서가 곧 그리는 순서다.
	for part in CharPart.DRAW_ORDER:
		var shape := CharPartShape.new()
		shape.name = "Part%d" % part
		add_child(shape)
		shape.setup(part, rig)
		_shapes[part] = shape
	_mount_weapon()
	apply_pose(CharPose.from_rig(rig))


## 무기를 **든 손의 자식으로** 붙인다.
##
## 자식이면 손의 트랜스폼을 그대로 물려받으므로 여기서 해 줄 일이 없다 —
## 손이 돌면 무기가 손을 축으로 같이 돈다. `sample()` 은 무기를 모르고,
## 파츠는 여섯 그대로다 (`CharWeapon`).
func _mount_weapon() -> void:
	_weapon = CharWeaponShape.new()
	_weapon.name = "Weapon"
	# 손 지역 좌표는 `+y` 가 아래다. 코어(`+y` 위)에서 잡은 자리를 뒤집어 넣는다.
	var grip := weapon.grip_offset(rig)
	_weapon.position = Vector2(grip.x, -grip.y)
	_weapon.rotation = -weapon.rest_angle(rig)
	_shapes[CharWeapon.HOLDER].add_child(_weapon)
	_weapon.setup(weapon)


func apply_pose(pose: CharPose) -> void:
	for part in CharPart.COUNT:
		_shapes[part].transform = pose.canvas_transform(part)
	var torso := CharPart.Id.TORSO
	var lift := pose.positions[torso].y - rig.rest_positions[torso].y
	_shadow_scale = 1.0 - lift * SHADOW_LIFT_RESPONSE
	_shadow_offset = pose.positions[torso].x * 0.5
	queue_redraw()


## 그 시각을 **끊어 보여 주는 표본점으로** 내린다. `hold_fps` 가 0 이면 그대로다.
##
## 잔상과 호도 이 표본점에서 뽑아야 한다 — 안 그러면 몸은 딱딱 넘어가는데 잔상만
## 부드럽게 흘러 **둘이 따로 논다.**
func held(at: float) -> float:
	if flourish == null or flourish.hold_fps <= 0.0:
		return at
	return floorf(at * flourish.hold_fps) / flourish.hold_fps


## 과거 자세와 호를 넣는다. **뷰는 이것을 그리기만 한다** — 어디서 왔는지 모른다.
##
## 번쩍임은 **파츠와 무기가 각자 자기 실루엣을 덮어** 만든다. 여기서 상자로 덮으면
## 그림과 어긋난 자리가 하얘진다 — 잔상은 상자여도 되지만 번쩍임은 안 된다.
## 잔상은 「지나간 것」이라 뭉뚱그려도 읽히고, 번쩍임은 **지금 그 자리**를 덮기 때문이다.
func set_motion(echoes: Array[CharPose], arc: PackedVector2Array, flash: float) -> void:
	_echoes = echoes
	_arc = arc
	if not is_equal_approx(flash, _flash):
		_flash = flash
		for shape in _shapes:
			shape.flash = flash
		if _weapon != null:
			_weapon.flash = flash
	queue_redraw()


## **클립과 시각만 주면 장식까지 스스로 만든다.**
##
## 액터와 캡처 도구가 같은 길을 쓰게 하려는 것이다 — 둘이 갈리면 벤치에서 본 것과
## 게임에서 나오는 것이 달라진다.
## `at` 은 **동작 시각**(히트스톱으로 멈춘 뒤의 것), `wall` 은 **실제 시각**이다.
##
## 둘이 갈라지는 것이 히트스톱이다 — 동작은 멈춰 있는데 충격은 계속 잦아든다.
func show_at(
	clip: CharClip, at: float, impact := -1.0, reaction: CharReaction = null, wall := -1.0
) -> void:
	var f := AnimFeatures.all_on()
	# **보간을 끈다.** 기본은 연속이다 — 사용자가 끊는 쪽을 뺐다 (§25.26.45).
	at = held(at)
	var pose := clip.sample(at, f)
	# **반응 층을 자세 위에 더한다.** 자세가 무엇이든 상관없다 (§25.27).
	if reaction != null:
		reaction.apply(pose, at if wall < 0.0 else wall, rig)
	apply_pose(pose)
	_stretch_blade(clip, at, f)
	set_motion(
		past_poses(clip, at, f), blade_sweep(clip, at, f), _flash_left(at, impact, reaction, wall)
	)


## **스트레치와 스미어.** 빠를수록 검이 진행 방향으로 늘어난다.
##
## 정지 프레임으로 보면 **이상하게 생긴 것이 정상이다** — 한두 프레임만 지나가므로
## 사람은 「빨랐다」로만 읽는다. 2D 액션의 고전 기법이고 에셋이 0 이다.
##
## 스미어는 같은 장치를 **더 밀어붙인 것**이라 축을 따로 두지 않고 배수만 키운다.
func _stretch_blade(clip: CharClip, at: float, f: AnimFeatures) -> void:
	if _weapon == null:
		return
	var pull := flourish.stretch + flourish.smear
	if pull <= 0.0:
		_weapon.scale = Vector2.ONE
		return
	var speed := _blade_speed(clip, at, f)
	# 길이 방향으로 늘리고 두께를 줄인다 — 부피를 대충 지켜야 「늘어났다」로 읽힌다.
	var along := 1.0 + pull * speed
	_weapon.scale = Vector2(along, 1.0 / sqrt(along))


## 검이 지금 얼마나 빨리 도는가 (`0` … `1` 언저리).
##
## 클립이 시각의 함수라 **두 시각을 뽑아 빼면 그만이다** — 속도를 따로 안 들고 다닌다.
func _blade_speed(clip: CharClip, at: float, f: AnimFeatures) -> float:
	var step := 0.02
	var before := maxf(at - step, 0.0)
	if is_equal_approx(before, at):
		return 0.0
	var was := clip.sample(before, f).rotations[CharWeapon.HOLDER]
	var now := clip.sample(at, f).rotations[CharWeapon.HOLDER]
	return clampf(absf(now - was) / (at - before) / 12.0, 0.0, 1.0)


## **검이 지금 어느 쪽으로 가고 있나.** 속도선이 방향을 여기서 얻는다 (§25.28.1).
##
## 자세를 **읽고** 나오는 것이라 박아 둔 값이 아니다 — 검이 왼쪽으로 지나가면
## 선도 왼쪽으로 흐른다.
func blade_heading(clip: CharClip, at: float) -> Vector2:
	var f := AnimFeatures.all_on()
	var step := 0.02
	var before := maxf(at - step, 0.0)
	if is_equal_approx(before, at):
		return Vector2.ZERO
	var was := weapon.tip_position(clip.sample(before, f), rig)
	var now := weapon.tip_position(clip.sample(at, f), rig)
	return now - was


## 파츠 노드. 나중에 `Sprite2D` 로 갈아 끼울 때의 접점이다.
func part_node(part: CharPart.Id) -> CharPartShape:
	return _shapes[part]


func _draw() -> void:
	if rig == null:
		return
	var rx := rig.total_width() * 0.30 * _shadow_scale
	var ry := rx * 0.22
	var points := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		points.append(Vector2(_shadow_offset + cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(points, SHADOW)
	_draw_arc_sweep()
	_draw_echoes()


## 검이 지나간 호를 **면으로** 그린다. 안쪽은 좁고 바깥은 넓다.
##
## **폴리곤 하나다.** 잔상보다 훨씬 싸고, 2D 액션에서 타격감의 절반을 낸다.
func _draw_arc_sweep() -> void:
	if _arc.size() < 4:
		return
	draw_colored_polygon(_arc, ARC_OUTER)


## 잔상. **뒤로 갈수록 옅어진다.**
##
## 파츠 노드를 복제하지 않는다 — 상자만 찍는다. 6N 개 노드를 만들면 웹에서 죽는다.
func _draw_echoes() -> void:
	if _echoes.is_empty():
		return
	var count := _echoes.size()
	for i in count:
		var fade := flourish.trail_alpha * (1.0 - float(i) / float(count))
		var tint := Color(ECHO.r, ECHO.g, ECHO.b, fade)
		var pose := _echoes[i]
		for part in CharPart.DRAW_ORDER:
			if not flourish.trail_body and part != CharWeapon.HOLDER:
				continue
			_draw_ghost(pose, part, tint)
		if not flourish.trail_body:
			_draw_ghost_blade(pose, tint)


## 파츠 하나를 옅은 상자로 찍는다.
func _draw_ghost(pose: CharPose, part: CharPart.Id, tint: Color) -> void:
	var at := pose.canvas_transform(part)
	var half := rig.half_sizes[part]
	var centre := rig.local_centers[part]
	var box := PackedVector2Array()
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var local := Vector2(centre.x + corner.x * half.x, -(centre.y + corner.y * half.y))
		box.append(at * local)
	draw_colored_polygon(box, tint)


## 무기 잔상. 몸을 안 남길 때도 **검은 남겨야** 궤적이 읽힌다.
##
## 윤곽을 `CharWeapon.OUTLINE` 에서 받는다 — 여기서 상자를 그리면 **잔상만 뭉툭한 막대**가
## 되어 지나간 것이 검으로 안 읽힌다.
func _draw_ghost_blade(pose: CharPose, tint: Color) -> void:
	var grip := weapon.grip_offset(rig)
	var mount := (
		pose.canvas_transform(CharWeapon.HOLDER)
		* Transform2D(-weapon.rest_angle(rig), Vector2(grip.x, -grip.y))
	)
	var ghost := PackedVector2Array()
	for point in weapon.outline_span(0.0, 1.0):
		ghost.append(mount * point)
	draw_colored_polygon(ghost, tint)


## 과거 자세들. **기록이 아니라 `sample(t - Δ)` 다** — 클립이 시각의 순수 함수라
## 그냥 뽑힌다. 링 버퍼가 없고 프레임률이 튀어도 간격이 안 변한다 (§25.3).
func past_poses(clip: CharClip, at: float, f: AnimFeatures) -> Array[CharPose]:
	var out: Array[CharPose] = []
	for i in range(1, flourish.trail_count + 1):
		var back := held(at - float(i) * flourish.trail_gap)
		if back < 0.0:
			if not clip.is_looping():
				break
			back = clip.wrap_time(back)
		out.append(clip.sample(back, f))
	return out


## 검이 지나간 호를 면으로 만든다. **바깥은 날 끝, 안쪽은 자루 쪽**이라 부채꼴이 된다.
func blade_sweep(clip: CharClip, at: float, f: AnimFeatures) -> PackedVector2Array:
	var sweep := PackedVector2Array()
	if not flourish.arc_on:
		return sweep
	var weapon := weapon
	var grip := weapon.grip_offset(rig)
	var thick := clampf(flourish.arc_weight * weapon.length() / CharWeapon.BASE_LENGTH, 0.2, 3.0)
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in ARC_STEPS + 1:
		var back := held(at - flourish.arc_span * float(i) / float(ARC_STEPS))
		if back < 0.0:
			if not clip.is_looping():
				break
			back = clip.wrap_time(back)
		var mount := (
			clip.sample(back, f).canvas_transform(CharWeapon.HOLDER)
			* Transform2D(-weapon.rest_angle(rig), Vector2(grip.x, -grip.y))
		)
		# 뒤로 갈수록 얇아진다 — 그래야 「지나갔다」로 읽힌다.
		var taper := 1.0 - float(i) / float(ARC_STEPS + 1)
		var reach := weapon.tip_offset().x
		var far_edge := reach * (0.55 + 0.45 * taper)
		# **안쪽 모서리가 0 으로 무너지면 안 된다.** 점이 겹쳐 삼각분할이 실패한다
		# (`Invalid polygon data` — 원피스 윤곽에서 한 번 밟은 것과 같은 실패다).
		var near_edge := maxf(far_edge - reach * 0.34 * thick * taper, reach * 0.12)
		outer.append(mount * Vector2(far_edge, 0.0))
		inner.append(mount * Vector2(near_edge, 0.0))
	if outer.size() < 3:
		return sweep
	# **검이 멈춰 있으면 호가 없다.** 정지(예비 끝)와 히트스톱 동안 표본이 전부 한 점에
	# 모여 넓이 0 인 폴리곤이 되고, 그러면 삼각분할이 실패한다.
	# 멈춤을 일부러 넣어 둔 클립이라(§25.19) 이 구간이 반드시 생긴다.
	var lowest := outer[0]
	var highest := outer[0]
	for point in outer:
		lowest = lowest.min(point)
		highest = highest.max(point)
	if lowest.distance_to(highest) < 2.0:
		return sweep
	sweep.append_array(outer)
	inner.reverse()
	sweep.append_array(inner)
	return sweep


## 지금 번쩍이고 있나 — 켜져 있으면 `1`, 아니면 `0`.
##
## **때린 쪽과 맞은 쪽이 같은 장치를 나눠 쓴다.** 때린 쪽은 **검이 닿는 시각**으로 켜고,
## 맞은 쪽은 **충격이 들어온 시각**으로 켠다. 때리다 맞으면 둘이 겹칠 뿐 싸우지 않는다.
##
## **밝기가 시간에 따라 줄지 않는다.** 켜져 있는 동안 일정하고 그다음 꺼진다 —
## 줄게 두면 하나뿐인 표본이 꺼지기 직전에 걸려 **눈금이 있는데 아무 일도 안 난다**
## (§25.28.3 에서 화면 임팩트 프레임이 정확히 그랬다).
##
## **충격은 실제 시각(`wall`)으로 잰다.** 히트스톱 동안 동작 시각은 멈춰 있는데
## 번쩍임까지 멈추면 맞은 순간이 얼어붙어 번쩍임이 안 끝난다.
func _flash_left(at: float, impact: float, reaction: CharReaction, wall: float) -> float:
	var hold := flourish.flash
	if hold <= 0.0:
		return 0.0
	if impact >= 0.0 and at >= impact and at - impact < hold:
		return 1.0
	if reaction != null and reaction.flash_left(at if wall < 0.0 else wall, hold) > 0.0:
		return 1.0
	return 0.0
