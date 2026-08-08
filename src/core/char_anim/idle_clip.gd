class_name CharIdleClip
extends CharClip
## idle — **사이드 사선**의 문법으로.
##
## 정면 걸음과 측면 걸음이 완전히 다르듯, 정면 idle 과 측면 idle 도 다르다.
## 무엇이 다른지가 이 파일의 전부다 (`docs/design/25-character-animation.md` §25.4).
##
## | | 정면 | **사이드 사선** |
## | --- | --- | --- |
## | 무게 | 좌우로 오간다 | **앞뒤로, 지면을 따라** 오간다 |
## | 발 | 한쪽이 통째로 들린다 | **뒤꿈치가 들린다.** 발끝은 땅에 남는다 |
## | 손 | 거울 대칭에서 위상만 어긋난다 | **앞손과 뒷손의 크기 · 속도가 다르다** |
## | 깊이 | 없다 | 겹침 · 크기 · 고주파 감쇠로 만든다 |
##
## 안 바뀐 것: 트랜스폼만 쓴다 · 관절 없음 · 파츠 여섯 · `sample()` 은 순수 함수.
## 지연 · 호 · 배율 · 비대칭 네 축도 그대로다. **앞뒤(`depth`)가 다섯째로 붙었다.**

const LOOP := 4.0

## 상하의 본체. 한 바퀴에 2 회 = 2.0 초에 한 번 숨쉰다.
const BREATH_CYCLES := 2.0

## **앞뒤 무게 이동.** 한 바퀴에 1 회.
##
## 정면일 때는 좌우로 흐르는 곁가지였지만, 측면에서는 이것이 **자세의 본체**다.
## 사람이 가만히 서 있을 때 실제로 하는 일이 앞뒤로 아주 조금씩 무게를 옮기는 것이다.
## 그래서 진폭을 정면의 1.1 에서 2.6 으로 키웠다.
const SWAY_CYCLES := 1.0

## 손에만 얹는 잔떨림. 한 바퀴에 3 회 — 호흡과 안 맞물려 보이게 홀수로 골랐다.
const FLUTTER_CYCLES := 3.0

const TORSO_RISE := 2.2
const TORSO_SWAY := 2.6
const TORSO_LEAN := 0.016
const TORSO_LEAN_DELAY := 0.10
const TORSO_STRETCH := 0.030

const HEAD_RISE := 3.4
const HEAD_RISE_DELAY := 0.13

## 앞뒤 2.4 회 + 상하 2 회 = 리사주 1:2. 옆에서 보면 머리가 **시상면에서 8 자**를 그린다.
## 실제로 사람 머리가 그렇게 움직인다 — 정면에서 8 자를 그리던 것과 축만 바뀐 것이 아니라
## 이쪽이 원래 맞는 평면이다.
const HEAD_SWAY := 2.4
const HEAD_SWAY_DELAY := 0.18

const HEAD_TILT := 0.032
const HEAD_TILT_DELAY := 0.30
const HEAD_SQUASH := 0.018

const HAND_RISE := 3.6
const HAND_DELAY := 0.19
const HAND_SPREAD := 1.3
const HAND_SPREAD_DELAY := 0.05
const HAND_CARRY := 1.8
const HAND_CARRY_DELAY := 0.12
const HAND_FLUTTER := 0.8

## 뒷손의 잔떨림 위상 어긋남. **`depth` 소관이지 `asymmetry` 소관이 아니다.**
##
## 정면일 때는 두 손의 차이가 전부 `asymmetry` 였다. 측면에서는 그 차이가
## **앞뒤에서 나온다.** 축을 안 옮기면 "비대칭을 껐는데 두 손이 여전히 다르다" 가 되어
## 조절판이 거짓말한다.
const HAND_FLUTTER_SKEW := 0.22
const HAND_TILT := 0.05
const HAND_TILT_DELAY := 0.08
const HAND_SQUASH := 0.015

## 뒷손의 진폭 배수. 멀리 있는 것은 화면에서 덜 움직인다.
const FAR_MOTION := 0.72

## 뒷손의 **잔떨림** 배수. 진폭보다 더 깎는다.
##
## **이것이 「느려 보인다」를 만드는 값이다.** 사람은 속도를 고주파 성분의 양으로 읽는다.
## 진폭만 줄이면 그냥 작은 손이 똑같이 빠르게 움직이는 것으로 보인다.
const FAR_FLUTTER := 0.35

## 뒷손이 더 늦다. 멀수록 굼뜨다.
const FAR_DELAY := 0.11

const FOOT_SQUASH := 0.030

## 뒤꿈치를 드는 각도. 발끝을 축으로 돌므로 위치 보정이 따라붙는다.
const FOOT_HEEL_LIFT := 0.075

## 무게가 빠진 발이 뒤로 조금 미끄러지는 양.
const FOOT_SLIDE := 0.4


func clip_name() -> String:
	return "idle (사이드 사선)"


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
	return pose


## 몸 — 나머지 전부의 원본 신호. 위로 숨쉬고 앞뒤로 무게를 옮긴다.
func _apply_torso(pose: CharPose, t: float, f: AnimFeatures) -> void:
	var part := CharPart.Id.TORSO
	var breath := _breath(t, 0.0, f)
	pose.positions[part] += Vector2(TORSO_SWAY * _sway(t, 0.0, f) * f.arc, TORSO_RISE * breath)
	# 무게가 실린 쪽으로 기운다. 앞(`+x`)으로 갈 때 정수리가 앞으로 = 시계 방향 = 음수.
	pose.rotations[part] = -TORSO_LEAN * _sway(t, TORSO_LEAN_DELAY, f) * f.arc
	pose.scales[part] = CharClip.volume_scale(TORSO_STRETCH * breath * f.squash)


## 머리 — 늦게, 그리고 시상면에서 8 자로.
func _apply_head(pose: CharPose, t: float, f: AnimFeatures) -> void:
	var part := CharPart.Id.HEAD
	var breath := _breath(t, HEAD_RISE_DELAY, f)
	pose.positions[part] += Vector2(
		HEAD_SWAY * _sway(t, HEAD_SWAY_DELAY, f) * f.arc, HEAD_RISE * breath
	)
	# 몸이 앞으로 갈 때 머리는 늦으므로 정수리가 상대적으로 뒤에 남는다 = 반시계, 양수.
	# 몸의 기울기와 부호가 반대라 척추의 S 곡선이 생긴다 — 의도한 것이다.
	pose.rotations[part] = HEAD_TILT * _sway(t, HEAD_TILT_DELAY, f) * f.arc
	pose.scales[part] = CharClip.volume_scale(-HEAD_SQUASH * breath * f.squash)


## 손 — 앞손과 뒷손은 **위상만 다른 같은 궤도가 아니다.**
##
## 진폭 · 지연 · 잔떨림 셋이 전부 다르고, 셋 다 `depth` 가 잡는다.
## `depth = 0` 이면 뒷손이 앞손과 똑같이 움직여 종이 인형 두 장이 된다.
func _apply_hand(pose: CharPose, t: float, f: AnimFeatures, part: CharPart.Id) -> void:
	var depth_sign := CharPart.depth_sign(part)
	var far := 1.0 if CharPart.is_far(part) else 0.0
	# 먼 쪽일수록 1 에서 멀어지는 배수들. 가까운 쪽은 `far = 0` 이라 전부 1 이 된다.
	var motion := lerpf(1.0, FAR_MOTION, far * f.depth)
	var flutter_scale := lerpf(1.0, FAR_FLUTTER, far * f.depth)
	var delay := HAND_DELAY + FAR_DELAY * far * f.depth
	var breath := _breath(t, delay, f)

	var offset_y := HAND_RISE * motion * breath
	offset_y += (
		HAND_FLUTTER * flutter_scale * _flutter(t, delay + HAND_FLUTTER_SKEW * far * f.depth, f)
	)

	# 가슴이 벌어지면 앞손은 앞으로, 뒷손은 뒤로 밀린다.
	var offset_x := depth_sign * HAND_SPREAD * _breath(t, delay + HAND_SPREAD_DELAY, f)
	# 몸의 앞뒤 무게 이동을 더 늦게 끌고 온다.
	offset_x += HAND_CARRY * motion * _sway(t, delay + HAND_CARRY_DELAY, f)

	pose.positions[part] += Vector2(offset_x * f.arc, offset_y)
	# 두 손이 같은 각도에서 보이므로 회전 방향도 같다 — 정면처럼 거울로 뒤집지 않는다.
	pose.rotations[part] = HAND_TILT * motion * _breath(t, delay + HAND_TILT_DELAY, f)
	pose.scales[part] = CharClip.volume_scale(-HAND_SQUASH * breath * f.squash)


## 발 — **뒤꿈치가 들린다.** 이것이 측면 문법의 핵심이다.
##
## 정면에서는 무게가 빠진 발이 통째로 들렸다. 옆에서 그렇게 하면 발이 공중에 뜬 채
## 평행이동하는 것으로 보여 서 있는 것이 아니게 된다. 옆에서 사람이 하는 일은
## **발끝을 땅에 붙인 채 뒤꿈치를 드는 것**이다.
##
## 피벗은 밑면 한가운데에 고정되어 있으므로, 회전만 시키면 발끝이 땅을 파고든다.
## 그래서 회전이 발끝을 내린 만큼을 다시 들어 올린다 — 그 보정이 아래의 `toe_drop` 이다.
func _apply_foot(pose: CharPose, t: float, f: AnimFeatures, part: CharPart.Id) -> void:
	var depth_sign := CharPart.depth_sign(part)
	var far := 1.0 if CharPart.is_far(part) else 0.0
	var motion := lerpf(1.0, FAR_MOTION, far * f.depth)

	# 몸이 앞(`+x`)으로 가면 앞발에 무게가 실린다. 뒤로 가면 뒷발이 받는다.
	var weight := depth_sign * _sway(t, 0.0, f) * f.asymmetry
	var loaded := maxf(weight, 0.0)
	var freed := maxf(-weight, 0.0)

	var heel := -FOOT_HEEL_LIFT * motion * freed
	# 발끝을 축으로 돌리려면 피벗을 그만큼 들어 올려야 한다. **이 값이 유일한 상승분이다** —
	# 여기에 「전체를 조금 더 띄우는」 항을 더하면 그만큼 발끝이 땅에서 떠 버린다.
	# 처음에 0.5 를 더했다가 발끝이 정확히 그만큼 뜨는 것을 테스트가 잡았다.
	var toe_drop := rig.sole_drop(part, heel)
	pose.positions[part] += Vector2(-FOOT_SLIDE * freed, toe_drop)
	pose.rotations[part] = heel
	# 피벗이 밑면이라 눌려도 밑면이 정확히 자기 지면에 남는다.
	pose.scales[part] = CharClip.volume_scale(-FOOT_SQUASH * loaded * f.squash)


func _breath(t: float, delay: float, f: AnimFeatures) -> float:
	return wave(BREATH_CYCLES, t, delay, f)


func _sway(t: float, delay: float, f: AnimFeatures) -> float:
	return wave(SWAY_CYCLES, t, delay, f)


func _flutter(t: float, delay: float, f: AnimFeatures) -> float:
	return wave(FLUTTER_CYCLES, t, delay, f)
