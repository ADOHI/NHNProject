class_name CharIdleClip
extends CharClip
## idle — 호흡 하나에서 시작해 층을 쌓은 것.
##
## 층마다 무엇을 담당하는지와 값을 고른 근거는
## `docs/design/25-character-animation.md` §25.4 에 있다. 요약하면
##
## * **몸** 이 유일한 원본 신호다. 나머지는 그것을 늦게 · 다르게 받는다
## * **머리** 는 늦게 오고 8 자를 그린다. 위치 · 좌우 · 갸웃의 지연이 셋 다 다르다
## * **손** 은 가장 늦고 가장 크게 뜬다. 떠 있는 손이 이 스타일에서 가장 많이 말한다
## * **발** 은 호흡을 안 받는다. 안 움직이는 것이 무게다
##
## 모든 주파수가 **한 바퀴당 정수 회**다. 무리수 비율이면 절대 되돌아오지 않아
## GIF 와 게임 루프의 이음매가 툭 끊긴다.

const LOOP := 4.0

## 상하의 본체. 한 바퀴에 2 회 = 2.0 초에 한 번 숨쉰다.
const BREATH_CYCLES := 2.0

## 좌우로 천천히 흐르는 것. 한 바퀴에 1 회.
##
## 상하 2 회 · 좌우 1 회면 **머리가 8 자를 그린다**(리사주 1:2). idle 의 "호" 가 이것이다.
const DRIFT_CYCLES := 1.0

## 손에만 얹는 잔떨림. 한 바퀴에 3 회 — 호흡과 안 맞물려 보이게 홀수로 골랐다.
const FLUTTER_CYCLES := 3.0

const TORSO_RISE := 2.2
const TORSO_SWAY := 1.1
const TORSO_TILT := 0.012
const TORSO_TILT_DELAY := 0.10
const TORSO_STRETCH := 0.030

## 몸의 2.2 보다 크다. 몸이 늘어나며 정수리를 밀어 올리므로 강체로 따라와도 2.8 은 된다.
const HEAD_RISE := 3.4
const HEAD_RISE_DELAY := 0.13
const HEAD_SWAY := 2.0
const HEAD_SWAY_DELAY := 0.18

## 위치보다 더 늦다. 이게 목의 무게다.
const HEAD_TILT := 0.030
const HEAD_TILT_DELAY := 0.30

## 몸이 늘어날 때 머리는 **반대로** 눌린다. 올라가는 것에 눌리는 것이 붙어야 가속이 보인다.
const HEAD_SQUASH := 0.018

## 몸보다 크다. 물리적으로는 매달린 것이 덜 흔들려야 하지만, 떠 있는 손은
## 부표처럼 더 크게 뜨는 쪽이 예쁘다. **물리가 아니라 미감으로 고른 값이다.**
const HAND_RISE := 3.6

## 몸 · 머리보다 가장 늦다 — 붙어 있지 않으니까.
const HAND_DELAY := 0.19
const HAND_DELAY_SKEW := 0.09
const HAND_RISE_SKEW := 0.18
const HAND_SPREAD := 1.3
const HAND_SPREAD_DELAY := 0.05
const HAND_CARRY := 1.6
const HAND_CARRY_DELAY := 0.12
const HAND_FLUTTER := 0.8
const HAND_FLUTTER_SKEW := 0.22
const HAND_TILT := 0.05
const HAND_TILT_DELAY := 0.08
const HAND_SQUASH := 0.015

const FOOT_SQUASH := 0.030
const FOOT_LIFT := 0.9
const FOOT_SPLAY := 0.5
const FOOT_TILT := 0.05


func clip_name() -> String:
	return "idle"


func loop_seconds() -> float:
	return LOOP


func sample(t: float, features: AnimFeatures) -> CharPose:
	var pose := CharPose.from_rig(rig)
	_apply_torso(pose, t, features)
	_apply_head(pose, t, features)
	_apply_hand(pose, t, features, CharPart.Id.HAND_L)
	_apply_hand(pose, t, features, CharPart.Id.HAND_R)
	_apply_foot(pose, t, features, CharPart.Id.FOOT_L)
	_apply_foot(pose, t, features, CharPart.Id.FOOT_R)
	return pose


## 몸 — 나머지 전부의 원본 신호.
##
## 좌우 성분을 `arc` 로 묶은 이유: 상하만 있으면 몸이 직선으로 오간다.
## 좌우가 붙어야 경로가 곡선이 된다. 그래서 이것이 "호" 다.
func _apply_torso(pose: CharPose, t: float, f: AnimFeatures) -> void:
	var part := CharPart.Id.TORSO
	var breath := _breath(t, 0.0, f)
	pose.positions[part] += Vector2(TORSO_SWAY * _drift(t, 0.0, f) * f.arc, TORSO_RISE * breath)
	# 무게가 실린 쪽으로 기운다 — 정수리가 `+x` 로 가는 것이므로 시계 방향, 즉 음수다.
	pose.rotations[part] = -TORSO_TILT * _drift(t, TORSO_TILT_DELAY, f) * f.arc
	# 면적 보존 — 가슴이 부풀면 몸통이 좁아진다.
	pose.scales[part] = _volume_scale(TORSO_STRETCH * breath * f.squash)


## 머리 — 늦게, 그리고 8 자로.
##
## 지연 값이 셋 다 다르다(0.13 · 0.18 · 0.30)는 게 핵심이다. **한 파츠 안에서도
## 이동과 회전이 따로 늦어야** 덩어리가 아니라 살로 읽힌다.
func _apply_head(pose: CharPose, t: float, f: AnimFeatures) -> void:
	var part := CharPart.Id.HEAD
	var breath := _breath(t, HEAD_RISE_DELAY, f)
	pose.positions[part] += Vector2(
		HEAD_SWAY * _drift(t, HEAD_SWAY_DELAY, f) * f.arc, HEAD_RISE * breath
	)
	# 몸이 `+x` 로 갈 때 머리는 늦으므로 정수리가 상대적으로 `-x` 에 남는다 = 반시계, 양수.
	# 몸의 기울기와 부호가 반대라 척추의 S 곡선이 생긴다 — 의도한 것이다.
	#
	# `arc` 로 묶는다: 갸웃거림은 좌우 흐름과 같은 곡선의 일부다(둘 다 `_drift` 가 원본).
	# 그래서 "호" 를 끄면 머리가 정말로 상하로만 오간다.
	pose.rotations[part] = HEAD_TILT * _drift(t, HEAD_TILT_DELAY, f) * f.arc
	pose.scales[part] = _volume_scale(-HEAD_SQUASH * breath * f.squash)


## 손 — 이 스타일에서 가장 많이 말하는 파츠.
##
## 비대칭은 **오른손에만** 얹는다. 그래서 `asymmetry = 0` 이면 두 손의 상하가
## 정확히 같아지고, 켜면 어긋난다. 스위치가 실제로 무엇을 하는지가 눈에 보인다.
func _apply_hand(pose: CharPose, t: float, f: AnimFeatures, part: CharPart.Id) -> void:
	var outward := CharPart.outward_sign(part)
	var skew := (1.0 if CharPart.is_right(part) else 0.0) * f.asymmetry
	var delay := HAND_DELAY + HAND_DELAY_SKEW * skew
	var rise := HAND_RISE * (1.0 + HAND_RISE_SKEW * skew)
	var breath := _breath(t, delay, f)

	var offset_y := rise * breath + HAND_FLUTTER * _flutter(t, delay + HAND_FLUTTER_SKEW * skew, f)
	# 가슴이 벌어지면 손이 바깥으로 밀리고, 몸의 좌우 이동을 더 늦게 끌고 온다.
	var offset_x := outward * HAND_SPREAD * _breath(t, delay + HAND_SPREAD_DELAY, f)
	offset_x += HAND_CARRY * _drift(t, delay + HAND_CARRY_DELAY, f)

	pose.positions[part] += Vector2(offset_x * f.arc, offset_y)
	# 뜨면서 바깥으로 젖혀진다. 오른손(`outward = +1`)의 위쪽이 `+x` 로 가므로 음수다.
	pose.rotations[part] = -outward * HAND_TILT * _breath(t, delay + HAND_TILT_DELAY, f)
	pose.scales[part] = _volume_scale(-HAND_SQUASH * breath * f.squash)


## 발 — 안 움직이는 것이 무게다.
##
## **호흡을 안 받는다.** 발까지 같이 떠 있으면 캐릭터가 땅에 서 있지 않고 물에 떠 있다.
## 발이 하는 일은 무게 이동뿐이고, 그것이 전부 `asymmetry` 에 걸려 있다.
##
## 들리는 양이 1 px 도 안 되는데 효과가 큰 것은 **비대칭이 곧 생명이라서** 그렇다.
func _apply_foot(pose: CharPose, t: float, f: AnimFeatures, part: CharPart.Id) -> void:
	var outward := CharPart.outward_sign(part)
	# 무게가 `+x` 쪽에 실리면 `drift > 0`. 그때 오른발이 「실린 발」이다.
	var weight := outward * _drift(t, 0.0, f) * f.asymmetry
	var loaded := maxf(weight, 0.0)
	var freed := maxf(-weight, 0.0)

	pose.positions[part] += Vector2(outward * FOOT_SPLAY * loaded, FOOT_LIFT * freed)
	pose.rotations[part] = -outward * FOOT_TILT * freed
	# 피벗이 밑면이라 눌려도 밑면이 정확히 땅에 남는다 (`char_rig.gd` §피벗).
	pose.scales[part] = _volume_scale(-FOOT_SQUASH * loaded * f.squash)


## 지연이 걸린 사인파. **모든 것이 「시각의 함수」인 지점이 여기다.**
##
## `features.delay` 가 0 이면 지연이 통째로 사라져 모든 파츠가 같은 위상이 된다.
func _wave(cycles: float, t: float, delay: float, f: AnimFeatures) -> float:
	return sin(TAU * cycles * (t - delay * f.delay) / LOOP)


func _breath(t: float, delay: float, f: AnimFeatures) -> float:
	return _wave(BREATH_CYCLES, t, delay, f)


func _drift(t: float, delay: float, f: AnimFeatures) -> float:
	return _wave(DRIFT_CYCLES, t, delay, f)


func _flutter(t: float, delay: float, f: AnimFeatures) -> float:
	return _wave(FLUTTER_CYCLES, t, delay, f)


## 면적을 보존하는 배율. `stretch` 가 0 이면 정확히 `Vector2.ONE` 이다.
##
## `1.0 / 1.0` 이 부동소수점에서도 정확히 `1.0` 이므로 "배율 끄기" 가 근사가 아니라 등식이다.
func _volume_scale(stretch: float) -> Vector2:
	var sy := 1.0 + stretch
	return Vector2(1.0 / sy, sy)
