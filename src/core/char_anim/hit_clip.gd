class_name CharHitClip
extends CharClip
## get hit — **경직 · 띄우기 · 바닥 쓰러짐.** §28.5 가 확정한 셋이 한 클립에 들어간다.
##
## `docs/design/25-character-animation.md` §25.12.
##
## **구조를 새로 짤 것이 하나도 없었다.** 휘두르기의 감쇠 진동을 그대로 쓰고
## **파츠마다 감쇠만 다르게** 준다 — 머리가 가장 오래 흔들리고 발이 가장 안 흔들린다.
## §25.3.1 이 처음부터 「사건 이후 흐른 시간의 함수」로 짜 두라고 한 값이 여기서 나온다.
##
## | 구간 | 하는 일 |
## | --- | --- |
## | **경직** | 맞은 자세로 **완전히 멈춘다.** 이 정지가 타격의 무게다 |
## | **띄우기** | 포물선으로 뜨고 뒤로 밀린다 |
## | **바닥 쓰러짐** | 떨어져 한 번 튀고 주저앉는다 |
##
## **`plant` 축은 여기서 아무 상관이 없다** — 그것은 walk 의 디딤 등속만 관장한다.
## 띄우기가 지면 규칙과 부딪히지도 않는다. 지면 규칙은 **파고드는 것만 금지하고
## 뜨는 것은 허용**하기 때문이다 (§25.12.1).

## 경직. 맞은 자세로 멈춰 있는 시간. **짧아야 한다** — 길면 정지가 아니라 고장으로 보인다.
const FREEZE := 0.09

## 띄워져 있는 시간과 한 번 튀는 시간.
const FLIGHT := 0.34
const BOUNCE := 0.18

## 주저앉아 자리 잡는 시간.
const SETTLE := 0.55

const LAUNCH_HEIGHT := 26.0

## 튈 때 올라가는 높이의 비율. 1 에 가까우면 공이 되고 0 이면 철퍼덕 떨어진다.
const BOUNCE_RATIO := 0.28

## 뒤로 밀리는 거리. 캐릭터는 `+x` 를 보고 있으므로 **`-x` 로** 밀린다.
const KNOCKBACK := 34.0

## 맞은 순간의 자세. `(앞뒤, 상하, 회전)` — `WeaponGuard.POSES` 와 같은 방식이다.
##
## **뒤로 젖혀지는 것이 양수 회전이다.** 피벗이 밑면이라 위쪽이 `-x` 로 가려면
## 반시계로 돌아야 한다.
const RECOIL: Dictionary[CharPart.Id, Vector3] = {
	CharPart.Id.HEAD: Vector3(-7.0, 1.0, 0.42),
	CharPart.Id.TORSO: Vector3(-4.0, 0.0, 0.24),
	CharPart.Id.HAND_FAR: Vector3(-6.0, 3.0, 0.30),
	CharPart.Id.HAND_NEAR: Vector3(-9.0, 4.0, 0.55),
	CharPart.Id.FOOT_FAR: Vector3(1.0, 0.0, 0.0),
	CharPart.Id.FOOT_NEAR: Vector3(2.0, 0.0, -0.10),
}

## 다 끝나고 주저앉은 자세. **발은 상하를 안 건드린다** — 땅에 있어야 하기 때문이다.
const SLUMP: Dictionary[CharPart.Id, Vector3] = {
	CharPart.Id.HEAD: Vector3(-12.0, -34.0, 0.60),
	CharPart.Id.TORSO: Vector3(-6.0, -20.0, 0.50),
	CharPart.Id.HAND_FAR: Vector3(-14.0, -26.0, 0.40),
	CharPart.Id.HAND_NEAR: Vector3(-10.0, -30.0, 0.90),
	CharPart.Id.FOOT_FAR: Vector3(-9.0, 0.0, 0.16),
	CharPart.Id.FOOT_NEAR: Vector3(6.0, 0.0, -0.22),
}

## 파츠마다 **다른 감쇠**. 이것이 「관절 없는데 살로 보이는」 것의 정체다.
##
## 머리가 가장 오래 흔들리고(목이 무거우니까) 발이 가장 안 흔들린다(땅에 있으니까).
## 같은 감쇠를 주면 여섯이 한 덩어리로 떨려 인형이 된다.
const RING_DECAY: Dictionary[CharPart.Id, float] = {
	CharPart.Id.HEAD: 3.4,
	CharPart.Id.TORSO: 6.0,
	CharPart.Id.HAND_FAR: 4.2,
	CharPart.Id.HAND_NEAR: 3.8,
	CharPart.Id.FOOT_FAR: 9.0,
	CharPart.Id.FOOT_NEAR: 9.0,
}

## 흔들리는 폭 (px) 과 회전 폭 (rad), 한 번 흔들리는 데 걸리는 시간.
const RING_SHIFT := 3.6
const RING_TWIST := 0.16
const RING_PERIOD := 0.26

## 맞는 순간의 눌림. 몸이 한 번 찌그러졌다 펴진다.
const IMPACT_SQUASH := 0.075

## 들고 있는 무기. **무기가 얹힌 상태가 전투 애니메이션의 바탕이다**(§25.11) —
## 무거운 무기는 더 길어서 쓰러질 때 검끝이 바닥에 박히기 쉽다.
var weapon := CharWeapon.new(1)


func clip_name() -> String:
	# 가운뎃점(U+00B7)이 아니라 불릿(U+2022)이다. **SongMyung 에 U+00B7 이 없어서**
	# 웹 빌드에서 두부가 된다 - 화면에 나가는 문자열이므로 글리프 검사가 잡았다.
	return "get hit (경직 • 띄우기 • 쓰러짐)"


func loop_seconds() -> float:
	return FREEZE + FLIGHT + BOUNCE + SETTLE


## **루프가 아니다.** 쓰러진 자세에 멈춰 선다 — 일어나기는 별개의 동작이다.
func is_looping() -> bool:
	return false


## 지면에서 뜬 높이. **포물선이다** — 사건 이후 흐른 시간의 함수라 그냥 닫힌 식이다.
##
## 경직 동안에는 0 이다. 맞은 자리에서 **멈춰 있어야** 정지가 보인다.
func lift(t: float) -> float:
	var flying := t - FREEZE
	if flying <= 0.0:
		return 0.0
	if flying < FLIGHT:
		return _hop(flying / FLIGHT, LAUNCH_HEIGHT)
	var bouncing := flying - FLIGHT
	if bouncing < BOUNCE:
		return _hop(bouncing / BOUNCE, LAUNCH_HEIGHT * BOUNCE_RATIO)
	return 0.0


## 뒤로 밀린 거리 (음수). 끝에서 속도가 0 이 되어 **미끄러지다 멈춘다.**
func drift(t: float) -> float:
	var flying := t - FREEZE
	if flying <= 0.0:
		return 0.0
	var span := FLIGHT + BOUNCE
	return -KNOCKBACK * smoothstep(0.0, 1.0, clampf(flying / span, 0.0, 1.0))


## 주저앉은 자세로 얼마나 갔는가. 땅에 닿고 나서야 오른다.
func slump(t: float) -> float:
	var landing := t - (FREEZE + FLIGHT)
	if landing <= 0.0:
		return 0.0
	return smoothstep(0.0, 1.0, clampf(landing / (BOUNCE + SETTLE), 0.0, 1.0))


## 맞은 자세가 남아 있는 정도. 경직 동안 **정확히 1** 이고 그 뒤로 빠르게 풀린다.
func recoil(t: float) -> float:
	if t < FREEZE:
		return 1.0
	return maxf(0.0, 1.0 - (t - FREEZE) / (FLIGHT * 0.8))


func sample(t: float, features: AnimFeatures) -> CharPose:
	var pose := CharPose.from_rig(rig)
	var at := clampf(t, 0.0, loop_seconds())
	var height := lift(at)
	var back := drift(at)
	var down := slump(at)
	var snap := recoil(at)
	for part in CharPart.COUNT:
		_apply_part(pose, part, at, features, height, back, down, snap)
	# 무기는 파츠가 아니라 접지 검사가 못 본다. 검끝이 박혔으면 든 손을 들어 띄운다.
	keep_weapon_off_floor(pose, weapon)
	return pose


func _apply_part(
	pose: CharPose,
	part: CharPart.Id,
	t: float,
	f: AnimFeatures,
	height: float,
	back: float,
	down: float,
	snap: float
) -> void:
	var hit: Vector3 = RECOIL[part]
	var rest: Vector3 = SLUMP[part]
	var far := 1.0 if CharPart.is_far(part) else 0.0
	# 먼 파츠가 덜 움직인다 — idle · walk 와 같은 깊이 규칙이다.
	var motion := lerpf(1.0, 0.78, far * f.depth)
	# 파츠마다 감쇠가 다르다. **여기가 「살로 보이는」 지점이다.**
	var wobble := _ring(t, RING_DECAY[part]) * f.delay * motion

	var shift := Vector2(hit.x, hit.y) * snap + Vector2(rest.x, rest.y) * down
	pose.positions[part] += (
		Vector2(shift.x * f.arc + back * motion, shift.y + height)
		+ Vector2(RING_SHIFT * wobble * f.arc, 0.0)
	)
	pose.rotations[part] = (hit.z * snap + rest.z * down) * f.arc + RING_TWIST * wobble

	# 발은 회전한 만큼 되들어 올린다 (idle · walk 와 같은 규칙).
	#
	# **떠 있을 때만 빼는 조건을 달았다가 걸렸다.** 뜬 높이가 0 을 갓 벗어난 프레임에서
	# 보정이 툭 꺼져 발이 0.22 만큼 파고들었다. 보정은 회전에서 나오는 값이지 높이와
	# 무관하므로 **언제나 건다** — 조건을 다는 것 자체가 불연속을 만든다.
	if CharPart.is_foot(part):
		pose.positions[part] += Vector2(0.0, pose.lift_to_clear_ground(part, rig))

	if part == CharPart.Id.TORSO:
		pose.scales[part] = CharClip.volume_scale(-IMPACT_SQUASH * snap * f.squash)


## 포물선 한 번. `u` 가 0 과 1 에서 정확히 0 이라 구간이 매끄럽게 이어진다.
func _hop(u: float, peak: float) -> float:
	return peak * 4.0 * u * (1.0 - u)


## 감쇠 진동. 휘두르기의 후속과 **같은 식**이다 — 새로 짤 것이 없었다.
func _ring(t: float, decay: float) -> float:
	var since := t - FREEZE
	if since <= 0.0:
		return 0.0
	return exp(-decay * since) * sin(TAU * since / RING_PERIOD)
