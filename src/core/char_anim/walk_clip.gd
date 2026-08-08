class_name CharWalkClip
extends CharClip
## walk — **「디딘 발」과 「나는 발」이 다른 규칙을 따른다.**
##
## idle 은 두 발이 둘 다 디딘 발이었다. 걸음의 정체는 한 발만 디디고 있다는 것이고,
## 그 둘이 완전히 다른 규칙을 따른다는 것이다
## (`docs/design/25-character-animation.md` §25.10).
##
## | | 디딘 발 | 나는 발 |
## | --- | --- | --- |
## | 접지 | 땅에 붙어 있다 | 떠 있다 |
## | 앞뒤 속도 | **일정** (지면 속도) | 빠르다 |
## | 회전 | 뒤꿈치 → 평평 → 발끝으로 구른다 | 발끝이 내려갔다 올라온다 |
##
## **깊이(near · far)는 교대하지 않는다.** 옆에서 보면 가까운 다리는 끝까지 가까운
## 다리다. 교대하는 것은 앞뒤 「위치」이지 「깊이」가 아니다. 그래서 그리는 순서를
## 넘길 일이 없고, 넘기지 않으므로 팝도 없다 (§25.10.1).
##
## **걸음은 사인파로 못 만든다.** 디딘 발이 등속이어야 하는데 사인은 속도가 변한다.
## 「사건 이후 흐른 시간의 함수」 구조는 그대로지만 그 함수가 사인일 필요는 없다.

## 한 걸음. 두 발이 각각 한 번씩 디디고 난다. 25 fps 로 정확히 30 장이라 GIF 가 맞아떨어진다.
const STRIDE := 1.2

## 한 걸음에서 발이 땅에 붙어 있는 비율.
##
## **0.5 를 넘느냐가 걷기와 달리기를 가른다.** 넘으면 두 발이 동시에 땅에 있는
## **양발 지지**가 생기고(걷기), 미만이면 둘 다 떠 있는 체공이 생긴다(달리기).
## `run` 에서 바꿀 값이 이것 하나다.
const STANCE := 0.6

## 발이 앞뒤로 오가는 전체 거리. 리그 폭(손 끝에서 끝까지 72)에 대해 보고 정했다.
const STEP_LENGTH := 26.0

## 나는 발이 뜨는 높이.
const SWING_LIFT := 7.0

## 발꿈치가 닿을 때 발끝이 들린 각도 (반시계 = 양수).
const HEEL_STRIKE := 0.24

## 발끝으로 밀고 나갈 때 뒤꿈치가 들린 각도 (시계 = 음수라 부호를 붙여 쓴다).
const TOE_OFF := 0.34

## 두 발이 오가는 한가운데. 몸 밑을 지나야 걸음으로 읽힌다 —
## 각자 자기 쉬는 자리 근처에서만 흔들면 발이 교차하지 않아 어정거리는 것이 된다.
const TRACK_CENTER := -2.0

const TORSO_BOB := 3.2
const TORSO_BOB_DELAY := 0.09
const TORSO_SURGE := 1.1
const TORSO_LEAN := 0.045
const TORSO_SQUASH := 0.032

const HEAD_BOB := 3.0
const HEAD_BOB_DELAY := 0.13
const HEAD_SURGE := 1.6
const HEAD_TILT := 0.030
const HEAD_TILT_DELAY := 0.26
const HEAD_SQUASH := 0.016

## 손이 앞뒤로 흔들리는 거리. 걸음에서는 손이 idle 보다 훨씬 크게 움직인다.
const HAND_SWING := 7.5
const HAND_SWING_DELAY := 0.10
const HAND_BOB := 2.2
const HAND_BOB_DELAY := 0.16
const HAND_TILT := 0.09

## 뒷손·뒷발의 배수. idle 과 같은 값이라 깊이가 클립마다 안 달라 보인다.
const FAR_MOTION := 0.72
const FAR_DELAY := 0.11


func clip_name() -> String:
	return "walk (사이드 사선)"


func loop_seconds() -> float:
	return STRIDE


func sample(t: float, features: AnimFeatures) -> CharPose:
	var pose := CharPose.from_rig(rig)
	_apply_torso(pose, t, features)
	_apply_head(pose, t, features)
	_apply_hand(pose, t, features, CharPart.Id.HAND_FAR)
	_apply_hand(pose, t, features, CharPart.Id.HAND_NEAR)
	_apply_foot(pose, t, features, CharPart.Id.FOOT_FAR)
	_apply_foot(pose, t, features, CharPart.Id.FOOT_NEAR)
	return pose


## 이 파츠가 짝지어진 발의 걸음 위상. `0` 이 그 발의 뒤꿈치가 닿는 순간이다.
##
## 뒷발이 반 걸음 늦다. **이 0.5 가 걸음의 전부**이고, 0 으로 두면 두 발이
## 같이 뛰는 토끼가 된다.
func foot_phase(t: float, part: CharPart.Id) -> float:
	var offset := 0.5 if CharPart.is_far(part) else 0.0
	return fposmod(t / STRIDE + offset, 1.0)


## 디딘 발인가. 나는 발과 규칙이 갈리는 지점이라 밖에서도 물어볼 수 있게 열어 둔다.
func is_planted(t: float, part: CharPart.Id, f: AnimFeatures) -> bool:
	var span := lerpf(0.5, STANCE, f.plant)
	return foot_phase(t, part) < span


## 발 — 디딤은 등속, 스윙은 호.
##
## **디딤이 등속이어야 미끄러지지 않는다.** 지면이 일정한 속도로 흐르기 때문이다.
## 사인파로 흔들면 속도가 사인으로 변해 발이 땅 위에서 썰매를 탄다 (§25.10.2).
func _apply_foot(pose: CharPose, t: float, f: AnimFeatures, part: CharPart.Id) -> void:
	var phase := foot_phase(t, part)
	var planted := _planted_foot(phase)
	var sliding := _sliding_foot(phase)
	var track := Vector3(
		lerpf(sliding.x, planted.x, f.plant),
		lerpf(sliding.y, planted.y, f.plant),
		lerpf(sliding.z, planted.z, f.plant)
	)

	var angle := track.z
	# 피벗이 밑면 한가운데라 회전만 시키면 낮은 쪽 밑창 끝이 땅을 파고든다.
	# 그만큼 들어 올리는 것이 **유일한 상승분**이다 (idle 과 같은 규칙).
	# **반너비가 아니라 밑창 길이로 재야 한다** — 부츠 밑창은 반너비보다 좁고 비대칭이다.
	var corner_drop := rig.sole_drop(part, angle)
	var rest_x := rig.rest_positions[part].x
	pose.positions[part] += Vector2(TRACK_CENTER + track.x - rest_x, track.y + corner_drop)
	pose.rotations[part] = angle


## 디딘 발 · 나는 발의 규칙. `(앞뒤, 높이, 회전)`.
##
## 디딤은 `u` 에 대해 **선형**이다 — 그것이 곧 등속이고, 등속이 곧 접지다.
func _planted_foot(phase: float) -> Vector3:
	var half := STEP_LENGTH * 0.5
	if phase < STANCE:
		var u := phase / STANCE
		# 뒤꿈치가 닿았다가(발끝 들림) 평평해지고 발끝으로 민다(뒤꿈치 들림).
		return Vector3(
			half - STEP_LENGTH * u, 0.0, lerpf(HEEL_STRIKE, -TOE_OFF, smoothstep(0.0, 1.0, u))
		)
	# 나는 발은 지면보다 빨리 돌아와야 한다 — 디딤에 쓴 시간을 만회해야 하기 때문이다.
	var v := (phase - STANCE) / (1.0 - STANCE)
	return Vector3(
		-half + STEP_LENGTH * smoothstep(0.0, 1.0, v),
		SWING_LIFT * sin(PI * v),
		lerpf(-TOE_OFF, HEEL_STRIKE, smoothstep(0.0, 1.0, v))
	)


## `plant` 를 껐을 때의 발. **사인파로 앞뒤로 흔들 뿐이다.**
##
## 방향은 맞다 — 땅에 닿아 있는 동안 뒤로 간다. 그런데 **속력이 사인으로 변해서**
## 발이 땅 위에서 미끄러진다. 그리고 디딤이 정확히 0.5 라 양발 지지가 없다.
func _sliding_foot(phase: float) -> Vector3:
	var half := STEP_LENGTH * 0.5
	return Vector3(half * cos(TAU * phase), SWING_LIFT * maxf(0.0, -sin(TAU * phase)), 0.0)


## 몸 — 한 걸음에 두 번 내려앉는다. **가장 낮은 순간이 접지보다 조금 늦다.**
##
## 그 지연이 충격을 흡수하는 것으로 보이게 만든다. `delay` 를 끄면 발과 정확히 같이
## 내려가 흡수가 사라진다 (§25.10.5).
func _apply_torso(pose: CharPose, t: float, f: AnimFeatures) -> void:
	var part := CharPart.Id.TORSO
	var drop := _footfall(t, TORSO_BOB_DELAY, f)
	pose.positions[part] += Vector2(TORSO_SURGE * _surge(t, 0.0, f) * f.arc, -TORSO_BOB * drop)
	pose.rotations[part] = -TORSO_LEAN * f.arc
	# 가장 낮을 때 눌린다. 위로 갈 때는 안 늘린다 — 걸음은 흡수가 본체다.
	pose.scales[part] = CharClip.volume_scale(-TORSO_SQUASH * maxf(drop, 0.0) * f.squash)


func _apply_head(pose: CharPose, t: float, f: AnimFeatures) -> void:
	var part := CharPart.Id.HEAD
	var drop := _footfall(t, HEAD_BOB_DELAY, f)
	pose.positions[part] += Vector2(
		HEAD_SURGE * _surge(t, HEAD_BOB_DELAY, f) * f.arc, -HEAD_BOB * drop
	)
	# 몸이 앞으로 기운 만큼 머리는 뒤로 남는다 — 척추의 S 곡선 (idle 과 같은 규칙).
	pose.rotations[part] = HEAD_TILT * _surge(t, HEAD_TILT_DELAY, f) * f.arc
	pose.scales[part] = CharClip.volume_scale(HEAD_SQUASH * maxf(drop, 0.0) * f.squash)


## 손 — **같은 쪽 발과 반대로** 흔든다.
##
## 같은 위상으로 두면 동측 보행이 되어 그 즉시 사람이 아닌 것으로 읽힌다 (§25.10.6).
## 깊이 규칙(뒷손이 작고 늦다)은 idle 에서 그대로 얹힌다.
func _apply_hand(pose: CharPose, t: float, f: AnimFeatures, part: CharPart.Id) -> void:
	var far := 1.0 if CharPart.is_far(part) else 0.0
	var motion := lerpf(1.0, FAR_MOTION, far * f.depth)
	var delay := FAR_DELAY * far * f.depth

	# 같은 쪽 발의 위상. 손은 그 발과 **반대로** 나가므로 부호가 음수다.
	var mate := CharPart.Id.FOOT_FAR if far > 0.0 else CharPart.Id.FOOT_NEAR
	var swing := -cos(TAU * (foot_phase(t, mate) - (HAND_SWING_DELAY + delay) * f.delay))
	pose.positions[part] += Vector2(
		HAND_SWING * motion * swing * f.arc,
		-HAND_BOB * motion * _footfall(t, HAND_BOB_DELAY + delay, f)
	)
	pose.rotations[part] = HAND_TILT * motion * swing * f.arc


## 발이 닿을 때마다 내려가는 신호. 한 걸음에 **2 회** — 발이 둘이니까.
##
## `+1` 이 가장 낮은 순간이다. 몸과 머리가 이것을 서로 다른 지연으로 받는다.
func _footfall(t: float, delay: float, f: AnimFeatures) -> float:
	return cos(2.0 * TAU * (t / STRIDE - delay * f.delay))


## 앞뒤로 밀리는 신호. 한 걸음에 2 회 — 발을 디딜 때마다 몸이 조금 밀린다.
func _surge(t: float, delay: float, f: AnimFeatures) -> float:
	return sin(2.0 * TAU * (t / STRIDE - delay * f.delay))
