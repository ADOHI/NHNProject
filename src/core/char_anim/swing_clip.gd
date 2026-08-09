class_name CharSwingClip
extends CharClip
## 휘두르기 — **예비 · 타격 · 후속**. 유일하게 루프가 아닌 것이 여기서 처음 나온다.
##
## `docs/design/25-character-animation.md` §25.11.
##
## **자세에서 자세로 간다.** 어느 자세에서 시작해 어느 자세로 끝나는지가 값으로 남아
## 있어서(`from_guard` · `to_guard`), 나중에 「앞 동작의 끝이 다음 동작의 시작이어야
## 이어진다」가 확정되면 **체인 조건이 그냥 등식 하나**가 된다 (`WeaponGuard`).
##
## §25.3.1 이 금지한 것을 여기서 안 쓴다 — `current += (target - current) * k` 로는
## **목표를 지나칠 방법이 아예 없어서** 타격감이 원천적으로 불가능하다. 대신 전부
## **「사건 이후 흐른 시간」의 함수**이고, 오버슛은 그냥 **진폭이 1 을 넘는 감쇠 진동**이다.
##
## 무기는 든 손의 자식이라 이 클립도 **무기를 모른다.** 손을 돌리면 검이 따라 돈다.

## 1 칸짜리 기준의 예비 — 치기 전에 **반대로** 물러나는 시간. **끌어야 한다.**
const ANTICIPATE := 0.26

## **예비 끝의 정지.** 물러난 자리에서 잠깐 선다.
##
## **이 정지가 다음 것을 크게 만든다.** 없으면 물러났다가 그대로 이어져 한 덩어리로
## 흐르고, 그러면 타격이 「시작되는 순간」이 없다.
const STILL := 0.05

## 1 칸짜리 기준의 타격 — 실제로 지나가는 시간.
##
## **한두 프레임이다.** 25 fps 에서 0.045 초면 1.1 프레임이다. 처음에 0.11 초(2.8 프레임)로
## 두었더니 203 도를 부드럽게 도는 것이 되어 **캐주얼하게** 보였다. 4 칸은 8.3 프레임이었다.
##
## **물리적으로 정확한 휘두르기는 등속에 가깝고, 액션의 타격감은 정확히 그 반대다.**
const STRIKE := 0.045

## 1 칸짜리 기준의 후속 — 지나친 것이 되돌아와 앉는 시간. **다시 늘어진다.**
const RECOVER := 0.42

## 타격만 무게를 **덜** 탄다. 무거운 검도 지나갈 때는 지나간다 —
## 무거움은 **들어 올리고 되돌리는 데서** 나오지 지나가는 속도에서 나오지 않는다.
const STRIKE_WEIGHT_POWER := 0.5

## 무거울수록 몸이 무기에 끌려간다. `drag` 가 0 이면 손만 움직인다.
const DRAG_SHIFT := 5.0
const DRAG_TWIST := 0.09

## 예비에서 시작 자세의 **반대쪽으로** 얼마나 더 가는가 (진행도 기준).
##
## **깊을수록 휘두르는 각이 커진다.** 0.14 에서 0.26 으로 키웠다 — 예비가 얕으면
## 검이 도는 각이 작아 역동성이 통째로 죽는다.
const ANTICIPATE_DEPTH := 0.26

## 타격이 목표를 지나치는 양. **1 을 넘는 것이 오버슛이다.**
##
## 자세를 정할 때 **이 값까지 넘겨서** 검끝이 어디 가는지 봐야 한다 — 마무리 자세가
## 안전해도 지나치는 순간에 검이 바닥을 뚫는다. 실제로 그렇게 뚫었다 (§25.11.2).
const OVERSHOOT := 0.14

## 후속의 되튐이 잦아드는 빠르기와 흔들리는 횟수.
const SETTLE_DECAY := 7.0
const SETTLE_CYCLES := 1.6

## 몸이 휘두름을 받아 도는 양. 손만 움직이면 팔이 아니라 막대가 도는 것으로 보인다.
const TORSO_TWIST := 0.20
const TORSO_SHIFT := 3.4
const TORSO_DROP := 2.6

## **예비에 몸이 반대로 꼬인다.** 팔만 뒤로 가면 풀리는 힘이 안 생긴다.
## 예비를 깊게 한 것(§25.19.2)이 여기서 값을 한다 — 시간이 있어야 감긴다.
const TORSO_COIL := 0.26

## **키가 변한다.** 예비에 낮아지고 타격에 뻗는다.
## 위아래로 안 움직이면 무슨 짓을 해도 평평해 보인다.
const TORSO_DIP := 7.5
const TORSO_EXTEND := 5.5

## **파츠마다 시작 시각이 다르다 — 아래에서 위로.**
##
## `die` 에서 찾은 「시작이 다른」 축을 **방향만 반대로** 쓴다. 저쪽은 손 → 발 → 몸 → 머리로
## 힘이 빠졌고, 이쪽은 **발 → 몸 → 반대손 → 든손 → 머리**로 힘이 올라간다.
## 그것이 「채찍처럼 이어진다」의 정체다.
##
## **든 손이 기준(0)이다.** 무기가 닿는 시각이 여기서 정해지므로, 든 손을 늦추면
## `impact_seconds()` 가 통째로 밀린다. 기준으로 두면 접점 값이 안 흔들린다.
const LEAD_FEET := 0.075
const LEAD_TORSO := 0.048
const LEAD_OFF_HAND := 0.024
const LEAD_HEAD := -0.038

## 반대 손이 균형을 잡느라 뻗는 거리.
const OFF_HAND_SWING := 15.0

## 앞발이 내디딜 때 뜨는 높이.
const STEP_HEIGHT := 6.0

## 예비에 **살짝 뒤로** 빼는 비율. 그래야 앞으로 나갈 때 힘이 실린다.
const ADVANCE_BACK := 0.24

## 머리는 몸보다 늦게 따라온다. idle 과 같은 규칙이다.
const HEAD_TWIST := 0.07
const HEAD_DELAY := 0.06

## 무게가 실리는 발. 휘두르면 앞발을 디디고 뒷발의 뒤꿈치가 뜬다.
const FOOT_HEEL_LIFT := 0.16
const FOOT_SQUASH := 0.045

var from_guard: WeaponGuard.Id = WeaponGuard.Id.HIGH
var to_guard: WeaponGuard.Id = WeaponGuard.Id.LOW

## 든 무기. **모양 하나가 나머지를 전부 정한다** (§25.16 · §25.20).
var weapon := CharWeapon.new(1)

## 한 타 뒤에 **제자리로 돌아오는가.**
##
## **이것이 전투의 성격을 바꾼다.** 안 돌아오면 체인이 곧 전진이라 5 타면 다섯 번
## 밀고 들어간다 — 적을 몰아붙이거나 **너무 깊이 들어가서 포위당한다.**
## 돌아오면 제자리 콤보라 다루기 쉽고 「밀어붙인다」는 감각이 없다.
##
## **값을 안 박았다.** 사용자가 둘을 보고 정한다 (§25.21.3).
var returns_home := false

## 무기의 관성에서 나온 구간 길이. **손으로 적은 값이 아니다.**
##
## **총 길이는 물리가 정하고 그 안의 배분은 연출이 정한다.** 둘은 다른 축이고 곱해진다 —
## `시간 ∝ √I` 는 한 방이 얼마나 걸리는지만 말하지, 그 시간을 어떻게 쪼개는지는
## 아무 말도 안 한다. 균등하게 퍼뜨리면 그게 「캐주얼틱」이다 (§25.19).
var anticipate := ANTICIPATE
var still := STILL
var strike := STRIKE
var recover := RECOVER

## **히트스톱.** 닿는 순간 멈춰 있는 시간. **무거운 것은 멈춤이 길다.**
##
## 이 값을 전투가 받아 **때린 쪽과 맞은 쪽을 같이** 멈춰야 타격감이 난다 —
## 휘두르는 쪽 혼자 멈추는 것은 절반이다 (§25.19.2).
var hitstop := 0.0

## 양 끝 자세를 미리 푼 값. **검끝이 바닥을 안 뚫도록 손본 뒤의 각도**가 들어 있다.
var _start_offset: Vector2
var _end_offset: Vector2
var _start_rotation: float
var _end_rotation: float


func _init(
	p_rig: CharRig,
	p_from := WeaponGuard.Id.HIGH,
	p_to := WeaponGuard.Id.LOW,
	p_weapon: CharWeapon = null
) -> void:
	super(p_rig)
	from_guard = p_from
	to_guard = p_to
	weapon = p_weapon if p_weapon != null else CharWeapon.new(1)
	# **넷이 한 값에서 나온다.** 칸을 늘리면 예비도 타격도 회복도 멈춤도 같이 늘어난다.
	var pace := weapon.time_scale()
	anticipate = ANTICIPATE * pace
	still = STILL * pace
	strike = STRIKE * pow(pace, STRIKE_WEIGHT_POWER)
	recover = RECOVER * pace
	hitstop = weapon.hitstop_seconds()
	_start_offset = WeaponGuard.hand_offset(from_guard)
	_end_offset = WeaponGuard.hand_offset(to_guard)
	_start_rotation = WeaponGuard.hand_rotation(from_guard, rig, weapon)
	_end_rotation = WeaponGuard.hand_rotation(to_guard, rig, weapon)
	_keep_the_blade_off_the_floor()


## 자세를 **지나치는 자리까지 포함해서** 안전하게 만든다.
##
## **마무리 자세가 안전한 것만으로는 부족하다.** 진행도가 `1 + OVERSHOOT` 까지 가고
## 예비가 `−ANTICIPATE_DEPTH` 까지 가므로, 검끝이 바닥을 뚫는 것은 **자세 사이가 아니라
## 자세 밖**에서다. 3 칸 무기에서 실제로 2.5 px 뚫었다 (§25.16.2).
##
## **한 번에 푼다.** 표본마다 잘라 내면 그 경계에서 각도가 튄다 (§25.12.3 — 조건을
## 다는 것 자체가 불연속을 만든다). 보간이 선형이라 양 끝만 맞추면 사이는 저절로 안전하다.
func _keep_the_blade_off_the_floor() -> void:
	# 타격은 마무리 자세를 `OVERSHOOT` 만큼 지나치고, 예비는 시작 자세를 그만큼 물러난다.
	_end_rotation = _lifted_to_clear(
		_start_offset, _start_rotation, _end_offset, _end_rotation, 1.0 + OVERSHOOT
	)
	_start_rotation = _lifted_to_clear(
		_end_offset, _end_rotation, _start_offset, _start_rotation, 1.0 + ANTICIPATE_DEPTH
	)


## 빠르게 갔다가 끝에서 느려지는 곡선. **선형 보간을 안 쓴다** —
## 균등하게 퍼지는 것이 「부드럽게 돈다」이고 그것이 캐주얼함의 정체다.
func _ease_out(u: float) -> float:
	var left := 1.0 - clampf(u, 0.0, 1.0)
	return 1.0 - left * left * left


## `far` 쪽 각도를, 진행도 `beyond` 까지 밀고 나가도 검끝이 뜨도록 들어 올린다.
##
## 이미 안전하면 그대로 돌려준다 — **필요할 때만 손댄다.**
func _lifted_to_clear(
	near_offset: Vector2, near_angle: float, far_offset: Vector2, far_angle: float, beyond: float
) -> float:
	var hand_y := (
		rig.rest_positions[CharWeapon.HOLDER].y + lerpf(near_offset.y, far_offset.y, beyond)
	)
	var floor_angle := weapon.safe_angle(hand_y) - weapon.rest_angle(rig)
	if lerpf(near_angle, far_angle, beyond) >= floor_angle:
		return far_angle
	# 도달점을 바닥 각도에 맞추려면 끝점을 얼마나 들어야 하는가 — 선형이라 나눗셈 하나다.
	return near_angle + (floor_angle - near_angle) / beyond


func clip_name() -> String:
	return (
		"swing %d칸 %s에서 %s로"
		% [weapon.cells, WeaponGuard.guard_name(from_guard), WeaponGuard.guard_name(to_guard)]
	)


func loop_seconds() -> float:
	return anticipate + still + strike + hitstop + recover


## **루프가 아니다.** 끝나면 마무리 자세에 멈춰 선다 — 그래야 다음 동작이 거기서 잇는다.
func is_looping() -> bool:
	return false


## 진행도. `0` 이 시작 자세 · `1` 이 마무리 자세이고, **그 밖으로 나가는 것이 이 함수의 전부다.**
##
## 음수면 시작 자세보다 더 뒤로 물러난 것(예비)이고, `1` 을 넘으면 마무리를 지나친
## 것(오버슛)이다. 지수 접근으로는 둘 다 만들 수 없다.
func progress(t: float) -> float:
	if t <= 0.0:
		return 0.0
	if t < anticipate:
		# 뒤로 물러난다. **빠르게 물러났다 느려진다** — 그래야 「당겼다」로 읽힌다.
		return -ANTICIPATE_DEPTH * _ease_out(t / anticipate)
	var after := t - anticipate
	# **예비 끝의 정지.** 여기서 서 있는 것이 다음 한 프레임을 크게 만든다.
	if after < still:
		return -ANTICIPATE_DEPTH
	after -= still
	if after < strike:
		# 한두 프레임 만에 지나간다. 끝이 완만해야 「닿았다」로 읽힌다.
		return lerpf(-ANTICIPATE_DEPTH, 1.0 + OVERSHOOT, _ease_out(after / strike))
	after -= strike
	# **히트스톱.** 지나친 자리에 그대로 선다 — 무거울수록 길다.
	if after < hitstop:
		return 1.0 + OVERSHOOT
	# 감쇠 진동으로 마무리에 앉는다. **오버슛이 그냥 진폭이 1 을 넘는 진동이다.**
	var settling := after - hitstop
	var u := clampf(settling / recover, 0.0, 1.0)
	# `(1 - u)` 를 곱해 **끝에서 정확히 1** 이 되게 한다. 감쇠만으로는 0.992 에서 멈추는데,
	# 마무리 자세가 값과 어긋나면 다음 동작이 그 차이만큼 튄다 (체인의 바탕이다).
	var decay := exp(-SETTLE_DECAY * settling) * (1.0 - u)
	return 1.0 + OVERSHOOT * decay * cos(TAU * SETTLE_CYCLES * u)


## **지금 몸이 앞으로 나가 있는 거리.** 예비에는 음수(뒤로)다.
##
## 「돌아온다」로 두면 후속 동안 0 으로 되돌아간다. 「남는다」면 그 자리에 남는다.
func travel_at(t: float) -> float:
	var at := progress(t)
	var ratio := (
		ADVANCE_BACK * at / ANTICIPATE_DEPTH if at < 0.0 else _ease_out(clampf(at, 0.0, 1.0))
	)
	if returns_home:
		var settling := t - (anticipate + still + strike + hitstop)
		if settling > 0.0:
			ratio *= 1.0 - smoothstep(0.0, 1.0, clampf(settling / recover, 0.0, 1.0))
	return weapon.advance_px() * ratio


## 그 파츠가 읽는 진행도. **파츠마다 시각이 어긋나 있다** — 발이 먼저, 머리가 나중.
func progress_for(t: float, lead: float) -> float:
	return progress(clampf(t + lead * weapon.time_scale(), 0.0, loop_seconds()))


func sample(t: float, features: AnimFeatures) -> CharPose:
	var pose := CharPose.from_rig(rig)
	var at := clampf(t, 0.0, loop_seconds())
	_apply_feet(pose, at, features)
	_apply_torso(pose, at, features)
	_apply_head(pose, at, features)
	_apply_hand(pose, at, features)
	_apply_travel(pose, at, features)
	keep_weapon_off_floor(pose, weapon)
	return pose


## 든 손 — 자세에서 자세로. **무기는 이 손의 자식이라 저절로 따라 돈다.**
##
## **이 파츠가 사슬의 기준이다** (`lead = 0`). 여기가 밀리면 닿는 시각이 통째로 밀린다.
func _apply_hand(pose: CharPose, t: float, f: AnimFeatures) -> void:
	var part := CharWeapon.HOLDER
	var at := progress(t)
	pose.positions[part] += _start_offset.lerp(_end_offset, at) * f.arc
	pose.rotations[part] = lerpf(_start_rotation, _end_rotation, at)

	# 빈손은 **반대로** 뻗어 균형을 잡는다. 가만히 있으면 한쪽만 사는 인형이 된다.
	var off := progress_for(t, LEAD_OFF_HAND * f.delay)
	var idle_hand := CharPart.Id.HAND_FAR
	pose.positions[idle_hand] += Vector2(-OFF_HAND_SWING * off, 3.0 * off) * f.arc
	pose.rotations[idle_hand] = -0.45 * off * f.arc


## 몸 — **예비에 꼬이고 낮아졌다가, 타격에 풀리며 뻗는다.**
##
## 손만 움직이면 팔이 아니라 막대가 도는 것으로 보인다. 그리고 **키가 안 변하면
## 무슨 짓을 해도 평평해 보인다.**
func _apply_torso(pose: CharPose, t: float, f: AnimFeatures) -> void:
	var part := CharPart.Id.TORSO
	var at := progress_for(t, LEAD_TORSO * f.delay)
	var drag := weapon.drag()
	# 예비(음수)에는 꼬임이 크고, 풀릴 때는 그보다 작다 — 감는 데 힘이 더 든다.
	var twist := TORSO_COIL if at < 0.0 else (TORSO_TWIST + DRAG_TWIST * drag)
	var forward := clampf(at, 0.0, 1.0)
	# 예비에 낮아지고 타격 중에 뻗었다가 마무리에 다시 내려앉는다.
	var height := -TORSO_DIP * maxf(-at, 0.0) / ANTICIPATE_DEPTH
	height += TORSO_EXTEND * sin(PI * forward) - TORSO_DROP * forward
	pose.positions[part] += Vector2((TORSO_SHIFT + DRAG_SHIFT * drag) * at, height) * f.arc
	pose.rotations[part] = -twist * at * f.arc
	pose.scales[part] = CharClip.volume_scale(-0.030 * forward * f.squash)


## 머리 — **맨 마지막으로 따라온다.** 예비에는 살짝 반대로 남는다.
func _apply_head(pose: CharPose, t: float, f: AnimFeatures) -> void:
	var part := CharPart.Id.HEAD
	var at := progress_for(t, LEAD_HEAD * f.delay)
	var forward := clampf(at, 0.0, 1.0)
	var height := -TORSO_DIP * 0.55 * maxf(-at, 0.0) / ANTICIPATE_DEPTH
	height += TORSO_EXTEND * 0.6 * sin(PI * forward) - TORSO_DROP * 0.5 * forward
	pose.positions[part] += Vector2(TORSO_SHIFT * 0.6 * at, height) * f.arc
	pose.rotations[part] = -HEAD_TWIST * at * f.arc


## 발 — **가장 먼저 움직인다.** 힘이 땅에서 올라오기 때문이다.
##
## 뒷발이 **미는 발**이라 예비에 눌리고 타격에 뒤꿈치가 뜬다. 앞발은 **딛는 발**이라
## 전진할 때 들려서 앞으로 나간다 (`_apply_travel`).
func _apply_feet(pose: CharPose, t: float, f: AnimFeatures) -> void:
	var at := progress_for(t, LEAD_FEET * f.delay)
	var loaded := maxf(at, 0.0) * f.asymmetry
	var coiled := maxf(-at, 0.0) / ANTICIPATE_DEPTH * f.asymmetry

	var near := CharPart.Id.FOOT_NEAR
	# 예비에는 뒤에 실렸다가 타격에 앞발로 넘어간다.
	pose.scales[near] = CharClip.volume_scale(-FOOT_SQUASH * loaded * f.squash)
	pose.rotations[near] = FOOT_HEEL_LIFT * 0.5 * coiled
	pose.positions[near] += Vector2(0.0, pose.lift_to_clear_ground(near, rig))

	var far := CharPart.Id.FOOT_FAR
	# **회전을 먼저 정하고 나서 올린다.** 재서 올리는 것이라 그 앞의 것만 반영된다.
	pose.rotations[far] = -FOOT_HEEL_LIFT * loaded
	pose.scales[far] = CharClip.volume_scale(-FOOT_SQUASH * 0.7 * coiled * f.squash)
	pose.positions[far] += Vector2(0.0, pose.lift_to_clear_ground(far, rig))


## **몸이 실제로 앞으로 나간다.** 애니메이션이 아니라 위치다 — 리치와 간격을 만든다.
##
## **뒷발은 안 따라간다.** 미는 발이라 땅에 박혀 있어야 힘이 실린다. 앞발만 들려서
## 나간다 — 그래서 전진이 **미끄러짐이 아니라 내딛기**가 된다 (§25.21.2).
func _apply_travel(pose: CharPose, t: float, f: AnimFeatures) -> void:
	var gone := travel_at(t) * f.arc
	if is_zero_approx(gone):
		return
	for part in CharPart.COUNT:
		if part == CharPart.Id.FOOT_FAR:
			continue
		pose.positions[part] += Vector2(gone, 0.0)
	# 앞발은 나가는 동안 들린다. 안 들면 땅을 긁으며 미끄러진다.
	var near := CharPart.Id.FOOT_NEAR
	var lift := STEP_HEIGHT * sin(PI * clampf(progress(t), 0.0, 1.0))
	pose.positions[near] += Vector2(0.0, lift)
	pose.positions[near] += Vector2(0.0, pose.lift_to_clear_ground(near, rig))
