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

## 예비 — 치기 전에 **반대로** 물러나는 시간. 이것이 없으면 타격이 갑자기 튀어나온다.
const ANTICIPATE := 0.16

## 타격 — 실제로 지나가는 시간. **짧을수록 세게 보인다.**
const STRIKE := 0.11

## 후속 — 지나친 것이 되돌아와 앉는 시간.
const RECOVER := 0.42

## 예비에서 시작 자세의 **반대쪽으로** 얼마나 더 가는가 (진행도 기준).
const ANTICIPATE_DEPTH := 0.14

## 타격이 목표를 지나치는 양. **1 을 넘는 것이 오버슛이다.**
##
## 자세를 정할 때 **이 값까지 넘겨서** 검끝이 어디 가는지 봐야 한다 — 마무리 자세가
## 안전해도 지나치는 순간에 검이 바닥을 뚫는다. 실제로 그렇게 뚫었다 (§25.11.2).
const OVERSHOOT := 0.14

## 후속의 되튐이 잦아드는 빠르기와 흔들리는 횟수.
const SETTLE_DECAY := 7.0
const SETTLE_CYCLES := 1.6

## 몸이 휘두름을 받아 도는 양. 손만 움직이면 팔이 아니라 막대가 도는 것으로 보인다.
const TORSO_TWIST := 0.10
const TORSO_SHIFT := 3.4
const TORSO_DROP := 2.6

## 머리는 몸보다 늦게 따라온다. idle 과 같은 규칙이다.
const HEAD_TWIST := 0.07
const HEAD_DELAY := 0.06

## 무게가 실리는 발. 휘두르면 앞발을 디디고 뒷발의 뒤꿈치가 뜬다.
const FOOT_HEEL_LIFT := 0.16
const FOOT_SQUASH := 0.045

var from_guard: WeaponGuard.Id = WeaponGuard.Id.HIGH
var to_guard: WeaponGuard.Id = WeaponGuard.Id.LOW


func _init(p_rig: CharRig, p_from := WeaponGuard.Id.HIGH, p_to := WeaponGuard.Id.LOW) -> void:
	super(p_rig)
	from_guard = p_from
	to_guard = p_to


func clip_name() -> String:
	return "swing %s에서 %s로" % [WeaponGuard.guard_name(from_guard), WeaponGuard.guard_name(to_guard)]


func loop_seconds() -> float:
	return ANTICIPATE + STRIKE + RECOVER


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
	if t < ANTICIPATE:
		# 뒤로 물러난다. 끝에서 속도가 0 이 되어야 타격으로 매끄럽게 넘어간다.
		return -ANTICIPATE_DEPTH * sin(PI * (t / ANTICIPATE))
	var struck := t - ANTICIPATE
	if struck < STRIKE:
		var u := struck / STRIKE
		# 뒤로 물러난 자리에서 목표를 지나친 자리까지. 끝이 완만해야 「닿았다」로 읽힌다.
		return lerpf(-ANTICIPATE_DEPTH, 1.0 + OVERSHOOT, smoothstep(0.0, 1.0, u))
	# 감쇠 진동으로 마무리에 앉는다. **오버슛이 그냥 진폭이 1 을 넘는 진동이다.**
	var settling := struck - STRIKE
	var u := clampf(settling / RECOVER, 0.0, 1.0)
	# `(1 - u)` 를 곱해 **끝에서 정확히 1** 이 되게 한다. 감쇠만으로는 0.992 에서 멈추는데,
	# 마무리 자세가 값과 어긋나면 다음 동작이 그 차이만큼 튄다 (체인의 바탕이다).
	var decay := exp(-SETTLE_DECAY * settling) * (1.0 - u)
	return 1.0 + OVERSHOOT * decay * cos(TAU * SETTLE_CYCLES * u)


func sample(t: float, features: AnimFeatures) -> CharPose:
	var pose := CharPose.from_rig(rig)
	var at := progress(clampf(t, 0.0, loop_seconds()))
	_apply_hand(pose, at, features)
	_apply_torso(pose, at, features)
	_apply_head(pose, t, features)
	_apply_feet(pose, at, features)
	return pose


## 든 손 — 자세에서 자세로. **무기는 이 손의 자식이라 저절로 따라 돈다.**
func _apply_hand(pose: CharPose, at: float, f: AnimFeatures) -> void:
	var part := CharWeapon.HOLDER
	var start := WeaponGuard.hand_offset(from_guard)
	var finish := WeaponGuard.hand_offset(to_guard)
	pose.positions[part] += start.lerp(finish, at) * f.arc
	pose.rotations[part] = lerpf(
		WeaponGuard.hand_rotation(from_guard), WeaponGuard.hand_rotation(to_guard), at
	)
	# 빈손은 반대로 뻗어 균형을 잡는다. 가만히 있으면 한쪽만 사는 인형이 된다.
	var idle_hand := CharPart.Id.HAND_FAR
	pose.positions[idle_hand] += Vector2(-start.lerp(finish, at).x * 0.35, 0.0) * f.arc
	pose.rotations[idle_hand] = -0.30 * at * f.arc


func _apply_torso(pose: CharPose, at: float, f: AnimFeatures) -> void:
	var part := CharPart.Id.TORSO
	pose.positions[part] += Vector2(TORSO_SHIFT * at, -TORSO_DROP * at) * f.arc
	pose.rotations[part] = -TORSO_TWIST * at * f.arc
	pose.scales[part] = CharClip.volume_scale(-0.030 * maxf(at, 0.0) * f.squash)


func _apply_head(pose: CharPose, t: float, f: AnimFeatures) -> void:
	var part := CharPart.Id.HEAD
	# 머리는 **늦게** 따라온다 — 지연이 시각의 함수라 그냥 과거의 진행도를 읽으면 된다.
	var late := progress(clampf(t - HEAD_DELAY * f.delay, 0.0, loop_seconds()))
	pose.positions[part] += Vector2(TORSO_SHIFT * 0.6 * late, -TORSO_DROP * 0.5 * late) * f.arc
	pose.rotations[part] = -HEAD_TWIST * late * f.arc


## 발 — 휘두르면 앞발을 디디고 뒷발의 뒤꿈치가 뜬다. idle 과 같은 접지 규칙이다.
func _apply_feet(pose: CharPose, at: float, f: AnimFeatures) -> void:
	var loaded := maxf(at, 0.0) * f.asymmetry
	var near := CharPart.Id.FOOT_NEAR
	pose.scales[near] = CharClip.volume_scale(-FOOT_SQUASH * loaded * f.squash)

	var far := CharPart.Id.FOOT_FAR
	var heel := -FOOT_HEEL_LIFT * loaded
	pose.positions[far] += Vector2(0.0, rig.sole_drop(far, heel))
	pose.rotations[far] = heel
