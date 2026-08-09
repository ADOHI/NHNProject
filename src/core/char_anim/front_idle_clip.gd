class_name CharFrontIdleClip
extends CharClip
## **정면 문법의 idle. 쓰려고 만든 것이 아니라 대조군이다.**
##
## 이 프로토타입의 첫 판이 정면 시점이었고, 시점을 사이드 사선으로 바로잡으면서
## 궤도를 다시 잡았다. 그때 "무엇이 실제로 달라졌는가" 를 말로만 적으면
## 확인할 방법이 없다. 그래서 **같은 캐릭터 · 같은 그림 · 같은 네 축**에
## 정면 문법만 얹은 것을 남겨 나란히 돌린다 (`idle_vs_front.gif`).
##
## 정면 문법의 세 가지 표시:
##
## 1. **발이 통째로 들린다.** 뒤꿈치를 굴리지 않는다 — 옆에서 보면 발이 공중에서
##    평행이동해 서 있는 것으로 안 보인다
## 2. **두 손이 같은 궤도를 돈다.** 좌우 거울일 뿐 크기도 속도도 같아서,
##    앞뒤가 있는 자세에 얹으면 **종이 인형 두 장**이 된다
## 3. **깊이가 없다.** `depth` 를 아예 안 본다
##
## 값은 사이드판과 같은 것을 쓴다. 달라지는 것이 **문법뿐**이어야 비교가 성립한다.

const LOOP := CharIdleClip.LOOP


func clip_name() -> String:
	return "idle (정면 문법 - 대조군)"


func loop_seconds() -> float:
	return LOOP


func sample(t: float, features: AnimFeatures) -> CharPose:
	var pose := CharPose.from_rig(rig)
	_apply_torso(pose, t, features)
	_apply_head(pose, t, features)
	_apply_hand(pose, t, features, CharPart.Id.HAND_FAR)
	_apply_hand(pose, t, features, CharPart.Id.HAND_NEAR)
	_apply_foot(pose, t, features, CharPart.Id.FOOT_FAR)
	_apply_foot(pose, t, features, CharPart.Id.FOOT_NEAR)
	rein_in_limbs(pose)
	return pose


func _apply_torso(pose: CharPose, t: float, f: AnimFeatures) -> void:
	var part := CharPart.Id.TORSO
	var breath := _breath(t, 0.0, f)
	# 정면에서는 좌우 흔들림이 곁가지라 진폭이 작다.
	pose.positions[part] += Vector2(
		1.1 * _sway(t, 0.0, f) * f.arc, CharIdleClip.TORSO_RISE * breath
	)
	pose.rotations[part] = -0.012 * _sway(t, CharIdleClip.TORSO_LEAN_DELAY, f) * f.arc
	pose.scales[part] = CharClip.volume_scale(CharIdleClip.TORSO_STRETCH * breath * f.squash)


func _apply_head(pose: CharPose, t: float, f: AnimFeatures) -> void:
	var part := CharPart.Id.HEAD
	var breath := _breath(t, CharIdleClip.HEAD_RISE_DELAY, f)
	pose.positions[part] += Vector2(
		2.0 * _sway(t, CharIdleClip.HEAD_SWAY_DELAY, f) * f.arc, CharIdleClip.HEAD_RISE * breath
	)
	pose.rotations[part] = (
		CharIdleClip.HEAD_TILT * _sway(t, CharIdleClip.HEAD_TILT_DELAY, f) * f.arc
	)
	pose.scales[part] = CharClip.volume_scale(-CharIdleClip.HEAD_SQUASH * breath * f.squash)


## 두 손이 **완전히 같은 궤도**를 돈다. 좌우로 벌어지는 방향만 거울이다.
## `depth` 를 안 보므로 뒷손이 앞손보다 덜 움직이지도, 느려 보이지도 않는다.
func _apply_hand(pose: CharPose, t: float, f: AnimFeatures, part: CharPart.Id) -> void:
	var mirror := CharPart.depth_sign(part)
	var delay := CharIdleClip.HAND_DELAY
	var breath := _breath(t, delay, f)

	var offset_y := CharIdleClip.HAND_RISE * breath
	offset_y += CharIdleClip.HAND_FLUTTER * _flutter(t, delay, f)
	var offset_x := (
		mirror * CharIdleClip.HAND_SPREAD * _breath(t, delay + CharIdleClip.HAND_SPREAD_DELAY, f)
	)
	offset_x += CharIdleClip.HAND_CARRY * _sway(t, delay + CharIdleClip.HAND_CARRY_DELAY, f)

	pose.positions[part] += Vector2(offset_x * f.arc, offset_y)
	# 거울로 뒤집는다 — 정면에서는 두 손이 서로 반대 방향에서 보이기 때문이다.
	pose.rotations[part] = (
		-mirror * CharIdleClip.HAND_TILT * _breath(t, delay + CharIdleClip.HAND_TILT_DELAY, f)
	)
	pose.scales[part] = CharClip.volume_scale(-CharIdleClip.HAND_SQUASH * breath * f.squash)


## 무게가 빠진 발이 **통째로** 들린다. 뒤꿈치 굴림이 없다.
func _apply_foot(pose: CharPose, t: float, f: AnimFeatures, part: CharPart.Id) -> void:
	var side := CharPart.depth_sign(part)
	var weight := side * _sway(t, 0.0, f) * f.asymmetry
	var loaded := maxf(weight, 0.0)
	var freed := maxf(-weight, 0.0)

	pose.positions[part] += Vector2(side * 0.5 * loaded, 0.9 * freed)
	pose.rotations[part] = -side * 0.05 * freed
	pose.scales[part] = CharClip.volume_scale(-CharIdleClip.FOOT_SQUASH * loaded * f.squash)


func _breath(t: float, delay: float, f: AnimFeatures) -> float:
	return wave(CharIdleClip.BREATH_CYCLES, t, delay, f)


func _sway(t: float, delay: float, f: AnimFeatures) -> float:
	return wave(CharIdleClip.SWAY_CYCLES, t, delay, f)


func _flutter(t: float, delay: float, f: AnimFeatures) -> float:
	return wave(CharIdleClip.FLUTTER_CYCLES, t, delay, f)
